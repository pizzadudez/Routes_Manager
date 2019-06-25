local Routes = LibStub("AceAddon-3.0"):GetAddon("Routes")
local RoutesManager = Routes:NewModule('RoutesManager', 'AceEvent-3.0', 'AceTimer-3.0')
local StdUi = LibStub('StdUi')

-- Initialization (after enabling module)
function RoutesManager:Enable()
    --self.db = Routes.db.global.routes
    self.db = RoutesDB.global.routes
    self.mapID = C_Map.GetBestMapForUnit('player')

    self:RegisterEvent('ZONE_CHANGED_NEW_AREA')
    -- draw 5 seconds after login (workaround)
    if not self.window then
        self.mapID = C_Map.GetBestMapForUnit('player')
        self:ScheduleTimer('DrawManagerFrame', 5)
    end
end


--[[ Event Handlers ]]--
function RoutesManager:ZONE_CHANGED_NEW_AREA()
    self.mapID = C_Map.GetBestMapForUnit('player')
    
    -- this event fires before loading in aswell
    if self.window then
        -- zone changed, redraw clusterBtns and infoFrame elements
        self.currCluster = nil
        self.currClusterName = nil
        self:DrawClusterButtons()
        -- infoFrame
        self:UpdateInfoFrame(GetZoneText(), '', '', true)
    end
end


