local addonName, addon = ...

local OptionsPanel = addon.ModuleBase:New("Options")
addon.OptionsPanel = OptionsPanel

-- AceConfig options table
local options = {
    name = "GrouperPlus",
    type = "group",
    args = {
        generalHeader = {
            order = 1,
            type = "header",
            name = "General Settings",
        },
        debugLevel = {
            order = 2,
            type = "select",
            name = "Debug Level",
            desc = "Set the level of debug messages to display",
            values = {
                ERROR = "ERROR",
                WARN = "WARN",
                INFO = "INFO",
                DEBUG = "DEBUG",
                TRACE = "TRACE"
            },
            get = function()
                return addon.settings.debugLevel or "INFO"
            end,
            set = function(info, value)
                local oldValue = addon.settings.debugLevel
                addon.settings.debugLevel = value
                OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Debug level changed from", oldValue, "to", value)
            end,
        },
        showMinimap = {
            order = 3,
            type = "toggle",
            name = "Show Minimap Icon",
            desc = "Toggle the visibility of the minimap icon",
            get = function()
                return not addon.settings.minimap.hide
            end,
            set = function(info, value)
                addon.settings.minimap.hide = not value
                local LibDBIcon = LibStub("LibDBIcon-1.0")
                if value then
                    LibDBIcon:Show("GrouperPlus")
                else
                    LibDBIcon:Hide("GrouperPlus")
                end
                OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Minimap icon visibility changed to", value)
            end,
        },
        integrationHeader = {
            order = 10,
            type = "header",
            name = "Integration Settings",
        },
        raiderIOGroup = {
            order = 11,
            type = "group",
            name = "RaiderIO",
            inline = true,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = "Enable RaiderIO Integration",
                    desc = "Enable or disable RaiderIO addon integration features",
                    width = "full",
                    get = function()
                        return addon.settings.raiderIO.enabled
                    end,
                    set = function(info, value)
                        addon.settings.raiderIO.enabled = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: RaiderIO integration changed to", value)
                    end,
                },
                showInTooltips = {
                    order = 2,
                    type = "toggle",
                    name = "Show RaiderIO Info in Tooltips",
                    desc = "Automatically add RaiderIO information to unit tooltips",
                    width = "full",
                    disabled = function()
                        return not addon.settings.raiderIO.enabled
                    end,
                    get = function()
                        return addon.settings.raiderIO.showInTooltips
                    end,
                    set = function(info, value)
                        addon.settings.raiderIO.showInTooltips = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: RaiderIO tooltips changed to", value)
                    end,
                },
            },
        },
        communicationHeader = {
            order = 20,
            type = "header",
            name = "Communication Settings",
        },
        communicationGroup = {
            order = 21,
            type = "group",
            name = "Addon Communication",
            inline = true,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = "Enable Addon Communication",
                    desc = "Enable communication with other GrouperPlus users in your guild",
                    width = "full",
                    get = function()
                        return addon.settings.communication.enabled
                    end,
                    set = function(info, value)
                        addon.settings.communication.enabled = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Addon communication changed to", value)
                    end,
                },
                dataSharingDesc = {
                    order = 2,
                    type = "description",
                    name = "\n|cFFFFD700Data Sharing Options|r",
                },
                acceptGroupSync = {
                    order = 3,
                    type = "toggle",
                    name = "Accept Group Synchronization",
                    desc = "Allow other addon users to sync their group formations to your interface",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.acceptGroupSync
                    end,
                    set = function(info, value)
                        addon.settings.communication.acceptGroupSync = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Accept group sync changed to", value)
                    end,
                },
                acceptPlayerData = {
                    order = 4,
                    type = "toggle",
                    name = "Accept Player Data Sharing",
                    desc = "Allow receiving player information (roles, ratings) from other addon users",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.acceptPlayerData
                    end,
                    set = function(info, value)
                        addon.settings.communication.acceptPlayerData = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Accept player data changed to", value)
                    end,
                },
                acceptRaiderIOData = {
                    order = 5,
                    type = "toggle",
                    name = "Accept RaiderIO Data Sharing",
                    desc = "Allow receiving RaiderIO scores from other addon users (useful when you don't have RaiderIO installed)",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.acceptRaiderIOData
                    end,
                    set = function(info, value)
                        addon.settings.communication.acceptRaiderIOData = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Accept RaiderIO data changed to", value)
                    end,
                },
                automationDesc = {
                    order = 6,
                    type = "description",
                    name = "\n|cFFFFD700Automation Options|r",
                },
                respondToRequests = {
                    order = 7,
                    type = "toggle",
                    name = "Respond to Formation Requests",
                    desc = "Automatically respond to group formation requests from other addon users",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.respondToRequests
                    end,
                    set = function(info, value)
                        addon.settings.communication.respondToRequests = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Respond to requests changed to", value)
                    end,
                },
                performanceDesc = {
                    order = 8,
                    type = "description",
                    name = "\n|cFFFFD700Performance Options|r",
                },
                compression = {
                    order = 9,
                    type = "toggle",
                    name = "Enable Message Compression",
                    desc = "Compress addon messages to reduce network traffic (requires LibCompress)",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.compression
                    end,
                    set = function(info, value)
                        addon.settings.communication.compression = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Message compression changed to", value)
                        
                        if value then
                            local LibCompress = LibStub("LibCompress", true)
                            if not LibCompress then
                                OptionsPanel.Debug(addon.LOG_LEVEL.WARN, "LibCompress not available - compression will not work")
                            end
                        end
                    end,
                },
            },
        },
    },
}

