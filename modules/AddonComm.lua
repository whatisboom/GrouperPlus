local addonName, addon = ...

local AddonComm = {}
addon.AddonComm = AddonComm

addon.DebugMixin:InjectInto(AddonComm, "Comm")

-- Simple serialization functions for addon communication
function addon:Serialize(data)
    if type(data) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(data) do
            if not first then
                result = result .. ","
            end
            first = false
            
            local key = type(k) == "string" and ("[" .. string.format("%q", k) .. "]") or ("[" .. tostring(k) .. "]")
            local value = self:Serialize(v)
            result = result .. key .. "=" .. value
        end
        result = result .. "}"
        return result
    elseif type(data) == "string" then
        return string.format("%q", data)
    else
        return tostring(data)
    end
end

function addon:Deserialize(str)
    if not str or str == "" then
        return false, nil
    end
    
    local success, result = pcall(loadstring("return " .. str))
    return success, result
end

local COMM_PREFIX = "GrouperPlus"
local MESSAGE_TYPES = {
    VERSION_CHECK = "VERSION_CHECK",
    VERSION_RESPONSE = "VERSION_RESPONSE",
    GROUP_SYNC = "GROUP_SYNC",
    PLAYER_DATA = "PLAYER_DATA",
    RAIDERIO_DATA = "RAIDERIO_DATA",
    FORMATION_REQUEST = "FORMATION_REQUEST",
    FORMATION_RESPONSE = "FORMATION_RESPONSE",
    KEYSTONE_DATA = "KEYSTONE_DATA",
    MEMBER_ROSTER_REQUEST = "MEMBER_ROSTER_REQUEST",
    MEMBER_ROSTER_DATA = "MEMBER_ROSTER_DATA",
    SESSION_CREATE = "SESSION_CREATE",
    SESSION_JOIN = "SESSION_JOIN",
    SESSION_LEAVE = "SESSION_LEAVE",
    SESSION_WHITELIST = "SESSION_WHITELIST",
    SESSION_FINALIZE = "SESSION_FINALIZE",
    SESSION_STATE = "SESSION_STATE",
    SESSION_END = "SESSION_END"
}

local connectedUsers = {}
local messageQueue = {}
local lastSyncTime = {}
local lastSyncedGroupState = nil
local lastSyncAppliedTime = nil
local lastRosterShareTime = nil
local playerRole = nil
local lastKnownSpec = nil

-- AceComm integration
local AceComm = nil

