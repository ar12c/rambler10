# Extract full SQL statements (incl. newlines) for Reborn's runtime_overrides.db
import re, zipfile, os

APK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'phenowork', 'reborn_base.apk')
with zipfile.ZipFile(APK) as z:
    blob = b'\n'.join(z.read(n) for n in z.namelist() if n.endswith('.dex'))

for pat, label in [
    (rb'CREATE TABLE IF NOT EXISTS RuntimeFlagOverrides[\s\S]{0,600?\}?', None),
]:
    pass

m = re.search(rb'CREATE TABLE IF NOT EXISTS RuntimeFlagOverrides[\s\S]{0,800}?\)', blob)
print('== CREATE TABLE RuntimeFlagOverrides ==')
print(m.group(0).decode('ascii', 'replace') if m else 'not found')

for m in re.finditer(rb'SELECT[\s\S]{0,200}?FROM RuntimeFlagOverrides[\s\S]{0,200}?(?=[\x00-\x1f]|$)', blob):
    print('== SELECT ==')
    print(m.group(0).decode('ascii', 'replace'))

for m in re.finditer(rb'[\x20-\x7e]{6,}RuntimeFlagOverrides[\s\S]{0,300}?\)', blob):
    print('== other ref ==')
    print(m.group(0)[:400].decode('ascii', 'replace'))
