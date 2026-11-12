package shifts

import (
	"testing"
	"time"
)

// The rider's day on the server: going online, breaks, Add time and the shift history.

func TestGoingOnlineKeepsTheFirstTime(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	_, token := f.rider()
	if code, out := f.send("POST", "/riders/me/shifts/online", token, ""); code != 409 || out["code"] != "no_open_shift" {
		t.Errorf("no shift: %d %v", code, out)
	}
	f.start(token)
	code, out := f.send("POST", "/riders/me/shifts/online", token, "")
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	sh := out["shift"].(map[string]any)
	check(t, sh, "Shift")
	first := sh["online_at"]
	if first == nil || sh["break"] != nil {
		t.Errorf("%v", sh)
	}
	_, out = f.send("POST", "/riders/me/shifts/online", token, "")
	if out["shift"].(map[string]any)["online_at"] != first {
		t.Error("going online again moved the time")
	}
}

func TestABreakStopsOffers(t *testing.T) {
	f := newFixture(t)
	scooter := f.scooter("SC-1")
	rider, token := f.rider()
	f.start(token)
	for _, body := range []string{`{}`, `{"length_s":30}`, `{"length_s":7200}`} {
		if code, out := f.send("POST", "/riders/me/shifts/break", token, body); code != 400 {
			t.Errorf("%s: %d %v", body, code, out)
		}
	}
	code, out := f.send("POST", "/riders/me/shifts/break", token, `{"length_s":900}`)
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	brk := out["shift"].(map[string]any)["break"].(map[string]any)
	started, _ := time.Parse(time.RFC3339Nano, brk["started_at"].(string))
	ends, _ := time.Parse(time.RFC3339Nano, brk["ends_at"].(string))
	if ends.Sub(started) != 15*time.Minute {
		t.Errorf("%v", brk)
	}
	// A longer break counts from the same start.
	_, out = f.send("POST", "/riders/me/shifts/break", token, `{"length_s":1800}`)
	longer := out["shift"].(map[string]any)["break"].(map[string]any)
	ends2, _ := time.Parse(time.RFC3339Nano, longer["ends_at"].(string))
	if longer["started_at"] != brk["started_at"] || ends2.Sub(started) != 30*time.Minute {
		t.Errorf("extending: %v", longer)
	}
	// On a break the rider is not free, so no offer can go to them.
	if n := f.count(`SELECT count(*) FROM shifts sh WHERE sh.scooter_id = $1 AND sh.ended_at IS NULL AND sh.break_started_at IS NULL`, scooter); n != 0 {
		t.Error("the rider on a break still counts as free")
	}
	code, out = f.send("POST", "/riders/me/shifts/break/end", token, "")
	if code != 200 || out["shift"].(map[string]any)["break"] != nil {
		t.Fatalf("%d %v", code, out)
	}
	if n := f.count("SELECT count(*) FROM audit_events WHERE entity_type = 'shift' AND action IN ('shift.break', 'shift.break_ended') AND actor_id = $1", rider); n != 3 {
		t.Errorf("%d audit rows", n)
	}
	// Ending with no break answers the shift as it is.
	if code, _ := f.send("POST", "/riders/me/shifts/break/end", token, ""); code != 200 {
		t.Errorf("%d", code)
	}
}

func TestAddTimeMovesThePlannedEnd(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	_, token := f.rider()
	f.start(token)
	later := time.Now().Add(3 * time.Hour).UTC().Truncate(time.Second)
	code, out := f.send("POST", "/riders/me/shifts/planned-end", token, `{"planned_end_at":"`+later.Format(time.RFC3339)+`"}`)
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	got, _ := time.Parse(time.RFC3339Nano, out["shift"].(map[string]any)["planned_end_at"].(string))
	if !got.Equal(later) {
		t.Errorf("%v", got)
	}
	for _, at := range []time.Time{time.Now().Add(-time.Minute), time.Now().Add(17 * time.Hour)} {
		if code, out := f.send("POST", "/riders/me/shifts/planned-end", token, `{"planned_end_at":"`+at.UTC().Format(time.RFC3339)+`"}`); code != 400 {
			t.Errorf("%v: %d %v", at, code, out)
		}
	}
}

func TestTheShiftHistory(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	rider, token := f.rider()
	code, out := f.send("GET", "/riders/me/shifts", token, "")
	if code != 200 || len(out["shifts"].([]any)) != 0 {
		t.Fatalf("%d %v", code, out)
	}
	check(t, out, "ShiftHistory")
	for _, q := range []string{"?days=0", "?days=40", "?days=x"} {
		if code, _ := f.send("GET", "/riders/me/shifts"+q, token, ""); code != 400 {
			t.Errorf("%s: %d", q, code)
		}
	}
	f.start(token)
	f.send("POST", "/riders/me/shifts/online", token, "")
	f.send("POST", "/riders/me/shifts/end", token, "")
	// A shift from long ago is outside the window.
	f.exec(`INSERT INTO shifts (rider_id, node_id, scooter_id, started_at, ended_at)
		SELECT rider_id, node_id, scooter_id, now() - interval '40 days', now() - interval '39 days' FROM shifts WHERE rider_id = $1`, rider)
	_, out = f.send("GET", "/riders/me/shifts", token, "")
	shifts := out["shifts"].([]any)
	if len(shifts) != 1 {
		t.Fatalf("%v", out)
	}
	rec := shifts[0].(map[string]any)
	check(t, rec, "ShiftRecord")
	if rec["online_at"] == nil || rec["ended_at"] == nil || rec["orders"] != float64(0) || rec["avg_delivery_s"] != nil {
		t.Errorf("%v", rec)
	}
}

func TestTheChecklistIsKeptWithTheShift(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	rider, token := f.rider()
	for _, list := range []string{`["helmet","helmet"]`, `["wings"]`} {
		if code, out := f.send("POST", "/riders/me/shifts/start", token, `{"node_id":"`+f.node+`","checklist":`+list+`}`); code != 400 {
			t.Errorf("%s: %d %v", list, code, out)
		}
	}
	if code, out := f.send("POST", "/riders/me/shifts/start", token, `{"node_id":"`+f.node+`","checklist":["helmet","phoneCharged","scooterBattery","location","insulatedBox","scooterClean"]}`); code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	if n := f.count("SELECT cardinality(checklist) FROM shifts WHERE rider_id = $1", rider); n != 6 {
		t.Errorf("%d items kept", n)
	}
}
