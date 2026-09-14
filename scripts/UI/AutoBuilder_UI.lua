-- ===========================================================================
--  Auto Builder - UI Script
--  Provides Auto Builder UI scripts.
-- ===========================================================================

print("=== Auto Builders (UI) Loading ===")

include("AutoBuilder_Managers")

function LoadProcessAllIdleBuilders()
    ProcessAllIdleBuilders()
end

function ProcessAllIdleBuilders(playerID)
    if playerID == nil then
        playerID = Game.GetLocalPlayer()
    end

    local player = Players[playerID]
    if player == nil or not player:IsHuman() then
        return
    end

    local cities = player:GetCities()
    for _, city in cities:Members() do
        local cityID = city:GetID()
        local plotID = Map.GetPlot(city:GetX(), city:GetY()):GetIndex()
        local obj = CityImprovementManager:new(plotID, playerID, cityID)
        obj:RefreshImprovementData()
        obj:ProcessBuilders()
    end
end

function ProcessNewBuilder(playerID, unitID, iX, iY)
    local unit = UnitManager.GetUnit(playerID, unitID)
    if unit:GetType() ~= BUILDER_INDEX then
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

Events.LoadGameViewStateDone.Add(LoadProcessAllIdleBuilders)
Events.PlayerTurnActivated.Add(ProcessAllIdleBuilders)
Events.UnitAddedToMap.Add(ProcessNewBuilder)

print("=== Auto Builders (UI) Loaded ===")
