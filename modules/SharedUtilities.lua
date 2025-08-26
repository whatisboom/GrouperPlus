local addonName, addon = ...

local SharedUtilities = {}
addon.SharedUtilities = SharedUtilities

SharedUtilities.LibraryEmbedding = {}
SharedUtilities.EventMixin = {}

function SharedUtilities:MixinEventHandling(target)
    for k, v in pairs(SharedUtilities.EventMixin) do
        target[k] = v
    end
end

function SharedUtilities.LibraryEmbedding:EmbedRequired(target, requiredLibraries)
    local LibraryManager = addon.LibraryManager
    if not LibraryManager then
        if target.Debug then
            target.Debug("ERROR", "LibraryManager not available")
        end
        return false
    end
    
    local success = true
    for _, libName in ipairs(requiredLibraries) do
        if not LibraryManager:SafeEmbed(target, libName) then
            if target.Debug then
                target.Debug("ERROR", "Failed to embed " .. libName)
            end
            success = false
        end
    end
    
    return success
end

function SharedUtilities:GetTableSize(tbl)
    local count = 0
    if tbl then
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
end

function SharedUtilities:IsPlayerNameNormalized(playerName)
    if not playerName or type(playerName) ~= "string" then
        return false
    end
    return playerName:find("-") ~= nil
end

function SharedUtilities:TableToString(tbl, depth)
    depth = depth or 0
    if depth > 3 then
        return "..."
    end
    
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    
    local indent = string.rep("  ", depth)
    local result = "{\n"
    
    for k, v in pairs(tbl) do
        result = result .. indent .. "  " .. tostring(k) .. " = "
        if type(v) == "table" then
            result = result .. SharedUtilities:TableToString(v, depth + 1)
        else
            result = result .. tostring(v)
        end
        result = result .. ",\n"
    end
    
    result = result .. indent .. "}"
    return result
end

function SharedUtilities.EventMixin:FireEvent(eventName, ...)
    if not self.SendMessage then
        if self.Debug then
            self.Debug("WARN", "Cannot fire event - AceEvent not available:", eventName)
        end
        return
    end
    if self.Debug then
        self.Debug("TRACE", "Firing event:", eventName)
    end
    self:SendMessage("GROUPERPLUS_" .. eventName, ...)
end

return SharedUtilities