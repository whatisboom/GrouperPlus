local addonName, addon = ...

local LibStub = LibStub

local StateSync = {}
addon.StateSync = StateSync

for k, v in pairs(addon.DebugMixin) do
    StateSync[k] = v
end
StateSync:InitDebug("StateSync")

-- Libraries will be embedded safely during initialization

local syncState = {
    isInitialized = false,
    isSyncing = false,
    lastSyncTime = 0,
    syncCooldown = 2.0,
    pendingRequests = {},
    syncHistory = {}
}

local SYNC_CHANNELS = {
    GUILD = "GUILD",
    PARTY = "PARTY", 
    RAID = "RAID"
}

function StateSync:OnInitialize()
    self.Debug("INFO", "Initializing StateSync")
    
    -- Safely embed required Ace3 libraries
    if not self:EmbedLibraries() then
        self.Debug("ERROR", "Failed to embed required libraries")
        return false
    end
    
    self.syncState = syncState
    self.SYNC_CHANNELS = SYNC_CHANNELS
    
    -- Only proceed if embedding was successful
    if self.RegisterComm and self.RegisterMessage then
        self:RegisterComm(addon.MessageProtocol.COMM_PREFIX, "OnCommReceived")
        self:RegisterMessages()
    else
        self.Debug("ERROR", "Required Ace3 methods not available after embedding")
        return false
    end
    
    syncState.isInitialized = true
    self.Debug("DEBUG", "StateSync initialized successfully")
    return true
end

function StateSync:RegisterMessages()
    self.Debug("TRACE", "Registering state sync messages")
    
    self:RegisterMessage("GROUPERPLUS_MEMBER_ADDED", "OnMemberStateChanged")
    self:RegisterMessage("GROUPERPLUS_MEMBER_UPDATED", "OnMemberStateChanged")
    self:RegisterMessage("GROUPERPLUS_MEMBER_REMOVED", "OnMemberStateChanged")
    self:RegisterMessage("GROUPERPLUS_GROUP_CREATED", "OnGroupStateChanged")
    self:RegisterMessage("GROUPERPLUS_GROUP_REMOVED", "OnGroupStateChanged")
    self:RegisterMessage("GROUPERPLUS_MEMBER_ADDED_TO_GROUP", "OnGroupStateChanged")
    self:RegisterMessage("GROUPERPLUS_MEMBER_REMOVED_FROM_GROUP", "OnGroupStateChanged")
    self:RegisterMessage("GROUPERPLUS_MEMBERS_SWAPPED", "OnGroupStateChanged")
    self:RegisterMessage("GROUPERPLUS_SESSION_CREATED", "OnSessionStateChanged")
    self:RegisterMessage("GROUPERPLUS_SESSION_JOINED", "OnSessionStateChanged")
    self:RegisterMessage("GROUPERPLUS_SESSION_LEFT", "OnSessionStateChanged")
    self:RegisterMessage("GROUPERPLUS_SESSION_ENDED", "OnSessionStateChanged")
end

function StateSync:BroadcastMemberState()
    if not self:CanSync() then
        self.Debug("TRACE", "Sync blocked - cooldown or sync in progress")
        return false
    end
    
    local memberData = addon.MemberStateManager and addon.MemberStateManager:GetShareableData()
    if not memberData or #memberData == 0 then
        self.Debug("TRACE", "No member data to broadcast")
        return false
    end
    
    local message = addon.MessageProtocol:CreateMemberStateSync(memberData)
    if not message then
        self.Debug("ERROR", "Failed to create member state sync message")
        return false
    end
    
    return self:SendMessage(message)
end

function StateSync:BroadcastGroupState()
    if not self:CanSync() then
        self.Debug("TRACE", "Sync blocked - cooldown or sync in progress")
        return false
    end
    
    local groupData = addon.GroupStateManager and addon.GroupStateManager:GetShareableData()
    if not groupData or #groupData == 0 then
        self.Debug("TRACE", "No group data to broadcast")
        return false
    end
    
    local message = addon.MessageProtocol:CreateGroupStateSync(groupData)
    if not message then
        self.Debug("ERROR", "Failed to create group state sync message")
        return false
    end
    
    return self:SendMessage(message)
end

