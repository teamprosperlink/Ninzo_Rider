package profile

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/geo"
	"github.com/teamprosperlink/Ninzo_backend/internal/identity"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/idempotency"
	"github.com/teamprosperlink/Ninzo_backend/internal/riderrules"
)

// Choices the rider app offers. They are the API's, so the app has none of its own; each code is
// what the app sends back (a skip's reason, a problem's type, a checklist item).
var (
	breakOptionsS   = []int{900, 1800, 2700, 3600}
	addTimeOptionsS = []int{900, 1800, 2700, 3600, 7200, 10800, 14400}
	skipReasons     = []map[string]string{
		{"code": "scooterProblem", "label": "Scooter problem"},
		{"code": "itemMissing", "label": "Item missing or damaged"},
		{"code": "notSafe", "label": "Not safe to ride"},
		{"code": "somethingElse", "label": "Something else"},
	}
	// The codes are reportProblem's type enum.
	problemTypes = []map[string]string{
		{"code": "breakdown", "label": "Breakdown", "hint": "Scooter won’t run"},
		{"code": "accident", "label": "Accident", "hint": "Tell us you’re safe"},
		{"code": "gate_closed", "label": "Gate closed", "hint": "Can’t get in"},
		{"code": "customer_absent", "label": "Customer absent", "hint": "Not at the gate"},
		{"code": "unsafe_route", "label": "Unsafe route", "hint": "Road feels unsafe"},
	}
	// check says what the app checks itself: manual is the rider's tick.
	checklist = []map[string]string{
		{"code": "helmet", "label": "Helmet on", "check": "manual", "hint": "Wear your helmet at all times"},
		{"code": "phoneCharged", "label": "Phone charged", "check": "phone_battery"},
		{"code": "scooterBattery", "label": "Scooter battery OK", "check": "scooter_battery"},
		{"code": "location", "label": "Location is on", "check": "location", "hint": "Needed to match you with nearby orders"},
		{"code": "insulatedBox", "label": "Insulated box ready", "check": "manual", "hint": "Clean, no leaks, lid closes firmly"},
		{"code": "scooterClean", "label": "Scooter is clean", "check": "manual", "hint": "Box and seat wiped"},
	}
)

// ChecklistCodes are the checklist items startShift accepts.
func ChecklistCodes() map[string]bool {
	out := map[string]bool{}
	for _, c := range checklist {
		out[c["code"]] = true
	}
	return out
}

// MountRiderApp adds getRiderSettings, getRiderHelp and sendRiderFeedback.
func (s *Service) MountRiderApp(r chi.Router, signedIn ...Middleware) {
	idem := idempotency.Middleware(s.Pool, idempotency.Options{Actor: identity.ActorID, Log: s.Log})
	r.Group(func(g chi.Router) {
		g.Use(signedIn...)
		g.Get("/riders/me/settings", s.getRiderSettings)
		g.Get("/riders/me/help", s.getRiderHelp)
		g.With(idem).Post("/riders/me/feedback", s.sendFeedback)
	})
}

// getRiderSettings is the rider's zone settings the app works by, with the choices it offers.
func (s *Service) getRiderSettings(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	if !s.requireLive(w, r, actor) {
		return
	}
	rd, err := readRider(r.Context(), s.Pool, actor.ID)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	zone := ""
	if rd.zone != nil {
		zone = *rd.zone
	}
	e, err := geo.LoadSettings(r.Context(), s.Pool, zone)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	value := func(name string) any {
		if v, ok := e.Get(name); ok {
			return v
		}
		return nil
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{
		"settings": map[string]any{
			"timer_length_s":                  value("timer_length_s"),
			"arrive_m":                        value("rider_arrive_m"),
			"almost_there_m":                  value("rider_almost_m"),
			"away_from_spot_m":                value("rider_away_m"),
			"low_stock_qty":                   value("restock_low_qty"),
			"scooter_capacity_qty":            value("scooter_capacity_qty"),
			"min_phone_battery_pct":           value("min_phone_battery_pct"),
			"min_scooter_battery_pct":         value("min_scooter_battery_pct"),
			"low_scooter_battery_pct":         value("low_scooter_battery_pct"),
			"ride_speed_kmh":                  value("straight_line_speed_kmh"),
			"break_options_s":                 breakOptionsS,
			"add_time_options_s":              addTimeOptionsS,
			"skip_reasons":                    skipReasons,
			"problem_types":                   problemTypes,
			"checklist":                       checklist,
			"stock_request_ask_before_s":      int(riderrules.StockAskBefore.Seconds()),
			"stock_request_reminder_before_s": int(riderrules.StockReminderBefore.Seconds()),
			"shift_ending_soon_before_s":      int(riderrules.EndingSoonBefore.Seconds()),
			"break_extension_s":               int(riderrules.BreakExtension.Seconds()),
			"not_at_gate_after_s":             int(riderrules.NotAtGateAfter.Seconds()),
			"handover_code_length":            riderrules.HandoverCodeDigits,
		},
		"server_time": serverTime(),
	})
}

// getRiderHelp is the help centre's questions and answers, in order.
func (s *Service) getRiderHelp(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	if !s.requireLive(w, r, actor) {
		return
	}
	rows, err := s.Pool.Query(r.Context(), `SELECT id::text, question, answer FROM help_articles
		WHERE app = 'rider' AND status = 'active' ORDER BY sort_order, created_at, id`)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	faq, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (map[string]any, error) {
		var id, q, a string
		err := row.Scan(&id, &q, &a)
		return map[string]any{"id": id, "question": q, "answer": a}, err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if faq == nil {
		faq = []map[string]any{}
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{"faq": faq, "server_time": serverTime()})
}

const maxFeedbackRunes = 2000

// sendFeedback keeps what the rider wrote, for the team to read.
func (s *Service) sendFeedback(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	var body struct {
		Message string `json:"message"`
	}
	err := json.NewDecoder(r.Body).Decode(&body)
	msg := strings.TrimSpace(body.Message)
	if err != nil || msg == "" || !utf8.ValidString(msg) || utf8.RuneCountInString(msg) > maxFeedbackRunes ||
		strings.ContainsFunc(msg, func(c rune) bool { return unicode.IsControl(c) && c != '\n' && c != '\t' }) {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send a message of 1 to 2000 characters.", false)
		return
	}
	var reply map[string]any
	err = database.InTx(r.Context(), s.Pool, func(tx pgx.Tx) error {
		if err := identity.CheckSession(r.Context(), tx, actor); err != nil {
			return err
		}
		if _, err := readRider(r.Context(), tx, actor.ID); err != nil {
			return err
		}
		var id string
		var at time.Time
		if err := tx.QueryRow(r.Context(), "INSERT INTO rider_feedback (rider_id, message) VALUES ($1, $2) RETURNING id::text, created_at",
			actor.ID, msg).Scan(&id, &at); err != nil {
			return err
		}
		reply = map[string]any{"feedback_id": id, "server_time": serverTime()}
		return idempotency.Save(r.Context(), tx, http.StatusCreated, reply)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpserver.WriteJSON(w, http.StatusCreated, reply)
}
