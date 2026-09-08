function GetImprovementTypeByDomain(plot)
    local resourceType = plot:GetResourceType()
    if resourceType == -1 then
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

print("=== Auto Builders (Helpers) Loaded ===")
