-- ===========================================================================
--  Auto Builder - UI Script
--  Provides Auto Builder UI scripts.
-- ===========================================================================

print("=== Auto Builders (UI) Loading ===")

include("AutoBuilder_Managers")

MovementEnabled = false

function LoadProcessAllIdleBuilders()
    local playerID = Game.GetLocalPlayer()
    ProcessAllIdleBuilders(playerID)
end

function ProcessAllIdleBuilders(playerID)
    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    MovementEnabled = true
    local cities = player:GetCities()
    for _, city in cities:Members() do
        local cityID = city:GetID()
        local plotID = Map.GetPlot(city:GetX(), city:GetY()):GetIndex()
        local obj = CityImprovementManager:new(plotID, playerID, cityID)
        obj:RefreshImprovementData()
        obj:ProcessBuilders()
    end
end

Events.LoadGameViewStateDone.Add(LoadProcessAllIdleBuilders)
Events.PlayerTurnActivated.Add(ProcessAllIdleBuilders)

function DisableMovement()
    MovementEnabled = false
end

Events.PlayerTurnDeactivated.Add(DisableMovement)

function ProcessNewBuilder(playerID, unitID, iX, iY)
    if not MovementEnabled then
        return
    end

    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local unit = UnitManager.GetUnit(playerID, unitID)
    if unit == nil or unit:GetType() ~= BUILDER_INDEX then
        return
    end

    local plot = Map.GetPlot(iX, iY)
    local plotID = plot:GetIndex()
    local city = Cities.GetPlotPurchaseCity(plot)
    if city ~= nil then
        local cityID = city:GetID()
        local obj = CityImprovementManager:new(plotID, playerID, cityID)
        if obj.finishedInitialization then
            obj:ProcessNewBuilder(unitID)
        end
    end
end

Events.UnitAddedToMap.Add(ProcessNewBuilder)

print("=== Auto Builders (UI) Loaded ===")