function StateSync:BroadcastSessionState()
    if not self:CanSync() then
        self.Debug("TRACE", "Sync blocked - cooldown or sync in progress")
        return false
    end
    
    local sessionData = addon.SessionStateManager and addon.SessionStateManager:GetShareableData()
    if not sessionData then
        self.Debug("TRACE", "No session data to broadcast")
        return false
    end
    
    local message = addon.MessageProtocol:CreateSessionStateSync(sessionData)
    if not message then
        self.Debug("ERROR", "Failed to create session state sync message")
        return false
    end
    
    return self:SendMessage(message)
end

function StateSync:BroadcastFullState()
    if not self:CanSync() then
        self.Debug("TRACE", "Sync blocked - cooldown or sync in progress")
        return false
    end
    
    local memberData = addon.MemberStateManager and addon.MemberStateManager:GetShareableData()
    local groupData = addon.GroupStateManager and addon.GroupStateManager:GetShareableData()
    local sessionData = addon.SessionStateManager and addon.SessionStateManager:GetShareableData()
    
    local message = addon.MessageProtocol:CreateFullStateSync(
        {members = memberData or {}},
        {groups = groupData or {}},
        sessionData
    )
    
    if not message then
        self.Debug("ERROR", "Failed to create full state sync message")
        return false
    end
    
    return self:SendMessage(message)
end

function StateSync:RequestState(requestType, target)
    local message = addon.MessageProtocol:CreateStateRequest(requestType, target)
    if not message then
        self.Debug("ERROR", "Failed to create state request message")
        return false
    end
    
    return self:SendMessage(message, target and "WHISPER" or nil, target)
end

function StateSync:SendPing(target)
    local message = addon.MessageProtocol:CreatePing(target)
    if not message then
        self.Debug("ERROR", "Failed to create ping message")
        return false
    end
    
    return self:SendMessage(message, target and "WHISPER" or nil, target)
end

function StateSync:SendMessage(message, distribution, target)
    if not message then
        self.Debug("ERROR", "Cannot send nil message")
        return false
    end
    
    local serialized = addon.MessageProtocol:SerializeMessage(message)
    if not serialized then
        self.Debug("ERROR", "Failed to serialize message")
        return false
    end
    
    distribution = distribution or self:GetBestDistribution()
    if not distribution then
        self.Debug("ERROR", "No available distribution channel")
        return false
    end
    
    local result = self:SendCommMessage(addon.MessageProtocol.COMM_PREFIX, serialized, distribution, target, "NORMAL")
    local success = (result ~= false)
    
    if success then
        addon.MessageProtocol:LogMessageSent(message, distribution, target)
        self:UpdateSyncState()
        self:AddToSyncHistory(message.type, "SENT", distribution, target)
    else
        self.Debug("ERROR", "Failed to send message:", message.type, "via:", distribution)
    end
    
    return success
end

function StateSync:BroadcastMessage(messageType, data, target)
    if not messageType or not data then
        self.Debug("ERROR", "BroadcastMessage requires messageType and data")
        return false
    end
    
    local message = nil
    
    -- Use specific message creation functions when available
    if messageType == "KEYSTONE_DATA" then
        message = addon.MessageProtocol:CreateKeystoneData(data)
    elseif messageType == "RAIDERIO_DATA" then
        message = addon.MessageProtocol:CreateRaiderIOData(data)
    else
        -- Fall back to generic message creation
        message = addon.MessageProtocol:CreateMessage(messageType, data, target or "broadcast")
    end
    
    if not message then
        self.Debug("ERROR", "Failed to create message for type:", messageType)
        return false
    end
    
    local distribution = target and "WHISPER" or self:GetBestDistribution()
    local success = self:SendMessage(message, distribution, target)
    
    if success then
        self.Debug("DEBUG", "Sent custom message:", messageType, "to:", target or "broadcast")
        self:AddToSyncHistory(messageType, "SENT", distribution, target)
    else
        self.Debug("ERROR", "Failed to send custom message:", messageType)
    end
    
    return success
end

function StateSync:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= addon.MessageProtocol.COMM_PREFIX then
        return
    end
    
    self.Debug("TRACE", "Received comm message from:", sender, "via:", distribution)
    
    local deserializedMessage = addon.MessageProtocol:DeserializeMessage(message)
    if not deserializedMessage then
        self.Debug("ERROR", "Failed to deserialize message from:", sender)
        return
    end
    
    addon.MessageProtocol:LogMessageReceived(deserializedMessage)
    
    if not addon.MessageProtocol:ShouldProcessMessage(deserializedMessage) then
        return
    end
    
    self:AddToSyncHistory(deserializedMessage.type, "RECEIVED", distribution, sender)
    self:ProcessMessage(deserializedMessage, sender)
