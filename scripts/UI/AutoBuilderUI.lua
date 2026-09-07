-- ===========================================================================
--  Auto Builder - UI Script
--  Provides Auto Builder UI scripts.
-- ===========================================================================

print("=== Auto Builders (UI) Loading ===")

local BUILDER_INDEX = GameInfo.Units["UNIT_BUILDER"].Index
CurrentImprovementMovesByUnit = {}
CurrentImprovementMovesByPlot = {}

function ProcessAllIdleBuilders(playerID)
    if playerID == nil then
        playerID = Game.GetLocalPlayer()
    end

    if playerID == nil then
        return
    end

    local player = Players[playerID]
    if player == nil then
        return
    end

    if not player:IsHuman() then
        return
    end

    local units = player:GetUnits()
    for _, unit in units:Members() do
        if unit:GetType() == BUILDER_INDEX then
            if (
                CurrentImprovementMovesByUnit[unit:GetID()] ~= nil
                or unit:IsReadyToMove()
            ) then
                ProcessIdleBuilder(unit)
            end
        end
    end
end

function ProcessIdleBuilder(unit)
    local unitID = unit:GetID()
    local currentUnitMove = CurrentImprovementMovesByUnit[unitID]
    if currentUnitMove ~= nil then
        if IsImprovementStillNeeded(unitID) then
            PerformUnitOperation(unit)
            return
        else
            CurrentImprovementMovesByUnit[unitID] = nil
            CurrentImprovementMovesByPlot[endPlotID] = nil
        end
    end

    -- Is the builder in the boundaries of one of the player's cities?
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY())
    local city = Cities.GetPlotPurchaseCity(unitPlot)
    if city == nil or city:GetOwner() ~= unit:GetOwner() then
        return
    end

    if FindNextAvailableImprovementPlot(unit, city) then
        PerformUnitOperation(unit)
    end
end

function FindNextAvailableImprovementPlot(unit, city)
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY())
    local unitID = unit:GetID()
    print("Checking for unit:", unit:GetID())
    local actionType = GetActionTypeForPlot(unit, unitPlot)
    if actionType ~= nil then
        StoreDataForActionOnPlot(unitPlot, unitID, actionType)
        return true
    end

    for _, plot in ipairs(Map.GetNeighborPlots(city:GetX(), city:GetY(), 3)) do
        local checkCity = Cities.GetPlotPurchaseCity(plot)
        if checkCity ~= nil and checkCity:GetID() == city:GetID() then
            local actionType = GetActionTypeForPlot(unit, plot)
            if actionType ~= nil then
                StoreDataForActionOnPlot(plot, unitID, actionType)
                return true
            end
        end
    end

    return false
end

function GetActionTypeForPlot(unit, plot)
    local plotID = plot:GetIndex()
    if CurrentImprovementMovesByPlot[plotID] ~= nil then
        print("another unit is already assigned to plot")
        return nil
    end

    local resourceType = plot:GetResourceType()
    if resourceType == -1 then
        print("no resource found for plot")
        return nil
    end

    local improvementTypeName = GetImprovementTypeByDomain(resourceType, plot:IsWater())
    if improvementTypeName == nil then
        print("no valid improvement type found for plot")
        return nil
    end

    local actionType = nil
    local improvementType = GameInfo.Improvements[improvementTypeName].Index
    local currentImprovementType = plot:GetImprovementType()
    if plot:IsImprovementPillaged() then
        actionType = UnitOperationTypes.REPAIR
    elseif currentImprovementType == -1 then
        actionType = UnitOperationTypes.BUILD_IMPROVEMENT
    elseif currentImprovementType ~= improvementType then
        actionType = UnitOperationTypes.REMOVE_IMPROVEMENT
    end

    if actionType == nil then
        print("no action found for plot")
        return nil
    end

    local params = {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    }
    if not UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, params) then
        print("cannot move to resource:", GameInfo.Resources[resourceType].ResourceType)
        return nil
    end

    return actionType
end

function GetImprovementTypeByDomain(resourceType, isWater)
    local domain = "DOMAIN_LAND"
    if isWater then
        domain = "DOMAIN_WATER"
    end
    local resource = GameInfo.Resources[resourceType]
    for _, resourceImprovement in ipairs(resource.ImprovementCollection) do
        local improvementType = resourceImprovement.ImprovementType
        local improvement = GameInfo.Improvements[improvementType]
        if improvement.Domain == domain then
            return improvementType
        end
    end
    return nil
end

function StoreDataForActionOnPlot(plot, unitID, actionType)
    local plotID = plot:GetIndex()
    local params = {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    }
    local extraParams = {}
    if actionType == UnitOperationTypes.BUILD_IMPROVEMENT then
        local resourceType = plot:GetResourceType()
        local improvementTypeName = GetImprovementTypeByDomain(
            resourceType,
            plot:IsWater()
        )
        local improvementHash = GameInfo.Improvements[improvementTypeName].Hash
        extraParams[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash
    end
    CurrentImprovementMovesByUnit[unitID] = {
        ["action"] = actionType,
        ["params"] = params,
        ["extra_params"] = extraParams,
        ["plot_id"] = plotID
    }
    CurrentImprovementMovesByPlot[plotID] = true
end

function IsImprovementStillNeeded(unitID)
    local data = CurrentImprovementMovesByUnit[unitID]
    local actionType = data["action"]
    local plot = Map.GetPlotByIndex(data["plot_id"])
    if actionType == UnitOperationTypes.REPAIR then
        return plot:IsImprovementPillaged()
    end

    local resourceType = plot:GetResourceType()
    local improvementTypeName = GetImprovementTypeByDomain(
        resourceType,
        plot:IsWater()
    )
    local improvementType = GameInfo.Improvements[improvementTypeName].Index
    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType == -1 then
        return actionType == UnitOperationTypes.BUILD_IMPROVEMENT
    end

    if currentImprovementType ~= improvementType then
        return actionType == UnitOperationTypes.REMOVE_IMPROVEMENT
    end

    return false
end

function PerformUnitOperation(unit)
    local data = CurrentImprovementMovesByUnit[unit:GetID()]
    if data == nil then
        return
    end

    local params = data["params"]
    local x = params[UnitOperationTypes.PARAM_X]
    local y = params[UnitOperationTypes.PARAM_Y]
    local endPlotID = Map.GetPlot(x, y):GetIndex()
    local unitPlotID = Map.GetPlot(unit:GetX(), unit:GetY()):GetIndex()
    local isReachable = unitPlotID == endPlotID
    if not isReachable then
        for _, plotID in pairs(UnitManager.GetReachableMovement(unit)) do
            if plotID == endPlotID then
                isReachable = true
            end
        end
    end

    if unitPlotID ~= endPlotID then
        UnitManager.RequestOperation(unit, UnitOperationTypes.MOVE_TO, params)
    end

    if isReachable then
        local actionType = data["action"]
        for key, value in pairs(data["extra_params"]) do
            params[key] = value
        end
        UnitManager.RequestOperation(unit, actionType, params)
    end
end

Events.PlayerTurnActivated.Add(ProcessAllIdleBuilders)
Events.LoadGameViewStateDone.Add(ProcessAllIdleBuilders)

print("=== Auto Builders (UI) Loaded ===")
