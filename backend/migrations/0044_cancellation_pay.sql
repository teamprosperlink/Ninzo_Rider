-- +goose Up
-- A cancelled order the rider had accepted pays them for the trip (the rider app's Navigate 04 and
-- 06): the lesser of riderrules.CancelPayCapPaise and the order's price. One per order.
-- +goose StatementBegin
DO $$
DECLARE
    c record;
BEGIN
    FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'public.earnings'::regclass AND contype = 'c'
        AND (pg_get_constraintdef(oid) LIKE '%''order''%order_id%' OR pg_get_constraintdef(oid) LIKE '%kind = ANY%')
    LOOP
        EXECUTE format('ALTER TABLE public.earnings DROP CONSTRAINT %I', c.conname);
    END LOOP;
END;
$$;
-- +goose StatementEnd
ALTER TABLE earnings
    ADD CONSTRAINT earnings_kind_check CHECK (kind IN ('order', 'incentive', 'relocation', 'cancellation')),
    ADD CONSTRAINT earnings_order_kinds CHECK ((kind IN ('order', 'cancellation')) = (order_id IS NOT NULL));
CREATE UNIQUE INDEX earnings_one_cancellation_per_order ON earnings (order_id) WHERE kind = 'cancellation';

-- +goose Down
DROP INDEX earnings_one_cancellation_per_order;
DELETE FROM earnings WHERE kind = 'cancellation';
ALTER TABLE earnings DROP CONSTRAINT earnings_order_kinds, DROP CONSTRAINT earnings_kind_check;
ALTER TABLE earnings
    ADD CONSTRAINT earnings_kind_check CHECK (kind IN ('order', 'incentive', 'relocation')),
    ADD CONSTRAINT earnings_check CHECK ((kind = 'order') = (order_id IS NOT NULL));
