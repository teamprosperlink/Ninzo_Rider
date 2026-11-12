// Package push sends pushes to phones through Firebase Cloud Messaging (the HTTP v1 API), signed in
// with a Google service account. It implements orders.Pusher without importing it.
package push

import (
	"bytes"
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	scope       = "https://www.googleapis.com/auth/firebase.messaging"
	defaultSend = "https://fcm.googleapis.com/v1/projects/%s/messages:send"
	// A token is renewed this long before Google says it ends.
	renewEarly = 5 * time.Minute
)

// FCM sends pushes for one Firebase project.
type FCM struct {
	project  string
	email    string
	key      *rsa.PrivateKey
	tokenURL string
	sendURL  string
	client   *http.Client

	mu      sync.Mutex
	access  string
	expires time.Time
}

type serviceAccount struct {
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
}

// FromFile reads a service account JSON file, the one Firebase gives for the project.
func FromFile(project, path string) (*FCM, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("push: reading the service account: %w", err)
	}
	return New(project, raw, nil)
}

// New makes a sender from the service account's JSON. client may be nil.
func New(project string, account []byte, client *http.Client) (*FCM, error) {
	if strings.TrimSpace(project) == "" {
		return nil, errors.New("push: FCM_PROJECT_ID is not set")
	}
	var sa serviceAccount
	if err := json.Unmarshal(account, &sa); err != nil || sa.ClientEmail == "" || sa.PrivateKey == "" {
		return nil, errors.New("push: the service account JSON has no client_email or private_key")
	}
	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		return nil, errors.New("push: the service account's private_key is not PEM")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, errors.New("push: the service account's private_key cannot be read")
	}
	key, ok := parsed.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("push: the service account's private_key is not RSA")
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	return &FCM{project: project, email: sa.ClientEmail, key: key, tokenURL: sa.TokenURI,
		sendURL: fmt.Sprintf(defaultSend, url.PathEscape(project)), client: client}, nil
}

// token is an OAuth access token for FCM, kept until shortly before it ends.
func (f *FCM) token(ctx context.Context) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.access != "" && time.Now().Before(f.expires.Add(-renewEarly)) {
		return f.access, nil
	}
	now := time.Now()
	assertion, err := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": f.email, "scope": scope, "aud": f.tokenURL, "iat": now.Unix(), "exp": now.Add(time.Hour).Unix(),
	}).SignedString(f.key)
	if err != nil {
		return "", err
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {assertion}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := f.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	var out struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(resp.Body).Decode(&out) != nil || out.AccessToken == "" {
		return "", fmt.Errorf("push: Google refused the service account (%d)", resp.StatusCode)
	}
	f.access, f.expires = out.AccessToken, now.Add(time.Duration(out.ExpiresIn)*time.Second)
	return f.access, nil
}

// Message is what goes to the phone: the title and body it shows, and the payload as data.
func Message(token, topic string, payload map[string]any) map[string]any {
	data := map[string]string{"topic": topic}
	for k, v := range payload {
		switch v := v.(type) {
		case nil:
		case string:
			data[k] = v
		default:
			b, _ := json.Marshal(v)
			data[k] = string(b)
		}
	}
	msg := map[string]any{"token": token, "data": data}
	title, _ := payload["title"].(string)
	body, _ := payload["body"].(string)
	if title != "" {
		msg["notification"] = map[string]string{"title": title, "body": body}
		msg["android"] = map[string]any{"priority": "HIGH"}
	}
	return map[string]any{"message": msg}
}

// Push implements orders.Pusher. A token the phone no longer has is not an error: there is nothing
// to retry. Google's own failures are, so the outbox tries again.
func (f *FCM) Push(ctx context.Context, platform, token, topic string, payload map[string]any) error {
	access, err := f.token(ctx)
	if err != nil {
		return err
	}
	body, err := json.Marshal(Message(token, topic, payload))
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.sendURL, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+access)
	req.Header.Set("Content-Type", "application/json")
	resp, err := f.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	switch {
	case resp.StatusCode < 300:
		return nil
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest:
		// UNREGISTERED or a malformed token: the phone is gone, and retrying will not help.
		return nil
	case resp.StatusCode == http.StatusUnauthorized:
		f.mu.Lock()
		f.access = ""
		f.mu.Unlock()
		return errors.New("push: FCM refused the access token")
	default:
		return fmt.Errorf("push: FCM answered %d", resp.StatusCode)
	}
}

// Pusher is what the push worker hands each push to (orders.Pusher has the same method).
type Pusher interface {
	Push(ctx context.Context, platform, token, topic string, payload map[string]any) error
}

// RiderOnly sends rider pushes (topic push.rider) through Rider and every other topic through
// Others, so turning FCM on for riders leaves customers' pushes as they were.
type RiderOnly struct {
	Rider  Pusher
	Others Pusher
}

// Push implements Pusher.
func (p RiderOnly) Push(ctx context.Context, platform, token, topic string, payload map[string]any) error {
	if topic == "push.rider" {
		return p.Rider.Push(ctx, platform, token, topic, payload)
	}
	return p.Others.Push(ctx, platform, token, topic, payload)
}
