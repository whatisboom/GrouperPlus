local addonName, addon = ...

local ModuleManager = {}
addon.ModuleManager = ModuleManager

local modules = {}
local initOrder = {}
local dependencies = {}

function ModuleManager:RegisterModule(name, moduleInstance, deps)
    if modules[name] then
        if addon.Debug then
            addon.Debug("WARN", "ModuleManager: Module", name, "already registered, replacing")
        end
    end
    
    modules[name] = moduleInstance
    dependencies[name] = deps or {}
    
    if addon.Debug then
        addon.Debug("DEBUG", "ModuleManager: Registered module", name)
        if deps and #deps > 0 then
            addon.Debug("TRACE", "ModuleManager: Module", name, "has dependencies:", table.concat(deps, ", "))
        end
    end
end

function ModuleManager:GetModule(name)
    return modules[name]
end

function ModuleManager:HasModule(name)
    return modules[name] ~= nil
end

function ModuleManager:GetAllModules()
    return modules
end

function ModuleManager:GetModuleNames()
    local names = {}
    for name, _ in pairs(modules) do
        table.insert(names, name)
    end
    return names
end

local function ResolveDependencies()
    local resolved = {}
    local temp = {}
    local order = {}
    
    local function visit(name)
        if temp[name] then
            error("ModuleManager: Circular dependency detected involving module: " .. name)
        end
        
        if not resolved[name] then
            temp[name] = true
            
            local deps = dependencies[name] or {}
            for _, dep in ipairs(deps) do
                if not modules[dep] then
                    error("ModuleManager: Module " .. name .. " depends on missing module: " .. dep)
                end
                visit(dep)
            end
            
            temp[name] = nil
            resolved[name] = true
            table.insert(order, name)
        end
    end
    
    for name, _ in pairs(modules) do
        visit(name)
    end
    
    return order
end

function ModuleManager:InitializeAll()
    if addon.Debug then
        addon.Debug("INFO", "ModuleManager: Starting module initialization")
    end
    
    local success, order = pcall(ResolveDependencies)
    if not success then
        if addon.Debug then
            addon.Debug("ERROR", "ModuleManager: Failed to resolve dependencies:", order)
        end
        return false
    end
    
    initOrder = order
    
    for _, name in ipairs(initOrder) do
        local module = modules[name]
        if module and module.Initialize then
            if addon.Debug then
                addon.Debug("DEBUG", "ModuleManager: Initializing module", name)
            end
            
            local initSuccess, err = pcall(module.Initialize, module)
            if not initSuccess then
                if addon.Debug then
                    addon.Debug("ERROR", "ModuleManager: Failed to initialize module", name, ":", err)
                end
                return false
            end
        else
            if addon.Debug then
                addon.Debug("WARN", "ModuleManager: Module", name, "has no Initialize method")
            end
        end
    end
    
    if addon.Debug then
        addon.Debug("INFO", "ModuleManager: All modules initialized successfully")
    end
    return true
end

function ModuleManager:CleanupAll()
    if addon.Debug then
        addon.Debug("INFO", "ModuleManager: Starting module cleanup")
    end
    
    local reverseOrder = {}
    for i = #initOrder, 1, -1 do
        table.insert(reverseOrder, initOrder[i])
    end
    
    for _, name in ipairs(reverseOrder) do
        local module = modules[name]
        if module and module.Cleanup then
            if addon.Debug then
                addon.Debug("DEBUG", "ModuleManager: Cleaning up module", name)
            end
            
            local success, err = pcall(module.Cleanup, module)
            if not success and addon.Debug then
                addon.Debug("ERROR", "ModuleManager: Error cleaning up module", name, ":", err)
            end
        end
    end
    
    if addon.Debug then
        addon.Debug("INFO", "ModuleManager: Module cleanup complete")
    end
end

function ModuleManager:InjectDependency(moduleName, dependencyName, dependency)
    local module = modules[moduleName]
    if not module then
        if addon.Debug then
            addon.Debug("ERROR", "ModuleManager: Cannot inject dependency - module", moduleName, "not found")
        end
        return false
    end
    
    if module.SetDependency then
        module:SetDependency(dependencyName, dependency)
        if addon.Debug then
            addon.Debug("TRACE", "ModuleManager: Injected dependency", dependencyName, "into module", moduleName)
        end
        return true
    else
        if addon.Debug then
            addon.Debug("WARN", "ModuleManager: Module", moduleName, "does not support dependency injection")
        end
        return false
    end
end

function ModuleManager:SetupCommunication(fromModule, toModule, eventName, handler)
    local from = modules[fromModule]
    local to = modules[toModule]
    
    if not from or not to then
        if addon.Debug then
            addon.Debug("ERROR", "ModuleManager: Cannot setup communication - modules not found")
        end
        return false
    end
    
    if to.RegisterEvent and handler then
        to:RegisterEvent(eventName, handler)
        if addon.Debug then
            addon.Debug("TRACE", "ModuleManager: Setup communication from", fromModule, "to", toModule, "for event", eventName)
        end
        return true
    end
    
    return false
end

function ModuleManager:GetInitializationOrder()
    return initOrder
end

function ModuleManager:GetModuleInfo()
    local info = {}
    for name, module in pairs(modules) do
        info[name] = {
            name = name,
            initialized = module.IsInitialized and module:IsInitialized() or false,
            dependencies = dependencies[name] or {},
            hasInitialize = module.Initialize ~= nil,
            hasCleanup = module.Cleanup ~= nil
        }
    end
    return info
end

return ModuleManager