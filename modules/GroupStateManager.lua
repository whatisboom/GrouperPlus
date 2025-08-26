local addonName, addon = ...

local LibStub = LibStub
local AceEvent = LibStub("AceEvent-3.0")

local GroupStateManager = {}
addon.GroupStateManager = GroupStateManager

addon.DebugMixin:InjectInto(GroupStateManager, "GroupState")

AceEvent:Embed(GroupStateManager)

local groupState = {
    groups = {},
    nextGroupId = 1,
    maxGroupSize = 5
}

function GroupStateManager:OnInitialize()
    self.Debug("INFO", "Initializing GroupStateManager")
    
    self.groupState = groupState
    self:RegisterMessages()
    
    self.Debug("DEBUG", "GroupStateManager initialized successfully")
end

function GroupStateManager:RegisterMessages()
    self.Debug("TRACE", "Registering group state messages")
    
    self:RegisterMessage("GROUPERPLUS_MEMBER_ADDED", "OnMemberAdded")
    self:RegisterMessage("GROUPERPLUS_MEMBER_REMOVED", "OnMemberRemoved")
    self:RegisterMessage("GROUPERPLUS_MEMBER_GROUP_CHANGED", "OnMemberGroupChanged")
end

function GroupStateManager:CreateGroup(groupData)
    local groupId = groupData and groupData.id or self:GenerateGroupId()
    
    if groupState.groups[groupId] then
        self.Debug("WARN", "Group already exists:", groupId)
        return nil
    end
    
    local group = {
        id = groupId,
        name = groupData and groupData.name or ("Group " .. groupId),
        members = {},
        createdTime = addon.WoWAPIWrapper:GetServerTime(),
        maxSize = groupData and groupData.maxSize or groupState.maxGroupSize,
        assignedKeystone = {
            mapID = nil,
            level = nil,
            dungeonName = nil,
            assignedPlayer = nil,
            timestamp = nil
        }
    }
    
    groupState.groups[groupId] = group
    self.Debug("INFO", "Created group:", groupId, "name:", group.name)
    
    self:FireEvent("GROUP_CREATED", group)
    return group
end

function GroupStateManager:RemoveGroup(groupId)
    local group = groupState.groups[groupId]
    if not group then
        self.Debug("WARN", "Cannot remove non-existent group:", groupId)
        return false
    end
    
    for _, memberName in ipairs(group.members) do
        if addon.MemberStateManager then
            addon.MemberStateManager:RemoveMemberFromGroup(memberName)
        end
    end
    
    groupState.groups[groupId] = nil
    self.Debug("INFO", "Removed group:", groupId)
    
    self:FireEvent("GROUP_REMOVED", group)
    return true
end

function GroupStateManager:GetGroup(groupId)
    return groupState.groups[groupId]
end

function GroupStateManager:GetAllGroups()
    local groups = {}
    for _, group in pairs(groupState.groups) do
        table.insert(groups, group)
    end
    
    table.sort(groups, function(a, b) return a.id < b.id end)
    return groups
end

