--[[----------------------------------------------------------------------------
	首个停靠点 - 末个停靠点 - 城际

	复用游戏自带的 firststop / laststop 组件，分别输出线路第一个和最后一个
	非途经点车站的名称。末端固定词「城际」直接写在 formatString 中。
------------------------------------------------------------------------------]]

function data()
	return {
		type = "rename_scheme",
		data = {
			schemeNameRaw = "firststop_laststop_intercity",
			schemeNameTranslated = _("First Stop") .. " - " .. _("Last Stop") .. " - 城际",
			sortKey = 24,
			formatString = "{key1} - {key2} - 城际",
			formatParams = {
				["key1"] = "firststop",
				["key2"] = "laststop",
			},
		},
	}
end
