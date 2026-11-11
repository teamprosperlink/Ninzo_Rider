// Command riders does what operations need for riders until the admin console covers it (v0.9.0).
// Every change is audited.
//
//	riders -local|-remote approve -phone +91... -zone zone-id -reason "why" -by "who"
//	riders -local|-remote plan -phone +91... -date YYYY-MM-DD -start HH:MM -end HH:MM [-node node-id] -by "who"
//	riders -local|-remote packing -phone +91... -date YYYY-MM-DD -state packing|ready [-ready-in 20m] -by "who"
//	riders -local|-remote hub-phone -hub hub-id -phone +91... -by "who"
//
// approve makes the rider active in a zone, and records their documents as checked by hand. plan
// makes or changes the rider's shift plan for a day (times are India time) and asks the rider if
// they are coming. packing moves the hub's packing of that day's stock on, for a rider who said
// they are coming. hub-phone sets the number Call hub manager rings. -remote applies to Supabase,
// so use it only through `task staging:riders`, which asks first.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/teamprosperlink/Ninzo_backend/internal/audit"
	"github.com/teamprosperlink/Ninzo_backend/internal/dbtarget"
	"github.com/teamprosperlink/Ninzo_backend/internal/platform/database"
	"github.com/teamprosperlink/Ninzo_backend/internal/ridernotes"
)

const usage = `usage: riders -local|-remote approve -phone +91... -zone zone-id -reason "why" -by "who"
       riders -local|-remote plan -phone +91... -date YYYY-MM-DD -start HH:MM -end HH:MM [-node node-id] -by "who"
       riders -local|-remote packing -phone +91... -date YYYY-MM-DD -state packing|ready [-ready-in 20m] -by "who"
       riders -local|-remote hub-phone -hub hub-id -phone +91... -by "who"`

var (
	phonePattern = regexp.MustCompile(`^\+91[6-9][0-9]{9}$`)
	idPattern    = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	india        = time.FixedZone("IST", 5*3600+1800)
)

func main() {
	if err := run(context.Background(), os.Args[1:], os.Getenv, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "riders:", err)
		os.Exit(1)
	}
}

// change is one command, ready to run in a transaction once the arguments are checked.
type change func(ctx context.Context, tx pgx.Tx, target dbtarget.Target, out io.Writer) error

func run(ctx context.Context, args []string, getenv func(string) string, out io.Writer) error {
	if len(args) < 2 || (args[0] != "-local" && args[0] != "-remote") {
		return errors.New(usage)
	}
	var do change
	var err error
	switch args[1] {
	case "approve":
		do, err = approve(args[2:])
	case "plan":
		do, err = plan(args[2:])
	case "packing":
		do, err = packing(args[2:])
	case "hub-phone":
		do, err = hubPhone(args[2:])
	default:
		err = errors.New(usage)
	}
	if err != nil {
		return err
	}
	dsn := getenv("DATABASE_URL")
	if dsn == "" {
		return errors.New("DATABASE_URL is not set")
	}
	target, err := dbtarget.Parse(dsn)
	if err != nil {
		return err
	}
	if args[0] == "-remote" {
		err = target.CheckRemote()
	} else {
		err = target.CheckLocal()
	}
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "target: host %s, project %q\n", target.Host(), target.Ref())
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	pool, err := database.Open(ctx, dsn, 2)
	if err != nil {
		return err
	}
	defer pool.Close()
	return database.InTx(ctx, pool, func(tx pgx.Tx) error { return do(ctx, tx, target, out) })
}

func flags(name string) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	return fs
}

// riderByPhone finds the rider with that phone, locked.
func riderByPhone(ctx context.Context, tx pgx.Tx, target dbtarget.Target, phone string) (id, status string, err error) {
	err = tx.QueryRow(ctx, `SELECT r.id::text, r.status FROM riders r JOIN people p ON p.id = r.person_id
		WHERE p.phone = $1 FOR UPDATE OF r`, phone).Scan(&id, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", errors.New("no rider has that phone. They must apply first")
	}
	if err != nil {
		return "", "", errors.New(target.Safe(err))
	}
	return id, status, nil
}

