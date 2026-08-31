#!/usr/bin/env python3
"""Validate a skill's frontmatter `description` against a character budget.

Codex refuses to load a skill whose description exceeds 1024 characters, and
truncates descriptions collectively once they exceed 2% of the context window.
The hard cap is what this script enforces; the shared budget is why a repo may
want to hold itself to something stricter.

Only `description` is measured. Codex's frontmatter parser knows `name`,
`description`, `metadata`, `license` and `allowed-tools` — a `when_to_use`
field is invisible to it, so it is reported as a note rather than counted.

Usage:
    check-skill.py <skill-dir>...            # enforce the 1024 default
    check-skill.py --max 600 <skill-dir>...  # hold to a stricter budget

Exits non-zero, listing every offender, if any description is over budget.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Codex's own limit, from skill-creator/scripts/quick_validate.py. A repo may
# opt into a lower ceiling, never a higher one.
CODEX_MAX_DESCRIPTION = 1024

BLOCK_KEEP = ("|", "|-", "|+")
BLOCK_FOLD = (">", ">-", ">+")


def frontmatter(skill_md: Path) -> str | None:
    m = re.match(r"^---\n(.*?)\n---", skill_md.read_text(), re.S)
    return m.group(1) if m else None


def scalar(fm: str, key: str) -> str | None:
    """Read one top-level scalar out of YAML frontmatter.

    Handles plain values and both block-scalar styles, which is the whole of
    what these skills use. Deliberately dependency-free: the sync runner is a
    bare checkout with no pip install step.
    """
    lines = fm.splitlines()
    for i, line in enumerate(lines):
        m = re.match(rf"{re.escape(key)}:\s*(.*)$", line)
        if not m:
            continue
        value = m.group(1).strip()
        if value not in BLOCK_KEEP + BLOCK_FOLD:
            return value.strip("\"'")
        block = []
        for follow in lines[i + 1:]:
            if follow.strip() == "":
                if block:
                    break
                continue
            if not follow.startswith((" ", "\t")):
                break
            block.append(follow.strip())
        return ("\n" if value in BLOCK_KEEP else " ").join(block)
    return None


def check(skill_dir: Path, max_chars: int) -> tuple[str, list[str]]:
    """Return ("ok" | "over" | "invalid", messages) for one skill directory."""
    skill_md = skill_dir / "SKILL.md"
    name = skill_dir.name
    if not skill_md.is_file():
        return "invalid", [f"{name}: no SKILL.md in {skill_dir}"]

    fm = frontmatter(skill_md)
    if fm is None:
        return "invalid", [f"{name}: SKILL.md has no YAML frontmatter"]

    description = (scalar(fm, "description") or "").strip()
    if not description:
        return "invalid", [f"{name}: frontmatter has no description"]

    count = len(description)
    notes = []
    if scalar(fm, "when_to_use") is not None:
        notes.append(
            f"{name}: note — `when_to_use` is not read by Codex; "
            "fold anything load-bearing into `description`"
        )

    if count > max_chars:
        over = count - max_chars
        notes.append(
            f"{name}: description is {count} characters, {over} over the "
            f"{max_chars}-character limit"
        )
        return "over", notes

    print(f"ok  {name}: description {count}/{max_chars} characters")
    return "ok", notes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("skill_dirs", nargs="+", type=Path)
    parser.add_argument(
        "--max",
        type=int,
        default=CODEX_MAX_DESCRIPTION,
        help=f"character budget for description (default {CODEX_MAX_DESCRIPTION})",
    )
    args = parser.parse_args()

    if args.max < 1:
        print("error: --max must be at least 1", file=sys.stderr)
        return 2
    if args.max > CODEX_MAX_DESCRIPTION:
        print(
            f"error: --max {args.max} exceeds Codex's {CODEX_MAX_DESCRIPTION}-character "
            "cap; a repo may only opt into a stricter budget",
            file=sys.stderr,
        )
        return 2

    over, invalid, all_notes = [], [], []
    for skill_dir in args.skill_dirs:
        status, notes = check(skill_dir, args.max)
        all_notes.extend(notes)
        if status == "over":
            over.append(skill_dir.name)
        elif status == "invalid":
            invalid.append(skill_dir.name)

    for note in all_notes:
        print(note, file=sys.stderr)

    if invalid:
        print(f"\nunreadable: {', '.join(invalid)}", file=sys.stderr)
    if over:
        print(
            f"\nover budget: {', '.join(over)}\n"
            "Codex will refuse a description over 1024 characters, and shortens "
            "all skills' descriptions once they collectively exceed 2% of the "
            "context window. Move detail into the SKILL.md body, and drop "
            "trigger keywords already present in the prose.",
            file=sys.stderr,
        )
    return 1 if (over or invalid) else 0


if __name__ == "__main__":
    raise SystemExit(main())
