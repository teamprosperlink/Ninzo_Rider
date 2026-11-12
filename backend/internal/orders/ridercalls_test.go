package orders

import "testing"

func TestCallNumbersAreReadAsTenDigits(t *testing.T) {
	for in, want := range map[string]string{
		"+919800000001": "9800000001",
		"09800000001":   "9800000001",
		"919800000001":  "9800000001",
		"98000 00001":   "9800000001",
		"12345":         "",
	} {
		if got := lastTen(in); got != want {
			t.Errorf("lastTen(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestRiderCallsNeedTheProvidersNumberAndKey(t *testing.T) {
	var none *RiderCalls
	for name, c := range map[string]*RiderCalls{
		"not set":    none,
		"no key":     {VirtualNumber: "+918000000000"},
		"bad number": {VirtualNumber: "8000000000", WebhookKey: "k"},
	} {
		if c.ready() {
			t.Errorf("%s: ready", name)
		}
	}
	if !(&RiderCalls{VirtualNumber: "+918000000000", WebhookKey: "k"}).ready() {
		t.Error("set up, but not ready")
	}
}
