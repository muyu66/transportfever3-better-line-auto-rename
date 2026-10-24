# Better Line Auto Rename

《Transport Fever 3》线路自动重命名与车站终点站列表增强 Mod。

本项目提供两个相对独立的功能：

1. 为线路自动重命名增加两个方案：**货物 - 首个停靠点 - 末个停靠点**、**首个停靠点 - 末个停靠点 - 城际**。
2. 车站窗口中的终点站线路按线路名自然排序，并用柔和淡黄色高亮当前车站名称。

> Mod ID：`better_line_auto_rename`

## 功能

### 自动重命名方案

游戏内置三个方案，本 Mod 增加：

| 方案                           | 资源名                           |
| ------------------------------ | -------------------------------- |
| 货物 - 首个停靠点 - 末个停靠点 | `cargo_firststop_laststop`       |
| 首个停靠点 - 末个停靠点 - 城际 | `firststop_laststop_intercity`   |

示例结果：

```text
谷物, 木材 - 北京中央车站 - 上海北站
北京中央车站 - 上海北站 - 城际
```

两个方案都复用游戏自带的组件。第一个方案使用 `cargo`、`firststop`、`laststop`；第二个方案使用 `firststop`、`laststop`，输出线路首尾停靠站名称，并在末尾附加固定的「城际」。

游戏本体可直接复用的组件只有 `town`、`firststop`、`laststop`、`cargo`、`carrier`。其中 `town` 输出线路上出现次数最多的城市，不是首站或末站城市。

### 车站终点站增强

在车站窗口的「终点站」列表中：

- 线路按名称自然排序，使用与全局线路管理器一致的 `lang_util.compareStrings()`。
- 线路名中的当前车站名称使用 `#FFE68C` 淡黄色高亮。
- 同一名称在一条线路中出现多次时会全部高亮。
- 只改变显示，不修改线路名称或存档数据。

## 安装

### 方式一：Staging Area

1. 退出游戏。
2. 将 `better_line_auto_rename/` 整个目录复制到：

   ```text
   <Steam>/userdata/<steamid>/xxxxxx/local/staging_area/
   ```

3. 启动游戏，在 Mod 管理器中启用 **Better Line Auto Rename**。
4. 重新载入存档。

最终目录应类似：

```text
staging_area/
└── better_line_auto_rename/
    ├── mod.json
    ├── _content.json
    ├── _metadata/
    │   └── modinfo.json
    └── content/
        ├── scheme_cargo_firststop_laststop.res.lua
        ├── scheme_firststop_laststop_intercity.res.lua
        ├── station_group_enhanced.res.lua
        ├── station_group_enhanced.script.tl
        └── station_group_enhanced.tl
```

### 方式二：发布包

直接从游戏内的模组中心安装。

## 使用

### 自动重命名

打开线路管理器，选择线路，点击**自动重命名**，在方案列表中选择：

```text
货物 - 首个停靠点 - 末个停靠点
首个停靠点 - 末个停靠点 - 城际
```

### 车站列表

打开任意车站窗口，查看「终点站」区域。线路会按名称排序，线路名中的当前车站名称会显示为淡黄色。

## 兼容性

- 不影响存档结构。
- 不修改游戏安装目录中的原文件。
- 车站增强通过 `react-replacement-config` 替换 `StationGroupWindowContent`。如果其他 Mod 也替换同一个 recipe，最终显示取决于替换顺序。

## 开发与验证

开发细节、资源机制和维护步骤见 [DEV.md](DEV.md)。

安装验证依赖并运行：

```bash
python -m pip install -r requirements-dev.txt
python tools/validate_mod.py
```

脚本会检查：

- JSON 与 `_content.json` 文件清单；
- 自动重命名资源、占位符、组件引用和本地化；
- 车站 UI 替换配置、唯一 recipe 前缀、排序与高亮实现。

如果 Transport Fever 3 不在默认位置，可指定：

```bash
python tools/validate_mod.py --game-dir "D:\SteamLibrary\steamapps\common\Transport Fever 3"
```

也可以使用游戏内置校验器：

```powershell
"<TF3>\TransportFever3.exe" --validate StagingArea,better_line_auto_rename out.json
```

该命令需要启动游戏进程。

## 项目结构

```text
.
├── better_line_auto_rename/       # Mod 根目录，目录名必须等于 modId
├── tools/
│   └── validate_mod.py            # 本地静态检查
├── .github/workflows/validate.yml # GitHub Actions
├── DEV.md                         # 开发文档
├── CHANGELOG.md
└── README.md
```

## 许可证

仓库附带MIT开源许可证。

这是非官方社区 Mod，与 Urban Games 无隶属关系。《Transport Fever 3》及其原始资源归其权利人所有。
