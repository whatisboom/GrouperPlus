local addonName, addon = ...

local LibStub = LibStub

local SessionStateManager = {}
addon.SessionStateManager = SessionStateManager

addon.DebugMixin:InjectInto(SessionStateManager, "SessionState")

-- AceEvent will be embedded safely during initialization

local sessionState = {
    sessionId = nil,
    ownerId = nil,
    isOwner = false,
    admins = {},
    isActive = false,
    isLocked = false,
    createdTime = nil,
    participants = {}
}

local SESSION_PERMISSIONS = {
    VIEW = "VIEW",
    EDIT_MEMBERS = "EDIT_MEMBERS", 
    EDIT_GROUPS = "EDIT_GROUPS",
    ADMIN = "ADMIN"
}

function SessionStateManager:OnInitialize()
    self.Debug("INFO", "Initializing SessionStateManager")
    
    addon.SharedUtilities:MixinEventHandling(self)
    
    -- Safely embed required Ace3 libraries
    if not self:EmbedLibraries() then
        self.Debug("ERROR", "Failed to embed required libraries")
        return false
    end
    
    self.sessionState = sessionState
    self.SESSION_PERMISSIONS = SESSION_PERMISSIONS
    
    self.Debug("DEBUG", "SessionStateManager initialized successfully")
    return true
end

function SessionStateManager:CreateSession(sessionData)
    if self:IsInSession() then
        self.Debug("WARN", "Already in an active session")
        return false, "Already in an active session"
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if not playerInfo then
        self.Debug("ERROR", "Failed to get player info for session creation")
        return false, "Failed to get player info"
    end
    
    sessionState.sessionId = self:GenerateSessionId()
    sessionState.ownerId = playerInfo.fullName
    sessionState.isOwner = true
    sessionState.admins = {[playerInfo.fullName] = true}
    sessionState.isActive = true
    sessionState.isLocked = sessionData and sessionData.locked or false
    sessionState.createdTime = addon.WoWAPIWrapper:GetServerTime()
    sessionState.participants = {
        [playerInfo.fullName] = {
            joinTime = addon.WoWAPIWrapper:GetServerTime(),
            permissions = {SESSION_PERMISSIONS.ADMIN}
        }
    }
    
    self.Debug("INFO", "Created session:", sessionState.sessionId, "owner:", sessionState.ownerId, "locked:", sessionState.isLocked)
    self:FireEvent("SESSION_CREATED", self:GetSessionInfo())
    
    return true, sessionState.sessionId
end

function SessionStateManager:JoinSession(sessionId, ownerId)
    if self:IsInSession() then
        self.Debug("WARN", "Already in an active session")
        return false, "Already in an active session"
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if not playerInfo then
        self.Debug("ERROR", "Failed to get player info for session join")
        return false, "Failed to get player info"
    end
    
    sessionState.sessionId = sessionId
    sessionState.ownerId = ownerId
    sessionState.isOwner = false
    sessionState.admins = {[ownerId] = true}
    sessionState.isActive = true
    sessionState.isLocked = true
    sessionState.createdTime = nil
    sessionState.participants = {
        [playerInfo.fullName] = {
            joinTime = addon.WoWAPIWrapper:GetServerTime(),
            permissions = {SESSION_PERMISSIONS.VIEW}
        }
    }
    
    self.Debug("INFO", "Joined session:", sessionId, "owner:", ownerId)
    self:FireEvent("SESSION_JOINED", self:GetSessionInfo())
    
    return true
end

function SessionStateManager:LeaveSession()
    if not self:IsInSession() then
        self.Debug("WARN", "Not in an active session")
        return false, "Not in an active session"
    end
    
    local sessionInfo = self:GetSessionInfo()
    
    if sessionState.isOwner then
        self:EndSession()
    else
        self:ClearSessionState()
        self:FireEvent("SESSION_LEFT", sessionInfo)
    end
    
    self.Debug("INFO", "Left session:", sessionInfo.sessionId)
    return true
end

function SessionStateManager:EndSession()
    if not self:IsInSession() then
        self.Debug("WARN", "No active session to end")
        return false, "No active session to end"
    end
    
    if not sessionState.isOwner then
        self.Debug("WARN", "Only session owner can end the session")
        return false, "Only session owner can end the session"
    end
    
    local sessionInfo = self:GetSessionInfo()
    self:ClearSessionState()
    
    self.Debug("INFO", "Ended session:", sessionInfo.sessionId)
    self:FireEvent("SESSION_ENDED", sessionInfo)
    
    return true
end

