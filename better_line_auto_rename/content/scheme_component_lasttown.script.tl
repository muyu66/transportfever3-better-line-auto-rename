local Ret = {
	renameFn = function(renameParams : AutoRename.RenameParams) : string
		local lastTownName : string = nil

		for __, via in ipairs(renameParams.reactLine.path) do
			if via.stop then
				local townName : string = nil
				local stationGroup = api.engine.getComponent(
					via.stop.stationGroup,
					api.type.ComponentType.STATION_GROUP
				) as Engine.Component.StationGroup

				if stationGroup and #stationGroup.stations > 0 then
					local stationIndex1 : integer = via.stop.station1 or 1
					if stationIndex1 < 1 or stationIndex1 > #stationGroup.stations then
						stationIndex1 = 1
					end

					local stationEntity = stationGroup.stations[stationIndex1]
					local townEntity = api.engine.system.stationSystem.getTown(stationEntity)
					if townEntity and api.engine.entityExists(townEntity) then
						townName = api.engine.util.getEntityName(townEntity)
					end
				end

				if townName then
					lastTownName = townName
				end
			end
		end

		return lastTownName or ""
	end,
}

return Ret
