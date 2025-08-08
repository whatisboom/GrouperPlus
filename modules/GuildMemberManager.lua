local addonName, addon = ...

-- Guild Member Management Module
-- Handles guild member list retrieval, filtering, and group membership tracking

local GuildMemberManager = {}
addon.GuildMemberManager = GuildMemberManager

for k, v in pairs(addon.DebugMixin) do
    GuildMemberManager[k] = v
end
GuildMemberManager:InitDebug("GuildMgr")

-- Private state
local memberList = {}
local membersInGroups = {} -- Track which members are assigned to groups
local MAX_LEVEL = GetMaxPlayerLevel()

-- Initialize the member list
function GuildMemberManager:Initialize(clearGroups)
    self.Debug("DEBUG", "GuildMemberManager: Initializing", clearGroups and "(clearing group tracking)" or "(preserving group tracking)")
    table.wipe(memberList)
    -- Only wipe membersInGroups if explicitly requested (e.g., when clearing all groups)
    if clearGroups then
        table.wipe(membersInGroups)
    end
end

-- Update guild member list with filtering and role detection
function GuildMemberManager:UpdateMemberList()
    self.Debug("DEBUG", "GuildMemberManager: Starting guild roster update")
    self.Debug("DEBUG", "GuildMemberManager: Current membersInGroups count:", next(membersInGroups) and "has members" or "empty")
    
    table.wipe(memberList)
    
    if not IsInGuild() then
        self.Debug("WARN", "GuildMemberManager: Player is not in a guild")
        return memberList
    end
    
    local numMembers = GetNumGuildMembers()
    self.Debug("DEBUG", "GuildMemberManager: Found", numMembers, "guild members")
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        if online and level == MAX_LEVEL then
            -- Only add if not already in a group
            if not membersInGroups[name] then
                local memberData = {
                    name = name,
                    class = classFileName or class,
                    classLocalized = class,
                    level = level
                }
                
                -- Add role information for all members, especially the player
                if addon.AutoFormation and addon.AutoFormation.GetPlayerRole then
                    memberData.role = addon.AutoFormation:GetPlayerRole(name)
                    self.Debug("TRACE", "GuildMemberManager: Determined role for", name, ":", memberData.role)
                end
                
                -- For the player, ensure we get the most current role
                local playerName = UnitName("player")
                local playerFullName = UnitName("player") .. "-" .. GetRealmName()
                self.Debug("DEBUG", "GuildMemberManager: Checking if", name, "equals player", playerName, "or", playerFullName)
                if name == playerName or name == playerFullName then
                    local currentSpec = GetSpecialization()
                    self.Debug("DEBUG", "GuildMemberManager: Player spec ID:", currentSpec)
                    if currentSpec then
                        local role = GetSpecializationRole(currentSpec)
                        self.Debug("DEBUG", "GuildMemberManager: Raw role from GetSpecializationRole:", role)
                        if role == "TANK" then
                            memberData.role = "TANK"
                        elseif role == "HEALER" then
                            memberData.role = "HEALER"
                        else
                            memberData.role = "DPS"
                        end
                        self.Debug("INFO", "GuildMemberManager: Updated player's own role to:", memberData.role, "from spec", currentSpec, "raw role:", role)
                    else
                        self.Debug("WARN", "GuildMemberManager: Could not get player specialization")
                    end
                else
                    self.Debug("TRACE", "GuildMemberManager: Member", name, "is not the player")
                end
                
                table.insert(memberList, memberData)
                self.Debug("TRACE", "GuildMemberManager: Added member", name, "level", level, "class:", classFileName or class, "role:", memberData.role or "unknown")
            else
                self.Debug("INFO", "GuildMemberManager: Skipped member", name, "- already in group")
            end
        else
            if not online then
                self.Debug("TRACE", "GuildMemberManager: Skipped member", name, "- offline")
            elseif level ~= MAX_LEVEL then
                self.Debug("TRACE", "GuildMemberManager: Skipped member", name, "- level", level, "(not max level", MAX_LEVEL, ")")
            end
        end
    end
    
    self.Debug("INFO", "GuildMemberManager: Found", #memberList, "online max level members (after filtering out grouped members)")
    
    return memberList
end

-- Get the current member list
function GuildMemberManager:GetMemberList()
    return memberList
end

-- Get member count
function GuildMemberManager:GetMemberCount()
    return #memberList
end

-- Check if a member is in a group
function GuildMemberManager:IsMemberInGroup(memberName)
    return membersInGroups[memberName] == true
end

-- Set a member's group status
function GuildMemberManager:SetMemberInGroup(memberName, inGroup)
    if inGroup then
        membersInGroups[memberName] = true
        self.Debug("DEBUG", "GuildMemberManager: Added", memberName, "to membersInGroups tracking")
    else
        membersInGroups[memberName] = nil
        self.Debug("DEBUG", "GuildMemberManager: Removed", memberName, "from membersInGroups tracking")
    end
end

-- Clear all group memberships (used when clearing all groups)
function GuildMemberManager:ClearAllGroupMemberships()
    self.Debug("DEBUG", "GuildMemberManager: Clearing all group memberships")
    table.wipe(membersInGroups)
end

-- Get all members currently in groups
function GuildMemberManager:GetMembersInGroups()
    local members = {}
    for memberName, _ in pairs(membersInGroups) do
        table.insert(members, memberName)
    end
    return members
end

-- Debug function to log current state
function GuildMemberManager:DebugState()
    self.Debug("DEBUG", "GuildMemberManager: Current membersInGroups:")
    for name, _ in pairs(membersInGroups) do
        self.Debug("DEBUG", "  -", name)
    end
end

-- Find member data by name
function GuildMemberManager:FindMemberByName(memberName)
    for _, member in ipairs(memberList) do
        if member.name == memberName then
            return member
        end
    end
    return nil
end