end

function StateSync:ProcessMessage(message, sender)
    local messageType = message.type
    
    if messageType == addon.MessageProtocol.MESSAGE_TYPES.MEMBER_STATE_SYNC then
        self:ProcessMemberStateSync(message, sender)
    elseif messageType == addon.MessageProtocol.MESSAGE_TYPES.GROUP_STATE_SYNC then
        self:ProcessGroupStateSync(message, sender)
    elseif messageType == addon.MessageProtocol.MESSAGE_TYPES.SESSION_STATE_SYNC then
        self:ProcessSessionStateSync(message, sender)
    elseif messageType == addon.MessageProtocol.MESSAGE_TYPES.FULL_STATE_SYNC then
        self:ProcessFullStateSync(message, sender)
    elseif messageType == addon.MessageProtocol.MESSAGE_TYPES.STATE_REQUEST then
        self:ProcessStateRequest(message, sender)
    elseif messageType == addon.MessageProtocol.MESSAGE_TYPES.PING then
        self:ProcessPing(message, sender)
    elseif messageType == addon.MessageProtocol.MESSAGE_TYPES.PONG then
        self:ProcessPong(message, sender)
    else
        self.Debug("WARN", "Unknown message type:", messageType, "from:", sender)
    end
end

function StateSync:ProcessMemberStateSync(message, sender)
    if not message.data or not message.data.members then
        self.Debug("WARN", "Invalid member state sync from:", sender)
        return
    end
    
    if addon.MemberStateManager then
        self:SetSyncInProgress(true)
        local imported = addon.MemberStateManager:ImportSharedData(message.data.members, sender)
        self:SetSyncInProgress(false)
        
        if imported > 0 then
            self:TriggerUIUpdate()
        end
    end
end

function StateSync:ProcessGroupStateSync(message, sender)
    if not message.data or not message.data.groups then
        self.Debug("WARN", "Invalid group state sync from:", sender)
        return
    end
    
    if addon.GroupStateManager then
        self:SetSyncInProgress(true)
        local imported = addon.GroupStateManager:ImportSharedData(message.data.groups, sender)
        self:SetSyncInProgress(false)
        
        if imported > 0 then
            self:TriggerUIUpdate()
        end
    end
end

function StateSync:ProcessSessionStateSync(message, sender)
    if not message.data then
        self.Debug("WARN", "Invalid session state sync from:", sender)
        return
    end
    
    if addon.SessionStateManager then
        self:SetSyncInProgress(true)
        addon.SessionStateManager:ImportSharedData(message.data, sender)
        self:SetSyncInProgress(false)
        
        self:TriggerUIUpdate()
    end
end

function StateSync:ProcessFullStateSync(message, sender)
    if not message.data then
        self.Debug("WARN", "Invalid full state sync from:", sender)
        return
    end
    
    self:SetSyncInProgress(true)
    
    if message.data.memberState and addon.MemberStateManager then
        addon.MemberStateManager:ImportSharedData(message.data.memberState.members or {}, sender)
    end
    
    if message.data.groupState and addon.GroupStateManager then
        addon.GroupStateManager:ImportSharedData(message.data.groupState.groups or {}, sender)
    end
    
    if message.data.sessionState and addon.SessionStateManager then
        addon.SessionStateManager:ImportSharedData(message.data.sessionState, sender)
    end
    
    self:SetSyncInProgress(false)
    self:TriggerUIUpdate()
end

function StateSync:ProcessStateRequest(message, sender)
    local requestType = message.data.requestType or "FULL"
    
    self.Debug("DEBUG", "Received state request:", requestType, "from:", sender)
    
    if requestType == "MEMBER" then
        self:BroadcastMemberState()
    elseif requestType == "GROUP" then
        self:BroadcastGroupState()
    elseif requestType == "SESSION" then
        self:BroadcastSessionState()
    else
        self:BroadcastFullState()
    end
end

function StateSync:ProcessPing(message, sender)
    self.Debug("TRACE", "Received ping from:", sender)
    
    local pongMessage = addon.MessageProtocol:CreatePong(message.data, sender)
    if pongMessage then
        self:SendMessage(pongMessage, "WHISPER", sender)
    end
end

function StateSync:ProcessPong(message, sender)
    local latency = nil
    if message.data and message.data.originalTimestamp then
        latency = addon.WoWAPIWrapper:GetTime() - message.data.originalTimestamp
    end
    
    self.Debug("DEBUG", "Received pong from:", sender, "latency:", latency and (latency * 1000) .. "ms" or "unknown")
