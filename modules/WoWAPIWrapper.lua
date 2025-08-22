local addonName, addon = ...

local WoWAPIWrapper = {}
addon.WoWAPIWrapper = WoWAPIWrapper

for k, v in pairs(addon.DebugMixin) do
    WoWAPIWrapper[k] = v
end
WoWAPIWrapper:InitDebug("WoWAPI")

function WoWAPIWrapper:GetPlayerInfo()
    local name = UnitName("player")
    local realm = GetRealmName()
    local fullName = name .. "-" .. realm
    local level = UnitLevel("player")
    local classLocalized, class = UnitClass("player")
    
    return {
        name = name,
        realm = realm,
        fullName = fullName,
        level = level,
        class = class,
        classLocalized = classLocalized
    }
end

function WoWAPIWrapper:GetPlayerRole()
    local currentSpec = GetSpecialization()
    if not currentSpec then
        return "DPS"
    end
    
    local role = GetSpecializationRole(currentSpec)
    if role == "TANK" then
        return "TANK"
    elseif role == "HEALER" then
        return "HEALER"
    else
        return "DPS"
    end
end

function WoWAPIWrapper:IsInGuild()
    return IsInGuild()
end

function WoWAPIWrapper:GetGuildMembers()
    if not self:IsInGuild() then
        return {}
    end
    
    local members = {}
    local numMembers = GetNumGuildMembers()
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        if name and online then
            table.insert(members, {
                name = name .. "-" .. GetRealmName(),
                level = level,
                class = classFileName or class,
                classLocalized = class,
                source = "GUILD",
                online = online
            })
        end
    end
    
    return members
end

function WoWAPIWrapper:IsInGroup()
    return IsInGroup()
end

function WoWAPIWrapper:IsInRaid()
    return IsInRaid()
end

function WoWAPIWrapper:GetGroupMembers()
    if not self:IsInGroup() then
        return {}
    end
    
    local members = {}
    local numMembers = GetNumGroupMembers()
    local unitPrefix = self:IsInRaid() and "raid" or "party"
    
    for i = 1, numMembers do
        local unit = unitPrefix .. i
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local fullName = realm and (name .. "-" .. realm) or (name .. "-" .. GetRealmName())
            local level = UnitLevel(unit)
            local classLocalized, class = UnitClass(unit)
            local online = UnitIsConnected(unit)
            
            table.insert(members, {
                name = fullName,
                level = level,
                class = class,
                classLocalized = classLocalized,
                source = self:IsInRaid() and "RAID" or "PARTY",
                online = online
            })
        end
    end
    
    local playerInfo = self:GetPlayerInfo()
    table.insert(members, {
        name = playerInfo.fullName,
        level = playerInfo.level,
        class = playerInfo.class,
        classLocalized = playerInfo.classLocalized,
        source = self:IsInRaid() and "RAID" or "PARTY",
        online = true
    })
    
    return members
end

function WoWAPIWrapper:GetMaxPlayerLevel()
    return GetMaxPlayerLevel()
end

function WoWAPIWrapper:GetServerTime()
    return GetServerTime()
end

function WoWAPIWrapper:GetTime()
    return GetTime()
end

function WoWAPIWrapper:NormalizePlayerName(name)
    if not name then
        return nil
    end
    
    if not string.find(name, "%-") then
        return name .. "-" .. GetRealmName()
    end
    
    return name
end

function WoWAPIWrapper:GetEnabledChannels()
    if addon.AddonComm and addon.AddonComm.GetEnabledChannels then
        return addon.AddonComm:GetEnabledChannels()
    end
    
    local channels = {}
    if self:IsInGuild() then
        table.insert(channels, "GUILD")
    end
    if self:IsInGroup() then
        table.insert(channels, self:IsInRaid() and "RAID" or "PARTY")
    end
    
    return channels
end

return WoWAPIWrapper