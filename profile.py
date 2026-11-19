#!/usr/bin/env python3
"""Resolve a resume .md into plain Markdown, applying a profile on top of a base.

Mark swappable parts of your base resume with named blocks:

    <!-- block: summary -->
    Your general summary...
    <!-- /block -->

A profile is a small .md file that names its base and replaces only some blocks:

    <!-- base: ../resume.md -->
    <!-- block: summary -->
    A summary tailored to this job...
    <!-- /block -->

Blocks the profile doesn't mention keep the base's text; an empty block removes it.
Block markers never reach the PDF, so they are safe anywhere, even inside lists.

Usage:
    python3 profile.py FILE.md            print resolved Markdown to stdout
    python3 profile.py --base FILE.md     print the base file's path (itself if no base)
    python3 profile.py --new BASE.md OUT.md
                                          start a profile containing every block of BASE
"""
import os
import re
import sys

BASE_RE = re.compile(r"^\s*<!--\s*base:\s*(.+?)\s*-->\s*$")
OPEN_RE = re.compile(r"^\s*<!--\s*block:\s*([\w-]+)\s*-->\s*$")
CLOSE_RE = re.compile(r"^\s*<!--\s*/block\s*-->\s*$")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read().splitlines()


def base_of(path):
    for line in read(path):
        m = BASE_RE.match(line)
        if m:
            return os.path.normpath(os.path.join(os.path.dirname(path), m.group(1)))
    return None


def parse(lines, path):
    """Split into a list of ('text', line) and ('block', name, [lines]) items."""
    items, name, body = [], None, []
    for n, line in enumerate(lines, 1):
        if OPEN_RE.match(line):
            if name:
                sys.exit(f"{path}:{n}: block '{name}' is still open")
            name, body = OPEN_RE.match(line).group(1), []
        elif CLOSE_RE.match(line):
            if not name:
                sys.exit(f"{path}:{n}: <!-- /block --> without an opening block")
            items.append(("block", name, body))
            name = None
        elif name:
            body.append(line)
        elif not BASE_RE.match(line):
            items.append(("text", line))
    if name:
        sys.exit(f"{path}: block '{name}' is never closed")
    return items


def blocks(items):
    return {it[1]: it[2] for it in items if it[0] == "block"}


def resolve(path):
    items = parse(read(path), path)
    base = base_of(path)
    if base is None:
        out = [line for it in items for line in ([it[1]] if it[0] == "text" else it[2])]
        return "\n".join(out) + "\n"

    overrides = blocks(items)
    base_items = parse(read(base), base)
    unknown = set(overrides) - set(blocks(base_items))
    if unknown:
        sys.exit(f"{path}: block(s) not found in {base}: {', '.join(sorted(unknown))}")
    out = []
    for it in base_items:
        if it[0] == "text":
            out.append(it[1])
        else:
            out.extend(overrides.get(it[1], it[2]))
    return "\n".join(out) + "\n"


def new_profile(base, out):
    if os.path.exists(out):
        sys.exit(f"{out} already exists — not overwriting it.")
    found = blocks(parse(read(base), base))
    if not found:
        sys.exit(f"{base} has no <!-- block: name --> markers to override.")
    rel = os.path.relpath(base, os.path.dirname(os.path.abspath(out)))
    lines = [
        f"<!-- base: {rel} -->",
        "<!-- Edit the blocks you want to change for this job; delete the ones you don't. -->",
        "",
    ]
    for name, body in found.items():
        lines += [f"<!-- block: {name} -->", *body, "<!-- /block -->", ""]
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"✓ Created {out} with blocks: {', '.join(found)}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "--new":
        new_profile(args[1], args[2])
    elif len(args) == 2 and args[0] == "--base":
        print(base_of(args[1]) or args[1])
    elif len(args) == 1:
        sys.stdout.write(resolve(args[0]))
    else:
        sys.exit(__doc__)
