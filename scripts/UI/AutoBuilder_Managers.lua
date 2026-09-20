include("AutoBuilder_Constants")

CityImprovementManager = {}
CityImprovementManager.__index = CityImprovementManager
CityImprovementManager.Registry = {}

function CityImprovementManager:new(plotID, playerID, cityID)
    if CityImprovementManager.Registry[plotID] then
        return CityImprovementManager.Registry[plotID]
    end

    local instance = {
        plotID = plotID,
        playerID = playerID,
        cityID = cityID,
        actionPlotCount = 0,
        plotImprovements = {},
        buildersInCity = {},
        builderImprovementsByUnit = {},
        builderImprovementsByPlot = {},
        districtMapPinPlots = {},
        possibleLumberMillPlots = {},
        existingLumberMillPlots = {},
        builderMapPinPlots = {},
        safePlot = nil,
        finishedInitialization = false,
        burningPlots = {}
    }

    setmetatable(instance, self)
    instance:GetCitySafePlot()
    CityImprovementManager.Registry[plotID] = instance
    return instance
end

function CityImprovementManager:RefreshImprovementData()
    self.districtMapPinPlots = {}
    -- TODO: allow for builder action map pins to take priority
    local config = PlayerConfigurations[self.playerID]
    local pins = config:GetMapPins()
    for _, pin in pairs(pins) do
        local plot = Map.GetPlot(pin:GetHexX(), pin:GetHexY())
        local city = Cities.GetPlotPurchaseCity(plot)
        local name = pin:GetIconName():gsub("^ICON_", "")
        if (
            city ~= nil and
            city:GetID() == self.cityID and
            city:GetOwner() == self.playerID
        ) then
            local plotID = plot:GetIndex()
            local info = GameInfo.Districts[name] or GameInfo.Buildings[name]
            local info2 = (
                GameInfo.Improvements[name] or
                GameInfo.UnitOperations[name]
            )
            if info ~= nil then
                self.districtMapPinPlots[plotID] = name
            elseif info2 ~= nil then
                self.builderMapPinPlots[plotID] = info2.Index
            end
        end
    end
    self.buildersInCity = {}
    self.plotImprovements = {}
    self.possibleLumberMillPlots = {}
    self.existingLumberMillPlots = {}
    local tempLumberMillPlots = {}
    self.burningPlots = {}
    local city = CityManager.GetCity(self.playerID, self.cityID)
    local plots = Map.GetCityPlots():GetPurchasedPlots(city)
    local player = Players[self.playerID]
    local civics = player:GetCulture()
    local techs = player:GetTechs()
    local possibleActionPlots = {}
    for i = 1, #plots do
        local plotID = plots[i]
        local plot = Map.GetPlotByIndex(plotID)
        -- find if any builders are on the plot
        local units = Units.GetUnitsInPlot(plot)
        if #units > 0 then
            for n = 1, #units do
                local unit = units[n]
                if unit:GetType() == BUILDER_INDEX then
                    table.insert(self.buildersInCity, unit:GetID())
                end
            end
        end
        local districtType = self.districtMapPinPlots[plotID]
        if (
            districtType == nil or
            (districtType ~= "BUILDING_ETEMENANKI" and plot:GetFeatureType() == MARSH_INDEX)
        ) then
            local feature = plot:GetFeatureType()
            if feature == JUNGLE_INDEX or feature == WOODS_INDEX then
                local improvement = plot:GetImprovementType()
                if improvement == LUMBER_MILL_INDEX then
                    table.insert(self.existingLumberMillPlots, plotID)
                else
                    local isHills = plot:IsHills()
                    if tempLumberMillPlots[isHills] == nil then
                        tempLumberMillPlots[isHills] = {}
                    end
                    table.insert(tempLumberMillPlots[isHills], plotID)
                end
            end
            if (
                feature == BURNING_WOODS_INDEX or
                feature == BURNING_JUNGLE_INDEX
            ) then
                self.burningPlots[plotID] = true
            elseif plot:GetDistrictType() == -1 then
                table.insert(possibleActionPlots, plotID)
            end
        end
    end
    local count = #self.existingLumberMillPlots
    local array = {true, false}
    for i = 1, #array do
        local key = array[i]
        if tempLumberMillPlots[key] ~= nil then
            for n = 1, #tempLumberMillPlots[key] do
                if count < MAX_LUMBER_MILLS_PER_CITY then
                    local plotID = tempLumberMillPlots[key][n]
                    self.possibleLumberMillPlots[plotID] = true
                end
            end
        end
    end
    self.actionPlotCount = 0
    for i = 1, #possibleActionPlots do
        local plotID = possibleActionPlots[i]
        local plot = Map.GetPlotByIndex(plotID)
        local x = plot:GetX()
        local y = plot:GetY()
        local actionLevel, actionType = self:GetActionTypeForPlot(plot)
        if actionLevel ~= nil and actionType ~= nil then
            local improvementHash = nil
            local canProceed = true
            if actionType == UnitOperationTypes.BUILD_IMPROVEMENT then
                canProceed = true
                local improvementType = self:GetImprovementTypeByDomain(plot)
                local improvementInfo = GameInfo.Improvements[
                    improvementType
                ]
                improvementHash = improvementInfo.Hash
                if improvementInfo.PrereqCivic then
                    local civicInfo = GameInfo.Civics[
                        improvementInfo.PrereqCivic
                    ]
                    if not civics:HasCivic(civicInfo.Index) then
                        canProceed = false
                    end
                end
                if improvementInfo.PrereqTech then
                    local techInfo = GameInfo.Technologies[
                        improvementInfo.PrereqTech
                    ]
                    if not techs:HasTech(techInfo.Index) then
                        canProceed = false
                    end
                end
            end

            if canProceed then
                self.actionPlotCount = self.actionPlotCount + 1
                local params = {
                    [UnitOperationTypes.PARAM_X] = x,
                    [UnitOperationTypes.PARAM_Y] = y,
                }
                if improvementHash then
                    params[
                        UnitOperationTypes.PARAM_IMPROVEMENT_TYPE
                    ] = improvementHash
                end

                if self.plotImprovements[actionLevel] == nil then
                    self.plotImprovements[actionLevel] = {}
                end
                self.plotImprovements[actionLevel][plotID] = {
                    X = x,
                    Y = y,
                    Action = actionType,
                    Params = params
                }
            end
        end
    end
    self.finishedInitialization = true