function GroupStateManager:AddMemberToGroup(memberName, groupId)
    local group = groupState.groups[groupId]
    if not group then
        self.Debug("WARN", "Cannot add member to non-existent group:", groupId)
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    if not normalizedName then
        self.Debug("WARN", "Invalid member name:", memberName)
        return false
    end
    
    if #group.members >= group.maxSize then
        self.Debug("WARN", "Group", groupId, "is full (", #group.members, "/", group.maxSize, ")")
        return false
    end
    
    for _, existingMember in ipairs(group.members) do
        if existingMember == normalizedName then
            self.Debug("WARN", "Member", normalizedName, "already in group", groupId)
            return false
        end
    end
    
    table.insert(group.members, normalizedName)
    
    if addon.MemberStateManager then
        addon.MemberStateManager:AssignMemberToGroup(normalizedName, groupId)
    end
    
    self.Debug("INFO", "Added member", normalizedName, "to group", groupId, "(", #group.members, "/", group.maxSize, ")")
    self:FireEvent("MEMBER_ADDED_TO_GROUP", normalizedName, group)
    
    return true
end

function GroupStateManager:RemoveMemberFromGroup(memberName, groupId)
    local group = groupState.groups[groupId]
    if not group then
        self.Debug("WARN", "Cannot remove member from non-existent group:", groupId)
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    if not normalizedName then
        self.Debug("WARN", "Invalid member name:", memberName)
        return false
    end
    
    for i, existingMember in ipairs(group.members) do
        if existingMember == normalizedName then
            table.remove(group.members, i)
            
            if addon.MemberStateManager then
                addon.MemberStateManager:RemoveMemberFromGroup(normalizedName)
            end
            
            self.Debug("INFO", "Removed member", normalizedName, "from group", groupId, "(", #group.members, "/", group.maxSize, ")")
            self:FireEvent("MEMBER_REMOVED_FROM_GROUP", normalizedName, group)
            
            return true
        end
    end
    
    self.Debug("WARN", "Member", normalizedName, "not found in group", groupId)
    return false
end

function GroupStateManager:MoveMemberBetweenGroups(memberName, fromGroupId, toGroupId)
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(memberName)
    if not normalizedName then
        self.Debug("WARN", "Invalid member name:", memberName)
        return false
    end
    
    local fromGroup = groupState.groups[fromGroupId]
    local toGroup = groupState.groups[toGroupId]
    
    if not fromGroup then
        self.Debug("WARN", "Source group does not exist:", fromGroupId)
        return false
    end
    
    if not toGroup then
        self.Debug("WARN", "Target group does not exist:", toGroupId)
        return false
    end
    
    if #toGroup.members >= toGroup.maxSize then
        self.Debug("WARN", "Target group", toGroupId, "is full")
        return false
    end
    
    if self:RemoveMemberFromGroup(normalizedName, fromGroupId) then
        return self:AddMemberToGroup(normalizedName, toGroupId)
    end
    
    return false
end

function GroupStateManager:GetGroupComposition(groupId)
    local group = groupState.groups[groupId]
    if not group then
        return nil
    end
    
    local composition = {
        groupId = groupId,
        groupName = group.name,
        members = {},
        roleCount = {TANK = 0, HEALER = 0, DPS = 0},
        totalMembers = #group.members,
        maxSize = group.maxSize
    }
    
    for _, memberName in ipairs(group.members) do
        local member = addon.MemberStateManager and addon.MemberStateManager:GetMember(memberName)
        if member then
            table.insert(composition.members, {
                name = member.name,
                class = member.class,
                role = member.role,
                rating = member.rating
            })
            
            composition.roleCount[member.role] = (composition.roleCount[member.role] or 0) + 1
        else
            table.insert(composition.members, {
                name = memberName,
                class = "UNKNOWN",
                role = "DPS",
                rating = 0
            })
            composition.roleCount.DPS = composition.roleCount.DPS + 1
        end
    end
    
    return composition
end

function GroupStateManager:GetAllGroupCompositions()
    local compositions = {}
    
    for groupId, _ in pairs(groupState.groups) do
        local composition = self:GetGroupComposition(groupId)
        if composition then
            table.insert(compositions, composition)
        end
    end
    
    table.sort(compositions, function(a, b) return a.groupId < b.groupId end)
    return compositions
end

function GroupStateManager:ClearAllGroups()
    local removedGroups = {}
    
    for groupId, group in pairs(groupState.groups) do
        table.insert(removedGroups, group)
    end
    
    groupState.groups = {}
    groupState.nextGroupId = 1
    
    if addon.MemberStateManager then
        addon.MemberStateManager:ClearAllGroupAssignments()
    end
    
    self.Debug("INFO", "Cleared all groups (", #removedGroups, "groups removed)")
    
    for _, group in ipairs(removedGroups) do
        self:FireEvent("GROUP_REMOVED", group)
    end
    
    self:FireEvent("ALL_GROUPS_CLEARED")
    return #removedGroups
end

function GroupStateManager:SwapMembers(member1Name, member2Name)
    local normalizedName1 = addon.WoWAPIWrapper:NormalizePlayerName(member1Name)
    local normalizedName2 = addon.WoWAPIWrapper:NormalizePlayerName(member2Name)
    
    if not normalizedName1 or not normalizedName2 then
        self.Debug("WARN", "Invalid member names for swap:", member1Name, member2Name)
        return false
    end
    
    local member1 = addon.MemberStateManager and addon.MemberStateManager:GetMember(normalizedName1)
    local member2 = addon.MemberStateManager and addon.MemberStateManager:GetMember(normalizedName2)
    
    if not member1 or not member2 then
        self.Debug("WARN", "One or both members not found for swap:", normalizedName1, normalizedName2)
        return false
    end
    
    local group1Id = member1.groupId
    local group2Id = member2.groupId
    
    if not group1Id or not group2Id then
        self.Debug("WARN", "One or both members not in groups for swap")
        return false
    end
    
    if self:RemoveMemberFromGroup(normalizedName1, group1Id) and 
       self:RemoveMemberFromGroup(normalizedName2, group2Id) then
        
        local success1 = self:AddMemberToGroup(normalizedName1, group2Id)
        local success2 = self:AddMemberToGroup(normalizedName2, group1Id)
        
        if success1 and success2 then
            self.Debug("INFO", "Successfully swapped members:", normalizedName1, "↔", normalizedName2)
            self:FireEvent("MEMBERS_SWAPPED", normalizedName1, normalizedName2, group1Id, group2Id)
            return true
        else
            self.Debug("ERROR", "Partial swap failure - attempting rollback")
            if success1 then self:RemoveMemberFromGroup(normalizedName1, group2Id) end
            if success2 then self:RemoveMemberFromGroup(normalizedName2, group1Id) end
            self:AddMemberToGroup(normalizedName1, group1Id)
            self:AddMemberToGroup(normalizedName2, group2Id)
        end
    end
    
    return false
end

function GroupStateManager:GenerateGroupId()
    local id = groupState.nextGroupId
    groupState.nextGroupId = groupState.nextGroupId + 1
    return id
end

function GroupStateManager:GetShareableData()
    local shareableGroups = {}
    
    for _, group in pairs(groupState.groups) do
        table.insert(shareableGroups, {
            id = group.id,
            name = group.name,
            members = group.members,
            maxSize = group.maxSize,
            timestamp = addon.WoWAPIWrapper:GetServerTime()
        })
    end
    
    self.Debug("DEBUG", "Prepared", #shareableGroups, "groups for sharing")
    return shareableGroups
end

function GroupStateManager:ImportSharedData(sharedGroups, sender)
    if not sharedGroups or type(sharedGroups) ~= "table" then
        self.Debug("WARN", "Invalid shared group data from:", sender)
        return 0
    end
    
    local imported = 0
    
    for _, groupData in ipairs(sharedGroups) do
        if groupData.id and groupData.members then
            local existingGroup = groupState.groups[groupData.id]
            if not existingGroup then
                if self:CreateGroup(groupData) then
                    for _, memberName in ipairs(groupData.members) do
                        self:AddMemberToGroup(memberName, groupData.id)
                    end
                    imported = imported + 1
                end
            end
        end
    end
    
    if imported > 0 then
        self.Debug("INFO", "Imported", imported, "shared groups from:", sender)
        self:FireEvent("SHARED_GROUPS_IMPORTED", imported, sender)
    end
    
    return imported
end

function GroupStateManager:OnMemberAdded(event, member)
    self.Debug("TRACE", "Member added event received:", member.name)
end

function GroupStateManager:OnMemberRemoved(event, member)
    if member.groupId then
        self:RemoveMemberFromGroup(member.name, member.groupId)
    end
end

function GroupStateManager:OnMemberGroupChanged(event, member, oldGroupId, newGroupId)
    self.Debug("TRACE", "Member group changed:", member.name, "from", oldGroupId, "to", newGroupId)
end

function GroupStateManager:AssignKeystoneToGroup(groupId, keystoneData)
    local group = groupState.groups[groupId]
    if not group then
        self.Debug("WARN", "Cannot assign keystone to non-existent group:", groupId)
        return false
    end
    
    if not keystoneData or not keystoneData.mapID or not keystoneData.level then
        self.Debug("WARN", "Invalid keystone data for assignment")
        return false
    end
    
    group.assignedKeystone = {
        mapID = keystoneData.mapID,
        level = keystoneData.level,
        dungeonName = keystoneData.dungeonName,
        assignedPlayer = keystoneData.assignedPlayer,
        timestamp = addon.WoWAPIWrapper:GetServerTime()
    }
    
    self.Debug("INFO", "Assigned keystone to group", groupId, ":", keystoneData.dungeonName, "+", keystoneData.level, "from", keystoneData.assignedPlayer)
    self:FireEvent("KEYSTONE_ASSIGNED", group, keystoneData)
    return true
end

function GroupStateManager:RemoveKeystoneFromGroup(groupId)
    local group = groupState.groups[groupId]
    if not group then
        self.Debug("WARN", "Cannot remove keystone from non-existent group:", groupId)
        return false
    end
    
    local oldKeystone = group.assignedKeystone
    group.assignedKeystone = {
        mapID = nil,
        level = nil,
        dungeonName = nil,
        assignedPlayer = nil,
        timestamp = nil
    }
    
    self.Debug("INFO", "Removed keystone from group", groupId)
    self:FireEvent("KEYSTONE_REMOVED", group, oldKeystone)
    return true
end

function GroupStateManager:GetGroupKeystone(groupId)
    local group = groupState.groups[groupId]
    if not group then
        return nil
    end
    
    local keystone = group.assignedKeystone
    if keystone.mapID and keystone.level then
        return {
            mapID = keystone.mapID,
            level = keystone.level,
            dungeonName = keystone.dungeonName,
            assignedPlayer = keystone.assignedPlayer,
            timestamp = keystone.timestamp,
            hasKeystone = true
        }
    end
    
    return { hasKeystone = false }
end

function GroupStateManager:GetAllGroupKeystones()
    local keystones = {}
    
    for groupId, group in pairs(groupState.groups) do
        local keystone = self:GetGroupKeystone(groupId)
        keystones[groupId] = keystone
    end
    
    return keystones
end

function GroupStateManager:IsKeystoneAssigned(mapID, level)
    for _, group in pairs(groupState.groups) do
        local keystone = group.assignedKeystone
        if keystone.mapID == mapID and keystone.level == level then
            return true, group.id
        end
    end
    return false, nil
end

function GroupStateManager:FireEvent(eventName, ...)
    self.Debug("TRACE", "Firing event:", eventName)
    self:SendMessage("GROUPERPLUS_" .. eventName, ...)
end

return GroupStateManager