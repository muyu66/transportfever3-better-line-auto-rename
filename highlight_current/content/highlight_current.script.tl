local react = ug_require "::/gui/main/react.lua" as React
local original = ug_require "::/gui/entity_window/station_group/station_group.tl" as Recipe<IEntityWindowParam>
local replacement = ug_require "highlight_current::/highlight_current.tl" as Recipe<IEntityWindowParam>

local replacementConfig : ReactReplacementConfig = {}

replacementConfig.doReplaceFn = function(api : ReactReplacementApi)
	if react.GetRecipeId(original) == nil then
		log.error("[highlight_current] Could not resolve StationGroupWindowContent")
		return
	end
	api.ReplaceRecipe(original, replacement)
	log.message("[highlight_current] StationGroupWindowContent replaced")
end

return replacementConfig
