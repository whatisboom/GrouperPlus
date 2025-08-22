local addonName, addon = ...

local LibStub = LibStub
local AceSerializer = LibStub("AceSerializer-3.0")

local MessageProtocol = {}
addon.MessageProtocol = MessageProtocol

for k, v in pairs(addon.DebugMixin) do
    MessageProtocol[k] = v
end
MessageProtocol:InitDebug("MsgProtocol")

local MESSAGE_TYPES = {
    MEMBER_STATE_SYNC = "MEMBER_STATE_SYNC",
    GROUP_STATE_SYNC = "GROUP_STATE_SYNC", 
    SESSION_STATE_SYNC = "SESSION_STATE_SYNC",
    FULL_STATE_SYNC = "FULL_STATE_SYNC",
    STATE_REQUEST = "STATE_REQUEST",
    PING = "PING",
    PONG = "PONG"
}

local MESSAGE_VERSION = "1.0"
local COMM_PREFIX = "GrouperPlus"

function MessageProtocol:OnInitialize()
    self.Debug("INFO", "Initializing MessageProtocol")
    
    self.MESSAGE_TYPES = MESSAGE_TYPES
    self.MESSAGE_VERSION = MESSAGE_VERSION
    self.COMM_PREFIX = COMM_PREFIX
    
    self.Debug("DEBUG", "MessageProtocol initialized successfully")
end

function MessageProtocol:CreateMessage(messageType, data, target)
    if not MESSAGE_TYPES[messageType] then
        self.Debug("ERROR", "Invalid message type:", messageType)
        return nil
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if not playerInfo then
        self.Debug("ERROR", "Failed to get player info for message creation")
        return nil
    end
    
    local message = {
        version = MESSAGE_VERSION,
        type = messageType,
        sender = playerInfo.fullName,
        timestamp = addon.WoWAPIWrapper:GetServerTime(),
        target = target,
        data = data or {}
    }
    
    if not self:ValidateMessage(message) then
        self.Debug("ERROR", "Message validation failed for type:", messageType)
        return nil
    end
    
    self.Debug("TRACE", "Created message:", messageType, "for target:", target or "broadcast")
    return message
end

function MessageProtocol:SerializeMessage(message)
    if not message then
        self.Debug("ERROR", "Cannot serialize nil message")
        return nil
    end
    
    local success, serialized = pcall(AceSerializer.Serialize, AceSerializer, message)
    if not success then
        self.Debug("ERROR", "Failed to serialize message:", serialized)
        return nil
    end
    
    self.Debug("TRACE", "Serialized message type:", message.type, "size:", string.len(serialized))
    return serialized
end

function MessageProtocol:DeserializeMessage(serialized)
    if not serialized or serialized == "" then
        self.Debug("ERROR", "Cannot deserialize empty message")
        return nil
    end
    
    local success, message = pcall(AceSerializer.Deserialize, AceSerializer, serialized)
    if not success then
        self.Debug("ERROR", "Failed to deserialize message:", message)
        return nil
    end
    
    if not self:ValidateMessage(message) then
        self.Debug("ERROR", "Deserialized message failed validation")
        return nil
    end
    
    self.Debug("TRACE", "Deserialized message type:", message.type, "from sender:", message.sender)
    return message
end

function MessageProtocol:ValidateMessage(message)
    if not message or type(message) ~= "table" then
        self.Debug("WARN", "Message is not a table")
        return false
    end
    
    if not message.version or message.version ~= MESSAGE_VERSION then
        self.Debug("WARN", "Invalid or unsupported message version:", message.version)
        return false
    end
    
    if not message.type or not MESSAGE_TYPES[message.type] then
        self.Debug("WARN", "Invalid message type:", message.type)
        return false
    end
    
    if not message.sender or type(message.sender) ~= "string" then
        self.Debug("WARN", "Invalid sender:", message.sender)
        return false
    end
    
    if not message.timestamp or type(message.timestamp) ~= "number" then
        self.Debug("WARN", "Invalid timestamp:", message.timestamp)
        return false
    end
    
    if not message.data or type(message.data) ~= "table" then
        self.Debug("WARN", "Invalid data field:", type(message.data))
        return false
    end
    
    return self:ValidateMessageData(message.type, message.data)
end

function MessageProtocol:ValidateMessageData(messageType, data)
    if messageType == MESSAGE_TYPES.MEMBER_STATE_SYNC then
        return self:ValidateMemberStateData(data)
    elseif messageType == MESSAGE_TYPES.GROUP_STATE_SYNC then
        return self:ValidateGroupStateData(data)
    elseif messageType == MESSAGE_TYPES.SESSION_STATE_SYNC then
        return self:ValidateSessionStateData(data)
    elseif messageType == MESSAGE_TYPES.FULL_STATE_SYNC then
        return self:ValidateFullStateData(data)
    elseif messageType == MESSAGE_TYPES.STATE_REQUEST then
        return self:ValidateStateRequestData(data)
    elseif messageType == MESSAGE_TYPES.PING or messageType == MESSAGE_TYPES.PONG then
        return true
    end
    
    self.Debug("WARN", "Unknown message type for validation:", messageType)
    return false
end

