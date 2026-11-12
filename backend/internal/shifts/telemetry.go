package shifts

import (
	"crypto/subtle"
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
)

// Telemetry takes the scooters' own reports (reportScooterTelemetry). The scooters, or the fleet
// system that speaks for them, sign with the shared key in TELEMETRY_KEY; with no key set the
// endpoint refuses everything.
type Telemetry struct {
	Service *Service
	Key     string
}

// Mount adds reportScooterTelemetry.
func (t *Telemetry) Mount(r chi.Router) {
	r.Post("/scooters/{code}/telemetry", t.report)
}

// maxClockSkew is how far ahead of the server a report's time may be.
const maxClockSkew = time.Minute

func (t *Telemetry) report(w http.ResponseWriter, r *http.Request) {
	if t.Key == "" || subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Telemetry-Key")), []byte(t.Key)) != 1 {
		httpserver.WriteError(w, http.StatusUnauthorized, "unauthorized", "Send the telemetry key.", false)
		return
	}
	var body struct {
		BatteryPct *int      `json:"battery_pct"`
		At         time.Time `json:"at"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.BatteryPct == nil || *body.BatteryPct < 0 || *body.BatteryPct > 100 ||
		body.At.IsZero() || body.At.After(time.Now().Add(maxClockSkew)) {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send battery_pct (0 to 100) and at.", false)
		return
	}
	code := chi.URLParam(r, "code")
	// Only a newer reading replaces the one kept; a scooter's change raises its rider's seq.
	tag, err := t.Service.Pool.Exec(r.Context(), `UPDATE scooters SET battery_pct = $2, battery_at = $3
		WHERE code = $1 AND (battery_at IS NULL OR battery_at < $3)`, code, *body.BatteryPct, body.At.UTC())
	if err != nil {
		t.Service.fail(w, r, err)
		return
	}
	if tag.RowsAffected() == 0 {
		var known bool
		if err := t.Service.Pool.QueryRow(r.Context(), "SELECT EXISTS (SELECT 1 FROM scooters WHERE code = $1)", code).Scan(&known); err != nil {
			t.Service.fail(w, r, err)
			return
		}
		if !known {
			httpserver.WriteError(w, http.StatusNotFound, "not_found", "No such scooter.", false)
			return
		}
	} else if _, err := t.Service.Pool.Exec(r.Context(), `INSERT INTO rider_state (rider_id, seq)
			SELECT current_rider_id, 1 FROM scooters WHERE code = $1 AND current_rider_id IS NOT NULL
			ON CONFLICT (rider_id) DO UPDATE SET seq = rider_state.seq + 1, updated_at = now()`, code); err != nil {
		t.Service.fail(w, r, err)
		return
	}
	httpserver.WriteJSON(w, http.StatusAccepted, map[string]any{"server_time": serverTime()})
}
