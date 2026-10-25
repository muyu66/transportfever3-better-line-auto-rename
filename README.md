# Transport Fever 3 Mods

本仓库包含三个可独立安装的《Transport Fever 3》Mod：

| 目录 / Mod ID | 显示名称 | 功能 |
| --- | --- | --- |
| `better_line_summary` | 更好的线路概览 | 新增非侵入式线路卡片，自然排序并高亮当前设施 |
| `better_rename_strategy_manual` | 更好的重命名策略（手动） | 提供线路命名方案，由玩家手动选择 |
| `better_rename_strategy_auto_apply` | 更好的重命名策略（自动应用） | 提供相同方案，并通过车辆到站事件自动应用 |

## better_line_summary

通过官方 `StationGroupEowExtensionPoint` 在车站窗口中新增“线路”卡片：

- 收集当前设施相关的所有线路并去重；
- 使用与全局线路管理器一致的 `lang_util.compareStrings()` 自然排序；
- 使用淡黄色 `#FFE68C` 高亮线路名称中的当前设施；
- 点击线路名称可打开线路窗口。

该 Mod 不替换 `StationGroupWindowContent`，不复制原版窗口，也不修改原版终点站列表。

## better_rename_strategy_manual

增加可手动选择的方案：

| 方案 | 示例 |
| --- | --- |
| 货物 - 首个停靠点 - 末个停靠点 | `谷物, 木材 - 北京中央车站 - 上海北站` |

在线路管理器中选择线路，点击“自动重命名”，再选择需要的方案。

## better_rename_strategy_auto_apply

包含手动版的全部方案，并增加事件驱动的自动应用：

- `update` 回调负责安全提交队列中的改名命令，不扫描线路。
- 首次加载旧存档时执行一次性追溯命名，所有非星号线路会分批应用新名称。
- 车辆到达线路站点时触发 `OnArriveAtStop`，并将改名任务加入队列。
- 每轮最多提交 10 条改名命令；队列保存在 GameScript 状态中，队列为空时立即返回。
- 只有停靠点、站点编号、终端或途经点路径变化时，才应用“货物 - 首个停靠点 - 末个停靠点”。
- 路径已处理时不会覆盖玩家后来手动设置的线路名。
- 线路名称去除尾部空格后以 `*` 结尾时，跳过追溯和后续自动修改。

线路必须有车辆实际运行并到站。无车辆、停运或无法到达下一站时不会自动改名。

## 启用组合

- `better_rename_strategy_manual` 与 `better_rename_strategy_auto_apply` 提供相同资源，不能同时启用。
- `better_line_summary` 可以与任一重命名 Mod 组合使用。
- `better_line_summary` 不使用 Recipe 替换，因此不会与其他车站窗口扩展插件争抢原版窗口。

## 安装

将需要的 Mod 根目录复制到：

```text
<Steam>/userdata/<steamid>/xxxxxxx/local/staging_area/
```

目录名必须与 `mod.json` 中的 `modId` 一致。修改后需要完全重启游戏。

## 开发与验证

```bash
python -m pip install -r requirements-dev.txt
python -B tools/validate_mods.py
```

游戏内置校验示例：

```powershell
"<TF3>\TransportFever3.exe" --validate StagingArea,better_line_summary out.json
"<TF3>\TransportFever3.exe" --validate StagingArea,better_rename_strategy_manual out.json
"<TF3>\TransportFever3.exe" --validate StagingArea,better_rename_strategy_auto_apply out.json
```

详细实现见 [DEV.md](DEV.md)。

## 许可证

仓库附带 MIT 开源许可证。

这是非官方社区项目，与 Urban Games 无隶属关系。《Transport Fever 3》及其原始资源归其权利人所有。
