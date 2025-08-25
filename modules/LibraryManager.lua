local addonName, addon = ...

local LibraryManager = {}
addon.LibraryManager = LibraryManager

local libraryCache = {}
local requiredLibraries = {
    "AceDB-3.0",
    "AceComm-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0",
    "AceSerializer-3.0",
    "LibDBIcon-1.0",
    "CallbackHandler-1.0"
}

function LibraryManager:Initialize()
    for _, libName in ipairs(requiredLibraries) do
        self:LoadLibrary(libName)
    end
end

function LibraryManager:LoadLibrary(libraryName, required)
    if libraryCache[libraryName] then
        return libraryCache[libraryName]
    end
    
    if not LibStub then
        local errorMsg = "LibraryManager: LibStub not available - cannot load " .. libraryName
        if addon.Debug then
            addon.Debug("ERROR", errorMsg)
        else
            error(errorMsg)
        end
        return nil
    end
    
    local success, lib = pcall(LibStub, libraryName, not required)
    if success and lib then
        libraryCache[libraryName] = lib
        if addon.Debug then
            addon.Debug("DEBUG", "LibraryManager: Successfully loaded library", libraryName)
        end
        return lib
    elseif required ~= false then
        local errorMsg = "LibraryManager: Required library not found: " .. libraryName
        if addon.Debug then
            addon.Debug("ERROR", errorMsg)
        else
            error(errorMsg)
        end
        return nil
    end
    
    if addon.Debug then
        addon.Debug("WARN", "LibraryManager: Optional library not found:", libraryName)
    end
    return nil
end

function LibraryManager:GetLibrary(libraryName)
    return libraryCache[libraryName] or self:LoadLibrary(libraryName, false)
end

function LibraryManager:RequireLibrary(libraryName)
    local lib = self:GetLibrary(libraryName)
    if not lib then
        error("LibraryManager: Required library not available: " .. libraryName)
    end
    return lib
end

function LibraryManager:IsLibraryLoaded(libraryName)
    return libraryCache[libraryName] ~= nil
end

function LibraryManager:GetLoadedLibraries()
    local loaded = {}
    for name, _ in pairs(libraryCache) do
        table.insert(loaded, name)
    end
    return loaded
end

function LibraryManager:CheckDependencies()
    local missing = {}
    for _, libName in ipairs(requiredLibraries) do
        if not self:IsLibraryLoaded(libName) then
            table.insert(missing, libName)
        end
    end
    
    if #missing > 0 then
        local missingList = table.concat(missing, ", ")
        if addon.Debug then
            addon.Debug("ERROR", "LibraryManager: Missing required libraries:", missingList)
        end
        return false, missingList
    end
    
    return true
end

function LibraryManager:GetAceDB()
    return self:GetLibrary("AceDB-3.0")
end

function LibraryManager:GetLibDBIcon()
    return self:GetLibrary("LibDBIcon-1.0")
end

function LibraryManager:GetCallbackHandler()
    return self:GetLibrary("CallbackHandler-1.0")
end

function LibraryManager:GetAceComm()
    return self:GetLibrary("AceComm-3.0")
end

function LibraryManager:GetAceEvent()
    return self:GetLibrary("AceEvent-3.0")
end

function LibraryManager:GetAceTimer()
    return self:GetLibrary("AceTimer-3.0")
end

function LibraryManager:GetAceSerializer()
    return self:GetLibrary("AceSerializer-3.0")
end

function LibraryManager:ValidateEmbedding(target, libraryName)
    local lib = self:GetLibrary(libraryName)
    if not lib then
        if addon.Debug then
            addon.Debug("ERROR", "LibraryManager: Cannot embed missing library:", libraryName)
        end
        return false
    end
    
    if not lib.Embed then
        if addon.Debug then
            addon.Debug("ERROR", "LibraryManager: Library does not support embedding:", libraryName)
        end
        return false
    end
    
    if addon.Debug then
        addon.Debug("DEBUG", "LibraryManager: Validated embedding for:", libraryName)
    end
    return true
end

function LibraryManager:SafeEmbed(target, libraryName)
    if not self:ValidateEmbedding(target, libraryName) then
        return false
    end
    
    local lib = self:GetLibrary(libraryName)
    local success, err = pcall(lib.Embed, lib, target)
    if not success then
        if addon.Debug then
            addon.Debug("ERROR", "LibraryManager: Failed to embed", libraryName, "error:", err)
        end
        return false
    end
    
    if addon.Debug then
        addon.Debug("DEBUG", "LibraryManager: Successfully embedded:", libraryName)
    end
    return true
end

return LibraryManager