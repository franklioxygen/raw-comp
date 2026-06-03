#!/usr/bin/env python3
"""Report localization parity and untranslated strings vs en.lproj."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Sources" / "RawComp" / "Resources"
LOCALES = ["de", "fr", "zh-Hans", "ja", "es", "it", "ko", "pt"]


def parse_entries(text: str) -> dict[str, str]:
    pattern = re.compile(r'"([^"]+)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;')
    return {key: value for key, value in pattern.findall(text)}


def main() -> int:
    en_path = ROOT / "en.lproj" / "Localizable.strings"
    en_vals = parse_entries(en_path.read_text())
    failures = 0

    for locale in LOCALES:
        path = ROOT / f"{locale}.lproj" / "Localizable.strings"
        loc_vals = parse_entries(path.read_text())
        missing = sorted(set(en_vals) - set(loc_vals))
        same = sorted(k for k in en_vals if k in loc_vals and loc_vals[k] == en_vals[k])
        print(f"{locale}: keys={len(loc_vals)} missing={len(missing)} still_english={len(same)}")
        if missing:
            failures += 1
            for key in missing[:5]:
                print(f"  missing: {key}")
        elif len(same) > 25:
            print(f"  (showing 5 of {len(same)} still-English strings)")
            for key in same[:5]:
                print(f"  english: {key}")

    untranslated = {
        locale: len(
            sorted(
                k
                for k in en_vals
                if k in parse_entries((ROOT / f"{locale}.lproj" / "Localizable.strings").read_text())
                and parse_entries((ROOT / f"{locale}.lproj" / "Localizable.strings").read_text())[k]
                == en_vals[k]
            )
        )
        for locale in LOCALES
    }
    worst = max(untranslated.values()) if untranslated else 0
    if failures:
        print("FAIL: one or more locales are missing keys.")
    elif worst > 0:
        print(f"FAIL: up to {worst} strings still match English in en.lproj.")
        return 1
    else:
        print("OK: all locales have full key parity; no strings identical to English.")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
