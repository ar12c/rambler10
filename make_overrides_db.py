# RamblerPort: build runtime_overrides.db for the GMS Flags Reborn Xposed hook.
#
# This is the mechanism that ACTUALLY unlocks Rambler on Gboard 18.x:
# the Reborn hook inside Gboard reads <gboard_data>/gmsflags_xposed/runtime_overrides.db
# (table RuntimeFlagOverrides) and rewrites flag values in-process at read time.
# Verified on-device: "InputMethod flag override applied: enable_agentic_dictation=true".
#
# Why not phenotype.db flag_overrides? GMS only merges overrides for flags the
# server actually committed - and the server never sends rambler/agentic flags
# for this device, so db-level overrides never reach Gboard's DataStore.
#
# Run on the PC:  python3 make_overrides_db.py   -> writes rambler_overrides.db
# Then apply:     sh apply_overrides.sh          (pushes + installs on device)
import os, sqlite3

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rambler_overrides.db')
PKG = 'com.google.android.inputmethod.latin'

# Gboard 18.x flag registry names (from base.apk strings). The master switch is
# enable_agentic_dictation - without it the rest are inert.
FLAGS = [
    'enable_agentic_dictation',
    'enable_jetson',
    'enable_jetson_in_toolbar',
    'enable_rambler_al_toolbar',
    'enable_rambler_toolbar_at_cursor_position',
    'show_rambler_dict_settings',
    # Writing tools / Jarvis proofread: still served FALSE by the server even
    # under the full yogi identity (verified in flags_jetpack_data_store.pb as
    # 08 00 on 2026-08-17) - force them on like the rambler set.
    'enable_writing_tools_v2_on_toolbar',
    'enable_writing_tools_cooperative_mode',
    'enable_on_device_proofread',
    # v2 masters + voice-UI entrance (the element next to the Rambler strip):
    'writing_tools',
    'enable_writing_tools_v2',
    'enable_writing_tools_voice_commands',
    'writing_helper',
    'writing_tools_enable_stable_entrance',
    'enable_writing_tools_suggest_style',
]

# Forced OFF: the debug UI echoes the parsed agentic-dictation result as a toast
# after every dictation. Explicit 'false' (not row removal) so a server-side
# true can never re-enable it under the yogi identity.
FLAGS_FALSE = [
    'enable_agentic_dictation_debug_ui',
]

if os.path.exists(OUT):
    os.remove(OUT)
con = sqlite3.connect(OUT)
cur = con.cursor()
cur.execute('CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT)')
cur.execute("INSERT INTO android_metadata VALUES ('en_US')")
# Exact schema from Reborn's RuntimeFlagOverrideStore (dex-verified).
cur.execute('''CREATE TABLE IF NOT EXISTS RuntimeFlagOverrides (
    packageName TEXT NOT NULL,
    name TEXT NOT NULL,
    flagType INTEGER NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY(packageName, name))''')
# NeedleRecipeStore also opens this db and expects RuntimeMicroHooks to exist.
cur.execute('''CREATE TABLE IF NOT EXISTS RuntimeMicroHooks (
    packageName TEXT NOT NULL,
    recipeId INTEGER NOT NULL,
    payloadBase64 TEXT NOT NULL,
    payloadSha256 TEXT NOT NULL,
    signatureBase64 TEXT NOT NULL,
    required INTEGER NOT NULL,
    PRIMARY KEY(packageName, recipeId))''')
for f in FLAGS:
    cur.execute('INSERT INTO RuntimeFlagOverrides VALUES (?,?,0,?)', (PKG, f, 'true'))
for f in FLAGS_FALSE:
    cur.execute('INSERT INTO RuntimeFlagOverrides VALUES (?,?,0,?)', (PKG, f, 'false'))
con.commit()
con.close()
print('wrote', OUT, 'with', len(FLAGS) + len(FLAGS_FALSE), 'bool overrides for', PKG)
