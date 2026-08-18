import pathlib
import sqlite3
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class OverridesDbTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["python3", str(ROOT / "make_overrides_db.py")],
                       check=True, capture_output=True)

    def _rows(self):
        con = sqlite3.connect(ROOT / "rambler_overrides.db")
        try:
            return dict(con.execute(
                "SELECT name, value FROM RuntimeFlagOverrides").fetchall())
        finally:
            con.close()

    def test_debug_ui_is_explicitly_false(self):
        self.assertEqual("false", self._rows()["enable_agentic_dictation_debug_ui"])

    def test_fifteen_flags_forced_true(self):
        rows = self._rows()
        self.assertEqual(16, len(rows))
        self.assertEqual(15, sum(1 for v in rows.values() if v == "true"))

    def test_microhooks_table_exists(self):
        con = sqlite3.connect(ROOT / "rambler_overrides.db")
        try:
            con.execute("SELECT COUNT(*) FROM RuntimeMicroHooks").fetchone()
        finally:
            con.close()


if __name__ == "__main__":
    unittest.main()
