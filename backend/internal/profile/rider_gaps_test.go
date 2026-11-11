package profile

import (
	"strings"
	"testing"
)

// The rider app's gaps: the rider's own details, and what they were told.

func TestAnAreaMustBeARealPlace(t *testing.T) {
	lat, lng, far, city, long := 12.93, 77.62, 91.0, "Bengaluru", strings.Repeat("x", maxCityRunes+1)
	for _, c := range []struct {
		name string
		area riderArea
		ok   bool
	}{
		{"a junction", riderArea{Name: " Silk Board ", City: &city, Lat: &lat, Lng: &lng}, true},
		{"no city", riderArea{Name: "Silk Board", Lat: &lat, Lng: &lng}, true},
		{"no name", riderArea{Name: "  ", Lat: &lat, Lng: &lng}, false},
		{"no place", riderArea{Name: "Silk Board"}, false},
		{"off the map", riderArea{Name: "Silk Board", Lat: &far, Lng: &lng}, false},
		{"a long city", riderArea{Name: "Silk Board", City: &long, Lat: &lat, Lng: &lng}, false},
		{"a hidden control", riderArea{Name: "Silk‮Board", Lat: &lat, Lng: &lng}, false},
	} {
		name, _, _, _, ok := cleanArea(c.area)
		if ok != c.ok {
			t.Errorf("%s: %v", c.name, ok)
		}
		if ok && name != strings.TrimSpace(c.area.Name) {
			t.Errorf("%s: the name was not trimmed: %q", c.name, name)
		}
	}
}

func TestARiderChangesTheirOwnDetails(t *testing.T) {
	f := newFixture(t)
	id, token := f.newRider("+919800000201")
	code, out := f.send(f.rider, "GET", "/riders/me", token, "")
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	if r := out["rider"].(map[string]any); r["email"] != nil || r["area"] != nil {
		t.Errorf("nothing given yet: %v", r)
	}
	code, out = f.send(f.rider, "PATCH", "/riders/me", token,
		`{"name":" Ravi Kumar ","email":"ravi@example.com","area":{"name":"Koramangala","city":"Bengaluru","lat":12.93,"lng":77.62}}`)
	if code != 200 {
		t.Fatalf("%d %v", code, out)
	}
	r := out["rider"].(map[string]any)
	checkFields(t, r, "rider", "Rider")
	area, _ := r["area"].(map[string]any)
	if r["id"] != id || r["name"] != "Ravi Kumar" || r["email"] != "ravi@example.com" || area["name"] != "Koramangala" || area["lat"] != 12.93 {
		t.Errorf("%v", r)
	}
	// Each can change alone; null clears the email and the area.
	_, out = f.send(f.rider, "PATCH", "/riders/me", token, `{"email":null,"area":null}`)
	if r := out["rider"].(map[string]any); r["name"] != "Ravi Kumar" || r["email"] != nil || r["area"] != nil {
		t.Errorf("clearing: %v", r)
	}
	for _, body := range []string{`{}`, `{"name":""}`, `{"name":null}`, `{"email":"not an email"}`, `{"area":{"name":"X"}}`, `not json`} {
		if code, out := f.send(f.rider, "PATCH", "/riders/me", token, body); code != 400 {
			t.Errorf("%s: %d %v", body, code, out)
		}
	}
	if n := f.count("SELECT count(*) FROM audit_events WHERE action = 'rider.updated' AND entity_id = $1", id); n != 2 {
		t.Errorf("%d audit rows", n)
	}
	if n := f.count("SELECT count(*) FROM audit_events WHERE after::text LIKE '%Ravi%' OR after::text LIKE '%Koramangala%' OR after::text LIKE '%example.com%'"); n != 0 {
		t.Error("personal data was kept in the audit log for good")
	}
	// A suspended rider can read, not change.
	f.exec("UPDATE riders SET status = 'suspended' WHERE id = $1", id)
	if code, out := f.send(f.rider, "PATCH", "/riders/me", token, `{"name":"Someone"}`); code != 403 {
		t.Errorf("suspended: %d %v", code, out)
	}
}

func TestARiderListsWhatTheyWereTold(t *testing.T) {
	f := newFixture(t)
	id, token := f.newRider("+919800000202")
	other, _ := f.newRider("+919800000203")
	code, out := f.send(f.rider, "GET", "/riders/me/notifications", token, "")
	if code != 200 || len(out["notifications"].([]any)) != 0 {
		t.Fatalf("%d %v", code, out)
	}
	f.exec(`INSERT INTO rider_notifications (rider_id, kind, title, body, created_at) VALUES
		($1, 'spot_assigned', 'Spot assigned · Node A', 'Head there.', now() - interval '1 hour'),
		($1, 'orders_waiting', 'Orders waiting at Node B', 'Paid time.', now()),
		($2, 'spot_assigned', 'Not yours', '', now())`, id, other)
	_, out = f.send(f.rider, "GET", "/riders/me/notifications", token, "")
	notes := out["notifications"].([]any)
	if len(notes) != 2 {
		t.Fatalf("%v", out)
	}
	first := notes[0].(map[string]any)
	checkFields(t, first, "rider", "RiderNotification")
	if first["kind"] != "orders_waiting" || notes[1].(map[string]any)["title"] != "Spot assigned · Node A" {
		t.Errorf("newest first: %v", notes)
	}
	f.exec("INSERT INTO rider_notifications (rider_id, kind, title, body) SELECT $1, 'spot_assigned', 'n' || g, '' FROM generate_series(1, 60) g", id)
	if _, out := f.send(f.rider, "GET", "/riders/me/notifications", token, ""); len(out["notifications"].([]any)) != maxNotifications {
		t.Errorf("at most %d: %d", maxNotifications, len(out["notifications"].([]any)))
	}
}