function SessionStateManager:AddParticipant(playerName, permissions)
    if not self:IsInSession() then
        self.Debug("WARN", "No active session")
        return false
    end
    
    if not self:HasPermission(SESSION_PERMISSIONS.ADMIN) then
        self.Debug("WARN", "Insufficient permissions to add participant")
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(playerName)
    if not normalizedName then
        self.Debug("WARN", "Invalid player name:", playerName)
        return false
    end
    
    sessionState.participants[normalizedName] = {
        joinTime = addon.WoWAPIWrapper:GetServerTime(),
        permissions = permissions or {SESSION_PERMISSIONS.VIEW}
    }
    
    self.Debug("INFO", "Added participant:", normalizedName, "permissions:", table.concat(permissions or {SESSION_PERMISSIONS.VIEW}, ", "))
    self:FireEvent("PARTICIPANT_ADDED", normalizedName, sessionState.participants[normalizedName])
    
    return true
end

function SessionStateManager:RemoveParticipant(playerName)
    if not self:IsInSession() then
        self.Debug("WARN", "No active session")
        return false
    end
    
    if not self:HasPermission(SESSION_PERMISSIONS.ADMIN) then
        self.Debug("WARN", "Insufficient permissions to remove participant")
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(playerName)
    if not normalizedName then
        self.Debug("WARN", "Invalid player name:", playerName)
        return false
    end
    
    if normalizedName == sessionState.ownerId then
        self.Debug("WARN", "Cannot remove session owner")
        return false
    end
    
    local participant = sessionState.participants[normalizedName]
    if not participant then
        self.Debug("WARN", "Participant not found:", normalizedName)
        return false
    end
    
    sessionState.participants[normalizedName] = nil
    sessionState.admins[normalizedName] = nil
    
    self.Debug("INFO", "Removed participant:", normalizedName)
    self:FireEvent("PARTICIPANT_REMOVED", normalizedName, participant)
    
    return true
end

function SessionStateManager:SetParticipantPermissions(playerName, permissions)
    if not self:IsInSession() then
        self.Debug("WARN", "No active session")
        return false
    end
    
    if not self:HasPermission(SESSION_PERMISSIONS.ADMIN) then
        self.Debug("WARN", "Insufficient permissions to modify participant permissions")
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(playerName)
    if not normalizedName then
        self.Debug("WARN", "Invalid player name:", playerName)
        return false
    end
    
    local participant = sessionState.participants[normalizedName]
    if not participant then
        self.Debug("WARN", "Participant not found:", normalizedName)
        return false
    end
    
    local oldPermissions = participant.permissions
    participant.permissions = permissions or {SESSION_PERMISSIONS.VIEW}
    
    local isAdmin = false
    for _, perm in ipairs(participant.permissions) do
        if perm == SESSION_PERMISSIONS.ADMIN then
            isAdmin = true
            break
        end
    end
    
    if isAdmin then
        sessionState.admins[normalizedName] = true
    else
        sessionState.admins[normalizedName] = nil
    end
    
    self.Debug("INFO", "Updated permissions for:", normalizedName, "new permissions:", table.concat(permissions or {}, ", "))
    self:FireEvent("PARTICIPANT_PERMISSIONS_CHANGED", normalizedName, participant.permissions, oldPermissions)
    
    return true
end

function SessionStateManager:LockSession()
    if not self:IsInSession() then
        self.Debug("WARN", "No active session")
        return false
    end
    
    if not self:HasPermission(SESSION_PERMISSIONS.ADMIN) then
        self.Debug("WARN", "Insufficient permissions to lock session")
        return false
    end
    
    sessionState.isLocked = true
    
    self.Debug("INFO", "Session locked")
    self:FireEvent("SESSION_LOCKED")
    
    return true
end

function SessionStateManager:UnlockSession()
    if not self:IsInSession() then
        self.Debug("WARN", "No active session")
        return false
    end
    
    if not self:HasPermission(SESSION_PERMISSIONS.ADMIN) then
        self.Debug("WARN", "Insufficient permissions to unlock session")
        return false
    end
    
    sessionState.isLocked = false
    
    self.Debug("INFO", "Session unlocked")
    self:FireEvent("SESSION_UNLOCKED")
    
    return true
end

function SessionStateManager:IsInSession()
    return sessionState.isActive and sessionState.sessionId ~= nil
end

function SessionStateManager:IsSessionOwner()
    return sessionState.isOwner
end

function SessionStateManager:IsSessionLocked()
    return sessionState.isLocked
end

function SessionStateManager:HasPermission(permission)
    if not self:IsInSession() then
        return true
    end
    
    if sessionState.isOwner then
        return true
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if not playerInfo then
        return false
    end
    
    local participant = sessionState.participants[playerInfo.fullName]
    if not participant then
        return false
    end
    
    for _, perm in ipairs(participant.permissions) do
        if perm == permission or perm == SESSION_PERMISSIONS.ADMIN then
            return true
        end
    end
    
    return false
