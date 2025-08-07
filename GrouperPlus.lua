local addonName, addon = ...
addon = addon or {}

local AceDB = LibStub("AceDB-3.0")

local db
local settings

local function Debug(level, ...)
    if not settings then return end
    
    level = level or "DEBUG"
    level = string.upper(level)
    
    if not addon.DEBUG_LEVELS[level] then
        level = "DEBUG"
    end
    
    local currentLevel = string.upper(settings.debugLevel)
    if not addon.DEBUG_LEVELS[currentLevel] then
        currentLevel = "INFO"
    end
    
    if addon.DEBUG_LEVELS[level] <= addon.DEBUG_LEVELS[currentLevel] then
        local args = {...}
        local message = ""
        
        for i, arg in ipairs(args) do
            if i > 1 then
                message = message .. " "
            end
            message = message .. tostring(arg)
        end
        
        print("|cFFFFD700[GrouperPlus:" .. level .. "]|r |cFF87CEEB" .. message .. "|r")
    end
end

-- Print function for user messages
function addon:Print(...)
    local args = {...}
    local message = ""
    
    for i, arg in ipairs(args) do
        if i > 1 then
            message = message .. " "
        end
        message = message .. tostring(arg)
    end
    
    print("|cFFFFD700[GrouperPlus]|r " .. message)
end

-- Export to addon namespace for use in modules
addon.Debug = Debug

local LibDBIcon = LibStub("LibDBIcon-1.0")

local minimapLDB = {
    type = "launcher",
    text = "GrouperPlus",
    icon = "Interface\\AddOns\\GrouperPlus\\textures\\icon",
    OnClick = function(self, button)
        if button == "LeftButton" then
            Debug(addon.LOG_LEVEL.INFO, "Minimap icon clicked with left button")
            if addon.ToggleMainFrame then
                addon:ToggleMainFrame()
            else
                Debug(addon.LOG_LEVEL.WARN, "MainFrame module not yet loaded")
            end
        elseif button == "RightButton" then
            if addon.dropdownFrame then
                ToggleDropDownMenu(1, nil, addon.dropdownFrame, self, 0, 0)
            else
                Debug(addon.LOG_LEVEL.WARN, "Dropdown menu not yet initialized")
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("GrouperPlus")
        tooltip:AddLine("|cFFFFFFFFLeft-click|r to toggle main frame", 1, 1, 1)
        tooltip:AddLine("|cFFFFFFFFRight-click|r for options", 1, 1, 1)
        tooltip:AddLine("|cFF00FF00Drag|r to move this button", 0, 1, 0)
    end,
}

local function InitializeMinimap()
    if LibDBIcon and not LibDBIcon:IsRegistered("GrouperPlus") and settings then
        LibDBIcon:Register("GrouperPlus", minimapLDB, settings.minimap)
        Debug(addon.LOG_LEVEL.INFO, "Minimap icon registered successfully")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            GrouperDB = GrouperDB or {}
            db = AceDB:New("GrouperDB", addon.defaults, true)
            settings = db.profile
            
            -- Export to addon namespace
            addon.db = db
            addon.settings = settings
            addon.Debug = Debug
            
            Debug(addon.LOG_LEVEL.INFO, "GrouperPlus addon loaded successfully!")
            Debug(addon.LOG_LEVEL.DEBUG, "Settings initialized with debugLevel:", settings.debugLevel)
            InitializeMinimap()
            
            -- Initialize Keystone module
            if addon.Keystone then
                C_Timer.After(2, function()
                    addon.Keystone:Initialize()
                end)
            end
            
            -- Initialize SessionManager module
            if addon.SessionManager then
                C_Timer.After(2, function()
                    addon.SessionManager:Initialize()
                end)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        Debug(addon.LOG_LEVEL.INFO, "Welcome to GrouperPlus!")
    end
end)

