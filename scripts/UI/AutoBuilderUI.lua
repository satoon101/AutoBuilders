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
    -- Clear the lumbermill and farm to start each turn
    cityPossibleLumberMills = {}
    cityExistingLumberMills = {}

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
        return
    end

    local hash = GameInfo.UnitOperations["UNITOPERATION_SKIP_TURN"].Hash
    UnitManager.RequestOperation(unit, hash, {})
end

function FindNextAvailableImprovementPlot(playerID, unit, city)
    local unitPlot = Map.GetPlot(unit:GetX(), unit:GetY())
    local unitID = unit:GetID()
    local actionType = GetActionTypeForPlot(unit, unitPlot)
    local unitPlotID = unitPlot:GetIndex()
    if actionType ~= nil then
        StoreDataForActionOnPlot(playerID, unitPlotID, unitID, actionType)
        return true
    end

    local foundActions = {}
    for _, plot in ipairs(Map.GetNeighborPlots(city:GetX(), city:GetY(), 3)) do
        local checkCity = Cities.GetPlotPurchaseCity(plot)
        if checkCity ~= nil and checkCity:GetID() == city:GetID() then
            local actionLevel, actionType = GetActionTypeForPlot(unit, plot)
            if actionType ~= nil then
                if foundActions[actionLevel] == nil then
                    foundActions[actionLevel] = {}
                end
                local data = {
                    ["action_type"] = actionType,
                    ["plot_id"] = plot:GetIndex()
                }
                table.insert(foundActions[actionLevel], data)
            end
        end
    end

    local lowest = math.huge
    for key, _ in pairs(foundActions) do
        if type(key) == "number" and key > 0 and key % 1 == 0 then
            if key < lowest then
                lowest = key
            end
        end
    end

    local actionTypes = {
        [UnitOperationTypes.BUILD_IMPROVEMENT] = "BUILD_IMPROVEMENT",
        [UnitOperationTypes.REMOVE_IMPROVEMENT] = "REMOVE_IMPROVEMENT",
        [UnitOperationTypes.REPAIR] = "REPAIR",
        [UnitOperationTypes.REMOVE_FEATURE] = "REMOVE_FEATURE",
    }
    if lowest ~= math.huge then
        local arrayLength = #foundActions[lowest]
        if arrayLength > 0 then
            local index = math.random(1, arrayLength)
            local data = foundActions[lowest][index]
            local plotID = data["plot_id"]
            local actionType = data["action_type"]
            local plot = Map.GetPlotByIndex(plotID)
            local resourceType = plot:GetResourceType()
            if resourceType ~= -1 then
                resourceType = GameInfo.Resources[resourceType].ResourceType
            end
            StoreDataForActionOnPlot(playerID, plotID, unitID, actionType)
            return true
        end
    end

    local safePlotID = GetCitySafePlot(playerID, city:GetID())
    local hash = GameInfo.UnitOperations["UNITOPERATION_SKIP_TURN"].Hash
    if safePlotID ~= nil and safePlotID ~= unitPlotID then
        StoreDataForActionOnPlot(playerID, safePlotID, unitID, hash)
        return true
    end

    return false
end

function GetActionTypeForPlot(unit, plot)
    local plotID = plot:GetIndex()
    if CurrentImprovementMovesByPlot[plotID] ~= nil then
        return nil, nil
    end

    local actionType = nil
    local actionLevel = nil

    -- Use configuration to store functions by their level
    --      lowest found level will be used for auto-builder first
    local actionFunctions = {
        [1] = {
            CheckPlotForRemovableMarsh
        },
        [2] = {
            CheckPlotForRepair
        },
        [3] = {
            CheckPlotForImprovementNeeded,
            CheckPlotForImprovementRemoval
        },
        [4] = {
            CheckPlotForLumbermill
        }
    }
    local actionTypes = {
        [UnitOperationTypes.BUILD_IMPROVEMENT] = "BUILD_IMPROVEMENT",
        [UnitOperationTypes.REMOVE_IMPROVEMENT] = "REMOVE_IMPROVEMENT",
        [UnitOperationTypes.REPAIR] = "REPAIR",
        [UnitOperationTypes.REMOVE_FEATURE] = "REMOVE_FEATURE",
    }
    for level = 1, #actionFunctions do
        local functions = actionFunctions[level]
        for _, actionFunction in ipairs(functions) do
            currentActionType = actionFunction(plot)
            if currentActionType ~= nil then
                actionLevel = level
                actionType = currentActionType
                print("Found Action:", plot:GetIndex(), actionLevel, actionTypes[actionType])
                break
            end
        end
        if actionType ~= nil then
            break
        end
    end

    if actionType == nil then
        return nil, nil
    end

    local params = {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    }
    if not UnitManager.CanStartOperation(unit, UnitOperationTypes.MOVE_TO, nil, params) then
        return nil, nil
    end

    return actionLevel, actionType
end

function StoreDataForActionOnPlot(playerID, plotID, unitID, actionType)
    local plot = Map.GetPlotByIndex(plotID)
    local params = {
        [UnitOperationTypes.PARAM_X] = plot:GetX(),
        [UnitOperationTypes.PARAM_Y] = plot:GetY()
    }
    local extraParams = {}
    if actionType == UnitOperationTypes.BUILD_IMPROVEMENT then
        local improvementType = GetImprovementTypeByDomain(plot, true)
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
        return plot:GetFeatureType() == MARSH_INDEX
    end

    if actionType == UnitOperationTypes.REPAIR then
        return plot:IsImprovementPillaged()
    end

    local improvementType = GetImprovementTypeByDomain(plot, true)
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
