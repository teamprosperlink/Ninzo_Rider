package shifts

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/audit"
	"github.com/teamprosperlink/Ninzo_backend/internal/identity"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/idempotency"
)

// mountPlans adds getShiftPlan, replyToShiftPlan and quarantineLot.
func (s *Service) mountPlans(g chi.Router, idem func(http.Handler) http.Handler) {
	g.Get("/riders/me/shift-plan", s.getShiftPlan)
	g.With(idem).Post("/riders/me/shift-plan/reply", s.replyToShiftPlan)
	g.With(idem).Post("/riders/me/stock/{lot_id}/quarantine", s.quarantineLot)
}

// Plan is one day's shift plan as the rider app reads it.
type Plan struct {
	ID         string  `json:"id"`
	Date       string  `json:"date"`
	NodeID     *string `json:"node_id"`
	StartsAt   string  `json:"starts_at"`
	EndsAt     string  `json:"ends_at"`
	StockReply string  `json:"stock_reply"`
	RepliedAt  *string `json:"replied_at"`
	Packing    string  `json:"packing"`
	ReadyAt    *string `json:"ready_at"`
}

func optional(t *time.Time) *string {
	if t == nil {
		return nil
	}
	v := stamp(*t)
	return &v
}

// ReadPlan reads the rider's plan for day (YYYY-MM-DD). lock takes its row lock, for a change. It
// returns nil when there is none.
func ReadPlan(ctx context.Context, q querier, riderID, day string, lock bool) (*Plan, error) {
	query := `SELECT id::text, day::text, node_id::text, starts_at, ends_at, stock_reply, replied_at, packing, ready_at
		FROM shift_plans WHERE rider_id = $1 AND day = $2::date`
	if lock {
		query += " FOR UPDATE"
	}
	var p Plan
	var starts, ends time.Time
	var replied, ready *time.Time
	err := q.QueryRow(ctx, query, riderID, day).Scan(&p.ID, &p.Date, &p.NodeID, &starts, &ends, &p.StockReply, &replied, &p.Packing, &ready)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	p.StartsAt, p.EndsAt, p.RepliedAt, p.ReadyAt = stamp(starts), stamp(ends), optional(replied), optional(ready)
	return &p, nil
}

// planOpen says whether the rider may still answer: not once the hub has started packing, and not
// after the shift's start.
func planOpen(p *Plan, now time.Time) bool {
	starts, err := time.Parse(time.RFC3339Nano, p.StartsAt)
	return err == nil && p.Packing == "not_started" && now.Before(starts)
}

func (s *Service) getShiftPlan(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	if _, err := liveRider(r.Context(), s.Pool, actor); err != nil {
		s.fail(w, r, err)
		return
	}
	p, err := ReadPlan(r.Context(), s.Pool, actor.ID, IndiaDay(time.Now()), false)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	var plan any // A typed nil would not be JSON null.
	if p != nil {
		plan = p
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{"plan": plan, "server_time": serverTime()})
}

