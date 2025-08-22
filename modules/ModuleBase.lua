local addonName, addon = ...

local ModuleBase = {}
addon.ModuleBase = ModuleBase

function ModuleBase:New(moduleName)
    local module = {}
    setmetatable(module, { __index = self })
    
    module.moduleName = moduleName or "Unknown"
    module.initialized = false
    module.dependencies = {}
    
    for k, v in pairs(addon.DebugMixin) do
        module[k] = v
    end
    module:InitDebug(module.moduleName)
    
    return module
end

function ModuleBase:Initialize()
    if self.initialized then
        self.Debug("WARN", "Module", self.moduleName, "already initialized")
        return true
    end
    
    self.Debug("INFO", "Initializing module:", self.moduleName)
    
    if self.OnInitialize then
        local success, err = pcall(self.OnInitialize, self)
        if not success then
            self.Debug("ERROR", "Failed to initialize module", self.moduleName, ":", err)
            return false
        end
    end
    
    self.initialized = true
    self.Debug("DEBUG", "Module", self.moduleName, "initialized successfully")
    return true
end

function ModuleBase:Cleanup()
    if not self.initialized then
        return
    end
    
    self.Debug("INFO", "Cleaning up module:", self.moduleName)
    
    if self.OnCleanup then
        local success, err = pcall(self.OnCleanup, self)
        if not success then
            self.Debug("ERROR", "Error during cleanup of module", self.moduleName, ":", err)
        end
    end
    
    self.initialized = false
    self.Debug("DEBUG", "Module", self.moduleName, "cleaned up")
end

function ModuleBase:RegisterEvent(event, handler)
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventHandlers = {}
    end
    
    if not self.eventHandlers[event] then
        self.eventFrame:RegisterEvent(event)
        self.eventHandlers[event] = {}
    end
    
    table.insert(self.eventHandlers[event], handler)
    
    self.eventFrame:SetScript("OnEvent", function(frame, eventName, ...)
        if self.eventHandlers[eventName] then
            for _, eventHandler in ipairs(self.eventHandlers[eventName]) do
                local success, err = pcall(eventHandler, self, ...)
                if not success then
                    self.Debug("ERROR", "Error in event handler for", eventName, "in module", self.moduleName, ":", err)
                end
            end
        end
    end)
    
    self.Debug("TRACE", "Registered event", event, "for module", self.moduleName)
end

function ModuleBase:UnregisterEvent(event)
    if not self.eventFrame or not self.eventHandlers then
        return
    end
    
    if self.eventHandlers[event] then
        self.eventFrame:UnregisterEvent(event)
        self.eventHandlers[event] = nil
        self.Debug("TRACE", "Unregistered event", event, "for module", self.moduleName)
    end
end

function ModuleBase:UnregisterAllEvents()
    if not self.eventFrame then
        return
    end
    
    self.eventFrame:UnregisterAllEvents()
    self.eventHandlers = {}
    self.Debug("TRACE", "Unregistered all events for module", self.moduleName)
end

function ModuleBase:SetDependency(name, dependency)
    self.dependencies[name] = dependency
    self.Debug("TRACE", "Set dependency", name, "for module", self.moduleName)
end

function ModuleBase:GetDependency(name)
    return self.dependencies[name]
end

function ModuleBase:HasDependency(name)
    return self.dependencies[name] ~= nil
end

function ModuleBase:RequireDependencies(...)
    local missing = {}
    for i = 1, select("#", ...) do
        local dep = select(i, ...)
        if not self:HasDependency(dep) then
            table.insert(missing, dep)
        end
    end
    
    if #missing > 0 then
        local missingList = table.concat(missing, ", ")
        self.Debug("ERROR", "Module", self.moduleName, "missing required dependencies:", missingList)
        return false, "Missing dependencies: " .. missingList
    end
    
    return true
end

function ModuleBase:IsInitialized()
    return self.initialized
end

function ModuleBase:GetModuleName()
    return self.moduleName
end

return ModuleBase