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
}
globals = {
    -- WoW API
    "CreateFrame",
    "UnitName",
    "UnitClass",
    "UnitRace",
    "UnitLevel",
    "UnitGUID",
    "GetRealmName",
    "GetRaidRosterInfo",
    "GetNumGroupMembers",
    "IsInRaid",
    "IsInGroup",
    "SendChatMessage",
    "RegisterAddonMessagePrefix",
    "SendAddonMessage",
    "GetAddOnMetadata",
    "GetBuildInfo",
    "GetTime",
    "GetServerTime",
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
    
    -- WoW Events
    "C_Timer",
    "C_AddOns",
    "C_MythicPlus",
    
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
    
    -- Addon globals
    "GrouperPlus",
    "GrouperPlusDB",
    "_G",
    "BINDING_HEADER_GROUPERPLUS",
    "BINDING_NAME_GROUPERPLUS_TOGGLE"
}

read_globals = {
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "LE_PARTY_CATEGORY_HOME",
    "LE_PARTY_CATEGORY_INSTANCE"
}