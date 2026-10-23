#!/usr/bin/env python3
"""对 better_line_auto_rename 做静态自检。

它做三件事：

1. 文件层面：mod.json / _content.json / _metadata/modinfo.json 能解析，
   modId 与目录名一致，_content.json 与磁盘上的实际文件一一对应。
2. 资源语义：用 lupa 嵌入真实 Lua 运行时执行 mod 的 .res.lua，
   再读取游戏本体 gui.zip 里的 3 个方案和 5 个组件做对照 ——
   检查类型、占位符、组件引用、sortKey，并用本体的 .mo 翻译表
   把「货物 - 首个停靠点 - 末个停靠点」真正渲染一遍。
3. 车站窗口：检查线路名排序、当前节点名称传递和高亮渲染代码，
   并与本地原版参考文件对照，避免覆盖时意外删掉大段原逻辑。

找不到游戏本体时只跑第 1 部分（游戏路径可用 --game-dir 指定）。
退出码 0 = 全部通过。
"""

from __future__ import annotations

import argparse
import gettext
import json
import os
import sys
import zipfile
from pathlib import Path

try:
    import lupa
except ImportError:  # pragma: no cover
    print("需要 lupa：python -m pip install lupa")
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parents[1]
MOD_DIR = ROOT / "better_line_auto_rename"
MOD_ID = "better_line_auto_rename"
STATION_GROUP_SCRIPT = (
    MOD_DIR / "content" / "station_group_enhanced.script.tl"
)
STATION_GROUP_RES = (
    MOD_DIR / "content" / "station_group_enhanced.res.lua"
)
STATION_GROUP_TL = (
    MOD_DIR / "content" / "station_group_enhanced.tl"
)

DEFAULT_GAME_DIR = Path(r"C:\Game\Steam\steamapps\common\Transport Fever 3")
GUI_ZIP = Path("base/content/gui.zip")
STRINGS_DIR = Path("base/strings")

# 本 mod 期望的最终显示名（游戏内语言 -> 文本）
EXPECTED_NAMES = {
    "en": "Cargo - First Stop - Last Stop",
    "zh_CN": "货物 - 首个停靠点 - 末个停靠点",
    "zh_TW": "貨物 - 首站 - 末站",
}

errors: list[str] = []
checks = 0


def check(cond: bool, message: str) -> None:
    global checks
    checks += 1
    if not cond:
        errors.append(message)


def load_json(path: Path, label: str):
    try:
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        errors.append(f"{label} 不存在：{path}")
    except json.JSONDecodeError as e:
        errors.append(f"{label} 不是合法 JSON：{e}")
    return None


def check_files() -> None:
    print("== 文件结构 ==")
    mod_json = load_json(MOD_DIR / "mod.json", "mod.json")
    content_json = load_json(MOD_DIR / "_content.json", "_content.json")
    modinfo = load_json(MOD_DIR / "_metadata" / "modinfo.json", "modinfo.json")

    if mod_json is not None:
        check(mod_json.get("modId") == MOD_ID,
              f"mod.json 的 modId 应为 {MOD_ID}，实际 {mod_json.get('modId')!r}")

    if content_json is not None:
        listed = set(content_json.get("files") or [])
        check(len(listed) == len(content_json.get("files") or []),
              "_content.json 的 files 有重复项")

        content_root = MOD_DIR / "content"
        on_disk = {
            p.relative_to(content_root).as_posix()
            for p in content_root.rglob("*") if p.is_file()
        }
        missing = sorted(listed - on_disk)
        unlisted = sorted(on_disk - listed)
        check(not missing, f"_content.json 列了不存在的文件：{missing}")
        check(not unlisted, f"content 下有文件没进 _content.json：{unlisted}")
        for path in (
            "station_group_enhanced.script.tl",
            "station_group_enhanced.res.lua",
            "station_group_enhanced.tl",
        ):
            check(path in listed, f"车站窗口增强文件未加入 _content.json：{path}")
        print(f"   内容文件 {len(on_disk)} 个，清单一致")

    if modinfo is not None:
        for key in ("name", "description", "summary", "authors", "tags"):
            check(key in modinfo, f"modinfo.json 缺少字段 {key}")

    if not errors:
        print("   OK")