local function HandleIncomingMessage(prefix, serializedMessage, distribution, sender)
    local playerFullName = UnitName("player") .. "-" .. GetRealmName()
    if not serializedMessage or sender == playerFullName then
        return
    end
    
    -- Deserialize the message
    local success, message = addon:Deserialize(serializedMessage)
    if not success or not message then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "Failed to deserialize message from", sender)
        return
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received message from", sender, "type:", message.type)
    
    if message.type == MESSAGE_TYPES.VERSION_CHECK then
        AddonComm.Debug(addon.LOG_LEVEL.INFO, "Received version check from", sender, "- version:", message.data.addonVersion)
        AddonComm:SendVersionResponse(sender)
        
        -- Check if this is a new user
        local isNewUser = not connectedUsers[sender]
        
        connectedUsers[sender] = {
            version = message.version,
            addonVersion = message.data.addonVersion,
            lastSeen = GetServerTime()
        }
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Added/updated user in connected list:", sender)
        
        -- Request roster from new users after a brief delay
        if isNewUser then
            C_Timer.After(5, function()
                AddonComm:RequestMemberRoster()
            end)
        end
        
        -- Trigger version check when we receive version info
        if addon.VersionWarning then
            C_Timer.After(1, function()
                addon.VersionWarning:CheckForNewerVersions()
            end)
        end
        
    elseif message.type == MESSAGE_TYPES.VERSION_RESPONSE then
        AddonComm.Debug(addon.LOG_LEVEL.INFO, "Received version response from", sender, "- version:", message.data.addonVersion)
        connectedUsers[sender] = {
            version = message.version,
            addonVersion = message.data.addonVersion,
            lastSeen = GetServerTime()
        }
        
        if addon.VersionWarning then
            C_Timer.After(1, function()
                addon.VersionWarning:CheckForNewerVersions()
            end)
        end
        
    elseif message.type == MESSAGE_TYPES.GROUP_SYNC then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Processing GROUP_SYNC message from", sender)
        AddonComm:HandleGroupSync(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.PLAYER_DATA then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received player data from", sender)
        if addon.OnPlayerDataReceived then
            addon:OnPlayerDataReceived(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.RAIDERIO_DATA then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received RaiderIO data from", sender)
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:ProcessReceivedData(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.KEYSTONE_DATA then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received keystone data from", sender)
        if addon.Keystone then
            addon.Keystone:HandleKeystoneData(message.data, sender)
        end
        
    -- Session message handling
    elseif message.type == MESSAGE_TYPES.SESSION_CREATE then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_CREATE from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnSessionCreate(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.SESSION_JOIN then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_JOIN from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnSessionJoin(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.SESSION_LEAVE then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_LEAVE from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnSessionLeave(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.SESSION_WHITELIST then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_WHITELIST from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnWhitelistUpdate(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.SESSION_FINALIZE then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_FINALIZE from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnSessionFinalize(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.SESSION_STATE then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_STATE from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnSessionStateUpdate(message.data, sender)
        end
        
    elseif message.type == MESSAGE_TYPES.SESSION_END then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received SESSION_END from", sender)
        if AddonComm.SessionManager then
            AddonComm.SessionManager:OnSessionEnd(message.data, sender)
        end
        
    -- Member roster sharing
    elseif message.type == MESSAGE_TYPES.MEMBER_ROSTER_REQUEST then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received MEMBER_ROSTER_REQUEST from", sender)
        AddonComm:HandleMemberRosterRequest(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.MEMBER_ROSTER_DATA then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Received MEMBER_ROSTER_DATA from", sender)
        AddonComm:HandleMemberRosterData(message.data, sender)
        
    else
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Unhandled message type:", message.type, "from", sender)
    end
end

function AddonComm:Initialize()
    if not self.initialized then
        -- Debug LibStub and library availability
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "AddonComm:Initialize - LibStub available:", LibStub ~= nil)
        if LibStub then
            local aceComm = LibStub("AceComm-3.0", true)
            AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Direct LibStub AceComm-3.0 check:", aceComm ~= nil)
        end
        
        -- Get AceComm library and embed it into AddonComm
        local AceCommLib = addon.LibraryManager:GetAceComm()
        if not AceCommLib then
            AddonComm.Debug(addon.LOG_LEVEL.ERROR, "AceComm-3.0 library not available via LibraryManager")
            
            -- Try direct LibStub access as fallback
            if LibStub then
                AceCommLib = LibStub("AceComm-3.0", true)
                if AceCommLib then
                    AddonComm.Debug(addon.LOG_LEVEL.INFO, "Found AceComm-3.0 via direct LibStub access")
                else
                    AddonComm.Debug(addon.LOG_LEVEL.ERROR, "AceComm-3.0 not found via direct LibStub either")
                    return false
                end
            else
                AddonComm.Debug(addon.LOG_LEVEL.ERROR, "LibStub not available")
                return false
            end
        else
            AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "AceComm-3.0 found via LibraryManager")
        end
        
        -- Store the AceComm library reference
        AceComm = AceCommLib
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "AceComm-3.0 library stored, methods available:")
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "  SendCommMessage:", type(AceComm.SendCommMessage))
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "  RegisterComm:", type(AceComm.RegisterComm))
        
        -- Register communication prefix and callback
        AceComm:RegisterComm(COMM_PREFIX, HandleIncomingMessage)
        AddonComm.Debug(addon.LOG_LEVEL.INFO, "AddonComm initialized with AceComm-3.0, prefix:", COMM_PREFIX)
        
        self.initialized = true
        
        -- Start version check after initialization
        C_Timer.After(2, function()
            self:BroadcastVersionCheck()
        end)
        
        -- Start role monitoring after initialization
        C_Timer.After(1, function()
            self:StartRoleMonitoring()
        end)
    end
    
    return true
end

function AddonComm:SendMessage(messageType, data, target, priority, distribution)
    if not self.initialized then
        AddonComm.Debug(addon.LOG_LEVEL.ERROR, "AddonComm not initialized")
        return false
    end
    
    local message = {
        version = "1.0",
        type = messageType,
        timestamp = GetServerTime(),
        sender = UnitName("player") .. "-" .. GetRealmName(),
        data = data or {}
    }
    
    local serialized = addon:Serialize(message)
    if not serialized then
        AddonComm.Debug(addon.LOG_LEVEL.ERROR, "Failed to serialize message of type:", messageType)
        return false
    end
    
    -- Default values
    priority = priority or "NORMAL"
    distribution = distribution or "GUILD"
    
    -- Send via AceComm - it handles chunking automatically!
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Attempting to send via AceComm:", "prefix=" .. COMM_PREFIX, "distribution=" .. distribution, "target=" .. (target or "nil"), "priority=" .. priority, "message_size=" .. string.len(serialized))
    
    -- AceComm API: SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
    -- Valid prio values: "BULK", "NORMAL", "ALERT"
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "About to call AceComm:SendCommMessage, AceComm available:", AceComm ~= nil)
    
    if not AceComm then
        AddonComm.Debug(addon.LOG_LEVEL.ERROR, "AceComm library not available for SendCommMessage")
        return false
    end
    
    local result = AceComm:SendCommMessage(COMM_PREFIX, serialized, distribution, target, priority)
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "AceComm:SendCommMessage returned:", result, type(result))
    
    -- AceComm:SendCommMessage returns nil on success, false on failure
    local success = (result ~= false)
    
    if success then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Sent", messageType, "message via AceComm to", distribution, target and ("(target: " .. target .. ")") or "")
    else
        AddonComm.Debug(addon.LOG_LEVEL.ERROR, "Failed to send", messageType, "message via AceComm - prefix:", COMM_PREFIX, "dist:", distribution, "target:", tostring(target), "priority:", priority)
    end
    
    return success
end

function AddonComm:GetEnabledChannels()
    if not addon.settings or not addon.settings.communication then
        return {"GUILD"}
    end
    
    local channels = {}
    if addon.settings.communication.channels.GUILD then
        table.insert(channels, "GUILD")
    end
    if addon.settings.communication.channels.PARTY then
        table.insert(channels, "PARTY")
    end
    if addon.settings.communication.channels.RAID then
        table.insert(channels, "RAID")
    end
    
    return #channels > 0 and channels or {"GUILD"}
end

function AddonComm:IsChannelAvailable(channel)
    if channel == "GUILD" then
        return IsInGuild()
    elseif channel == "PARTY" then
        return IsInGroup() and not IsInRaid()
    elseif channel == "RAID" then
        return IsInRaid()
    end
    return false
end

function AddonComm:BroadcastVersionCheck()
    if not self.initialized then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "AddonComm not initialized, skipping version check broadcast")
        return
    end
    
    local channels = self:GetEnabledChannels()
    local availableChannels = {}
    
    -- Check which channels are available
    for _, channel in ipairs(channels) do
        if self:IsChannelAvailable(channel) then
            table.insert(availableChannels, channel)
        else
            AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Channel", channel, "not available for version check")
        end
    end
    
    if #availableChannels == 0 then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "No available channels for version check broadcast")
        return
    end
    
    local versionData = {
        addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    }
    
    for _, channel in ipairs(availableChannels) do
        self:SendMessage(MESSAGE_TYPES.VERSION_CHECK, versionData, nil, "NORMAL", channel)
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Version check broadcast sent successfully")
end

function AddonComm:SendVersionResponse(target)
    self:SendMessage(MESSAGE_TYPES.VERSION_RESPONSE, {
        addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    }, target)
end

function AddonComm:SyncGroupFormation(groups, bypassThrottle)
    if not groups then
        -- Allow empty groups array to sync "clear all groups" state
        groups = {}
    end
    
    local now = GetServerTime()
    
    -- Create a simple hash of the group state for comparison
    local currentStateHash = ""
    for i, group in ipairs(groups) do
        if group and group.members then
            for j, member in ipairs(group.members) do
                currentStateHash = currentStateHash .. (member.name or "") .. ":"
            end
        end
        currentStateHash = currentStateHash .. "|"
    end
    
    -- Check if we're trying to sync the exact same state
    if not bypassThrottle and lastSyncedGroupState == currentStateHash then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Group sync skipped - identical to last synced state")
        return
    end
    
    -- Apply throttling to both empty and non-empty groups to prevent sync loops
    if not bypassThrottle and lastSyncTime.groups and (now - lastSyncTime.groups) < 3 then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Group sync throttled - too recent (", now - lastSyncTime.groups, "seconds ago)")
        return
    end
    
    -- Prevent outgoing sync immediately after applying an incoming sync (cooldown period)
    if not bypassThrottle and lastSyncAppliedTime and (now - lastSyncAppliedTime) < 5 then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Group sync throttled - too soon after applying incoming sync (", now - lastSyncAppliedTime, "seconds ago)")
        return
    end
    
    if bypassThrottle then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Group sync throttle bypassed")
    end
    
    local syncData = {
        groups = {},
        timestamp = now,
        leader = UnitName("player") .. "-" .. GetRealmName()
    }
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "SyncGroupFormation: Input groups count:", #groups)
    
    for i, group in ipairs(groups) do
        if group and group.members then
            syncData.groups[i] = {
                members = {},
                avgRating = group.avgRating or 0
            }
            
            for j, member in ipairs(group.members) do
                if member and member.name then
                    syncData.groups[i].members[j] = {
                        name = member.name,
                        role = member.role,
                        rating = member.score or member.rating or 0,
                        class = member.class
                    }
                end
            end
        end
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "SyncGroupFormation: Prepared syncData with", #syncData.groups, "groups")
    
    -- Count total members for size estimation
    local totalMembers = 0
    for _, group in pairs(syncData.groups) do
        if group and group.members then
            totalMembers = totalMembers + #group.members
        end
    end
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "SyncGroupFormation: Sync data contains", totalMembers, "total members across", #syncData.groups, "groups")
    
    -- Send to ALL available channels to ensure cross-realm/cross-guild sync
    local allChannels = {"GUILD", "PARTY", "RAID"}
    local sentCount = 0
    
    for _, channel in ipairs(allChannels) do
        if self:IsChannelAvailable(channel) then
            -- AceComm automatically handles large messages with chunking!
            local success = self:SendMessage(MESSAGE_TYPES.GROUP_SYNC, syncData, nil, "NORMAL", channel)
            if success then
                sentCount = sentCount + 1
                AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Sent GROUP_SYNC to channel:", channel)
            else
                AddonComm.Debug(addon.LOG_LEVEL.ERROR, "Failed to send GROUP_SYNC to channel:", channel)
            end
        else
            AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Channel", channel, "not available for GROUP_SYNC")
        end
    end
    
    if sentCount > 0 then
        lastSyncTime.groups = now
        lastSyncedGroupState = currentStateHash
        AddonComm.Debug(addon.LOG_LEVEL.INFO, "Synced group formation with", #syncData.groups, "groups to", sentCount, "channels")
    else
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "Failed to sync groups - no channels available")
    end
end

function AddonComm:HandleGroupSync(data, sender)
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "HandleGroupSync called from", sender)
    
    if not addon.settings.communication or not addon.settings.communication.acceptGroupSync then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Group sync disabled, ignoring message from", sender)
        return
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Group sync enabled, checking data validity")
    
    if not data or not data.groups or not data.timestamp then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "Invalid group sync data from", sender)
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Data structure: data=", data ~= nil, "groups=", data and data.groups ~= nil, "timestamp=", data and data.timestamp ~= nil)
        return
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.INFO, "Received group sync from", sender, "with", #data.groups, "groups")
    
    if addon.OnGroupSyncReceived then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Calling OnGroupSyncReceived handler")
        addon:OnGroupSyncReceived(data, sender)
        
        -- Mark that we just applied an incoming sync (start cooldown period)
        lastSyncAppliedTime = GetServerTime()
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Sync applied - starting cooldown period")
    else
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "OnGroupSyncReceived handler not available")
    end
