# Better Line Auto Rename 开发文档

## 1. 项目目标

本项目为《Transport Fever 3》增加：

- 一个新的线路自动重命名方案；
- 车站终点站列表的名称排序与当前车站名称高亮。

Mod ID 与 Mod 根目录名固定为：

```text
better_line_auto_rename
```

`mod.json` 中的 `modId`、Mod 根目录名和 Mod 资源 URI 前缀必须保持一致。

## 2. 目录结构

```text
better_line_auto_rename/
├── mod.json
├── _content.json
├── _metadata/
│   └── modinfo.json
└── content/
    ├── scheme_cargo_firststop_laststop.res.lua
    ├── station_group_enhanced.res.lua
    ├── station_group_enhanced.script.tl
    └── station_group_enhanced.tl
```

`content/` 直接映射为 Mod 资源根。只有游戏要求固定层级的文件才需要继续增加目录。

## 3. 功能一：自动重命名方案

### 3.1 游戏机制

`manager_window.tl` 通过以下接口读取所有自动重命名方案：

```lua
api.res.genericRep.getAllOfType("rename_scheme")
```

方案资源包含：

- `schemeNameRaw`：稳定资源名；
- `schemeNameTranslated`：按钮显示名；
- `sortKey`：方案顺序；
- `formatString`：最终名称格式；
- `formatParams`：引用的组件资源。

### 3.2 本项目的实现

`scheme_cargo_firststop_laststop.res.lua` 复用游戏自带的：

- `cargo`
- `firststop`
- `laststop`

输出顺序为：

```text
{cargo} - {firststop} - {laststop}
```

资源名固定为 `cargo_firststop_laststop`，`sortKey` 必须大于原版三个方案，当前为 `23`。

## 4. 功能二与三：车站窗口增强

### 4.1 为什么不直接放同名 `station_group.tl`

TF3 不会用 Mod `content/` 中的同名 `.tl` 自动替换 GUI 源码。直接放同路径文件会被忽略，而且不会产生明显错误。

正确方式是使用 `react-replacement-config`，在 React 初始化时显式替换目标 recipe。

### 4.2 替换链路

`station_group_enhanced.res.lua`：

```lua
type = "react-replacement-config"
filePath = "better_line_auto_rename::/station_group_enhanced.script"
doReplaceFn = "doReplaceFn"
```

`station_group_enhanced.script.tl`：

1. 引用原版 `StationGroupWindowContent`；
2. 引用本 Mod 的增强版本；
3. 通过 `api.ReplaceRecipe(original, replacement)` 完成替换。

Mod 自定义脚本路径必须带 Mod ID 前缀：

```text
better_line_auto_rename::/station_group_enhanced.script
```

### 4.3 为什么需要复制完整窗口文件

终点站列表的排序和文本节点都由 `station_group.tl` 内部的局部 recipe 创建，游戏没有提供只修改该列表的公开回调。

因此 `station_group_enhanced.tl` 是基于当前游戏版本的完整副本，但做了两项隔离处理：

1. 所有 `ug_require` 使用 `::/` 绝对路径；
2. 所有内部 React recipe 使用 `BetterAutoRename` 唯一前缀，避免与原版 recipe 冲突。

### 4.4 排序

`TerminalStops` 不再依赖实体 ID 顺序，而是先收集线路实体：

```lua
table.sort(sortedLineEntities, function(a, b)
    return lang_util.compareStrings(nameA, nameB) < 0
end)
```

这与全局线路管理器的自然名称排序一致，例如 `Line 2` 会排在 `Line 10` 前。

### 4.5 当前车站名称高亮

当前车站名称来自：

```lua
api.engine.util.getEntityName(stationGroupEntityId)
```

显示名会被拆分为普通文本和匹配文本。匹配部分使用：

```lua
api.type.Vec4f.new(1.0, 0.90, 0.55, 1.0)
```

即 `#FFE68C` 淡黄色。选择该颜色的原因是：

- 与普通白色文本有明确区分；
- 比游戏金色 `Highlight` 更柔和；
- 在深色车站面板上保持足够对比度。

高亮只影响显示，不修改线路实体。

## 5. 本地开发

### 5.1 依赖

- Python 3.10+
- `lupa`

安装：

```bash
python -m pip install -r requirements-dev.txt
```

### 5.2 静态检查

```bash
python tools/validate_mod.py
```

默认游戏路径：

```text
C:\Game\Steam\steamapps\common\Transport Fever 3
```

可通过 `--game-dir` 覆盖。找不到游戏目录时，脚本仍会执行文件结构和 Mod 自身的静态检查。

### 5.3 本地安装

将整个 `better_line_auto_rename/` 放入：

```text
<Steam>/userdata/<steamid>/xxxxxx/local/staging_area/
```

修改 `.tl`、`.res.lua` 或 `_content.json` 后必须完全重启游戏。

### 5.4 游戏内置校验

```powershell
"<TF3>\TransportFever3.exe" --validate StagingArea,better_line_auto_rename out.json
```

游戏日志和错误信息位于：

```text
<Steam>/userdata/<steamid>/xxxxxx/local/crash_dump/
```

## 6. 发布流程

1. 更新 `mod.json` 的 `revision`，每次发布只增不减。
2. 更新 `_metadata/modinfo.json` 和 `CHANGELOG.md`。
3. 运行 `python tools/validate_mod.py`。
4. 在游戏中测试自动重命名方案、线路排序和高亮。

## 7. 兼容性说明

- 自动重命名方案是独立资源，通常可与其他方案 Mod 共存。
- 车站窗口通过 recipe replacement 修改，若其他 Mod 也替换 `StationGroupWindowContent`，两者可能互相覆盖。
- 不要同时使用多个基于不同原版窗口版本的车站 UI replacement Mod。

## 8. 重命名 Mod ID

若必须更改 Mod ID，需要同步修改：

```text
better_line_auto_rename/ 目录名
mod.json                  modId
content/station_group_enhanced.res.lua   filePath
content/station_group_enhanced.script.tl replacement require
tools/validate_mod.py     MOD_DIR / MOD_ID / 路径断言
README.md 与 DEV.md
```

没有完整同步这些位置会导致 `Resource not found`。
