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

-- Damage type classification for DPS specializations
-- PHYSICAL = primarily physical damage, benefits most from Mystic Touch
-- MAGIC = primarily magic damage, benefits most from Chaos Brand
-- HYBRID = significant mix of both, benefits from both debuffs
local SPEC_DAMAGE_TYPE = {
    -- Death Knight
    [251] = "HYBRID",   -- Frost (physical auto attacks + magic spells)
    [252] = "HYBRID",   -- Unholy (physical diseases + magic spells)
    
    -- Demon Hunter
    [581] = "PHYSICAL", -- Havoc (mostly physical with some chaos magic)
    
    -- Druid
    [102] = "MAGIC",    -- Balance (pure magic damage)
    [103] = "PHYSICAL", -- Feral (pure physical damage)
    
    -- Evoker
    [1467] = "MAGIC",   -- Devastation (pure magic damage)
    [1473] = "MAGIC",   -- Augmentation (pure magic damage)
    
    -- Hunter
    [253] = "PHYSICAL", -- Beast Mastery (physical shots + pet damage)
    [254] = "PHYSICAL", -- Marksmanship (physical shots)
    [255] = "HYBRID",   -- Survival (physical melee + magic bombs/traps)
    
    -- Mage
    [62] = "MAGIC",     -- Arcane (pure magic damage)
    [63] = "MAGIC",     -- Fire (pure magic damage)
    [64] = "MAGIC",     -- Frost (pure magic damage)
    
    -- Monk
    [269] = "PHYSICAL", -- Windwalker (pure physical damage)
    
    -- Paladin
    [70] = "HYBRID",    -- Retribution (physical melee + holy magic)
    
    -- Priest
    [258] = "MAGIC",    -- Shadow (pure magic damage)
    
    -- Rogue
    [259] = "PHYSICAL", -- Assassination (pure physical + poisons)
    [260] = "PHYSICAL", -- Outlaw (pure physical damage)
    [261] = "PHYSICAL", -- Subtlety (pure physical damage)
    
    -- Shaman
    [262] = "MAGIC",    -- Elemental (pure magic damage)
    [263] = "HYBRID",   -- Enhancement (physical melee + magic spells)
    
    -- Warlock
    [265] = "MAGIC",    -- Affliction (pure magic damage)
    [266] = "MAGIC",    -- Demonology (pure magic damage)
    [267] = "MAGIC",    -- Destruction (pure magic damage)
    
    -- Warrior
    [71] = "PHYSICAL",  -- Arms (pure physical damage)
    [72] = "PHYSICAL",  -- Fury (pure physical damage)
}

-- Class-based damage type fallback for when spec detection fails
local CLASS_DAMAGE_TYPE = {
    DEATHKNIGHT = "HYBRID",     -- Most DK specs are hybrid
    DEMONHUNTER = "PHYSICAL",   -- Only DPS spec is mostly physical
    DRUID = "MIXED",            -- Can be pure magic (Balance) or pure physical (Feral)
    EVOKER = "MAGIC",           -- All DPS specs are pure magic
    HUNTER = "PHYSICAL",        -- Most specs are physical (BM/MM), only SV is hybrid
    MAGE = "MAGIC",             -- All specs are pure magic
    MONK = "PHYSICAL",          -- Windwalker is pure physical
    PALADIN = "HYBRID",         -- Retribution is hybrid
    PRIEST = "MAGIC",           -- Shadow is pure magic
    ROGUE = "PHYSICAL",         -- All specs are pure physical
    SHAMAN = "MIXED",           -- Can be pure magic (Elemental) or hybrid (Enhancement)
    WARLOCK = "MAGIC",          -- All specs are pure magic
    WARRIOR = "PHYSICAL"        -- All specs are pure physical
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
            channels = {
                GUILD = true,
                PARTY = true,
                RAID = true
            },
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
        },
        debug = {
            enabled = false,
            ignoreMaxLevel = false
        },
        sessionNotifications = {
            enabled = true,
            style = "POPUP_AND_CHAT",
            responseTimeout = 60,
            snoozeDuration = 300,
            channels = {
                GUILD = true,
                PARTY = false,
                RAID = false
            },
            messageTemplate = "GrouperPlus session starting! Join through your addon or whisper me '1' to join the session"
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
addon.SPEC_DAMAGE_TYPE = SPEC_DAMAGE_TYPE
addon.CLASS_DAMAGE_TYPE = CLASS_DAMAGE_TYPE
addon.defaults = defaults