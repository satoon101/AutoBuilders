include("AutoBuilder_Constants")

function CheckPlotForRemovableMarsh(plot)
    local featureType = plot:GetFeatureType()
    if featureType == MARSH_INDEX then
        return UnitOperationTypes.REMOVE_FEATURE
    end
    return nil
end

function CheckPlotForRepair(plot)
    if plot:IsImprovementPillaged() then
        return UnitOperationTypes.REPAIR
    end
    return nil
end

function CheckPlotForImprovementNeeded(plot, obj)
    local improvementType = obj:GetImprovementTypeByDomain(plot)
    if improvementType == nil then
        return nil
    end

    local plotID = plot:GetIndex()
    local canImprove = ExposedMembers.AutoBuilder.CanHaveImprovement(
        plotID, improvementType, obj.playerID
    )
    if not canImprove then
        return nil
    end

    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType == -1 then
        return UnitOperationTypes.BUILD_IMPROVEMENT
    end
    return nil
end

function CheckPlotForImprovementRemoval(plot, obj)
    local improvementType = obj:GetImprovementTypeByDomain(plot)
    if improvementType == nil then
        return nil
    end

    local plotID = plot:GetIndex()
    local canImprove = ExposedMembers.AutoBuilder.CanHaveImprovement(
        plotID, improvementType, obj.playerID
    )
    if not canImprove then
        return nil
    end

    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType ~= improvementType then
        return UnitOperationTypes.REMOVE_IMPROVEMENT
    end
    return nil
end

function CheckPlotForLumbermill(plot, obj)
    local plotID = plot:GetIndex()
    if obj.possibleLumberMillPlots[plotID] ~= nil then
        local canImprove = ExposedMembers.AutoBuilder.CanHaveImprovement(
            plotID, LUMBER_MILL_INDEX, obj.playerID
        )
        if canImprove then
            return UnitOperationTypes.BUILD_IMPROVEMENT
        end
    end
    return nil
end

function CheckPlotForMapPin(plot, obj)
    local plotID = plot:GetIndex()
    if obj.builderMapPinPlots[plotID] ~= nil then
        local value = obj.builderMapPinPlots[plotID]
        if GameInfo.UnitOperationTypes[value] ~= nil then
            return GameInfo.UnitOperationTypes[value]
        elseif GameInfo.Improvements[value] ~= nil then
            return UnitOperationTypes.BUILD_IMPROVEMENT
        end
    end
end

print("=== Auto Builders (Actions) Loaded ===")
