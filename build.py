#!/usr/bin/env python3
"""Build the tracked files under content/ into a static GitHub Pages site."""

from __future__ import annotations

import argparse
import html
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from urllib.parse import quote


ROOT = Path(__file__).resolve().parent
CONTENT = ROOT / "content"
OUTPUT = ROOT / "_site"
ASSETS = ROOT / "assets"


@dataclass(frozen=True)
class FileEntry:
    path: PurePosixPath
    size: int


def tracked_content_files(root: Path = ROOT) -> list[PurePosixPath]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "content"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    )
    files: list[PurePosixPath] = []
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        value = raw.decode("utf-8", "surrogateescape")
        path = PurePosixPath(value)
        if len(path.parts) > 1 and (root / path).is_file():
            files.append(PurePosixPath(*path.parts[1:]))
    return sorted(files, key=lambda item: item.as_posix().casefold())


def url_for(path: PurePosixPath) -> str:
    return "/" + "/".join(quote(part, safe="") for part in path.parts)


def human_size(size: int) -> str:
    units = ("B", "KiB", "MiB", "GiB")
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{int(value)} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    raise AssertionError("unreachable")


def validate_outputs(files: list[PurePosixPath]) -> None:
    sources = set(files)
    generated_pages = {path.with_suffix(".html") for path in files if path.suffix.lower() == ".md"}
    collisions = sources & generated_pages
    directories = {PurePosixPath()}
    for path in files:
        parent = path.parent
        while parent != PurePosixPath("."):
            directories.add(parent)
            parent = parent.parent
    index_collisions = {directory / "index.html" for directory in directories} & sources
    conflicts = sorted(collisions | index_collisions, key=lambda item: item.as_posix())
    if conflicts:
        joined = "\n  ".join(path.as_posix() for path in conflicts)
        raise RuntimeError(f"generated HTML would overwrite source file(s):\n  {joined}")


def render_tree(files: list[FileEntry], current: PurePosixPath) -> str:
    descendants = [entry for entry in files if current == PurePosixPath(".") or entry.path.is_relative_to(current)]
    tree: dict[str, object] = {}
    prefix_len = 0 if current == PurePosixPath(".") else len(current.parts)
    for entry in descendants:
        node = tree
        for part in entry.path.parts[prefix_len:-1]:
            node = node.setdefault(part, {})  # type: ignore[assignment]
        node.setdefault("__files__", []).append(entry)  # type: ignore[union-attr]

    def walk(node: dict[str, object], base: PurePosixPath) -> str:
        chunks = ["<ul class=\"tree\">"]
        for name in sorted((key for key in node if key != "__files__"), key=str.casefold):
            child = base / name
            chunks.append(
                '<li><details><summary>📁 '
                + html.escape(name)
                + f' <a class="open-folder" href="{url_for(child)}/">打开</a></summary>'
                + walk(node[name], child)  # type: ignore[arg-type]
                + "</details></li>"
            )
        for entry in sorted(node.get("__files__", []), key=lambda item: item.path.name.casefold()):  # type: ignore[union-attr]
            name = html.escape(entry.path.name)
            source_link = f'<a href="{url_for(entry.path)}">原文</a>'
            if entry.path.suffix.lower() == ".md":
                read_link = f'<a href="{url_for(entry.path.with_suffix(".html"))}">阅读</a> · '
            else:
                read_link = ""
            chunks.append(
                f'<li class="file"><span>📄 {name}</span><span class="meta">'
                f'{html.escape(human_size(entry.size))} · {read_link}{source_link}</span></li>'
            )
        chunks.append("</ul>")
        return "".join(chunks)

    return walk(tree, current)


def page(files: list[FileEntry], current: PurePosixPath) -> str:
    label = "全部文件" if current == PurePosixPath(".") else current.as_posix()
    download_path = "" if current == PurePosixPath(".") else current.as_posix()
    return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(label)} · 文件站</title>
<link rel="stylesheet" href="/assets/site.css"></head>
<body><main><nav><a href="/">文件站</a></nav>
<header><div><h1>{html.escape(label)}</h1><p>浏览或下载 Git 仓库中公开的源文件。</p></div>
<button class="download" data-download-path="{html.escape(download_path, quote=True)}">下载目录</button></header>
<div id="download-status" role="status" aria-live="polite"></div>
{render_tree(files, current)}
</main><script src="/assets/jszip.min.js"></script><script src="/assets/site.js"></script></body></html>
"""


def build(root: Path = ROOT, output: Path = OUTPUT) -> list[FileEntry]:
    content = root / "content"
    paths = tracked_content_files(root)
    if not paths:
        raise RuntimeError("no tracked files found under content/; add and commit content first")
    validate_outputs(paths)
    entries = [FileEntry(path, (content / path).stat().st_size) for path in paths]
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    for entry in entries:
        destination = output / entry.path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(content / entry.path, destination)
        if entry.path.suffix.lower() == ".md":
            subprocess.run(
                ["pandoc", str(content / entry.path), "--standalone", "--from=gfm", "--to=html5",
                 f"--metadata=title:{entry.path.stem}", "--css=/assets/site.css", "-o", str(output / entry.path.with_suffix(".html"))],
                check=True,
            )
    directories = {PurePosixPath(".")}
    for entry in entries:
        parent = entry.path.parent
        while parent != PurePosixPath("."):
            directories.add(parent)
            parent = parent.parent
    for directory in directories:
        target = output / directory / "index.html"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(page(entries, directory), encoding="utf-8")
    manifest = [{"path": item.path.as_posix(), "url": url_for(item.path), "size": item.size} for item in entries]
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    shutil.copytree(root / "assets", output / "assets")
    (output / ".nojekyll").touch()
    return entries


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    try:
        entries = build(output=args.output.resolve())
    except (RuntimeError, subprocess.CalledProcessError, FileNotFoundError) as error:
        print(f"build failed: {error}", file=sys.stderr)
        return 1
    print(f"built {len(entries)} source files in {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

