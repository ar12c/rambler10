# RamblerPort: figure out HOW GMS Flags Reborn applies overrides (db write vs hook),
# where it stores them, and the exact phenotype.db encoding if it writes SQL.
import re, zipfile, os

APK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'phenowork', 'reborn_base.apk')
KEYWORDS = [
    'RuntimeFlagOverrides', 'overrideStore', '.db', 'RuntimeFlag',
    'getDatabasePath', 'openOrCreateDatabase', 'SQLiteDatabase',
    'CREATE TABLE IF NOT EXISTS', 'WHERE packageName', 'enabled',
]

def strings(data, n=4):
    return re.findall(rb'[\x20-\x7e]{%d,}' % n, data)

hits = {k: set() for k in KEYWORDS}
with zipfile.ZipFile(APK) as z:
    names = [n for n in z.namelist() if n.endswith(('.dex', '.xml', '.json', '.properties')) or 'resources' not in n]
    for n in z.namelist():
        if not n.endswith('.dex'):
            continue
        data = z.read(n)
        for s in strings(data):
            t = s.decode('ascii', 'replace')
            for k in KEYWORDS:
                if k.lower() in t.lower():
                    hits[k].add(t[:200])

for k in KEYWORDS:
    if hits[k]:
        print(f'== {k} ({len(hits[k])}) ==')
        for t in sorted(hits[k])[:25]:
            print('  ', t)
        print()
