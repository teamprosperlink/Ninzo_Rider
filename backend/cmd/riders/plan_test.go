package main

import (
	"bytes"
	"context"
	"testing"
	"time"

	"github.com/teamprosperlink/Ninzo_backend/internal/platform/dbtest"
)

func TestBadPlanArgumentsTouchNothing(t *testing.T) {
	phone, hub := "+919800000001", "00000000-0000-0000-0000-000000000001"
	for _, args := range [][]string{
		{"-local", "plan", "-phone", phone, "-date", "2026-11-12", "-start", "09:00", "-end", "17:00"},
		{"-local", "plan", "-phone", phone, "-date", "12-11-2026", "-start", "09:00", "-end", "17:00", "-by", "o"},
		{"-local", "plan", "-phone", phone, "-date", "2026-11-12", "-start", "9am", "-end", "17:00", "-by", "o"},
		{"-local", "plan", "-phone", phone, "-date", "2026-11-12", "-start", "09:00", "-end", "17:00", "-node", "n7", "-by", "o"},
		{"-local", "plan", "-phone", phone, "-date", "2026-11-12", "-start", "06:00", "-end", "23:00", "-by", "o"},
		{"-local", "packing", "-phone", phone, "-date", "2026-11-12", "-state", "done", "-by", "o"},
		{"-local", "packing", "-phone", phone, "-date", "2026-11-12", "-state", "packing", "-ready-in", "-5m", "-by", "o"},
		{"-local", "hub-phone", "-hub", "hub_2", "-phone", phone, "-by", "o"},
		{"-local", "hub-phone", "-hub", hub, "-phone", "12345", "-by", "o"},
	} {
		if err := run(context.Background(), args, env(map[string]string{"DATABASE_URL": "postgres://u:p@localhost/db"}), &bytes.Buffer{}); err == nil {
			t.Errorf("%v was accepted", args)
		}
	}
}

func TestPlanTimesAreIndiaTime(t *testing.T) {
	s, e, err := planTimes("2026-11-12", "09:00", "17:30")
	if err != nil || !s.Equal(time.Date(2026, 11, 12, 3, 30, 0, 0, time.UTC)) || !e.Equal(time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)) {
		t.Errorf("%v %v %v", s, e, err)
	}
	// A night shift ends the next day.
	s, e, err = planTimes("2026-11-12", "20:00", "02:00")
	if err != nil || e.Sub(s) != 6*time.Hour {
		t.Errorf("%v %v %v", s, e, err)
	}
}

func TestPlanningAShiftAndPacking(t *testing.T) {
	pool := dbtest.Fresh(t)
	ctx := context.Background()
	url := pool.Config().ConnString()
	exec := func(sql string, args ...any) string {
		t.Helper()
		var id string
		if err := pool.QueryRow(ctx, sql, args...).Scan(&id); err != nil {
			t.Fatal(err)
		}
		return id
	}
	count := func(sql string, args ...any) int {
		t.Helper()
		var n int
		if err := pool.QueryRow(ctx, sql, args...).Scan(&n); err != nil {
			t.Fatal(err)
		}
		return n
	}
	zone := exec("INSERT INTO zones (name, city) VALUES ('Z', 'Bengaluru') RETURNING id::text")
	node := exec("INSERT INTO staging_nodes (zone_id, name, lat, lng, capacity) VALUES ($1, 'Node A', 12.93, 77.62, 4) RETURNING id::text", zone)
	hub := exec("INSERT INTO hubs (zone_id, name, lat, lng) VALUES ($1, 'Hub 2', 12.94, 77.61) RETURNING id::text", zone)
	person := exec("INSERT INTO people (phone) VALUES ('+919800000001') RETURNING id::text")
	rider := exec("INSERT INTO riders (person_id, status, zone_id) VALUES ($1, 'active', $2) RETURNING id::text", person, zone)
	do := func(args ...string) error {
		return run(ctx, append([]string{"-local"}, args...), env(map[string]string{"DATABASE_URL": url}), &bytes.Buffer{})
	}
	if err := do("plan", "-phone", "+919800000001", "-date", "2026-11-12", "-start", "09:00", "-end", "17:00", "-node", node, "-by", "owner"); err != nil {
		t.Fatal(err)
	}
	if n := count(`SELECT count(*) FROM shift_plans WHERE rider_id = $1 AND day = '2026-11-12' AND node_id = $2
		AND starts_at = '2026-11-12T03:30:00Z' AND stock_reply = 'pending'`, rider, node); n != 1 {
		t.Error("no plan")
	}
	if n := count("SELECT count(*) FROM rider_notifications WHERE rider_id = $1 AND kind = 'stock_request'", rider); n != 1 {
		t.Errorf("%d stock requests", n)
	}
	// Nothing is packed for a rider who has not said they are coming.
	if err := do("packing", "-phone", "+919800000001", "-date", "2026-11-12", "-state", "packing", "-by", "hub"); err == nil {
		t.Error("packed for a rider not coming")
	}
	if _, err := pool.Exec(ctx, "UPDATE shift_plans SET stock_reply = 'coming', replied_at = now() WHERE rider_id = $1", rider); err != nil {
		t.Fatal(err)
	}
	if err := do("packing", "-phone", "+919800000001", "-date", "2026-11-12", "-state", "packing", "-ready-in", "20m", "-by", "hub"); err != nil {
		t.Fatal(err)
	}
	if err := do("packing", "-phone", "+919800000001", "-date", "2026-11-12", "-state", "ready", "-by", "hub"); err != nil {
		t.Fatal(err)
	}
	if n := count("SELECT count(*) FROM shift_plans WHERE rider_id = $1 AND packing = 'ready' AND ready_at IS NOT NULL", rider); n != 1 {
		t.Error("not ready")
	}
	if n := count("SELECT count(*) FROM rider_notifications WHERE rider_id = $1 AND kind = 'stock_ready'", rider); n != 1 {
		t.Errorf("%d stock ready notifications", n)
	}
	if err := do("packing", "-phone", "+919800000001", "-date", "2026-11-12", "-state", "packing", "-by", "hub"); err == nil {
		t.Error("ready went back to packing")
	}
	if err := do("hub-phone", "-hub", hub, "-phone", "+919800000100", "-by", "owner"); err != nil {
		t.Fatal(err)
	}
	if n := count("SELECT count(*) FROM hubs WHERE id = $1 AND manager_phone = '+919800000100'", hub); n != 1 {
		t.Error("no manager phone")
	}
	if n := count("SELECT count(*) FROM audit_events WHERE after::text LIKE '%9800000100%' OR reason LIKE '%9800000100%'"); n != 0 {
		t.Error("the number was kept in the audit log for good")
	}
}
