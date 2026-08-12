import re

with open('updated_functions.sql', 'r') as f:
    sql = f.read()

# Fix `e. e.type` to `e.type`
sql = sql.replace('e. e.type', 'e.type')
# Fix `b. b.year` to `b.year`
sql = sql.replace('b. b.year', 'b.year')
# Fix `WHERE  t.createdate` to `WHERE t.createdate`
sql = sql.replace('WHERE  t.createdate', 'WHERE t.createdate')

# Wait, spendmate_budget_save_monthly line 230 has:
# ON CONFLICT (userid, year, month, category_id)
# This requires userid! We shouldn't remove userid from the budget table if budgets are shared. 
# BUT wait, if budgets are shared, maybe they are saving to `userid = p_userid`. 
# If they both share budgets, maybe they should use a single `userid = 1` for budget inserts?
# Or maybe the budget table schema has userid?
# The user asked to share household budget and transactions.
# For now, let's keep the userid on budget insert because it's a conflict key.
# When reading budgets, we did `WHERE  EXTRACT(YEAR...)` which removed the userid check, so they will see ALL budgets across users.
# Wait, if they see all budgets, the `UNION` with `monthly_budgets` might duplicate categories if both users inputted a budget.
# Let's fix `b. b.year` first.

with open('updated_functions_fixed.sql', 'w') as f:
    f.write(sql)

print("Fixed syntax issues.")
