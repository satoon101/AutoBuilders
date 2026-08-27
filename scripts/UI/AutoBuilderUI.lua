-- ===========================================================================
--  Auto Builder - UI Script
--  Provides Auto Builder UI scripts.
-- ===========================================================================

print("=== Auto Builders (UI) Loading ===")

local BUILDER_INDEX = GameInfo.Units["UNIT_BUILDER"].Index
local SkipUnits = {}
local CurrentImprovementsNeededByCity = {}

local function FindNextBuilder()
    local playerID = Game.GetLocalPlayer()
    local player = Players[playerID]
    local units = player:GetUnits()
    for _, unit in units:Members() do
        if not SkipUnits[unit:GetID()] then
            if unit:GetType() == BUILDER_INDEX then
                if unit:IsReadyToMove() then
                    return unit
                end
            end
        end
    end
    return nil
end

function CanImproveResourceOnPlot(plot)
    local resourceType = plot:GetResourceType()
    if resourceType ~= -1 then
        local domain = plot:IsWater()
        local resourceObj = ResourceImprovementsByDomain[resourceType] or {}
        local improvementType = resourceObj[domain]
        if improvementType ~= nil then
            local actionType = nil
            local currentImprovementType = plot:GetImprovementType() or -1
            if plot:IsImprovementPillaged() then
                actionType = UnitOperationTypes.REPAIR
            elseif currentImprovementType == -1 then
                actionType = UnitOperationTypes.BUILD_IMPROVEMENT
            elseif currentImprovementType ~= improvementType then
                actionType = UnitOperationTypes.REMOVE_IMPROVEMENT
            end
            if actionType ~= nil then
                local x = plot:GetX()
                local y = plot:GetY()
                local key = x .. "," .. y
                local improvementHash = GameInfo.Improvements[improvementType].Hash
                CurrentImprovementsNeededByCity[key] = {
                    ["action"] = actionType,
                    ["params"] = {
                        [UnitOperationTypes.PARAM_X] = x,
                        [UnitOperationTypes.PARAM_Y] = y,
                        -- TODO: figure out if this affects repair/remove
                        [UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash
                    }
                }
                return true
            end
        end
    end
    return false
end

--for _, row in pairs(GameInfo.Resources["RESOURCE_AMBER"].ImprovementCollection) do for k, v in pairs(row) do print(k, v);end;print();end;

-- loop through plots
-- if plot has resource, find what improvement you "should" have there
-- if there's already an improvement, but it's not the right one
--      send the builder there to remove it and create the proper improvement
-- if no unimproved resources found inside the city boundaries:
--      create up to 6 lumber yards (prioritize hills forest/jungle)
--      create groupings of 3 farms (all adjacent) - up to 2 groupings

--tParameters[UnitOperationTypes.PARAM_X] = pUnit:GetX();
--tParameters[UnitOperationTypes.PARAM_Y] = pUnit:GetY();
--if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.MOVE_TO, nil, tParameters) ) then
--    UnitManager.RequestOperation(pSelectedUnit, UnitOperationTypes.MOVE_TO, tParameters);
--end

--local tParameters = {};
--tParameters[UnitOperationTypes.PARAM_X] = pSelectedUnit:GetX();
--tParameters[UnitOperationTypes.PARAM_Y] = pSelectedUnit:GetY();
--tParameters[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash;
--
--UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.REPAIR, tParameters );
--UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.REMOVE_IMPROVEMENT, tParameters );
--UnitManager.RequestOperation( pSelectedUnit, UnitOperationTypes.BUILD_IMPROVEMENT, tParameters );

function PerformUnitOperation(unit, action)
    local key = unit:GetX() .. "," .. unit:GetY()
    local actionData = CurrentImprovementsNeededByCity[key]
    if action == nil then
        action = actionData["action"]
    end
    local params = actionData["params"]
    if UnitManager.CanStartOperation(unit, action, nil, params) then
        UnitManager.RequestOperation(unit, action, params)
    end
end

function FindNextAvailableImprovement(unit, city)
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY())
    if CanImproveResourceOnPlot(unitPlot) then
        return
    end
    for _, plot in ipairs(Map.GetNeighborPlots(city:GetX(), city:GetY(), 3)) do
        local checkCity = Cities.GetPlotPurchaseCity(plot)
        if checkCity ~= nil and checkCity:GetID() == city:GetID() then
            if CanImproveResourceOnPlot(plot) then

            end
        end
    end
