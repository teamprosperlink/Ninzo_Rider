package orders

import (
	"context"
	"crypto/subtle"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/identity"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/idempotency"
)

// RiderCalls makes the rider's masked calls with a telephony provider's "dynamic connect" flow:
// the rider calls VirtualNumber, the provider asks connectCall whom to connect, and gets the
// customer's number. Set from TELEPHONY_VIRTUAL_NUMBER and TELEPHONY_WEBHOOK_KEY; without them,
// every rider call is call_not_available, as before.
type RiderCalls struct {
	VirtualNumber string
	WebhookKey    string
	// TTL is how long the bridge stays open for the rider to call. Zero means five minutes.
	TTL time.Duration
}

var e164 = regexp.MustCompile(`^\+[1-9][0-9]{7,14}$`)

// ready says whether rider calls can be made.
func (c *RiderCalls) ready() bool {
	return c != nil && e164.MatchString(c.VirtualNumber) && c.WebhookKey != ""
}

func (c *RiderCalls) ttl() time.Duration {
	if c.TTL > 0 {
		return c.TTL
	}
	return 5 * time.Minute
}

// bridgeRiderCall opens a bridge from the rider to the order's customer and answers the number to
// call. The order must be one this rider accepted and still holds.
func (s *Service) bridgeRiderCall(w http.ResponseWriter, r *http.Request, actor identity.Actor, orderID string) {
	var reply map[string]any
	err := database.InTx(r.Context(), s.Pool, func(tx pgx.Tx) error {
		var riderPhone, customerPhone *string
		err := tx.QueryRow(r.Context(), `SELECT rp.phone, cp.phone FROM orders o
			JOIN offers f ON f.order_id = o.id AND f.rider_id = $2 AND f.state = 'accepted' AND f.released_at IS NULL
			JOIN riders rd ON rd.id = f.rider_id JOIN people rp ON rp.id = rd.person_id
			JOIN customers c ON c.id = o.customer_id JOIN people cp ON cp.id = c.person_id
			WHERE o.id = $1`, orderID, actor.ID).Scan(&riderPhone, &customerPhone)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return err
		}
		if riderPhone == nil || customerPhone == nil {
			return errNoCalls // A customer signed in with Google may have no phone yet.
		}
		var expires time.Time
		if err := tx.QueryRow(r.Context(), `INSERT INTO call_bridges (order_id, rider_id, virtual_number, caller_phone, callee_phone, expires_at)
			VALUES ($1, $2, $3, $4, $5, now() + make_interval(secs => $6)) RETURNING expires_at`,
			orderID, actor.ID, s.RiderCalls.VirtualNumber, *riderPhone, *customerPhone, s.RiderCalls.ttl().Seconds()).Scan(&expires); err != nil {
			return err
		}
		// The numbers stay out of the stored reply's audit; the reply holds only the virtual one.
		reply = map[string]any{"phone": s.RiderCalls.VirtualNumber, "expires_at": expires.UTC().Format(time.RFC3339Nano), "server_time": serverTime()}
		return idempotency.Save(r.Context(), tx, http.StatusOK, reply)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpserver.WriteJSON(w, http.StatusOK, reply)
}

// MountCallWebhook adds connectCall, which the telephony provider calls; it is signed with the
// webhook key, not a session.
func (s *Service) MountCallWebhook(r chi.Router) {
	r.Get("/telephony/connect", s.connectCall)
}

// lastTen is an Indian number's ten digits, however the provider writes it (+91…, 0…, 91…).
func lastTen(n string) string {
	digits := strings.Map(func(c rune) rune {
		if c >= '0' && c <= '9' {
			return c
		}
		return -1
	}, n)
	if len(digits) < 10 {
		return ""
	}
	return digits[len(digits)-10:]
}

// connectCall answers whom a call from `from` to the virtual number `to` connects to: the customer
// of the caller's newest open bridge. With format=text it is the number alone, for providers that
// read plain text.
func (s *Service) connectCall(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	if !s.RiderCalls.ready() || subtle.ConstantTimeCompare([]byte(q.Get("key")), []byte(s.RiderCalls.WebhookKey)) != 1 {
		httpserver.WriteError(w, http.StatusUnauthorized, "unauthorized", "Send the webhook key.", false)
		return
	}
	from, to := lastTen(q.Get("from")), lastTen(q.Get("to"))
	if from == "" || (to != "" && to != lastTen(s.RiderCalls.VirtualNumber)) {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send from, and to as the virtual number.", false)
		return
	}
	number, err := s.calleeFor(r.Context(), from)
	if errors.Is(err, pgx.ErrNoRows) {
		httpserver.WriteError(w, http.StatusNotFound, "not_found", "No open call for this caller.", false)
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if q.Get("format") == "text" {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte(number))
		return
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{"number": number, "server_time": serverTime()})
}

func (s *Service) calleeFor(ctx context.Context, fromTen string) (string, error) {
	var number string
	err := s.Pool.QueryRow(ctx, `SELECT callee_phone FROM call_bridges
		WHERE virtual_number = $1 AND right(caller_phone, 10) = $2 AND expires_at > now()
		ORDER BY created_at DESC LIMIT 1`, s.RiderCalls.VirtualNumber, fromTen).Scan(&number)
	return number, err
}
