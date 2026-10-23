local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local cargo_util = ug_require "::/gui/main/cargo_util.tl" as CargoUtil
local color_util = ug_require "::/gui/main/color_util.tl" as ColorUtil
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local entity_util = ug_require "::/scripts/entity_util.tl" as EntityUtil
local entity_window_hud = ug_require "::/gui/entity_window/entity_window_hud.tl" as EntityWindowHud
local eow_extension_util = ug_require "::/gui/entity_window/eow_extension_util.tl" as EowExtensionUtil
local entity_window_util = ug_require "::/gui/entity_window/entity_window_util.tl" as EntityWindowUtil
local gui_react_util = ug_require "::/gui/main/gui_react_util.tl" as GuiReactUtil
local hud_react_util = ug_require "::/gui/hud/hud_react_util.tl" as HudReactUtil
local lang_util = ug_require "::/scripts/lang_util.tl" as LangUtil
local line_react_util = ug_require "::/gui/line_vehicle_mgmt/line_react_util.tl" as LineReactUtil
local line_util = ug_require "::/gui/line_vehicle_mgmt/line_util.tl" as LineUtil
local react = ug_require "::/gui/main/react.lua" as React
local selector_react_util = ug_require "::/gui/main/selector_react_util.tl" as SelectorReactUtil
local station_group_eow = ug_require "::/gui/entity_window/station_group/station_group_eow.script.tl" as StationGroupEow
local styleutil = ug_require "::/gui/main/styleutil.tl" as StyleUtil
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard
local highlightColor = api.type.Vec4f.new(1.0, 0.90, 0.55, 1.0)

local makeHighlightedLineName = function(lineName : string, highlightName : string) : TreeNodeId
	local textChildren = {}
	local searchStart = 1

	while highlightName ~= nil and highlightName ~= "" do
		local matchStart, matchEnd = string.find(lineName, highlightName, searchStart, true)
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
local StationGroupViaLabel = react.RegisterRecipe("BetterAutoRenameStationGroupViaLabel", function(lineEntityId : Engine.Entity, stopIndex : integer) : TreeNodeId
	local makeNameState = function() : string
		if not api.engine.entityExists(lineEntityId) then
			return nil
		end
		local line = api.engine.getComponent(lineEntityId, api.type.ComponentType.LINE) as Engine.Component.Line
		local nextStop = ((stopIndex + 1) % #line.stops) 
		local stop = line.stops[nextStop + 1] 
		local nextName = api.engine.util.getEntityName(stop.stationGroup)
		local nextStationName = nextName or "invalid"
		return nextStationName
	end

	local nameState = engine_react_util.useStepState(makeNameState)

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.TextView{
				meta = { class ="font-scale-annotation, via-label" },
				text = _("via"),
			},
			builtin.TextView{
				meta = { class ="font-scale-annotation, station-name" },
				text = nameState:old(),
			},
		},
	}
end)

local record TerminalCounterParam
	countCurrent : integer
	countMaximum : integer
	isVeryBad : boolean
	countBad : integer
	showUnhappy : boolean
	tooltip : string
	overflowing : boolean
end

local TerminalCounter = react.RegisterRecipe("BetterAutoRenameTerminalCounter", function(params : TerminalCounterParam) : TreeNodeId
	local children = {}

	children[#children + 1] = builtin.Component{
		meta = { class = "count-labels" },
	}
	
	local happinessClass = ""
	if params.countBad and params.countBad > 0 then
		happinessClass = params.isVeryBad and "inferior, very" or "inferior"
	end

	local overflowingClass = ""
	if params.overflowing then
		overflowingClass = "inferior"

		local makeOverflowWarning = function() : TreeNodeId
			return builtin.ImageView{
				meta = {
					class = "terminal-overflow-alert",
					tooltip = _("Some passengers may leave because the station is overloaded."),
				},
				path = "::/gui/entity_window/icons/terminal_full.tga",
				scaling = builtin.type.ImageViewScaling.AutoFit,
			}
		end

		table.insert(children, makeOverflowWarning())
	end


	if params.countCurrent > 0 or params.countMaximum > 0 then
		children[#children + 1] = builtin.TextView{
			meta = {
				class = "font-scale-annotation, count-labels, count-label-left, " .. overflowingClass,
				tooltip = params.tooltip,
			},
			text = lang_util.formatInt(params.countCurrent),
		}
	else
		children[#children + 1] = builtin.Component{
			meta = { class = "count-labels, count-label-left" },
		}
	end

	if params.countMaximum > 0 then
		children[#children + 1] = builtin.TextView{
			meta = {
				class = "font-scale-annotation, count-labels, count-label-slash, ",
				tooltip = params.tooltip,
			},
			text = "/",
		}
		children[#children + 1] = builtin.TextView{
			meta = {
				class = "font-scale-annotation, count-labels, count-label-right, ",
				tooltip = params.tooltip,
			},
			text = lang_util.formatInt(params.countMaximum),
		}
	else
		children[#children + 1] = builtin.Component {
			meta = { class = "count-labels, count-label-slash" },
		}
		children[#children + 1] = builtin.Component {
			meta = { class = "count-labels, count-label-right" },
		}
	end

	if params.countCurrent > 0 or params.countMaximum > 0 then
		children[#children + 1] = builtin.ImageView{
			meta = {
				class = "count-image",
				tooltip = _("Passengers"),
			},
			path = cargo_util.getPassengerCargoIcon(),
		}
	else 
		children[#children + 1] = builtin.Component{
			meta = { class = "count-image" },
		}
	end

	if params.showUnhappy and (params.countBad and (params.countBad > 0)) then
		children[#children + 1] = gui_react_util.EmoteIcon{
			satisfaction = "Aloof",
			tooltip = _("Unhappy Passengers"),
		}
		children[#children + 1] = builtin.TextView{
			meta = {
				class = "font-scale-annotation, count-labels, count-label-right, " .. happinessClass,
				tooltip = params.tooltip,
			},
			text = lang_util.formatInt(params.countBad),
		}
	else
		children[#children + 1] = builtin.Component{
			meta = { class = "count-image" },
		}
		children[#children + 1] = builtin.Component{
			meta = { class = "count-labels, count-label-right" },
		}
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end)

