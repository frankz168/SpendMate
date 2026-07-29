-- 1. Add column to transactions
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE;

-- 2. Update spendmate_transaction_insert
DROP FUNCTION IF EXISTS public.spendmate_transaction_insert(integer, character varying, numeric, character varying, character varying, text);

CREATE OR REPLACE FUNCTION public.spendmate_transaction_insert(
    p_userid integer, 
    p_type character varying, 
    p_amount numeric, 
    p_category character varying, 
    p_destination character varying, 
    p_note text,
    p_is_recurring boolean DEFAULT FALSE
)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE new_id INT;
BEGIN
    INSERT INTO transactions (userid, type, amount, category, destination, note, createdate, is_recurring)
    VALUES (p_userid, p_type, p_amount, p_category, p_destination, p_note, NOW(), p_is_recurring)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$function$;

-- 3. Update spendmate_transaction_update
DROP FUNCTION IF EXISTS public.spendmate_transaction_update(integer, integer, character varying, numeric, character varying, character varying, text);

CREATE OR REPLACE FUNCTION public.spendmate_transaction_update(
    p_id integer, 
    p_userid integer, 
    p_type character varying, 
    p_amount numeric, 
    p_category character varying, 
    p_destination character varying, 
    p_note text,
    p_is_recurring boolean DEFAULT FALSE
)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE transactions
    SET type = p_type,
        amount = p_amount,
        category = p_category,
        destination = p_destination,
        note = p_note,
        is_recurring = p_is_recurring
    WHERE id = p_id AND userid = p_userid;
END;
$function$;

-- 4. Update getlist to return is_recurring
DROP FUNCTION IF EXISTS public.spendmate_transaction_getlist(integer, timestamp without time zone, timestamp without time zone);
CREATE OR REPLACE FUNCTION public.spendmate_transaction_getlist(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone)
 RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.userid = p_userid
      AND t.createdate >= p_from
      AND t.createdate < p_to
    ORDER BY t.createdate DESC;
END;
$function$;

-- 5. Update getbyid
DROP FUNCTION IF EXISTS public.spendmate_transaction_getbyid(integer, integer);
CREATE OR REPLACE FUNCTION public.spendmate_transaction_getbyid(p_id integer, p_userid integer)
 RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.id = p_id AND t.userid = p_userid;
END;
$function$;

-- 6. Update exportall
DROP FUNCTION IF EXISTS public.spendmate_transaction_exportall(integer, timestamp without time zone, timestamp without time zone);
CREATE OR REPLACE FUNCTION public.spendmate_transaction_exportall(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone)
 RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.userid = p_userid
      AND (p_from IS NULL OR t.createdate >= p_from)
      AND (p_to IS NULL OR t.createdate < p_to)
    ORDER BY t.createdate DESC;
END;
$function$;

-- 7. Recurring Automation Function
CREATE OR REPLACE FUNCTION public.spendmate_automation_runrecurring(p_userid integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    rec RECORD;
    v_start_of_month date;
BEGIN
    v_start_of_month := date_trunc('month', CURRENT_DATE)::date;

    -- Loop through all recurring templates for the user
    FOR rec IN 
        SELECT * FROM transactions 
        WHERE userid = p_userid AND is_recurring = TRUE 
          -- Only clone if it was created before the current month to avoid cloning it immediately when they create it this month
          AND date_trunc('month', createdate)::date < v_start_of_month
    LOOP
        -- Check if a clone was already created this month
        IF NOT EXISTS (
            SELECT 1 FROM transactions 
            WHERE userid = p_userid 
              AND category = rec.category 
              AND amount = rec.amount 
              AND type = rec.type
              AND note LIKE '[Auto-Recurring]%'
              AND is_recurring = FALSE
              AND date_trunc('month', createdate)::date = v_start_of_month
        ) THEN
            -- Create the clone
            INSERT INTO transactions (userid, type, amount, category, destination, note, createdate, is_recurring)
            VALUES (
                rec.userid, 
                rec.type, 
                rec.amount, 
                rec.category, 
                rec.destination, 
                '[Auto-Recurring] ' || COALESCE(rec.note, ''), 
                CURRENT_DATE, 
                FALSE
            );
        END IF;
    END LOOP;
END;
$function$;