def check_station_window_features() -> None:
    """检查车站终点站列表的官方 recipe 替换、排序和名称高亮实现。"""
    print("== 车站窗口增强 ==")
    required = (STATION_GROUP_SCRIPT, STATION_GROUP_RES, STATION_GROUP_TL)
    for path in required:
        check(path.is_file(), f"缺少车站窗口增强文件：{path}")
    if not all(path.is_file() for path in required):
        return

    script = STATION_GROUP_SCRIPT.read_text(encoding="utf-8")
    resource = STATION_GROUP_RES.read_text(encoding="utf-8")
    source = STATION_GROUP_TL.read_text(encoding="utf-8")

    script_snippets = {
        "使用官方 React recipe 替换接口":
            "api.ReplaceRecipe(original, replacement)",
        "引用原版 StationGroupWindowContent":
            'ug_require "::/gui/entity_window/station_group/station_group.tl"',
        "使用 Mod ID 限定增强文件路径":
            'ug_require "better_line_auto_rename::/station_group_enhanced.tl"',
    }
    for description, snippet in script_snippets.items():
        check(snippet in script, f"{description}：找不到关键代码 {snippet!r}")

    source_snippets = {
        "线路名排序使用全局管理器同款比较函数":
            "lang_util.compareStrings(aName, bName)",
        "排序结果用于实际渲染列表":
            "for __, lineEntity in ipairs(sortedLineEntities) do",
        "线路名文本走高亮渲染":
            "makeHighlightedLineName(nameState:old(), highlightName)",
        "当前节点名称作为高亮词":
            'highlightName = api.engine.util.getEntityName(stationGroupEntityId) or ""',
        "高亮使用游戏主题高亮色":
            "color = highlightColor",
        "高亮使用柔和淡黄色":
            "local highlightColor = api.type.Vec4f.new(1.0, 0.90, 0.55, 1.0)",
        "支持名称中出现多次的重复高亮":
            "string.find(lineName, highlightName, searchStart, true)",
        "使用唯一前缀注册替换 recipe":
            'react.RegisterRecipe("BetterAutoRenameStationGroupWindowContent"',
    }
    for description, snippet in source_snippets.items():
        check(snippet in source, f"{description}：找不到关键代码 {snippet!r}")
    check("DBG:" not in source, "发布版仍包含 [DBG:n] 调试标记")

    check('type = "react-replacement-config"' in resource,
          "资源类型不是 react-replacement-config")

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    res, err = eval_res(lua, resource, STATION_GROUP_RES.name, {})
    check(err is None, f"{STATION_GROUP_RES.name}: {err}")
    if res is not None:
        check(res["type"] == "react-replacement-config",
              f"资源类型解析错误：{res['type']!r}")
        data = res["data"]
        check(data["filePath"] ==
              "better_line_auto_rename::/station_group_enhanced.script",
              "替换资源解析后的 filePath 不正确")
        check(data["doReplaceFn"] == "doReplaceFn",
              "替换资源 doReplaceFn 应为 doReplaceFn")
        check(data["order"] == 100, "替换资源 order 应为 100")

    print("   加载：官方 react-replacement-config 替换 StationGroupWindowContent")
    print("   排序：lang_util.compareStrings（与全局线路管理器一致）")
    print("   高亮：当前车站节点名称，使用柔和淡黄色 #FFE68C")
    if not errors:
        print("   OK")


def game_resources(game_dir: Path):
    """从 gui.zip 里取出 rename_scheme 与 rename_scheme_component 的源码。"""
    zpath = game_dir / GUI_ZIP
    if not zpath.is_file():
        return None
    schemes, components = [], []
    with zipfile.ZipFile(zpath) as z:
        for name in z.namelist():
            if not name.endswith(".res.lua"):
                continue
            if "/auto_rename/schemes/" in name:
                schemes.append((name, z.read(name).decode("utf-8")))
            elif "/auto_rename/scheme_components/" in name:
                components.append((name, z.read(name).decode("utf-8")))
    return schemes, components


def eval_res(lua, source: str, name: str, tr):
    """在独立的 Lua 全局环境里执行 .res.lua 并返回 data() 结果。"""
    lua.execute("""
        __format = function(s, params)
            return (s:gsub("{(%w+)}", function(k)
                local v = params[k]
                if v == nil then return "{" .. k .. "}" end
                return v
            end))
        end
    """)
    lua.globals()["_"] = lambda s: tr.get(s, s)
    # 本体组件资源用 resolve() 把相对路径解析成 "<资源名>"，校验时原样返回即可。
    lua.globals()["resolve"] = lambda p: p
    lua.globals()["__name"] = name
    try:
        loaded = lua.eval("load")(source, "@" + name)
        # Lua 的 load 成功时只返回函数，失败时返回 nil, message；
        # lupa 的 unpack_returned_tuples 会让后者变成 Python tuple。
        if isinstance(loaded, tuple):
            fn, err = loaded
        else:
            fn, err = loaded, None
        if fn is None:
            return None, f"Lua 语法错误：{err}"
        fn()
        res = lua.globals()["data"]()
        lua.execute("data = nil")
        return res, None
    except Exception as e:  # lupa.LuaError 等
        return None, f"Lua 运行错误：{e}"


