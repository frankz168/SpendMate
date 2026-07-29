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
$$ LANGUAGE plpgsql;
