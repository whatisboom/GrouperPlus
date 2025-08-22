local addonName, addon = ...

local LibStub = LibStub
local AceEvent = LibStub("AceEvent-3.0")
local AceTimer = LibStub("AceTimer-3.0")

local MemberStateManager = {}
addon.MemberStateManager = MemberStateManager

for k, v in pairs(addon.DebugMixin) do
    MemberStateManager[k] = v
end
MemberStateManager:InitDebug("MemberState")

AceEvent:Embed(MemberStateManager)
AceTimer:Embed(MemberStateManager)

local memberState = {
    members = {},
    lastUpdate = 0,
    updateThrottle = 1.0
}

local MEMBER_SOURCES = {
    GUILD = "GUILD",
    PARTY = "PARTY", 
    RAID = "RAID",
    SHARED = "SHARED",
    MANUAL = "MANUAL"
}

function MemberStateManager:OnInitialize()
    self.Debug("INFO", "Initializing MemberStateManager")
    
    self.memberState = memberState
    self.MEMBER_SOURCES = MEMBER_SOURCES
    
    self:RegisterEvents()
    self.Debug("DEBUG", "MemberStateManager initialized successfully")
end

function MemberStateManager:RegisterEvents()
    self.Debug("TRACE", "Registering member state events")
    
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecializationChanged")
end

function MemberStateManager:AddMember(memberData)
    if not memberData or not memberData.name then
        self.Debug("WARN", "Invalid member data provided to AddMember")
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberData.name)
    if not normalizedName then
        self.Debug("WARN", "Failed to normalize member name:", memberData.name)
        return false
    end
    
    local existingMember = memberState.members[normalizedName]
    if existingMember then
        self:UpdateMember(normalizedName, memberData)
        return true
    end
    
    local member = {
        name = normalizedName,
        class = memberData.class or "UNKNOWN",
        classLocalized = memberData.classLocalized or memberData.class or "Unknown",
        level = memberData.level or addon.WoWAPIWrapper:GetMaxPlayerLevel(),
        role = memberData.role or "DPS",
        source = memberData.source or MEMBER_SOURCES.MANUAL,
        rating = memberData.rating or 0,
        online = memberData.online ~= false,
        groupId = nil,
        lastSeen = addon.WoWAPIWrapper:GetServerTime(),
        addedTime = addon.WoWAPIWrapper:GetServerTime()
    }
    
    memberState.members[normalizedName] = member
    self.Debug("INFO", "Added member:", normalizedName, "from source:", member.source)
    
    self:FireEvent("MEMBER_ADDED", member)
    return true
end

function MemberStateManager:UpdateMember(memberName, updates)
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    local member = memberState.members[normalizedName]
    
    if not member then
        self.Debug("WARN", "Attempted to update non-existent member:", normalizedName)
        return false
    end
    
    local changed = false
    local oldData = {}
    
    for key, value in pairs(updates) do
        if key ~= "name" and member[key] ~= value then
            oldData[key] = member[key]
            member[key] = value
            changed = true
        end
    end
    
    if changed then
        member.lastSeen = addon.WoWAPIWrapper:GetServerTime()
        self.Debug("DEBUG", "Updated member:", normalizedName, "changed fields:", self:TableToString(oldData))
        self:FireEvent("MEMBER_UPDATED", member, oldData)
    end
    
    return changed
end

function MemberStateManager:RemoveMember(memberName)
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    local member = memberState.members[normalizedName]
    
    if not member then
        self.Debug("WARN", "Attempted to remove non-existent member:", normalizedName)
        return false
    end
    
    memberState.members[normalizedName] = nil
    self.Debug("INFO", "Removed member:", normalizedName)
    
    self:FireEvent("MEMBER_REMOVED", member)
    return true
end

function MemberStateManager:GetMember(memberName)
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    return memberState.members[normalizedName]
end

function MemberStateManager:GetAllMembers()
    local members = {}
    for _, member in pairs(memberState.members) do
        table.insert(members, member)
    end
    return members
end

function MemberStateManager:GetAvailableMembers()
    local members = {}
    for _, member in pairs(memberState.members) do
        if not member.groupId then
            table.insert(members, member)
        end
    end
    return members
end

function MemberStateManager:GetMembersBySource(source)
    local members = {}
    for _, member in pairs(memberState.members) do
        if member.source == source then
            table.insert(members, member)
        end
    end
    return members
end

function MemberStateManager:GetMembersByRole(role)
    local members = {}
    for _, member in pairs(memberState.members) do
        if member.role == role then
            table.insert(members, member)
        end
    end
    return members
end

function MemberStateManager:AssignMemberToGroup(memberName, groupId)
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    local member = memberState.members[normalizedName]
    
    if not member then
        self.Debug("WARN", "Cannot assign non-existent member to group:", normalizedName)
        return false
    end
    
    local oldGroupId = member.groupId
    member.groupId = groupId
    
    self.Debug("INFO", "Assigned member", normalizedName, "to group", groupId, "(was in", oldGroupId, ")")
    self:FireEvent("MEMBER_GROUP_CHANGED", member, oldGroupId, groupId)
    
    return true
end

function MemberStateManager:RemoveMemberFromGroup(memberName)
    return self:AssignMemberToGroup(memberName, nil)
end

function MemberStateManager:GetMembersInGroup(groupId)
    local members = {}
    for _, member in pairs(memberState.members) do
        if member.groupId == groupId then
            table.insert(members, member)
        end
    end
    return members
end

