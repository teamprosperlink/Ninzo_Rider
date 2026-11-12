package shifts

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
)

func TestScooterTelemetryIsTheShiftsBattery(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	_, token := f.rider()
	tel := &Telemetry{Service: &Service{Pool: f.s.Pool, Log: quiet}, Key: "fleet-key"}
	srv := httptest.NewServer(httpserver.NewRouter(quiet, func(context.Context) error { return nil }, func(r chi.Router) { tel.Mount(r) }))
	t.Cleanup(srv.Close)
	report := func(key, code, body string) int {
		t.Helper()
		req, _ := http.NewRequest("POST", srv.URL+"/v1/scooters/"+code+"/telemetry", strings.NewReader(body))
		if key != "" {
			req.Header.Set("X-Telemetry-Key", key)
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		return resp.StatusCode
	}
	now := time.Now().UTC()
	at := func(d time.Duration) string { return now.Add(d).Format(time.RFC3339) }
	if c := report("", "SC-1", `{"battery_pct":70,"at":"`+at(0)+`"}`); c != 401 {
		t.Errorf("no key: %d", c)
	}
	if c := report("wrong", "SC-1", `{"battery_pct":70,"at":"`+at(0)+`"}`); c != 401 {
		t.Errorf("wrong key: %d", c)
	}
	for _, body := range []string{`{"battery_pct":101,"at":"` + at(0) + `"}`, `{"at":"` + at(0) + `"}`, `{"battery_pct":50,"at":"` + at(time.Hour) + `"}`} {
		if c := report("fleet-key", "SC-1", body); c != 400 {
			t.Errorf("%s: %d", body, c)
		}
	}
	if c := report("fleet-key", "NOPE", `{"battery_pct":70,"at":"`+at(0)+`"}`); c != 404 {
		t.Errorf("unknown scooter: %d", c)
	}
	f.start(token)
	if c := report("fleet-key", "SC-1", `{"battery_pct":72,"at":"`+at(-time.Minute)+`"}`); c != 202 {
		t.Fatalf("%d", c)
	}
	// An older reading does not replace a newer one.
	report("fleet-key", "SC-1", `{"battery_pct":10,"at":"`+at(-10*time.Minute)+`"}`)
	if n := f.count("SELECT battery_pct FROM scooters WHERE code = 'SC-1'"); n != 72 {
		t.Errorf("kept %d", n)
	}
	var sh shift
	var started time.Time
	if err := f.s.Pool.QueryRow(context.Background(), "SELECT id::text, started_at FROM shifts WHERE ended_at IS NULL").Scan(&sh.ID, &started); err != nil {
		t.Fatal(err)
	}
	filled, err := Fill(context.Background(), f.s.Pool, sh.ID, started)
	if err != nil || filled.Scooter["battery_pct"] == nil || *filled.Scooter["battery_pct"].(*int) != 72 {
		t.Errorf("fresh: %v %v", filled.Scooter, err)
	}
	// A stale reading is not shown.
	f.exec("UPDATE scooters SET battery_at = now() - interval '2 hours' WHERE code = 'SC-1'")
	if filled, _ := Fill(context.Background(), f.s.Pool, sh.ID, started); filled.Scooter["battery_pct"].(*int) != nil {
		t.Errorf("stale: %v", filled.Scooter)
	}
}
