local react = ug_require "::/gui/main/react.lua" as React
local original = ug_require "::/gui/entity_window/station_group/station_group.tl" as Recipe<IEntityWindowParam>
local replacement = ug_require "better_line_auto_rename::/station_group_enhanced.tl" as Recipe<IEntityWindowParam>

local replacementConfig : ReactReplacementConfig = {}

replacementConfig.doReplaceFn = function(api : ReactReplacementApi)
	if react.GetRecipeId(original) == nil then
		log.error("[better_line_auto_rename] Could not resolve StationGroupWindowContent")
		return
	end
	api.ReplaceRecipe(original, replacement)
	log.message("[better_line_auto_rename] StationGroupWindowContent replaced")
end

return replacementConfig
