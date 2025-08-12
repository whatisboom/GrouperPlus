local addonName, addon = ...

local LibraryManager = {}
addon.LibraryManager = LibraryManager

local libraryCache = {}
local requiredLibraries = {
    "AceDB-3.0",
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
    
    local lib = LibStub and LibStub(libraryName, not required)
    if lib then
        libraryCache[libraryName] = lib
        if addon.Debug then
            addon.Debug("DEBUG", "LibraryManager: Loaded library", libraryName)
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

return LibraryManager