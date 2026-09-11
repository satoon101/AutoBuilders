
include("AutoBuilderUI_Helpers")

local MEDIEVAL_ERA_INDEX = GameInfo.Eras["ERA_MEDIEVAL"].Index
local MERCANTILISM_INDEX = GameInfo.Civics["CIVIC_MERCANTILISM"].Index
local CONSTRUCTION_INDEX = GameInfo.Technologies["TECH_CONSTRUCTION"].Index
MAX_LUMBER_MILLS_PER_CITY = 6

function CheckPlotForRemovableMarsh(plot)
    local currentEra = Game.GetEras():GetCurrentEra()
    if currentEra >= MEDIEVAL_ERA_INDEX then
        local featureType = plot:GetFeatureType()
        if featureType == MARSH_INDEX then
            return UnitOperationTypes.REMOVE_FEATURE
        end
    end
    return nil
end

function CheckPlotForRepair(plot)
    if plot:IsImprovementPillaged() then
        return UnitOperationTypes.REPAIR
    end
    return nil
end

function CheckPlotForImprovementNeeded(plot)
    local improvementType = GetImprovementTypeByDomain(plot, false)
    if improvementType == nil then
        return nil
    end

    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType == -1 then
        return UnitOperationTypes.BUILD_IMPROVEMENT
    end
    return nil
end

function CheckPlotForImprovementRemoval(plot)
    local improvementType = GetImprovementTypeByDomain(plot, false)
    if improvementType == nil then
        return nil
    end

    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType ~= improvementType then
        return UnitOperationTypes.REMOVE_IMPROVEMENT
    end
    return nil
end

function CheckPlotForLumbermill(plot)
    local city = Cities.GetPlotPurchaseCity(plot)
    local cityID = city:GetID()
    local playerID = city:GetOwner()
    FindFarmAndLumberMillPlotsForCity(playerID, cityID)
    local currentCount = cityExistingLumberMills[cityID]
    if currentCount >= MAX_LUMBER_MILLS_PER_CITY then
        return nil
    end

    local possibleMills = cityPossibleLumberMills[cityID]
    if possibleMills == nil then
        return nil
    end

    local plotID = plot:GetIndex()
    local hillsMills = possibleMills[true] or {}
    local player = Players[playerID]
    local techs = player:GetTechs()
    local civics = player:GetCulture()
    local hasConstruction = techs:HasTech(CONSTRUCTION_INDEX)
    local hasMercantilism = civics:HasCivic(MERCANTILISM_INDEX)
    local function InnerCheck(isHills)
        local checkArray = possibleMills[isHills]
        local found = false
        for _, checkPlotID in ipairs(checkArray) do
            if checkPlotID == plotID then
                found = true
                break
            end
        end

        if not found then
            return nil
        end

        local plot = Map.GetPlotByIndex(plotID)
        local featureType = plot:GetFeatureType()
        if featureType == FOREST_INDEX and hasConstruction then
            return UnitOperationTypes.BUILD_IMPROVEMENT
        elseif featureType == JUNGLE_INDEX and hasMercantilism then
            return UnitOperationTypes.BUILD_IMPROVEMENT
        end

        return nil
    end

    local actionType = InnerCheck(true)
    if actionType ~= nil then
        return actionType
    end

    local count = #hillsMills + currentCount
    local nonHillsAllowed = MAX_LUMBER_MILLS_PER_CITY - count
    if nonHillsAllowed > 0 then
        return InnerCheck(false)
    end
    return nil
end

print("=== Auto Builders (Actions) Loaded ===")
