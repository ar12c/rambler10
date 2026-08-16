# Parse a uiautomator dump into a readable clickable-elements list.
import re, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

path = sys.argv[1] if len(sys.argv) > 1 else r'phenowork\reborn_ui.xml'
x = open(path, encoding='utf-8').read()
nodes = re.findall(r'text="([^"]*)"[^>]*resource-id="([^"]*)"[^>]*class="([^"]*)"[^>]*bounds="([^"]*)"', x)
if not nodes:
    # attribute order varies; fall back to per-node parsing
    for m in re.finditer(r'<node([^>]*)>', x):
        attrs = dict(re.findall(r'([\w-]+)="([^"]*)"', m.group(1)))
        t, rid, cls, b = attrs.get('text', ''), attrs.get('resource-id', ''), attrs.get('class', ''), attrs.get('bounds', '')
        if t.strip() or 'EditText' in cls or 'Button' in cls or attrs.get('clickable') == 'true':
            print(f"{b:24} {cls.split('.')[-1]:22} {rid.split('/')[-1]:30} {t[:70]}")
else:
    for t, rid, cls, b in nodes:
        if t.strip() or 'EditText' in cls or 'Button' in cls:
            print(f"{b:24} {cls.split('.')[-1]:22} {rid.split('/')[-1]:30} {t[:70]}")
