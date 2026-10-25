# Transport Fever 3 Mods 开发文档

## 1. 三个独立包

```text
better_line_summary/
better_rename_strategy_manual/
better_rename_strategy_auto_apply/
```

每个目录都有独立的 `mod.json`、`_content.json`、`_metadata/` 和 `content/`。
目录名、`modId` 与 Mod 资源 URI 前缀必须一致。

## 2. 重命名方案

两个重命名 Mod 包含相同的资源：

- `scheme_cargo_firststop_laststop.res.lua`

方案复用游戏自带的 `cargo`、`firststop`、`laststop` 组件。
两个包使用相同的原始资源名，因此不能同时启用。
验证器会检查两个包中的方案文件完全一致。

## 3. 手动版

`better_rename_strategy_manual` 只包含方案资源，不包含 GameScript，
也不修改任何 GUI。

## 4. 自动应用版

`better_rename_strategy_auto_apply` 同时包含方案资源和：

```text
content/auto_apply_on_arrive_at_stop.gs.lua
content/auto_apply_on_arrive_at_stop.script.tl
```

`.gs.lua` 注册 `updateScript` 和 `handleEventScript`。队列存放在 GameScript
状态中，因此可以跨 `handleEvent` 与 `update` 的回调环境共享。

### 4.1 初始化

新游戏、地图游戏、任务、教程或旧存档迁移初始化时：

```lua
state:subscribeToEvent("OnArriveAtStop")
```

首次运行或从旧版状态迁移时，扫描一次当前玩家的已有线路：

- 非星号线路建立路径签名，并将需要更新的名字加入状态队列；
- 星号线路不建立签名，便于删除星号后在下一次到站时重新启用；
- 迁移完成后状态版本更新为 5，后续加载不会再次全局改名。

之后从存档恢复时保留已存签名，并清理已删除线路。

### 4.2 事件处理

只处理：

```lua
id == "TransportVehicleSystem"
name == "OnArriveAtStop"
```

`ArriveAtStop` 直接提供 `lineEntity`，因此不遍历线路列表。

路径签名包含：

- 停靠站组、站点编号和终端编号；
- 途经点 tag；
- 途经点 edge ID 或位置。

签名变化时才读取 `cargo_firststop_laststop` 方案，并将改名任务加入局部队列。
`update` 在安全阶段每轮最多提交 10 条
`api.cmd.makeEntitySetNameCmd()`；队列为空时立即返回，不扫描线路。
路径未变化时不会覆盖后来手动设置的名称。

线路名称去除尾部空格后若以 `*` 结尾，则跳过自动修改，并且不更新路径签名。
删除该星号后，车辆下一次到站会重新检查并应用自动名称。

## 5. 更好的线路概览

`better_line_summary` 使用资源类型：

```lua
type = "react-plugin ::StationGroupEowExtensionPoint"
```

插件通过官方 `StationGroupEowExtensionPoint` 在车站窗口中原有内容之后新增独立卡片，
不调用 `api.ReplaceRecipe()`，也不复制 `station_group.tl`。

插件使用 `api.engine.system.lineSystem.getLineStops(entityId)` 收集当前设施相关线路，
去重后按 `lang_util.compareStrings()` 自然排序。线路名称中的当前设施名称使用
`#FFE68C` 高亮，点击线路可打开线路窗口。

原版终点站列表保持原顺序和原始文本。

## 6. 本地验证

```bash
python -m pip install -r requirements-dev.txt
python -B tools/validate_mods.py
```

验证器检查：

- 三个包的目录、`modId`、清单、元数据和封面；
- 手动版与自动版的命名方案完全一致；
- 自动版不存在 tick 轮询或重复线路扫描；
- 自动版确实订阅 `OnArriveAtStop`，并通过状态队列和有界 `update` 提交命令；
- 线路概览版只使用官方扩展点，不包含 Recipe 替换或原版窗口副本；
- 线路概览版同时包含自然排序、重复名称高亮和线路点击跳转。

## 7. 安装与游戏校验

将需要的 Mod 根目录复制到：

```text
<Steam>/userdata/<steamid>/xxxxxxx/local/staging_area/
```

```powershell
"<TF3>\TransportFever3.exe" --validate StagingArea,better_line_summary out.json
"<TF3>\TransportFever3.exe" --validate StagingArea,better_rename_strategy_manual out.json
"<TF3>\TransportFever3.exe" --validate StagingArea,better_rename_strategy_auto_apply out.json
```

修改 `.tl`、`.res.lua` 或 `_content.json` 后必须完全重启游戏。

## 8. 发布

1. 更新目标 Mod 的 `mod.json` 的 `revision`，只增不减。
2. 更新 `_metadata/modinfo.json`。
3. 运行 `python -B tools/validate_mods.py`。
4. 在游戏中分别测试启用组合和存档兼容。
