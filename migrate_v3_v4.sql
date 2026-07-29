-- V3 MIGRATION
CREATE TABLE IF NOT EXISTS tbl_Settings_Config (
    ConfigKey VARCHAR(100) PRIMARY KEY,
    ConfigValue VARCHAR(255) NOT NULL,
    Description TEXT,
    Creator VARCHAR(100) DEFAULT 'System',
    CreateDate TIMESTAMP DEFAULT NOW(),
    Auditor VARCHAR(100),
    AuditDate TIMESTAMP
);

-- Use INSERT ON CONFLICT DO NOTHING to avoid duplicate key errors
INSERT INTO tbl_Settings_Config (ConfigKey, ConfigValue, Description) VALUES
('Email_FromEmail', 'franky.sutanto93@gmail.com', 'System email address'),
('Email_Password', 'eyanrqtkkapeviyb', 'System email password (App Password)'),
('Email_SmtpHost', 'smtp.gmail.com', 'SMTP Server Host'),
('Email_SmtpPort', '587', 'SMTP Server Port'),
('Report_EmailTo', 'franky.sutanto93@gmail.com,evelineamalia0812@gmail.com', 'Comma-separated list of emails to receive reports'),
('Report_DailyTime', '07:10:00', 'Time to send daily report'),
('Report_WeeklyTime', '07:10:00', 'Time to send weekly report'),
('Report_MonthlyTime', '07:10:00', 'Time to send monthly report'),
('Report_WeeklyDay', '0', 'Day of week for weekly report (0=Sunday, 1=Monday, etc)'),
('Report_MonthlyDay', '1', 'Day of month for monthly report'),
('MonthlyBudget', '61260000', 'Total monthly expense budget')
ON CONFLICT (ConfigKey) DO NOTHING;

-- V4 MIGRATION
CREATE OR REPLACE FUNCTION get_config_value(p_key VARCHAR)
RETURNS VARCHAR AS
$$
DECLARE val VARCHAR;
BEGIN
    SELECT ConfigValue INTO val
    FROM tbl_Settings_Config
    WHERE ConfigKey = p_key;
    
    RETURN val;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_report_data(p_type VARCHAR)
RETURNS TABLE (
    category VARCHAR,
    total DECIMAL
)
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
        WHERE t.createdate >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY t.category;
    ELSE
        RAISE EXCEPTION 'Invalid report type';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_transactions(p_userid INT, p_from TIMESTAMP, p_to TIMESTAMP)
RETURNS TABLE (
    id INT,
    type VARCHAR,
    amount DECIMAL,
    category VARCHAR,
    destination VARCHAR,
    note TEXT,
    createdate TIMESTAMP
)
AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate
    FROM transactions t
    WHERE t.userid = p_userid
      AND t.createdate >= p_from
      AND t.createdate < p_to
    ORDER BY t.createdate DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_transaction_by_id(p_id INT, p_userid INT)
RETURNS TABLE (
    id INT,
    type VARCHAR,
    amount DECIMAL,
    category VARCHAR,
    destination VARCHAR,
    note TEXT,
    createdate TIMESTAMP
)
AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.type, t.amount, t.category, t.destination, t.note, t.createdate
    FROM transactions t
    WHERE t.id = p_id AND t.userid = p_userid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_transaction(
    p_id INT,
    p_userid INT,
    p_type VARCHAR,
    p_amount NUMERIC,
    p_category VARCHAR,
    p_destination VARCHAR,
    p_note TEXT
)
RETURNS VOID AS
$$
BEGIN
    UPDATE transactions
    SET type = p_type,
        amount = p_amount,
        category = p_category,
        destination = p_destination,
        note = p_note
    WHERE id = p_id AND userid = p_userid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_transaction(p_id INT, p_userid INT)
RETURNS VOID AS
$$
BEGIN
    DELETE FROM transactions 
    WHERE id = p_id AND userid = p_userid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_for_export(p_userid INT, p_from TIMESTAMP DEFAULT NULL, p_to TIMESTAMP DEFAULT NULL)
RETURNS TABLE (
    createdate TIMESTAMP,
    type VARCHAR,
    category VARCHAR,
    destination VARCHAR,
    amount DECIMAL,
    note TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT t.createdate, t.type, t.category, t.destination, t.amount, t.note
    FROM transactions t
    WHERE t.userid = p_userid
      AND (p_from IS NULL OR t.createdate >= p_from)
      AND (p_to IS NULL OR t.createdate <= p_to)
    ORDER BY t.createdate DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_total_by_type(p_userid INT, p_from TIMESTAMP, p_to TIMESTAMP, p_type VARCHAR)
RETURNS NUMERIC AS
$$
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
$$ LANGUAGE plpgsql;