end

-- Function for MainFrame to notify that sync application is complete
function AddonComm:NotifySyncApplied()
    lastSyncAppliedTime = GetServerTime()
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Sync application complete - cooldown period started")
end

-- Role monitoring functions (existing functionality)
function AddonComm:StartRoleMonitoring()
    local function CheckRoleChange()
        local currentSpec = GetSpecialization()
        if currentSpec ~= lastKnownSpec then
            lastKnownSpec = currentSpec
            if currentSpec then
                local role = GetSpecializationRole(currentSpec)
                if role ~= playerRole then
                    playerRole = role
                    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Player role changed to:", role)
                    self:SharePlayerRole()
                end
            end
        end
    end
    
    CheckRoleChange()
    
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    frame:SetScript("OnEvent", CheckRoleChange)
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Role monitoring started")
end

function AddonComm:SharePlayerRole(force)
    if not self.initialized then
        return
    end
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    local currentSpec = GetSpecialization()
    
    if not currentSpec then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "No specialization available for role sharing")
        return
    end
    
    local role = GetSpecializationRole(currentSpec)
    local level = UnitLevel("player")
    local class = select(2, UnitClass("player"))
    
    local playerData = {
        player = playerName,
        role = role,
        level = level,
        class = class,
        timestamp = GetServerTime()
    }
    
    local channels = self:GetEnabledChannels()
    for _, channel in ipairs(channels) do
        if self:IsChannelAvailable(channel) then
            self:SendMessage(MESSAGE_TYPES.PLAYER_DATA, playerData, nil, "NORMAL", channel)
            AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Shared role", role, "to", channel)
        end
    end
