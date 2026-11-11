-- +goose Up
-- What the rider app kept on the phone because the API had nowhere to put it.
--
-- The rider's own details: an email for contact (it never signs anyone in) and the area they chose
-- while applying. The area is all four parts or none.
ALTER TABLE riders
    ADD COLUMN email     text CHECK (email IS NULL OR (length(email) BETWEEN 3 AND 254 AND email LIKE '%_@_%')),
    ADD COLUMN area_name text CHECK (area_name IS NULL OR length(area_name) BETWEEN 1 AND 120),
    ADD COLUMN area_city text CHECK (area_city IS NULL OR length(area_city) <= 80),
    ADD COLUMN area_lat  double precision CHECK (area_lat IS NULL OR area_lat BETWEEN -90 AND 90),
    ADD COLUMN area_lng  double precision CHECK (area_lng IS NULL OR area_lng BETWEEN -180 AND 180),
    ADD CONSTRAINT riders_area_whole CHECK (
        (area_name IS NULL) = (area_city IS NULL) AND (area_name IS NULL) = (area_lat IS NULL) AND (area_name IS NULL) = (area_lng IS NULL));

-- The number "Call hub manager" rings. Null until the admin enters it.
ALTER TABLE hubs ADD COLUMN manager_phone text CHECK (manager_phone IS NULL OR manager_phone ~ '^\+[1-9][0-9]{7,14}$');

-- One planned shift per rider per day (India time), made by operations: when it starts and ends,
-- the morning stock request the rider answers, and the hub's packing of the day's stock.
CREATE TABLE shift_plans (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id    uuid        NOT NULL REFERENCES riders (id) ON DELETE RESTRICT,
    day         date        NOT NULL,
    node_id     uuid        REFERENCES staging_nodes (id) ON DELETE RESTRICT,
    starts_at   timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL CHECK (ends_at > starts_at),
    stock_reply text        NOT NULL DEFAULT 'pending' CHECK (stock_reply IN ('pending', 'coming', 'not_today')),
    replied_at  timestamptz,
    packing     text        NOT NULL DEFAULT 'not_started' CHECK (packing IN ('not_started', 'packing', 'ready')),
    ready_at    timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rider_id, day),
    CHECK ((stock_reply = 'pending') = (replied_at IS NULL)),
    -- The hub packs only for a rider who is coming.
    CHECK (packing = 'not_started' OR stock_reply = 'coming'),
    CHECK (packing <> 'ready' OR ready_at IS NOT NULL)
);
ALTER TABLE shift_plans ENABLE ROW LEVEL SECURITY;

-- A shift keeps its planned end, and the phone that started it, so another phone of the same
-- rider can tell the shift is open elsewhere.
ALTER TABLE shifts
    ADD COLUMN planned_end_at timestamptz,
    ADD COLUMN device_id      uuid REFERENCES devices (id) ON DELETE SET NULL;

-- What the rider was told. Each row is also sent as a push (topic push.rider).
CREATE TABLE rider_notifications (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id   uuid        NOT NULL REFERENCES riders (id) ON DELETE RESTRICT,
    kind       text        NOT NULL CHECK (kind ~ '^[a-z_]{1,40}$'),
    title      text        NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
    body       text        NOT NULL CHECK (length(body) <= 500),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX rider_notifications_rider_idx ON rider_notifications (rider_id, created_at DESC, id DESC);
ALTER TABLE rider_notifications ENABLE ROW LEVEL SECURITY;

-- A rider can quarantine a lot on their own scooter (after a temperature alert, or food they find
-- damaged). The lot leaves the scooter through the ledger, under its own reason.
ALTER TABLE lots ADD COLUMN quarantined_by_rider uuid REFERENCES riders (id) ON DELETE RESTRICT;
ALTER TABLE stock_ledger DROP CONSTRAINT stock_ledger_reason_check;
ALTER TABLE stock_ledger ADD CONSTRAINT stock_ledger_reason_check
    CHECK (reason IN ('scan', 'reserve', 'release', 'handover', 'unload', 'correction', 'quarantine'));

-- +goose Down
ALTER TABLE stock_ledger DROP CONSTRAINT stock_ledger_reason_check;
ALTER TABLE stock_ledger ADD CONSTRAINT stock_ledger_reason_check
    CHECK (reason IN ('scan', 'reserve', 'release', 'handover', 'unload', 'correction'));
ALTER TABLE lots DROP COLUMN quarantined_by_rider;
DROP TABLE rider_notifications;
ALTER TABLE shifts DROP COLUMN device_id, DROP COLUMN planned_end_at;
DROP TABLE shift_plans;
ALTER TABLE hubs DROP COLUMN manager_phone;
ALTER TABLE riders DROP CONSTRAINT riders_area_whole,
    DROP COLUMN area_lng, DROP COLUMN area_lat, DROP COLUMN area_city, DROP COLUMN area_name, DROP COLUMN email;
