package shifts

import (
	"testing"
	"time"
)

// The rider app's gaps: shift plans, the planned end and device on a shift, and quarantine.

func TestIndiaDayIsTheDayInIndia(t *testing.T) {
	for _, c := range []struct {
		at   time.Time
		want string
	}{
		{time.Date(2026, 11, 11, 18, 29, 0, 0, time.UTC), "2026-11-11"},
		{time.Date(2026, 11, 11, 18, 30, 0, 0, time.UTC), "2026-11-12"},
		{time.Date(2026, 11, 10, 20, 0, 0, 0, time.UTC), "2026-11-11"},
	} {
		if got := IndiaDay(c.at); got != c.want {
			t.Errorf("%v: %s, want %s", c.at, got, c.want)
		}
	}
}

func TestAPlanCanBeAnsweredUntilPackingOrTheStart(t *testing.T) {
	now := time.Date(2026, 11, 11, 4, 0, 0, 0, time.UTC)
	later, earlier := stamp(now.Add(time.Hour)), stamp(now.Add(-time.Minute))
	for _, c := range []struct {
		name    string
		plan    Plan
		answers bool
	}{
		{"before the start", Plan{StartsAt: later, Packing: "not_started"}, true},
		{"after the start", Plan{StartsAt: earlier, Packing: "not_started"}, false},
		{"packing", Plan{StartsAt: later, Packing: "packing"}, false},
		{"ready", Plan{StartsAt: later, Packing: "ready"}, false},
		{"bad time", Plan{StartsAt: "soon", Packing: "not_started"}, false},
	} {
		if got := planOpen(&c.plan, now); got != c.answers {
			t.Errorf("%s: %v", c.name, got)
		}
	}
}

func (f *fixture) plan(rider string, starts, ends time.Duration) string {
	f.t.Helper()
	return f.id(`INSERT INTO shift_plans (rider_id, day, node_id, starts_at, ends_at) VALUES ($1, $2::date, $3, now() + make_interval(secs => $4),
		now() + make_interval(secs => $5)) RETURNING id::text`, rider, IndiaDay(time.Now()), f.node, starts.Seconds(), ends.Seconds())
}

func TestTodaysPlanAndTheStockRequest(t *testing.T) {
	f := newFixture(t)
	rider, token := f.rider()
	code, out := f.send("GET", "/riders/me/shift-plan", token, "")
	if code != 200 || out["plan"] != nil {
		t.Fatalf("no plan: %d %v", code, out)
	}
	check(t, out, "ShiftPlanResponse")
	if code, out := f.send("POST", "/riders/me/shift-plan/reply", token, `{"reply":"coming"}`); code != 404 {
		t.Errorf("no plan to answer: %d %v", code, out)
	}
	id := f.plan(rider, time.Hour, 9*time.Hour)
	_, out = f.send("GET", "/riders/me/shift-plan", token, "")
	plan, _ := out["plan"].(map[string]any)
	check(t, plan, "ShiftPlan")
	if plan["id"] != id || plan["stock_reply"] != "pending" || plan["replied_at"] != nil || plan["packing"] != "not_started" || plan["node_id"] != f.node {
		t.Errorf("%v", plan)
	}
	if code, out := f.send("POST", "/riders/me/shift-plan/reply", token, `{"reply":"maybe"}`); code != 400 {
		t.Errorf("a bad answer: %d %v", code, out)
	}
	for _, reply := range []string{"not_today", "coming"} {
		code, out := f.send("POST", "/riders/me/shift-plan/reply", token, `{"reply":"`+reply+`"}`)
		if code != 200 {
			t.Fatalf("%s: %d %v", reply, code, out)
		}
		if p := out["plan"].(map[string]any); p["stock_reply"] != reply || p["replied_at"] == nil {
			t.Errorf("%s: %v", reply, p)
		}
	}
	if n := f.count("SELECT count(*) FROM audit_events WHERE action = 'shift_plan.replied' AND entity_id = $1", id); n != 2 {
		t.Errorf("%d audit rows", n)
	}
	// Once the hub packs, the answer stands.
	f.exec("UPDATE shift_plans SET packing = 'packing' WHERE id = $1", id)
	if code, out := f.send("POST", "/riders/me/shift-plan/reply", token, `{"reply":"not_today"}`); code != 409 || out["code"] != "shift_plan_closed" {
		t.Errorf("after packing: %d %v", code, out)
	}
	// The hub packs only for a rider who is coming.
	if _, err := f.s.Pool.Exec(t.Context(), "UPDATE shift_plans SET stock_reply = 'not_today' WHERE id = $1", id); err == nil {
		t.Error("the database let the hub pack for a rider not coming")
	}
}

func TestAPlanClosesAtTheShiftStart(t *testing.T) {
	f := newFixture(t)
	rider, token := f.rider()
	f.plan(rider, -time.Minute, 8*time.Hour)
	if code, out := f.send("POST", "/riders/me/shift-plan/reply", token, `{"reply":"coming"}`); code != 409 || out["code"] != "shift_plan_closed" {
		t.Errorf("%d %v", code, out)
	}
}

