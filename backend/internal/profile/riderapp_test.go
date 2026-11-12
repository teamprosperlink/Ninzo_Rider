package profile

import (
	"strings"
	"testing"
)

func TestTheRiderAppGetsItsSettingsFromTheZone(t *testing.T) {
	f := newFixture(t)
	id, token := f.newRider("+919800000401")
	code, out := f.send(f.rider, "GET", "/riders/me/settings", token, "")
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	s := out["settings"].(map[string]any)
	checkFields(t, s, "rider", "RiderSettings")
	// The global values from the migrations.
	for name, want := range map[string]float64{"timer_length_s": 90, "arrive_m": 100, "almost_there_m": 300, "away_from_spot_m": 150,
		"scooter_capacity_qty": 8, "min_phone_battery_pct": 50, "min_scooter_battery_pct": 40, "low_scooter_battery_pct": 20} {
		if s[name] != want {
			t.Errorf("%s = %v, want %v", name, s[name], want)
		}
	}
	if len(s["checklist"].([]any)) != 6 || len(s["problem_types"].([]any)) != 5 || len(s["break_options_s"].([]any)) != 4 {
		t.Errorf("%v", s)
	}
	// A zone's own value wins.
	var zone string
	if err := f.s.Pool.QueryRow(t.Context(), "INSERT INTO zones (name, city, status) VALUES ('Z', 'Bengaluru', 'active') RETURNING id::text").Scan(&zone); err != nil {
		t.Fatal(err)
	}
	f.exec("UPDATE riders SET zone_id = $2 WHERE id = $1", id, zone)
	f.exec(`INSERT INTO zone_settings (zone_id, version, rider_arrive_m, reason, created_by) VALUES ($1, 1, 60, 'smaller hubs', 'test')`, zone)
	_, out = f.send(f.rider, "GET", "/riders/me/settings", token, "")
	if s := out["settings"].(map[string]any); s["arrive_m"] != float64(60) || s["timer_length_s"] != float64(90) {
		t.Errorf("zone override: %v", s)
	}
}

func TestTheHelpCentreAndFeedback(t *testing.T) {
	f := newFixture(t)
	id, token := f.newRider("+919800000402")
	code, out := f.send(f.rider, "GET", "/riders/me/help", token, "")
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	faq := out["faq"].([]any)
	if len(faq) != 6 || faq[0].(map[string]any)["question"] != "How do I go online?" || faq[0].(map[string]any)["answer"] == "" {
		t.Errorf("%v", faq)
	}
	f.exec("UPDATE help_articles SET status = 'hidden' WHERE sort_order = 1")
	if _, out := f.send(f.rider, "GET", "/riders/me/help", token, ""); len(out["faq"].([]any)) != 5 {
		t.Error("a hidden article is still shown")
	}
	for _, body := range []string{`{}`, `{"message":"  "}`, `{"message":"` + strings.Repeat("x", 2001) + `"}`} {
		if code, _ := f.send(f.rider, "POST", "/riders/me/feedback", token, body); code != 400 {
			t.Errorf("%.30s: %d", body, code)
		}
	}
	code, out = f.send(f.rider, "POST", "/riders/me/feedback", token, `{"message":"The map is hard to read at night."}`)
	if code != 201 || out["feedback_id"] == nil {
		t.Fatalf("%d %v", code, out)
	}
	if n := f.count("SELECT count(*) FROM rider_feedback WHERE rider_id = $1 AND message = 'The map is hard to read at night.'", id); n != 1 {
		t.Errorf("%d", n)
	}
}
