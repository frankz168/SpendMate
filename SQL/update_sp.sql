DROP FUNCTION IF EXISTS public.spendmate_transaction_insert(integer, character varying, numeric, character varying, character varying, text, boolean);
CREATE OR REPLACE FUNCTION public.spendmate_transaction_insert(
    p_userid integer, 
    p_type character varying, 
    p_amount numeric, 
    p_category character varying, 
    p_destination character varying, 
    p_note text, 
    p_is_recurring boolean DEFAULT false,
    p_createdate timestamp without time zone DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE new_id INT;
BEGIN
    INSERT INTO transactions (userid, type, amount, category, destination, note, createdate, is_recurring)
    VALUES (p_userid, p_type, p_amount, p_category, p_destination, p_note, COALESCE(p_createdate, NOW()), p_is_recurring)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$;
ALTER FUNCTION public.spendmate_transaction_insert(p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean, p_createdate timestamp without time zone) OWNER TO frankz168;
