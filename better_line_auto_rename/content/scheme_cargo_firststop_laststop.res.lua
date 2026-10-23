--[[----------------------------------------------------------------------------
	货物 - 首个停靠点 - 末个停靠点 —— Transport Fever 3 线路自动重命名方案

	游戏本体在 gui/line_vehicle_mgmt/auto_rename/ 下内置了 3 个方案：
	    firststop_laststop  「首个停靠点 - 末个停靠点」
	    town_cargo          「城镇 - 货物」
	    town_carrier        「城镇 - 承运商」
	它们在 UI 里不是硬编码的：manager_window.tl 用
	    api.res.genericRep.getAllOfType("rename_scheme")
	扫描所有已加载的 rename_scheme 资源，按 sortKey 排序后逐个生成按钮。
	所以 mod 只要再提供一个同类型的 .res.lua，就会自动出现在列表里。

	本方案不新增组件，直接复用本体已有的三个 rename_scheme_component：
	    cargo      —— 线路上运量最大的货物（最多列 3 种）
	    firststop  —— 第一个停靠站
	    laststop   —— 最后一个停靠站
	formatString / formatParams 的写法和本体方案完全一致。

	显示名用 _("Cargo") .. " - " .. _("First Stop") .. " - " .. _("Last Stop")
	拼出来，而不是写一个新的翻译键：这三个词条本体在所有语言里都已存在，
	这样中文界面会显示「货物 - 首个停靠点 - 末个停靠点」，英文、繁中亦然，
	mod 不必自带 locale 文件。
------------------------------------------------------------------------------]]

function data()
	return {
		type = "rename_scheme",
		data = {
			-- 全局唯一标识。与本体三个方案（firststop_laststop / town_cargo /
			-- town_carrier）不重名；sortKey 相同时 UI 会按这个字段排序。
			schemeNameRaw = "cargo_firststop_laststop",

			-- 按钮 tooltip 上显示的名字，由三个本体词条拼接而成。
			schemeNameTranslated = _("Cargo") .. " - " .. _("First Stop") .. " - " .. _("Last Stop"),

			-- 排在三个内置方案之后：内置 20 / 21 / 22。
			sortKey = 23,

			-- {key1} / {key2} / {key3} 会被 lang_util.format 替换成
			-- formatParams 对应组件算出来的字符串。
			formatString = "{key1} - {key2} - {key3}",
			formatParams = {
				["key1"] = "cargo",
				["key2"] = "firststop",
				["key3"] = "laststop",
			},
		},
	}
end
