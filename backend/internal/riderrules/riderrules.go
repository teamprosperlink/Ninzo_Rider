// Package riderrules holds the rider app's timings and formats that are not zone settings, in one
// place: the code that acts on them (reminders, the handover code) and getRiderSettings, which
// tells the app, both read them, so the app has none of its own. It imports nothing.
package riderrules

import "time"

const (
	// StockAskBefore is when, before a planned start, the rider is asked if they are coming.
	StockAskBefore = time.Hour
	// StockReminderBefore is when a rider who has not answered is reminded.
	StockReminderBefore = 30 * time.Minute
	// EndingSoonBefore is when, before the planned end, "Shift ending soon" goes.
	EndingSoonBefore = 15 * time.Minute
	// BreakExtension is what "+15 min" adds to a break.
	BreakExtension = 15 * time.Minute
	// NotAtGateAfter is how long the handover's code step waits, empty, before offering
	// "Customer not at the gate?".
	NotAtGateAfter = 15 * time.Second
	// HandoverCodeDigits is the length of the customer's handover code.
	HandoverCodeDigits = 4
)
