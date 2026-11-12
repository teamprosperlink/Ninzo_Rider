-- +goose Up
-- The rest of the rider's day the app kept on the phone: when the rider went online at their spot,
-- and a break. A rider on a break gets no offers.
ALTER TABLE shifts
    ADD COLUMN online_at        timestamptz,
    ADD COLUMN break_started_at timestamptz,
    ADD COLUMN break_ends_at    timestamptz,
    ADD CONSTRAINT shifts_break_whole CHECK ((break_started_at IS NULL) = (break_ends_at IS NULL)),
    ADD CONSTRAINT shifts_break_after_start CHECK (break_ends_at IS NULL OR break_ends_at > break_started_at),
    -- When "Shift ending soon" went to the rider, so it goes once.
    ADD COLUMN ending_soon_sent_at timestamptz;

-- When the reminder to answer the morning stock request went, so it goes once.
ALTER TABLE shift_plans ADD COLUMN reminded_at timestamptz;

-- The rider's document photos, uploaded while applying, for operations to check by hand until
-- DigiLocker (decision 0016). One photo per document and side; a new upload replaces the old one.
-- The bytes never go into audit rows, the outbox or stored replies.
CREATE TABLE rider_documents (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id     uuid        NOT NULL REFERENCES riders (id) ON DELETE RESTRICT,
    document     text        NOT NULL CHECK (document IN ('aadhaar', 'drivingLicence', 'vehicleRc', 'selfie', 'bank')),
    side         text        NOT NULL CHECK (side IN ('front', 'back', 'photo')),
    content_type text        NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
    -- The API takes a photo as base64 JSON inside the 1 MB request limit.
    size_bytes   integer     NOT NULL CHECK (size_bytes BETWEEN 1 AND 700000),
    bytes        bytea       NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rider_id, document, side)
);
ALTER TABLE rider_documents ENABLE ROW LEVEL SECURITY;

-- +goose Down
DROP TABLE rider_documents;
ALTER TABLE shift_plans DROP COLUMN reminded_at;
ALTER TABLE shifts DROP COLUMN ending_soon_sent_at, DROP CONSTRAINT shifts_break_after_start, DROP CONSTRAINT shifts_break_whole,
    DROP COLUMN break_ends_at, DROP COLUMN break_started_at, DROP COLUMN online_at;
