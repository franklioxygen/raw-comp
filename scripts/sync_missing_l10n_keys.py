#!/usr/bin/env python3
"""Insert any keys from en.lproj that are missing in other locale files (English fallback)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Sources" / "RawComp" / "Resources"
LOCALES = ["de", "fr", "zh-Hans", "ja", "es", "it", "ko", "pt"]


def parse_entries(text: str) -> dict[str, str]:
    pattern = re.compile(r'"([^"]+)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;')
    return {key: value for key, value in pattern.findall(text)}


def main() -> None:
    en_path = ROOT / "en.lproj" / "Localizable.strings"
    en_entries = parse_entries(en_path.read_text())

    for locale in LOCALES:
        path = ROOT / f"{locale}.lproj" / "Localizable.strings"
        if not path.exists():
            continue

        text = path.read_text()
        existing = parse_entries(text)
        missing = [key for key in en_entries if key not in existing]
        if not missing:
            print(f"{locale}: complete")
            continue

        additions = "\n".join(
            f'"{key}" = "{en_entries[key]}";' for key in sorted(missing)
        )
        path.write_text(text.rstrip() + "\n\n" + additions + "\n")
        print(f"{locale}: added {len(missing)} keys")


if __name__ == "__main__":
    main()