local LineStopButton = react.RegisterRecipe("BetterAutoRenameLineStopButton", function(lineEntityId : Engine.Entity, stopIndex : integer, highlightName : string) : TreeNodeId
	local makeNameState = function() : string
		local name = api.engine.util.getEntityName(lineEntityId)
		local line = api.engine.getComponent(lineEntityId, api.type.ComponentType.LINE) as Engine.Component.Line
		local stationName = name or "invalid"

		local numStops = #line.stops
		if stopIndex ~= nil and stopIndex >= 0 and numStops > 0 then
			local nextStopIndex = (stopIndex + 1) % numStops
			local nextStop = line.stops[nextStopIndex + 1] -- +1 to achieve 1-based index
			local nextName = api.engine.util.getEntityName(nextStop.stationGroup)
			local nextStationName = nextName or "invalid"
			return string.format("%s - %s", stationName, nextStationName)
		end

		return stationName
	end

	local nameState = engine_react_util.useStepState(makeNameState)

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.Button{
				content = builtin.BoxLayout{ 
					orientation = builtin.type.Orientation.Horizontal,
					children = {
						line_react_util.ColorWidget({
							entity = lineEntityId,
						}),
						makeHighlightedLineName(nameState:old(), highlightName),
					},
				},
				onClick = function()
					react.fireEvent(
						nil,
						"selectEntity",
						{
							entity = lineEntityId,
							stack = true
						}
					)
				end
			},
		}
	}
end)

local record TerminalTitleParam
	terminalIndex : integer
	displayNumber : integer
	isPassengerTerminal : boolean
	isCargoTerminal : boolean
	cargoClass : string
	terminalLength : number
end

