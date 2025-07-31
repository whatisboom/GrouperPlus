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