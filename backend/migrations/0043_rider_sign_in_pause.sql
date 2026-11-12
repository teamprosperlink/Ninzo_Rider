-- +goose Up
-- When a sign-in code ran out of attempts. For a rider that pauses sign-in on the phone for
-- riderrules.SignInPause, as the rider app's design says ("Try again in 30 minutes").
ALTER TABLE otp_requests ADD COLUMN locked_at timestamptz;
CREATE INDEX otp_requests_locked_idx ON otp_requests (actor_type, phone, locked_at DESC) WHERE locked_at IS NOT NULL;

-- +goose Down
DROP INDEX otp_requests_locked_idx;
ALTER TABLE otp_requests DROP COLUMN locked_at;