-- [[ UI Drawing/Updating ]]--
function RoutesManager:DrawManagerFrame()
    local window = StdUi:PanelWithTitle(UIParent, 240, 310, 'Routes Manager', 100, 16)
    window:SetPoint('TOPLEFT', UIParent, 'CENTER', 350, 200)
    self.window = window

    self:DrawInfoFrame()
    self:DrawClusterScrollFrame()

    -- addNode Button
    local addNodeBtn = StdUi:Button(window, 60, 30, 'Add Node')
    addNodeBtn:SetPoint('TOPLEFT', window.infoFrame, 'TOPLEFT', 0, -68)
    addNodeBtn:SetScript('OnClick', function()
        if self.currCluster then
            self.currCluster.route = self.currCluster.route or {}
            local nodeList = self.currCluster.route
            nodeList[#nodeList + 1] = self:PlayerPositionCoords()
            self:SortNodes(self.currCluster)
            self:UpdateInfoFrame(nil, nil, #nodeList, true)
        end
    end)
    -- removeNode Button
    local removeNodeBtn = StdUi:Button(window, 60, 30, 'Remove Node')
    removeNodeBtn:SetPoint('TOPLEFT', addNodeBtn, 'BOTTOMLEFT', 0, -6)
    removeNodeBtn:SetScript('OnClick', function()
        if self.currCluster then
            self:RemoveClosestNode(self.currCluster)
            self:SortNodes(self.currCluster)
            self:UpdateInfoFrame(nil, nil, #nodeList, true)
        end
    end)
    -- addCluster nameBox
    local addClusterNameBox = StdUi:EditBox(window, 60, 20)
    addClusterNameBox:SetPoint('TOPLEFT', window.infoFrame, 'BOTTOMLEFT', 0, -12)
    this = self
    addClusterNameBox.OnValueChanged = function(self)
        this.newClusterName = (self:GetValue())
        if name == '' then
            this.newClusterName = nil
        end
        self:ClearFocus()
    end
    -- addCluster Button
    local addClusterBtn = StdUi:Button(window, 60, 30, 'Add Cluster')
    addClusterBtn:SetPoint('TOPLEFT', addClusterNameBox, 'BOTTOMLEFT', 0, -6)
    addClusterBtn:SetScript('OnClick', function()
        if self.newClusterName then
            local newCluster = {
                route = {
                    self:PlayerPositionCoords(),
                    self:PlayerPositionCoords() + 500000,
                    self:PlayerPositionCoords() + 50
                },
                color = {53/255, 199/255, 252/255, 0.5},
                defaultColor = {53/255, 199/255, 252/255, 0.5}
            }
            self.db[self.mapID][self.newClusterName] = newCluster
            self:DrawClusterButtons()
        end
        addClusterNameBox:SetValue('') -- sets self.newClusterName to nil
    end)
    -- renameCluster Button
    local renameClusterBtn = StdUi:Button(window, 60, 30, 'Rename Cluster')
    renameClusterBtn:SetPoint('LEFT', addClusterBtn, 'RIGHT', 6, 0)
    renameClusterBtn:SetScript('OnClick', function()
        if self.currCluster then
            local newCluster = {}
            for k, v in pairs(self.currCluster) do
                newCluster[k] = v
            end
            self.db[self.mapID][self.newClusterName] = newCluster
            
            self.removedClusters = self.removedClusters or {}
            tinsert(self.removedClusters, self.currClusterName)
            table.wipe(self.currCluster)
            self.currCluster = newCluster
            self:DrawClusterButtons()
            self:UpdateInfoFrame(nil, self.newClusterName, #self.currCluster.route, true)
        end
        addClusterNameBox:SetValue('')
    end)
    -- removeCluster Button (+ shiftKey)
    local removeClusterBtn = StdUi:Button(window, 80, 24, 'Remove Cluster')
    removeClusterBtn:SetPoint('TOPLEFT', removeNodeBtn, 'BOTTOMLEFT', 0, -6)
    removeClusterBtn:SetScript('OnClick', function()
        if self.currCluster and IsShiftKeyDown() then
            self.removedClusters = self.removedClusters or {}
            tinsert(self.removedClusters, self.currClusterName)
            table.wipe(self.currCluster)
            self.currCluster = nil
            self:DrawClusterButtons()
            self:UpdateInfoFrame(nil, '', '', true)
        end
    end)
end


-- Cluster Scroll Frame
function RoutesManager:DrawClusterScrollFrame()
    local clusterFrame = {}
    clusterFrame.panel, clusterFrame.scrollFrame, clusterFrame.clusterFrame, clusterFrame.scrollBar =
        self:ScrollFrame(self.window, 56, 250)
    clusterFrame.panel:SetPoint('TOPRIGHT', self.window, 'TOPRIGHT', -10, -32)
    clusterFrame.panel:SetPoint('BOTTOMRIGHT', self.window, 'BOTTOMRIGHT', -10, 10)
    
    self.window.clusterFrame = clusterFrame

    self:DrawClusterButtons()
end

-- ClusterBtns Frame Draw/Update
function RoutesManager:DrawClusterButtons()
    local clusterFrame = self.window.clusterFrame.clusterFrame

    -- sort clusterKeys in zone table
    local clusterKeys = {}
    for clusterKey, _ in pairs(self.db[self.mapID]) do
        tinsert(clusterKeys, clusterKey)
    end
    for _, removedKey in ipairs(self.removedClusters or {}) do
        for i, clusterKey in ipairs(clusterKeys) do
            if clusterKey == removedKey then
                tremove(clusterKeys, i)
            end
        end
    end
    table.sort(clusterKeys)
    
    -- create clusterBtns now that the keys are sorted
    local clusterBtns = clusterFrame.clusterBtns or {}
    clusterFrame.clusterBtns = clusterBtns
    for i, clusterName in ipairs(clusterKeys) do
        local clusterBtn = clusterBtns[i]
        if not clusterBtn then
            clusterBtn = self:CreateClusterButton(clusterName)     
            clusterBtns[i] = clusterBtn
        end
        -- update clusterName 
        clusterBtn.text:SetText(clusterName)
        -- :Show() if previously :Hidden()
        if not clusterBtn:IsVisible() then
            clusterBtn:Show()
        end
        -- anchor buttons
        if i == 1 then clusterBtn:SetPoint('TOPLEFT', clusterFrame, 'TOPLEFT')
        else clusterBtn:SetPoint('TOP', clusterBtns[i-1], 'BOTTOM') end
        
    end
    -- hide excess slides
    for i = #clusterKeys + 1, #clusterBtns do
        clusterBtns[i]:Hide()
    end
end

function RoutesManager:CreateClusterButton(clusterName)
    local clusterFrame = self.window.clusterFrame.clusterFrame

    local btn = StdUi:Button(clusterFrame, 50, 20, clusterName)  
    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    this = self
    btn:SetScript('OnClick', function(self, button)
        if this.currCluster then
            this.currCluster.color = this.currCluster.defaultColor or 
            {53/255, 199/255, 252/255, 0.5}
        end
        if button == 'LeftButton' then
            this.currClusterName = self.text:GetText()
            this.currCluster = this.db[this.mapID][this.currClusterName]
            this.currCluster.color = {255/255, 94/255, 255/255, 1}
            this:SortNodes(this.currCluster)
            this:UpdateInfoFrame(nil, this.currClusterName, #this.currCluster.route, true)
        elseif button == 'RightButton' then
            if this.currCluster then
                this.currCluster.color = this.currCluster.defaultColor or 
                    {53/255, 199/255, 252/255, 0.5}
            end
            this.currClusterName = nil
            this.currCluster = nil
            this:UpdateInfoFrame(nil, '', '', true)
        end
    end)
    return btn
end


function RoutesManager:DrawInfoFrame()
    local window = self.window
    local infoFrame = StdUi:Frame(window, 150, 200)
    infoFrame:SetPoint('TOPLEFT', window, 'TOPLEFT', 10, -32)
    window.infoFrame = infoFrame

    -- zone name
    local zoneNameTitle = StdUi:Label(infoFrame, 'Zone:', 16)
    zoneNameTitle:SetPoint('TOPLEFT', infoFrame, 'TOPLEFT', 0, -6)
    local zoneName = StdUi:Label(infoFrame, GetZoneText(), 16)
    zoneName:SetPoint('LEFT', zoneNameTitle, 'RIGHT', 3, 0)
    zoneName:SetTextColor(1, 1, 0.12, 1)
    infoFrame.zoneName = zoneName
    -- cluster name
    local clusterNameTitle = StdUi:Label(infoFrame, 'Cluster:', 16)
    clusterNameTitle:SetPoint('TOPLEFT', zoneNameTitle, 'BOTTOMLEFT', 0, -4)
    local clusterName = StdUi:Label(infoFrame, '', 16)
    clusterName:SetPoint('LEFT', clusterNameTitle, 'RIGHT', 3, 0)
    clusterName:SetTextColor(1, 1, 0.12, 1)
    infoFrame.clusterName = clusterName
    -- node count
    local nodeCountTitle = StdUi:Label(infoFrame, 'Nodes Count:', 16)
    nodeCountTitle:SetPoint('TOPLEFT', clusterNameTitle, 'BOTTOMLEFT', 0, -4)
    local nodeCount = StdUi:Label(infoFrame, '', 16)
    nodeCount:SetPoint('Left', nodeCountTitle, 'RIGHT', 3, 0)
    nodeCount:SetTextColor(1, 1, 0.12, 1)
    infoFrame.nodeCount = nodeCount
    -- node list
    local nodeList = StdUi:Frame(infoFrame, 80, 150)
    nodeList:SetPoint('TOPLEFT', nodeCount, 'BOTTOMLEFT', 0, 0)
    infoFrame.nodeList = nodeList
    self:DrawInfoFrameNodeList()
end

-- Usage: nil => no change, emptyString => set nothing, true (4th param) => redraw nodeList
function RoutesManager:UpdateInfoFrame(zoneName, clusterName, nodeCount, nodeList)
    local infoFrame = self.window.infoFrame

    if zoneName then
        infoFrame.zoneName:SetText(zoneName)
    end
    if clusterName then
        infoFrame.clusterName:SetText(clusterName)
    end
    if nodeCount then
        infoFrame.nodeCount:SetText(nodeCount)
    end
    if nodeList then
        self:DrawInfoFrameNodeList()
    end
end

function RoutesManager:DrawInfoFrameNodeList()
    local nodeFrame = self.window.infoFrame.nodeList
    local nodes = nodeFrame.nodes or {}
    nodeFrame.nodes = nodes

    -- no cluster selected => dont draw and hide all labels
    if not self.currCluster then
        for _, node in ipairs(nodes) do
            node:Hide()
        end
        return 
    end

    for i, node in ipairs(self.currCluster.route) do
        local label = nodes[i]
        if not label then -- create if not exists
            label = StdUi:Label(nodeFrame, '', 14)
        end
        label:Show()
        label:SetText(node) -- update text
        if i == 1 then
            label:SetPoint('TOPLEFT', nodeFrame, 'TOPLEFT', 0, 0)
        else
            label:SetPoint('TOPLEFT', nodes[i-1], 'BOTTOMLEFT', 0, -2)
        end
        nodes[i] = label
    end
    -- hide excess node labels
    for i = #self.currCluster.route + 1, #nodes do
        nodes[i]:Hide()
    end
end


-- [[ Helper Functions ]] --
-- Returns Player Position as Node formatted number (xxxxyyyy)
function RoutesManager:PlayerPositionCoords()
    local position = C_Map.GetPlayerMapPosition(self.mapID, 'player')
    local px = math.floor(position.x * 10000 + 0.5)
    local py = math.floor(position.y * 10000 + 0.5)
    return tonumber(px..py)
end

-- Sorts the nodes in a cluster to create a non-intersecting polygon
function RoutesManager:SortNodes(cluster)
    if #cluster.route < 3 then return end
    
    table.sort(cluster.route)
    local leftMostNode = tremove(cluster.route, 1)
    local rightMostNode = tremove(cluster.route)
    local xa = math.floor(leftMostNode / 10000)
    local ya = leftMostNode % 10000
    local xb = math.floor(rightMostNode / 10000)
    local yb = rightMostNode % 10000

    -- nodes above are inserted in the first iteration
    sortedNodes = {}
    tinsert(sortedNodes, leftMostNode)
    for _, node in ipairs(cluster.route) do
        local x = math.floor(node / 10000)
        local y = node % 10000
        -- determinant
        local det = (xa-x)*(yb-y) - (xb-x)*(ya-y)
        if det >= 0 then
            tinsert(sortedNodes, node) -- insert after leftMost
        else
            tinsert(sortedNodes, 1, node) -- insert before leftMost
        end
    end
    tinsert(sortedNodes, rightMostNode)

    cluster.route = sortedNodes
end

-- Remove Closest Node from Cluster
function RoutesManager:RemoveClosestNode(cluster)
    local currPosition = self:PlayerPositionCoords()
    local x = math.floor(currPosition / 10000)
    local y = currPosition % 10000

    local closestNodeIdx
    local minDistance
    for i, node in ipairs(cluster.route) do
        xn = math.floor(node / 10000)
        yn = node % 10000
        local distance = math.sqrt((x-xn)*(x-xn) + (y-yn)*(y-yn))
        if not minDistance or distance < minDistance then
            minDistance = distance
            closestNodeIdx = i
        end
    end
    tremove(cluster.route, closestNodeIdx)
end


-- PERMANENTLY POSTPONED

-- function RoutesManager:MINIMAP_PING(self, unit, x, y)
--     local playerPosition = C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit('player'), 'player')
--     local xp = playerPosition.x
--     local yp = playerPosition.y

--     local c = 0.13021616986442394

--     local pingX = (xp + xp * x * c) * 10000 
--     local pingY = (yp + yp * y * c * -1) * 10000 
--     print(pingX)
--     print(pingY)
-- end