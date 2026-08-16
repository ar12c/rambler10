# RamblerPort: insert rambler flag overrides into GMS phenotype.db (PC side).
# Same mechanism the root version of GMS Flags uses. Reads phenowork\phenotype.db
# (pulled from device, WAL alongside), writes overrides, checkpoints WAL so the
# db is self-contained for the push back.
import os, sqlite3, sys

WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'phenowork')
os.chdir(WORK)

PKG_SUFFIX = 'inputmethod.latin'
FLAGS = ['rambler_al_toolbar', 'rambler_dict_settings', 'rambler_toolbar_at_cursor_position']

con = sqlite3.connect('phenotype.db')
cur = con.cursor()

if '--inspect' in sys.argv:
    for t in ['config_packages', 'accounts', 'flag_overrides_to_commit']:
        print('==', t)
        row = cur.execute('SELECT sql FROM sqlite_master WHERE name=?', (t,)).fetchone()
        print(row[0] if row else '  (missing)')
        print()
    print('== accounts rows ==')
    for r in cur.execute('SELECT * FROM accounts LIMIT 10'):
        print(' ', r)
    cols = [r[1] for r in cur.execute('PRAGMA table_info(config_packages)')]
    print('== config_packages cols ==', cols)
    namecol = next((c for c in cols if 'name' in c.lower()), cols[0])
    for r in cur.execute(f"SELECT * FROM config_packages WHERE {namecol} LIKE '%inputmethod.latin%' LIMIT 5"):
        print(' ', r)
    con.close()
    sys.exit(0)

print('== override tables schema ==')
for (name,) in cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%override%'"):
    print(cur.execute("SELECT sql FROM sqlite_master WHERE name=?", (name,)).fetchone()[0])
    print()

# Exact config package row for Gboard's own config.
row = cur.execute(
    "SELECT config_package_id, name FROM config_packages WHERE name=?",
    ('com.google.android.inputmethod.latin#com.google.android.inputmethod.latin',)).fetchone()
if not row:
    print('!! gboard config package not registered; aborting')
    con.close(); sys.exit(1)
cpid, pkg = row
print('gboard config_package_id:', cpid, ' name:', pkg)

print('== existing flag_overrides rows (encoding reference) ==')
existing = cur.execute('SELECT override_id, config_package_id, account_id, active, name, value, type, source FROM flag_overrides LIMIT 10').fetchall()
for r in existing:
    print(' ', r, ' value_type:', type(r[5]).__name__)
if not existing:
    print('  (empty - using convention: value=1 as INTEGER, type=0=boolean)')

for f in FLAGS:
    cur.execute('DELETE FROM flag_overrides WHERE config_package_id=? AND account_id=0 AND name=?', (cpid, f))
    cur.execute(
        'INSERT INTO flag_overrides (config_package_id, config_package_name, account_id, active, name, value, type, source)'
        ' VALUES (?, NULL, 0, 1, ?, 1, 0, 0)', (cpid, f))
    print('inserted override:', f)

print('== final state ==')
for r in cur.execute('SELECT name, value, type, active, account_id FROM flag_overrides WHERE config_package_id=?', (cpid,)):
    print(' ', r)

con.commit()
# fold WAL into the main db so we push a single self-contained file
print('checkpoint:', cur.execute('PRAGMA wal_checkpoint(TRUNCATE)').fetchone())
con.close()
print('OK - phenowork\\phenotype.db is ready to push back')
