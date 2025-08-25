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
                if addon.settings.debug.enabled then
                    return "TRACE"
                else
                    return addon.settings.debugLevel or "INFO"
                end
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
        debugHeader = {
            order = 5,
            type = "header",
            name = "Debug Settings",
        },
        debugModeGroup = {
            order = 6,
            type = "group",
            name = "Debug Mode",
            inline = true,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = "Enable Debug Mode",
                    desc = "Enable debug mode to automatically set debug level to TRACE and enable additional debugging options",
                    width = "full",
                    get = function()
                        return addon.settings.debug.enabled
                    end,
                    set = function(info, value)
                        local oldValue = addon.settings.debug.enabled
                        addon.settings.debug.enabled = value
                        if value then
                            OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Debug mode enabled, effective debug level is now TRACE")
                        else
                            OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Debug mode disabled, debug level restored to user selection")
                        end
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Debug mode changed from", oldValue, "to", value)
                    end,
                },
                ignoreMaxLevel = {
                    order = 2,
                    type = "toggle",
                    name = "Ignore Max Level Requirements",
                    desc = "Ignore maximum level requirements when populating screens and communicating",
                    disabled = function()
                        return not addon.settings.debug.enabled
                    end,
                    get = function()
                        return addon.settings.debug.ignoreMaxLevel
                    end,
                    set = function(info, value)
                        local oldValue = addon.settings.debug.ignoreMaxLevel
                        addon.settings.debug.ignoreMaxLevel = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Ignore max level requirements changed from", oldValue, "to", value)
                    end,
                },
            },
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
                    desc = "Enable communication with other GrouperPlus users",
                    width = "full",
                    get = function()
                        return addon.settings.communication.enabled
                    end,
                    set = function(info, value)
                        addon.settings.communication.enabled = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Addon communication changed to", value)
                    end,
                },
                channelsDesc = {
                    order = 2,
                    type = "description",
                    name = "\n|cFFFFD700Communication Channels|r\nSelect which channels to use for addon communication:",
                },
                channelGuild = {
                    order = 3,
                    type = "toggle",
                    name = "Guild Channel",
                    desc = "Send addon messages to guild members",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.channels and addon.settings.communication.channels.GUILD or false
                    end,
                    set = function(info, value)
                        local oldValue = addon.settings.communication.channels.GUILD
                        addon.settings.communication.channels.GUILD = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Guild channel changed from", oldValue, "to", value)
                    end,
                },
                channelParty = {
                    order = 4,
                    type = "toggle",
                    name = "Party Channel",
                    desc = "Send addon messages to party members",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.channels and addon.settings.communication.channels.PARTY or false
                    end,
                    set = function(info, value)
                        local oldValue = addon.settings.communication.channels.PARTY
                        addon.settings.communication.channels.PARTY = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Party channel changed from", oldValue, "to", value)
                    end,
                },
                channelRaid = {
                    order = 5,
                    type = "toggle",
                    name = "Raid Channel",
                    desc = "Send addon messages to raid members",
                    width = "full",
                    disabled = function()
                        return not addon.settings.communication.enabled
                    end,
                    get = function()
                        return addon.settings.communication.channels and addon.settings.communication.channels.RAID or false
                    end,
                    set = function(info, value)
                        local oldValue = addon.settings.communication.channels.RAID
                        addon.settings.communication.channels.RAID = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Raid channel changed from", oldValue, "to", value)
                    end,
                },
                dataSharingDesc = {
                    order = 6,
                    type = "description",
                    name = "\n|cFFFFD700Data Sharing Options|r",
                },
                acceptGroupSync = {
                    order = 7,
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
                    order = 8,
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
                    order = 9,
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
                    order = 10,
                    type = "description",
                    name = "\n|cFFFFD700Automation Options|r",
                },
                respondToRequests = {
                    order = 11,
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
                    order = 12,
                    type = "description",
                    name = "\n|cFFFFD700Performance Options|r",
                },
                compression = {
                    order = 13,
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
        sessionNotificationHeader = {
            order = 30,
            type = "header",
            name = "Session Notification Settings",
        },
        sessionNotificationGroup = {
            order = 31,
            type = "group",
            name = "Session Recruitment",
            inline = true,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = "Enable Session Notifications",
                    desc = "Enable notifications when other players start GrouperPlus sessions",
                    width = "full",
                    get = function()
                        return addon.settings.sessionNotifications.enabled
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.enabled = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Session notifications changed to", value)
                    end,
                },
                notificationStyle = {
                    order = 2,
                    type = "select",
                    name = "Notification Style",
                    desc = "Choose how to receive session notifications",
                    values = {
                        POPUP_AND_CHAT = "Popup + Chat Messages",
                        CHAT_ONLY = "Chat Messages Only"
                    },
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                    get = function()
                        return addon.settings.sessionNotifications.style
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.style = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Notification style changed to", value)
                    end,
                },
                responseTimeout = {
                    order = 3,
                    type = "range",
                    name = "Response Timeout",
                    desc = "How long to wait for responses when starting a session (seconds)",
                    min = 30,
                    max = 300,
                    step = 15,
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                    get = function()
                        return addon.settings.sessionNotifications.responseTimeout
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.responseTimeout = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Response timeout changed to", value)
                    end,
                },
                channelsDesc = {
                    order = 4,
                    type = "description",
                    name = "\n|cFFFFD700Announcement Channels|r\nSelect which channels to announce your sessions in:",
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                },
                announcementGuild = {
                    order = 5,
                    type = "toggle",
                    name = "Announce in Guild",
                    desc = "Post session announcements in guild chat",
                    width = "full",
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                    get = function()
                        return addon.settings.sessionNotifications.channels.GUILD
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.channels.GUILD = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Guild announcements changed to", value)
                    end,
                },
                announcementParty = {
                    order = 6,
                    type = "toggle",
                    name = "Announce in Party",
                    desc = "Post session announcements in party chat",
                    width = "full",
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                    get = function()
                        return addon.settings.sessionNotifications.channels.PARTY
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.channels.PARTY = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Party announcements changed to", value)
                    end,
                },
                announcementRaid = {
                    order = 7,
                    type = "toggle",
                    name = "Announce in Raid",
                    desc = "Post session announcements in raid chat",
                    width = "full",
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                    get = function()
                        return addon.settings.sessionNotifications.channels.RAID
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.channels.RAID = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Raid announcements changed to", value)
                    end,
                },
                messageTemplate = {
                    order = 8,
                    type = "input",
                    name = "Announcement Message",
                    desc = "Customize the message posted in chat channels",
                    width = "full",
                    multiline = 2,
                    disabled = function()
                        return not addon.settings.sessionNotifications.enabled
                    end,
                    get = function()
                        return addon.settings.sessionNotifications.messageTemplate
                    end,
                    set = function(info, value)
                        addon.settings.sessionNotifications.messageTemplate = value
                        OptionsPanel.Debug(addon.LOG_LEVEL.INFO, "OptionsPanel: Message template updated")
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
        function() 
            if addon.settings.debug.enabled then
                return "TRACE"
            else
                return addon.settings.debugLevel or "INFO"
            end
        end,
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