end

function StateSync:GetBestDistribution()
    local channels = addon.WoWAPIWrapper:GetEnabledChannels()
    
    for _, channel in ipairs(channels) do
        if channel == "RAID" then
            return "RAID"
        elseif channel == "PARTY" then
            return "PARTY"
        elseif channel == "GUILD" then
            return "GUILD"
        end
    end
    
    return nil
end

function StateSync:CanSync()
    if not syncState.isInitialized then
        return false
    end
    
    if syncState.isSyncing then
        return false
    end
    
    local now = addon.WoWAPIWrapper:GetTime()
    if (now - syncState.lastSyncTime) < syncState.syncCooldown then
        return false
    end
    
    return true
end

function StateSync:SetSyncInProgress(inProgress)
    syncState.isSyncing = inProgress
    self.Debug("TRACE", "Sync in progress:", inProgress)
end

function StateSync:IsSyncInProgress()
    return syncState.isSyncing
end

function StateSync:UpdateSyncState()
    syncState.lastSyncTime = addon.WoWAPIWrapper:GetTime()
end

function StateSync:AddToSyncHistory(messageType, direction, distribution, target)
    local entry = {
        messageType = messageType,
        direction = direction,
        distribution = distribution,
        target = target,
        timestamp = addon.WoWAPIWrapper:GetServerTime()
    }
    
    table.insert(syncState.syncHistory, entry)
    
    while #syncState.syncHistory > 100 do
        table.remove(syncState.syncHistory, 1)
    end
end

function StateSync:GetSyncHistory()
    return syncState.syncHistory
end

function StateSync:TriggerUIUpdate()
    self:ScheduleTimer("DoUIUpdate", 0.1)
end

function StateSync:DoUIUpdate()
    if addon.MainFrame and addon.MainFrame.RefreshMemberDisplay then
        addon.MainFrame:RefreshMemberDisplay()
    elseif addon.MainFrame and addon.MainFrame.UpdateMemberDisplay then
        addon.MainFrame:UpdateMemberDisplay()
    end
end

function StateSync:OnMemberStateChanged(event, ...)
    self.Debug("TRACE", "Member state changed, scheduling sync")
    self:ScheduleTimer("BroadcastMemberState", 1.0)
end

function StateSync:OnGroupStateChanged(event, ...)
    self.Debug("TRACE", "Group state changed, scheduling sync")
    self:ScheduleTimer("BroadcastGroupState", 1.0)
end

function StateSync:OnSessionStateChanged(event, ...)
    self.Debug("TRACE", "Session state changed, scheduling sync")
    self:ScheduleTimer("BroadcastSessionState", 1.0)
end

function StateSync:EmbedLibraries()
    local LibraryManager = addon.LibraryManager
    if not LibraryManager then
        self.Debug("ERROR", "LibraryManager not available")
        return false
    end
    
    local success = true
    
    -- Embed AceEvent-3.0
    if not LibraryManager:SafeEmbed(self, "AceEvent-3.0") then
        self.Debug("ERROR", "Failed to embed AceEvent-3.0")
        success = false
    end
    
    -- Embed AceTimer-3.0
    if not LibraryManager:SafeEmbed(self, "AceTimer-3.0") then
        self.Debug("ERROR", "Failed to embed AceTimer-3.0")
        success = false
    end
    
    -- Embed AceComm-3.0
    if not LibraryManager:SafeEmbed(self, "AceComm-3.0") then
        self.Debug("ERROR", "Failed to embed AceComm-3.0")
        success = false
    end
    
    return success
end

function StateSync:OnDisable()
    self.Debug("INFO", "Disabling StateSync")
    
    -- Unregister all communications
    if self.UnregisterAllComm then
        self:UnregisterAllComm()
        self.Debug("DEBUG", "Unregistered all comm handlers")
    end
    
    -- Cancel all timers
    if self.CancelAllTimers then
        self:CancelAllTimers()
        self.Debug("DEBUG", "Cancelled all timers")
    end
    
    -- Unregister all messages
    if self.UnregisterAllMessages then
        self:UnregisterAllMessages()
        self.Debug("DEBUG", "Unregistered all message handlers")
    end
    
    -- Clear sync state
    syncState.isInitialized = false
    syncState.isSyncing = false
    syncState.pendingRequests = {}
    
    self.Debug("DEBUG", "StateSync disabled successfully")
end

return StateSync