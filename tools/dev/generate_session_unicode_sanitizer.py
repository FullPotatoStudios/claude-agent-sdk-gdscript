#!/usr/bin/env python3

from __future__ import annotations

import unicodedata
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TARGET_PATH = REPO_ROOT / "addons/claude_agent_sdk/runtime/sessions/claude_unicode_sanitizer.gd"
MAX_PASSES = 10
STRIP_CATEGORIES = ("Cf", "Co", "Cn")
S_BASE = 0xAC00
L_BASE = 0x1100
V_BASE = 0x1161
T_BASE = 0x11A7
L_COUNT = 19
V_COUNT = 21
T_COUNT = 28
S_COUNT = L_COUNT * V_COUNT * T_COUNT


def build_strip_ranges() -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    previous: int | None = None

    for codepoint in range(0x110000):
        category = unicodedata.category(chr(codepoint))
        if category not in STRIP_CATEGORIES:
            continue
        if start is None:
            start = codepoint
            previous = codepoint
            continue
        assert previous is not None
        if codepoint == previous + 1:
            previous = codepoint
            continue
        ranges.append((start, previous))
        start = codepoint
        previous = codepoint

    if start is not None and previous is not None:
        ranges.append((start, previous))
    return ranges


def build_nfkd_map() -> list[tuple[int, str]]:
    entries: list[tuple[int, str]] = []
    for codepoint in range(0x110000):
        value = chr(codepoint)
        normalized = unicodedata.normalize("NFKD", value)
        if normalized != value:
            entries.append((codepoint, normalized))
    return entries


def build_non_zero_combining_classes() -> list[tuple[int, int]]:
    entries: list[tuple[int, int]] = []
    for codepoint in range(0x110000):
        combining_class = unicodedata.combining(chr(codepoint))
        if combining_class != 0:
            entries.append((codepoint, combining_class))
    return entries


def build_canonical_composition_map() -> dict[int, dict[int, int]]:
    mapping: dict[int, dict[int, int]] = {}
    for codepoint in range(0x110000):
        decomposition = unicodedata.decomposition(chr(codepoint))
        if not decomposition or decomposition.startswith("<"):
            continue
        parts = [int(part, 16) for part in decomposition.split()]
        if len(parts) != 2:
            continue
        first = chr(parts[0])
        second = chr(parts[1])
        if unicodedata.normalize("NFC", first + second) != chr(codepoint):
            continue
        if parts[0] not in mapping:
            mapping[parts[0]] = {}
        mapping[parts[0]][parts[1]] = codepoint
    return mapping


def format_strip_ranges(ranges: list[tuple[int, int]]) -> str:
    values: list[str] = []
    for start, end in ranges:
        values.append(str(start))
        values.append(str(end))

    lines: list[str] = []
    width = 8
    for index in range(0, len(values), width):
        chunk = values[index : index + width]
        lines.append("\t" + ", ".join(chunk) + ",")
    return "\n".join(lines)


def format_nfkc_map(entries: list[tuple[int, str]]) -> str:
    def gdscript_string(value: str) -> str:
        parts = ['"']
        for char in value:
            codepoint = ord(char)
            if char == "\\":
                parts.append("\\\\")
            elif char == '"':
                parts.append('\\"')
            elif char == "\n":
                parts.append("\\n")
            elif char == "\r":
                parts.append("\\r")
            elif char == "\t":
                parts.append("\\t")
            elif codepoint < 0x20 or codepoint in (0x0085, 0x2028, 0x2029):
                parts.append("\\u%04x" % codepoint)
            else:
                parts.append(char)
        parts.append('"')
        return "".join(parts)

    lines = [
        "\t%d: %s," % (codepoint, gdscript_string(normalized))
        for codepoint, normalized in entries
    ]
    return "\n".join(lines)


def format_int_map(entries: list[tuple[int, int]]) -> str:
    lines = [
        "\t%d: %d," % (codepoint, value)
        for codepoint, value in entries
    ]
    return "\n".join(lines)


