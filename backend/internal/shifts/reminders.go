package shifts

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/ridernotes"
)

const (
	// stockReminderBefore is how long before a planned start a rider who has not answered the
	// stock request is reminded.
	stockReminderBefore = 30 * time.Minute
	// endingSoonBefore is how long before the planned end "Shift ending soon" goes.
	endingSoonBefore = 15 * time.Minute
)

// RunReminders sends the timed reminders every so often until ctx ends: the stock request to a
// rider who has not answered, and "Shift ending soon". Each goes once.
func (s *Service) RunReminders(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		if _, err := s.Remind(ctx, time.Now()); err != nil && ctx.Err() == nil {
			s.Log.Error("shifts: reminders failed", "error", err.Error())
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

// Remind sends what is due at now, and says how many went.
func (s *Service) Remind(ctx context.Context, now time.Time) (int, error) {
	sent := 0
	err := database.InTx(ctx, s.Pool, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `UPDATE shift_plans SET reminded_at = $1, updated_at = now()
			WHERE stock_reply = 'pending' AND reminded_at IS NULL AND starts_at > $1 AND starts_at <= $1 + make_interval(secs => $2)
			RETURNING rider_id::text, starts_at`, now, stockReminderBefore.Seconds())
		if err != nil {
			return err
		}
		type due struct {
			rider string
			at    time.Time
		}
		plans, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (due, error) {
			var d due
			return d, r.Scan(&d.rider, &d.at)
		})
		if err != nil {
			return err
		}
		for _, p := range plans {
			if err := ridernotes.Add(ctx, tx, p.rider, ridernotes.StockRequest, "Still coming in today?",
				"Your shift starts at "+p.at.In(india).Format("3:04 PM")+". Tell the hub, or it won't pack your stock."); err != nil {
				return err
			}
		}
		rows, err = tx.Query(ctx, `UPDATE shifts SET ending_soon_sent_at = $1
			WHERE ended_at IS NULL AND ending_soon_sent_at IS NULL AND planned_end_at > $1 AND planned_end_at <= $1 + make_interval(secs => $2)
			RETURNING rider_id::text, planned_end_at`, now, endingSoonBefore.Seconds())
		if err != nil {
			return err
		}
		ending, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (due, error) {
			var d due
			return d, r.Scan(&d.rider, &d.at)
		})
		if err != nil {
			return err
		}
		for _, e := range ending {
			if err := ridernotes.Add(ctx, tx, e.rider, ridernotes.ShiftEndingSoon, "Shift ending soon",
				"Your shift ends at "+e.at.In(india).Format("3:04 PM")+". Add time if you want to keep riding."); err != nil {
				return err
			}
		}
		sent = len(plans) + len(ending)
		return nil
	})
	return sent, err
}
