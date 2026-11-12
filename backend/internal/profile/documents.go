package profile

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/audit"
	"github.com/teamprosperlink/Ninzo_backend/internal/identity"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/httpserver"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/idempotency"
)

// maxDocumentBytes is one photo once decoded. It keeps the base64 body inside the request limit.
const maxDocumentBytes = 700000

var (
	documentKinds = map[string]bool{"aadhaar": true, "drivingLicence": true, "vehicleRc": true, "selfie": true, "bank": true}
	documentSides = map[string]bool{"front": true, "back": true, "photo": true}
	// The first bytes of each kind of image the app may send.
	imageMagic = map[string][]byte{
		"image/jpeg": {0xFF, 0xD8, 0xFF},
		"image/png":  {0x89, 'P', 'N', 'G'},
		"image/webp": []byte("RIFF"),
	}
)

func documentInfo(document, side, contentType string, size int, at time.Time) map[string]any {
	return map[string]any{"document": document, "side": side, "content_type": contentType, "size_bytes": size,
		"uploaded_at": at.UTC().Format(time.RFC3339Nano)}
}

// listDocuments is what the rider uploaded, without the photos.
func (s *Service) listDocuments(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	if !s.requireLive(w, r, actor) {
		return
	}
	if _, err := readRider(r.Context(), s.Pool, actor.ID); err != nil {
		s.fail(w, r, err)
		return
	}
	rows, err := s.Pool.Query(r.Context(), `SELECT document, side, content_type, size_bytes, created_at FROM rider_documents
		WHERE rider_id = $1 ORDER BY document, side`, actor.ID)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	docs, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (map[string]any, error) {
		var document, side, contentType string
		var size int
		var at time.Time
		err := row.Scan(&document, &side, &contentType, &size, &at)
		return documentInfo(document, side, contentType, size, at), err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if docs == nil {
		docs = []map[string]any{}
	}
	httpserver.WriteJSON(w, http.StatusOK, map[string]any{"documents": docs, "server_time": serverTime()})
}

// uploadDocument keeps one photo of one side of a document, replacing the one before (decision 0016).
// The photo never goes into the audit row or the stored reply.
func (s *Service) uploadDocument(w http.ResponseWriter, r *http.Request) {
	actor, _ := identity.ActorFrom(r.Context())
	var body struct {
		Document    string `json:"document"`
		Side        string `json:"side"`
		ContentType string `json:"content_type"`
		Data        string `json:"data_base64"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || !documentKinds[body.Document] || !documentSides[body.Side] {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send document, side, content_type and data_base64.", false)
		return
	}
	magic, known := imageMagic[body.ContentType]
	photo, err := base64.StdEncoding.DecodeString(body.Data)
	if !known || err != nil || len(photo) == 0 || len(photo) > maxDocumentBytes || !bytes.HasPrefix(photo, magic) {
		httpserver.WriteError(w, http.StatusBadRequest, "invalid_request", "Send a JPEG, PNG or WebP photo of at most 700 KB.", false)
		return
	}
	var reply map[string]any
	var refused bool
	err = database.InTx(r.Context(), s.Pool, func(tx pgx.Tx) error {
		if err := identity.CheckSession(r.Context(), tx, actor); err != nil {
			return err
		}
		if err := requireActive(r.Context(), tx, actor); err != nil {
			return err
		}
		status, _, err := latestVerification(r.Context(), tx, actor.ID)
		if err != nil {
			return err
		}
		if status == "verified" {
			refused = true
			return nil
		}
		var at time.Time
		if err := tx.QueryRow(r.Context(), `INSERT INTO rider_documents (rider_id, document, side, content_type, size_bytes, bytes)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (rider_id, document, side) DO UPDATE SET content_type = EXCLUDED.content_type, size_bytes = EXCLUDED.size_bytes,
				bytes = EXCLUDED.bytes, created_at = now()
			RETURNING created_at`, actor.ID, body.Document, body.Side, body.ContentType, len(photo), photo).Scan(&at); err != nil {
			return err
		}
		if err := audit.Record(r.Context(), tx, audit.Event{
			ActorType: identity.TypeRider, ActorID: actor.ID, Action: "rider.document_uploaded", EntityType: "rider", EntityID: actor.ID,
			After: map[string]any{"document": body.Document, "side": body.Side, "size_bytes": len(photo)},
		}); err != nil {
			return err
		}
		reply = map[string]any{"document": documentInfo(body.Document, body.Side, body.ContentType, len(photo), at), "server_time": serverTime()}
		return idempotency.Save(r.Context(), tx, http.StatusCreated, reply)
	})
	switch {
	case err != nil:
		s.fail(w, r, err)
	case refused:
		httpserver.WriteError(w, http.StatusConflict, "already_verified", "Your documents are already verified.", false)
	default:
		httpserver.WriteJSON(w, http.StatusCreated, reply)
	}
}
