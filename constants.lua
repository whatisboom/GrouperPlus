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

local CLASS_UTILITIES = {
    DEATHKNIGHT = { "COMBAT_REZ" },
    DRUID = { "COMBAT_REZ", "VERSATILITY" },
    EVOKER = { "BLOODLUST" },
    HUNTER = { "BLOODLUST" },
    MAGE = { "BLOODLUST", "INTELLECT" },
    MONK = { "MYSTIC_TOUCH" },
    PALADIN = { "COMBAT_REZ" },
    PRIEST = { "STAMINA" },
    SHAMAN = { "BLOODLUST", "SKYFURY" },
    WARLOCK = { "COMBAT_REZ" },
    WARRIOR = { "ATTACK_POWER" },
    DEMONHUNTER = { "CHAOS_BRAND" }
}

local UTILITY_INFO = {
    COMBAT_REZ = { priority = 1, name = "Combat Rez", color = {1, 0.8, 0} },
    BLOODLUST = { priority = 1, name = "Bloodlust", color = {1, 0.8, 0} },
    INTELLECT = { priority = 2, name = "Intellect", color = {0.5, 0.8, 1} },
    STAMINA = { priority = 2, name = "Stamina", color = {0.5, 0.8, 1} },
    ATTACK_POWER = { priority = 2, name = "Attack Power", color = {0.5, 0.8, 1} },
    VERSATILITY = { priority = 2, name = "Versatility", color = {0.5, 0.8, 1} },
    SKYFURY = { priority = 3, name = "Skyfury", color = {0.7, 0.7, 0.7} },
    MYSTIC_TOUCH = { priority = 3, name = "Mystic Touch", color = {0.7, 0.7, 0.7} },
    CHAOS_BRAND = { priority = 3, name = "Chaos Brand", color = {0.7, 0.7, 0.7} }
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
            acceptKeystoneData = true,
            respondToRequests = true,
            compression = true
        },
        versionWarning = {
            enabled = true,
            showPatchUpdates = false,
            autoCheckInterval = 300
        },
        dismissedVersions = {},
        sessions = {
            currentSessionId = nil,
            isSessionOwner = false,
            sessionSettings = {
                allowCollaboration = true,
                requireApproval = false,
                autoSync = true
            }
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
addon.CLASS_UTILITIES = CLASS_UTILITIES
addon.UTILITY_INFO = UTILITY_INFO
addon.defaults = defaults