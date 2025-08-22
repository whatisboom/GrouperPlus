local addonName, addon = ...

-- Member Management Module
-- Handles member list retrieval from multiple channels (guild, party, raid), filtering, and group membership tracking

local MemberManager = {}
addon.MemberManager = MemberManager

for k, v in pairs(addon.DebugMixin) do
    MemberManager[k] = v
end
MemberManager:InitDebug("MemberMgr")

-- Private state
local memberList = {}
local membersInGroups = {} -- Track which members are assigned to groups
local MAX_LEVEL = GetMaxPlayerLevel()

-- Initialize the member list
function MemberManager:Initialize(clearGroups)
    self.Debug("DEBUG", "MemberManager: Initializing", clearGroups and "(clearing group tracking)" or "(preserving group tracking)")
    table.wipe(memberList)
    -- Only wipe membersInGroups if explicitly requested (e.g., when clearing all groups)
    if clearGroups then
        table.wipe(membersInGroups)
    end
end

-- Update member list from all enabled communication channels with filtering and role detection
function MemberManager:UpdateMemberList()
    self.Debug("DEBUG", "MemberManager: Starting member list update from enabled channels")
    
    -- Debug output for current members in groups
    local groupMemberCount = 0
    for name, _ in pairs(membersInGroups) do
        groupMemberCount = groupMemberCount + 1
        self.Debug("TRACE", "MemberManager: Member in group:", name)
    end
    self.Debug("DEBUG", "MemberManager: Current membersInGroups count:", groupMemberCount)
    
    table.wipe(memberList)
    local seenMembers = {} -- Track duplicates across channels
    
    -- Get enabled channels from communication settings
    local enabledChannels = {}
    if addon.AddonComm and addon.AddonComm.GetEnabledChannels then
        enabledChannels = addon.AddonComm:GetEnabledChannels()
    else
        -- Fallback to guild only if AddonComm not available
        enabledChannels = {"GUILD"}
    end
    
    self.Debug("DEBUG", "MemberManager: Enabled channels:", table.concat(enabledChannels, ", "))
    
    -- Collect members from each enabled channel
    for _, channel in ipairs(enabledChannels) do
        if channel == "GUILD" then
            self:CollectGuildMembers(seenMembers)
        elseif channel == "PARTY" then
            self:CollectPartyMembers(seenMembers)
        elseif channel == "RAID" then
            self:CollectRaidMembers(seenMembers)
        end
    end
    
    self.Debug("INFO", "MemberManager: Found", #memberList, "total available members from", #enabledChannels, "channels (after filtering)")
    
    return memberList
end

-- Collect guild members
function MemberManager:CollectGuildMembers(seenMembers)
    if not IsInGuild() then
        self.Debug("DEBUG", "MemberManager: Not in guild, skipping guild members")
        return
    end
    
    local numMembers = GetNumGuildMembers()
    self.Debug("DEBUG", "MemberManager: Checking", numMembers, "guild members")
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        self:ProcessMember(name, level, classFileName or class, class, "GUILD", seenMembers, online)
    end
end

-- Collect party members
function MemberManager:CollectPartyMembers(seenMembers)
    if not IsInGroup() or IsInRaid() then
        self.Debug("DEBUG", "MemberManager: Not in party (or in raid), skipping party members")
        return
    end
    
    local numMembers = GetNumGroupMembers()
    self.Debug("DEBUG", "MemberManager: Checking", numMembers, "party members")
    
    for i = 1, numMembers do
        local unit = "party" .. i
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local fullName = realm and (name .. "-" .. realm) or name
            local level = UnitLevel(unit)
            local classLocalized, class = UnitClass(unit)
            local online = UnitIsConnected(unit)
            self:ProcessMember(fullName, level, class, classLocalized, "PARTY", seenMembers, online)
        end
    end
    
    -- Include the player
    local playerName = UnitName("player")
    local playerFullName = playerName .. "-" .. GetRealmName()
    local playerLevel = UnitLevel("player")
    local playerClassLocalized, playerClass = UnitClass("player")
    self:ProcessMember(playerFullName, playerLevel, playerClass, playerClassLocalized, "PARTY", seenMembers, true)
end

-- Collect raid members  
function MemberManager:CollectRaidMembers(seenMembers)
    if not IsInRaid() then
        self.Debug("DEBUG", "MemberManager: Not in raid, skipping raid members")
        return
    end
    
    local numMembers = GetNumGroupMembers()
    self.Debug("DEBUG", "MemberManager: Checking", numMembers, "raid members")
    
    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local fullName = realm and (name .. "-" .. realm) or name
            local level = UnitLevel(unit)
            local classLocalized, class = UnitClass(unit)
            local online = UnitIsConnected(unit)
            self:ProcessMember(fullName, level, class, classLocalized, "RAID", seenMembers, online)
        end
    end
end

-- Process a member for inclusion in the list
function MemberManager:ProcessMember(name, level, class, classLocalized, source, seenMembers, online)
    if not name then
        return
    end
    
    self.Debug("TRACE", "MemberManager: Processing", name, "from", source)
    
    -- Check level and online requirements
    local shouldInclude = online and (level == MAX_LEVEL or (addon.settings and addon.settings.debug and addon.settings.debug.enabled and addon.settings.debug.ignoreMaxLevel))
    
    if not shouldInclude then
        if not online then
            self.Debug("TRACE", "MemberManager: Skipped", name, "from", source, "- offline")
        elseif level ~= MAX_LEVEL then
            self.Debug("TRACE", "MemberManager: Skipped", name, "from", source, "- level", level, "(not max level", MAX_LEVEL, ")")
        end
        return
    end
    
    -- Normalize name first to ensure consistent format for all checks
    -- Always ensure names have consistent realm format for proper deduplication
    local normalizedName = name
    if not string.find(name, "%-") then
        -- If name has no realm, add current realm for consistency (guild members and current player)
        normalizedName = name .. "-" .. GetRealmName()
    end
    -- For party/raid members, the name should already include the correct realm
    
    -- Skip if already in a group (check using normalized name)
    if membersInGroups[normalizedName] then
        self.Debug("DEBUG", "MemberManager: Skipped", normalizedName, "from", source, "- already in group")
        return
    else
        self.Debug("TRACE", "MemberManager: Member", normalizedName, "not found in membersInGroups - will be included")
    end
    
    if seenMembers[normalizedName] then
        self.Debug("DEBUG", "MemberManager: Skipped duplicate", name, "from", source, "(normalized as", normalizedName, "already seen from", seenMembers[normalizedName], ")")
        return
    end
    
    -- Create member data using normalized name format
    local memberData = {
        name = normalizedName,
        class = class,
        classLocalized = classLocalized,
        level = level,
        source = source
    }
    
    -- Add role information
    if addon.AutoFormation and addon.AutoFormation.GetPlayerRole then
        memberData.role = addon.AutoFormation:GetPlayerRole(normalizedName)
        self.Debug("TRACE", "MemberManager: Determined role for", normalizedName, ":", memberData.role)
    end
    
    -- For the player, ensure we get the most current role
    local playerName = UnitName("player")
    local playerFullName = UnitName("player") .. "-" .. GetRealmName()
    if normalizedName == playerFullName then
        local currentSpec = GetSpecialization()
        if currentSpec then
            local role = GetSpecializationRole(currentSpec)
            if role == "TANK" then
                memberData.role = "TANK"
            elseif role == "HEALER" then
                memberData.role = "HEALER"
            else
                memberData.role = "DPS"
            end
            self.Debug("INFO", "MemberManager: Updated player's own role to:", memberData.role, "from spec", currentSpec)
        end
    end
    
    -- Add to lists
    table.insert(memberList, memberData)
    seenMembers[normalizedName] = source
    
    local levelNote = level == MAX_LEVEL and "" or " (DEBUG: ignoring level req)"
    self.Debug("TRACE", "MemberManager: Added", normalizedName, "from", source, "level", level, levelNote, "class:", class, "role:", memberData.role or "unknown")
end

-- Get the current member list
function MemberManager:GetMemberList()
    return memberList
end

-- Get member count
function MemberManager:GetMemberCount()
    return #memberList
end

-- Check if a member is in a group
function MemberManager:IsMemberInGroup(memberName)
    return membersInGroups[memberName] == true
end

-- Set a member's group status
function MemberManager:SetMemberInGroup(memberName, inGroup)
    if inGroup then
        membersInGroups[memberName] = true
        self.Debug("DEBUG", "MemberManager: Added", memberName, "to membersInGroups tracking")
    else
        membersInGroups[memberName] = nil
        self.Debug("DEBUG", "MemberManager: Removed", memberName, "from membersInGroups tracking")
    end
end

-- Clear all group memberships (used when clearing all groups)
function MemberManager:ClearAllGroupMemberships()
    self.Debug("DEBUG", "MemberManager: Clearing all group memberships")
    table.wipe(membersInGroups)
end

-- Get all members currently in groups
function MemberManager:GetMembersInGroups()
    local members = {}
    for memberName, _ in pairs(membersInGroups) do
        table.insert(members, memberName)
    end
    return members
end

-- Debug function to log current state
function MemberManager:DebugState()
    self.Debug("DEBUG", "MemberManager: Current membersInGroups:")
    for name, _ in pairs(membersInGroups) do
        self.Debug("DEBUG", "  -", name)
    end
end

-- Find member data by name
function MemberManager:FindMemberByName(memberName)
    for _, member in ipairs(memberList) do
        if member.name == memberName then
            return member
        end
    end
    return nil
end