function MessageProtocol:ValidateMemberStateData(data)
    if not data.members or type(data.members) ~= "table" then
        self.Debug("WARN", "Invalid members data in member state sync")
        return false
    end
    
    for _, member in ipairs(data.members) do
        if not member.name or type(member.name) ~= "string" then
            self.Debug("WARN", "Invalid member name in member state sync")
            return false
        end
        
        if not member.class or type(member.class) ~= "string" then
            self.Debug("WARN", "Invalid member class in member state sync")
            return false
        end
    end
    
    return true
end

function MessageProtocol:ValidateGroupStateData(data)
    if not data.groups or type(data.groups) ~= "table" then
        self.Debug("WARN", "Invalid groups data in group state sync")
        return false
    end
    
    for _, group in ipairs(data.groups) do
        if not group.id then
            self.Debug("WARN", "Invalid group id in group state sync")
            return false
        end
        
        if not group.members or type(group.members) ~= "table" then
            self.Debug("WARN", "Invalid group members in group state sync")
            return false
        end
    end
    
    return true
end

function MessageProtocol:ValidateSessionStateData(data)
    if not data.sessionId or type(data.sessionId) ~= "string" then
        self.Debug("WARN", "Invalid sessionId in session state sync")
        return false
    end
    
    if not data.ownerId or type(data.ownerId) ~= "string" then
        self.Debug("WARN", "Invalid ownerId in session state sync")
        return false
    end
    
    return true
end

function MessageProtocol:ValidateFullStateData(data)
    local valid = true
    
    if data.memberState and not self:ValidateMemberStateData(data.memberState) then
        valid = false
    end
    
    if data.groupState and not self:ValidateGroupStateData(data.groupState) then
        valid = false
    end
    
    if data.sessionState and not self:ValidateSessionStateData(data.sessionState) then
        valid = false
    end
    
    return valid
end

function MessageProtocol:ValidateStateRequestData(data)
    if data.requestType and type(data.requestType) ~= "string" then
        self.Debug("WARN", "Invalid requestType in state request")
        return false
    end
    
    return true
end

function MessageProtocol:CreateMemberStateSync(members)
    return self:CreateMessage(MESSAGE_TYPES.MEMBER_STATE_SYNC, {
        members = members or {}
    })
end

function MessageProtocol:CreateGroupStateSync(groups)
    return self:CreateMessage(MESSAGE_TYPES.GROUP_STATE_SYNC, {
        groups = groups or {}
    })
end

function MessageProtocol:CreateSessionStateSync(sessionData)
    return self:CreateMessage(MESSAGE_TYPES.SESSION_STATE_SYNC, sessionData or {})
end

function MessageProtocol:CreateFullStateSync(memberState, groupState, sessionState)
    return self:CreateMessage(MESSAGE_TYPES.FULL_STATE_SYNC, {
        memberState = memberState,
        groupState = groupState, 
        sessionState = sessionState
    })
end

function MessageProtocol:CreateStateRequest(requestType, target)
    return self:CreateMessage(MESSAGE_TYPES.STATE_REQUEST, {
        requestType = requestType or "FULL"
    }, target)
end

function MessageProtocol:CreatePing(target)
    return self:CreateMessage(MESSAGE_TYPES.PING, {
        timestamp = addon.WoWAPIWrapper:GetTime()
    }, target)
end

function MessageProtocol:CreatePong(originalPingData, target)
    return self:CreateMessage(MESSAGE_TYPES.PONG, {
        originalTimestamp = originalPingData and originalPingData.timestamp,
        responseTime = addon.WoWAPIWrapper:GetTime()
    }, target)
end

function MessageProtocol:IsMessageFromSelf(message)
    if not message or not message.sender then
        return false
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    return playerInfo and message.sender == playerInfo.fullName
end

function MessageProtocol:IsMessageExpired(message, maxAge)
    if not message or not message.timestamp then
        return true
    end
    
    maxAge = maxAge or 300
    local now = addon.WoWAPIWrapper:GetServerTime()
    return (now - message.timestamp) > maxAge
end

function MessageProtocol:GetMessageAge(message)
    if not message or not message.timestamp then
        return nil
    end
    
    local now = addon.WoWAPIWrapper:GetServerTime()
    return now - message.timestamp
end

function MessageProtocol:ShouldProcessMessage(message)
    if not message then
        return false
    end
    
    if self:IsMessageFromSelf(message) then
        self.Debug("TRACE", "Ignoring message from self:", message.type)
        return false
    end
    
    if self:IsMessageExpired(message, 300) then
        self.Debug("TRACE", "Ignoring expired message:", message.type, "age:", self:GetMessageAge(message))
        return false
    end
    
    return true
end

function MessageProtocol:LogMessageReceived(message)
    if not message then
        return
    end
    
    local age = self:GetMessageAge(message)
    self.Debug("DEBUG", "Received message:", message.type, "from:", message.sender, "age:", age, "s")
end

function MessageProtocol:LogMessageSent(message, distribution, target)
    if not message then
        return
    end
    
    self.Debug("DEBUG", "Sent message:", message.type, "via:", distribution, "to:", target or "broadcast")
end

return MessageProtocol