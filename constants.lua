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

addon.DEBUG_LEVELS = DEBUG_LEVELS
addon.LOG_LEVEL = LOG_LEVEL
addon.defaults = defaults