end

function SessionStateManager:CanEditMembers()
    if not self:IsInSession() then
        return true
    end
    
    if sessionState.isLocked then
        return self:HasPermission(SESSION_PERMISSIONS.ADMIN)
    end
    
    return self:HasPermission(SESSION_PERMISSIONS.EDIT_MEMBERS)
end

function SessionStateManager:CanEditGroups()
    if not self:IsInSession() then
        return true
    end
    
    if sessionState.isLocked then
        return self:HasPermission(SESSION_PERMISSIONS.ADMIN)
    end
    
    return self:HasPermission(SESSION_PERMISSIONS.EDIT_GROUPS)
end

function SessionStateManager:GetSessionInfo()
    if not self:IsInSession() then
        return nil
    end
    
    return {
        sessionId = sessionState.sessionId,
        ownerId = sessionState.ownerId,
        isOwner = sessionState.isOwner,
        isActive = sessionState.isActive,
        isLocked = sessionState.isLocked,
        createdTime = sessionState.createdTime,
        participantCount = addon.SharedUtilities:GetTableSize(sessionState.participants),
        adminCount = addon.SharedUtilities:GetTableSize(sessionState.admins)
    }
end

function SessionStateManager:GetParticipants()
    local participants = {}
    for name, data in pairs(sessionState.participants) do
        table.insert(participants, {
            name = name,
            joinTime = data.joinTime,
            permissions = data.permissions,
            isAdmin = sessionState.admins[name] == true
        })
    end
    return participants
end

function SessionStateManager:GetShareableData()
    if not self:IsInSession() then
        return nil
    end
    
    return {
        sessionId = sessionState.sessionId,
        ownerId = sessionState.ownerId,
        isLocked = sessionState.isLocked,
        createdTime = sessionState.createdTime,
        participants = sessionState.participants,
        admins = sessionState.admins,
        timestamp = addon.WoWAPIWrapper:GetServerTime()
    }
end

function SessionStateManager:ImportSharedData(sessionData, sender)
    if not sessionData or not sessionData.sessionId then
        self.Debug("WARN", "Invalid shared session data from:", sender)
        return false
    end
    
    if self:IsInSession() and sessionState.sessionId ~= sessionData.sessionId then
        self.Debug("DEBUG", "Ignoring session data for different session")
        return false
    end
    
    if not self:IsInSession() and sessionData.ownerId ~= sender then
        self.Debug("WARN", "Session data not from owner, ignoring")
        return false
    end
    
    if not self:IsInSession() then
        self:JoinSession(sessionData.sessionId, sessionData.ownerId)
    end
    
    sessionState.isLocked = sessionData.isLocked
    sessionState.createdTime = sessionData.createdTime
    
    if sessionData.participants then
        for name, data in pairs(sessionData.participants) do
            if not sessionState.participants[name] then
                sessionState.participants[name] = data
            end
        end
    end
    
    if sessionData.admins then
        for name, _ in pairs(sessionData.admins) do
            sessionState.admins[name] = true
        end
    end
    
    self.Debug("INFO", "Imported session data from:", sender)
    self:FireEvent("SESSION_DATA_IMPORTED", sessionData, sender)
    
    return true
end

function SessionStateManager:ClearSessionState()
    sessionState.sessionId = nil
    sessionState.ownerId = nil
    sessionState.isOwner = false
    sessionState.admins = {}
    sessionState.isActive = false
    sessionState.isLocked = false
    sessionState.createdTime = nil
    sessionState.participants = {}
    
    self.Debug("DEBUG", "Session state cleared")
end

function SessionStateManager:GenerateSessionId()
    local time = addon.WoWAPIWrapper:GetTime()
    local random = math.random(10000, 99999)
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    local playerName = playerInfo and playerInfo.name or "Unknown"
    return string.format("%s-%d-%d", playerName, time, random)
end


function SessionStateManager:EmbedLibraries()
    return addon.SharedUtilities.LibraryEmbedding:EmbedRequired(self, {"AceEvent-3.0"})
end

function SessionStateManager:OnDisable()
    self.Debug("INFO", "Disabling SessionStateManager")
    
    -- End any active session
    if self:IsInSession() and self:IsSessionOwner() then
        self:EndSession()
    elseif self:IsInSession() then
        self:LeaveSession()
    end
    
    -- Unregister all messages
    if self.UnregisterAllMessages then
        self:UnregisterAllMessages()
        self.Debug("DEBUG", "Unregistered all message handlers")
    end
    
    -- Clear session state
    self:ClearSessionState()
    
    self.Debug("DEBUG", "SessionStateManager disabled successfully")
end


return SessionStateManager