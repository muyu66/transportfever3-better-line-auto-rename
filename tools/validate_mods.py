#!/usr/bin/env python3
"""Validate the four independently installable Transport Fever 3 mods."""

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

MOD_IDS = (
    "better_line_summary",
    "better_rename_strategy_manual",
    "better_rename_strategy_auto_apply",
)
OBSOLETE_MOD_IDS = (
    "highlight_current",
    "highlight_current_entity",
    "better_line_auto_rename",
    "terminal_line_name_sort",
)

SCHEME_FILES = {"scheme_cargo_firststop_laststop.res.lua"}

EXPECTED_CONTENT = {
    "better_line_summary": {
        "better_line_summary.res.lua",
        "better_line_summary.script.tl",
    },
    "better_rename_strategy_manual": SCHEME_FILES,
    "better_rename_strategy_auto_apply": SCHEME_FILES
    | {
        "auto_apply_on_arrive_at_stop.gs.lua",
        "auto_apply_on_arrive_at_stop.script.tl",
    },
}

EXPECTED_NAMES = {
    "better_line_summary": "Better Line Summary",
    "better_rename_strategy_manual": "Better Rename Strategy (Manual)",
    "better_rename_strategy_auto_apply": "Better Rename Strategy (Auto-apply)",
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
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"{path.relative_to(ROOT)}: {error}")
        return {}


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        errors.append(f"{path.relative_to(ROOT)}: {error}")
        return ""


def evaluate_resource(path: Path) -> dict:
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals()["_"] = lambda value: value
    lua.globals()["resolve"] = lambda value: value
    try:
        lua.execute(path.read_text(encoding="utf-8"))
        return lua.globals().data()
    except Exception as error:  # lupa.LuaError
        errors.append(f"{path.relative_to(ROOT)}: Lua error: {error}")
        return {}


def check_packages() -> None:
    print("== Packages ==")
    for mod_id in OBSOLETE_MOD_IDS:
        check(
            not (ROOT / mod_id).exists(),
            f"obsolete mod directory still exists: {mod_id}",
        )

    for mod_id in MOD_IDS:
        mod_dir = ROOT / mod_id
        check(mod_dir.is_dir(), f"missing mod directory: {mod_id}")
        if not mod_dir.is_dir():
            continue

        mod_json = load_json(mod_dir / "mod.json")
        check(mod_json.get("modId") == mod_id, f"{mod_id}: modId mismatch")
        expected_revision = {
            "better_line_summary": 2,
            "better_rename_strategy_manual": 2,
            "better_rename_strategy_auto_apply": 8,
        }[mod_id]
        check(
            mod_json.get("revision") == expected_revision,
            f"{mod_id}: expected revision {expected_revision}",
        )

        content_json = load_json(mod_dir / "_content.json")
        listed = content_json.get("files") or []
        check(len(listed) == len(set(listed)), f"{mod_id}: duplicate content entries")
        check(
            set(listed) == EXPECTED_CONTENT[mod_id],
            f"{mod_id}: _content.json mismatch",
        )

        content_dir = mod_dir / "content"
        on_disk = {
            path.relative_to(content_dir).as_posix()
            for path in content_dir.rglob("*")
            if path.is_file()
        }
        check(
            on_disk == EXPECTED_CONTENT[mod_id],
            f"{mod_id}: unexpected content files: {sorted(on_disk)}",
        )

        modinfo = load_json(mod_dir / "_metadata" / "modinfo.json")
        check(
            modinfo.get("name") == EXPECTED_NAMES[mod_id],
            f"{mod_id}: unexpected display name",
        )
        for key in ("name", "description", "summary", "authors", "tags"):
            check(key in modinfo, f"{mod_id}: modinfo missing {key}")
        check(
            (mod_dir / "_metadata" / "0.jpg").is_file(),
            f"{mod_id}: missing cover image",
        )

    print(f"   {len(MOD_IDS)} packages, {sum(len(v) for v in EXPECTED_CONTENT.values())} content files")


def check_rename_schemes() -> None:
    print("== Rename schemes ==")
    manual = ROOT / "better_rename_strategy_manual" / "content"
    auto = ROOT / "better_rename_strategy_auto_apply" / "content"

    for filename in sorted(SCHEME_FILES):
        manual_path = manual / filename
        auto_path = auto / filename
        check(
            manual_path.read_bytes() == auto_path.read_bytes(),
            f"{filename}: manual and auto-apply copies differ",
        )
        result = evaluate_resource(manual_path)
        data = result["data"]
        check(result["type"] == "rename_scheme", f"{filename}: wrong resource type")
        check(
            data["schemeNameRaw"] == "cargo_firststop_laststop",
            f"{filename}: unexpected scheme name",
        )
        check(data["sortKey"] == 23, f"{filename}: unexpected sortKey")
        placeholders = set(re.findall(r"\{(\w+)\}", data["formatString"]))
        check(
            placeholders == set(data["formatParams"].keys()),
            f"{filename}: placeholder/parameter mismatch",
        )

    print("   1 identical scheme in manual and auto-apply editions")


