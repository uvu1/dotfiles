"""Regression tests for preserving local Codex configuration during sync."""

import importlib.util
from pathlib import Path
import sys
import tomllib
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('sync_ai_config', Path(__file__).with_name('sync-ai-config.py'))
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)
SOURCE = '''# managed defaults
model = "managed"
tui.notification_method = "bel"
tui.status_line = [
  "git-branch",
  "context-remaining",
]
'''


class SyncTests(unittest.TestCase):
    def verify(self, target):
        result = sync.synchronize(SOURCE, target)
        before, after = map(tomllib.loads, (target, result))
        owned = dict(sync.leaves(tomllib.loads(SOURCE)))
        self.assertEqual(sync.without_managed(before, owned), sync.without_managed(after, owned))
        self.assertEqual(sync.synchronize(SOURCE, result), result)
        return result

    def test_new_config(self):
        self.verify('')

    def test_local_settings_inside_markers(self):
        result = self.verify(f'''{sync.BEGIN}
model = "old"
tui.screen_reader_detection_done = true
[projects."/example"]
trust_level = "trusted"
[model_providers.example]
name = "Example"
[mcp_servers.example]
command = "example"
{sync.END}
''')
        self.assertGreater(result.index('[projects.'), result.index(sync.END))

    def test_tui_table_after_other_tables(self):
        self.verify('''[notice]
hide_warning = true
[tui]
notification_method = "auto"
status_line = [
  "thread-name",
]
screen_reader_detection_done = true
''')

    def test_multiline_strings_and_array_tables(self):
        self.verify(f'''custom = """
{sync.END}
[not_a_table]
"""
[[local_array]]
value = "first"
[[local_array]]
value = "second"
''')

    def test_invalid_toml_rejected(self):
        with self.assertRaises(ValueError):
            sync.synchronize(SOURCE, 'model = [')

    def test_unsafe_inline_table_rejected(self):
        with self.assertRaises(ValueError):
            sync.synchronize(SOURCE, 'tui = {notification_method="auto", local=true}')

    def test_source_table_headers_rejected(self):
        with self.assertRaises(ValueError):
            sync.synchronize('[tui]\nnotification_method="bel"', '')


if __name__ == '__main__':
    unittest.main()
