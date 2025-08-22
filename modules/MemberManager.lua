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
local fullMemberList = {} -- Track all discovered members (for sharing)
local sharedMemberList = {} -- Track shared members from other clients (persistent)
local membersInGroups = {} -- Track which members are assigned to groups
local MAX_LEVEL = GetMaxPlayerLevel()

-- Initialize the member list
function MemberManager:Initialize(clearGroups)
    self.Debug("DEBUG", "MemberManager: Initializing", clearGroups and "(clearing group tracking)" or "(preserving group tracking)")
    table.wipe(memberList)
    table.wipe(fullMemberList)
    -- Don't wipe sharedMemberList - it should persist across updates
    -- Only wipe membersInGroups if explicitly requested (e.g., when clearing all groups)
    if clearGroups then
        table.wipe(membersInGroups)
        table.wipe(sharedMemberList) -- Only clear shared members when explicitly clearing all
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
    table.wipe(fullMemberList)
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
    
    -- Add shared members from other clients to both lists
    local sharedCount = 0
    for _, sharedMember in ipairs(sharedMemberList) do
        if sharedMember.name and not seenMembers[sharedMember.name] then
            -- Add to full member list
            table.insert(fullMemberList, sharedMember)
            seenMembers[sharedMember.name] = sharedMember.source
            
            -- Only add to display list if not in a group
            if not membersInGroups[sharedMember.name] then
                table.insert(memberList, sharedMember)
            end
            
            sharedCount = sharedCount + 1
            self.Debug("TRACE", "MemberManager: Added shared member to lists:", sharedMember.name, "from", sharedMember.source)
        end
    end
    
    if sharedCount > 0 then
        self.Debug("DEBUG", "MemberManager: Added", sharedCount, "shared members to member lists")
    end
    
    self.Debug("INFO", "MemberManager: Found", #memberList, "available members and", #fullMemberList, "total members from", #enabledChannels, "channels +", sharedCount, "shared")
    
    -- Check if we should auto-share roster due to significant changes (but not during sync operations)
    if self:CheckAutoRosterShare() and not self:IsSyncInProgress() then
        if addon.AddonComm and addon.AddonComm.ShareMemberRoster then
            C_Timer.After(2, function()
                addon.AddonComm:ShareMemberRoster()
            end)
        end
    elseif self:IsSyncInProgress() then
        self.Debug("DEBUG", "MemberManager: Skipping auto-roster share - sync operation in progress")
    end
    
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
    
    -- Check if member is in a group (but don't skip - we still want them in fullMemberList)
    local isInGroup = membersInGroups[normalizedName]
    if isInGroup then
        self.Debug("DEBUG", "MemberManager: Member", normalizedName, "is already in group - will add to full list only")
    else
        self.Debug("TRACE", "MemberManager: Member", normalizedName, "not in group - will be included in display list")
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
    
    -- Always add to full member list (for sharing purposes)
    table.insert(fullMemberList, memberData)
    seenMembers[normalizedName] = source
    
    -- Only add to filtered member list if not in a group (for UI display)
    if not membersInGroups[normalizedName] then
        table.insert(memberList, memberData)
        local levelNote = level == MAX_LEVEL and "" or " (DEBUG: ignoring level req)"
        self.Debug("TRACE", "MemberManager: Added to display list", normalizedName, "from", source, "level", level, levelNote, "class:", class, "role:", memberData.role or "unknown")
    else
        self.Debug("DEBUG", "MemberManager: Added to full list only (already in group)", normalizedName, "from", source)
    end
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

-- Get shareable member roster for communication
function MemberManager:GetShareableMemberRoster()
    self.Debug("DEBUG", "MemberManager: Preparing shareable member roster")
    
    local shareableMembers = {}
    local now = GetServerTime()
    
    for _, member in ipairs(fullMemberList) do
        if member.name and member.class then
            table.insert(shareableMembers, {
                name = member.name,
                class = member.class,
                classLocalized = member.classLocalized,
                level = member.level or 80,
                role = member.role or "DPS",
                source = member.source or "UNKNOWN",
                rating = member.rating or 0,
                timestamp = now
            })
        end
    end
    
    self.Debug("INFO", "MemberManager: Prepared", #shareableMembers, "members for sharing")
    return shareableMembers
end

-- Receive and integrate member roster from other clients
function MemberManager:ReceiveMemberRoster(data, sender)
    if not data or not data.members then
        self.Debug("WARN", "MemberManager: Invalid roster data received from", sender)
        return
    end
    
    self.Debug("INFO", "MemberManager: Processing roster from", data.sender, "with", #data.members, "members")
    
    local receivedMembers = data.members
    local mergedCount = 0
    local now = GetServerTime()
    
    -- Create a lookup table for existing members
    local existingMembers = {}
    for _, member in ipairs(memberList) do
        existingMembers[member.name] = member
    end
    
    -- Process each received member
    for _, receivedMember in ipairs(receivedMembers) do
        if receivedMember.name and receivedMember.class then
            local existing = existingMembers[receivedMember.name]
            
            if existing then
                -- Update existing member if received data is newer or has better info
                if not existing.role and receivedMember.role then
                    existing.role = receivedMember.role
                    self.Debug("TRACE", "MemberManager: Updated role for", receivedMember.name, "to", receivedMember.role)
                end
                
                if not existing.rating and receivedMember.rating and receivedMember.rating > 0 then
                    existing.rating = receivedMember.rating
                    self.Debug("TRACE", "MemberManager: Updated rating for", receivedMember.name, "to", receivedMember.rating)
                end
                
                if not existing.level and receivedMember.level then
                    existing.level = receivedMember.level
                end
            else
                -- Add new member to shared member list (regardless of group status)
                local newMember = {
                    name = receivedMember.name,
                    class = receivedMember.class,
                    classLocalized = receivedMember.classLocalized or receivedMember.class,
                    level = receivedMember.level or 80,
                    role = receivedMember.role or "DPS",
                    source = "SHARED_" .. (receivedMember.source or "UNKNOWN"),
                    rating = receivedMember.rating or 0,
                    timestamp = receivedMember.timestamp or now
                }
                
                table.insert(sharedMemberList, newMember)
                mergedCount = mergedCount + 1
                
                self.Debug("TRACE", "MemberManager: Added shared member", receivedMember.name, "from", receivedMember.source)
            end
        end
    end
    
    if mergedCount > 0 then
        self.Debug("INFO", "MemberManager: Merged", mergedCount, "new members from", data.sender)
        
        -- Update UI if we have significant new members
        if addon.MainFrame and addon.MainFrame.RefreshMemberDisplay then
            C_Timer.After(1, function()
                addon.MainFrame:RefreshMemberDisplay()
            end)
        else
            -- Fallback: trigger via UpdateMemberList call which should refresh UI
            C_Timer.After(1, function()
                self:UpdateMemberList()
            end)
        end
    else
        self.Debug("DEBUG", "MemberManager: No new members to merge from", data.sender)
    end
end

-- Check if sync is currently in progress
function MemberManager:IsSyncInProgress()
    -- Check if group sync is being applied in MainFrame
    if addon.MainFrame and addon.MainFrame.IsSyncInProgress then
        return addon.MainFrame:IsSyncInProgress()
    end
    return false
end

-- Check if we should auto-share roster (significant changes)
function MemberManager:CheckAutoRosterShare()
    local currentCount = #memberList
    
    if not self.lastMemberCount then
        self.lastMemberCount = currentCount
        return false
    end
    
    local changePercentage = math.abs(currentCount - self.lastMemberCount) / math.max(self.lastMemberCount, 1)
    
    if changePercentage > 0.1 then -- 10% change threshold
        self.Debug("DEBUG", "MemberManager: Significant member list change detected:", self.lastMemberCount, "->", currentCount)
        self.lastMemberCount = currentCount
        return true
    end
    
    self.lastMemberCount = currentCount
    return false
end