local TerminalTitle = react.RegisterRecipe("BetterAutoRenameTerminalTitle", function(param : TerminalTitleParam) : TreeNodeId
	local children = {}

	if param.displayNumber == nil then
		children[#children + 1] = builtin.ImageView{
			meta = {
				class = "iconlabelindicator-icon-size",
			},
			path = "::/gui/entity_window/icons/station_pool.tga",
			scaling = builtin.type.ImageViewScaling.AutoFit,
		}
	else
		children[#children + 1] = line_react_util.makeTerminalIndicator(param.displayNumber, true)
	end

	local terminalText = ""
	local bubbleColor : Vec3f

	if param.terminalIndex == nil then
		terminalText = _("Waiting Hall")
	else
		terminalText = _("Passenger and Cargo")
		if param.isPassengerTerminal then
			if not param.isCargoTerminal then
				terminalText = _("Passenger")
			end
		else
			if param.cargoClass ~= "UNIVERSAL" then
				local cargoClassId = api.res.cargoClassRep.getCargoClassId(param.cargoClass)
				if cargoClassId ~= -1 then
					local specializationData = api.res.cargoClassRep.get(cargoClassId)

					terminalText = specializationData.name
					bubbleColor = specializationData.color
				else
					terminalText = _("All Cargo Types")
				end
			else
				terminalText = _("All Cargo Types")
			end
		end
	end

	local brightness = bubbleColor and ((bubbleColor.x + bubbleColor.y + bubbleColor.z) / 3.0) or 0
	local invertTextClass = (brightness > 0.5) and "invert, " or ""

	children[#children + 1] = builtin.TextView{
		meta = {
			class = invertTextClass .. "font-scale-body, terminal-label-compact, bubble",
			styleSheet = styleutil.makeStyle{
				backgroundColor1 = bubbleColor
					and { bubbleColor.x, bubbleColor.y, bubbleColor.z, 1.0 }
					or { 0, 0, 0, 0 },
			},
		},
		text = terminalText,
	}

	children[#children + 1] = gui_react_util.makeHorizontalSpacer()

	if param.terminalLength ~= nil and param.terminalLength > 0 then
		children[#children + 1] = builtin.TextView{
			meta = { class = "font-scale-annotation, terminal-length", },
			text = api.util.formatLength(param.terminalLength),
		}
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end)

local record StopAndQualityState
	stopIndex0 : integer
	qualityData : UtilCargo.CargoQualityData
	hasOverlength : boolean
	tooltip : string
end

local record TerminalStopsParam
	line2StopAndQuality : {Engine.Entity : {StopAndQualityState}}
	isCargoTerminal : boolean
	highlightName : string
end

local TerminalStops = react.RegisterRecipe("BetterAutoRenameTerminalStops", function(params : TerminalStopsParam) : TreeNodeId
	local children = {}

	local makeTerminalLengthWarning = function() : TreeNodeId
		return builtin.ImageView{
			meta = {
				class = "terminal-length-alert",
				tooltip = _("Terminal is too short for some vehicles."),
			},
			path = "::/gui/statistics/icons/alert.tga",
			scaling = builtin.type.ImageViewScaling.AutoFit,
		}
	end

	if params.line2StopAndQuality ~= nil then
		-- Match the global line manager's name sorting instead of the entity-id order
		-- produced by orderedPairs.
		local sortedLineEntities : {Engine.Entity} = {}
		for lineEntity, __ in pairs(params.line2StopAndQuality as {Engine.Entity : {StopAndQualityState}}) do
			sortedLineEntities[#sortedLineEntities + 1] = lineEntity
		end
		table.sort(sortedLineEntities, function(a : Engine.Entity, b : Engine.Entity) : boolean
			local aName = api.engine.util.getEntityName(a) or ""
			local bName = api.engine.util.getEntityName(b) or ""
			local comparison = lang_util.compareStrings(aName, bName)
			if comparison == 0 then
				return a < b
			end
			return comparison < 0
		end)

		for __, lineEntity in ipairs(sortedLineEntities) do
			local stopsAndQualities = params.line2StopAndQuality[lineEntity]
			local lineChildren = {}
			
			local stopsAndQualitiesForLine = (stopsAndQualities as {StopAndQualityState})

			if #(stopsAndQualitiesForLine) == 1 then
				lineChildren[#lineChildren + 1] = builtin.FloatingLayout{
					children = {
						builtin.FloatingLayoutChild{
							h = -1,
							v = -1,
							item = builtin.BoxLayout{
								orientation = builtin.type.Orientation.Horizontal,
								children = {
									LineStopButton(lineEntity as Engine.Entity, nil, params.highlightName),
									gui_react_util.makeHorizontalSpacer(),
									TerminalCounter{
										countCurrent = stopsAndQualitiesForLine[1].qualityData.countTotal,
										countMaximum = 0,
										isVeryBad = stopsAndQualitiesForLine[1].qualityData.isVeryBad,
										countBad = stopsAndQualitiesForLine[1].qualityData.countBad,
										showUnhappy = true,
										tooltip = stopsAndQualitiesForLine[1].tooltip,
									},
								}
							}
						},
						stopsAndQualitiesForLine[1].hasOverlength and builtin.FloatingLayoutChild{
							h = 0,
							v = 0.5,
							item = makeTerminalLengthWarning()
						} or nil,
					}
				}
			else
				lineChildren[#lineChildren + 1] = LineStopButton(lineEntity as Engine.Entity, nil, params.highlightName)

				for __, stopAndQuality in ipairs(stopsAndQualitiesForLine) do
					lineChildren[#lineChildren + 1] = builtin.FloatingLayout{
						children = {
							builtin.FloatingLayoutChild{
								h = -1,
								v = -1,
								item = builtin.BoxLayout{
									orientation = builtin.type.Orientation.Horizontal,
									children = {
										StationGroupViaLabel(lineEntity as Engine.Entity, stopAndQuality.stopIndex0),
										gui_react_util.makeHorizontalSpacer(),
										TerminalCounter{
											countCurrent = stopAndQuality.qualityData.countTotal,
											countMaximum = 0,
											isVeryBad = stopAndQuality.qualityData.isVeryBad,
											countBad = stopAndQuality.qualityData.countBad,
											showUnhappy = true,
											tooltip = stopAndQuality.tooltip,
										},
									}
								}
							},
							stopsAndQualitiesForLine[1].hasOverlength and builtin.FloatingLayoutChild{
								h = 0,
								v = 0.5,
								item = makeTerminalLengthWarning()
							} or nil,
						}
					}
				end
			end
			
			children[#children + 1] = builtin.BoxLayout{
				orientation = builtin.type.Orientation.Vertical,
				children = lineChildren,
			}
		end
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = children
	}
end)

local record TerminalBarParam
	terminalIndex : integer
	displayNumber : integer
	capacityUsage : UtilLine.TerminalCapacityUsage
	isPassengerTerminal : boolean
	isCargoTerminal : boolean
	cargoClass : string
	terminalLength : number
	hasVeryBadStop : boolean
	countBadAllStops : integer
	overflowing : boolean
end

local TerminalBar = react.RegisterRecipe("BetterAutoRenameTerminalBar", function(param : TerminalBarParam) : TreeNodeId
	local children = {}
	
	children[#children + 1] = TerminalTitle{
		terminalIndex = param.terminalIndex,
		displayNumber = param.displayNumber,
		isPassengerTerminal = param.isPassengerTerminal,
		isCargoTerminal = param.isCargoTerminal,
		cargoClass = param.cargoClass,
		terminalLength = param.terminalLength,
	}

	children[#children + 1] = gui_react_util.makeHorizontalSpacer()

	children[#children + 1] = TerminalCounter{
		countCurrent = param.capacityUsage and param.capacityUsage.used or 0,
		countMaximum = param.capacityUsage and param.capacityUsage.capacity or 0,
		isVeryBad = param.hasVeryBadStop,
		countBad = param.countBadAllStops,
		overflowing = param.overflowing,
		showUnhappy = false,
	}

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end)

local record TerminalStopState
	terminalHasPlayerStops : boolean
	line2StopAndQuality : {Engine.Entity : {StopAndQualityState}}
	isPassengerTerminal : boolean
	isCargoTerminal : boolean
	cargoClass : string
	terminalLength : number
end

local record TerminalState
	terminalIndex : integer -- Note: zero based index
	displayNumber : integer
	capacityUsage : UtilLine.TerminalCapacityUsage
	terminalLineStops : TerminalStopState
	terminalLineStopsCount : integer
	hasVeryBadStop : boolean
	countBadAllStops : integer
	overflowing : boolean
end

local record TerminalsAndStopsState
	waitingHallCapacityUsages : {UtilLine.TerminalCapacityUsage}
	station2TerminalStates : {{Engine.Entity, {TerminalState}}}
	highlightName : string
end

local record TerminalsAndStopsParams
	stateParams : TerminalsAndStopsState
	key : string
	gameCtx : GameContext
	showOnRightSide : boolean
	lastInScrollAreaRef : ReactRefWrap
end

local TerminalsAndStops = react.RegisterRecipe("BetterAutoRenameTerminalsAndStops", function(params : TerminalsAndStopsParams) : TreeNodeId
	local children = {}

	for i, terminalStates in ipairs(params.stateParams.station2TerminalStates) do
		for j, terminalState in ipairs(terminalStates[2]) do
			local lastEntry = i == #params.stateParams.station2TerminalStates and j == #terminalStates[2]
			local hasStops = terminalState.terminalLineStopsCount > 0
			local localKey = params.key .. "-" .. tostring(i) .. "-" .. tostring(j)

			local cardChildren = {}

			cardChildren[#cardChildren + 1] = TerminalBar{
				terminalIndex = terminalState.terminalIndex,
				displayNumber = terminalState.displayNumber,
				capacityUsage = terminalState.capacityUsage,
				isPassengerTerminal = terminalState.terminalLineStops.isPassengerTerminal,
				isCargoTerminal = terminalState.terminalLineStops.isCargoTerminal,
				cargoClass = terminalState.terminalLineStops.cargoClass,
				terminalLength = terminalState.terminalLineStops.terminalLength,
				hasVeryBadStop = terminalState.hasVeryBadStop,
				countBadAllStops = terminalState.countBadAllStops,
				overflowing = terminalState.overflowing,
			}
			
			if hasStops then
				cardChildren[#cardChildren + 1] = TerminalStops{
					line2StopAndQuality = terminalState.terminalLineStops.line2StopAndQuality,
					isCargoTerminal = terminalState.terminalLineStops.isCargoTerminal,
					highlightName = params.stateParams.highlightName,
				}
			end

			if lastEntry then
				children[#children + 1] = content_card.ContentCard(react.ref(params.lastInScrollAreaRef), {
					meta = { localKey = localKey, },
					extraChildrenPermanent = cardChildren,
					separatorBetweenExtraChildren = true,
				})
			else
				children[#children + 1] = content_card.ContentCard{
					meta = { localKey = localKey, },
					extraChildrenPermanent = cardChildren,
					separatorBetweenExtraChildren = true,
				}
			end
		end
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = children
	}
end)

local record StationGroupStatisticsParam
	entityId : Engine.Entity
	logNames : {string}
	labels : {string}
	colors : {Vec4f}
	styleClass : string
	chartType : EntityWindowUtil.DiagramType
	showTimeScaleSlider : boolean
	showLegend : boolean
	legendOrientation : Builtin.Type.Orientation
	initialNumYearsToDisplay : integer
	minNumYearsToDisplay : integer
	nextUpFocusRef : ReactRefWrap
end

local StationGroupStatistics = react.RegisterRecipe("BetterAutoRenameStationGroupStatistics", function(params : StationGroupStatisticsParam) : TreeNodeId
	local isSelectedState = react.useState(false)
	local chartRef = react.useNodeRef()

	if params.nextUpFocusRef ~= nil and params.nextUpFocusRef:get() then
		react.useInputAction("IA_NAV_UP", react.iaHandler(function()
			params.nextUpFocusRef:get():focus()
		end))
	end

	if isSelectedState:old() then
		react.useInputAction("IA_MENU_BACK", react.iaHandler(
			function()
				isSelectedState:set(false)
			end
		))
	else
		react.useInputAction("IA_SELECT", react.iaHandler(
			function()
				isSelectedState:set(true)
				chartRef:get():focus()
			end
		))
	end

	return builtin.BoxLayout{
		child = builtin.Component{
			meta = {
				class = isSelectedState:old() and "inspect" or "",
				forceFocusable = true,
				disableFocusableRecursive = not isSelectedState:old(),
			},
			layout = builtin.BoxLayout{
				orientation = builtin.type.Orientation.Vertical,
				children = {
					entity_window_util.EntityDiagramWidget(react.ref(chartRef), {
						meta = {
							onFocusChange = function(focus : boolean)
								if not focus then
									isSelectedState:set(false)
								end
							end,
						},
						entityId = params.entityId,
						logNames = params.logNames,
						labels = params.labels,
						colors = params.colors,
						styleClass = params.styleClass,
						chartType = params.chartType,
						showTimeScaleSlider = params.showTimeScaleSlider,
						showLegend = params.showLegend,
						legendOrientation = params.legendOrientation,
						initialNumYearsToDisplay = params.initialNumYearsToDisplay,
						minNumYearsToDisplay = params.minNumYearsToDisplay,
					}),
				},
			},
		},
	}
end)

local StationGroupWindowContent = react.RegisterRecipe("BetterAutoRenameStationGroupWindowContent", function(params : IEntityWindowParam) : TreeNodeId
	local defaultColorsRef = react.useRefLazy(function() : DefaultColors return api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/default_colors.gres")).data as DefaultColors end)
	local stationGroupEntityId = params.keyEntity

	local entityIsOwnedByPlayerState = engine_react_util.useStepState(function() : boolean
		return entity_util.isOwnedByPlayer(stationGroupEntityId)
	end)
	
	local makeStationEntitiesState = function() : {Engine.Entity}
		local constructions : {Engine.Entity} = {}
		local stationGroup : Engine.Component.StationGroup = api.engine.getComponent(stationGroupEntityId, api.type.ComponentType.STATION_GROUP)
		if stationGroup then
			for __, station in ipairs(stationGroup.stations) do
				local construction = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(station)
				if api.engine.entityExists(construction) then
					constructions[#constructions + 1] = construction
				end
			end
		end
		return constructions
	end

	local makeTerminalsAndStopsState = function() : TerminalsAndStopsState
		local calculateCapacityUsage = function(stationId : Engine.Entity, terminalIndex : integer) : UtilLine.TerminalCapacityUsage
			if not api.engine.util.station.isStationOfType(stationId, false) then
				return nil
			end
			return api.engine.util.station.calculateStationTerminalUsage(stationId, terminalIndex)
		end

		local makeStopTooltip = function(line : Engine.Entity, stopIndex : integer, passengerCargoTypeId : CargoTypeId) : string
			local getStopNumberAndCount = function(lineComp : Engine.Component.Line, stopIndex2 : integer) : {integer : integer}
				local stopNumber = 0
				local stopCount = 0
				for i, stop in ipairs(lineComp.stops) do
					local count = #stop.waypoints + 1
					if (i - 1) < stopIndex2 then 
						stopNumber = stopNumber + count
					end
					stopCount = stopCount + count
				end
				return {stopNumber, stopCount}
			end

			local tooltip = _("Destinations:\n")

			local passengers = api.engine.system.simEntityAtTerminalSystem.getLineStopSimEntities(line, stopIndex, passengerCargoTypeId)
			local destinations2PassengerCount : {integer : integer} = {}

			for __, passenger in ipairs(passengers) do
				local simEntityAtTerminal = api.engine.getComponent(passenger, api.type.ComponentType.SIM_ENTITY_AT_TERMINAL) as Engine.Component.SimEntityAtTerminal
				if destinations2PassengerCount[simEntityAtTerminal.lineStop1] == nil then
					destinations2PassengerCount[simEntityAtTerminal.lineStop1] = 0
				end
				destinations2PassengerCount[simEntityAtTerminal.lineStop1] = destinations2PassengerCount[simEntityAtTerminal.lineStop1] + 1
			end

			local lineComponent = api.engine.getComponent(line, api.type.ComponentType.LINE) as Engine.Component.Line

			for stopIndex2, count2 in pairs(destinations2PassengerCount) do
				local stationName = api.engine.util.getEntityName(lineComponent.stops[stopIndex2+1].stationGroup)

				local stopNumberAndCount = getStopNumberAndCount(lineComponent, stopIndex2)
				local tooltipLine = lang_util.format("[{stopNumber}] {stationName} {count}\n", {
					stopNumber = lang_util.formatInt(stopNumberAndCount[1] + 1), -- stop numbers start at 0 internally but display starts at 1
					stationName = stationName,
					count = lang_util.formatInt(count2),
				})
				tooltip = tooltip .. tooltipLine
			end

			tooltip = string.sub(tooltip, 1, -2)
			return tooltip
		end

		local gatherTerminalStops = function(stationEntity : Engine.Entity, terminalIndex : integer, station : Engine.Component.Station) : TerminalStopState
			local terminalHasPlayerStops = false
			local terminal2stops = api.engine.system.lineSystem.getLineStopsForTerminal(stationEntity, terminalIndex)
			
			local line2StopAndQuality : {Engine.Entity : {StopAndQualityState}} = {}
			for __, terminalStops in ipairs(terminal2stops) do
				local lineEntity = terminalStops[1] as Engine.Entity
				if entity_util.isOwnedByPlayer(lineEntity) then
					terminalHasPlayerStops = true
					local stopIndex0 = terminalStops[2]

					local passengerCargoTypeId = cargo_util.getPassengerCargoTypeId()
					local qualityData = api.engine.util.cargo.getCargoQualityDataAtStop(lineEntity, stopIndex0, passengerCargoTypeId)

					local stopAndQuality : StopAndQualityState = {}
					stopAndQuality.stopIndex0 = stopIndex0
					stopAndQuality.qualityData = qualityData
					stopAndQuality.tooltip = makeStopTooltip(lineEntity, stopIndex0, passengerCargoTypeId)

					local stationTerminal2overlength = api.engine.system.transportVehicleSystem.checkLineStopForVehicleOverlength(
						lineEntity,
						stopIndex0
					)
					local hasOverlength = false
					for _stationTerminal, __ in pairs(stationTerminal2overlength) do
						hasOverlength = true
					end
					stopAndQuality.hasOverlength = hasOverlength

					if line2StopAndQuality[lineEntity] == nil then
						line2StopAndQuality[lineEntity] = {}
					end
					table.insert(line2StopAndQuality[lineEntity], stopAndQuality)
				end
			end

			local terminalIndex1 = terminalIndex + 1

			local terminal = station.terminals[terminalIndex1]
			local cargoClass : string
			for __, transferSpeed in ipairs(terminal.cargoTransferSpeeds) do
				for __, class in ipairs(transferSpeed.cargoTypeSet.cargoClassesIncluded) do
					cargoClass = class
				end
			end

			local terminalLength = line_util.getTerminalLength(stationEntity, terminalIndex1)

			local terminalStopState : TerminalStopState = {
				terminalHasPlayerStops = terminalHasPlayerStops,
				line2StopAndQuality = line2StopAndQuality,
				isPassengerTerminal = terminal.passengersLoad or terminal.passengersUnload,
				isCargoTerminal = terminal.cargoLoad or terminal.cargoUnload,
				cargoClass = cargoClass,
				terminalLength = terminalLength,
			}

			return terminalStopState
		end

		local station2terminalStates : {{Engine.Entity, {TerminalState}}} = {}
		local waitingHallCapacityUsages : {UtilLine.TerminalCapacityUsage} = {}

		local stationGroup = api.engine.getComponent(stationGroupEntityId, api.type.ComponentType.STATION_GROUP) as Engine.Component.StationGroup
		local displayNumber = 1
		for __, stationId in ipairs(stationGroup.stations) do
			local station = api.engine.getComponent(stationId, api.type.ComponentType.STATION) as Engine.Component.Station

			local terminalsOfStation = {}
			
			local stationIsOverflowing = false
			if station.pool.capacity > 0 then
				local capacityUsage = calculateCapacityUsage(stationId, -1)
				waitingHallCapacityUsages[#waitingHallCapacityUsages + 1] = capacityUsage
				if capacityUsage then
					stationIsOverflowing = waitingHallCapacityUsages[#waitingHallCapacityUsages].used > waitingHallCapacityUsages[#waitingHallCapacityUsages].capacity
				end
			end


			for i, __ in ipairs(station.terminals) do
				local terminalLineStops = gatherTerminalStops(stationId, i - 1, station)
				local terminalLineStopsCount = 0

				local hasVeryBadStop = false
				local countBadAllStops = 0

				for __, line2StopAndQuality in orderedPairs(terminalLineStops.line2StopAndQuality) do
					for __, stopAndQuality in orderedPairs(line2StopAndQuality as {Engine.Entity : {StopAndQualityState}}) do
						local stopQualityData = (stopAndQuality as StopAndQualityState).qualityData
						countBadAllStops = countBadAllStops + stopQualityData.countBad
						hasVeryBadStop = stopQualityData.isVeryBad and true or hasVeryBadStop
						terminalLineStopsCount = terminalLineStopsCount + 1
					end
				end

				local terminalCapacityUsage = calculateCapacityUsage(stationId, i - 1)

				local overflowing = (terminalCapacityUsage and terminalCapacityUsage.used > terminalCapacityUsage.capacity) 
					and (stationIsOverflowing or station.pool.capacity == 0)

				local terminalState : TerminalState = {
					terminalIndex = i - 1,
					displayNumber = displayNumber,
					capacityUsage = terminalCapacityUsage,
					terminalLineStops = terminalLineStops,
					terminalLineStopsCount = terminalLineStopsCount,
					hasVeryBadStop = hasVeryBadStop,
					countBadAllStops = countBadAllStops,
					overflowing = overflowing,
				}

				terminalsOfStation[#terminalsOfStation + 1] = terminalState
				displayNumber = displayNumber + 1
			end

			table.insert(station2terminalStates, {stationId, terminalsOfStation})
		end

		return {
			waitingHallCapacityUsages = waitingHallCapacityUsages,
			highlightName = api.engine.util.getEntityName(stationGroupEntityId) or "",
			station2TerminalStates = station2terminalStates,
		}
	end

	local stationEntitiesState = engine_react_util.useStepState(makeStationEntitiesState)
	local terminalsAndStopsState = engine_react_util.useStepState(makeTerminalsAndStopsState)

	-- overview
	local widgets = {}
	local refSelf = react.useSelfRef()
	local showOnRightSide = content_card.useShowCalloutOnRight(refSelf)

	local initialFocusRef = react.useNodeRef()
	local initialFocusDummyRef = react.useNodeRef()
	widgets[#widgets + 1] = builtin.Component(react.ref(initialFocusDummyRef), {
		meta = {
			forceFocusable = api.util.getInputMode() ~= api.type["enum"].InputMode.Gamepad,
		},
	})
	react.onMount(function()
		if api.util.getInputMode() == api.type["enum"].InputMode.Gamepad and initialFocusRef:get() then
			initialFocusRef:get():focus()
		else
			initialFocusDummyRef:get():focus()
		end
	end)

	local allKeys = {
		stationGroupTerminalAndStopsCard = "stationGroupTerminalAndStops",
		stationGroupWaitingHallCard = "stationGroupWaitingHall",
		stationGroupTerminalsTitleCard = "stationGroupTerminalsTitle",
		stationGroupStatisticsCard = "stationGroupStatistics",
	}
	local collapsibleCardsState : ReactStateT<{string : boolean}> = react.useState({})
	local updateCollapsibleState, isExpanded = content_card.makeContentCardsCollapsibleFunctions(collapsibleCardsState, true)
	local extensionParams : StationGroupEow.StationGroupWidgetPluginParams = {
		entityId = stationGroupEntityId,
		gameCtx = params.gameCtx,
		showCalloutOnRightSide = showOnRightSide,
		setCollapsibleExpanded = updateCollapsibleState,
		getCollapsibleExpanded = isExpanded,
		ownershipState = eow_extension_util.useOwnershipStepState(stationGroupEntityId):old(),
	}

	-- notifications
	widgets[#widgets + 1] = entity_window_util.NotificationWidget(stationGroupEntityId)
	for __, stationEntity in ipairs(stationEntitiesState:old()) do
		widgets[#widgets + 1] = entity_window_util.NotificationWidget(stationEntity)
	end

	local pluginWidgets = gui_react_util.usePlugins(station_group_eow.StationGroupEowExtensionPoint, nil, extensionParams)
	for __, widget in ipairs(pluginWidgets) do
		widgets[#widgets + 1] = widget
	end

	-- waiting halls
	for __, waitingHallCapacityUsage in ipairs(terminalsAndStopsState:old().waitingHallCapacityUsages) do
		widgets[#widgets + 1] = content_card.ContentCard{
			meta = { localKey = allKeys.stationGroupWaitingHallCard, },
			initialCalloutTextPermanent = "", --_("CALLOUT_LLOUT_STATIONGROUP_WAITINGHALL"),
			recipeAndParamPermanent = content_card.makeRecipeAndParam(
				TerminalBar,
				{
					capacityUsage = waitingHallCapacityUsage,
				}
			),
			gameCtx = params.gameCtx,
			showOnRightSide = showOnRightSide,
		}
	end

	widgets[#widgets + 1] = content_card.ContentCard{
		meta = { localKey = allKeys.stationGroupTerminalsTitleCard, },
		title = _("Terminals"),
		gameCtx = params.gameCtx,
		showOnRightSide = showOnRightSide,
	}

	local lastInScrollAreaRef = react.useNodeRef()

	--terminal and stops widget
	widgets[#widgets + 1] = TerminalsAndStops{
		stateParams = terminalsAndStopsState:old(),
		key = allKeys.stationGroupTerminalAndStopsCard,
		gameCtx = params.gameCtx,
		showOnRightSide = showOnRightSide,
		lastInScrollAreaRef = lastInScrollAreaRef,
	}
	
	local layerConfig = api.type.LayerConfig.new()
	local catchmentAreaRenderableConfig = api.type.LayerConfig.CatchmentAreaRenderableConfig.new()
	catchmentAreaRenderableConfig.isVisible = true
	catchmentAreaRenderableConfig.entity = stationGroupEntityId
	catchmentAreaRenderableConfig.cargo = true
	catchmentAreaRenderableConfig.person = true
	layerConfig.catchmentAreaRenderableConfig = catchmentAreaRenderableConfig
	
	params.setActionFn(function() : TreeNodeId
		local makeState = function() : {Builtin.Type.LineVisualization}
			local relevantLines : {Engine.Entity : boolean} = {}
			local line2stop = api.engine.system.lineSystem.getLineStops(params.keyEntity)
			for __, linestop in ipairs(line2stop) do
				local line = linestop[1]
				relevantLines[line] = true
			end
			local lines : {Builtin.Type.LineVisualization} = {}
			for line, __ in pairs(relevantLines) do
				local lineVis = builtin.type.LineVisualization.new()
				lineVis.entity = line
				lineVis.transparency = 1.0
				table.insert(lines, lineVis)	
			end
			return lines
		end
		local snapFactorRef = react.useRefLazy(function() : HudReactUtil.LineViewerSnapFactors return hud_react_util.makeDefaultLineViewerSnapFactors() end)
		local relevantLines = engine_react_util.useStepStateTimer(makeState)

		local visibilityThresholds = hud_react_util.makeDefaultVisibilityThresholds()
		local stationDetailsThresholds = hud_react_util.findSubEntityThresholds(visibilityThresholds, api.gui.SelectionDetails.Type.Station, true)
		stationDetailsThresholds.detailsThreshold = hud_react_util.DefaultVisDistDetailThreshold * 2
		visibilityThresholds = hud_react_util.setSubEntityThresholds(visibilityThresholds, api.gui.SelectionDetails.Type.Station, stationDetailsThresholds)

		local hudGuiConfig = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/hud/hud_gui_config.gres")).data as HudGuiConfig
		local sfxFinance = api.gui.genericRep.get(api.gui.genericRep.find("::/game_mechanics/finance/sound/finance_sfx.gres")).data as FinanceSFX
		local vehicleIconOffsets = hud_react_util.makeVehicleIconOffsets(hudGuiConfig.vehicleIconOffsets)
		local selectedEntityRef : ReactRefT<Engine.Entity> = react.useRef(-1)
		local children = {
			builtin.HudIconManagerConfig{
				userParam = {
					accessNotificationCacheFn = params.gameCtx.accessNotificationCacheFn,
					selectedEntity = stationGroupEntityId,
				},
				masterRecipe = entity_window_hud.StationGroupHudIconMaster,
				preFilter = entity_window_hud.getStationGroupHudIconPreFilter(),
				showCosts = true,
				showIncome = true,
				incomeSFX = sfxFinance.Income or {},
				costsRenderDistance = hudGuiConfig.renderDistances.Costs,
				visibilityThresholds = visibilityThresholds,
				vehicleIconOffsets = vehicleIconOffsets,
			},
			selector_react_util.makeDefaultSelectorIfMouse(params.gameCtx.rendererComponent, selectedEntityRef),
			selector_react_util.makeDefaultSelectorTooltips(selectedEntityRef),

			#relevantLines:old() > 0 and builtin.LineViewer{
				selectable = true,
				maxSnapFactorView = snapFactorRef:get().view,
				maxSnapFactorWorld = snapFactorRef:get().world,
				fadingMinHeight = 80.0,
				fadingDeltaHeight = 180.0,
				showTerminals = false,
				showLines = relevantLines:old(),
				hiddenLinesTransparent = false,
			} or nil,
		}

		if layerConfig ~= nil then
			children[#children+1] = builtin.LayerConfig{ config = layerConfig }
		end
		
		return builtin.ActionDescriptor{
			horizontalPromptList = true,
			children = children,
			terrainCirclePolicy = "Never",
		}
	end)

	local chart : TreeNodeId = nil

	if entityIsOwnedByPlayerState:old() then
		chart = content_card.ContentCard{
			meta = { localKey = allKeys.stationGroupStatisticsCard, },
			title = _("Statistics"),
			initialCalloutTextPermanent = "", --_("CALLOUT_STATIONGROUP_STATISTICS"),
			recipeAndParamPermanent = content_card.makeRecipeAndParam(
				StationGroupStatistics,
				{
					entityId = stationGroupEntityId,
					logNames = {"itemsLoaded", "itemsUnloaded"},
					labels = {_("Loaded"), _("Unloaded")},
					colors = { color_util.toVec4(defaultColorsRef:get().Positive), color_util.toVec4(defaultColorsRef:get().Negative) },
					styleClass = "town-window-chart-size",
					chartType = "logbookDiff",
					showTimeScaleSlider = false,
					showLegend = true,
					legendOrientation = builtin.type.Orientation.Horizontal,
					initialNumYearsToDisplay = 16,
					minNumYearsToDisplay = 11,
					nextUpFocusRef = lastInScrollAreaRef,
				}
			),
			gameCtx = params.gameCtx,
			showOnRightSide = showOnRightSide,
		}
	end

	local maintenanceBar : TreeNodeId = nil
	local actionButtonBar : TreeNodeId = nil

	local record ConstructionState
		constructionEntity : Engine.Entity
		isModifiable : boolean
	end

	local makeConstructionState = function(old? : ConstructionState) : ConstructionState
		local stationGroup = api.engine.getComponent(stationGroupEntityId, api.type.ComponentType.STATION_GROUP) as Engine.Component.StationGroup
		local constructionEntity : Engine.Entity = nil;
		if #stationGroup.stations == 1 then
			constructionEntity = api.engine.system.streetConnectorSystem.getConstructionEntityForSubconstruction(stationGroup.stations[1])
			if constructionEntity >= 0 then
				local construction = api.engine.getComponent(constructionEntity, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
				if #construction.slots > 0 then
					return {
						constructionEntity = constructionEntity,
						isModifiable = entity_window_util.isConstructionModifiableEngine(constructionEntity),
					}
				end
			end
		end
		-- In case the last station of the station group has been removed, keep old construction entity
		if #stationGroup.stations == 0 and old then
			if old.constructionEntity ~= nil and api.engine.entityExists(old.constructionEntity) then
				local conComp = api.engine.getComponent(old.constructionEntity, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
				if conComp then
					return {
						constructionEntity = constructionEntity,
						isModifiable = entity_window_util.isConstructionModifiableEngine(old.constructionEntity),
					}
				end
			end
		end
		return nil
	end
	local constructionState = engine_react_util.useStepState(makeConstructionState)

	if entityIsOwnedByPlayerState:old() then
		maintenanceBar = entity_window_util.MaintenanceBar{
			entity = stationGroupEntityId,
			maintenancePeriodText = _("Year"),
			initialCalloutText = "", --_("CALLOUT_STATIONGROUP_MAINTENANCECOST"),
			gameCtx = params.gameCtx,
			showOnRightSide = showOnRightSide,
		}

		if constructionState:old() ~= nil and constructionState:old().isModifiable then
			actionButtonBar = entity_window_util.ActionButtonBar(react.ref(initialFocusRef), {
				primaryButtons = {
					{
						description = _("Configure"),
						icon = "::/gui/entity_window/icons/symbol_wrench.tga",
						onClick = entity_window_util.makeConfigureOnClickFunction(constructionState:old().constructionEntity),
						tag = "entityWindow.stationGroup.configure",
					},
				},
			})
		end
	end

	return builtin.BoxLayout {
		orientation = builtin.type.Orientation.Vertical, 
		children = {
			entity_window_util.ContentWidgetScrollContainer(widgets, true),
			chart,
			maintenanceBar,
			actionButtonBar,
		},
	}
end)

return StationGroupWindowContent
