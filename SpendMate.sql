CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    phonenumber VARCHAR(20) NOT NULL,
    createdate TIMESTAMP DEFAULT NOW()
);

CREATE TABLE expenses (
    id SERIAL PRIMARY KEY,
    userid INT NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    category VARCHAR(50) NOT NULL,
    note TEXT,
    createdate TIMESTAMP DEFAULT NOW(),

    CONSTRAINT fk_user
        FOREIGN KEY(userid)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_expenses_userid ON expenses(userid);
CREATE INDEX idx_expenses_createdate ON expenses(createdate);
CREATE INDEX idx_expenses_user_date ON expenses(userid, createdate);

INSERT INTO users (name, phonenumber)
VALUES ('Franky', '08123456789');

INSERT INTO expenses (userid, amount, category, note)
VALUES (1, 150000, 'Makan', 'Lunch'),
       (1, 100000, 'Transport', 'Grab'),
       (1, 50000, 'Lainnya', 'Kopi');

CREATE OR REPLACE FUNCTION insert_expense(
    p_userid INT,
    p_amount NUMERIC,
    p_category VARCHAR,
    p_note TEXT
)
RETURNS INT AS
$$
DECLARE new_id INT;
BEGIN
    INSERT INTO expenses (userid, amount, category, note, createdate)
    VALUES (p_userid, p_amount, p_category, p_note, NOW())
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_daily_summary(p_userid INT)
RETURNS TABLE (
    category VARCHAR,
    total DECIMAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.category,               -- ✅ kasih alias table
        SUM(e.amount) AS total   -- ✅ kasih alias result
    FROM expenses e              -- ✅ alias table
    WHERE e.userid = p_userid
      AND e.createdate::date = CURRENT_DATE
    GROUP BY e.category;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_daily_total(p_userid INT)
RETURNS NUMERIC AS
$$
DECLARE total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO total
    FROM expenses
    WHERE userid = p_userid
      AND createdate::date = CURRENT_DATE;

    RETURN total;
END;
$$ LANGUAGE plpgsql;