local addonName, addon = ...

local LibStub = LibStub

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
    PONG = "PONG",
    -- Session notification types
    SESSION_RECRUITMENT = "SESSION_RECRUITMENT",
    SESSION_JOIN_REQUEST = "SESSION_JOIN_REQUEST",
    SESSION_JOIN_RESPONSE = "SESSION_JOIN_RESPONSE",
    -- Custom message types
    KEYSTONE_DATA = "KEYSTONE_DATA",
    RAIDERIO_DATA = "RAIDERIO_DATA"
}

local MESSAGE_VERSION = "1.0"
local COMM_PREFIX = "GrouperPlus"

function MessageProtocol:OnInitialize()
    self.Debug("INFO", "Initializing MessageProtocol")
    
    -- Get AceSerializer library safely
    local LibraryManager = addon.LibraryManager
    if LibraryManager then
        self.AceSerializer = LibraryManager:GetLibrary("AceSerializer-3.0")
        if not self.AceSerializer then
            self.Debug("ERROR", "AceSerializer-3.0 not available")
            return false
        end
    else
        -- Fallback to direct LibStub call
        self.AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
        if not self.AceSerializer then
            self.Debug("ERROR", "AceSerializer-3.0 not available via LibStub")
            return false
        end
    end
    
    self.MESSAGE_TYPES = MESSAGE_TYPES
    self.MESSAGE_VERSION = MESSAGE_VERSION
    self.COMM_PREFIX = COMM_PREFIX
    
    self.Debug("DEBUG", "MessageProtocol initialized successfully")
    return true
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
    
    if not self.AceSerializer then
        self.Debug("ERROR", "AceSerializer not available")
        return nil
    end
    
    local success, serialized = pcall(self.AceSerializer.Serialize, self.AceSerializer, message)
    if not success then
        self.Debug("ERROR", "Failed to serialize message:", serialized)
        return nil
    end
    
    if not serialized then
        self.Debug("ERROR", "Serialization returned nil")
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
    
    if not self.AceSerializer then
        self.Debug("ERROR", "AceSerializer not available")
        return nil
    end
    
    self.Debug("TRACE", "Attempting to deserialize message of length:", string.len(serialized))
    
    local success, message = pcall(self.AceSerializer.Deserialize, self.AceSerializer, serialized)
    if not success then
        self.Debug("ERROR", "Failed to deserialize message:", message)
        self.Debug("ERROR", "Serialized data type:", type(serialized), "length:", string.len(serialized))
        self.Debug("ERROR", "First 100 chars:", string.sub(serialized, 1, 100))
        return nil
    end
    
    if not message then
        self.Debug("ERROR", "Deserialization returned nil")
        return nil
    end
    
    self.Debug("TRACE", "Deserialization successful, validating message")
    
    if not self:ValidateMessage(message) then
        self.Debug("ERROR", "Deserialized message failed validation")
        self.Debug("ERROR", "Message type:", type(message), "content:", message)
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
    elseif messageType == MESSAGE_TYPES.SESSION_RECRUITMENT then
        return self:ValidateSessionRecruitmentData(data)
    elseif messageType == MESSAGE_TYPES.SESSION_JOIN_REQUEST or messageType == MESSAGE_TYPES.SESSION_JOIN_RESPONSE then
        return self:ValidateSessionJoinData(data)
    elseif messageType == MESSAGE_TYPES.KEYSTONE_DATA then
        return self:ValidateKeystoneData(data)
    elseif messageType == MESSAGE_TYPES.RAIDERIO_DATA then
        return self:ValidateRaiderIOData(data)
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

function MessageProtocol:CreateKeystoneData(keystoneData)
    return self:CreateMessage(MESSAGE_TYPES.KEYSTONE_DATA, keystoneData or {})
end

function MessageProtocol:CreateRaiderIOData(raiderIOData)
    return self:CreateMessage(MESSAGE_TYPES.RAIDERIO_DATA, raiderIOData or {})
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

function MessageProtocol:ValidateKeystoneData(data)
    if not data.player or type(data.player) ~= "string" then
        self.Debug("WARN", "Keystone data missing or invalid player field")
        return false
    end
    
    if not data.mapID or type(data.mapID) ~= "number" then
        self.Debug("WARN", "Keystone data missing or invalid mapID field")
        return false
    end
    
    if not data.level or type(data.level) ~= "number" then
        self.Debug("WARN", "Keystone data missing or invalid level field")
        return false
    end
    
    -- Optional fields - validate if present but don't require them
    if data.dungeonName and type(data.dungeonName) ~= "string" then
        self.Debug("WARN", "Keystone data has invalid dungeonName field type")
        return false
    end
    
    if data.timestamp and type(data.timestamp) ~= "number" then
        self.Debug("WARN", "Keystone data has invalid timestamp field type")
        return false
    end
    
    return true
end

function MessageProtocol:ValidateRaiderIOData(data)
    if not data.player or type(data.player) ~= "string" then
        self.Debug("WARN", "RaiderIO data missing or invalid player field")
        return false
    end
    
    if not data.data or type(data.data) ~= "table" then
        self.Debug("WARN", "RaiderIO data missing or invalid data field")
        return false
    end
    
    return true
end

function MessageProtocol:ValidateSessionRecruitmentData(data)
    if not data.sessionId or type(data.sessionId) ~= "string" then
        self.Debug("WARN", "Session recruitment data missing or invalid sessionId")
        return false
    end
    
    if not data.leaderId or type(data.leaderId) ~= "string" then
        self.Debug("WARN", "Session recruitment data missing or invalid leaderId")
        return false
    end
    
    if data.timeout and type(data.timeout) ~= "number" then
        self.Debug("WARN", "Session recruitment data has invalid timeout field")
        return false
    end
    
    return true
end

function MessageProtocol:ValidateSessionJoinData(data)
    if not data.sessionId or type(data.sessionId) ~= "string" then
        self.Debug("WARN", "Session join data missing or invalid sessionId")
        return false
    end
    
    if data.accepted ~= nil and type(data.accepted) ~= "boolean" then
        self.Debug("WARN", "Session join data has invalid accepted field")
        return false
    end
    
    return true
end

function MessageProtocol:CreateSessionRecruitment(recruitmentData)
    return self:CreateMessage(MESSAGE_TYPES.SESSION_RECRUITMENT, recruitmentData or {})
end

function MessageProtocol:CreateSessionJoinRequest(sessionId, playerName)
    return self:CreateMessage(MESSAGE_TYPES.SESSION_JOIN_REQUEST, {
        sessionId = sessionId,
        playerName = playerName or ""
    })
end

function MessageProtocol:CreateSessionJoinResponse(sessionId, accepted, playerName)
    return self:CreateMessage(MESSAGE_TYPES.SESSION_JOIN_RESPONSE, {
        sessionId = sessionId,
        accepted = accepted,
        playerName = playerName or ""
    })
end

return MessageProtocol