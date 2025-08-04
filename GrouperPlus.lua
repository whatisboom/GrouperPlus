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

-- Export to addon namespace for use in modules
addon.Debug = Debug

local LibDBIcon = LibStub("LibDBIcon-1.0")

local minimapLDB = {
    type = "launcher",
    text = "GrouperPlus",
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
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
            print("GrouperPlus: SLASH COMMAND - Triggering auto-formation")
            addon:AutoFormGroups()
        else
            Debug(addon.LOG_LEVEL.WARN, "AutoFormGroups function not yet loaded")
        end
    elseif command == "button" or command == "check" then
        local button = _G["GrouperPlusAutoFormButton"]
        if button then
            print("GrouperPlus: Button found! Enabled:", button:IsEnabled(), "Shown:", button:IsShown(), "Visible:", button:IsVisible())
            print("GrouperPlus: Manually triggering button click...")
            button:Click()
        else
            print("GrouperPlus: Button not found! Frame might not be created yet.")
        end
    elseif command == "comm" or command == "communication" then
        if addon.AddonComm then
            local connectedUsers = addon.AddonComm:GetConnectedUsers()
            local count = 0
            for user, info in pairs(connectedUsers) do
                count = count + 1
                print("GrouperPlus: Connected user:", user, "version:", info.version)
            end
            if count == 0 then
                print("GrouperPlus: No other GrouperPlus users detected")
            else
                print("GrouperPlus: Found", count, "connected users")
            end
        else
            print("GrouperPlus: Communication module not loaded")
        end
    elseif command == "version" or command == "broadcast" then
        if addon.AddonComm then
            addon.AddonComm:BroadcastVersionCheck()
            print("GrouperPlus: Version check broadcast sent to guild")
        else
            print("GrouperPlus: Communication module not loaded")
        end
    elseif command == "share" then
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:ShareGuildMemberData()
            print("GrouperPlus: Attempted to share RaiderIO data for guild members")
        else
            print("GrouperPlus: RaiderIO integration not loaded")
        end
    elseif command == "role" then
        if addon.AddonComm then
            addon.AddonComm:SharePlayerRole(true)
            print("GrouperPlus: Forced role share sent to guild")
        else
            print("GrouperPlus: Communication module not loaded")
        end
    elseif command == "checkrole" then
        if addon.AddonComm then
            addon.AddonComm:CheckForRoleChange()
            print("GrouperPlus: Checked for role changes")
        else
            print("GrouperPlus: Communication module not loaded")
        end
    elseif command == "debugspec" or command == "spec" then
        local playerName = UnitName("player")
        local currentSpec = GetSpecialization()
        local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "Unknown"
        local role = currentSpec and GetSpecializationRole(currentSpec) or "Unknown"
        
        print("GrouperPlus Debug:")
        print("  Player Name: " .. (playerName or "nil"))
        print("  Spec ID: " .. (currentSpec or "nil"))
        print("  Spec Name: " .. (specName or "nil")) 
        print("  Role: " .. (role or "nil"))
        
        if addon.AutoFormation then
            local detectedRole = addon.AutoFormation:GetPlayerRole("player")
            print("  AutoFormation Role: " .. (detectedRole or "nil"))
        end
    elseif command == "refresh" or command == "update" then
        if addon.UpdatePlayerRoleInUI then
            addon:UpdatePlayerRoleInUI()
            print("GrouperPlus: Forced UI refresh")
        else
            print("GrouperPlus: UI refresh function not available")
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
    end
end