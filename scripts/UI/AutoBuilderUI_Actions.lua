
include("AutoBuilderUI_Helpers")

local MEDIEVAL_ERA_INDEX = GameInfo.Eras["ERA_MEDIEVAL"].Index
MARSH_INDEX = GameInfo.Features["FEATURE_MARSH"].Index

function CheckPlotForRemovableMarsh(plot)
    local currentEra = Game.GetEras():GetCurrentEra()
    if currentEra >= MEDIEVAL_ERA_INDEX then
        print(1)
        local featureType = plot:GetFeatureType()
        print("Feature Type:", featureType, MARSH_INDEX, featureType == MARSH_INDEX)
        if featureType == MARSH_INDEX then
            print("MARSH!!!")
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
    local improvementType = GetImprovementTypeByDomain(plot)
    if improvementType == nil then
        return nil
    end

    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType == -1 then
        return UnitOperationTypes.BUILD_IMPROVEMENT
    end
end

function CheckPlotForImprovementRemoval(plot)
    local improvementType = GetImprovementTypeByDomain(plot)
    if improvementType == nil then
        return nil
    end

    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType ~= improvementType then
        return UnitOperationTypes.REMOVE_IMPROVEMENT
    end
end

print("=== Auto Builders (Actions) Loaded ===")
