-- +goose Up
-- The scooter's charge, as its telemetry last reported it (reportScooterTelemetry). A reading
-- older than riderrules.BatteryFreshFor is not shown.
ALTER TABLE scooters
    ADD COLUMN battery_pct integer CHECK (battery_pct IS NULL OR battery_pct BETWEEN 0 AND 100),
    ADD COLUMN battery_at  timestamptz,
    ADD CONSTRAINT scooters_battery_whole CHECK ((battery_pct IS NULL) = (battery_at IS NULL));

-- +goose Down
ALTER TABLE scooters DROP CONSTRAINT scooters_battery_whole, DROP COLUMN battery_at, DROP COLUMN battery_pct;
