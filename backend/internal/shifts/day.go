package shifts

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/audit"
	"github.com/teamprosperlink/Ninzo_backend/internal/identity"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/idempotency"
)

const (
	minBreak         = time.Minute
	maxBreak         = time.Hour
	maxShiftLength   = 16 * time.Hour
	defaultShiftDays = 7
	maxShiftDays     = 31
)

// mountDay adds goOnline, takeBreak, endBreak, setPlannedEnd and listShifts.
func (s *Service) mountDay(g chi.Router, idem func(http.Handler) http.Handler) {
	g.With(idem).Post("/riders/me/shifts/online", s.goOnline)
	g.With(idem).Post("/riders/me/shifts/break", s.takeBreak)
	g.With(idem).Post("/riders/me/shifts/break/end", s.endBreak)
	g.With(idem).Post("/riders/me/shifts/planned-end", s.setPlannedEnd)
	g.Get("/riders/me/shifts", s.listShifts)
}

// onOpenShift runs change on the rider's open shift, locked, then answers the shift as it is now.
// change returns the audit action, or "" when nothing changed.
func (s *Service) onOpenShift(w http.ResponseWriter, r *http.Request, change func(ctx context.Context, tx pgx.Tx, sh shift) (string, error)) {
	actor, _ := identity.ActorFrom(r.Context())
	var reply map[string]any
	err := database.InTx(r.Context(), s.Pool, func(tx pgx.Tx) error {
		if err := identity.CheckSession(r.Context(), tx, actor); err != nil {
			return err
		}
		if _, err := readRider(r.Context(), tx, actor.ID); err != nil {
			return err
		}
		sh, _, open, err := openShift(r.Context(), tx, actor.ID)
		if err != nil {
			return err
		}
		if !open {
			return refuse("no_open_shift", "No shift is open.")
		}
		action, err := change(r.Context(), tx, sh)
		if err != nil {
			return err
		}
		if action != "" {
			if err := bump(r.Context(), tx, actor.ID); err != nil {
				return err
			}
			if err := audit.Record(r.Context(), tx, audit.Event{
				ActorType: identity.TypeRider, ActorID: actor.ID, Action: action, EntityType: "shift", EntityID: sh.ID,
			}); err != nil {
				return err
			}
		}
		started, err := time.Parse(time.RFC3339Nano, sh.StartedAt)
		if err != nil {
			return err
		}
		f, err := Fill(r.Context(), tx, sh.ID, started)
		if err != nil {
			return err
		}
		sh.fill(f)
		reply = map[string]any{"shift": sh, "server_time": serverTime()}
		return idempotency.Save(r.Context(), tx, http.StatusOK, reply)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpserver.WriteJSON(w, http.StatusOK, reply)
}

// goOnline keeps the first time the rider went online in the shift.
func (s *Service) goOnline(w http.ResponseWriter, r *http.Request) {
	s.onOpenShift(w, r, func(ctx context.Context, tx pgx.Tx, sh shift) (string, error) {
		tag, err := tx.Exec(ctx, "UPDATE shifts SET online_at = now() WHERE id = $1 AND online_at IS NULL", sh.ID)
		if err != nil || tag.RowsAffected() == 0 {
			return "", err
		}
		return "shift.online", nil
	})
}

// takeBreak starts a break, or makes the one under way longer: length_s counts from its start.
// Not with an order accepted, which must be delivered first.
func (s *Service) takeBreak(w http.ResponseWriter, r *http.Request) {
	var body struct {
		LengthS int `json:"length_s"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil ||
		time.Duration(body.LengthS)*time.Second < minBreak || time.Duration(body.LengthS)*time.Second > maxBreak {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "length_s must be 60 to 3600.", false)
		return
	}
	s.onOpenShift(w, r, func(ctx context.Context, tx pgx.Tx, sh shift) (string, error) {
		actor, _ := identity.ActorFrom(ctx)
		var busy bool
		if err := tx.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM offers WHERE rider_id = $1 AND released_at IS NULL AND state = 'accepted')",
			actor.ID).Scan(&busy); err != nil {
			return "", err
		}
		if busy {
			return "", refuse("order_in_progress", "Finish the current order first.")
		}
		// An open offer goes back, so the order finds another rider.
		if err := handBack(ctx, tx, actor.ID, identity.TypeRider, actor.ID); err != nil {
			return "", err
		}
		if _, err := tx.Exec(ctx, `UPDATE shifts SET break_started_at = coalesce(break_started_at, now()),
				break_ends_at = coalesce(break_started_at, now()) + make_interval(secs => $2) WHERE id = $1`, sh.ID, body.LengthS); err != nil {
			return "", err
		}
		return "shift.break", nil
	})
}

func (s *Service) endBreak(w http.ResponseWriter, r *http.Request) {
	s.onOpenShift(w, r, func(ctx context.Context, tx pgx.Tx, sh shift) (string, error) {
		tag, err := tx.Exec(ctx, "UPDATE shifts SET break_started_at = NULL, break_ends_at = NULL WHERE id = $1 AND break_started_at IS NOT NULL", sh.ID)
		if err != nil || tag.RowsAffected() == 0 {
			return "", err
		}
		return "shift.break_ended", nil
	})
}

// setPlannedEnd is "Add time": a new planned end, in the future and within 16 hours of the start.
func (s *Service) setPlannedEnd(w http.ResponseWriter, r *http.Request) {
	var body struct {
		PlannedEndAt time.Time `json:"planned_end_at"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.PlannedEndAt.IsZero() {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send planned_end_at.", false)
		return
	}
	s.onOpenShift(w, r, func(ctx context.Context, tx pgx.Tx, sh shift) (string, error) {
		started, err := time.Parse(time.RFC3339Nano, sh.StartedAt)
		if err != nil {
			return "", err
		}
		if !body.PlannedEndAt.After(time.Now()) || body.PlannedEndAt.Sub(started) > maxShiftLength {
			return "", &badRequest{"planned_end_at must be in the future and within 16 hours of the start."}
		}
		if _, err := tx.Exec(ctx, "UPDATE shifts SET planned_end_at = $2 WHERE id = $1", sh.ID, body.PlannedEndAt.UTC()); err != nil {
			return "", err
		}
		return "shift.planned_end", nil
	})
}

// badRequest is a 400 found once the shift is read.
type badRequest struct{ message string }

func (b *badRequest) Error() string { return "shifts: " + b.message }

// shiftRecord is one shift for listShifts.
type shiftRecord struct {
	ID           string  `json:"id"`
	NodeID       string  `json:"node_id"`
	StartedAt    string  `json:"started_at"`
	EndedAt      *string `json:"ended_at"`
	OnlineAt     *string `json:"online_at"`
	PlannedEndAt *string `json:"planned_end_at"`
	Orders       int     `json:"orders"`
	Portions     int     `json:"portions"`
	AvgDeliveryS *int    `json:"avg_delivery_s"`
}

// listShifts is the rider's shifts started in the last days days (India time, today included), with
// what was handed over on each: an order counts on the shift its offer was accepted in.
func (s *Service) listShifts(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	days := defaultShiftDays
	if v := r.URL.Query().Get("days"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > maxShiftDays {
			httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "days must be 1 to 31.", false)
			return
		}
		days = n
	}
	if _, err := liveRider(r.Context(), s.Pool, actor); err != nil {
		s.fail(w, r, err)
		return
	}
	from, err := time.ParseInLocation("2006-01-02", IndiaDay(time.Now()), india)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	from = from.AddDate(0, 0, -(days - 1))
	rows, err := s.Pool.Query(r.Context(), `SELECT sh.id::text, sh.node_id::text, sh.started_at, sh.ended_at, sh.online_at, sh.planned_end_at,
			count(d.id), coalesce(sum(d.portions), 0)::int, round(avg(d.seconds))::int
		FROM shifts sh
		LEFT JOIN LATERAL (
			SELECT o.id, (SELECT coalesce(sum(i.qty), 0) FROM order_items i WHERE i.order_id = o.id) AS portions,
				extract(epoch FROM o.handed_over_at - f.rider_accepted_at) AS seconds
			FROM offers f JOIN orders o ON o.id = f.order_id
			WHERE f.rider_id = sh.rider_id AND f.state = 'accepted' AND o.handed_over_at IS NOT NULL AND f.rider_accepted_at IS NOT NULL
				AND f.rider_accepted_at >= sh.started_at AND f.rider_accepted_at < coalesce(sh.ended_at, 'infinity')
		) d ON true
		WHERE sh.rider_id = $1 AND sh.started_at >= $2
		GROUP BY sh.id ORDER BY sh.started_at DESC, sh.id`, actor.ID, from.UTC())
	if err != nil {
		s.fail(w, r, err)
		return
	}
	records, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (shiftRecord, error) {
		var rec shiftRecord
		var started time.Time
		var ended, online, planned *time.Time
		err := row.Scan(&rec.ID, &rec.NodeID, &started, &ended, &online, &planned, &rec.Orders, &rec.Portions, &rec.AvgDeliveryS)
		rec.StartedAt, rec.EndedAt, rec.OnlineAt, rec.PlannedEndAt = stamp(started), optional(ended), optional(online), optional(planned)
		return rec, err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if records == nil {
		records = []shiftRecord{}
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{"shifts": records, "server_time": serverTime()})
}
