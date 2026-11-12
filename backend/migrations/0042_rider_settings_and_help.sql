-- +goose Up
-- What the rider app had written into itself: the distances it checks, the battery levels, how much
-- a scooter holds (decision 0014: settings, not constants). As in 0034, the default fills the
-- existing rows, the global one included, and then goes.
ALTER TABLE zone_settings
    ADD COLUMN rider_arrive_m          integer DEFAULT 100 CHECK (rider_arrive_m BETWEEN 20 AND 500),
    ADD COLUMN rider_almost_m          integer DEFAULT 300 CHECK (rider_almost_m BETWEEN 50 AND 2000),
    ADD COLUMN rider_away_m            integer DEFAULT 150 CHECK (rider_away_m BETWEEN 50 AND 2000),
    ADD COLUMN scooter_capacity_qty    integer DEFAULT 8 CHECK (scooter_capacity_qty BETWEEN 1 AND 100),
    ADD COLUMN min_phone_battery_pct   integer DEFAULT 50 CHECK (min_phone_battery_pct BETWEEN 0 AND 100),
    ADD COLUMN min_scooter_battery_pct integer DEFAULT 40 CHECK (min_scooter_battery_pct BETWEEN 0 AND 100),
    ADD COLUMN low_scooter_battery_pct integer DEFAULT 20 CHECK (low_scooter_battery_pct BETWEEN 0 AND 100);
ALTER TABLE zone_settings
    ALTER COLUMN rider_arrive_m DROP DEFAULT,
    ALTER COLUMN rider_almost_m DROP DEFAULT,
    ALTER COLUMN rider_away_m DROP DEFAULT,
    ALTER COLUMN scooter_capacity_qty DROP DEFAULT,
    ALTER COLUMN min_phone_battery_pct DROP DEFAULT,
    ALTER COLUMN min_scooter_battery_pct DROP DEFAULT,
    ALTER COLUMN low_scooter_battery_pct DROP DEFAULT;

-- The help centre's questions and answers, per app, in order. Operations edit them; these are the
-- first ones, to be reviewed.
CREATE TABLE help_articles (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    app        text        NOT NULL CHECK (app IN ('rider', 'customer', 'partner')),
    question   text        NOT NULL CHECK (length(question) BETWEEN 3 AND 200),
    answer     text        NOT NULL CHECK (length(answer) BETWEEN 3 AND 2000),
    sort_order integer     NOT NULL DEFAULT 0,
    status     text        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'hidden')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX help_articles_app_idx ON help_articles (app, sort_order) WHERE status = 'active';
ALTER TABLE help_articles ENABLE ROW LEVEL SECURITY;
INSERT INTO help_articles (app, question, answer, sort_order) VALUES
    ('rider', 'How do I go online?', 'Finish the checklist, ride to your hub, scan your stock onto the scooter, then ride to your spot. Go online unlocks once you are there.', 1),
    ('rider', 'How do I load stock at the hub?', 'When the hub has packed your stock, scan each lot''s code on the stock screen. If a code will not scan, count it by hand.', 2),
    ('rider', 'Customer isn''t at the gate', 'Wait at the gate, then use Report a problem and choose Customer absent. Support takes it from there.', 3),
    ('rider', 'How are my earnings counted?', 'You earn for each order handed over, an incentive once you reach the day''s order target, and paid time for each move you accept. Earnings shows each part.', 4),
    ('rider', 'How do I change my shift?', 'Operations plan your shifts. Use Add time to ride longer today, or call your hub manager to change a planned shift.', 5),
    ('rider', 'Scooter has a fault, who do I call?', 'Use Report a problem and choose Breakdown, then call your hub manager from Contact us.', 6);

-- What riders tell us through Send feedback.
CREATE TABLE rider_feedback (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id   uuid        NOT NULL REFERENCES riders (id) ON DELETE RESTRICT,
    message    text        NOT NULL CHECK (length(message) BETWEEN 1 AND 2000),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX rider_feedback_created_idx ON rider_feedback (created_at DESC);
ALTER TABLE rider_feedback ENABLE ROW LEVEL SECURITY;

-- The "Before you start" checklist the rider ticked, kept with the shift it started.
ALTER TABLE shifts ADD COLUMN checklist text[];

-- The code printed at a gate, and in its QR code, that the rider checks on arrival. Null when the
-- gate has none, so arrival is by location alone (decision 0012).
ALTER TABLE gates ADD COLUMN rider_code text CHECK (rider_code IS NULL OR rider_code ~ '^[A-Za-z0-9-]{4,32}$');

-- +goose Down
ALTER TABLE gates DROP COLUMN rider_code;
ALTER TABLE shifts DROP COLUMN checklist;
DROP TABLE rider_feedback;
DROP TABLE help_articles;
ALTER TABLE zone_settings
    DROP COLUMN low_scooter_battery_pct, DROP COLUMN min_scooter_battery_pct, DROP COLUMN min_phone_battery_pct,
    DROP COLUMN scooter_capacity_qty, DROP COLUMN rider_away_m, DROP COLUMN rider_almost_m, DROP COLUMN rider_arrive_m;