def format_nested_int_map(entries: dict[int, dict[int, int]]) -> str:
    lines: list[str] = []
    for outer_key in sorted(entries):
        inner = entries[outer_key]
        inner_values = ", ".join(
            "%d: %d" % (inner_key, inner[inner_key]) for inner_key in sorted(inner)
        )
        lines.append("\t%d: {%s}," % (outer_key, inner_values))
    return "\n".join(lines)


def _combining_class(codepoint: int, classes: dict[int, int]) -> int:
    return classes.get(codepoint, 0)


def _reorder_combining_marks(
    codepoints: list[int],
    classes: dict[int, int],
) -> list[int]:
    ordered: list[int] = []
    for codepoint in codepoints:
        ordered.append(codepoint)
        combining_class = _combining_class(codepoint, classes)
        if combining_class == 0:
            continue
        index = len(ordered) - 1
        while index > 0:
            previous_class = _combining_class(ordered[index - 1], classes)
            if previous_class == 0 or previous_class <= combining_class:
                break
            ordered[index - 1], ordered[index] = ordered[index], ordered[index - 1]
            index -= 1
    return ordered


def _compose_pair(
    starter: int,
    codepoint: int,
    compositions: dict[int, dict[int, int]],
) -> int | None:
    if L_BASE <= starter < L_BASE + L_COUNT and V_BASE <= codepoint < V_BASE + V_COUNT:
        return S_BASE + ((starter - L_BASE) * V_COUNT + (codepoint - V_BASE)) * T_COUNT
    if (
        S_BASE <= starter < S_BASE + S_COUNT
        and (starter - S_BASE) % T_COUNT == 0
        and T_BASE + 1 <= codepoint < T_BASE + T_COUNT
    ):
        return starter + (codepoint - T_BASE)
    return compositions.get(starter, {}).get(codepoint)


def _normalize_nfkc_with_tables(
    value: str,
    decompositions: dict[int, str],
    classes: dict[int, int],
    compositions: dict[int, dict[int, int]],
) -> str:
    codepoints: list[int] = []
    for char in value:
        decomposition = decompositions.get(ord(char))
        if decomposition is None:
            codepoints.append(ord(char))
            continue
        codepoints.extend(ord(part) for part in decomposition)

    ordered = _reorder_combining_marks(codepoints, classes)
    if not ordered:
        return ""

    composed: list[int] = [ordered[0]]
    starter_index = 0
    starter = composed[0]
    last_class = 0

    for codepoint in ordered[1:]:
        combining_class = _combining_class(codepoint, classes)
        composite = _compose_pair(starter, codepoint, compositions)
        if composite is not None and (last_class < combining_class or last_class == 0):
            composed[starter_index] = composite
            starter = composite
            continue
        if combining_class == 0:
            starter_index = len(composed)
            starter = codepoint
            last_class = 0
        else:
            last_class = combining_class
        composed.append(codepoint)

    return "".join(chr(codepoint) for codepoint in composed)


def _strip_disallowed_codepoints(value: str) -> str:
    return "".join(
        char for char in value if unicodedata.category(char) not in STRIP_CATEGORIES
    )


def verify_tables(
    nfkd_entries: list[tuple[int, str]],
    combining_entries: list[tuple[int, int]],
    composition_entries: dict[int, dict[int, int]],
) -> None:
    decompositions = dict(nfkd_entries)
    combining_classes = dict(combining_entries)
    cases = [
        "A\u030A",
        "e\u0301",
        "A\u0327\u0301",
        "o\u0308",
        "가",
        "한",
        "A\u200b\u030A",
        "a\u200bb",
        "a\u2066Ⓑ\u2069",
        "Ⓐ①ﬃ",
        "Ⅳ",
        "㎏",
        "µ",
        "⒈",
        "㏂",
        "㉑",
        "ʰ",
        "ſ",
        "Ǖ",
    ]

    for value in cases + [chr(codepoint) for codepoint in range(0x2000)]:
        current = value
        for _ in range(MAX_PASSES):
            previous = current
            current = _normalize_nfkc_with_tables(
                current, decompositions, combining_classes, composition_entries
            )
            current = _strip_disallowed_codepoints(current)
            if current == previous:
                break
        expected = value
        for _ in range(MAX_PASSES):
            previous = expected
            expected = unicodedata.normalize("NFKC", expected)
            expected = _strip_disallowed_codepoints(expected)
            if expected == previous:
                break
        if current != expected:
            raise RuntimeError(
                "Generated sanitizer tables diverged for %r: %r != %r"
                % (value, current, expected)
            )


