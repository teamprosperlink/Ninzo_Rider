package shifts

import (
	"context"
	"testing"
	"time"
)

func TestTimedRemindersGoOnce(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	svc := &Service{Pool: f.s.Pool, Log: quiet}
	waiting, _ := f.rider()
	answered, _ := f.rider()
	later, _ := f.rider()
	f.plan(waiting, 20*time.Minute, 8*time.Hour)
	f.plan(answered, 20*time.Minute, 8*time.Hour)
	f.exec("UPDATE shift_plans SET stock_reply = 'coming', replied_at = now() WHERE rider_id = $1", answered)
	f.plan(later, 3*time.Hour, 8*time.Hour)
	ending, token := f.rider()
	f.start(token)
	f.exec("UPDATE shifts SET planned_end_at = now() + interval '10 minutes' WHERE rider_id = $1", ending)

	ctx := context.Background()
	n, err := svc.Remind(ctx, time.Now())
	if err != nil || n != 2 {
		t.Fatalf("%d %v", n, err)
	}
	if c := f.count("SELECT count(*) FROM rider_notifications WHERE rider_id = $1 AND kind = 'stock_request'", waiting); c != 1 {
		t.Errorf("the rider who has not answered: %d", c)
	}
	if c := f.count("SELECT count(*) FROM rider_notifications WHERE rider_id = ANY($1::uuid[])", []string{answered, later}); c != 0 {
		t.Errorf("an answered or later plan was reminded: %d", c)
	}
	if c := f.count("SELECT count(*) FROM rider_notifications WHERE rider_id = $1 AND kind = 'shift_ending_soon'", ending); c != 1 {
		t.Errorf("ending soon: %d", c)
	}
	if n, err := svc.Remind(ctx, time.Now()); err != nil || n != 0 {
		t.Errorf("a second pass sent %d %v", n, err)
	}
}
