CREATE OR REPLACE FUNCTION public.spendmate_dashboard_get6monthtrend(p_userid integer) RETURNS TABLE(month character varying, income numeric, expense numeric)
    LANGUAGE plpgsql
    AS $$
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
        ON to_char(t.createdate, 'Mon YYYY') = m.mth 
    GROUP BY m.mth, m.sort_date
    ORDER BY m.sort_date;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_dashboard_getdailysummary(p_userid integer) RETURNS TABLE(category character varying, total numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.category,
        SUM(e.amount) AS total
    FROM transactions e
    WHERE e. e.type = 'Expense'
      AND e.createdate::date = CURRENT_DATE
    GROUP BY e.category;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_dashboard_getdailytotal(p_userid integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO total
    FROM transactions
    WHERE  type = 'Expense'
      AND createdate::date = CURRENT_DATE;

    RETURN total;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_report_getdata(p_type character varying, p_userid integer) RETURNS TABLE(category character varying, total numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_type = 'daily' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE  t.type = 'Expense'
          AND t.createdate >= CURRENT_DATE
        GROUP BY t.category;
    ELSIF p_type = 'weekly' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE  t.type = 'Expense'
          AND t.createdate >= date_trunc('week', CURRENT_DATE)
        GROUP BY t.category;
    ELSIF p_type = 'monthly' THEN
        RETURN QUERY
        SELECT t.category, SUM(t.amount) AS total
        FROM transactions t
        WHERE  t.type = 'Expense'
          AND EXTRACT(YEAR FROM t.createdate) = EXTRACT(YEAR FROM CURRENT_DATE)
          AND EXTRACT(MONTH FROM t.createdate) = EXTRACT(MONTH FROM CURRENT_DATE)
        GROUP BY t.category;
    ELSE
        RAISE EXCEPTION 'Invalid report type';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_transaction_delete(p_id integer, p_userid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM transactions 
    WHERE id = p_id ;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_transaction_exportall(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone) RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE  (p_from IS NULL OR t.createdate >= p_from)
      AND (p_to IS NULL OR t.createdate < p_to)
    ORDER BY t.createdate DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_transaction_getbyid(p_id integer, p_userid integer) RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.id = p_id ;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_transaction_getlist(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone) RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE  t.createdate >= p_from
      AND t.createdate < p_to
    ORDER BY t.createdate DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_transaction_gettotalbytype(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone, p_type character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE total_amount NUMERIC;
BEGIN
    SELECT COALESCE(SUM(t.amount), 0) INTO total_amount
    FROM transactions t
    WHERE  t.type = p_type
      AND t.createdate >= p_from
      AND t.createdate < p_to;

    RETURN total_amount;
END;

$$;

CREATE OR REPLACE FUNCTION public.spendmate_transaction_update(p_id integer, p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE transactions
    SET type = p_type,
        amount = p_amount,
        category = p_category,
        destination = p_destination,
        note = p_note,
        is_recurring = p_is_recurring
    WHERE id = p_id ;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_budget_getmonthlyrecap(p_userid integer, p_year integer, p_month integer) RETURNS TABLE("Id" integer, "GroupType" character varying, "Category" character varying, "TargetAmount" numeric, "ActualAmount" numeric, "IsPaid" boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH MonthlyTx AS (
        SELECT t.category, SUM(t.amount) as actual_sum
        FROM transactions t
        WHERE  EXTRACT(YEAR FROM t.createdate) = p_year
          AND EXTRACT(MONTH FROM t.createdate) = p_month
          AND t.type IN ('Expense', 'Transfer')
        GROUP BY t.category
    ),
    AllCategories AS (
        SELECT tx.category as name FROM MonthlyTx tx
        UNION
        SELECT c.name FROM categories c WHERE c.is_active = TRUE
        UNION
        SELECT c.name FROM monthly_budgets b
        JOIN categories c ON b.category_id = c.id
        WHERE b. b.year = p_year AND b.month = p_month
    )
    SELECT 
        COALESCE(b.id, 0) as "Id",
        COALESCE(c_master.group_type, 'Variable') as "GroupType",
        ac.name as "Category",
        COALESCE(b.target_amount, COALESCE(c_master.default_target, 0)) as "TargetAmount",
        COALESCE(tx.actual_sum, 0) as "ActualAmount",
        COALESCE(b.is_paid, FALSE) as "IsPaid"
    FROM AllCategories ac
    LEFT JOIN categories c_master ON ac.name = c_master.name
    LEFT JOIN monthly_budgets b 
        ON c_master.id = b.category_id AND b. b.year = p_year AND b.month = p_month
    LEFT JOIN MonthlyTx tx 
        ON ac.name = tx.category
    ORDER BY 
        CASE COALESCE(c_master.group_type, 'Variable')
            WHEN 'Fixed' THEN 1
            WHEN 'Savings' THEN 2
            WHEN 'Variable' THEN 3
            ELSE 4
        END, 
        ac.name;
END;
$$;

CREATE OR REPLACE FUNCTION public.spendmate_budget_save_monthly(p_userid integer, p_year integer, p_month integer, p_group_type character varying, p_category character varying, p_target_amount numeric, p_is_paid boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_category_id INT;
BEGIN
    -- Ensure category exists in master
    SELECT id INTO v_category_id FROM categories WHERE name = p_category;
    IF NOT FOUND THEN
        INSERT INTO categories (name, group_type, default_target, is_active)
        VALUES (p_category, p_group_type, p_target_amount, TRUE)
        RETURNING id INTO v_category_id;
    END IF;

    -- Upsert monthly_budgets
    INSERT INTO monthly_budgets (userid, year, month, category_id, target_amount, is_paid)
    VALUES (p_userid, p_year, p_month, v_category_id, p_target_amount, p_is_paid)
    ON CONFLICT (userid, year, month, category_id) 
    DO UPDATE SET 
        target_amount = EXCLUDED.target_amount,
        is_paid = EXCLUDED.is_paid;
END;
$$;