-- Profile options
local profileOptions = {
    name = "Profiles",
    type = "group",
    args = {},
}

function OptionsPanel:OnInitialize()
    if not addon.db then
        self.Debug(addon.LOG_LEVEL.ERROR, "OptionsPanel: Database not initialized")
        return
    end
    
    if self.optionsFrame then
        self.Debug(addon.LOG_LEVEL.WARN, "OptionsPanel: Already initialized, skipping duplicate registration")
        return
    end
    
    -- Check if AceConfig libraries are available
    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceDBOptions = LibStub("AceDBOptions-3.0", true)
    
    if not AceConfig or not AceConfigDialog then
        -- Fallback to basic Settings API
        self.Debug(addon.LOG_LEVEL.WARN, "OptionsPanel: AceConfig not available, using fallback")
        self:CreateFallbackPanel()
        return
    end
    
    -- Register the options table
    AceConfig:RegisterOptionsTable("GrouperPlus", options)
    
    -- Add to Blizzard options
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("GrouperPlus", "GrouperPlus")
    
    -- Add profile options if AceDBOptions is available
    if AceDBOptions and addon.db then
        profileOptions.args = AceDBOptions:GetOptionsTable(addon.db)
        AceConfig:RegisterOptionsTable("GrouperPlus_Profiles", profileOptions)
        AceConfigDialog:AddToBlizOptions("GrouperPlus_Profiles", "Profiles", "GrouperPlus")
    end
    
    self.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Initialized with AceConfig")
end

-- Fallback function using standard Settings API
function OptionsPanel:CreateFallbackPanel()
    if addon.optionsCategoryID then
        self.Debug(addon.LOG_LEVEL.WARN, "OptionsPanel: Fallback panel already exists, skipping duplicate registration")
        return
    end
    
    local category = Settings.RegisterVerticalLayoutCategory("GrouperPlus")
    
    -- Debug Level
    local debugOptions = function()
        local container = Settings.CreateControlTextContainer()
        container:Add("ERROR", "ERROR")
        container:Add("WARN", "WARN")
        container:Add("INFO", "INFO")
        container:Add("DEBUG", "DEBUG")
        container:Add("TRACE", "TRACE")
        return container:GetData()
    end
    
    local debugSetting = Settings.RegisterProxySetting(category, "GrouperPlusDebugLevel", 
        Settings.VarType.String, "Debug Level", "INFO",
        function() return addon.settings.debugLevel or "INFO" end,
        function(value) addon.settings.debugLevel = value end
    )
    Settings.CreateDropdown(category, debugSetting, debugOptions, "Set the level of debug messages to display")
    
    -- Minimap Icon
    local minimapSetting = Settings.RegisterProxySetting(category, "GrouperPlusShowMinimap",
        Settings.VarType.Boolean, "Show Minimap Icon", true,
        function() return not addon.settings.minimap.hide end,
        function(value) 
            addon.settings.minimap.hide = not value
            local LibDBIcon = LibStub("LibDBIcon-1.0")
            if value then
                LibDBIcon:Show("GrouperPlus")
            else
                LibDBIcon:Hide("GrouperPlus")
            end
        end
    )
    Settings.CreateCheckbox(category, minimapSetting, "Toggle the visibility of the minimap icon")
    
    Settings.RegisterAddOnCategory(category)
    addon.optionsCategoryID = category:GetID()
    
    self.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Created fallback panel")
end


-- Slash commands
SLASH_GROUPEROPTIONS1 = "/grouperopt"
SLASH_GROUPEROPTIONS2 = "/grouperptions"
SlashCmdList["GROUPEROPTIONS"] = function()
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    
    if AceConfigDialog then
        -- Use AceConfig dialog
        AceConfigDialog:Open("GrouperPlus")
    elseif addon.optionsCategoryID then
        -- Use fallback Settings API
        Settings.OpenToCategory(addon.optionsCategoryID)
    else
        OptionsPanel.Debug(addon.LOG_LEVEL.WARN, "OptionsPanel: Options panel not yet initialized")
    end
end