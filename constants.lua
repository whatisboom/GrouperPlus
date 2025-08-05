local addonName, addon = ...

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

local ROLE_COLORS = {
    TANK = {r = 0.2, g = 0.6, b = 1.0},     -- Blue
    HEALER = {r = 0.0, g = 1.0, b = 0.0},   -- Green
    DPS = {r = 1.0, g = 0.2, b = 0.2},      -- Red
    UNKNOWN = {r = 0.7, g = 0.7, b = 0.7}   -- Gray
}

local ROLE_DISPLAY = {
    TANK = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t",
    HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t",
    DPS = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t",
    UNKNOWN = "[?]"
}

local ITEM_QUALITY_COLORS = {
    POOR = {r = 0.62, g = 0.62, b = 0.62},        -- Gray (Poor)
    COMMON = {r = 1.0, g = 1.0, b = 1.0},         -- White (Common)
    UNCOMMON = {r = 0.12, g = 1.0, b = 0.0},      -- Green (Uncommon)
    RARE = {r = 0.0, g = 0.44, b = 0.87},         -- Blue (Rare)
    EPIC = {r = 0.64, g = 0.21, b = 0.93},        -- Purple (Epic)
    LEGENDARY = {r = 1.0, g = 0.5, b = 0.0},      -- Orange (Legendary)
    ARTIFACT = {r = 0.9, g = 0.8, b = 0.5}        -- Gold (Artifact)
}

local defaults = {
    profile = {
        debugLevel = "WARN",
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
        },
        communication = {
            enabled = true,
            acceptGroupSync = true,
            acceptPlayerData = true,
            acceptRaiderIOData = true,
            respondToRequests = true,
            compression = true
        }
    }
}

-- Helper function to get role display info
function addon:GetRoleDisplay(role)
    local displayText = ROLE_DISPLAY[role] or ROLE_DISPLAY.UNKNOWN
    local color = ROLE_COLORS[role] or ROLE_COLORS.UNKNOWN
    return displayText, color
end

addon.DEBUG_LEVELS = DEBUG_LEVELS
addon.LOG_LEVEL = LOG_LEVEL
addon.ROLE_COLORS = ROLE_COLORS
addon.ROLE_DISPLAY = ROLE_DISPLAY
addon.ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
addon.defaults = defaults