end

function CityImprovementManager:GetActionTypeForPlot(plot)
    local actionType = nil
    local actionLevel = nil

    for level = 1, #ActionFunctions do
        local actionFunction = ActionFunctions[level]
        local currentActionType = actionFunction(plot, self)
        if currentActionType ~= nil then
            actionLevel = level
            actionType = currentActionType
            break
        end
        if actionType ~= nil then
            break
        end
    end

    return actionLevel, actionType
end

function CityImprovementManager:ProcessNewBuilder(unitID)
    local level, plotID = self:GetNextTask()
    if level ~= nil and plotID ~= nil then
        local data = self.plotImprovements[level][plotID]
        self.builderImprovementsByUnit[unitID] = plotID
        self.builderImprovementsByPlot[plotID] = data
        self:ProcessCurrentTaskForUnit(unitID)
        return
    end
    self:SkipTurn(unitID)
end

function CityImprovementManager:ProcessBuilders()
    local city = CityManager.GetCity(self.playerID, self.cityID)
    if #self.buildersInCity == 0 then
        if self.actionPlotCount >= 3 then
            self:AddWorkerPin()
        end
        return
    end
    for i = 1, #self.buildersInCity do
        local unitID = self.buildersInCity[i]
        local unit = UnitManager.GetUnit(self.playerID, unitID)
        local findNewTask = true
        if #self.burningPlots > 0 then
            local plotID = self.builderImprovementsByUnit[unitID]
            if plotID ~= nil then
                self.builderImprovementsByPlot[plotID] = nil
            end
            self.builderImprovementsByUnit[unitID] = nil
        else
            if self.builderImprovementsByUnit[unitID] ~= nil then
                if self:IsImprovementStillNeeded(unitID) then
                    findNewTask = false
                    self:ProcessCurrentTaskForUnit(unitID)
                else
                    local plotID = self.builderImprovementsByUnit[unitID]
                    self.builderImprovementsByPlot[plotID] = nil
                    self.builderImprovementsByUnit[unitID] = nil
                end
            elseif not unit:IsReadyToMove() then
                findNewTask = false
            end
            if findNewTask then
                local level, plotID = self:GetNextTask()
                if level ~= nil and plotID ~= nil then
                    local data = self.plotImprovements[level][plotID]
                    self.builderImprovementsByUnit[unitID] = plotID
                    self.builderImprovementsByPlot[plotID] = data
                    self:ProcessCurrentTaskForUnit(unitID)
                end
            end
        end
        if self.builderImprovementsByUnit[unitID] == nil then
            self:SkipTurn(unitID)
        end
    end
end

function CityImprovementManager:AddWorkerPin()
    local foundBuilder = false
    local city = CityManager.GetCity(self.playerID, self.cityID)
    local queue = city:GetBuildQueue()
    local length = queue:GetSize()
    -- Find if a builder is already in the queue
    for i = 0, length - 1 do
        local item = queue:GetAt(i)
        if item.UnitType == BUILDER_INDEX then
            foundBuilder = true
        end
    end
    -- Add the pin and fire the OnAdd event if builder not found in queue
    if not foundBuilder then
        local config = PlayerConfigurations[self.playerID]
        local plot = Map.GetPlotByIndex(self.plotID)
        local x = plot:GetX()
        local y = plot:GetY()
        local pin = config:GetMapPin(x, y)
        local iconName = "ICON_UNIT_BUILDER"
        pin:SetIconName(iconName)
        Network.BroadcastPlayerInfo()
        LuaEvents.MapPinPopup_OnAdd(self.playerID, pin:GetID(), iconName, x, y)
    end
end