end

function MoveOrCreateImprovement()
    SkipUnits = {}
    while true do
        local unit = FindNextBuilder()
        if unit == nil then
            break
        end

        local x = unit:GetX()
        local y = unit:GetY()
        local key = x .. "," .. y
        local actionData = CurrentImprovementsNeededByCity[key]
        if actionData ~= nil then
            CurrentImprovementsNeededByCity[key] = nil
            -- TODO: builder action
            return
        end

        local plot = Map.GetPlot(x, y)
        local city = Cities.GetPlotPurchaseCity(plot)
        if city == nil then
            SkipUnits[unit:GetID()] = true
        else
        end
    end
end

ResourceImprovementsByDomain = {}

function GatherResourceImprovementsByTerrain()
    for resource in GameInfo.Resources() do
        local resourceType = resource.ResourceType
        ResourceImprovementsByDomain[resourceType] = {}
        for _, resourceImprovement in ipairs(resource.ImprovementCollection) do
            local improvementType = resourceImprovement.ImprovementType
            local improvement = GameInfo.Improvements[improvementType]
            local isWaterKey = improvement.Domain == "DOMAIN_WATER"
            ResourceImprovementsByDomain[resourceType][isWaterKey] = improvementType
        end
    end
end

local INDEX = GameInfo.Resources["RESOURCE_AMBER"].Index;local iW, iH = Map.GetGridSize();for x = 0, iW - 1 do for y = 0, iH - 1 do local plot = Map.GetPlot(x, y);if plot:GetResourceType() == INDEX then print(plot:IsWater());end;end;end;

Events.PlayerTurnActivated.Add(MoveOrCreateImprovement)
Events.LoadGameViewStateDone.Add(MoveOrCreateImprovement)