func TestAShiftKeepsItsPlannedEndAndDevice(t *testing.T) {
	f := newFixture(t)
	f.scooter("SC-1")
	f.scooter("SC-2")
	rider, token := f.rider()
	other, _ := f.rider()
	f.plan(rider, time.Hour, 9*time.Hour)
	mine := f.id("INSERT INTO devices (actor_type, actor_id, platform, push_token) VALUES ('rider', $1, 'android', 'tok-mine') RETURNING id::text", rider)
	theirs := f.id("INSERT INTO devices (actor_type, actor_id, platform, push_token) VALUES ('rider', $1, 'android', 'tok-theirs') RETURNING id::text", other)
	for _, body := range []string{`{"node_id":"` + f.node + `","device_id":"` + theirs + `"}`, `{"node_id":"` + f.node + `","device_id":"phone"}`} {
		if code, out := f.send("POST", "/riders/me/shifts/start", token, body); code != 400 {
			t.Errorf("%s: %d %v", body, code, out)
		}
	}
	if n := f.count("SELECT count(*) FROM shifts WHERE rider_id = $1", rider); n != 0 {
		t.Fatalf("a refused start made %d shifts", n)
	}
	code, out := f.send("POST", "/riders/me/shifts/start", token, `{"node_id":"`+f.node+`","device_id":"`+mine+`"}`)
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	sh := out["shift"].(map[string]any)
	check(t, sh, "Shift")
	end, err := time.Parse(time.RFC3339Nano, sh["planned_end_at"].(string))
	if err != nil || time.Until(end) < 8*time.Hour || time.Until(end) > 9*time.Hour {
		t.Errorf("planned_end_at %v %v", sh["planned_end_at"], err)
	}
	if sh["device_id"] != mine {
		t.Errorf("device_id %v", sh["device_id"])
	}
	// Starting tells the rider their spot, and queues the push.
	if n := f.count("SELECT count(*) FROM rider_notifications WHERE rider_id = $1 AND kind = 'spot_assigned' AND title = 'Spot assigned · Node A'", rider); n != 1 {
		t.Errorf("%d spot notifications", n)
	}
	if n := f.count("SELECT count(*) FROM outbox_events WHERE topic = 'push.rider' AND payload->>'rider_id' = $1 AND payload->>'kind' = 'notification'", rider); n != 1 {
		t.Errorf("%d pushes", n)
	}
	// With no plan and no device, both are null.
	f.send("POST", "/riders/me/shifts/end", token, "")
	f.exec("DELETE FROM shift_plans WHERE rider_id = $1", rider)
	_, out = f.start(token)
	if sh := out["shift"].(map[string]any); sh["planned_end_at"] != nil || sh["device_id"] != nil {
		t.Errorf("%v", sh)
	}
}

func TestQuarantiningALot(t *testing.T) {
	f := newFixture(t)
	scooter := f.scooter("SC-1")
	lot := f.lot("LOT-0001", 10, 48*time.Hour)
	other := f.lot("LOT-0002", 5, 48*time.Hour)
	rider, token := f.rider()
	path := "/riders/me/stock/" + lot + "/quarantine"
	if code, out := f.send("POST", path, token, `{"reason":"temperature"}`); code != 409 || out["code"] != "no_open_shift" {
		t.Errorf("no shift: %d %v", code, out)
	}
	f.start(token)
	f.send("POST", "/riders/me/stock/scan", token, `{"lot_code":"LOT-0001","scanned_at":"2026-11-07T10:00:00Z"}`)
	for _, body := range []string{`{}`, `{"reason":"bored"}`, `{"reason":"other","note":"` + longNote() + `"}`} {
		if code, out := f.send("POST", path, token, body); code != 400 {
			t.Errorf("%.40s: %d %v", body, code, out)
		}
	}
	if code, out := f.send("POST", "/riders/me/stock/"+other+"/quarantine", token, `{"reason":"damaged"}`); code != 409 || out["code"] != "lot_not_on_scooter" {
		t.Errorf("a lot not on the scooter: %d %v", code, out)
	}
	if code, _ := f.send("POST", "/riders/me/stock/00000000-0000-0000-0000-000000000000/quarantine", token, `{"reason":"damaged"}`); code != 404 {
		t.Errorf("no such lot: %d", code)
	}
	f.exec("UPDATE scooter_stock SET reserved = 1 WHERE lot_id = $1", lot)
	if code, out := f.send("POST", path, token, `{"reason":"temperature"}`); code != 409 || out["code"] != "lot_reserved" {
		t.Errorf("held for an order: %d %v", code, out)
	}
	f.exec("UPDATE scooter_stock SET reserved = 0 WHERE lot_id = $1", lot)
	code, out := f.send("POST", path, token, `{"reason":"temperature","note":"box was warm"}`)
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	check(t, out, "QuarantineResponse")
	if n := f.count("SELECT on_hand FROM scooter_stock WHERE scooter_id = $1 AND lot_id = $2", scooter, lot); n != 0 {
		t.Errorf("on hand %d", n)
	}
	if n := f.count("SELECT coalesce(sum(delta_on_hand), 0) FROM stock_ledger WHERE lot_id = $1", lot); n != 0 {
		t.Errorf("the ledger sums to %d", n)
	}
	if n := f.count(`SELECT count(*) FROM lots WHERE id = $1 AND status = 'quarantined' AND quarantine_reason = 'temperature'
		AND quarantine_note = 'box was warm' AND quarantined_by_rider = $2`, lot, rider); n != 1 {
		t.Error("the lot is not marked quarantined")
	}
	if _, out := f.send("GET", "/riders/me/stock", token, ""); len(out["lots"].([]any)) != 0 {
		t.Errorf("a quarantined lot is still listed: %v", out)
	}
	// Asking again answers the same; the lot can never be scanned again.
	if code, again := f.send("POST", path, token, `{"reason":"temperature"}`); code != 200 || again["quarantined_at"] != out["quarantined_at"] {
		t.Errorf("again: %d %v", code, again)
	}
	if n := f.count("SELECT count(*) FROM stock_ledger WHERE lot_id = $1 AND reason = 'quarantine'", lot); n != 1 {
		t.Errorf("%d quarantine rows", n)
	}
}

func longNote() string {
	b := make([]byte, maxQuarantineNote+1)
	for i := range b {
		b[i] = 'x'
	}
	return string(b)
}
