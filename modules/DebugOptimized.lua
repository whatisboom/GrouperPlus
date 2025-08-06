local addonName, addon = ...

local DebugOptimized = addon.ModuleFactory:CreateModule("DebugOptimized", {})

local LOG_LEVEL = addon.LOG_LEVEL
local currentLevel = LOG_LEVEL.INFO

local levelPriority = {
    [LOG_LEVEL.ERROR] = 1,
    [LOG_LEVEL.WARN] = 2,
    [LOG_LEVEL.INFO] = 3,
    [LOG_LEVEL.DEBUG] = 4,
    [LOG_LEVEL.TRACE] = 5
}

local levelColors = {
    [LOG_LEVEL.ERROR] = "|cFFFF0000",
    [LOG_LEVEL.WARN] = "|cFFFFAA00",
    [LOG_LEVEL.INFO] = "|cFF00FF00",
    [LOG_LEVEL.DEBUG] = "|cFFFFFF00",
    [LOG_LEVEL.TRACE] = "|cFF888888"
}

local function shouldLog(level)
    local requestedPriority = levelPriority[level] or 5
    local currentPriority = levelPriority[currentLevel] or 3
    return requestedPriority <= currentPriority
end

local function formatMessage(...)
    local args = {...}
    local formatted = {}
    
    for i = 1, select("#", ...) do
        local arg = args[i]
        if arg == nil then
            formatted[i] = "nil"
        elseif type(arg) == "table" then
            formatted[i] = tostring(arg)
        else
            formatted[i] = tostring(arg)
        end
    end
    
    return table.concat(formatted, " ")
end

function DebugOptimized:Log(level, ...)
    if not shouldLog(level) then
        return
    end
    
    local message = formatMessage(...)
    local color = levelColors[level] or "|cFFFFFFFF"
    
    print("|cFFFFD700[GrouperPlus:" .. level .. "]|r " .. color .. message .. "|r")
end

function DebugOptimized:SetLevel(level)
    if levelPriority[level] then
        currentLevel = level
        if addon.db and addon.db.profile then
            addon.db.profile.debugLevel = level
        end
    end
end

function DebugOptimized:GetLevel()
    return currentLevel
end

local function CreateLevelFunction(level)
    return function(...)
        if shouldLog(level) then
            DebugOptimized:Log(level, ...)
        end
    end
end

DebugOptimized.Error = CreateLevelFunction(LOG_LEVEL.ERROR)
DebugOptimized.Warn = CreateLevelFunction(LOG_LEVEL.WARN)
DebugOptimized.Info = CreateLevelFunction(LOG_LEVEL.INFO)
DebugOptimized.Debug = CreateLevelFunction(LOG_LEVEL.DEBUG)
DebugOptimized.Trace = CreateLevelFunction(LOG_LEVEL.TRACE)

local function OptimizedDebug(level, ...)
    if not shouldLog(level) then
        return
    end
    
    DebugOptimized:Log(level, ...)
end

OptimizedDebug.SetLevel = function(level)
    DebugOptimized:SetLevel(level)
end

OptimizedDebug.GetLevel = function()
    return DebugOptimized:GetLevel()
end

OptimizedDebug.shouldLog = shouldLog

addon.DebugOptimized = OptimizedDebug
addon.DebugModule = DebugOptimized

DebugOptimized.Initialize = function(self)
    if addon.db and addon.db.profile and addon.db.profile.debugLevel then
        currentLevel = addon.db.profile.debugLevel
    end
    
    addon.Debug = OptimizedDebug
    
    addon.Debug(LOG_LEVEL.INFO, "DebugOptimized module initialized with level:", currentLevel)
end

return DebugOptimized