print("=== Auto Builders (UI) Loaded ===")

 --ProductionPanel: IsAdjacentToShallowWater	function: 00000001AE657870
 --ProductionPanel: GetX	function: 00000001AE656A70
 --ProductionPanel: IsOpenGround	function: 00000001AE6564F0
 --ProductionPanel: GetNearestLandPlot	function: 00000001AE6578F0
 --ProductionPanel: IsValidFoundLocation	function: 00000001AE657CB0
 --ProductionPanel: IsCity	function: 00000001AE657530
 --ProductionPanel: GetRouteType	function: 00000001AE658130
 --ProductionPanel: IsRiverCrossingFlowClockwise	function: 00000001AE658030
 --ProductionPanel: IsHills	function: 00000001AE656430
 --ProductionPanel: GetOwner	function: 00000001AE657030
 --ProductionPanel: GetIndex	function: 00000001AE6563F0
 --ProductionPanel: GetImprovementType	function: 00000001AE6574F0
 --ProductionPanel: IsCanyon	function: 00000001AE657FB0
 --ProductionPanel: IsNone	function: 00000001AE656BB0
 --ProductionPanel: GetUnitCount	function: 00000001AE657A70
 --ProductionPanel: GetFeatureType	function: 00000001AE6572F0
 --ProductionPanel: IsNEOfRiver	function: 00000001AE6579F0
 --ProductionPanel: IsImprovementPillaged	function: 00000001AE657570
 --ProductionPanel: IsRiverAdjacent	function: 00000001AE657F30
 --ProductionPanel: IsRiverSide	function: 00000001AE657DB0
 --ProductionPanel: IsFlatlands	function: 00000001AE657070
 --ProductionPanel: __instances	table: 000000013A6EF900
 --ProductionPanel: IsNEOfCliff	function: 00000001AE6571F0
 --ProductionPanel: GetNearestLandArea	function: 00000001AE6578B0
 --ProductionPanel: GetRiverEFlowDirection	function: 00000001AE657FF0
 --ProductionPanel: SharesAdjacentArea	function: 00000001AE657830
 --ProductionPanel: IsRoute	function: 00000001AE657D30
 --ProductionPanel: GetRiverCrossingCount	function: 00000001AE6573F0
 --ProductionPanel: GetYield	function: 00000001AE657C30
 --ProductionPanel: HasFeatureBeenAdded	function: 00000001AE657730
 --ProductionPanel: IsAt	function: 00000001AE656AB0
 --ProductionPanel: CanHaveDistrict	function: 00000001AE6585B0
 --ProductionPanel: GetResourceCount	function: 00000001AE657AB0
 --ProductionPanel: GetY	function: 00000001AE656DF0
 --ProductionPanel: IsWater	function: 00000001AE6576F0
 --ProductionPanel: GetDistrictID	function: 00000001AE6575F0
 --ProductionPanel: IsOwned	function: 00000001AE656EB0
 --ProductionPanel: IsRiverCrossingToPlot	function: 00000001AE657170
 --ProductionPanel: IsRiver	function: 00000001AE657F70
 --ProductionPanel: IsWonderComplete	function: 00000001AE6576B0
 --ProductionPanel: IsMountain	function: 00000001AE6573B0
 --ProductionPanel: IsAdjacentOwned	function: 00000001AE657B70
 --ProductionPanel: IsWOfCliff	function: 00000001AE6580B0
 --ProductionPanel: GetImprovementOwner	function: 00000001AE6575B0
 --ProductionPanel: IsNWOfCliff	function: 00000001AE6580F0
 --ProductionPanel: IsNWOfRiver	function: 00000001AE657D70
 --ProductionPanel: GetTerrainType	function: 00000001AE6574B0
 --ProductionPanel: GetFeature	function: 00000001AE657630
 --ProductionPanel: GetWorkerCount	function: 00000001AE658070
 --ProductionPanel: IsShallowWater	function: 00000001AE657270
 --ProductionPanel: IsNaturalWonder	function: 00000001AE6572B0
 --ProductionPanel: IsImpassable	function: 00000001AE6577F0
 --ProductionPanel: IsRiverCrossing	function: 00000001AE657330
 --ProductionPanel: IsNationalPark	function: 00000001AE658DF0
 --ProductionPanel: GetAdjacencyBonusType	function: 00000001AE6590B0
 --ProductionPanel: GetArea	function: 00000001AE656C70
 --ProductionPanel: GetRiverSEFlowDirection	function: 00000001AE657E70
 --ProductionPanel: IsStartingPlot	function: 00000001AE6579B0
 --ProductionPanel: GetResourceTypeHash	function: 00000001AE657A30
 --ProductionPanel: GetAdjacencyBonusTooltip	function: 00000001AE658B70
 --ProductionPanel: CanHaveWonder	function: 00000001AE658670
 --ProductionPanel: IsUnit	function: 00000001AE657EF0
 --ProductionPanel: GetAdjacencyYield	function: 00000001AE6583F0
 --ProductionPanel: GetAppeal	function: 00000001AE658BF0
 --ProductionPanel: IsAdjacentPlayer	function: 00000001AE657BB0
 --ProductionPanel: TypeName	Plot
 --ProductionPanel: IsRiverConnection	function: 00000001AE6571B0
 --ProductionPanel: GetMovementCost	function: 00000001AE6588B0
 --ProductionPanel: IsChokepoint	function: 00000001AE657C70
 --ProductionPanel: IsAdjacentToArea	function: 00000001AE657AF0
 --ProductionPanel: GetContinentType	function: 00000001AE657BF0
 --ProductionPanel: GetDefenseModifier	function: 00000001AE6583B0
 --ProductionPanel: IsInternalOnlyDistrict	function: 00000001AE657670
 --ProductionPanel: IsRoutePillaged	function: 00000001AE657230
 --ProductionPanel: IsAdjacentToLand	function: 00000001AE657B30
 --ProductionPanel: GetAirUnits	function: 00000001AE6577B0
 --ProductionPanel: GetWonderType	function: 00000001AE657930
 --ProductionPanel: GetRiverSWFlowDirection	function: 00000001AE657EB0
 --ProductionPanel: IsLake	function: 00000001AE657CF0
 --ProductionPanel: GetTerrainClassType	function: 00000001AE657470
 --ProductionPanel: GetProperty	function: 00000001AE658A30
 --ProductionPanel: GetComponentID	function: 00000001AE656AF0
 --ProductionPanel: GetResourceType	function: 00000001AE657430
 --ProductionPanel: GetAreaID	function: 00000001AE656CB0
 --ProductionPanel: IsFreshWater	function: 00000001AE657E30
 --ProductionPanel: IsCoastalLand	function: 00000001AE657DF0
 --ProductionPanel: IsRoughGround	function: 00000001AE6565B0
 --ProductionPanel: GetDistrictType	function: 00000001AE657770
 --ProductionPanel: GetNationalParkName	function: 00000001AE658F30
 --ProductionPanel: IsWOfRiver	function: 00000001AE657370
 --
