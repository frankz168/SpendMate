-- 1. Drop old functions first (they depend on monthly_budgets)
DROP FUNCTION IF EXISTS get_monthly_recap(INT, INT, INT);
DROP FUNCTION IF EXISTS save_monthly_budget(INT, INT, INT, VARCHAR, VARCHAR, NUMERIC, BOOLEAN);

-- 2. Drop old table
DROP TABLE IF EXISTS monthly_budgets;
DROP TABLE IF EXISTS categories;

-- 3. Create Master Categories Table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL, 
    group_type VARCHAR(50) NOT NULL,   -- 'Fixed', 'Savings', 'Variable'
    default_target DECIMAL(18,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    createdate TIMESTAMP DEFAULT NOW()
);

-- 4. Create New Monthly Budgets Table
CREATE TABLE monthly_budgets (
    id SERIAL PRIMARY KEY,
    userid INT NOT NULL,
    year INT NOT NULL,
    month INT NOT NULL,
    category_id INT NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    target_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(userid, year, month, category_id)
);

-- 5. Insert Master Data from Spreadsheet
INSERT INTO categories (name, group_type, default_target) VALUES
('KPR HOME TENJO', 'Fixed', 6300000),
('KPR HOME CRB', 'Fixed', 1200000),
('GROCERIES MONTHLY', 'Fixed', 0),
('ELECTRIC TOKEN', 'Fixed', 500000),
('PDAM', 'Fixed', 115800),
('TRANSPORT / GAS', 'Fixed', 150000),
('FRANKY PARENTS', 'Fixed', 0),
('EVE PARENTS', 'Fixed', 4000000),
('INTERNET & KUOTA', 'Fixed', 457000),
('LAUNDRY', 'Fixed', 35000),
('NANOVEST', 'Savings', 5000000),
('GOLD 5GR', 'Savings', 12071625),
('SILVER 100GR', 'Savings', 6048000),
('DINING OUT', 'Variable', 0),
('RECREATION', 'Variable', 0),
('SHOPPING', 'Variable', 0);

-- 6. Insert default Monthly Budgets for User 1, July 2026 based on the master data defaults
INSERT INTO monthly_budgets (userid, year, month, category_id, target_amount, is_paid)
SELECT 
    1, 2026, 7, id, default_target, FALSE
FROM categories;

-- Set specific ones to "paid" for testing based on spreadsheet
UPDATE monthly_budgets 
SET is_paid = TRUE 
WHERE userid = 1 AND year = 2026 AND month = 7 AND category_id IN (
    SELECT id FROM categories WHERE name IN (
        'KPR HOME TENJO', 'ELECTRIC TOKEN', 'PDAM', 'FRANKY PARENTS',
        'NANOVEST', 'GOLD 5GR', 'SILVER 100GR'
    )
);

-- 7. Update get_monthly_recap Function
CREATE OR REPLACE FUNCTION get_monthly_recap(p_userid INT, p_year INT, p_month INT)
RETURNS TABLE (
    "Id" INT,
    "GroupType" VARCHAR,
    "Category" VARCHAR,
    "TargetAmount" DECIMAL,
    "ActualAmount" DECIMAL,
    "IsPaid" BOOLEAN
) AS $$
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
        SELECT c.name FROM monthly_budgets b
        JOIN categories c ON b.category_id = c.id
        WHERE b.userid = p_userid AND b.year = p_year AND b.month = p_month
    )
    SELECT 
        COALESCE(b.id, 0) as "Id",
        COALESCE(c_master.group_type, 'Variable') as "GroupType",
        ac.name as "Category",
        COALESCE(b.target_amount, 0) as "TargetAmount",
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
$$ LANGUAGE plpgsql;

-- 8. Function to save/upsert budget by category name
CREATE OR REPLACE FUNCTION save_monthly_budget(
    p_userid INT,
    p_year INT,
    p_month INT,
    p_group_type VARCHAR,
    p_category VARCHAR,
    p_target_amount NUMERIC,
    p_is_paid BOOLEAN
)
RETURNS VOID AS
$$
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
$$ LANGUAGE plpgsql;

-- 9. Function to Get All Categories for Master UI
CREATE OR REPLACE FUNCTION get_categories()
RETURNS TABLE (
    "Id" INT,
    "Name" VARCHAR,
    "GroupType" VARCHAR,
    "DefaultTarget" DECIMAL,
    "IsActive" BOOLEAN
) AS $$
BEGIN
    RETURN QUERY SELECT id, name, group_type, default_target, is_active FROM categories ORDER BY group_type, name;
END;
$$ LANGUAGE plpgsql;
