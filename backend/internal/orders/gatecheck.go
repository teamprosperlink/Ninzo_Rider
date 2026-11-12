package orders

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/identity"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
)

const maxGateCode = 64

// checkGate is checkGate: the rider's scan of the gate's QR code, or the code typed in, against the
// code printed at the gate. A gate with no code is arrived at by location alone (decision 0012), so
// the reply says nothing was checked. The order must be one this rider accepted.
func (s *Service) checkGate(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	var body struct {
		Method string `json:"method"`
		Value  string `json:"value"`
	}
	value := ""
	if err := json.NewDecoder(r.Body).Decode(&body); err == nil {
		value = strings.TrimSpace(body.Value)
	}
	if (body.Method != "qr" && body.Method != "code") || value == "" || len(value) > maxGateCode {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send method (qr or code) and value.", false)
		return
	}
	if err := s.riderReadable(r, actor); err != nil {
		s.fail(w, r, err)
		return
	}
	id := chi.URLParam(r, "order_id")
	if !idPattern.MatchString(id) {
		s.fail(w, r, errNotFound)
		return
	}
	var code *string
	err := s.Pool.QueryRow(r.Context(), `SELECT g.rider_code FROM orders o JOIN gates g ON g.id = o.gate_id
		JOIN offers f ON f.order_id = o.id AND f.rider_id = $2 AND f.state = 'accepted' AND f.released_at IS NULL
		WHERE o.id = $1 LIMIT 1`, id, actor.ID).Scan(&code)
	if errors.Is(err, pgx.ErrNoRows) {
		err = errNotFound
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	checked, matched := code != nil, true
	if checked {
		// A QR code may carry the code inside a longer text, such as a link; it must end with it.
		got, want := strings.ToUpper(value), strings.ToUpper(*code)
		if body.Method == "qr" && strings.HasSuffix(got, want) {
			got = got[len(got)-len(want):]
		}
		matched = subtle.ConstantTimeCompare([]byte(got), []byte(want)) == 1
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{"checked": checked, "matched": matched, "server_time": serverTime()})
}
