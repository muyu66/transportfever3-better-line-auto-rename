#!/usr/bin/env python3
"""Validate the standalone highlight_current mod."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import lupa
except ImportError:  # pragma: no cover
    print("Missing lupa: python -m pip install -r requirements-dev.txt")
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parents[1]
MOD_ID = "highlight_current"
MOD_DIR = ROOT / MOD_ID
CONTENT_DIR = MOD_DIR / "content"
SCRIPT_PATH = CONTENT_DIR / "highlight_current.script.tl"
RESOURCE_PATH = CONTENT_DIR / "highlight_current.res.lua"
TEMPLATE_PATH = CONTENT_DIR / "highlight_current.tl"
ORIGINAL_TEMPLATE_PATH = (
    ROOT / "better_line_auto_rename" / "content" / "station_group_enhanced.tl"
)
EXPECTED_FILES = {
    "highlight_current.res.lua",
    "highlight_current.script.tl",
    "highlight_current.tl",
}

errors: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        errors.append(message)


def load_json(path: Path) -> dict:
    try:
        with path.open(encoding="utf-8") as file:
            return json.load(file)
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"{path.relative_to(ROOT)}: {error}")
        return {}


def check_package() -> None:
    print("== Package ==")
    mod_json = load_json(MOD_DIR / "mod.json")
    content_json = load_json(MOD_DIR / "_content.json")
    modinfo = load_json(MOD_DIR / "_metadata" / "modinfo.json")

    check(mod_json.get("modId") == MOD_ID, "mod.json modId must be highlight_current")
    listed = content_json.get("files") or []
    check(len(listed) == len(set(listed)), "_content.json contains duplicate files")
    check(set(listed) == EXPECTED_FILES, "_content.json does not match the content files")

    on_disk = {
        path.relative_to(CONTENT_DIR).as_posix()
        for path in CONTENT_DIR.rglob("*")
        if path.is_file()
    }
    check(on_disk == EXPECTED_FILES, f"unexpected content files: {sorted(on_disk)}")

    for key in ("name", "description", "summary", "authors", "tags"):
        check(key in modinfo, f"modinfo.json is missing {key}")
    check(modinfo.get("name") == "Highlight Current", "unexpected display name")
    check((MOD_DIR / "_metadata" / "0.jpg").is_file(), "missing cover image")
    print(f"   Mod ID: {MOD_ID}; content files: {len(on_disk)}")


def check_replacement() -> None:
    print("== Replacement ==")
    script = SCRIPT_PATH.read_text(encoding="utf-8")
    resource = RESOURCE_PATH.read_text(encoding="utf-8")

    for snippet in (
        'ug_require "::/gui/entity_window/station_group/station_group.tl"',
        'ug_require "highlight_current::/highlight_current.tl"',
        "api.ReplaceRecipe(original, replacement)",
        '"[highlight_current] Could not resolve StationGroupWindowContent"',
    ):
        check(snippet in script, f"replacement script is missing {snippet!r}")

    check('type = "react-replacement-config"' in resource, "wrong resource type")
    check(
        'filePath = "highlight_current::/highlight_current.script"' in resource,
        "wrong replacement script path",
    )
    check('doReplaceFn = "doReplaceFn"' in resource, "wrong replacement callback")
    check("order = 100" in resource, "wrong replacement order")

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(resource)
    result = lua.globals().data()
    check(result["type"] == "react-replacement-config", "resource type failed to load")
    check(
        result["data"]["filePath"] == "highlight_current::/highlight_current.script",
        "resource script path failed to load",
    )
    check(result["data"]["order"] == 100, "resource order failed to load")


def check_highlight_only() -> None:
    print("== Highlight implementation ==")
    source = TEMPLATE_PATH.read_text(encoding="utf-8")

    recipe_names = re.findall(r'react\.RegisterRecipe\("([^"]+)"', source)
    check(bool(recipe_names), "no React recipes found")
    check(
        all(name.startswith("HighlightCurrent") for name in recipe_names),
        "every React recipe must use the HighlightCurrent prefix",
    )

    for snippet in (
        "local highlightColor = api.type.Vec4f.new(1.0, 0.90, 0.55, 1.0)",
        "local makeHighlightedLineName = function(",
        "string.find(lineName, highlightName, searchStart, true)",
        "makeHighlightedLineName(nameState:old(), highlightName)",
        'highlightName = api.engine.util.getEntityName(stationGroupEntityId) or ""',
        "color = highlightColor",
        "return StationGroupWindowContent",
    ):
        check(snippet in source, f"highlight implementation is missing {snippet!r}")

    for excluded in ("sortedLineEntities", "lang_util.compareStrings", "scheme_"):
        check(excluded not in source, f"non-highlight feature leaked into new mod: {excluded}")
    check("BetterAutoRename" not in source, "old mod recipe prefix leaked into new mod")
    print(f"   React recipes: {len(recipe_names)}; repeated matches supported")

    original = ORIGINAL_TEMPLATE_PATH.read_text(encoding="utf-8")
    for snippet in (
        "makeHighlightedLineName(nameState:old(), highlightName)",
        'highlightName = api.engine.util.getEntityName(stationGroupEntityId) or ""',
    ):
        check(snippet in original, "better_line_auto_rename lost its highlight feature")


def main() -> int:
    check_package()
    check_replacement()
    check_highlight_only()

    if errors:
        print("\nFAILED")
        for error in errors:
            print(f" - {error}")
        return 1

    print(f"\nPASSED ({checks} checks)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
