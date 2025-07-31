local addonName, addon = ...
addon = addon or {}

local AceDB = LibStub("AceDB-3.0")

local defaults = {
    profile = {
        debugLevel = "INFO",
        minimap = {
            hide = false,
            minimapPos = 225,
        },
        mainFrame = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0
        },
        raiderIO = {
            enabled = true,
            showInTooltips = true
        }
    }
}

local db
local settings

local DEBUG_LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
    TRACE = 5
}

local LOG_LEVEL = {
    ERROR = "ERROR",
    WARN = "WARN",
    INFO = "INFO",
    DEBUG = "DEBUG",
    TRACE = "TRACE"
}

local function Debug(level, ...)
    if not settings then return end
    
    level = level or "DEBUG"
    level = string.upper(level)
    
    if not DEBUG_LEVELS[level] then
        level = "DEBUG"
    end
    
    local currentLevel = string.upper(settings.debugLevel)
    if not DEBUG_LEVELS[currentLevel] then
        currentLevel = "INFO"
    end
    
    if DEBUG_LEVELS[level] <= DEBUG_LEVELS[currentLevel] then
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
addon.LOG_LEVEL = LOG_LEVEL
addon.DEBUG_LEVELS = DEBUG_LEVELS

local LibDBIcon = LibStub("LibDBIcon-1.0")

local minimapLDB = {
    type = "launcher",
    text = "GrouperPlus",
    icon = "Interface\\Icons\\INV_Misc_GroupLooking",
    OnClick = function(self, button)
        if button == "LeftButton" then
            Debug(LOG_LEVEL.INFO, "Minimap icon clicked with left button")
            if addon.ToggleMainFrame then
                addon:ToggleMainFrame()
            else
                Debug(LOG_LEVEL.WARN, "MainFrame module not yet loaded")
            end
        elseif button == "RightButton" then
            if addon.dropdownFrame then
                ToggleDropDownMenu(1, nil, addon.dropdownFrame, self, 0, 0)
            else
                Debug(LOG_LEVEL.WARN, "Dropdown menu not yet initialized")
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
        Debug(LOG_LEVEL.INFO, "Minimap icon registered successfully")
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
            db = AceDB:New("GrouperDB", defaults, true)
            settings = db.profile
            
            -- Export to addon namespace
            addon.db = db
            addon.settings = settings
            addon.Debug = Debug
            addon.LOG_LEVEL = LOG_LEVEL
            
            Debug(LOG_LEVEL.INFO, "GrouperPlus addon loaded successfully!")
            Debug(LOG_LEVEL.DEBUG, "Settings initialized with debugLevel:", settings.debugLevel)
            InitializeMinimap()
        end
    elseif event == "PLAYER_LOGIN" then
        Debug(LOG_LEVEL.INFO, "Welcome to GrouperPlus!")
    end
end)

SLASH_GROUPER1 = "/grouper"
SlashCmdList["GROUPER"] = function(msg)
    local command = msg:lower()
    
    if command == "minimap" or command == "show" then
        settings.minimap.hide = false
        LibDBIcon:Show("GrouperPlus")
        Debug(LOG_LEVEL.INFO, "Minimap button shown")
    elseif command == "hide" then
        settings.minimap.hide = true
        LibDBIcon:Hide("GrouperPlus")
        Debug(LOG_LEVEL.INFO, "Minimap button hidden")
    elseif command == "main" or command == "frame" or command == "gui" then
        if addon.ShowMainFrame then
            addon:ShowMainFrame()
            Debug(LOG_LEVEL.INFO, "Main frame shown via slash command")
        else
            Debug(LOG_LEVEL.WARN, "MainFrame module not yet loaded")
        end
    elseif command == "toggle" then
        if addon.ToggleMainFrame then
            addon:ToggleMainFrame()
            Debug(LOG_LEVEL.INFO, "Main frame toggled via slash command")
        else
            Debug(LOG_LEVEL.WARN, "MainFrame module not yet loaded")
        end
    elseif command == "test" or command == "raiderio" then
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:TestPlayer()
            Debug(LOG_LEVEL.INFO, "RaiderIO test completed - check debug output")
        else
            Debug(LOG_LEVEL.WARN, "RaiderIO integration module not yet loaded")
        end
    else
        Debug(LOG_LEVEL.INFO, "GrouperPlus commands:")
        Debug(LOG_LEVEL.INFO, "/grouper show - Show minimap button")
        Debug(LOG_LEVEL.INFO, "/grouper hide - Hide minimap button")
        Debug(LOG_LEVEL.INFO, "/grouper main - Show main frame")
        Debug(LOG_LEVEL.INFO, "/grouper toggle - Toggle main frame")
        Debug(LOG_LEVEL.INFO, "/grouper test - Test RaiderIO integration")
    end
end