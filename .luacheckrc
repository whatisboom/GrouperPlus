std = "lua51"
max_line_length = false
exclude_files = {
    "libs/**/*.lua",
    ".luacheckrc"
}
ignore = {
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "542", -- Empty if branch
    "611", -- Line contains only whitespace
    "612", -- Line contains trailing whitespace
    "613", -- Trailing whitespace in a comment
}
globals = {
    -- WoW API
    "CreateFrame",
    "UnitName",
    "UnitClass",
    "UnitRace",
    "UnitLevel",
    "UnitGUID",
    "UnitExists",
    "UnitIsPlayer",
    "GetRealmName",
    "GetRaidRosterInfo",
    "GetNumGroupMembers",
    "GetNumGuildMembers",
    "GetGuildRosterInfo",
    "GetMaxPlayerLevel",
    "IsInRaid",
    "IsInGroup",
    "IsInGuild",
    "SendChatMessage",
    "RegisterAddonMessagePrefix",
    "SendAddonMessage",
    "GetAddOnMetadata",
    "GetBuildInfo",
    "GetTime",
    "GetServerTime",
    "GetSpecialization",
    "GetSpecializationInfo",
    "GetSpecializationRole",
    "GetInspectSpecialization",
    "GetCursorPosition",
    "SetCursor",
    "ResetCursor",
    "PlaySound",
    "PlaySoundFile",
    "print",
    "select",
    "date",
    "time",
    "format",
    "strsplit",
    "strjoin",
    "strupper",
    "strlower",
    "strtrim",
    "string",
    "table",
    "math",
    "pairs",
    "ipairs",
    "next",
    "type",
    "tonumber",
    "tostring",
    "setmetatable",
    "getmetatable",
    "rawget",
    "rawset",
    "pcall",
    "xpcall",
    "error",
    "assert",
    "unpack",
    
    -- WoW UI
    "UIParent",
    "GameTooltip",
    "DEFAULT_CHAT_FRAME",
    "InterfaceOptionsFrame_OpenToCategory",
    "Settings",
    "SlashCmdList",
    "SOUNDKIT",
    "BackdropTemplateMixin",
    "GameFontNormal",
    "GameFontHighlight",
    "ToggleDropDownMenu",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",
    "UIDropDownMenu_Initialize",
    "CloseDropDownMenus",
    "UIDROPDOWNMENU_MENU_VALUE",
    "RAID_CLASS_COLORS",
    "CUSTOM_CLASS_COLORS",
    
    -- WoW Events
    "C_Timer",
    "C_AddOns",
    "C_MythicPlus",
    "C_ChallengeMode",
    "C_ChatInfo",
    "C_Container",
    "C_Item",
    "C_GuildInfo",
    
    -- Libraries
    "LibStub",
    "AceGUI",
    "AceConfig",
    "AceConfigDialog",
    "AceDB",
    "AceDBOptions",
    "CallbackHandler",
    "LibDataBroker",
    "LibDBIcon",
    "RaiderIO",
    
    -- Addon globals
    "GrouperPlus",
    "GrouperPlusDB",
    "GrouperDB",
    "_G",
    "_",
    "yOffset",
    "RemoveExcessEmptyGroups",
    "SLASH_GROUPER1",
    "SLASH_GROUPEROPTIONS1",
    "SLASH_GROUPEROPTIONS2",
    "BINDING_HEADER_GROUPERPLUS",
    "BINDING_NAME_GROUPERPLUS_TOGGLE"
}

read_globals = {
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "LE_PARTY_CATEGORY_HOME",
    "LE_PARTY_CATEGORY_INSTANCE"
}