end

function AddonComm:GetConnectedUsers()
    return connectedUsers
end

-- Broadcast message to all available channels
function AddonComm:BroadcastMessage(messageType, data, priority)
    if not self.initialized then
        AddonComm.Debug(addon.LOG_LEVEL.ERROR, "AddonComm not initialized for broadcast")
        return false
    end
    
    local channels = self:GetEnabledChannels()
    local sentCount = 0
    
    for _, channel in ipairs(channels) do
        if self:IsChannelAvailable(channel) then
            local success = self:SendMessage(messageType, data, nil, priority, channel)
            if success then
                sentCount = sentCount + 1
            end
        end
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Broadcasted", messageType, "to", sentCount, "channels")
    return sentCount > 0
end

-- Member Roster Sharing Functions
function AddonComm:ShareMemberRoster()
    if not self.initialized then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "AddonComm not initialized for roster sharing")
        return false
    end
    
    -- Throttle roster sharing (max once per 30 seconds)
    local now = GetServerTime()
    if lastRosterShareTime and (now - lastRosterShareTime) < 30 then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Member roster sharing throttled - too recent")
        return false
    end
    
    -- Get current member roster from MemberManager
    if not addon.MemberManager then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "MemberManager not available for roster sharing")
        return false
    end
    
    local shareableMembers = addon.MemberManager:GetShareableMemberRoster()
    if not shareableMembers or #shareableMembers == 0 then
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "No members to share in roster")
        return false
    end
    
    local rosterData = {
        members = shareableMembers,
        sender = UnitName("player") .. "-" .. GetRealmName(),
        timestamp = now,
        memberCount = #shareableMembers
    }
    
    AddonComm.Debug(addon.LOG_LEVEL.INFO, "Sharing member roster with", #shareableMembers, "members")
    local success = self:BroadcastMessage(MESSAGE_TYPES.MEMBER_ROSTER_DATA, rosterData)
    
    if success then
        lastRosterShareTime = now
        AddonComm.Debug(addon.LOG_LEVEL.DEBUG, "Member roster shared successfully")
    else
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "Failed to share member roster")
    end
    
    return success
