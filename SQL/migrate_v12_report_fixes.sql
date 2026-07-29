-- DROP OLD FUNCTION
DROP FUNCTION IF EXISTS public.spendmate_report_getdata(character varying);

-- CREATE NEW FUNCTION WITH USERID AND CORRECT FILTERS
CREATE OR REPLACE FUNCTION public.spendmate_report_getdata(p_type character varying, p_userid integer)
 RETURNS TABLE(category character varying, total numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_type = 'daily' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE t.userid = p_userid
          AND t.type = 'Expense'
          AND t.createdate >= CURRENT_DATE
        GROUP BY t.category;
    ELSIF p_type = 'weekly' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE t.userid = p_userid
          AND t.type = 'Expense'
          AND t.createdate >= date_trunc('week', CURRENT_DATE)
        GROUP BY t.category;
    ELSIF p_type = 'monthly' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE t.userid = p_userid
          AND t.type = 'Expense'
          AND EXTRACT(YEAR FROM t.createdate) = EXTRACT(YEAR FROM CURRENT_DATE)
          AND EXTRACT(MONTH FROM t.createdate) = EXTRACT(MONTH FROM CURRENT_DATE)
        GROUP BY t.category;
    ELSE
        RAISE EXCEPTION 'Invalid report type';
    END IF;
END;
$function$;
