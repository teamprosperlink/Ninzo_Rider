-- +goose Up
-- A rider's masked call to a customer (startRiderMaskedCall): for a short while, a call from the
-- rider's phone to the virtual number is connected to the customer's. Neither sees the other's.
CREATE TABLE call_bridges (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id       uuid        NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,
    rider_id       uuid        NOT NULL REFERENCES riders (id) ON DELETE RESTRICT,
    virtual_number text        NOT NULL CHECK (virtual_number ~ '^\+[1-9][0-9]{7,14}$'),
    caller_phone   text        NOT NULL CHECK (caller_phone ~ '^\+[1-9][0-9]{7,14}$'),
    callee_phone   text        NOT NULL CHECK (callee_phone ~ '^\+[1-9][0-9]{7,14}$'),
    expires_at     timestamptz NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX call_bridges_route_idx ON call_bridges (virtual_number, caller_phone, expires_at DESC);
ALTER TABLE call_bridges ENABLE ROW LEVEL SECURITY;

-- +goose Down
DROP TABLE call_bridges;
