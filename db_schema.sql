--
-- PostgreSQL database dump
--

\restrict 1qAOtehbSJuH2tvibd3phVhMnQeELYTxKnnN1DzgRbwRVTl7lhICBJZCFJnxNUD

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
-- Name: spendmate_report_getdata(character varying, integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_report_getdata(p_type character varying, p_userid integer) RETURNS TABLE(category character varying, total numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.spendmate_report_getdata(p_type character varying, p_userid integer) OWNER TO frankz168;

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

--
-- Name: spendmate_user_delete(integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_user_delete(p_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM users WHERE id = p_id;
END;
$$;


ALTER FUNCTION public.spendmate_user_delete(p_id integer) OWNER TO frankz168;

--
-- Name: spendmate_user_getall(); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_user_getall() RETURNS TABLE(id integer, name character varying, phonenumber character varying, username character varying, createdate timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.name, 
        u.phonenumber, 
        u.username, 
        u.createdate 
    FROM users u
    ORDER BY u.createdate DESC;
END;
$$;


ALTER FUNCTION public.spendmate_user_getall() OWNER TO frankz168;

--
-- Name: spendmate_user_getbyid(integer); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_user_getbyid(p_id integer) RETURNS TABLE(id integer, name character varying, phonenumber character varying, username character varying, passwordhash character varying, createdate timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.name, 
        u.phonenumber, 
        u.username, 
        u.password_hash as PasswordHash, 
        u.createdate 
    FROM users u
    WHERE u.id = p_id;
END;
$$;


ALTER FUNCTION public.spendmate_user_getbyid(p_id integer) OWNER TO frankz168;

--
-- Name: spendmate_user_getbyusername(character varying); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_user_getbyusername(p_username character varying) RETURNS TABLE(id integer, name character varying, phonenumber character varying, username character varying, passwordhash character varying, createdate timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id, 
        u.name, 
        u.phonenumber, 
        u.username, 
        u.password_hash as PasswordHash, 
        u.createdate 
    FROM users u
    WHERE u.username = p_username;
END;
$$;


ALTER FUNCTION public.spendmate_user_getbyusername(p_username character varying) OWNER TO frankz168;

--
-- Name: spendmate_user_insert(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_user_insert(p_name character varying, p_phonenumber character varying, p_username character varying, p_password_hash character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO users (name, phonenumber, username, password_hash)
    VALUES (p_name, p_phonenumber, p_username, p_password_hash);
END;
$$;


ALTER FUNCTION public.spendmate_user_insert(p_name character varying, p_phonenumber character varying, p_username character varying, p_password_hash character varying) OWNER TO frankz168;

--
-- Name: spendmate_user_update(integer, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: frankz168
--

CREATE FUNCTION public.spendmate_user_update(p_id integer, p_name character varying, p_phonenumber character varying, p_username character varying, p_password_hash character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_password_hash IS NOT NULL AND p_password_hash != '' THEN
        UPDATE users 
        SET name = p_name, 
            phonenumber = p_phonenumber, 
            username = p_username, 
            password_hash = p_password_hash
        WHERE id = p_id;
    ELSE
        UPDATE users 
        SET name = p_name, 
            phonenumber = p_phonenumber, 
            username = p_username
        WHERE id = p_id;
    END IF;
END;
$$;


ALTER FUNCTION public.spendmate_user_update(p_id integer, p_name character varying, p_phonenumber character varying, p_username character varying, p_password_hash character varying) OWNER TO frankz168;

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

\unrestrict 1qAOtehbSJuH2tvibd3phVhMnQeELYTxKnnN1DzgRbwRVTl7lhICBJZCFJnxNUD

