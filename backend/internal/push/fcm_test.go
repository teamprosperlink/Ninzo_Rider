package push

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/golang-jwt/jwt/v5"
)

func account(t *testing.T, tokenURL string) ([]byte, *rsa.PrivateKey) {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	pemKey := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
	raw, _ := json.Marshal(map[string]string{"client_email": "push@ninzo.iam.gserviceaccount.com", "private_key": string(pemKey), "token_uri": tokenURL})
	return raw, key
}

func TestAPushIsSignedAndSent(t *testing.T) {
	var tokens, sends atomic.Int32
	var sent map[string]any
	var key *rsa.PrivateKey
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/token":
			tokens.Add(1)
			_ = r.ParseForm()
			claims := jwt.MapClaims{}
			if _, err := jwt.ParseWithClaims(r.Form.Get("assertion"), claims, func(*jwt.Token) (any, error) { return &key.PublicKey, nil }); err != nil {
				t.Errorf("assertion: %v", err)
			}
			if claims["scope"] != scope || claims["iss"] != "push@ninzo.iam.gserviceaccount.com" {
				t.Errorf("claims %v", claims)
			}
			_, _ = io.WriteString(w, `{"access_token":"ya29.test","expires_in":3600}`)
		case "/v1/projects/ninzo-test/messages:send":
			sends.Add(1)
			if r.Header.Get("Authorization") != "Bearer ya29.test" {
				t.Errorf("auth %q", r.Header.Get("Authorization"))
			}
			_ = json.NewDecoder(r.Body).Decode(&sent)
			if strings.Contains(r.URL.RawQuery, "fail") {
				w.WriteHeader(500)
			}
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	raw, k := account(t, srv.URL+"/token")
	key = k
	f, err := New("ninzo-test", raw, srv.Client())
	if err != nil {
		t.Fatal(err)
	}
	f.sendURL = srv.URL + "/v1/projects/ninzo-test/messages:send"
	payload := map[string]any{"rider_id": "r1", "kind": "notification", "title": "Your stock is ready", "body": "Collect it at the hub.", "n": 3}
	for range 2 {
		if err := f.Push(context.Background(), "android", "device-token", "push.rider", payload); err != nil {
			t.Fatal(err)
		}
	}
	if tokens.Load() != 1 || sends.Load() != 2 {
		t.Errorf("%d tokens, %d sends: the access token must be kept", tokens.Load(), sends.Load())
	}
	msg := sent["message"].(map[string]any)
	data := msg["data"].(map[string]any)
	if msg["token"] != "device-token" || msg["notification"].(map[string]any)["title"] != "Your stock is ready" ||
		data["topic"] != "push.rider" || data["n"] != "3" || data["kind"] != "notification" {
		t.Errorf("%v", sent)
	}
	f.sendURL += "?fail"
	if err := f.Push(context.Background(), "android", "device-token", "push.rider", payload); err == nil {
		t.Error("a 500 must be retried")
	}
}

func TestAGoneTokenIsNotRetried(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/token" {
			_, _ = io.WriteString(w, `{"access_token":"a","expires_in":3600}`)
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()
	raw, _ := account(t, srv.URL+"/token")
	f, err := New("p", raw, srv.Client())
	if err != nil {
		t.Fatal(err)
	}
	f.sendURL = srv.URL + "/send"
	if err := f.Push(context.Background(), "ios", "old", "push.customer", map[string]any{"stage": "ARRIVED"}); err != nil {
		t.Errorf("%v", err)
	}
}

func TestBadAccountsAreRefused(t *testing.T) {
	for name, raw := range map[string]string{
		"not json": "nope",
		"no key":   `{"client_email":"a@b"}`,
		"not pem":  `{"client_email":"a@b","private_key":"abc"}`,
	} {
		if _, err := New("p", []byte(raw), nil); err == nil {
			t.Errorf("%s was accepted", name)
		}
	}
	if _, err := New("", []byte(`{}`), nil); err == nil {
		t.Error("no project was accepted")
	}
	if _, err := FromFile("p", "no/such/file.json"); err == nil {
		t.Error("a missing file was accepted")
	}
}

type recorder struct{ topics []string }

func (r *recorder) Push(_ context.Context, _, _, topic string, _ map[string]any) error {
	r.topics = append(r.topics, topic)
	return nil
}

func TestOnlyRiderPushesGoToTheRiderPusher(t *testing.T) {
	rider, others := &recorder{}, &recorder{}
	p := RiderOnly{Rider: rider, Others: others}
	for _, topic := range []string{"push.rider", "push.customer", "push.rider"} {
		_ = p.Push(context.Background(), "android", "t", topic, nil)
	}
	if len(rider.topics) != 2 || len(others.topics) != 1 || others.topics[0] != "push.customer" {
		t.Errorf("rider %v, others %v", rider.topics, others.topics)
	}
}
