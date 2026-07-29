-- 1. Ensure 'OTHERS' exists in the categories table
INSERT INTO categories (name, group_type, default_target, is_active)
SELECT 'OTHERS', 'Variable', 0.00, true
WHERE NOT EXISTS (
    SELECT 1 FROM categories WHERE name = 'OTHERS'
);

-- 2. Update transactions to map to new category names
UPDATE transactions SET category = 'DINING OUT' WHERE category = 'Food';
UPDATE transactions SET category = 'SHOPPING' WHERE category = 'Shopping';
UPDATE transactions SET category = 'TRANSPORT / GAS' WHERE category = 'Transport';
UPDATE transactions SET category = 'OTHERS' WHERE category = 'Others';
