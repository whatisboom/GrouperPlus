local addonName, addon = ...

local DebugMixin = {}

function DebugMixin:InitDebug(moduleName)
    self.moduleName = moduleName or "Unknown"
    self.debugCache = {}
    
    self.Debug = function(level, ...)
        if not addon.settings then return end
        
        level = level or "DEBUG"
        level = string.upper(level)
        
        if not addon.DEBUG_LEVELS[level] then
            level = "DEBUG"
        end
        
        local currentLevel = string.upper(addon.settings.debugLevel)
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
            
            print("|cFFFFD700[GrouperPlus:" .. self.moduleName .. ":" .. level .. "]|r |cFF87CEEB" .. message .. "|r")
        end
    end
    
    self.DebugTable = function(level, tableName, tbl, depth)
        if not addon.settings or not tbl then return end
        
        depth = depth or 0
        local maxDepth = 3
        
        if depth > maxDepth then
            self.Debug(level, tableName, "... (max depth reached)")
            return
        end
        
        local indent = string.rep("  ", depth)
        
        if depth == 0 then
            self.Debug(level, tableName .. " = {")
        end
        
        for k, v in pairs(tbl) do
            local key = tostring(k)
            if type(v) == "table" then
                self.Debug(level, indent .. "  " .. key .. " = {")
                self.DebugTable(level, "", v, depth + 1)
                self.Debug(level, indent .. "  }")
            else
                self.Debug(level, indent .. "  " .. key .. " = " .. tostring(v))
            end
        end
        
        if depth == 0 then
            self.Debug(level, "}")
        end
    end
    
    self.DebugOnce = function(level, key, ...)
        if not self.debugCache[key] then
            -- Implement simple cache size limit to prevent memory leaks
            local cacheSize = 0
            for _ in pairs(self.debugCache) do
                cacheSize = cacheSize + 1
            end
            
            -- If cache is getting too large, clear oldest entries (simple approach)
            if cacheSize >= 100 then
                local cleared = 0
                for k, _ in pairs(self.debugCache) do
                    self.debugCache[k] = nil
                    cleared = cleared + 1
                    if cleared >= 50 then -- Clear half the cache
                        break
                    end
                end
            end
            
            self.debugCache[key] = true
            self.Debug(level, ...)
        end
    end
    
    self.ClearDebugCache = function()
        table.wipe(self.debugCache)
    end
    
    for levelName, _ in pairs(addon.DEBUG_LEVELS or {}) do
        self[levelName] = levelName
    end
end

function DebugMixin:SetModuleName(name)
    self.moduleName = name
end

-- New injection method to replace manual copying
function DebugMixin:InjectInto(target, moduleName)
    for k, v in pairs(self) do
        if k ~= "InjectInto" then  -- Don't inject self-reference
            target[k] = v
        end
    end
    target:InitDebug(moduleName)
end

-- Add lazy evaluation helper
function DebugMixin:ShouldLog(level)
    if not addon.settings then return false end
    
    level = level or "DEBUG"
    level = string.upper(level)
    
    if not addon.DEBUG_LEVELS[level] then
        level = "DEBUG"
    end
    
    local currentLevel = string.upper(addon.settings.debugLevel)
    if not addon.DEBUG_LEVELS[currentLevel] then
        currentLevel = "INFO"
    end
    
    return addon.DEBUG_LEVELS[level] <= addon.DEBUG_LEVELS[currentLevel]
end

addon.DebugMixin = DebugMixin