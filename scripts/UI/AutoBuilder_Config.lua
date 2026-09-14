include("AutoBuilder_Actions")

-- Set to the maximum number of lumber mills that should be created
-- The script will prioritize lumber mills on hills over non-hills first
MAX_LUMBER_MILLS_PER_CITY = 6

-- Place Action Functions in the order they should be prioritized
ActionFunctions = {
    CheckPlotForRemovableMarsh,
    CheckPlotForRepair,
    CheckPlotForImprovementRemoval,
    CheckPlotForImprovementNeeded,
    CheckPlotForLumbermill,
}
