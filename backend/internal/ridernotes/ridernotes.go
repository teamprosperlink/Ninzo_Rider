// Package ridernotes records what a rider is told, so the app can list it (listRiderNotifications),
// and queues the same thing as a push to the rider's devices. It has no imports from other
// feature packages, so any of them can call it inside their own transaction.
package ridernotes

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/platform/outbox"
)

// Kinds the app knows. The list is open, so new kinds never break an app.
const (
	SpotAssigned  = "spot_assigned"
	OrdersWaiting = "orders_waiting"
	StockRequest  = "stock_request"
	StockReady    = "stock_ready"
)

const (
	maxTitle = 120
	maxBody  = 500
)

// Add records a notification for the rider and queues its push, in the caller's transaction, so
// neither happens without the change it is about.
func Add(ctx context.Context, tx pgx.Tx, riderID, kind, title, body string) error {
	title, body = clip(strings.TrimSpace(title), maxTitle), clip(strings.TrimSpace(body), maxBody)
	if riderID == "" || kind == "" || title == "" {
		return errors.New("ridernotes: rider, kind and title are required")
	}
	var id string
	if err := tx.QueryRow(ctx, `INSERT INTO rider_notifications (rider_id, kind, title, body) VALUES ($1, $2, $3, $4) RETURNING id::text`,
		riderID, kind, title, body).Scan(&id); err != nil {
		return err
	}
	return outbox.Add(ctx, tx, "push.rider", map[string]any{
		"rider_id": riderID, "kind": "notification", "notification_id": id, "notification_kind": kind, "title": title, "body": body,
	})
}

// clip shortens s to at most n runes.
func clip(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}