def check_auto_apply() -> None:
    print("== Auto-apply ==")
    mod_dir = ROOT / "better_rename_strategy_auto_apply"
    descriptor = read(mod_dir / "content" / "auto_apply_on_arrive_at_stop.gs.lua")
    script = read(mod_dir / "content" / "auto_apply_on_arrive_at_stop.script.tl")

    check("handleEventScript" in descriptor, "auto-apply: missing handleEventScript")
    check(
        "updateScript" in descriptor,
        "auto-apply: updateScript is required for safe queue dispatch",
    )
    check(
        "postUpdateScript" not in descriptor,
        "auto-apply: postUpdateScript is no longer used",
    )

    for forbidden in (
        "scanIntervalTicks",
        "tickCount",
    ):
        check(forbidden not in script, f"auto-apply: polling code leaked: {forbidden}")

    for required in (
        'state:subscribeToEvent("OnArriveAtStop")',
        'id ~= "TransportVehicleSystem"',
        'name ~= "OnArriveAtStop"',
        "param as ArriveAtStop",
        "entity_util.isOwnedByPlayer(lineEntity)",
        "makeLinePathSignature(line)",
        "stateData.signatures[lineEntity] == signature",
        "api.cmd.makeEntitySetNameCmd(lineEntity, newName)",
        "local hasAutoRenameOptOutSuffix",
        'trimmedName:sub(-1) == "*"',
        "if hasAutoRenameOptOutSuffix(currentName) then",
        "local maxRenamesPerUpdate <const> = 10",
        "pendingRenames : {Engine.Entity : string}",
        "stateData.pendingRenames[lineEntity] = newName",
        "local flushPendingRenames = function(",
        "flushPendingRenames(state)",
        "local stateVersion <const> = 5",
        "previousVersion < stateVersion",
        "update = function",
        '"[better_rename_strategy_auto_apply] migration queued "',
        '"[better_rename_strategy_auto_apply] submitted "',
        "handleLegacy",
    ):
        check(required in script, f"auto-apply: missing {required!r}")

    opt_out = script.find("if hasAutoRenameOptOutSuffix(currentName) then")
    signature_update = script.find("stateData.signatures[lineEntity] = signature")
    check(
        0 <= opt_out < signature_update,
        "auto-apply: opt-out must run before signature update",
    )

    flush_helper = script.find("local flushPendingRenames = function")
    update_callback = script.find("update = function")
    handle_event = script.find("handleEvent = function")
    command_dispatch = script.find("api.cmd.sendCommand(")
    check(
        flush_helper < command_dispatch < update_callback < handle_event,
        "auto-apply: commands must be dispatched from update, not handleEvent",
    )
    check(
        script.count("api.cmd.sendCommand(") == 1,
        "auto-apply: expected exactly one safe command dispatch site",
    )

    # getLines() is allowed exactly once for first-run baseline, never from update.
    check(script.count("getLines()") == 1, "auto-apply: only one initial baseline scan is allowed")
    print("   OnArriveAtStop state queue; safe bounded update dispatch")


def check_line_summary_mod() -> None:
    print("== Better line summary ==")
    mod_dir = ROOT / "better_line_summary"
    content = mod_dir / "content"
    resource = evaluate_resource(content / "better_line_summary.res.lua")
    data = resource["data"]
    script = read(content / "better_line_summary.script.tl")

    check(
        resource["type"] == "react-plugin ::StationGroupEowExtensionPoint",
        "summary: wrong resource type",
    )
    check(
        data["filePath"]
        == "better_line_summary::/better_line_summary.script@BetterLineSummaryPlugin",
        "summary: wrong plugin script path",
    )
    check(data["order"] == 50, "summary: unexpected plugin order")
    check(
        'station_group_eow.script.tl" as StationGroupEow' in script,
        "summary: official station extension point is not imported",
    )
    for required in (
        "react.RegisterPluginRecipe(",
        "StationGroupEowExtensionPoint",
        'api.engine.system.lineSystem.getLineStops(',
        "lang_util.compareStrings(aName, bName)",
        "local highlightColor <const> = api.type.Vec4f.new(1.0, 0.90, 0.55, 1.0)",
        "local makeHighlightedLineName",
    ):
        check(required in script, f"summary: missing {required!r}")
    check(
        re.search(
            r"string\.find\(\s*lineName,\s*highlightName,\s*searchStart,\s*true\s*\)",
            script,
        )
        is not None,
        "summary: safe repeated-text search is missing",
    )
    for forbidden in (
        "api.ReplaceRecipe(",
        "react-replacement-config",
        "StationGroupWindowContent",
        'ug_require "::/gui/entity_window/station_group/station_group.tl"',
        "return builtin.Button{",
    ):
        check(forbidden not in script, f"summary: invasive code leaked: {forbidden}")
    check(
        re.search(
            r'RegisterRecipe\(\s*"BetterLineSummaryRow".*?return builtin\.BoxLayout\{',
            script,
            re.DOTALL,
        )
        is not None,
        "summary: row recipe root must be a BoxLayout",
    )
    print("   non-invasive station extension: sort + highlight")


def main() -> int:
    check_packages()
    check_rename_schemes()
    check_auto_apply()
    check_line_summary_mod()

    if errors:
        print("\nFAILED")
        for error in errors:
            print(f" - {error}")
        return 1

    print(f"\nPASSED ({checks} checks)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
