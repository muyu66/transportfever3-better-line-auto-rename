local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local gui_react_util = ug_require "::/gui/main/gui_react_util.tl" as GuiReactUtil
local lang_util = ug_require "::/scripts/lang_util.tl" as LangUtil
local line_react_util = ug_require "::/gui/line_vehicle_mgmt/line_react_util.tl" as LineReactUtil
local react = ug_require "::/gui/main/react.lua" as React
local station_group_eow = ug_require "::/gui/entity_window/station_group/station_group_eow.script.tl" as StationGroupEow
local styleutil = ug_require "::/gui/main/styleutil.tl" as StyleUtil

local highlightColor <const> = api.type.Vec4f.new(1.0, 0.90, 0.55, 1.0)

local record LineSummaryEntry
	lineEntity : Engine.Entity
	name : string
end

local record LineSummaryContentParam
	lines : {LineSummaryEntry}
	highlightName : string
end

local makeHighlightedLineName = function(
	lineName : string,
	highlightName : string
) : TreeNodeId
	local textChildren : {TreeNodeId} = {}
	local searchStart = 1

	while highlightName ~= nil and highlightName ~= "" do
		local matchStart, matchEnd = string.find(
			lineName,
			highlightName,
			searchStart,
			true
		)
		if matchStart == nil then
			break
		end

		if matchStart > searchStart then
			textChildren[#textChildren + 1] = builtin.TextView{
				meta = { class = "font-scale-body" },
				text = string.sub(lineName, searchStart, matchStart - 1),
			}
		end

		textChildren[#textChildren + 1] = builtin.TextView{
			meta = {
				class = "font-scale-body",
				styleSheet = styleutil.makeStyle{
					color = highlightColor,
				},
			},
			text = string.sub(lineName, matchStart, matchEnd),
		}
		searchStart = matchEnd + 1
	end

	if #textChildren == 0 then
		return builtin.TextView{
			meta = { class = "font-scale-body" },
			text = lineName,
		}
	end

	if searchStart <= #lineName then
		textChildren[#textChildren + 1] = builtin.TextView{
			meta = { class = "font-scale-body" },
			text = string.sub(lineName, searchStart),
		}
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = textChildren,
	}
end

local LineSummaryRow = react.RegisterRecipe(
	"BetterLineSummaryRow",
	function(entry : LineSummaryEntry, highlightName : string) : TreeNodeId
		return builtin.BoxLayout{
			orientation = builtin.type.Orientation.Vertical,
			child = builtin.Button{
				content = builtin.BoxLayout{
					orientation = builtin.type.Orientation.Horizontal,
					children = {
						line_react_util.ColorWidget({
							entity = entry.lineEntity,
						}),
						gui_react_util.makeHorizontalSpacer(),
						makeHighlightedLineName(entry.name, highlightName),
					},
				},
				onClick = function()
					react.fireEvent(nil, "selectEntity", {
						entity = entry.lineEntity,
						stack = true,
					})
				end,
			},
		}
	end
)

local LineSummaryContent = react.RegisterRecipe(
	"BetterLineSummaryContent",
	function(params : LineSummaryContentParam) : TreeNodeId
		if #params.lines == 0 then
			return builtin.BoxLayout{
				orientation = builtin.type.Orientation.Vertical,
				child = builtin.TextView{
					meta = { class = "font-scale-body" },
					text = "-",
				},
			}
		end

		local children : {TreeNodeId} = {}
		for __, entry in ipairs(params.lines) do
			children[#children + 1] = LineSummaryRow(entry, params.highlightName)
		end

		return builtin.BoxLayout{
			orientation = builtin.type.Orientation.Vertical,
			children = children,
		}
	end
)

local better_line_summary = {}

better_line_summary.BetterLineSummaryPlugin = react.RegisterPluginRecipe(
	station_group_eow.StationGroupEowExtensionPoint,
	"BetterLineSummaryPlugin",
	function(
		params : StationGroupEow.StationGroupWidgetPluginParams
	) : TreeNodeId
		local makeLineSummary = function() : {LineSummaryEntry}
			local uniqueLineEntities : {Engine.Entity : boolean} = {}
			local lineStops = api.engine.system.lineSystem.getLineStops(
				params.entityId
			)
			for __, lineAndStop in ipairs(lineStops) do
				uniqueLineEntities[lineAndStop[1]] = true
			end

			local lineEntities : {Engine.Entity} = {}
			for lineEntity, __ in pairs(uniqueLineEntities) do
				if api.engine.entityExists(lineEntity) then
					lineEntities[#lineEntities + 1] = lineEntity
				end
			end

			table.sort(
				lineEntities,
				function(a : Engine.Entity, b : Engine.Entity) : boolean
					local aName = api.engine.util.getEntityName(a) or ""
					local bName = api.engine.util.getEntityName(b) or ""
					local comparison = lang_util.compareStrings(aName, bName)
					if comparison == 0 then
						return a < b
					end
					return comparison < 0
				end
			)

			local entries : {LineSummaryEntry} = {}
			for __, lineEntity in ipairs(lineEntities) do
				entries[#entries + 1] = {
					lineEntity = lineEntity,
					name = api.engine.util.getEntityName(lineEntity) or "",
				}
			end
			return entries
		end

		local makeHighlightName = function() : string
			return api.engine.util.getEntityName(params.entityId) or ""
		end

		local linesState = engine_react_util.useStepState(makeLineSummary)
		local highlightNameState = engine_react_util.useStepState(
			makeHighlightName
		)

		return builtin.BoxLayout{
			child = content_card.ContentCard{
				meta = { localKey = "betterLineSummary" },
				title = _("Lines"),
				initialCalloutTextPermanent = "",
				recipeAndParamPermanent = content_card.makeRecipeAndParam(
					LineSummaryContent,
					{
						lines = linesState:old(),
						highlightName = highlightNameState:old(),
					}
				),
				gameCtx = params.gameCtx,
				showOnRightSide = params.showCalloutOnRightSide,
			},
		}
	end
)

return better_line_summary
