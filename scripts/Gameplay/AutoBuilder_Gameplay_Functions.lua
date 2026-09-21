-- ===========================================================================
--  Auto Builder - UI Script
--  Provides Auto Builder UI scripts.
-- ===========================================================================

print("=== Auto Builders (Gameplay) Loading ===")

ExposedMembers.AutoBuilder = ExposedMembers.AutoBuilder or {}

function CanHaveImprovement(plotID, improvementType, playerID)
    local plot = Map.GetPlotByIndex(plotID)
    return ImprovementBuilder.CanHaveImprovement(
        plot, improvementType, playerID
    )
end

ExposedMembers.AutoBuilder.CanHaveImprovement = CanHaveImprovement

print("=== Auto Builders (Gameplay) Loaded ===")
