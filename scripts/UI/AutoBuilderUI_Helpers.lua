FOREST_INDEX = GameInfo.Features["FEATURE_FOREST"].Index
JUNGLE_INDEX = GameInfo.Features["FEATURE_JUNGLE"].Index
MARSH_INDEX = GameInfo.Features["FEATURE_MARSH"].Index
FLOODPLAINS_INDEX = GameInfo.Features["FEATURE_FLOODPLAINS"].Index
local LUMBER_MILL_INDEX = GameInfo.Improvements["IMPROVEMENT_LUMBER_MILL"].Index
FARM_INDEX = GameInfo.Improvements["IMPROVEMENT_FARM"].Index
cityExistingLumberMills = {}
cityPossibleLumberMills = {}
citySafePlot = {}

function GetImprovementTypeByDomain(plot, isNotResource)
    local resourceType = plot:GetResourceType()
    if resourceType == -1 then
        if isNotResource then
            local featureType = plot:GetFeatureType()
            if featureType == FOREST_INDEX or featureType == JUNGLE_INDEX then
                return LUMBER_MILL_INDEX
            end
        end
        return nil
    end

    local isWater = plot:IsWater()
    local domain = "DOMAIN_LAND"
    if isWater then
        domain = "DOMAIN_WATER"
    end
    local resource = GameInfo.Resources[resourceType]
    for _, resourceImprovement in ipairs(resource.ImprovementCollection) do
        local improvementType = resourceImprovement.ImprovementType
        local improvement = GameInfo.Improvements[improvementType]
        if improvement.Domain == domain then
            return improvement.Index
        end
    end
    return nil
end

function FindFarmAndLumberMillPlotsForCity(playerID, cityID)
    local city = CityManager.GetCity(playerID, cityID)
    if (
        cityPossibleLumberMills[cityID] ~= nil and
        cityExistingLumberMills[cityID] ~= nil
    ) then
        return
    end

    cityPossibleLumberMills[cityID] = {}
    cityExistingLumberMills[cityID] = 0
    for _, plot in ipairs(Map.GetNeighborPlots(city:GetX(), city:GetY(), 3)) do
        if plot:GetResourceType() == -1 then
            local plotID = plot:GetIndex()
            local improvementType = plot:GetImprovementType()
            local featureType = plot:GetFeatureType()
            if improvementType == LUMBER_MILL_INDEX then
                local count = cityExistingLumberMills[cityID]
                cityExistingLumberMills[cityID] = count + 1
            elseif featureType == FOREST_INDEX or featureType == JUNGLE_INDEX then
                local isHills = plot:IsHills()
                if cityPossibleLumberMills[cityID][isHills] == nil then
                    cityPossibleLumberMills[cityID][isHills] = {}
                end
                table.insert(cityPossibleLumberMills[cityID][isHills], plotID)
            end
        end
    end
end

function GetCitySafePlot(playerID, cityID)
    if citySafePlot[playerID] == nil then
        citySafePlot[playerID] = {}
    end

    local safePlotID = citySafePlot[playerID][cityID]
    if safePlotID ~= nil then
        return safePlotID
    end

    local city = CityManager.GetCity(playerID, cityID)
    local iX = city:GetX()
    local iY = city:GetY()
    local plot = Map.GetPlot(iX, iY)
    local featureType = plot:GetFeatureType()
    if featureType ~= FLOODPLAINS_INDEX then
        citySafePlot[playerID][cityID] = plot:GetIndex()
    end

    local hillsPlotID = nil
    local nonHillsPlotID = nil
    for direction = 0, 5 do
        local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction)
        if adjacentPlot ~= nil then
            local featureType = adjacentPlot:GetFeatureType()
            if (
                featureType ~= FLOODPLAINS_INDEX
                and featureType ~= FOREST_INDEX
                and featureType ~= JUNGLE_INDEX
            ) then
                local adjacentPlotID = adjacentPlot:GetIndex()
                if adjacentPlot:IsHills() then
                    hillsPlotID = adjacentPlotID
                else
                    nonHillsPlotID = adjacentPlotID
                end
            end
        end
    end
    if hillsPlotID ~= nil then
        return hillsPlotID
    end

    return nonHillsPlotID
end

function GetMutualTrianglePlots(pCentralPlot)
    local iX, iY = pCentralPlot:GetX(), pCentralPlot:GetY()

    -- Loop directions 0 to 5.
    -- direction 5 wraps around to check direction 0.
    for direction = 0, 5 do
        local dirA = direction
        local dirB = (direction + 1) % 6 -- Wraps 6 back to 0 cleanly

        local pPlotA = Map.GetAdjacentPlot(iX, iY, dirA)
        local pPlotB = Map.GetAdjacentPlot(iX, iY, dirB)

        -- If both adjacent plots exist, you have successfully found a triangle group!
        if pPlotA ~= nil and pPlotB ~= nil then
            -- Returns: Central Plot, First Neighbor, Second Neighbor
            -- All three of these plots physically touch each other.
            return { pCentralPlot, pPlotA, pPlotB }
        end
    end
    return nil
end

print("=== Auto Builders (Helpers) Loaded ===")
