-- ===========================================================================
--  Auto Builder - UI Script
--  Provides Auto Builder UI scripts.
-- ===========================================================================

print("=== Auto Builders (UI) Loading ===")

include("AutoBuilderUI_Actions")

local BUILDER_INDEX = GameInfo.Units["UNIT_BUILDER"].Index
CurrentImprovementMovesByUnit = {}
CurrentImprovementMovesByPlot = {}

function ProcessAllIdleBuilders(playerID)
    if playerID == nil then
        playerID = Game.GetLocalPlayer()
    end

    if playerID == nil or Players == nil then
        return
    end

    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    if CurrentImprovementMovesByUnit[playerID] == nil then
        CurrentImprovementMovesByUnit[playerID] = {}
    end

    for unitID, _ in pairs(CurrentImprovementMovesByUnit[playerID]) do
        if UnitManager.GetUnit(playerID, unitID) == nil then
            local plotID = CurrentImprovementMovesByUnit[playerID][unitID]["plot_id"]
            CurrentImprovementMovesByUnit[playerID][unitID] = nil
            CurrentImprovementMovesByPlot[plotID] = nil
        end
    end
    local units = player:GetUnits()
    for _, unit in units:Members() do
        if unit:GetType() == BUILDER_INDEX then
            if (
                CurrentImprovementMovesByUnit[playerID][unit:GetID()] ~= nil
                or unit:IsReadyToMove()
            ) then
                ProcessIdleBuilder(playerID, unit)
            end
        end
    end
end

function ProcessIdleBuilder(playerID, unit)
    local unitID = unit:GetID()
    local currentUnitMove = CurrentImprovementMovesByUnit[playerID][unitID]
    if currentUnitMove ~= nil then
        if IsImprovementStillNeeded(playerID, unitID) then
            PerformUnitOperation(playerID, unit)
            return
        else
            local plotID = CurrentImprovementMovesByUnit[playerID][unitID]["plot_id"]
            CurrentImprovementMovesByUnit[playerID][unitID] = nil
            CurrentImprovementMovesByPlot[plotID] = nil
        end
    end

    -- Is the builder in the boundaries of one of the player's cities?
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY())
    local city = Cities.GetPlotPurchaseCity(unitPlot)
    if city == nil or city:GetOwner() ~= unit:GetOwner() then
        return
    end

    if FindNextAvailableImprovementPlot(playerID, unit, city) then
        PerformUnitOperation(playerID, unit)
    end
end

function FindNextAvailableImprovementPlot(playerID, unit, city)
    print(playerID, unit:GetID(), city:GetID())
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY())
    local unitID = unit:GetID()
    local actionType = GetActionTypeForPlot(unit, unitPlot)
    print(actionType)
    if actionType ~= nil then
        StoreDataForActionOnPlot(playerID, unitPlot, unitID, actionType)
        return true
    end

    for _, plot in ipairs(Map.GetNeighborPlots(city:GetX(), city:GetY(), 3)) do
        local checkCity = Cities.GetPlotPurchaseCity(plot)
        if checkCity ~= nil and checkCity:GetID() == city:GetID() then
            local actionType = GetActionTypeForPlot(unit, plot)
            if actionType ~= nil then
                StoreDataForActionOnPlot(playerID, plot, unitID, actionType)
                return true
            end
        end
    end

    return false
end

function GetActionTypeForPlot(unit, plot)
    local plotID = plot:GetIndex()
    if CurrentImprovementMovesByPlot[plotID] ~= nil then
        print("exit", 1)
        return nil
    end

    local actionType = nil

    local actionFunctions = {
        CheckPlotForRemovableMarsh,
        CheckPlotForRepair,
        CheckPlotForImprovementNeeded,
        CheckPlotForImprovementRemoval,
    }
    for _, actionFunction in ipairs(actionFunctions) do
        actionType = actionFunction(plot)
        if actionType ~= nil then
            print("found action type:", actionType)
            break
        end
    end

    if actionType == nil then
        print("exit", 2)
        return nil
    end

    local params = {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    }
    if not UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, params) then
        print("exit", 3)
        return nil
    end

    local actionTypes = {
        [UnitOperationTypes.BUILD_IMPROVEMENT] = "BUILD_IMPROVEMENT",
        [UnitOperationTypes.REMOVE_IMPROVEMENT] = "REMOVE_IMPROVEMENT",
        [UnitOperationTypes.REPAIR] = "REPAIR",
        [UnitOperationTypes.REMOVE_FEATURE] = "REMOVE_FEATURE",
    }
    print("returning action type:", actionTypes[actionType])
    return actionType
end

function StoreDataForActionOnPlot(playerID, plot, unitID, actionType)
    local plotID = plot:GetIndex()
    local params = {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    }
    local extraParams = {}
    if actionType == UnitOperationTypes.BUILD_IMPROVEMENT then
        local resourceType = plot:GetResourceType()
        local improvementType = GetImprovementTypeByDomain(plot)
        local improvementHash = GameInfo.Improvements[improvementType].Hash
        extraParams[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE] = improvementHash
    end
    CurrentImprovementMovesByUnit[playerID][unitID] = {
        ["action"] = actionType,
        ["params"] = params,
        ["extra_params"] = extraParams,
        ["plot_id"] = plotID
    }
    CurrentImprovementMovesByPlot[plotID] = true
end

function IsImprovementStillNeeded(playerID, unitID)
    local data = CurrentImprovementMovesByUnit[playerID][unitID]
    local actionType = data["action"]
    local plot = Map.GetPlotByIndex(data["plot_id"])

    if actionType == UnitOperationTypes.REMOVE_FEATURE then
        print("REMOVE MARSH!!", plot:GetFeatureType(), MARSH_INDEX, plot:GetFeatureType() == MARSH_INDEX)
        return plot:GetFeatureType() == MARSH_INDEX
    end

    if actionType == UnitOperationTypes.REPAIR then
        return plot:IsImprovementPillaged()
    end

    local resourceType = plot:GetResourceType()
    local improvementType = GetImprovementTypeByDomain(plot)
    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType == -1 then
        return actionType == UnitOperationTypes.BUILD_IMPROVEMENT
    end

    if currentImprovementType ~= improvementType then
        return actionType == UnitOperationTypes.REMOVE_IMPROVEMENT
    end

    return false
end

function PerformUnitOperation(playerID, unit)
    local data = CurrentImprovementMovesByUnit[playerID][unit:GetID()]
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

function test()
--     local unit = UnitManager.GetUnit(0, 1245184)
--     local plot = Map.GetPlot(34, 13)
--     local feature = plot:GetFeatureType()
--     local MARSH_INDEX = GameInfo.Features["FEATURE_MARSH"].Index
--     if feature == MARSH_INDEX then
--         local params = {
--             [UnitOperationTypes.PARAM_X] = 34,
--             [UnitOperationTypes.PARAM_Y] = 13,
-- --             [UnitOperationParameterTypes.OPERATION_TYPE] = UnitOperationTypes.CLEAR_FEATURE,
--         }
--         UnitManager.RequestOperation(unit, UnitOperationTypes.REMOVE_FEATURE, params)
--     end
end