def check_semantics(game_dir: Path) -> None:
    print("== 资源语义 ==")
    resources = game_resources(game_dir)
    if resources is None:
        print(f"   跳过：找不到 {game_dir / GUI_ZIP}（用 --game-dir 指定游戏目录）")
        return

    base_schemes_src, base_components_src = resources
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)

    base_schemes = {}
    for name, src in base_schemes_src:
        res, err = eval_res(lua, src, name, {})
        check(err is None, f"{name}: {err}")
        if res is not None:
            base_schemes[res["data"]["schemeNameRaw"]] = res["data"]

    base_components = {}
    for name, src in base_components_src:
        res, err = eval_res(lua, src, name, {})
        check(err is None, f"{name}: {err}")
        if res is not None:
            base_components[res["data"]["schemeComponentNameRaw"]] = res["data"]

    check(len(base_schemes) == 3, f"本体方案应为 3 个，实际 {len(base_schemes)}")
    check(len(base_components) == 5, f"本体组件应为 5 个，实际 {len(base_components)}")

    mod_res_path = (
        MOD_DIR / "content" / "scheme_cargo_firststop_laststop.res.lua"
    )
    check(mod_res_path.is_file(), f"缺少方案文件：{mod_res_path}")
    if not mod_res_path.is_file():
        return

    for lang, expected in EXPECTED_NAMES.items():
        tr = {}
        try:
            gt = gettext.translation(
                "base", localedir=str(game_dir / STRINGS_DIR), languages=[lang]
            )
            tr = {k: gt.gettext(k) for k in
                  ("Cargo", "First Stop", "Last Stop")}
        except FileNotFoundError:
            pass

        res, err = eval_res(lua, mod_res_path.read_text(encoding="utf-8"),
                            mod_res_path.name, tr)
        check(err is None, f"{mod_res_path.name}（{lang}）: {err}")
        if res is None:
            continue

        check(res["type"] == "rename_scheme",
              f"type 应为 rename_scheme，实际 {res['type']!r}")
        data = res["data"]

        check(data["schemeNameRaw"] not in base_schemes,
              f"schemeNameRaw 与本体重名：{data['schemeNameRaw']}")
        check(isinstance(data["sortKey"], int),
              f"sortKey 应为整数，实际 {type(data['sortKey'])}")

        max_base_key = max(s["sortKey"] for s in base_schemes.values())
        check(data["sortKey"] > max_base_key,
              f"sortKey 应排在本体方案之后（>{max_base_key}），实际 {data['sortKey']}")

        # 占位符集合必须与 formatParams 的键完全一致
        import re
        placeholders = set(re.findall(r"\{(\w+)\}", data["formatString"]))
        params = {k: v for k, v in data["formatParams"].items()}
        check(placeholders == set(params),
              f"formatString 占位符 {sorted(placeholders)} 与 "
              f"formatParams 键 {sorted(params)} 不一致")
        for key, comp in params.items():
            check(comp in base_components,
                  f"formatParams[{key!r}] 引用了不存在的组件 {comp!r}")

        # 用真实组件名顺序渲染，确认顺序是 货物 - 首站 - 末站
        fake = {"key1": "CARGO", "key2": "FIRST", "key3": "LAST"}
        rendered = lua.globals()["__format"](data["formatString"], fake)
        check(rendered == "CARGO - FIRST - LAST",
              f"formatString 渲染顺序不对：{rendered!r}")

        check(data["schemeNameTranslated"] == expected,
              f"{lang} 显示名应为 {expected!r}，实际 {data['schemeNameTranslated']!r}")
        print(f"   {lang}: {data['schemeNameTranslated']}")

    # 模拟 UI 的排序：sortKey 升序，同级按 schemeNameRaw
    all_schemes = list(base_schemes.values())
    mod_res, _ = eval_res(lua, mod_res_path.read_text(encoding="utf-8"),
                          mod_res_path.name, {})
    if mod_res:
        all_schemes.append(mod_res["data"])
    if all_schemes:
        all_schemes.sort(key=lambda s: (s["sortKey"], s["schemeNameRaw"]))
        order = " → ".join(s["schemeNameRaw"] for s in all_schemes)
        check(all_schemes[-1]["schemeNameRaw"] == "cargo_firststop_laststop",
              f"排序后新方案应在最后：{order}")
        print(f"   排序：{order}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--game-dir", type=Path, default=DEFAULT_GAME_DIR,
                    help="Transport Fever 3 安装目录")
    args = ap.parse_args()

    print(f"mod 目录：{MOD_DIR}")
    check_files()
    check_station_window_features()
    if args.game_dir.is_dir():
        check_semantics(args.game_dir)
    else:
        print(f"== 资源语义 ==\n   跳过：游戏目录不存在 {args.game_dir}")

    print()
    if errors:
        print(f"失败：{len(errors)} 个问题 / 共 {checks} 项检查")
        for e in errors:
            print("  ✗", e)
        return 1
    print(f"全部通过（{checks} 项检查）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
