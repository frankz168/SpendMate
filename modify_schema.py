import re

with open('db_schema.sql', 'r') as f:
    sql = f.read()

# We only want to modify functions. Let's find all CREATE FUNCTION blocks.
# Actually, the simplest is to replace `t.userid = p_userid` in the entire schema
# and recreate only those functions, but let's just do a global replace in db_schema.sql 
# for testing, then run it. But wait, `spendmate_transaction_insert` uses `p_userid`. 
# If we replace all `userid = p_userid`, insert might be affected? 
# Insert says: `VALUES (p_userid, ...)` this doesn't match `userid = p_userid`.

# Let's extract only the CREATE FUNCTION statements that we want to replace.
functions = [
    'spendmate_dashboard_get6monthtrend',
    'spendmate_dashboard_getdailysummary',
    'spendmate_dashboard_getdailytotal',
    'spendmate_report_getdata',
    'spendmate_transaction_delete',
    'spendmate_transaction_exportall',
    'spendmate_transaction_getbyid',
    'spendmate_transaction_getlist',
    'spendmate_transaction_gettotalbytype',
    'spendmate_transaction_update',
    'spendmate_budget_getmonthlyrecap',
    'spendmate_budget_save_monthly'
]

# Note: spendmate_budget_save_monthly might have `userid = p_userid` in an UPDATE statement.
# Let's write a targeted regex replacement.

new_sql = sql

for func in functions:
    # find the function body
    match = re.search(r'(CREATE FUNCTION public\.' + func + r'.*?\$\$;)', new_sql, re.DOTALL)
    if match:
        body = match.group(1)
        # replace `t.userid = p_userid AND` with ``
        body = re.sub(r't\.userid\s*=\s*p_userid\s*AND', '', body, flags=re.IGNORECASE)
        # replace `AND t.userid = p_userid` with ``
        body = re.sub(r'AND\s*t\.userid\s*=\s*p_userid', '', body, flags=re.IGNORECASE)
        # replace `WHERE t.userid = p_userid` with `WHERE 1=1`
        body = re.sub(r'WHERE\s*t\.userid\s*=\s*p_userid', 'WHERE 1=1', body, flags=re.IGNORECASE)

        # also for non-aliased userid
        body = re.sub(r'userid\s*=\s*p_userid\s*AND', '', body, flags=re.IGNORECASE)
        body = re.sub(r'AND\s*userid\s*=\s*p_userid', '', body, flags=re.IGNORECASE)
        body = re.sub(r'WHERE\s*userid\s*=\s*p_userid', 'WHERE 1=1', body, flags=re.IGNORECASE)
        
        # update new_sql
        new_sql = new_sql.replace(match.group(1), body)

with open('updated_functions.sql', 'w') as f:
    # Just extract the CREATE FUNCTION blocks we modified so we don't drop/recreate everything.
    # Actually, running the whole schema would create tables, which we don't want.
    # Let's extract only the CREATE OR REPLACE FUNCTION blocks.
    # We can replace CREATE FUNCTION with CREATE OR REPLACE FUNCTION
    for func in functions:
        match = re.search(r'(CREATE FUNCTION public\.' + func + r'.*?\$\$;)', new_sql, re.DOTALL)
        if match:
            func_sql = match.group(1).replace('CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION')
            f.write(func_sql + "\n\n")

print("Created updated_functions.sql")