func approve(args []string) (change, error) {
	fs := flags("approve")
	phone := fs.String("phone", "", "")
	zone := fs.String("zone", "", "")
	reason := fs.String("reason", "", "")
	by := fs.String("by", "", "")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 {
		return nil, errors.New(usage)
	}
	if !phonePattern.MatchString(*phone) || *zone == "" || len(strings.TrimSpace(*reason)) < 3 || strings.TrimSpace(*by) == "" {
		return nil, errors.New(usage)
	}
	return func(ctx context.Context, tx pgx.Tx, target dbtarget.Target, out io.Writer) error {
		rider, status, err := riderByPhone(ctx, tx, target, *phone)
		if err != nil {
			return err
		}
		if status == "suspended" {
			return errors.New("this rider is suspended, so approving them would undo that")
		}
		var exists bool
		if err := tx.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM zones WHERE id::text = $1)", *zone).Scan(&exists); err != nil || !exists {
			return errors.New("no such zone")
		}
		if _, err := tx.Exec(ctx, "UPDATE riders SET status = 'active', zone_id = $2, updated_at = now() WHERE id = $1", rider, *zone); err != nil {
			return errors.New(target.Safe(err))
		}
		if _, err := tx.Exec(ctx, `INSERT INTO rider_verifications (rider_id, status, method, reason) VALUES ($1, 'verified', 'manual_upload', $2)`,
			rider, strings.TrimSpace(*by)+": "+strings.TrimSpace(*reason)); err != nil {
			return errors.New(target.Safe(err))
		}
		if err := audit.Record(ctx, tx, audit.Event{
			ActorType: audit.ActorSystem, Action: "rider.approved", EntityType: "rider", EntityID: rider,
			Before: map[string]any{"status": status}, After: map[string]any{"status": "active", "zone_id": *zone},
			Reason: strings.TrimSpace(*by) + ": " + strings.TrimSpace(*reason),
		}); err != nil {
			return err
		}
		fmt.Fprintf(out, "approved rider %s in zone %s\n", rider, *zone)
		return nil
	}, nil
}

// planTimes reads a day and two clock times in India time. The end may be past midnight.
func planTimes(day, start, end string) (time.Time, time.Time, error) {
	d, err := time.ParseInLocation("2006-01-02", day, india)
	if err != nil {
		return time.Time{}, time.Time{}, errors.New(usage)
	}
	at := func(clock string) (time.Time, error) {
		c, err := time.Parse("15:04", clock)
		if err != nil {
			return time.Time{}, errors.New(usage)
		}
		return d.Add(time.Duration(c.Hour())*time.Hour + time.Duration(c.Minute())*time.Minute), nil
	}
	s, err := at(start)
	if err != nil {
		return s, s, err
	}
	e, err := at(end)
	if err != nil {
		return s, e, err
	}
	if !e.After(s) {
		e = e.Add(24 * time.Hour)
	}
	if e.Sub(s) > 16*time.Hour {
		return s, e, errors.New("a shift is at most 16 hours")
	}
	return s, e, nil
}

func plan(args []string) (change, error) {
	fs := flags("plan")
	phone := fs.String("phone", "", "")
	day := fs.String("date", "", "")
	start := fs.String("start", "", "")
	end := fs.String("end", "", "")
	node := fs.String("node", "", "")
	by := fs.String("by", "", "")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 || !phonePattern.MatchString(*phone) || strings.TrimSpace(*by) == "" ||
		(*node != "" && !idPattern.MatchString(*node)) {
		return nil, errors.New(usage)
	}
	starts, ends, err := planTimes(*day, *start, *end)
	if err != nil {
		return nil, err
	}
	var nodeID *string
	if *node != "" {
		nodeID = node
	}
	return func(ctx context.Context, tx pgx.Tx, target dbtarget.Target, out io.Writer) error {
		rider, status, err := riderByPhone(ctx, tx, target, *phone)
		if err != nil {
			return err
		}
		if status != "active" {
			return errors.New("only an active rider can have a shift planned")
		}
		var nodeName string
		if nodeID != nil {
			err := tx.QueryRow(ctx, `SELECT n.name FROM staging_nodes n JOIN riders r ON r.zone_id = n.zone_id WHERE n.id = $1 AND r.id = $2`,
				*nodeID, rider).Scan(&nodeName)
			if errors.Is(err, pgx.ErrNoRows) {
				return errors.New("no such node in the rider's zone")
			}
			if err != nil {
				return errors.New(target.Safe(err))
			}
		}
		// A changed plan asks again, unless the hub has started packing.
		var id, packing string
		if err := tx.QueryRow(ctx, `INSERT INTO shift_plans (rider_id, day, node_id, starts_at, ends_at) VALUES ($1, $2::date, $3, $4, $5)
			ON CONFLICT (rider_id, day) DO UPDATE SET node_id = EXCLUDED.node_id, starts_at = EXCLUDED.starts_at, ends_at = EXCLUDED.ends_at,
				stock_reply = CASE WHEN shift_plans.packing = 'not_started' THEN 'pending' ELSE shift_plans.stock_reply END,
				replied_at = CASE WHEN shift_plans.packing = 'not_started' THEN NULL ELSE shift_plans.replied_at END,
				updated_at = now()
			RETURNING id::text, packing`, rider, *day, nodeID, starts, ends).Scan(&id, &packing); err != nil {
			return errors.New(target.Safe(err))
		}
		if err := bumpRider(ctx, tx, rider); err != nil {
			return errors.New(target.Safe(err))
		}
		if err := audit.Record(ctx, tx, audit.Event{
			ActorType: audit.ActorSystem, Action: "shift_plan.set", EntityType: "shift_plan", EntityID: id,
			After:  map[string]any{"day": *day, "starts_at": starts.UTC().Format(time.RFC3339), "ends_at": ends.UTC().Format(time.RFC3339), "node_id": nodeID},
			Reason: strings.TrimSpace(*by),
		}); err != nil {
			return err
		}
		if packing == "not_started" {
			where := ""
			if nodeName != "" {
				where = " at " + nodeName
			}
			if err := ridernotes.Add(ctx, tx, rider, ridernotes.StockRequest, "Coming in today?",
				fmt.Sprintf("Your shift%s starts at %s. Tell the hub if you're coming, so it packs your stock.", where, starts.Format("3:04 PM"))); err != nil {
				return err
			}
		}
		fmt.Fprintf(out, "planned shift %s for rider %s on %s, %s to %s\n", id, rider, *day, starts.Format("15:04"), ends.Format("15:04"))
		return nil
	}, nil
}

