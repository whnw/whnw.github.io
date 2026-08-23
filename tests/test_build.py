import html
import json
import subprocess
import tempfile
import unittest
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

import build


class UnitTests(unittest.TestCase):
    def test_url_encoding_and_html_escaping(self):
        path = PurePosixPath("中文 目录/a#b?.txt")
        self.assertEqual(build.url_for(path), "/%E4%B8%AD%E6%96%87%20%E7%9B%AE%E5%BD%95/a%23b%3F.txt")
        entry = build.FileEntry(PurePosixPath("<script>.txt"), 3)
        rendered = build.page([entry], PurePosixPath("."))
        self.assertIn(html.escape("<script>.txt"), rendered)
        self.assertNotIn("<script>.txt", rendered)

    def test_markdown_html_collision(self):
        with self.assertRaisesRegex(RuntimeError, "note.html"):
            build.validate_outputs([PurePosixPath("note.md"), PurePosixPath("note.html")])

    def test_source_index_collision(self):
        with self.assertRaisesRegex(RuntimeError, "docs/index.html"):
            build.validate_outputs([PurePosixPath("docs/index.html")])


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "content" / "中文 目录").mkdir(parents=True)
        (self.root / "assets").mkdir()
        (self.root / "assets" / "site.css").write_text("body{}", encoding="utf-8")
        (self.root / "assets" / "site.js").write_text("", encoding="utf-8")
        (self.root / "assets" / "jszip.min.js").write_text("", encoding="utf-8")
        (self.root / "assets" / "JSZip.LICENSE.markdown").write_text("MIT", encoding="utf-8")
        (self.root / "content" / "中文 目录" / "read me.md").write_text("# 标题\n", encoding="utf-8")
        (self.root / "content" / "中文 目录" / ".hidden").write_bytes(b"hidden")
        (self.root / "content" / "raw#.txt").write_bytes(b"raw")
        (self.root / "not-published.txt").write_text("no", encoding="utf-8")
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "content"], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-qm", "fixtures"], cwd=self.root, check=True)

    def tearDown(self):
        self.temp.cleanup()

    def test_tracked_filter_recursive_build_and_manifest(self):
        untracked = self.root / "content" / "untracked.txt"
        untracked.write_text("no", encoding="utf-8")
        output = self.root / "_site"
        entries = build.build(self.root, output)
        paths = {entry.path.as_posix() for entry in entries}
        self.assertEqual(paths, {"raw#.txt", "中文 目录/.hidden", "中文 目录/read me.md"})
        self.assertTrue((output / "中文 目录" / "read me.html").is_file())
        self.assertTrue((output / "中文 目录" / "index.html").is_file())
        self.assertFalse((output / "untracked.txt").exists())
        self.assertFalse((output / "not-published.txt").exists())
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        for item in manifest:
            decoded = unquote(urlsplit(item["url"]).path).lstrip("/")
            target = output / decoded
            self.assertTrue(target.is_file(), item["url"])
            self.assertEqual(target.stat().st_size, item["size"])


if __name__ == "__main__":
    unittest.main()