function MemberStateManager:ClearAllGroupAssignments()
    local changedMembers = {}
    
    for _, member in pairs(memberState.members) do
        if member.groupId then
            local oldGroupId = member.groupId
            member.groupId = nil
            table.insert(changedMembers, {member = member, oldGroupId = oldGroupId})
        end
    end
    
    if #changedMembers > 0 then
        self.Debug("INFO", "Cleared group assignments for", #changedMembers, "members")
        for _, data in ipairs(changedMembers) do
            self:FireEvent("MEMBER_GROUP_CHANGED", data.member, data.oldGroupId, nil)
        end
    end
    
    return #changedMembers
end

function MemberStateManager:RefreshFromSources()
    local now = addon.WoWAPIWrapper:GetTime()
    if now - memberState.lastUpdate < memberState.updateThrottle then
        self.Debug("TRACE", "Skipping refresh - throttled")
        return
    end
    
    memberState.lastUpdate = now
    self.Debug("DEBUG", "Refreshing member data from all sources")
    
    local discovered = {}
    local channels = addon.WoWAPIWrapper:GetEnabledChannels()
    
    for _, channel in ipairs(channels) do
        local members = {}
        
        if channel == "GUILD" then
            members = addon.WoWAPIWrapper:GetGuildMembers()
        elseif channel == "PARTY" or channel == "RAID" then
            members = addon.WoWAPIWrapper:GetGroupMembers()
        end
        
        for _, memberData in ipairs(members) do
            if memberData.level == addon.WoWAPIWrapper:GetMaxPlayerLevel() or 
               (addon.settings and addon.settings.debug and addon.settings.debug.enabled and addon.settings.debug.ignoreMaxLevel) then
                
                local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberData.name)
                if normalizedName and not discovered[normalizedName] then
                    discovered[normalizedName] = memberData
                    
                    local existingMember = self:GetMember(normalizedName)
                    if existingMember then
                        self:UpdateMember(normalizedName, {
                            level = memberData.level,
                            online = memberData.online,
                            source = memberData.source,
                            lastSeen = addon.WoWAPIWrapper:GetServerTime()
                        })
                    else
                        self:AddMember(memberData)
                    end
                end
            end
        end
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if playerInfo then
        playerInfo.role = addon.WoWAPIWrapper:GetPlayerRole()
        playerInfo.source = MEMBER_SOURCES.MANUAL
        playerInfo.online = true
        
        local existingPlayer = self:GetMember(playerInfo.fullName)
        if existingPlayer then
            self:UpdateMember(playerInfo.fullName, playerInfo)
        else
            self:AddMember(playerInfo)
        end
    end
    
    self:FireEvent("MEMBERS_REFRESHED", discovered)
end

function MemberStateManager:GetShareableData()
    local shareableMembers = {}
    local now = addon.WoWAPIWrapper:GetServerTime()
    
    for _, member in pairs(memberState.members) do
        if member.online and member.source ~= MEMBER_SOURCES.SHARED then
            table.insert(shareableMembers, {
                name = member.name,
                class = member.class,
                classLocalized = member.classLocalized,
                level = member.level,
                role = member.role,
                source = member.source,
                rating = member.rating,
                timestamp = now
            })
        end
    end
    
    self.Debug("DEBUG", "Prepared", #shareableMembers, "members for sharing")
    return shareableMembers
end

function MemberStateManager:ImportSharedData(sharedMembers, sender)
    if not sharedMembers or type(sharedMembers) ~= "table" then
        self.Debug("WARN", "Invalid shared member data from:", sender)
        return 0
    end
    
    local imported = 0
    
    for _, memberData in ipairs(sharedMembers) do
        if memberData.name and memberData.class then
            local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberData.name)
            local existingMember = self:GetMember(normalizedName)
            
            if not existingMember then
                memberData.source = MEMBER_SOURCES.SHARED
                if self:AddMember(memberData) then
                    imported = imported + 1
                end
            else
                local updates = {}
                if not existingMember.role and memberData.role then
                    updates.role = memberData.role
                end
                if not existingMember.rating and memberData.rating and memberData.rating > 0 then
                    updates.rating = memberData.rating
                end
                
                if next(updates) then
                    self:UpdateMember(normalizedName, updates)
                end
            end
        end
    end
    
    if imported > 0 then
        self.Debug("INFO", "Imported", imported, "shared members from:", sender)
        self:FireEvent("SHARED_MEMBERS_IMPORTED", imported, sender)
    end
    
    return imported
end

function MemberStateManager:OnGuildRosterUpdate()
    self.Debug("TRACE", "Guild roster updated")
    self:ScheduleTimer("RefreshFromSources", 0.5)
end

function MemberStateManager:OnGroupRosterUpdate()
    self.Debug("TRACE", "Group roster updated")
    self:ScheduleTimer("RefreshFromSources", 0.5)
end

function MemberStateManager:OnSpecializationChanged(event, unitID)
    if unitID == "player" then
        local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
        if playerInfo then
            local newRole = addon.WoWAPIWrapper:GetPlayerRole()
            self:UpdateMember(playerInfo.fullName, {role = newRole})
            self.Debug("INFO", "Player role updated to:", newRole)
        end
    end
end

function MemberStateManager:TableToString(tbl)
    if not tbl or type(tbl) ~= "table" then
        return tostring(tbl)
    end
    
    local parts = {}
    for k, v in pairs(tbl) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

function MemberStateManager:FireEvent(eventName, ...)
    self.Debug("TRACE", "Firing event:", eventName)
    self:SendMessage("GROUPERPLUS_" .. eventName, ...)
end

return MemberStateManager