end

function AddonComm:RequestMemberRoster()
    if not self.initialized then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "AddonComm not initialized for roster request")
        return false
    end
    
    local requestData = {
        requester = UnitName("player") .. "-" .. GetRealmName(),
        timestamp = GetServerTime()
    }
    
    AddonComm.Debug(addon.LOG_LEVEL.INFO, "Requesting member rosters from connected users")
    return self:BroadcastMessage(MESSAGE_TYPES.MEMBER_ROSTER_REQUEST, requestData)
end

function AddonComm:HandleMemberRosterRequest(data, sender)
    if not data or not data.requester then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "Invalid roster request from", sender)
        return
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.INFO, "Received roster request from", data.requester, "- sharing our roster")
    
    -- Share our roster in response to the request
    C_Timer.After(math.random(1, 3), function()
        self:ShareMemberRoster()
    end)
end

function AddonComm:HandleMemberRosterData(data, sender)
    if not data or not data.members or not data.sender then
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "Invalid roster data from", sender)
        return
    end
    
    AddonComm.Debug(addon.LOG_LEVEL.INFO, "Received member roster from", data.sender, "with", data.memberCount or 0, "members")
    
    -- Pass to MemberManager for integration
    if addon.MemberManager then
        addon.MemberManager:ReceiveMemberRoster(data, sender)
    else
        AddonComm.Debug(addon.LOG_LEVEL.WARN, "MemberManager not available to process received roster")
    end
end

return AddonComm