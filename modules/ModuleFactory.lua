local addonName, addon = ...

local ModuleFactory = {}
addon.ModuleFactory = ModuleFactory

local Debug = addon.Debug or function() end

function ModuleFactory:CreateModule(moduleName, moduleDefinition)
    Debug("DEBUG", "ModuleFactory:CreateModule creating module:", moduleName)
    
    local module = moduleDefinition or {}
    
    module.name = moduleName
    module.initialized = false
    
    addon[moduleName] = module
    
    local originalInitialize = module.Initialize
    module.Initialize = function(self, ...)
        if self.initialized then
            Debug("DEBUG", moduleName .. " already initialized, skipping")
            return
        end
        
        Debug("INFO", "Initializing module:", moduleName)
        
        if originalInitialize then
            local success, err = pcall(originalInitialize, self, ...)
            if not success then
                Debug("ERROR", "Failed to initialize " .. moduleName .. ":", err)
                return false
            end
        end
        
        self.initialized = true
        Debug("INFO", moduleName .. " initialized successfully")
        return true
    end
    
    local originalOnEnable = module.OnEnable
    module.OnEnable = function(self, ...)
        Debug("DEBUG", moduleName .. ":OnEnable called")
        if originalOnEnable then
            return originalOnEnable(self, ...)
        end
    end
    
    local originalOnDisable = module.OnDisable
    module.OnDisable = function(self, ...)
        Debug("DEBUG", moduleName .. ":OnDisable called")
        if originalOnDisable then
            return originalOnDisable(self, ...)
        end
    end
    
    module.IsInitialized = function(self)
        return self.initialized
    end
    
    module.GetName = function(self)
        return self.name
    end
    
    Debug("INFO", "Module", moduleName, "created successfully")
    return module
end

function ModuleFactory:RegisterModule(moduleName, moduleTable)
    Debug("DEBUG", "ModuleFactory:RegisterModule registering module:", moduleName)
    
    if not moduleTable then
        Debug("ERROR", "ModuleFactory:RegisterModule - moduleTable is nil for", moduleName)
        return nil
    end
    
    return self:CreateModule(moduleName, moduleTable)
end

function ModuleFactory:InitializeAllModules()
    Debug("INFO", "ModuleFactory:InitializeAllModules starting")
    
    local modules = {
        "DebugOptimized",
        "Utilities",
        "AddonComm", 
        "Keystone",
        "VersionWarning",
        "AddonUserList",
        "AutoFormation",
        "MainFrame"
    }
    
    for _, moduleName in ipairs(modules) do
        local module = addon[moduleName]
        if module and module.Initialize then
            Debug("DEBUG", "Initializing module:", moduleName)
            module:Initialize()
        end
    end
    
    Debug("INFO", "ModuleFactory:InitializeAllModules completed")
end

return ModuleFactory