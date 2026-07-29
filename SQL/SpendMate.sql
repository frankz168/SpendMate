--
-- PostgreSQL database dump
--

\restrict xVyziJTJjtHf4q1FewjOTj61lNdSAMc7gOoW2xTgaTJ2ESX5Rmu4rw7ydTbIGdN

-- Dumped from database version 18.3 (Homebrew)
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.monthly_budgets DROP CONSTRAINT IF EXISTS monthly_budgets_category_id_fkey;
ALTER TABLE IF EXISTS ONLY public.transactions DROP CONSTRAINT IF EXISTS fk_user;
DROP INDEX IF EXISTS public.idx_transactions_userid;
DROP INDEX IF EXISTS public.idx_transactions_user_date;
DROP INDEX IF EXISTS public.idx_transactions_createdate;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_username_key;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.tbl_settings_config DROP CONSTRAINT IF EXISTS tbl_settings_config_pkey;
ALTER TABLE IF EXISTS ONLY public.monthly_budgets DROP CONSTRAINT IF EXISTS monthly_budgets_userid_year_month_category_id_key;
ALTER TABLE IF EXISTS ONLY public.monthly_budgets DROP CONSTRAINT IF EXISTS monthly_budgets_pkey;
ALTER TABLE IF EXISTS ONLY public.transactions DROP CONSTRAINT IF EXISTS expenses_pkey;
ALTER TABLE IF EXISTS ONLY public.categories DROP CONSTRAINT IF EXISTS categories_pkey;
ALTER TABLE IF EXISTS ONLY public.categories DROP CONSTRAINT IF EXISTS categories_name_key;
ALTER TABLE IF EXISTS public.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.transactions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.monthly_budgets ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.categories ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.users_id_seq;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.tbl_settings_config;
DROP SEQUENCE IF EXISTS public.monthly_budgets_id_seq;
DROP TABLE IF EXISTS public.monthly_budgets;
DROP SEQUENCE IF EXISTS public.expenses_id_seq;
DROP TABLE IF EXISTS public.transactions;
DROP SEQUENCE IF EXISTS public.categories_id_seq;
DROP TABLE IF EXISTS public.categories;
DROP FUNCTION IF EXISTS public.spendmate_transaction_update(p_id integer, p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean);
DROP FUNCTION IF EXISTS public.spendmate_transaction_insert(p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean);
DROP FUNCTION IF EXISTS public.spendmate_transaction_gettotalbytype(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone, p_type character varying);
DROP FUNCTION IF EXISTS public.spendmate_transaction_getlist(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone);
DROP FUNCTION IF EXISTS public.spendmate_transaction_getbyid(p_id integer, p_userid integer);
DROP FUNCTION IF EXISTS public.spendmate_transaction_exportall(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone);
DROP FUNCTION IF EXISTS public.spendmate_transaction_delete(p_id integer, p_userid integer);
DROP FUNCTION IF EXISTS public.spendmate_report_getdata(p_type character varying);
DROP FUNCTION IF EXISTS public.spendmate_master_getcategories();
DROP FUNCTION IF EXISTS public.spendmate_dashboard_getdailytotal(p_userid integer);
DROP FUNCTION IF EXISTS public.spendmate_dashboard_getdailysummary(p_userid integer);
DROP FUNCTION IF EXISTS public.spendmate_dashboard_get6monthtrend(p_userid integer);
DROP FUNCTION IF EXISTS public.spendmate_config_getvalue(p_key character varying);
DROP FUNCTION IF EXISTS public.spendmate_budget_save_monthly(p_userid integer, p_year integer, p_month integer, p_group_type character varying, p_category character varying, p_target_amount numeric, p_is_paid boolean);
DROP FUNCTION IF EXISTS public.spendmate_budget_getmonthlyrecap(p_userid integer, p_year integer, p_month integer);
DROP FUNCTION IF EXISTS public.spendmate_automation_runrecurring(p_userid integer);
--
-- Name: spendmate_automation_runrecurring(integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_automation_runrecurring(p_userid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.spendmate_automation_runrecurring(p_userid integer) OWNER TO frankz168;

--
-- Name: spendmate_budget_getmonthlyrecap(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_budget_getmonthlyrecap(p_userid integer, p_year integer, p_month integer) RETURNS TABLE("Id" integer, "GroupType" character varying, "Category" character varying, "TargetAmount" numeric, "ActualAmount" numeric, "IsPaid" boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH MonthlyTx AS (
        SELECT t.category, SUM(t.amount) as actual_sum
        FROM transactions t
        WHERE t.userid = p_userid
          AND EXTRACT(YEAR FROM t.createdate) = p_year
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
        WHERE b.userid = p_userid AND b.year = p_year AND b.month = p_month
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
        ON c_master.id = b.category_id AND b.userid = p_userid AND b.year = p_year AND b.month = p_month
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


ALTER FUNCTION public.spendmate_budget_getmonthlyrecap(p_userid integer, p_year integer, p_month integer) OWNER TO frankz168;

--
-- Name: spendmate_budget_save_monthly(integer, integer, integer, character varying, character varying, numeric, boolean); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_budget_save_monthly(p_userid integer, p_year integer, p_month integer, p_group_type character varying, p_category character varying, p_target_amount numeric, p_is_paid boolean) RETURNS void
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


ALTER FUNCTION public.spendmate_budget_save_monthly(p_userid integer, p_year integer, p_month integer, p_group_type character varying, p_category character varying, p_target_amount numeric, p_is_paid boolean) OWNER TO frankz168;

--
-- Name: spendmate_config_getvalue(character varying); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_config_getvalue(p_key character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE val VARCHAR;
BEGIN
    SELECT ConfigValue INTO val
    FROM tbl_Settings_Config
    WHERE ConfigKey = p_key;
    
    RETURN val;
END;
$$;


ALTER FUNCTION public.spendmate_config_getvalue(p_key character varying) OWNER TO frankz168;

--
-- Name: spendmate_dashboard_get6monthtrend(integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_dashboard_get6monthtrend(p_userid integer) RETURNS TABLE(month character varying, income numeric, expense numeric)
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
        ON to_char(t.createdate, 'Mon YYYY') = m.mth AND t.userid = p_userid
    GROUP BY m.mth, m.sort_date
    ORDER BY m.sort_date;
END;
$$;


ALTER FUNCTION public.spendmate_dashboard_get6monthtrend(p_userid integer) OWNER TO frankz168;

--
-- Name: spendmate_dashboard_getdailysummary(integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_dashboard_getdailysummary(p_userid integer) RETURNS TABLE(category character varying, total numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.category,
        SUM(e.amount) AS total
    FROM transactions e
    WHERE e.userid = p_userid
      AND e.type = 'Expense'
      AND e.createdate::date = CURRENT_DATE
    GROUP BY e.category;
END;
$$;


ALTER FUNCTION public.spendmate_dashboard_getdailysummary(p_userid integer) OWNER TO frankz168;

--
-- Name: spendmate_dashboard_getdailytotal(integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_dashboard_getdailytotal(p_userid integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO total
    FROM transactions
    WHERE userid = p_userid
      AND type = 'Expense'
      AND createdate::date = CURRENT_DATE;

    RETURN total;
END;
$$;


ALTER FUNCTION public.spendmate_dashboard_getdailytotal(p_userid integer) OWNER TO frankz168;

--
-- Name: spendmate_master_getcategories(); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_master_getcategories() RETURNS TABLE("Id" integer, "Name" character varying, "GroupType" character varying, "DefaultTarget" numeric, "IsActive" boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY SELECT id, name, group_type, default_target, is_active FROM categories ORDER BY group_type, name;
END;
$$;


ALTER FUNCTION public.spendmate_master_getcategories() OWNER TO frankz168;

--
-- Name: spendmate_report_getdata(character varying); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_report_getdata(p_type character varying) RETURNS TABLE(category character varying, total numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.spendmate_report_getdata(p_type character varying) OWNER TO frankz168;

--
-- Name: spendmate_transaction_delete(integer, integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_delete(p_id integer, p_userid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM transactions 
    WHERE id = p_id AND userid = p_userid;
END;
$$;


ALTER FUNCTION public.spendmate_transaction_delete(p_id integer, p_userid integer) OWNER TO frankz168;

--
-- Name: spendmate_transaction_exportall(integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_exportall(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone) RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.userid = p_userid
      AND (p_from IS NULL OR t.createdate >= p_from)
      AND (p_to IS NULL OR t.createdate < p_to)
    ORDER BY t.createdate DESC;
END;
$$;


ALTER FUNCTION public.spendmate_transaction_exportall(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone) OWNER TO frankz168;

--
-- Name: spendmate_transaction_getbyid(integer, integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_getbyid(p_id integer, p_userid integer) RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.id = p_id AND t.userid = p_userid;
END;
$$;


ALTER FUNCTION public.spendmate_transaction_getbyid(p_id integer, p_userid integer) OWNER TO frankz168;

--
-- Name: spendmate_transaction_getlist(integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_getlist(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone) RETURNS TABLE(id integer, type character varying, amount numeric, category character varying, destination character varying, note text, createdate timestamp without time zone, is_recurring boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate, t.is_recurring
    FROM transactions t
    WHERE t.userid = p_userid
      AND t.createdate >= p_from
      AND t.createdate < p_to
    ORDER BY t.createdate DESC;
END;
$$;


ALTER FUNCTION public.spendmate_transaction_getlist(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone) OWNER TO frankz168;

--
-- Name: spendmate_transaction_gettotalbytype(integer, timestamp without time zone, timestamp without time zone, character varying); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_gettotalbytype(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone, p_type character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE total_amount NUMERIC;
BEGIN
    SELECT COALESCE(SUM(t.amount), 0) INTO total_amount
    FROM transactions t
    WHERE t.userid = p_userid
      AND t.type = p_type
      AND t.createdate >= p_from
      AND t.createdate < p_to;

    RETURN total_amount;
END;

$$;


ALTER FUNCTION public.spendmate_transaction_gettotalbytype(p_userid integer, p_from timestamp without time zone, p_to timestamp without time zone, p_type character varying) OWNER TO frankz168;

--
-- Name: spendmate_transaction_insert(integer, character varying, numeric, character varying, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_insert(p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE new_id INT;
BEGIN
    INSERT INTO transactions (userid, type, amount, category, destination, note, createdate, is_recurring)
    VALUES (p_userid, p_type, p_amount, p_category, p_destination, p_note, NOW(), p_is_recurring)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$;


ALTER FUNCTION public.spendmate_transaction_insert(p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean) OWNER TO frankz168;

--
-- Name: spendmate_transaction_update(integer, integer, character varying, numeric, character varying, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_transaction_update(p_id integer, p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean DEFAULT false) RETURNS void
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
    WHERE id = p_id AND userid = p_userid;
END;
$$;


ALTER FUNCTION public.spendmate_transaction_update(p_id integer, p_userid integer, p_type character varying, p_amount numeric, p_category character varying, p_destination character varying, p_note text, p_is_recurring boolean) OWNER TO frankz168;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: frankz168
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    group_type character varying(50) NOT NULL,
    default_target numeric(18,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    createdate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.categories OWNER TO frankz168;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: frankz168
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO frankz168;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: frankz168
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: frankz168
--

CREATE TABLE public.transactions (
    id integer CONSTRAINT expenses_id_not_null NOT NULL,
    userid integer CONSTRAINT expenses_userid_not_null NOT NULL,
    amount numeric(18,2) CONSTRAINT expenses_amount_not_null NOT NULL,
    category character varying(50) CONSTRAINT expenses_category_not_null NOT NULL,
    note text,
    createdate timestamp without time zone DEFAULT now(),
    type character varying(20) DEFAULT 'Expense'::character varying NOT NULL,
    destination character varying(100),
    is_recurring boolean DEFAULT false
);


ALTER TABLE public.transactions OWNER TO frankz168;

--
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: frankz168
--

CREATE SEQUENCE public.expenses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.expenses_id_seq OWNER TO frankz168;

--
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: frankz168
--

ALTER SEQUENCE public.expenses_id_seq OWNED BY public.transactions.id;


--
-- Name: monthly_budgets; Type: TABLE; Schema: public; Owner: frankz168
--

CREATE TABLE public.monthly_budgets (
    id integer NOT NULL,
    userid integer NOT NULL,
    year integer NOT NULL,
    month integer NOT NULL,
    category_id integer NOT NULL,
    target_amount numeric(18,2) DEFAULT 0 NOT NULL,
    is_paid boolean DEFAULT false NOT NULL
);


ALTER TABLE public.monthly_budgets OWNER TO frankz168;

--
-- Name: monthly_budgets_id_seq; Type: SEQUENCE; Schema: public; Owner: frankz168
--

CREATE SEQUENCE public.monthly_budgets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.monthly_budgets_id_seq OWNER TO frankz168;

--
-- Name: monthly_budgets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: frankz168
--

ALTER SEQUENCE public.monthly_budgets_id_seq OWNED BY public.monthly_budgets.id;


--
-- Name: tbl_settings_config; Type: TABLE; Schema: public; Owner: frankz168
--

CREATE TABLE public.tbl_settings_config (
    configkey character varying(100) NOT NULL,
    configvalue character varying(255) NOT NULL,
    description text,
    creator character varying(100) DEFAULT 'System'::character varying,
    createdate timestamp without time zone DEFAULT now(),
    auditor character varying(100),
    auditdate timestamp without time zone
);


ALTER TABLE public.tbl_settings_config OWNER TO frankz168;

--
-- Name: users; Type: TABLE; Schema: public; Owner: frankz168
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(100),
    phonenumber character varying(20) NOT NULL,
    createdate timestamp without time zone DEFAULT now(),
    username character varying(50),
    password_hash character varying(255)
);


ALTER TABLE public.users OWNER TO frankz168;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: frankz168
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO frankz168;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: frankz168
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: monthly_budgets id; Type: DEFAULT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.monthly_budgets ALTER COLUMN id SET DEFAULT nextval('public.monthly_budgets_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.expenses_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: frankz168
--

INSERT INTO public.categories VALUES (1, 'KPR HOME TENJO', 'Fixed', 6300000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (2, 'KPR HOME CRB', 'Fixed', 1200000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (3, 'GROCERIES MONTHLY', 'Fixed', 0.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (4, 'ELECTRIC TOKEN', 'Fixed', 500000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (5, 'PDAM', 'Fixed', 115800.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (6, 'TRANSPORT / GAS', 'Fixed', 150000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (7, 'FRANKY PARENTS', 'Fixed', 0.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (8, 'EVE PARENTS', 'Fixed', 4000000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (9, 'INTERNET & KUOTA', 'Fixed', 457000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (10, 'LAUNDRY', 'Fixed', 35000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (11, 'NANOVEST', 'Savings', 5000000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (12, 'GOLD 5GR', 'Savings', 12071625.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (13, 'SILVER 100GR', 'Savings', 6048000.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (14, 'DINING OUT', 'Variable', 0.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (15, 'RECREATION', 'Variable', 0.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (16, 'SHOPPING', 'Variable', 0.00, true, '2026-07-29 10:44:05.496882');
INSERT INTO public.categories VALUES (17, 'OTHERS', 'Variable', 0.00, true, '2026-07-29 13:12:48.096017');


--
-- Data for Name: monthly_budgets; Type: TABLE DATA; Schema: public; Owner: frankz168
--

INSERT INTO public.monthly_budgets VALUES (8, 1, 2026, 7, 8, 4000000.00, false);
INSERT INTO public.monthly_budgets VALUES (14, 1, 2026, 7, 14, 0.00, false);
INSERT INTO public.monthly_budgets VALUES (15, 1, 2026, 7, 15, 0.00, false);
INSERT INTO public.monthly_budgets VALUES (16, 1, 2026, 7, 16, 0.00, false);
INSERT INTO public.monthly_budgets VALUES (1, 1, 2026, 7, 1, 6300000.00, true);
INSERT INTO public.monthly_budgets VALUES (4, 1, 2026, 7, 4, 500000.00, true);
INSERT INTO public.monthly_budgets VALUES (5, 1, 2026, 7, 5, 115800.00, true);
INSERT INTO public.monthly_budgets VALUES (11, 1, 2026, 7, 11, 5000000.00, true);
INSERT INTO public.monthly_budgets VALUES (12, 1, 2026, 7, 12, 12071625.00, true);
INSERT INTO public.monthly_budgets VALUES (13, 1, 2026, 7, 13, 6048000.00, true);
INSERT INTO public.monthly_budgets VALUES (7, 1, 2026, 7, 7, 9000000.00, true);
INSERT INTO public.monthly_budgets VALUES (3, 1, 2026, 7, 3, 2200000.00, true);
INSERT INTO public.monthly_budgets VALUES (9, 1, 2026, 7, 9, 457000.00, true);
INSERT INTO public.monthly_budgets VALUES (2, 1, 2026, 7, 2, 1200000.00, true);
INSERT INTO public.monthly_budgets VALUES (10, 1, 2026, 7, 10, 35000.00, true);
INSERT INTO public.monthly_budgets VALUES (6, 1, 2026, 7, 6, 1000000.00, true);


--
-- Data for Name: tbl_settings_config; Type: TABLE DATA; Schema: public; Owner: frankz168
--

INSERT INTO public.tbl_settings_config VALUES ('Email_FromEmail', 'franky.sutanto93@gmail.com', 'System email address', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Email_Password', 'eyanrqtkkapeviyb', 'System email password (App Password)', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Email_SmtpHost', 'smtp.gmail.com', 'SMTP Server Host', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Email_SmtpPort', '587', 'SMTP Server Port', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Report_EmailTo', 'franky.sutanto93@gmail.com,evelineamalia0812@gmail.com', 'Comma-separated list of emails to receive reports', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Report_DailyTime', '07:10:00', 'Time to send daily report', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Report_WeeklyTime', '07:10:00', 'Time to send weekly report', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Report_MonthlyTime', '07:10:00', 'Time to send monthly report', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Report_WeeklyDay', '0', 'Day of week for weekly report (0=Sunday, 1=Monday, etc)', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('Report_MonthlyDay', '1', 'Day of month for monthly report', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);
INSERT INTO public.tbl_settings_config VALUES ('MonthlyBudget', '61260000', 'Total monthly expense budget', 'System', '2026-07-29 08:49:48.343552', NULL, NULL);


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: frankz168
--

INSERT INTO public.transactions VALUES (41, 1, 145850.00, 'SHOPPING', 'AEON STORE GUARDIAN VITAMIN AND CANDY', '2026-05-06 14:44:21.129208', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (45, 1, 66300.00, 'SHOPPING', 'ALPHA MIDI KRING GALON AND ZAITUN OIL', '2026-05-06 14:47:22.419238', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (31, 1, 500000.00, 'OTHERS', 'Electric May 2026', '2026-05-06 14:35:50.254644', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (46, 1, 882000.00, 'SHOPPING', 'AEON GROCERIES MONTHLY', '2026-05-06 14:47:54.704009', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (48, 1, 236000.00, 'SHOPPING', 'EVE TWO HOTPANS SHOPEE', '2026-05-06 14:50:35.815425', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (49, 1, 780000.00, 'SHOPPING', 'SHOPPING STAR TSHIRT AND ETC SMS', '2026-05-06 14:52:08.965275', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (56, 1, 400000.00, 'SHOPPING', 'Pizzaro 400k Tshirt', '2026-05-06 15:16:06.169569', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (58, 1, 85000.00, 'SHOPPING', 'Perfume Shopee May', '2026-05-06 15:26:27.074852', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (59, 1, 20800.00, 'SHOPPING', 'Pulsa 20k', '2026-05-06 15:27:23.204613', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (60, 1, 31500.00, 'SHOPPING', 'Pulsa 30k Telkomsel', '2026-05-06 15:27:49.968115', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (61, 1, 23000.00, 'SHOPPING', 'Black Glasses Shopee', '2026-05-06 15:28:44.385232', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (66, 1, 36000.00, 'SHOPPING', 'alfamidi bread & shampo', '2026-05-06 21:26:36.83189', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (69, 1, 25000.00, 'SHOPPING', 'shopee parfum', '2026-05-07 14:39:51.587157', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (76, 1, 55000.00, 'SHOPPING', 'aseton eve', '2026-05-10 23:07:17.818611', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (77, 1, 71000.00, 'SHOPPING', 'guardian lavojoy', '2026-05-10 23:07:41.395479', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (82, 1, 107000.00, 'SHOPPING', 'alfamidi', '2026-05-10 23:09:33.078894', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (83, 1, 216200.00, 'SHOPPING', 'natasha skincare', '2026-05-10 23:11:10.129384', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (84, 1, 90000.00, 'SHOPPING', 'xxi ticket', '2026-05-10 23:11:29.296601', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (98, 1, 153500.00, 'SHOPPING', 'alfamidi', '2026-05-20 16:56:27.533121', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (109, 1, 50000.00, 'SHOPPING', 'shopeepay case phone', '2026-05-20 17:04:21.298629', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (114, 1, 28700.00, 'SHOPPING', 'indomart', '2026-05-29 09:49:05.218725', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (135, 1, 111700.00, 'SHOPPING', 'skincare ponds shopee', '2026-05-29 10:01:37.161904', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (74, 1, 50000.00, 'TRANSPORT / GAS', 'e tol', '2026-05-10 23:05:46.786215', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (85, 1, 650000.00, 'TRANSPORT / GAS', 'gas BP', '2026-05-10 23:12:20.380303', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (91, 1, 50000.00, 'TRANSPORT / GAS', 'e tol', '2026-05-13 15:54:33.345079', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (99, 1, 50000.00, 'TRANSPORT / GAS', 'e tol', '2026-05-20 16:56:49.78043', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (103, 1, 50000.00, 'TRANSPORT / GAS', 'ovo grab car', '2026-05-20 16:59:35.990722', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (106, 1, 100000.00, 'TRANSPORT / GAS', 'e tol', '2026-05-20 17:01:20.806301', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (119, 1, 500000.00, 'TRANSPORT / GAS', 'e tol crb jkt', '2026-05-29 09:52:11.437977', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (32, 1, 55000.00, 'OTHERS', 'QRC YOUTAP', '2026-05-06 14:37:17.462918', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (33, 1, 100000.00, 'OTHERS', 'FLAZZ BCA', '2026-05-06 14:37:35.728289', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (36, 1, 110000.00, 'OTHERS', 'XXI SMS MUMMY MOVIE', '2026-05-06 14:39:49.494922', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (39, 1, 86846.00, 'OTHERS', 'LANNY HERMAN SUYAN', '2026-05-06 14:43:20.713505', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (44, 1, 100000.00, 'OTHERS', 'WITHDRAW CASH BCA ATM', '2026-05-06 14:45:56.270273', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (47, 1, 162800.00, 'OTHERS', 'PDAM MAY TENJO', '2026-05-06 14:49:43.814659', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (50, 1, 8000000.00, 'OTHERS', 'Mama May Expense', '2026-05-06 15:01:58.262451', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (52, 1, 2700000.00, 'OTHERS', 'Mama''s Credit Card DBS 2', '2026-05-06 15:03:09.01175', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (54, 1, 4000000.00, 'OTHERS', 'MAY EXPENSE EVE''S FAMILY', '2026-05-06 15:05:42.87621', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (55, 1, 5800000.00, 'OTHERS', 'Tenjo Podomoro''s House Installment', '2026-05-06 15:08:16.587983', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (51, 1, 100000.00, 'OTHERS', 'Mama''s Credit Card DBS 1', '2026-05-06 15:02:39.139134', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (57, 1, 547000.00, 'OTHERS', 'MCD Breakfast 16 May 2026 Cathering', '2026-05-06 15:16:32.517612', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (63, 1, 547000.00, 'OTHERS', 'Mcd Catering wedding', '2026-05-06 18:45:22.525384', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (67, 1, 35000.00, 'OTHERS', 'laundry blanket', '2026-05-07 14:30:01.793343', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (68, 1, 283050.00, 'OTHERS', 'indihome may', '2026-05-07 14:30:52.625306', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (73, 1, 133000.00, 'OTHERS', 'kuota xl eve', '2026-05-10 11:43:36.199545', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (75, 1, 22500.00, 'OTHERS', 'print promise wedding', '2026-05-10 23:06:49.129774', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (86, 1, 100000.00, 'OTHERS', 'GIFT CHURCH GBI', '2026-05-10 23:13:16.934493', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (90, 1, 7600.00, 'OTHERS', 'fotocopy ', '2026-05-13 15:54:11.753734', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (95, 1, 5000.00, 'OTHERS', 'Parking Immigration', '2026-05-13 17:03:51.182498', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (110, 1, 650000.00, 'OTHERS', 'car rent balance', '2026-05-20 17:05:10.178194', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (126, 1, 120000.00, 'OTHERS', 'my salon crb', '2026-05-29 09:55:52.313709', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (128, 1, 24800.00, 'OTHERS', 'snappy laminating', '2026-05-29 09:57:34.565629', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (131, 1, 1950000.00, 'OTHERS', 'paspor eve', '2026-05-29 09:58:42.468407', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (136, 1, 263600.00, 'OTHERS', 'krim natasha eve', '2026-05-29 10:02:25.468398', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (139, 1, 600000.00, 'TRANSPORT / GAS', 'Gas Camry BP ', '2026-05-29 11:28:42.263348', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (137, 1, 23800.00, 'SHOPPING', 'kantong sampah shopee', '2026-05-29 10:03:02.555306', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (143, 1, 34900.00, 'SHOPPING', 'alfamidi', '2026-05-31 19:05:56.232737', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (157, 1, 194000.00, 'SHOPPING', 'alfamidi', '2026-06-02 20:13:47.469035', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (158, 1, 692423.00, 'SHOPPING', 'spaylater', '2026-06-02 20:18:18.075966', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (160, 1, 28800.00, 'SHOPPING', 'shopee', '2026-06-09 13:36:35.413511', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (169, 1, 60800.00, 'SHOPPING', 'galon alfamidi', '2026-06-09 13:40:57.275821', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (170, 1, 73700.00, 'SHOPPING', 'case ipad shopee', '2026-06-09 13:41:26.579951', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (171, 1, 60000.00, 'SHOPPING', 'miniso laci ', '2026-06-09 13:43:27.796549', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (176, 1, 110300.00, 'SHOPPING', 'galon + sayur alfamidi ', '2026-06-09 13:45:54.61772', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (178, 1, 90000.00, 'SHOPPING', 'ticket cinema', '2026-06-09 13:49:40.58797', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (179, 1, 915000.00, 'SHOPPING', 'aeon groceries', '2026-06-09 13:49:59.987479', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (181, 1, 156000.00, 'SHOPPING', 'Tokopedia Shopping 1 Temperred Glass Ipad', '2026-06-09 19:09:34.78764', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (182, 1, 167000.00, 'SHOPPING', 'Tokopedia SH 2', '2026-06-09 19:10:08.035565', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (183, 1, 91000.00, 'SHOPPING', 'Tokopedia SH 3', '2026-06-09 19:10:25.781874', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (186, 1, 369000.00, 'SHOPPING', 'Oli Camry', '2026-06-09 19:13:55.624985', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (187, 1, 111000.00, 'SHOPPING', 'Filter Oli Camry', '2026-06-09 19:14:07.523979', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (189, 1, 1100000.00, 'SHOPPING', 'groceries aeon', '2026-06-22 15:02:29.512955', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (190, 1, 50000.00, 'SHOPPING', 'ovo', '2026-06-22 15:02:54.909354', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (192, 1, 122400.00, 'SHOPPING', 'galon + vegetable', '2026-06-22 15:04:08.378625', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (197, 1, 153000.00, 'SHOPPING', 'aeon', '2026-06-22 15:07:27.670007', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (198, 1, 331000.00, 'SHOPPING', 'groceries aeon', '2026-06-22 15:08:13.81612', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (204, 1, 142600.00, 'SHOPPING', 'milk n coffe k3mart', '2026-06-22 15:12:54.53503', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (206, 1, 27000.00, 'SHOPPING', 'vegetable alfamidi', '2026-06-22 15:13:49.324783', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (209, 1, 41500.00, 'SHOPPING', 'galon alfamidi', '2026-06-30 13:42:36.94209', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (214, 1, 57800.00, 'SHOPPING', 'groceries alfamidi', '2026-06-30 13:45:33.443527', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (230, 1, 82200.00, 'SHOPPING', 'Shopee obat pel', '2026-07-10 16:36:16.454831', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (241, 1, 40000.00, 'SHOPPING', 'Cloth eve', '2026-07-10 16:41:45.666358', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (246, 1, 77000.00, 'SHOPPING', 'Cloth eve', '2026-07-10 16:44:21.934878', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (173, 1, 50000.00, 'TRANSPORT / GAS', 'e tol', '2026-06-09 13:44:24.488483', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (205, 1, 50000.00, 'TRANSPORT / GAS', 'e tol', '2026-06-22 15:13:05.528927', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (235, 1, 50000.00, 'TRANSPORT / GAS', 'E tol', '2026-07-10 16:39:01.298185', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (138, 1, 1400000.00, 'OTHERS', 'Verse Hotel Cirebon', '2026-05-29 11:28:30.819404', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (140, 1, 500000.00, 'OTHERS', 'Electric May', '2026-05-31 19:02:36.794916', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (141, 1, 31000.00, 'OTHERS', 'Pulsa XL Franky', '2026-05-31 19:02:49.086768', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (149, 1, 2000000.00, 'OTHERS', 'Pay DBS Credit Card', '2026-06-01 18:40:50.524762', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (150, 1, 2720000.00, 'OTHERS', 'DBS Credit Card 2', '2026-06-01 18:41:28.498859', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (152, 1, 8000000.00, 'OTHERS', 'Franky''s Parents Expense', '2026-06-01 18:42:31.570399', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (151, 1, 4000000.00, 'OTHERS', 'Eve''s Parents Expense', '2026-06-01 18:42:11.788695', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (153, 1, 125000.00, 'OTHERS', 'PDAM Tenjo Cluster Damar', '2026-06-01 18:43:14.241692', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (154, 1, 17000.00, 'OTHERS', 'Admin''s Fee BCA', '2026-06-01 18:43:26.470969', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (159, 1, 70000.00, 'OTHERS', 'laundry ', '2026-06-09 13:36:02.750187', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (174, 1, 189000.00, 'OTHERS', 'kuota xl', '2026-06-09 13:44:57.060244', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (175, 1, 286000.00, 'OTHERS', 'indihome', '2026-06-09 13:45:19.37038', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (180, 1, 820000.00, 'OTHERS', 'Kartu Kredit SQ Franky', '2026-06-09 19:07:32.655487', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (184, 1, 150000.00, 'OTHERS', 'Cutting Grass Tenjo', '2026-06-09 19:10:43.710916', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (185, 1, 1012000.00, 'OTHERS', 'Electric Franky''s Parents', '2026-06-09 19:13:29.27618', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (194, 1, 10000.00, 'OTHERS', 'xl repair card', '2026-06-22 15:05:00.849472', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (211, 1, 500000.00, 'OTHERS', 'token electric', '2026-06-30 13:44:15.464093', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (223, 1, 237300.00, 'OTHERS', 'Cream natasha', '2026-07-10 16:30:36.412468', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (224, 1, 157000.00, 'OTHERS', 'Alfamidi', '2026-07-10 16:31:11.011391', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (229, 1, 65800.00, 'OTHERS', 'Alfamidi', '2026-07-10 16:35:39.805762', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (233, 1, 16000.00, 'OTHERS', 'Alfamidi', '2026-07-10 16:38:10.589841', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (242, 1, 163400.00, 'OTHERS', 'Alfamidi', '2026-07-10 16:42:24.25177', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (258, 1, 800000.00, 'TRANSPORT / GAS', 'Gas Camry 49 Liters', '2026-07-10 17:04:56.386812', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (259, 1, 135100.00, 'SHOPPING', 'Wiper camry', '2026-07-10 17:05:32.450729', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (261, 1, 510000.00, 'SHOPPING', 'Azko Rubber and Stopkontak', '2026-07-10 17:07:18.20023', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (35, 1, 18000.00, 'DINING OUT', 'DRINK SMS MINERAL WATER', '2026-05-06 14:38:56.901099', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (37, 1, 50000.00, 'DINING OUT', 'OVO DONER KEBAB DINNER SMS', '2026-05-06 14:40:31.498232', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (38, 1, 69500.00, 'DINING OUT', 'EL BAKERY PODOMORO TENJO', '2026-05-06 14:41:27.378523', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (40, 1, 226600.00, 'DINING OUT', 'SOTO BETAWI EBET BSD ', '2026-05-06 14:43:51.648178', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (42, 1, 33000.00, 'DINING OUT', 'GO COCO AEON MALL', '2026-05-06 14:45:09.365434', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (43, 1, 47000.00, 'DINING OUT', 'SHILIN AEON XXL CHICKEN BBQ', '2026-05-06 14:45:30.953878', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (117, 1, 200000.00, 'DINING OUT', 'arunika crb ticket', '2026-05-29 09:50:30.247725', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (34, 1, 81000.00, 'DINING OUT', 'BOGANA ', '2026-05-06 14:37:57.621875', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (64, 1, 12000.00, 'DINING OUT', 'matcha tenjo foodcourt', '2026-05-06 21:25:40.328954', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (65, 1, 16000.00, 'DINING OUT', 'bingxue sundae', '2026-05-06 21:26:08.804319', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (70, 1, 148000.00, 'DINING OUT', 'dinner seafood tenjo', '2026-05-08 19:46:30.968271', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (71, 1, 10000.00, 'DINING OUT', 'fruit ice tenjo', '2026-05-08 19:46:51.2009', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (72, 1, 48000.00, 'DINING OUT', 'el bakery', '2026-05-08 19:47:15.012942', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (78, 1, 55000.00, 'DINING OUT', 'kwetiaw aho', '2026-05-10 23:08:04.006787', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (79, 1, 63500.00, 'DINING OUT', 'bakmi gm', '2026-05-10 23:08:22.020085', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (80, 1, 73000.00, 'DINING OUT', 'popcorn xxi', '2026-05-10 23:08:48.48119', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (81, 1, 101000.00, 'DINING OUT', 'jco donut', '2026-05-10 23:09:09.270584', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (87, 1, 22000.00, 'DINING OUT', 'fruit ice and uduk rice tenjo', '2026-05-11 19:22:24.349051', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (89, 1, 360000.00, 'DINING OUT', 'ketan bumbu', '2026-05-13 15:53:51.882595', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (93, 1, 39000.00, 'DINING OUT', 'ginger candy + le mineral', '2026-05-13 15:55:51.346719', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (88, 1, 216000.00, 'DINING OUT', 'hachi grill', '2026-05-13 15:53:37.404216', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (92, 1, 18000.00, 'DINING OUT', 'eat nasi rames', '2026-05-13 15:55:09.332619', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (94, 1, 18000.00, 'DINING OUT', 'Porridge + le mineral Immigration', '2026-05-13 17:03:22.774422', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (96, 1, 24000.00, 'DINING OUT', 'ice cream aeon', '2026-05-14 11:34:25.420626', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (97, 1, 209000.00, 'DINING OUT', 'pop corn + cinema ticket', '2026-05-14 11:35:29.816591', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (100, 1, 281500.00, 'DINING OUT', 'nasi uduk kribo', '2026-05-20 16:57:19.352912', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (101, 1, 160000.00, 'DINING OUT', 'mcd', '2026-05-20 16:57:43.775649', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (102, 1, 218300.00, 'DINING OUT', 'eat foo heng puri', '2026-05-20 16:58:19.821078', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (104, 1, 212000.00, 'DINING OUT', 'bakmi keriting akhai', '2026-05-20 17:00:15.453467', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (105, 1, 63000.00, 'DINING OUT', 'ice cream n coffe indomart', '2026-05-20 17:00:51.144971', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (107, 1, 275000.00, 'DINING OUT', 'nasi uduk senusantara pik', '2026-05-20 17:02:22.673073', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (108, 1, 107000.00, 'DINING OUT', 'galon alfamidi', '2026-05-20 17:02:55.393017', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (111, 1, 81000.00, 'DINING OUT', 'sambar bakar dinner tenjo', '2026-05-20 18:47:08.140324', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (112, 1, 23500.00, 'DINING OUT', 'roti bakar 88 tenjo', '2026-05-20 18:47:26.323229', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (113, 1, 112000.00, 'DINING OUT', 'el bakery bread tenjo', '2026-05-20 18:47:41.834138', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (115, 1, 356000.00, 'DINING OUT', 'resto joglo arunika crb', '2026-05-29 09:49:34.819673', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (116, 1, 195000.00, 'DINING OUT', 'ketan bumbu crb', '2026-05-29 09:49:55.021509', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (118, 1, 193000.00, 'DINING OUT', 'nasi lengko crb', '2026-05-29 09:50:59.167732', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (120, 1, 175000.00, 'DINING OUT', 'swike mawar crb', '2026-05-29 09:52:32.446633', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (121, 1, 100000.00, 'DINING OUT', 'grab food crb', '2026-05-29 09:53:11.915297', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (122, 1, 141900.00, 'DINING OUT', 'empal gentong crb', '2026-05-29 09:53:51.621158', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (123, 1, 117000.00, 'DINING OUT', 'mie koclok crb', '2026-05-29 09:54:14.890485', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (124, 1, 138000.00, 'DINING OUT', 'roti bakar gaternia crb', '2026-05-29 09:54:42.045334', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (125, 1, 55000.00, 'DINING OUT', 'tous les jours crb', '2026-05-29 09:55:20.717937', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (127, 1, 60500.00, 'DINING OUT', 'mcd rest area', '2026-05-29 09:56:35.016031', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (129, 1, 16500.00, 'DINING OUT', 'mcd ', '2026-05-29 09:57:58.462239', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (130, 1, 36500.00, 'DINING OUT', 'mcd', '2026-05-29 09:58:13.279471', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (132, 1, 15000.00, 'DINING OUT', 'siomay imigration', '2026-05-29 09:59:15.584192', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (133, 1, 110000.00, 'DINING OUT', 'hokben', '2026-05-29 09:59:40.978906', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (134, 1, 288000.00, 'DINING OUT', 'oleh2 boncherry crb', '2026-05-29 10:00:49.668485', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (142, 1, 20000.00, 'DINING OUT', 'nasi uduk ', '2026-05-31 19:05:08.477395', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (144, 1, 60000.00, 'DINING OUT', 'nasi padang', '2026-05-31 19:06:40.220361', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (145, 1, 49000.00, 'DINING OUT', 'el bakery', '2026-05-31 19:06:57.821336', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (147, 1, 50000.00, 'DINING OUT', 'bakmie bon', '2026-05-31 19:08:18.054488', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (148, 1, 53000.00, 'DINING OUT', 'dkriuk chicken', '2026-05-31 19:08:39.414818', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (155, 1, 30000.00, 'DINING OUT', 'smooties juice', '2026-06-02 20:12:56.488577', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (156, 1, 18000.00, 'DINING OUT', 'mc n cheese food court', '2026-06-02 20:13:20.866252', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (249, 1, 35000.00, 'OTHERS', 'Laundry', '2026-07-10 16:45:44.14526', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (250, 1, 4000000.00, 'OTHERS', 'Eve''s July Expense Parents', '2026-07-10 16:57:09.707224', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (251, 1, 8000000.00, 'OTHERS', 'Franky''s Parent July Expense', '2026-07-10 16:57:49.250555', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (252, 1, 2300000.00, 'OTHERS', 'Camry Franky Tax July', '2026-07-10 16:58:10.108538', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (253, 1, 724000.00, 'OTHERS', 'Final Fantasy vii rebirth trf Vita', '2026-07-10 16:58:46.02579', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (161, 1, 98000.00, 'DINING OUT', 'food', '2026-06-09 13:37:09.565516', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (162, 1, 15000.00, 'DINING OUT', 'food', '2026-06-09 13:37:26.445112', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (163, 1, 24000.00, 'DINING OUT', 'pecel lele', '2026-06-09 13:37:54.936435', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (164, 1, 40000.00, 'DINING OUT', 'nasi uduk + jus', '2026-06-09 13:38:11.599276', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (165, 1, 70000.00, 'DINING OUT', 'martabak pacenongan', '2026-06-09 13:38:39.165841', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (166, 1, 140500.00, 'DINING OUT', 'roti bakar 88', '2026-06-09 13:39:10.808726', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (167, 1, 25000.00, 'DINING OUT', 'ell bakery', '2026-06-09 13:39:41.888371', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (168, 1, 31500.00, 'DINING OUT', 'roti + panadol indomart', '2026-06-09 13:40:15.782822', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (172, 1, 103000.00, 'DINING OUT', 'bakso lapangan tembak', '2026-06-09 13:44:09.180498', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (177, 1, 85000.00, 'DINING OUT', 'popcorn cinema', '2026-06-09 13:49:09.801822', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (188, 1, 20000.00, 'DINING OUT', 'ice cream MCD Aeon 16 June', '2026-06-22 11:13:24.032284', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (191, 1, 55000.00, 'DINING OUT', 'eat outside', '2026-06-22 15:03:29.411976', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (193, 1, 80000.00, 'DINING OUT', 'ovo', '2026-06-22 15:04:30.724637', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (195, 1, 54000.00, 'DINING OUT', 'doner kebab aeon', '2026-06-22 15:05:27.212528', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (196, 1, 52000.00, 'DINING OUT', 'eat aeon', '2026-06-22 15:06:15.096131', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (199, 1, 25000.00, 'DINING OUT', 'dodol tenjo', '2026-06-22 15:08:43.059174', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (200, 1, 64000.00, 'DINING OUT', 'eat outside', '2026-06-22 15:09:11.464045', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (201, 1, 83000.00, 'DINING OUT', 'bakmi bangka', '2026-06-22 15:09:41.926962', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (202, 1, 71000.00, 'DINING OUT', 'pizza tenjo', '2026-06-22 15:10:03.623037', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (203, 1, 50000.00, 'DINING OUT', 'ketoprak', '2026-06-22 15:11:24.666279', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (207, 1, 377000.00, 'DINING OUT', 'Mr Dakgalbi Lippo Mall Puri Parents', '2026-06-22 16:31:26.920064', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (208, 1, 61000.00, 'DINING OUT', 'eat outside tenjo', '2026-06-30 13:42:10.729499', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (210, 1, 20000.00, 'DINING OUT', 'bingxue', '2026-06-30 13:42:51.227684', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (212, 1, 71000.00, 'DINING OUT', 'soto ojolali', '2026-06-30 13:44:41.880722', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (213, 1, 36000.00, 'DINING OUT', 'jajan food court', '2026-06-30 13:45:07.795371', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (215, 1, 45000.00, 'DINING OUT', 'food', '2026-06-30 13:47:50.250747', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (216, 1, 39000.00, 'DINING OUT', 'bingxue', '2026-06-30 13:48:17.195769', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (217, 1, 81000.00, 'DINING OUT', 'bakmie bangka', '2026-06-30 13:48:57.918211', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (218, 1, 57000.00, 'DINING OUT', 'kopi kenangan', '2026-06-30 13:49:41.914957', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (227, 1, 175000.00, 'DINING OUT', 'Eat outside tenjo', '2026-07-10 16:34:04.103657', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (219, 1, 250000.00, 'DINING OUT', 'Mama''s Eve Cake Birthday Holland Double Choco', '2026-06-30 14:14:11.25307', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (225, 1, 11000.00, 'DINING OUT', 'Bingxue', '2026-07-10 16:33:10.139415', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (226, 1, 35000.00, 'DINING OUT', 'El bakery', '2026-07-10 16:33:39.524066', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (228, 1, 45000.00, 'DINING OUT', 'Nasi uduk ruko tenjo', '2026-07-10 16:35:06.797008', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (231, 1, 125000.00, 'DINING OUT', 'Cendol tenjo', '2026-07-10 16:36:52.865959', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (232, 1, 40000.00, 'DINING OUT', 'Food', '2026-07-10 16:37:18.935071', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (234, 1, 30000.00, 'DINING OUT', 'Kebab tenjo', '2026-07-10 16:38:35.037271', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (236, 1, 90000.00, 'DINING OUT', 'Nasi babi Bali aeon', '2026-07-10 16:39:38.315481', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (237, 1, 75000.00, 'DINING OUT', 'Nasi campur aeon', '2026-07-10 16:39:54.925994', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (238, 1, 55000.00, 'DINING OUT', 'Es krim duren aeon', '2026-07-10 16:40:19.040923', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (239, 1, 14000.00, 'DINING OUT', 'Es krim aeon', '2026-07-10 16:40:33.021034', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (240, 1, 1120000.00, 'OTHERS', 'Groceries aeon', '2026-07-10 16:41:17.095639', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (243, 1, 171000.00, 'OTHERS', 'Xl kuota', '2026-07-10 16:43:11.651653', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (244, 1, 134000.00, 'OTHERS', 'Xl kuota pap eve', '2026-07-10 16:43:41.45098', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (245, 1, 286000.00, 'OTHERS', 'Indihome', '2026-07-10 16:44:01.68573', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (247, 1, 41000.00, 'OTHERS', 'Toner ponds', '2026-07-10 16:44:51.808957', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (248, 1, 80000.00, 'OTHERS', 'Jastip market tenjo', '2026-07-10 16:45:27.208987', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (254, 1, 6300000.00, 'OTHERS', 'July 2026 installment Tenjo House', '2026-07-10 17:00:04.479022', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (255, 1, 1050000.00, 'OTHERS', 'Electric Franky''s Parent', '2026-07-10 17:01:48.775949', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (256, 1, 4720000.00, 'OTHERS', 'Credit Card DBS Mama Franky', '2026-07-10 17:03:09.030301', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (257, 1, 116000.00, 'OTHERS', 'PDAM Tenjo Bogor Damar', '2026-07-10 17:04:31.533103', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (260, 1, 100000.00, 'OTHERS', 'Gift Church GBI The Breeze', '2026-07-10 17:06:52.477289', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (262, 1, 1800000.00, 'OTHERS', 'CC Franky BCA ', '2026-07-10 17:07:40.855765', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (263, 1, 500000.00, 'OTHERS', 'Electric Token July Franky''s Family', '2026-07-10 17:33:09.647088', 'Expense', NULL, false);
INSERT INTO public.transactions VALUES (264, 1, 1300000.00, 'OTHERS', 'MayBank Ipad + Switch', '2026-07-10 17:39:19.986148', 'Expense', '', false);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: frankz168
--

INSERT INTO public.users VALUES (1, 'Franky', '08123456789', '2026-05-03 18:43:16.232287', 'franky', '$2a$11$NT/573MY5bX1GAFwNBJQOe5rKaGrf/BZuSZfmhTu0od7YiCOgVrfm');


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: frankz168
--

SELECT pg_catalog.setval('public.categories_id_seq', 17, true);


--
-- Name: expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: frankz168
--

SELECT pg_catalog.setval('public.expenses_id_seq', 266, true);


--
-- Name: monthly_budgets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: frankz168
--

SELECT pg_catalog.setval('public.monthly_budgets_id_seq', 24, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: frankz168
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: transactions expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);


--
-- Name: monthly_budgets monthly_budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.monthly_budgets
    ADD CONSTRAINT monthly_budgets_pkey PRIMARY KEY (id);


--
-- Name: monthly_budgets monthly_budgets_userid_year_month_category_id_key; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.monthly_budgets
    ADD CONSTRAINT monthly_budgets_userid_year_month_category_id_key UNIQUE (userid, year, month, category_id);


--
-- Name: tbl_settings_config tbl_settings_config_pkey; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.tbl_settings_config
    ADD CONSTRAINT tbl_settings_config_pkey PRIMARY KEY (configkey);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_transactions_createdate; Type: INDEX; Schema: public; Owner: frankz168
--

CREATE INDEX idx_transactions_createdate ON public.transactions USING btree (createdate);


--
-- Name: idx_transactions_user_date; Type: INDEX; Schema: public; Owner: frankz168
--

CREATE INDEX idx_transactions_user_date ON public.transactions USING btree (userid, createdate);


--
-- Name: idx_transactions_userid; Type: INDEX; Schema: public; Owner: frankz168
--

CREATE INDEX idx_transactions_userid ON public.transactions USING btree (userid);


--
-- Name: transactions fk_user; Type: FK CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_user FOREIGN KEY (userid) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: monthly_budgets monthly_budgets_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: frankz168
--

ALTER TABLE ONLY public.monthly_budgets
    ADD CONSTRAINT monthly_budgets_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict xVyziJTJjtHf4q1FewjOTj61lNdSAMc7gOoW2xTgaTJ2ESX5Rmu4rw7ydTbIGdN

