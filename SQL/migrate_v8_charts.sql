CREATE OR REPLACE FUNCTION public.spendmate_report_getdata(p_type character varying)
 RETURNS TABLE(category character varying, total numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_type = 'daily' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE t.createdate >= CURRENT_DATE
        GROUP BY t.category;
    ELSIF p_type = 'weekly' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE t.createdate >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY t.category;
    ELSIF p_type = 'monthly' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE EXTRACT(YEAR FROM t.createdate) = EXTRACT(YEAR FROM CURRENT_DATE)
          AND EXTRACT(MONTH FROM t.createdate) = EXTRACT(MONTH FROM CURRENT_DATE)
        GROUP BY t.category;
    ELSE
        RAISE EXCEPTION 'Invalid report type';
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.spendmate_dashboard_get6monthtrend(p_userid integer)
 RETURNS TABLE(month character varying, income numeric, expense numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH Months AS (
        SELECT 
            to_char(m, 'Mon YYYY')::character varying AS mth,
            m as sort_date
        FROM generate_series(
            date_trunc('month', current_date) - interval '5 months',
            date_trunc('month', current_date),
            '1 month'
        ) AS m
    )
    SELECT 
        m.mth,
        COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'Income'), 0) as income,
        COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'Expense' OR t.type = 'Transfer'), 0) as expense
    FROM Months m
    LEFT JOIN transactions t 
        ON to_char(t.createdate, 'Mon YYYY') = m.mth AND t.userid = p_userid
    GROUP BY m.mth, m.sort_date
    ORDER BY m.sort_date;
END;
$function$;