def build_output() -> str:
    strip_ranges = build_strip_ranges()
    nfkd_map = build_nfkd_map()
    combining_classes = build_non_zero_combining_classes()
    composition_map = build_canonical_composition_map()
    verify_tables(nfkd_map, combining_classes, composition_map)
    python_version = "%d.%d.%d" % (
        sys.version_info.major,
        sys.version_info.minor,
        sys.version_info.micro,
    )
    return """extends RefCounted

# Generated by tools/dev/generate_session_unicode_sanitizer.py.
# Source Unicode data: Python %(python_version)s / unicodedata %(unidata_version)s.
# Do not edit by hand; regenerate from Python's unicodedata tables instead.

const MAX_PASSES := %(max_passes)d
const STRIP_RANGES := [
%(strip_ranges)s
]
const NFKD_DECOMPOSITION_MAP := {
%(nfkd_map)s
}
const NON_ZERO_COMBINING_CLASSES := {
%(combining_classes)s
}
const CANONICAL_COMPOSITION_MAP := {
%(composition_map)s
}
const HANGUL_S_BASE := %(hangul_s_base)d
const HANGUL_L_BASE := %(hangul_l_base)d
const HANGUL_V_BASE := %(hangul_v_base)d
const HANGUL_T_BASE := %(hangul_t_base)d
const HANGUL_L_COUNT := %(hangul_l_count)d
const HANGUL_V_COUNT := %(hangul_v_count)d
const HANGUL_T_COUNT := %(hangul_t_count)d
const HANGUL_S_COUNT := %(hangul_s_count)d


static func sanitize(value: String) -> String:
\tvar current := value
\tfor _i in range(MAX_PASSES):
\t\tvar previous := current
\t\tcurrent = _normalize_nfkc(previous)
\t\tcurrent = _strip_disallowed_codepoints(current)
\t\tif current == previous:
\t\t\tbreak
\treturn current


static func _normalize_nfkc(value: String) -> String:
\tvar decomposed: Array[int] = []
\tfor i in range(value.length()):
\t\tvar code := value.unicode_at(i)
\t\tif NFKD_DECOMPOSITION_MAP.has(code):
\t\t\tvar decomposition := str(NFKD_DECOMPOSITION_MAP[code])
\t\t\tfor j in range(decomposition.length()):
\t\t\t\tdecomposed.append(decomposition.unicode_at(j))
\t\telse:
\t\t\tdecomposed.append(code)
\tvar ordered := _reorder_combining_marks(decomposed)
\treturn _compose_canonical(ordered)


static func _reorder_combining_marks(codepoints: Array[int]) -> Array[int]:
\tvar ordered: Array[int] = []
\tfor code in codepoints:
\t\tordered.append(code)
\t\tvar code_class := _combining_class(code)
\t\tif code_class == 0:
\t\t\tcontinue
\t\tvar index := ordered.size() - 1
\t\twhile index > 0:
\t\t\tvar previous_class := _combining_class(int(ordered[index - 1]))
\t\t\tif previous_class == 0 or previous_class <= code_class:
\t\t\t\tbreak
\t\t\tvar previous_code := int(ordered[index - 1])
\t\t\tordered[index - 1] = int(ordered[index])
\t\t\tordered[index] = previous_code
\t\t\tindex -= 1
\treturn ordered


static func _compose_canonical(codepoints: Array[int]) -> String:
\tif codepoints.is_empty():
\t\treturn ""
\tvar composed: Array[int] = [int(codepoints[0])]
\tvar starter_index := 0
\tvar starter := int(composed[0])
\tvar last_class := 0
\tfor i in range(1, codepoints.size()):
\t\tvar code := int(codepoints[i])
\t\tvar code_class := _combining_class(code)
\t\tvar composite := _compose_pair(starter, code)
\t\tif composite >= 0 and (last_class < code_class or last_class == 0):
\t\t\tcomposed[starter_index] = composite
\t\t\tstarter = composite
\t\t\tcontinue
\t\tif code_class == 0:
\t\t\tstarter_index = composed.size()
\t\t\tstarter = code
\t\t\tlast_class = 0
\t\telse:
\t\t\tlast_class = code_class
\t\tcomposed.append(code)
\tvar text := ""
\tfor code in composed:
\t\ttext += char(code)
\treturn text


static func _compose_pair(starter: int, code: int) -> int:
\tif starter >= HANGUL_L_BASE and starter < HANGUL_L_BASE + HANGUL_L_COUNT:
\t\tif code >= HANGUL_V_BASE and code < HANGUL_V_BASE + HANGUL_V_COUNT:
\t\t\treturn HANGUL_S_BASE + ((starter - HANGUL_L_BASE) * HANGUL_V_COUNT + (code - HANGUL_V_BASE)) * HANGUL_T_COUNT
\tif starter >= HANGUL_S_BASE and starter < HANGUL_S_BASE + HANGUL_S_COUNT:
\t\tif (starter - HANGUL_S_BASE) %% HANGUL_T_COUNT == 0 and code > HANGUL_T_BASE and code < HANGUL_T_BASE + HANGUL_T_COUNT:
\t\t\treturn starter + (code - HANGUL_T_BASE)
\tif CANONICAL_COMPOSITION_MAP.has(starter):
\t\tvar trailing_map: Dictionary = CANONICAL_COMPOSITION_MAP[starter]
\t\tif trailing_map.has(code):
\t\t\treturn int(trailing_map[code])
\treturn -1


static func _combining_class(code: int) -> int:
\tif NON_ZERO_COMBINING_CLASSES.has(code):
\t\treturn int(NON_ZERO_COMBINING_CLASSES[code])
\treturn 0


static func _strip_disallowed_codepoints(value: String) -> String:
\tvar next := ""
\tfor j in range(value.length()):
\t\tvar code := value.unicode_at(j)
\t\tif _should_strip_codepoint(code):
\t\t\tcontinue
\t\tnext += char(code)
\treturn next


static func _should_strip_codepoint(code: int) -> bool:
\tfor i in range(0, STRIP_RANGES.size(), 2):
\t\tvar range_start := int(STRIP_RANGES[i])
\t\tif code < range_start:
\t\t\treturn false
\t\tvar range_end := int(STRIP_RANGES[i + 1])
\t\tif code <= range_end:
\t\t\treturn true
\treturn false
""" % {
        "max_passes": MAX_PASSES,
        "python_version": python_version,
        "unidata_version": unicodedata.unidata_version,
        "strip_ranges": format_strip_ranges(strip_ranges),
        "nfkd_map": format_nfkc_map(nfkd_map),
        "combining_classes": format_int_map(combining_classes),
        "composition_map": format_nested_int_map(composition_map),
        "hangul_s_base": S_BASE,
        "hangul_l_base": L_BASE,
        "hangul_v_base": V_BASE,
        "hangul_t_base": T_BASE,
        "hangul_l_count": L_COUNT,
        "hangul_v_count": V_COUNT,
        "hangul_t_count": T_COUNT,
        "hangul_s_count": S_COUNT,
    }


def main() -> None:
    TARGET_PATH.write_text(build_output(), encoding="utf-8")


if __name__ == "__main__":
    main()