func packing(args []string) (change, error) {
	fs := flags("packing")
	phone := fs.String("phone", "", "")
	day := fs.String("date", "", "")
	state := fs.String("state", "", "")
	readyIn := fs.Duration("ready-in", 0, "")
	by := fs.String("by", "", "")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 || !phonePattern.MatchString(*phone) || strings.TrimSpace(*by) == "" ||
		(*state != "packing" && *state != "ready") || *readyIn < 0 || *readyIn > 6*time.Hour {
		return nil, errors.New(usage)
	}
	if _, err := time.Parse("2006-01-02", *day); err != nil {
		return nil, errors.New(usage)
	}
	return func(ctx context.Context, tx pgx.Tx, target dbtarget.Target, out io.Writer) error {
		rider, _, err := riderByPhone(ctx, tx, target, *phone)
		if err != nil {
			return err
		}
		var id, reply, before string
		err = tx.QueryRow(ctx, "SELECT id::text, stock_reply, packing FROM shift_plans WHERE rider_id = $1 AND day = $2::date FOR UPDATE",
			rider, *day).Scan(&id, &reply, &before)
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("this rider has no shift planned that day")
		}
		if err != nil {
			return errors.New(target.Safe(err))
		}
		if reply != "coming" {
			return errors.New("the hub packs only for a rider who said they are coming")
		}
		if before == "ready" && *state == "packing" {
			return errors.New("the stock is already ready")
		}
		// ready_at is when it was ready, or when the hub expects it while packing.
		var readyAt any
		switch {
		case *state == "ready":
			readyAt = time.Now().UTC()
		case *readyIn > 0:
			readyAt = time.Now().UTC().Add(*readyIn)
		}
		if _, err := tx.Exec(ctx, "UPDATE shift_plans SET packing = $2, ready_at = $3, updated_at = now() WHERE id = $1", id, *state, readyAt); err != nil {
			return errors.New(target.Safe(err))
		}
		if err := bumpRider(ctx, tx, rider); err != nil {
			return errors.New(target.Safe(err))
		}
		if err := audit.Record(ctx, tx, audit.Event{
			ActorType: audit.ActorSystem, Action: "shift_plan.packing", EntityType: "shift_plan", EntityID: id,
			Before: map[string]any{"packing": before}, After: map[string]any{"packing": *state}, Reason: strings.TrimSpace(*by),
		}); err != nil {
			return err
		}
		if *state == "ready" && before != "ready" {
			if err := ridernotes.Add(ctx, tx, rider, ridernotes.StockReady, "Your stock is ready", "Collect it at the hub."); err != nil {
				return err
			}
		}
		fmt.Fprintf(out, "shift plan %s: packing %s\n", id, *state)
		return nil
	}, nil
}

func hubPhone(args []string) (change, error) {
	fs := flags("hub-phone")
	hub := fs.String("hub", "", "")
	phone := fs.String("phone", "", "")
	by := fs.String("by", "", "")
	if err := fs.Parse(args); err != nil || fs.NArg() != 0 || !idPattern.MatchString(*hub) || !phonePattern.MatchString(*phone) || strings.TrimSpace(*by) == "" {
		return nil, errors.New(usage)
	}
	return func(ctx context.Context, tx pgx.Tx, target dbtarget.Target, out io.Writer) error {
		tag, err := tx.Exec(ctx, "UPDATE hubs SET manager_phone = $2, updated_at = now() WHERE id = $1", *hub, *phone)
		if err != nil {
			return errors.New(target.Safe(err))
		}
		if tag.RowsAffected() == 0 {
			return errors.New("no such hub")
		}
		// The number itself stays out of the audit trail, which is kept for good.
		if err := audit.Record(ctx, tx, audit.Event{
			ActorType: audit.ActorSystem, Action: "hub.manager_phone_set", EntityType: "hub", EntityID: *hub, Reason: strings.TrimSpace(*by),
		}); err != nil {
			return err
		}
		fmt.Fprintf(out, "hub %s: manager phone set\n", *hub)
		return nil
	}, nil
}

// bumpRider raises the rider's seq, so the app fetches its state again.
func bumpRider(ctx context.Context, tx pgx.Tx, rider string) error {
	_, err := tx.Exec(ctx, `INSERT INTO rider_state (rider_id, seq) VALUES ($1, 1)
		ON CONFLICT (rider_id) DO UPDATE SET seq = rider_state.seq + 1, updated_at = now()`, rider)
	return err
}
