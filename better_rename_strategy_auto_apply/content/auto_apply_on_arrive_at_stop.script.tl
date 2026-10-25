local entity_util = ug_require "::/scripts/entity_util.tl" as EntityUtil
local lang_util = ug_require "::/scripts/lang_util.tl" as LangUtil

local targetSchemeNameRaw <const> = "cargo_firststop_laststop"
local stateVersion <const> = 5
local maxRenamesPerUpdate <const> = 10

local record AutoApplyState
	version : integer
	signatures : {Engine.Entity : string}
	pendingRenames : {Engine.Entity : string}
end

local record HookScheme
	schemeNameRaw : string
	formatString : string
	formatParams : {string : string}
end

local record CargoNameCountId
	name : string
	count : integer
	cargoTypeId : CargoTypeId
end

local ensureState = function(value : AutoApplyState) : AutoApplyState
	if value == nil then
		return {
			version = stateVersion,
			signatures = {},
			pendingRenames = {},
		}
	end
	value.version = value.version or stateVersion
	value.signatures = value.signatures or {}
	value.pendingRenames = value.pendingRenames or {}
	return value
end

local makeLinePathSignature = function(line : Engine.Component.Line) : string
	local parts : {string} = { tostring(#line.stops) }

	for __, stop in ipairs(line.stops) do
		parts[#parts + 1] = string.format(
			"s:%s:%s:%s",
			tostring(stop.stationGroup),
			tostring(stop.station),
			tostring(stop.terminal)
		)

		if stop.waypoints then
			for __, waypoint in ipairs(stop.waypoints) do
				local waypointKey = "w:" .. tostring(waypoint.tag)
				local edgePos = waypoint.edgePos
				if edgePos and edgePos.edgeId then
					waypointKey = waypointKey .. string.format(
						":%s:%s:%s",
						tostring(edgePos.edgeId.entity),
						tostring(edgePos.edgeId.index),
						tostring(edgePos.param)
					)
				elseif waypoint.pos then
					waypointKey = waypointKey .. string.format(
						":%s:%s:%s",
						tostring(waypoint.pos.x),
						tostring(waypoint.pos.y),
						tostring(waypoint.pos.z)
					)
				end
				parts[#parts + 1] = waypointKey
			end
		end
	end

	return table.concat(parts, "|")
end

local findTargetScheme = function() : HookScheme
	for __, resourceId in ipairs(api.res.genericRep.getAllOfType("rename_scheme")) do
		local resource = api.res.genericRep.get(resourceId)
		local scheme = resource.data as HookScheme
		if scheme.schemeNameRaw == targetSchemeNameRaw then
			return scheme
		end
	end
	return nil
end

local makeCargoName = function(line : Engine.Component.Line) : string
	local cargoName2count : {string : integer} = {}
	local cargoName2id : {string : CargoTypeId} = {}

	for __, stop in ipairs(line.stops) do
		if stop.stopConfig and stop.stopConfig.load then
			for cargoTypeId0, enabled in ipairs(stop.stopConfig.load) do
				if enabled then
					local cargoTypeId = cargoTypeId0 - 1
					local cargoType = api.res.cargoTypeRep.get(cargoTypeId) as CargoType
					local cargoName = cargoType.name
					if cargoName2count[cargoName] == nil then
						cargoName2count[cargoName] = 0
						cargoName2id[cargoName] = cargoTypeId
					end
					cargoName2count[cargoName] = cargoName2count[cargoName] + 1
				end
			end
		end
	end

	local cargoNameCountIds : {CargoNameCountId} = {}
	for cargoName, count in pairs(cargoName2count) do
		cargoNameCountIds[#cargoNameCountIds + 1] = {
			name = cargoName,
			count = count,
			cargoTypeId = cargoName2id[cargoName],
		}
	end
	table.sort(cargoNameCountIds, function(a : CargoNameCountId, b : CargoNameCountId) : boolean
		if a.count == b.count then
			return (a.cargoTypeId as integer) < (b.cargoTypeId as integer)
		end
		return a.count > b.count
	end)

	local displayCount = math.min(3, #cargoNameCountIds)
	local cargoNames : string = nil
	for i = 1, displayCount do
		if cargoNames == nil then
			cargoNames = cargoNameCountIds[i].name
		else
			cargoNames = cargoNames .. ", " .. cargoNameCountIds[i].name
		end
	end

	local remaining = #cargoNameCountIds - displayCount
	if remaining > 0 then
		cargoNames = cargoNames .. ", [+" .. lang_util.formatInt(remaining) .. "]"
	end
	return cargoNames or _("No Cargo")
end

local makeAutoRename = function(lineEntity : Engine.Entity) : string
	local scheme = findTargetScheme()
	if scheme == nil then
		scheme = {
			schemeNameRaw = targetSchemeNameRaw,
			formatString = "{key1} - {key2} - {key3}",
			formatParams = {
				key1 = "cargo",
				key2 = "firststop",
				key3 = "laststop",
			},
		}
	end

	local line = api.engine.getComponent(lineEntity, api.type.ComponentType.LINE) as Engine.Component.Line
	if line == nil or #line.stops == 0 then
		return nil
	end

	local firstName = api.engine.util.getEntityName(line.stops[1].stationGroup) or ""
	local lastName = api.engine.util.getEntityName(line.stops[#line.stops].stationGroup) or ""
	local componentValues : {string : string} = {
		cargo = makeCargoName(line),
		firststop = firstName,
		laststop = lastName,
	}
	local components : {string : string} = {}
	for key, schemeComponentNameRaw in pairs(scheme.formatParams) do
		local componentValue = componentValues[schemeComponentNameRaw]
		if componentValue == nil then
			log.warning(
				"[better_rename_strategy_auto_apply] Unsupported rename component: "
				.. schemeComponentNameRaw
			)
			return nil
		end
		components[key] = componentValue
	end

	return lang_util.format(scheme.formatString, components)
end

local isInitializationEvent = function(name : string) : boolean
	return name == "initNewGame"
		or name == "initNewGameFromMap"
		or name == "initMission"
		or name == "initTutorial"
		or name == "handleLegacy"
end

local hasAutoRenameOptOutSuffix = function(lineName : string) : boolean
	if lineName == nil then
		return false
	end
	local trimmedName = lineName:match("^(.-)%s*$") or lineName
	return trimmedName:sub(-1) == "*"
end

local initialize = function(
	state : GameScriptState<AutoApplyState>
)
	state:subscribeToEvent("OnArriveAtStop")

	local stateData = state:get()
	local previousVersion = 0
	if stateData ~= nil and stateData.version ~= nil then
		previousVersion = stateData.version
	end
	stateData = ensureState(stateData)

	if previousVersion < stateVersion then
		-- One-time migration for existing saves. Queue unsuffixed lines for
		-- renaming; update drains the queue in bounded batches.
		local signatures : {Engine.Entity : string} = {}
		local queuedCount = 0
		for __, lineEntity in ipairs(api.engine.system.lineSystem.getLines()) do
			if entity_util.isOwnedByPlayer(lineEntity) then
				local line = api.engine.getComponent(
					lineEntity,
					api.type.ComponentType.LINE
				) as Engine.Component.Line
				if line ~= nil then
					local currentName = api.engine.util.getEntityName(lineEntity) or ""
					if not hasAutoRenameOptOutSuffix(currentName) then
						signatures[lineEntity] = makeLinePathSignature(line)
						local newName = makeAutoRename(lineEntity)
						if newName ~= nil
							and newName ~= ""
							and newName ~= currentName then
							stateData.pendingRenames[lineEntity] = newName
							queuedCount = queuedCount + 1
						end
					end
				end
			end
		end
		stateData.signatures = signatures
		log.message(
			"[better_rename_strategy_auto_apply] migration queued "
			.. lang_util.formatInt(queuedCount) .. " line(s)"
		)
	else
		local aliveSignatures : {Engine.Entity : string} = {}
		for lineEntity, signature in pairs(stateData.signatures) do
			if api.engine.entityExists(lineEntity) then
				aliveSignatures[lineEntity] = signature
			end
		end
		stateData.signatures = aliveSignatures
	end

	stateData.version = stateVersion
	state:set(stateData)
end

local flushPendingRenames = function(
	state : GameScriptState<AutoApplyState>
)
	local stateData = ensureState(state:get())
	if next(stateData.pendingRenames) == nil then
		return
	end

	local processed = 0
	local commandsSent = 0
	local remaining : {Engine.Entity : string} = {}
	for lineEntity, newName in pairs(stateData.pendingRenames) do
		if processed >= maxRenamesPerUpdate then
			remaining[lineEntity] = newName
		elseif api.engine.entityExists(lineEntity) then
			processed = processed + 1
			local currentName = api.engine.util.getEntityName(lineEntity)
			if currentName ~= newName then
				api.cmd.sendCommand(
					api.cmd.makeEntitySetNameCmd(lineEntity, newName)
				)
				commandsSent = commandsSent + 1
			end
		end
	end
	stateData.pendingRenames = remaining
	stateData.version = stateVersion
	state:set(stateData)
	if commandsSent > 0 then
		log.message(
			"[better_rename_strategy_auto_apply] submitted "
			.. lang_util.formatInt(commandsSent) .. " rename command(s)"
		)
	end
end

local ret : GameScript<AutoApplyState> = {
	update = function(
		_userParams : table,
		state : GameScriptState<AutoApplyState>,
		_dt : number
	) : any
		flushPendingRenames(state)
		return nil
	end,

	handleEvent = function(
		_userParams : table,
		state : GameScriptState<AutoApplyState>,
		src : string,
		id : string,
		name : string,
		param : any
	) : any
		if src == "" and id == "" and isInitializationEvent(name) then
			initialize(state)
			return
		end

		if id ~= "TransportVehicleSystem" or name ~= "OnArriveAtStop" then
			return
		end

		local arrived = param as ArriveAtStop
		local lineEntity = arrived.lineEntity
		if lineEntity == nil
			or not api.engine.entityExists(lineEntity)
			or not entity_util.isOwnedByPlayer(lineEntity) then
			return
		end

		local line = api.engine.getComponent(
			lineEntity,
			api.type.ComponentType.LINE
		) as Engine.Component.Line
		if line == nil or #line.stops == 0 then
			return
		end

		local currentName = api.engine.util.getEntityName(lineEntity) or ""
		if hasAutoRenameOptOutSuffix(currentName) then
			-- Do not update the signature: removing the marker later can re-enable
			-- auto-renaming on the next arrival without another route change.
			return
		end

		local stateData = ensureState(state:get())
		local signature = makeLinePathSignature(line)
		if stateData.signatures[lineEntity] == signature then
			return
		end

		stateData.signatures[lineEntity] = signature
		stateData.version = stateVersion
		state:set(stateData)

		local newName = makeAutoRename(lineEntity)
		if newName == nil or newName == "" or newName == currentName then
			return
		end

		stateData.pendingRenames[lineEntity] = newName
		state:set(stateData)
	end,
}

return ret
