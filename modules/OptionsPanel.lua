local addonName, addon = ...

local function CreateOptionsPanel()
    if not addon.db then 
        addon.Debug(addon.LOG_LEVEL.ERROR, "OptionsPanel: Cannot create options panel - database not initialized")
        return 
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "OptionsPanel: Creating options panel")
    local category = Settings.RegisterVerticalLayoutCategory("GrouperPlus")
    
    -- Debug Level Dropdown
    do
        local name = "Debug Level"
        local tooltip = "Set the level of debug messages to display"
        local options = function()
            local container = Settings.CreateControlTextContainer()
            container:Add("ERROR", "ERROR")
            container:Add("WARN", "WARN")
            container:Add("INFO", "INFO")
            container:Add("DEBUG", "DEBUG")
            container:Add("TRACE", "TRACE")
            return container:GetData()
        end
        
        local defaultValue = "INFO"
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusDebugLevel", Settings.VarType.String,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.debugLevel or defaultValue
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting debug level:", currentValue)
                return currentValue
            end,
            function(value) 
                local oldValue = addon.settings.debugLevel
                addon.settings.debugLevel = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Debug level changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateDropdown(category, setting, options, tooltip)
    end
    
    -- Show Minimap Icon Checkbox
    do
        local name = "Show Minimap Icon"
        local tooltip = "Toggle the visibility of the minimap icon"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusShowMinimap", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = not addon.settings.minimap.hide
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting minimap visibility:", currentValue)
                return currentValue
            end,
            function(value)
                local wasHidden = addon.settings.minimap.hide
                addon.settings.minimap.hide = not value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Minimap icon visibility changed from", not wasHidden, "to", value)
                
                local LibDBIcon = LibStub("LibDBIcon-1.0")
                if value then
                    LibDBIcon:Show("GrouperPlus")
                    addon.Debug(addon.LOG_LEVEL.DEBUG, "OptionsPanel: Minimap icon shown")
                else
                    LibDBIcon:Hide("GrouperPlus")
                    addon.Debug(addon.LOG_LEVEL.DEBUG, "OptionsPanel: Minimap icon hidden")
                end
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Enable RaiderIO Integration Checkbox
    do
        local name = "Enable RaiderIO Integration"
        local tooltip = "Enable or disable RaiderIO addon integration features"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusRaiderIOEnabled", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.raiderIO.enabled
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting RaiderIO enabled:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.raiderIO.enabled
                addon.settings.raiderIO.enabled = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: RaiderIO integration changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Show in Tooltips Checkbox
    do
        local name = "Show RaiderIO Info in Tooltips"
        local tooltip = "Automatically add RaiderIO information to unit tooltips"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusRaiderIOTooltips", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.raiderIO.showInTooltips
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting RaiderIO tooltips:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.raiderIO.showInTooltips
                addon.settings.raiderIO.showInTooltips = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: RaiderIO tooltips changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Enable Communication Checkbox
    do
        local name = "Enable Addon Communication"
        local tooltip = "Enable communication with other GrouperPlus users in your guild"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusCommunicationEnabled", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.communication.enabled
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting communication enabled:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.communication.enabled
                addon.settings.communication.enabled = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Addon communication changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Accept Group Sync Checkbox
    do
        local name = "Accept Group Synchronization"
        local tooltip = "Allow other addon users to sync their group formations to your interface"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusAcceptGroupSync", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.communication.acceptGroupSync
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting accept group sync:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.communication.acceptGroupSync
                addon.settings.communication.acceptGroupSync = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Accept group sync changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Accept Player Data Checkbox
    do
        local name = "Accept Player Data Sharing"
        local tooltip = "Allow receiving player information (roles, ratings) from other addon users"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusAcceptPlayerData", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.communication.acceptPlayerData
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting accept player data:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.communication.acceptPlayerData
                addon.settings.communication.acceptPlayerData = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Accept player data changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Accept RaiderIO Data Checkbox
    do
        local name = "Accept RaiderIO Data Sharing"
        local tooltip = "Allow receiving RaiderIO scores from other addon users (useful when you don't have RaiderIO installed)"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusAcceptRaiderIOData", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.communication.acceptRaiderIOData
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting accept RaiderIO data:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.communication.acceptRaiderIOData
                addon.settings.communication.acceptRaiderIOData = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Accept RaiderIO data changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Respond to Formation Requests Checkbox
    do
        local name = "Respond to Formation Requests"
        local tooltip = "Automatically respond to group formation requests from other addon users"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusRespondToRequests", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.communication.respondToRequests
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting respond to requests:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.communication.respondToRequests
                addon.settings.communication.respondToRequests = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Respond to requests changed from", oldValue, "to", value)
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    -- Enable Compression Checkbox
    do
        local name = "Enable Message Compression"
        local tooltip = "Compress addon messages to reduce network traffic (requires LibCompress)"
        local defaultValue = true
        
        local setting = Settings.RegisterProxySetting(category, "GrouperPlusCompressionEnabled", Settings.VarType.Boolean,
            name, defaultValue,
            function() 
                local currentValue = addon.settings.communication.compression
                addon.Debug(addon.LOG_LEVEL.TRACE, "OptionsPanel: Getting compression enabled:", currentValue)
                return currentValue
            end,
            function(value)
                local oldValue = addon.settings.communication.compression
                addon.settings.communication.compression = value
                addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Message compression changed from", oldValue, "to", value)
                
                -- Test LibCompress availability when enabling
                if value then
                    local LibCompress = LibStub("LibCompress", true)
                    if not LibCompress then
                        addon.Debug(addon.LOG_LEVEL.WARN, "LibCompress not available - compression will not work")
                    else
                        addon.Debug(addon.LOG_LEVEL.INFO, "LibCompress available - compression enabled")
                    end
                end
            end
        )
        
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    
    
    Settings.RegisterAddOnCategory(category)
    addon.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Options panel registered successfully")
    return category:GetID()
end

-- Wait for addon to be fully loaded
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "OptionsPanel: Addon loaded, scheduling panel creation")
        C_Timer.After(0.1, function()
            addon.optionsCategoryID = CreateOptionsPanel()
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Add slash command to open options
SLASH_GROUPEROPTIONS1 = "/grouperopt"
SLASH_GROUPEROPTIONS2 = "/grouperptions"
SlashCmdList["GROUPEROPTIONS"] = function()
    if addon.optionsCategoryID then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "OptionsPanel: Opening options panel via slash command")
        Settings.OpenToCategory(addon.optionsCategoryID)
    else
        addon.Debug(addon.LOG_LEVEL.WARN, "OptionsPanel: Options panel not yet initialized")
    end
end