SLASH_GROUPER1 = "/grouper"
SlashCmdList["GROUPER"] = function(msg)
    local command = msg:lower()
    
    if command == "minimap" or command == "show" then
        settings.minimap.hide = false
        LibDBIcon:Show("GrouperPlus")
        Debug(addon.LOG_LEVEL.INFO, "Minimap button shown")
    elseif command == "hide" then
        settings.minimap.hide = true
        LibDBIcon:Hide("GrouperPlus")
        Debug(addon.LOG_LEVEL.INFO, "Minimap button hidden")
    elseif command == "main" or command == "frame" or command == "gui" then
        if addon.ShowMainFrame then
            addon:ShowMainFrame()
            Debug(addon.LOG_LEVEL.INFO, "Main frame shown via slash command")
        else
            Debug(addon.LOG_LEVEL.WARN, "MainFrame module not yet loaded")
        end
    elseif command == "toggle" then
        if addon.ToggleMainFrame then
            addon:ToggleMainFrame()
            Debug(addon.LOG_LEVEL.INFO, "Main frame toggled via slash command")
        else
            Debug(addon.LOG_LEVEL.WARN, "MainFrame module not yet loaded")
        end
    elseif command == "test" or command == "raiderio" then
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:TestPlayer()
            Debug(addon.LOG_LEVEL.INFO, "RaiderIO test completed - check debug output")
        else
            Debug(addon.LOG_LEVEL.WARN, "RaiderIO integration module not yet loaded")
        end
    elseif command == "autoform" or command == "auto" then
        if addon.AutoFormGroups then
            Debug(addon.LOG_LEVEL.INFO, "SLASH COMMAND - Triggering auto-formation")
            addon:AutoFormGroups()
        else
            Debug(addon.LOG_LEVEL.WARN, "AutoFormGroups function not yet loaded")
        end
    elseif command == "button" or command == "check" then
        local button = _G["GrouperPlusAutoFormButton"]
        if button then
            Debug(addon.LOG_LEVEL.DEBUG, "Button found! Enabled:", button:IsEnabled(), "Shown:", button:IsShown(), "Visible:", button:IsVisible())
            Debug(addon.LOG_LEVEL.DEBUG, "Manually triggering button click...")
            button:Click()
        else
            Debug(addon.LOG_LEVEL.WARN, "Button not found! Frame might not be created yet.")
        end
    elseif command == "session" or command == "sess" then
        if addon.SessionManager then
            local sessionInfo = addon.SessionManager:GetSessionInfo()
            if sessionInfo then
                Debug(addon.LOG_LEVEL.INFO, "Session ID:", sessionInfo.sessionId)
                Debug(addon.LOG_LEVEL.INFO, "Session Owner:", sessionInfo.owner)
                Debug(addon.LOG_LEVEL.INFO, "Is Owner:", sessionInfo.isOwner)
                Debug(addon.LOG_LEVEL.INFO, "Is Finalized:", sessionInfo.isFinalized)
                Debug(addon.LOG_LEVEL.INFO, "Participants:", sessionInfo.participantCount)
            else
                Debug(addon.LOG_LEVEL.INFO, "No active session")
            end
        else
            Debug(addon.LOG_LEVEL.WARN, "SessionManager not yet loaded")
        end
    elseif command == "refresh" or command == "perms" then
        if addon.UpdateEditPermissions then
            addon:UpdateEditPermissions()
            Debug(addon.LOG_LEVEL.INFO, "Manually refreshed edit permissions")
        else
            Debug(addon.LOG_LEVEL.WARN, "UpdateEditPermissions function not available")
        end
    elseif command == "comm" or command == "communication" then
        if addon.AddonComm then
            local connectedUsers = addon.AddonComm:GetConnectedUsers()
            local count = 0
            for user, info in pairs(connectedUsers) do
                count = count + 1
                Debug(addon.LOG_LEVEL.INFO, "Connected user:", user, "version:", info.version)
            end
            if count == 0 then
                Debug(addon.LOG_LEVEL.INFO, "No other GrouperPlus users detected")
            else
                Debug(addon.LOG_LEVEL.INFO, "Found", count, "connected users")
            end
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "version" or command == "broadcast" then
        if addon.AddonComm then
            addon.AddonComm:BroadcastVersionCheck()
            Debug(addon.LOG_LEVEL.INFO, "Version check broadcast sent to guild")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "share" then
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:ShareGuildMemberData()
            Debug(addon.LOG_LEVEL.INFO, "Attempted to share RaiderIO data for guild members")
        else
            Debug(addon.LOG_LEVEL.WARN, "RaiderIO integration not loaded")
        end
    elseif command == "role" then
        if addon.AddonComm then
            addon.AddonComm:SharePlayerRole(true)
            Debug(addon.LOG_LEVEL.INFO, "Forced role share sent to guild")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "checkrole" then
        if addon.AddonComm then
            addon.AddonComm:CheckForRoleChange()
            Debug(addon.LOG_LEVEL.INFO, "Checked for role changes")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "debugspec" or command == "spec" then
        local playerName = UnitName("player")
        local currentSpec = GetSpecialization()
        local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "Unknown"
        local role = currentSpec and GetSpecializationRole(currentSpec) or "Unknown"
        
        Debug(addon.LOG_LEVEL.DEBUG, "Player Debug Info:")
        Debug(addon.LOG_LEVEL.DEBUG, "  Player Name:", (playerName or "nil"))
        Debug(addon.LOG_LEVEL.DEBUG, "  Spec ID:", (currentSpec or "nil"))
        Debug(addon.LOG_LEVEL.DEBUG, "  Spec Name:", (specName or "nil"))
        Debug(addon.LOG_LEVEL.DEBUG, "  Role:", (role or "nil"))
        
        if addon.AutoFormation then
            local detectedRole = addon.AutoFormation:GetPlayerRole("player")
            Debug(addon.LOG_LEVEL.DEBUG, "  AutoFormation Role:", (detectedRole or "nil"))
        end
    elseif command == "refresh" or command == "update" then
        if addon.UpdatePlayerRoleInUI then
            addon:UpdatePlayerRoleInUI()
            Debug(addon.LOG_LEVEL.INFO, "Forced UI refresh")
        else
            Debug(addon.LOG_LEVEL.WARN, "UI refresh function not available")
        end
    elseif command == "users" or command == "userlist" or command == "list" then
        if addon.AddonUserList then
            addon.AddonUserList:ToggleUserList()
            Debug(addon.LOG_LEVEL.INFO, "Addon user list toggled")
        else
            Debug(addon.LOG_LEVEL.WARN, "AddonUserList module not loaded")
        end
    elseif command == "versioncheck" or command == "checkversion" then
        if addon.VersionWarning then
            addon.VersionWarning:CheckForNewerVersions()
            Debug(addon.LOG_LEVEL.INFO, "Manual version check triggered")
        else
            Debug(addon.LOG_LEVEL.WARN, "VersionWarning module not loaded")
        end
    elseif command == "versiontest" then
        if addon.VersionWarning then
            -- Test with fake newer version
            addon.VersionWarning:ShowVersionWarning("0.7.0", {"TestUser"})
            Debug(addon.LOG_LEVEL.INFO, "Test version warning shown")
        else
            Debug(addon.LOG_LEVEL.WARN, "VersionWarning module not loaded")
        end
    elseif command == "versiondismiss" then
        if addon.VersionWarning then
            addon.VersionWarning:DismissWarning()
            Debug(addon.LOG_LEVEL.INFO, "Version warning dismissed")
        else
            Debug(addon.LOG_LEVEL.WARN, "VersionWarning module not loaded")
        end
    elseif command == "keystone" or command == "key" then
        if addon.Keystone then
            local info = addon.Keystone:GetKeystoneInfo()
            local keystoneString = addon.Keystone:GetKeystoneString()
            Debug(addon.LOG_LEVEL.INFO, "Current keystone:", keystoneString)
            
            local received = addon.Keystone:GetReceivedKeystones()
            local count = 0
            for player, data in pairs(received) do
                count = count + 1
                local playerKeystone = "No Keystone"
                if data.mapID and data.level then
                    playerKeystone = string.format("%s +%d", data.dungeonName or "Unknown", data.level)
                end
                Debug(addon.LOG_LEVEL.INFO, "  " .. player .. ":", playerKeystone)
            end
            
            if count == 0 then
                Debug(addon.LOG_LEVEL.INFO, "No keystone data received from other players")
            end
            
            addon.Keystone:ForceUpdate()
        else
            Debug(addon.LOG_LEVEL.WARN, "Keystone module not loaded")
        end
    else
        Debug(addon.LOG_LEVEL.INFO, "GrouperPlus commands:")
        Debug(addon.LOG_LEVEL.INFO, "/grouper show - Show minimap button")
        Debug(addon.LOG_LEVEL.INFO, "/grouper hide - Hide minimap button")
        Debug(addon.LOG_LEVEL.INFO, "/grouper main - Show main frame")
        Debug(addon.LOG_LEVEL.INFO, "/grouper toggle - Toggle main frame")
        Debug(addon.LOG_LEVEL.INFO, "/grouper test - Test RaiderIO integration")
        Debug(addon.LOG_LEVEL.INFO, "/grouper comm - Check connected users")
        Debug(addon.LOG_LEVEL.INFO, "/grouper broadcast - Send version check")
        Debug(addon.LOG_LEVEL.INFO, "/grouper share - Share RaiderIO data")
        Debug(addon.LOG_LEVEL.INFO, "/grouper role - Force share current role")
        Debug(addon.LOG_LEVEL.INFO, "/grouper checkrole - Check for role changes")
        Debug(addon.LOG_LEVEL.INFO, "/grouper spec - Debug player specialization info")
        Debug(addon.LOG_LEVEL.INFO, "/grouper refresh - Force UI refresh")
        Debug(addon.LOG_LEVEL.INFO, "/grouper users - Show addon user list window")
        Debug(addon.LOG_LEVEL.INFO, "/grouper versioncheck - Check for newer versions")
        Debug(addon.LOG_LEVEL.INFO, "/grouper versiontest - Test version warning display")
        Debug(addon.LOG_LEVEL.INFO, "/grouper versiondismiss - Dismiss current version warning")
        Debug(addon.LOG_LEVEL.INFO, "/grouper keystone - Show current keystone and received keystones")
    end
end