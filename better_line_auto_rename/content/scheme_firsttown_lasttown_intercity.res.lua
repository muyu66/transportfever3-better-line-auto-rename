--[[----------------------------------------------------------------------------
	首站城市 - 末站城市 - 城际

	firsttown / lasttown 是本 Mod 提供的端点城市组件。它们按线路路径中的
	第一个、最后一个非途经点车站，找到该站所属城市并返回城市名。
	末端固定词「城际」直接写在 formatString 中，不需要额外组件。
------------------------------------------------------------------------------]]

function data()
	return {
		type = "rename_scheme",
		data = {
			schemeNameRaw = "firsttown_lasttown_intercity",
			schemeNameTranslated = "首站城市 - 末站城市 - 城际",
			sortKey = 24,
			formatString = "{key1} - {key2} - 城际",
			formatParams = {
				["key1"] = "firsttown",
				["key2"] = "lasttown",
			},
		},
	}
end