function CityImprovementManager:GetNextTask()
    local levels = {}
    for k in pairs(self.plotImprovements) do
        table.insert(levels, k)
    end
    table.sort(levels)
    for i = 1, #levels do
        local level = levels[i]
        for plotID, _ in pairs(self.plotImprovements[level]) do
            if self.builderImprovementsByPlot[plotID] == nil then
                return level, plotID
            end
        end
    end
    return nil
end

function CityImprovementManager:IsImprovementStillNeeded(unitID)
    local plotID = self.builderImprovementsByUnit[unitID]
    if plotID == nil then
        return nil
    end

    local data = self.builderImprovementsByPlot[plotID]
    if data == nil then
        return nil
    end

    local actionType = data["Action"]
    local plot = Map.GetPlotByIndex(plotID)

    if actionType == UnitOperationTypes.REMOVE_FEATURE then
        return plot:GetFeatureType() == MARSH_INDEX
    end

    if actionType == UnitOperationTypes.REPAIR then
        return plot:IsImprovementPillaged()
    end

    local improvementType = self:GetImprovementTypeByDomain(plot)
    local currentImprovementType = plot:GetImprovementType()
    if currentImprovementType == -1 then
        if actionType == UnitOperationTypes.BUILD_IMPROVEMENT then
            local params = data["Params"]
            local hash = params[UnitOperationTypes.PARAM_IMPROVEMENT_TYPE]
            local info = GameInfo.Improvements[hash]
            local canImprove = ExposedMembers.AutoBuilder.CanHaveImprovement(
                plotID, info.Index, self.playerID
            )
            if canImprove then
                return true
            end
        end
        return false
    end

    if currentImprovementType ~= improvementType then
        return actionType == UnitOperationTypes.REMOVE_IMPROVEMENT
    end
    return false
end

function CityImprovementManager:ProcessCurrentTaskForUnit(unitID)
    local unit = UnitManager.GetUnit(self.playerID, unitID)
    local endPlotID = self.builderImprovementsByUnit[unitID]
    local data = self.builderImprovementsByPlot[endPlotID]
    if data == nil then
        return
    end

    local x = data["X"]
    local y = data["Y"]
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
        local moveParams = {
            [UnitOperationTypes.PARAM_X] = x,
            [UnitOperationTypes.PARAM_Y] = y,
        }
        UnitManager.RequestOperation(
            unit, UnitOperationTypes.MOVE_TO, moveParams
        )
    end

    if isReachable then
        local actionType = data["Action"]
        local params = data["Params"]
        UnitManager.RequestOperation(unit, actionType, params)
    end
end

function CityImprovementManager:SkipTurn(unitID)
    local unit = UnitManager.GetUnit(self.playerID, unitID)
    if self.safePlot ~= nil then
        local plot = Map.GetPlotByIndex(self.safePlot)
        local params = {
            [UnitOperationTypes.PARAM_X] = plot:GetX(),
            [UnitOperationTypes.PARAM_Y] = plot:GetY(),
        }
        UnitManager.RequestOperation(unit, UnitOperationTypes.MOVE_TO, params)
    end
    UnitManager.RequestOperation(unit, SKIP_TURN_HASH, {})
end

function CityImprovementManager:GetCitySafePlot()
    local city = CityManager.GetCity(self.playerID, self.cityID)
    local iX = city:GetX()
    local iY = city:GetY()
    local plot = Map.GetPlot(iX, iY)
    local featureType = plot:GetFeatureType()
    if featureType ~= FLOODPLAINS_INDEX then
        self.safePlot = plot:GetIndex()
        return
    end

    local hillsPlotID = nil
    local nonHillsPlotID = nil
    for direction = 0, 5 do
        local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction)
        if adjacentPlot ~= nil then
            featureType = adjacentPlot:GetFeatureType()
            if (
                featureType ~= FLOODPLAINS_INDEX
                and featureType ~= WOODS_INDEX
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
        self.safePlot = hillsPlotID
        return
    end

    self.safePlot = nonHillsPlotID
end

function CityImprovementManager:GetImprovementTypeByDomain(plot)
    local plotID = plot:GetIndex()
    if self.builderMapPinPlots[plotID] ~= nil then
        local value = self.builderMapPinPlots[plotID]
        local info = GameInfo.Improvements[value]
        if info ~= nil then
            return info.Index
        end
    end

    local resourceType = plot:GetResourceType()
    if resourceType ~= -1 then
        local player = Players[self.playerID]
        local resources = player:GetResources()
        -- if the resource is not visible, yet, don't allow improvement
        if not resources:IsResourceVisible(resourceType) then
            resourceType = -1
        end
    end
    if resourceType == -1 then
        local featureType = plot:GetFeatureType()
        if featureType == WOODS_INDEX or featureType == JUNGLE_INDEX then
            return LUMBER_MILL_INDEX
        end
        return nil
    end

    local isWater = plot:IsWater()
    local domain = "DOMAIN_LAND"
    if isWater then
        domain = "DOMAIN_SEA"
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

print("=== Auto Builders (Managers) Loaded ===")
