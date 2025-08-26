local addonName, addon = ...

local WoWAPIWrapper = {}
addon.WoWAPIWrapper = WoWAPIWrapper

addon.DebugMixin:InjectInto(WoWAPIWrapper, "WoWAPI")

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
    -- WoW API returns "DAMAGER" for DPS specs, translate to our internal "DPS" terminology
    return role == "DAMAGER" and "DPS" or role
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
            -- Normalize the name properly - don't double-add realm
            local normalizedName = self:NormalizePlayerName(name)
            table.insert(members, {
                name = normalizedName,
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
            local baseName = realm and (name .. "-" .. realm) or name
            local normalizedName = self:NormalizePlayerName(baseName)
            local level = UnitLevel(unit)
            local classLocalized, class = UnitClass(unit)
            local online = UnitIsConnected(unit) -- luacheck: ignore 113
            
            table.insert(members, {
                name = normalizedName,
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

function WoWAPIWrapper:GetClassColor(class)
    if not class then
        return nil
    end
    
    local classColor = RAID_CLASS_COLORS[class]
    if classColor then
        return {
            r = classColor.r,
            g = classColor.g, 
            b = classColor.b
        }
    end
    
    return {r = 1, g = 1, b = 1}
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