func (s *Service) replyToShiftPlan(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	var body struct {
		Reply string `json:"reply"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || (body.Reply != "coming" && body.Reply != "not_today") {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "reply must be coming or not_today.", false)
		return
	}
	var reply map[string]any
	err := database.InTx(r.Context(), s.Pool, func(tx pgx.Tx) error {
		if err := identity.CheckSession(r.Context(), tx, actor); err != nil {
			return err
		}
		if _, err := readRider(r.Context(), tx, actor.ID); err != nil {
			return err
		}
		now := time.Now()
		p, err := ReadPlan(r.Context(), tx, actor.ID, IndiaDay(now), true)
		if err != nil {
			return err
		}
		if p == nil {
			return errNotFound
		}
		if !planOpen(p, now) {
			return refuse("shift_plan_closed", "The hub has started packing, or the shift has started.")
		}
		before := p.StockReply
		if _, err := tx.Exec(r.Context(), "UPDATE shift_plans SET stock_reply = $2, replied_at = now(), updated_at = now() WHERE id = $1",
			p.ID, body.Reply); err != nil {
			return err
		}
		if err := bump(r.Context(), tx, actor.ID); err != nil {
			return err
		}
		if err := audit.Record(r.Context(), tx, audit.Event{
			ActorType: identity.TypeRider, ActorID: actor.ID, Action: "shift_plan.replied", EntityType: "shift_plan", EntityID: p.ID,
			Before: map[string]any{"stock_reply": before}, After: map[string]any{"stock_reply": body.Reply},
		}); err != nil {
			return err
		}
		if p, err = ReadPlan(r.Context(), tx, actor.ID, p.Date, false); err != nil {
			return err
		}
		reply = map[string]any{"plan": p, "server_time": serverTime()}
		return idempotency.Save(r.Context(), tx, http.StatusOK, reply)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpserver.WriteJSON(w, http.StatusOK, reply)
}

var quarantineReasons = map[string]bool{"temperature": true, "damaged": true, "expired": true, "other": true}

const maxQuarantineNote = 500

// quarantineLot takes a whole lot off the rider's scooter. The stock leaves through the ledger, so
// scooter_stock can still be rebuilt from it, and the lot can never be scanned again.
func (s *Service) quarantineLot(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	lot := chi.URLParam(r, "lot_id")
	if !idPattern.MatchString(lot) {
		s.fail(w, r, errNotFound)
		return
	}
	var body struct {
		Reason string  `json:"reason"`
		Note   *string `json:"note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || !quarantineReasons[body.Reason] {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "reason must be temperature, damaged, expired or other.", false)
		return
	}
	var note *string
	if body.Note != nil {
		n := strings.TrimSpace(*body.Note)
		if utf8.RuneCountInString(n) > maxQuarantineNote || !utf8.ValidString(n) {
			httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "The note is too long.", false)
			return
		}
		if n != "" {
			note = &n
		}
	}
	var reply map[string]any
	err := database.InTx(r.Context(), s.Pool, func(tx pgx.Tx) error {
		if err := identity.CheckSession(r.Context(), tx, actor); err != nil {
			return err
		}
		if _, err := readRider(r.Context(), tx, actor.ID); err != nil {
			return err
		}
		_, scooter, open, err := openShift(r.Context(), tx, actor.ID)
		if err != nil {
			return err
		}
		if !open {
			return refuse("no_open_shift", "Start a shift first.")
		}
		// The lot first, then its stock row, the order ScanTx takes them in.
		var status string
		var by *string
		var at *time.Time
		err = tx.QueryRow(r.Context(), "SELECT status, quarantined_by_rider::text, quarantined_at FROM lots WHERE id = $1 FOR UPDATE", lot).Scan(&status, &by, &at)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return err
		}
		if status == "quarantined" {
			if by != nil && *by == actor.ID && at != nil {
				reply = map[string]any{"lot_id": lot, "quarantined_at": stamp(*at), "server_time": serverTime()}
				return idempotency.Save(r.Context(), tx, http.StatusOK, reply)
			}
			return refuse("lot_not_on_scooter", "This lot is not on your scooter.")
		}
		var onHand, reserved int
		err = tx.QueryRow(r.Context(), "SELECT on_hand, reserved FROM scooter_stock WHERE scooter_id = $1 AND lot_id = $2 FOR UPDATE",
			scooter, lot).Scan(&onHand, &reserved)
		if errors.Is(err, pgx.ErrNoRows) {
			return refuse("lot_not_on_scooter", "This lot is not on your scooter.")
		}
		if err != nil {
			return err
		}
		if reserved > 0 {
			return refuse("lot_reserved", "Part of this lot is held for an order.")
		}
		if onHand > 0 {
			if _, err := tx.Exec(r.Context(), "UPDATE scooter_stock SET on_hand = 0, updated_at = now() WHERE scooter_id = $1 AND lot_id = $2", scooter, lot); err != nil {
				return err
			}
			if _, err := tx.Exec(r.Context(), `INSERT INTO stock_ledger (scooter_id, lot_id, delta_on_hand, reason, actor_type, actor_id)
				VALUES ($1, $2, $3, 'quarantine', 'rider', $4)`, scooter, lot, -onHand, actor.ID); err != nil {
				return err
			}
		}
		var quarantined time.Time
		if err := tx.QueryRow(r.Context(), `UPDATE lots SET status = 'quarantined', quarantine_reason = $2, quarantine_note = $3,
				quarantined_by_rider = $4, quarantined_at = now() WHERE id = $1 RETURNING quarantined_at`,
			lot, body.Reason, note, actor.ID).Scan(&quarantined); err != nil {
			return err
		}
		if err := bump(r.Context(), tx, actor.ID); err != nil {
			return err
		}
		if err := audit.Record(r.Context(), tx, audit.Event{
			ActorType: identity.TypeRider, ActorID: actor.ID, Action: "lot.quarantined", EntityType: "lot", EntityID: lot,
			After: map[string]any{"reason": body.Reason, "qty": onHand},
		}); err != nil {
			return err
		}
		reply = map[string]any{"lot_id": lot, "quarantined_at": stamp(quarantined), "server_time": serverTime()}
		return idempotency.Save(r.Context(), tx, http.StatusOK, reply)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpserver.WriteJSON(w, http.StatusOK, reply)
}
