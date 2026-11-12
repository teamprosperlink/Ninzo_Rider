package profile

import (
	"encoding/base64"
	"testing"
)

func jpeg(n int) string {
	b := make([]byte, n)
	copy(b, []byte{0xFF, 0xD8, 0xFF, 0xE0})
	return base64.StdEncoding.EncodeToString(b)
}

func TestARiderUploadsDocumentPhotos(t *testing.T) {
	f := newFixture(t)
	id, token := f.newRider("+919800000301")
	code, out := f.send(f.rider, "GET", "/riders/me", token, "")
	if code != 200 || out["rider"].(map[string]any)["phone"] != "+919800000301" {
		t.Fatalf("the phone: %d %v", code, out)
	}
	code, out = f.send(f.rider, "GET", "/riders/me/documents", token, "")
	if code != 200 || len(out["documents"].([]any)) != 0 {
		t.Fatalf("%d %v", code, out)
	}
	body := `{"document":"aadhaar","side":"front","content_type":"image/jpeg","data_base64":"` + jpeg(1000) + `"}`
	code, out = f.send(f.rider, "POST", "/riders/me/documents", token, body)
	if code != 201 {
		t.Fatalf("%d %v", code, out)
	}
	checkFields(t, out["document"].(map[string]any), "rider", "RiderDocumentInfo")
	// A new photo replaces the one before.
	f.send(f.rider, "POST", "/riders/me/documents", token, `{"document":"aadhaar","side":"front","content_type":"image/jpeg","data_base64":"`+jpeg(2000)+`"}`)
	_, out = f.send(f.rider, "GET", "/riders/me/documents", token, "")
	docs := out["documents"].([]any)
	if len(docs) != 1 || docs[0].(map[string]any)["size_bytes"] != float64(2000) {
		t.Errorf("%v", docs)
	}
	for name, bad := range map[string]string{
		"not a photo": `{"document":"aadhaar","side":"front","content_type":"image/jpeg","data_base64":"` + base64.StdEncoding.EncodeToString([]byte("hello")) + `"}`,
		"bad kind":    `{"document":"passport","side":"front","content_type":"image/jpeg","data_base64":"` + jpeg(10) + `"}`,
		"bad base64":  `{"document":"aadhaar","side":"front","content_type":"image/jpeg","data_base64":"%%%"}`,
		"a pdf":       `{"document":"aadhaar","side":"front","content_type":"application/pdf","data_base64":"` + jpeg(10) + `"}`,
		"over 700 KB": `{"document":"aadhaar","side":"back","content_type":"image/jpeg","data_base64":"` + jpeg(700001) + `"}`,
		"no side":     `{"document":"aadhaar","content_type":"image/jpeg","data_base64":"` + jpeg(10) + `"}`,
	} {
		if code, out := f.send(f.rider, "POST", "/riders/me/documents", token, bad); code != 400 {
			t.Errorf("%s: %d %v", name, code, out)
		}
	}
	// The photo is never in the audit trail or a stored reply.
	if n := f.count("SELECT count(*) FROM audit_events WHERE action = 'rider.document_uploaded' AND entity_id = $1", id); n != 2 {
		t.Errorf("%d audit rows", n)
	}
	if n := f.count("SELECT count(*) FROM audit_events WHERE length(after::text) > 500"); n != 0 {
		t.Error("an audit row holds the photo")
	}
	// Once verified, nothing more is taken.
	f.exec("INSERT INTO rider_verifications (rider_id, status, method) VALUES ($1, 'verified', 'manual_upload')", id)
	if code, out := f.send(f.rider, "POST", "/riders/me/documents", token, body); code != 409 || out["code"] != "already_verified" {
		t.Errorf("verified: %d %v", code, out)
	}
}
