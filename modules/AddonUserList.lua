local addonName, addon = ...

local AddonUserList = {}
addon.AddonUserList = AddonUserList

local userListFrame = nil
local refreshTimer = nil

function AddonUserList:CreateUserListWindow()
    if userListFrame then
        return userListFrame
    end
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Creating Addon User List window")
    
    -- Create main frame
    userListFrame = CreateFrame("Frame", "GrouperPlusUserListFrame", UIParent, "BasicFrameTemplateWithInset")
    userListFrame:SetSize(400, 500)
    userListFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    userListFrame:SetMovable(true)
    userListFrame:EnableMouse(true)
    userListFrame:RegisterForDrag("LeftButton")
    userListFrame:SetScript("OnDragStart", userListFrame.StartMoving)
    userListFrame:SetScript("OnDragStop", userListFrame.StopMovingOrSizing)
    userListFrame:Hide()
    
    -- Set frame properties
    userListFrame.title = userListFrame:CreateFontString(nil, "OVERLAY")
    userListFrame.title:SetFontObject("GameFontHighlightLarge")
    userListFrame.title:SetPoint("LEFT", userListFrame.TitleBg, "LEFT", 5, 0)
    userListFrame.title:SetText("GrouperPlus Users")
    
    -- Create header info
    local headerInfo = userListFrame:CreateFontString(nil, "OVERLAY")
    headerInfo:SetFontObject("GameFontNormal")
    headerInfo:SetPoint("TOPLEFT", userListFrame.Inset, "TOPLEFT", 10, -10)
    headerInfo:SetText("Guild members with GrouperPlus installed:")
    headerInfo:SetJustifyH("LEFT")
    userListFrame.headerInfo = headerInfo
    
    -- Create user count display
    local userCount = userListFrame:CreateFontString(nil, "OVERLAY")
    userCount:SetFontObject("GameFontHighlight")
    userCount:SetPoint("TOPLEFT", headerInfo, "BOTTOMLEFT", 0, -5)
    userCount:SetText("Users: 0")
    userCount:SetTextColor(0.8, 0.8, 0.8, 1)
    userListFrame.userCount = userCount
    
    -- Create scroll frame for user list
    local scrollFrame = CreateFrame("ScrollFrame", nil, userListFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", userCount, "BOTTOMLEFT", 0, -15)
    scrollFrame:SetPoint("BOTTOMRIGHT", userListFrame.Inset, "BOTTOMRIGHT", -25, 40)
    userListFrame.scrollFrame = scrollFrame
    
    -- Create content frame
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(contentFrame)
    userListFrame.contentFrame = contentFrame
    
    -- Create refresh button
    local refreshButton = CreateFrame("Button", nil, userListFrame, "GameMenuButtonTemplate")
    refreshButton:SetSize(100, 22)
    refreshButton:SetPoint("BOTTOMLEFT", userListFrame.Inset, "BOTTOMLEFT", 10, 10)
    refreshButton:SetText("Refresh")
    refreshButton:SetScript("OnClick", function()
        addon.Debug(addon.LOG_LEVEL.INFO, "Manual refresh of addon user list")
        AddonUserList:RefreshUserList()
        if addon.AddonComm then
            addon.AddonComm:BroadcastVersionCheck()
        end
    end)
    userListFrame.refreshButton = refreshButton
    
    -- Create close button functionality
    userListFrame:SetScript("OnHide", function()
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Addon user list window hidden")
        if refreshTimer then
            refreshTimer:Cancel()
            refreshTimer = nil
        end
    end)
    
    -- Auto-refresh every 30 seconds when visible
    userListFrame:SetScript("OnShow", function()
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Addon user list window shown")
        AddonUserList:RefreshUserList()
        
        -- Start auto-refresh timer
        if not refreshTimer then
            refreshTimer = C_Timer.NewTicker(30, function()
                if userListFrame:IsVisible() then
                    AddonUserList:RefreshUserList()
                end
            end)
        end
    end)
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Addon User List window created successfully")
    return userListFrame
end

function AddonUserList:RefreshUserList()
    if not userListFrame or not userListFrame.contentFrame then
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Refreshing addon user list")
    
    -- Clear existing user entries
    for i, child in ipairs({userListFrame.contentFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Get connected users
    local connectedUsers = {}
    local userCount = 0
    if addon.AddonComm then
        connectedUsers = addon.AddonComm:GetConnectedUsers()
        for user, info in pairs(connectedUsers) do
            userCount = userCount + 1
        end
    end
    
    -- Add current player to the list
    local playerName = UnitName("player")
    if playerName then
        connectedUsers[playerName] = {
            version = "0.6.0", -- Current addon version
            lastSeen = GetServerTime(),
            isCurrentPlayer = true
        }
        userCount = userCount + 1
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Added current player to addon user list:", playerName)
    end
    
    -- Update user count display
    userListFrame.userCount:SetText("Users: " .. userCount)
    
    if userCount == 1 and playerName and connectedUsers[playerName] and connectedUsers[playerName].isCurrentPlayer then
        -- Show "only you" message
        local noUsersText = userListFrame.contentFrame:CreateFontString(nil, "OVERLAY")
        noUsersText:SetFontObject("GameFontNormal")
        noUsersText:SetPoint("TOPLEFT", userListFrame.contentFrame, "TOPLEFT", 10, -10)
        noUsersText:SetText("No other GrouperPlus users detected in guild.")
        noUsersText:SetJustifyH("LEFT")
        noUsersText:SetTextColor(0.7, 0.7, 0.7, 1)
        
        local helpText = userListFrame.contentFrame:CreateFontString(nil, "OVERLAY")
        helpText:SetFontObject("GameFontNormalSmall")
        helpText:SetPoint("TOPLEFT", noUsersText, "BOTTOMLEFT", 0, -10)
        helpText:SetText("Other guild members need to install GrouperPlus\nand be online to appear in this list.")
        helpText:SetJustifyH("LEFT")
        helpText:SetTextColor(0.6, 0.6, 0.6, 1)
        
        -- Still show current player entry below the message
        userListFrame.contentFrame:SetHeight(120)
        yOffset = -80 -- Start user entries below the help text
    else
        -- Normal display - no special message needed
        yOffset = -10
    end
    
    -- Create user entries
    local entryHeight = 45
    
    -- Sort users - current player first, then alphabetically
    local sortedUsers = {}
    for user, info in pairs(connectedUsers) do
        table.insert(sortedUsers, {name = user, info = info})
    end
    table.sort(sortedUsers, function(a, b) 
        -- Current player always comes first
        if a.info.isCurrentPlayer then return true end
        if b.info.isCurrentPlayer then return false end
        -- Otherwise sort alphabetically
        return a.name < b.name 
    end)
    
    for i, userData in ipairs(sortedUsers) do
        local user = userData.name
        local info = userData.info
        
        -- Create user entry frame
        local userEntry = CreateFrame("Frame", nil, userListFrame.contentFrame)
        userEntry:SetSize(userListFrame.contentFrame:GetWidth() - 20, entryHeight)
        userEntry:SetPoint("TOPLEFT", userListFrame.contentFrame, "TOPLEFT", 10, yOffset)
        
        -- Background for alternating colors
        local bg = userEntry:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i % 2 == 0 then
            bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
        else
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.3)
        end
        
        -- Player name with class color
        local nameText = userEntry:CreateFontString(nil, "OVERLAY")
        nameText:SetFontObject("GameFontNormalLarge")
        nameText:SetPoint("TOPLEFT", userEntry, "TOPLEFT", 10, -5)
        
        -- Get class color
        local className = UnitClass(user)
        if className then
            local classColor = RAID_CLASS_COLORS[className]
            if classColor then
                nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            else
                nameText:SetTextColor(1, 1, 1, 1)
            end
        else
            nameText:SetTextColor(1, 1, 1, 1)
        end
        
        -- Add indicator for current player
        local displayName = user
        if info.isCurrentPlayer then
            displayName = user .. " (You)"
        end
        nameText:SetText(displayName)
        
        -- Version info
        local versionText = userEntry:CreateFontString(nil, "OVERLAY")
        versionText:SetFontObject("GameFontNormalSmall")
        versionText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
        versionText:SetText("Version: " .. (info.version or "Unknown"))
        versionText:SetTextColor(0.8, 0.8, 0.8, 1)
        
        -- Last seen info
        local lastSeenText = userEntry:CreateFontString(nil, "OVERLAY")
        lastSeenText:SetFontObject("GameFontNormalSmall")
        lastSeenText:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -2)
        
        if info.isCurrentPlayer then
            lastSeenText:SetText("Status: Online (Current Player)")
            lastSeenText:SetTextColor(0.0, 1.0, 0.0, 1) -- Green for current player
        elseif info.lastSeen then
            local timeDiff = GetServerTime() - info.lastSeen
            local timeStr = ""
            if timeDiff < 60 then
                timeStr = "Just now"
            elseif timeDiff < 3600 then
                timeStr = math.floor(timeDiff / 60) .. " minutes ago"
            else
                timeStr = math.floor(timeDiff / 3600) .. " hours ago"
            end
            lastSeenText:SetText("Last seen: " .. timeStr)
            lastSeenText:SetTextColor(0.7, 0.7, 0.7, 1)
        else
            lastSeenText:SetText("Last seen: Unknown")
            lastSeenText:SetTextColor(0.7, 0.7, 0.7, 1)
        end
        
        yOffset = yOffset - entryHeight - 5
    end
    
    -- Update content frame height
    local totalHeight = math.max(100, (#sortedUsers * (entryHeight + 5)) + 20)
    userListFrame.contentFrame:SetHeight(totalHeight)
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Addon user list refreshed -", userCount, "users displayed")
end

function AddonUserList:ShowUserList()
    if not userListFrame then
        self:CreateUserListWindow()
    end
    
    if userListFrame:IsVisible() then
        userListFrame:Hide()
        addon.Debug(addon.LOG_LEVEL.INFO, "Addon user list window hidden")
    else
        userListFrame:Show()
        addon.Debug(addon.LOG_LEVEL.INFO, "Addon user list window shown")
    end
end

function AddonUserList:ToggleUserList()
    self:ShowUserList()
end

-- Auto-initialize when AddonComm is available
local function InitializeWhenReady()
    if addon.AddonComm then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "AddonUserList initialized with AddonComm available")
        return
    end
    
    -- Wait for AddonComm to be available
    C_Timer.After(1, InitializeWhenReady)
end

-- Initialize after a short delay to ensure other modules are loaded
C_Timer.After(2, InitializeWhenReady)