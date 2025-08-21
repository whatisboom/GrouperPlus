local addonName, addon = ...

local SessionManager = addon.ModuleBase:New("Session")
addon.SessionManager = SessionManager

local sessionState = {
    sessionId = nil,
    sessionOwner = nil,
    isOwner = false,
    whitelist = {},
    isFinalized = false,
    sessionStartTime = nil,
    participants = {},
}

function SessionManager:OnInitialize()
    self.Debug("INFO", "Initializing session manager")
    
    self.sessionState = sessionState
    
    self:RegisterEvents()
    self:RegisterCommHandlers()
    
    self.Debug("DEBUG", "Session manager initialized successfully")
end

function SessionManager:RegisterEvents()
    self.Debug("TRACE", "Registering session events")
end

function SessionManager:RegisterCommHandlers()
    self.Debug("TRACE", "SessionManager:RegisterCommHandlers - Registering session comm handlers")
    
    local AddonComm = addon.AddonComm
    if AddonComm and AddonComm.RegisterHandler then
        AddonComm:RegisterHandler("SESSION_CREATE", function(data, sender) self:OnSessionCreate(data, sender) end)
        AddonComm:RegisterHandler("SESSION_JOIN", function(data, sender) self:OnSessionJoin(data, sender) end)
        AddonComm:RegisterHandler("SESSION_LEAVE", function(data, sender) self:OnSessionLeave(data, sender) end)
        AddonComm:RegisterHandler("SESSION_WHITELIST", function(data, sender) self:OnWhitelistUpdate(data, sender) end)
        AddonComm:RegisterHandler("SESSION_FINALIZE", function(data, sender) self:OnSessionFinalize(data, sender) end)
        AddonComm:RegisterHandler("SESSION_STATE", function(data, sender) self:OnSessionStateUpdate(data, sender) end)
        AddonComm:RegisterHandler("SESSION_END", function(data, sender) self:OnSessionEnd(data, sender) end)
    end
end

function SessionManager:CreateSession()
    self.Debug("INFO", "SessionManager:CreateSession - Creating new grouping session")
    
    if self:IsInSession() then
        self.Debug("WARN", "SessionManager:CreateSession - Already in a session")
        return false, "Already in a session"
    end
    
    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local fullName = playerName .. "-" .. playerRealm
    
    sessionState.sessionId = self:GenerateSessionId()
    sessionState.sessionOwner = fullName
    sessionState.isOwner = true
    sessionState.whitelist = { [fullName] = true }
    sessionState.isFinalized = false
    sessionState.sessionStartTime = GetTime()
    sessionState.participants = { [fullName] = { joinTime = GetTime(), hasEditPermission = true } }
    
    self.Debug("INFO", "SessionManager:CreateSession - Session created with ID: " .. sessionState.sessionId)
    
    self:BroadcastSessionCreate()
    self:UpdateUI()
    
    return true, sessionState.sessionId
end

function SessionManager:JoinSession(sessionId, owner)
    self.Debug("INFO", "SessionManager:JoinSession", "Joining session: " .. tostring(sessionId))
    
    if self:IsInSession() then
        self.Debug("WARN", "SessionManager:JoinSession", "Already in a session")
        return false, "Already in a session"
    end
    
    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local fullName = playerName .. "-" .. playerRealm
    
    sessionState.sessionId = sessionId
    sessionState.sessionOwner = owner
    sessionState.isOwner = false
    sessionState.whitelist = {}
    sessionState.isFinalized = false
    sessionState.participants = { [fullName] = { joinTime = GetTime(), hasEditPermission = false } }
    
    self:BroadcastSessionJoin()
    self:UpdateUI()
    
    return true
end

function SessionManager:LeaveSession()
    self.Debug("INFO", "SessionManager:LeaveSession", "Leaving current session")
    
    if not self:IsInSession() then
        self.Debug("WARN", "SessionManager:LeaveSession", "Not in a session")
        return false, "Not in a session"
    end
    
    self:BroadcastSessionLeave()
    
    if sessionState.isOwner then
        self:EndSession()
    else
        self:ClearSessionState()
        self:UpdateUI()
    end
    
    return true
end

function SessionManager:EndSession()
    self.Debug("INFO", "SessionManager:EndSession", "Ending current session")
    
    if not sessionState.isOwner then
        self.Debug("WARN", "SessionManager:EndSession", "Only session owner can end the session")
        return false, "Only session owner can end the session"
    end
    
    self:BroadcastSessionEnd()
    self:ClearSessionState()
    self:UpdateUI()
    
    return true
end

function SessionManager:AddToWhitelist(playerName)
    self.Debug("INFO", "SessionManager:AddToWhitelist", "Adding player to whitelist: " .. tostring(playerName))
    
    if not sessionState.isOwner then
        self.Debug("WARN", "SessionManager:AddToWhitelist", "Only session owner can modify whitelist")
        return false, "Only session owner can modify whitelist"
    end
    
    sessionState.whitelist[playerName] = true
    
    if sessionState.participants[playerName] then
        sessionState.participants[playerName].hasEditPermission = true
    end
    
    self:BroadcastWhitelistUpdate()
    self:UpdateUI()
    
    return true
end

function SessionManager:RemoveFromWhitelist(playerName)
    self.Debug("INFO", "SessionManager:RemoveFromWhitelist", "Removing player from whitelist: " .. tostring(playerName))
    
    if not sessionState.isOwner then
        self.Debug("WARN", "SessionManager:RemoveFromWhitelist", "Only session owner can modify whitelist")
        return false, "Only session owner can modify whitelist"
    end
    
    local playerNameFull = UnitName("player") .. "-" .. GetRealmName()
    if playerName == sessionState.sessionOwner or playerName == playerNameFull then
        self.Debug("WARN", "SessionManager:RemoveFromWhitelist", "Cannot remove session owner from whitelist")
        return false, "Cannot remove session owner from whitelist"
    end
    
    sessionState.whitelist[playerName] = nil
    
    if sessionState.participants[playerName] then
        sessionState.participants[playerName].hasEditPermission = false
    end
    
    self:BroadcastWhitelistUpdate()
    self:UpdateUI()
    
    return true
end

function SessionManager:FinalizeGroups()
    self.Debug("INFO", "SessionManager:FinalizeGroups", "Finalizing group composition")
    
    if not sessionState.isOwner then
        self.Debug("WARN", "SessionManager:FinalizeGroups", "Only session owner can finalize groups")
        return false, "Only session owner can finalize groups"
    end
    
    if sessionState.isFinalized then
        self.Debug("WARN", "SessionManager:FinalizeGroups", "Groups already finalized")
        return false, "Groups already finalized"
    end
    
    sessionState.isFinalized = true
    
    self:BroadcastSessionFinalize()
    self:UpdateUI()
    
    self.Debug("INFO", "SessionManager:FinalizeGroups", "Groups finalized successfully")
    
    return true
end

function SessionManager:CanEdit()
    local inSession = self:IsInSession()
    self.Debug("TRACE", "SessionManager:CanEdit - inSession:", inSession)
    
    if not inSession then
        self.Debug("TRACE", "SessionManager:CanEdit - Not in session, allowing edit")
        return true
    end
    
    if sessionState.isFinalized then
        self.Debug("TRACE", "SessionManager:CanEdit - Session is finalized, denying edit")
        return false
    end
    
    if sessionState.isOwner then
        self.Debug("TRACE", "SessionManager:CanEdit - Is session owner, allowing edit")
        return true
    end
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    local isWhitelisted = sessionState.whitelist[playerName] == true
    self.Debug("TRACE", "SessionManager:CanEdit - Player:", playerName, "isWhitelisted:", isWhitelisted)
    
    return isWhitelisted
end

function SessionManager:IsInSession()
    return sessionState.sessionId ~= nil
end

function SessionManager:IsSessionOwner()
    return sessionState.isOwner
end

function SessionManager:IsSessionFinalized()
    return sessionState.isFinalized
end

function SessionManager:GetSessionInfo()
    if not self:IsInSession() then
        return nil
    end
    
    return {
        sessionId = sessionState.sessionId,
        owner = sessionState.sessionOwner,
        isOwner = sessionState.isOwner,
        isFinalized = sessionState.isFinalized,
        participantCount = self:GetTableSize(sessionState.participants),
        whitelistCount = self:GetTableSize(sessionState.whitelist),
        startTime = sessionState.sessionStartTime
    }
end

function SessionManager:GetParticipants()
    return sessionState.participants or {}
end

function SessionManager:GetWhitelist()
    return sessionState.whitelist or {}
end

function SessionManager:BroadcastSessionCreate()
    self.Debug("DEBUG", "SessionManager:BroadcastSessionCreate", "Broadcasting session creation")
    
    local data = {
        sessionId = sessionState.sessionId,
        owner = sessionState.sessionOwner,
        startTime = sessionState.sessionStartTime
    }
    
    if addon.AddonComm then
        addon.AddonComm:BroadcastMessage("SESSION_CREATE", data)
    end
end

function SessionManager:BroadcastSessionJoin()
    self.Debug("DEBUG", "SessionManager:BroadcastSessionJoin", "Broadcasting session join")
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    local data = {
        sessionId = sessionState.sessionId,
        player = playerName
    }
    
    if addon.AddonComm then
        addon.AddonComm:BroadcastMessage("SESSION_JOIN", data)
    end
end

function SessionManager:BroadcastSessionLeave()
    self.Debug("DEBUG", "SessionManager:BroadcastSessionLeave", "Broadcasting session leave")
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    local data = {
        sessionId = sessionState.sessionId,
        player = playerName
    }
    
    if addon.AddonComm then
        addon.AddonComm:BroadcastMessage("SESSION_LEAVE", data)
    end
end

function SessionManager:BroadcastWhitelistUpdate()
    self.Debug("DEBUG", "SessionManager:BroadcastWhitelistUpdate", "Broadcasting whitelist update")
    
    local data = {
        sessionId = sessionState.sessionId,
        whitelist = sessionState.whitelist
    }
    
    if addon.AddonComm then
        addon.AddonComm:BroadcastMessage("SESSION_WHITELIST", data)
    end
end

function SessionManager:BroadcastSessionFinalize()
    self.Debug("DEBUG", "SessionManager:BroadcastSessionFinalize", "Broadcasting session finalization")
    
    local data = {
        sessionId = sessionState.sessionId
    }
    
    if addon.AddonComm then
        addon.AddonComm:BroadcastMessage("SESSION_FINALIZE", data)
    end
end

function SessionManager:BroadcastSessionEnd()
    self.Debug("DEBUG", "SessionManager:BroadcastSessionEnd", "Broadcasting session end")
    
    local data = {
        sessionId = sessionState.sessionId
    }
    
    if addon.AddonComm then
        addon.AddonComm:BroadcastMessage("SESSION_END", data)
    end
end

function SessionManager:OnSessionCreate(data, sender)
    self.Debug("DEBUG", "SessionManager:OnSessionCreate", "Received session create from: " .. tostring(sender))
    
    if self:IsInSession() then
        self.Debug("DEBUG", "SessionManager:OnSessionCreate", "Already in a session, ignoring")
        return
    end
    
    addon:Print("A grouping session has been started by " .. tostring(data.owner))
    self:UpdateUI()
end

function SessionManager:OnSessionJoin(data, sender)
    self.Debug("DEBUG", "SessionManager:OnSessionJoin", "Player joined session: " .. tostring(data.player))
    
    if not self:IsInSession() or sessionState.sessionId ~= data.sessionId then
        return
    end
    
    sessionState.participants[data.player] = { 
        joinTime = GetTime(), 
        hasEditPermission = sessionState.whitelist[data.player] == true 
    }
    
    self:UpdateUI()
end

function SessionManager:OnSessionLeave(data, sender)
    self.Debug("DEBUG", "SessionManager:OnSessionLeave", "Player left session: " .. tostring(data.player))
    
    if not self:IsInSession() or sessionState.sessionId ~= data.sessionId then
        return
    end
    
    sessionState.participants[data.player] = nil
    
    self:UpdateUI()
end

function SessionManager:OnWhitelistUpdate(data, sender)
    self.Debug("DEBUG", "SessionManager:OnWhitelistUpdate", "Received whitelist update")
    
    if not self:IsInSession() or sessionState.sessionId ~= data.sessionId then
        return
    end
    
    if sender ~= sessionState.sessionOwner then
        self.Debug("WARN", "SessionManager:OnWhitelistUpdate", "Whitelist update from non-owner, ignoring")
        return
    end
    
    sessionState.whitelist = data.whitelist or {}
    
    local playerName = UnitName("player") .. "-" .. GetRealmName()
    for participant, info in pairs(sessionState.participants) do
        info.hasEditPermission = sessionState.whitelist[participant] == true or participant == sessionState.sessionOwner
    end
    
    self:UpdateUI()
end

function SessionManager:OnSessionFinalize(data, sender)
    self.Debug("DEBUG", "SessionManager:OnSessionFinalize", "Session finalized")
    
    if not self:IsInSession() or sessionState.sessionId ~= data.sessionId then
        return
    end
    
    if sender ~= sessionState.sessionOwner then
        self.Debug("WARN", "SessionManager:OnSessionFinalize", "Finalize from non-owner, ignoring")
        return
    end
    
    sessionState.isFinalized = true
    
    addon:Print("Groups have been finalized by the session owner")
    self:UpdateUI()
end

function SessionManager:OnSessionEnd(data, sender)
    self.Debug("DEBUG", "SessionManager:OnSessionEnd", "Session ended")
    
    if not self:IsInSession() or sessionState.sessionId ~= data.sessionId then
        return
    end
    
    if sender ~= sessionState.sessionOwner then
        self.Debug("WARN", "SessionManager:OnSessionEnd", "End session from non-owner, ignoring")
        return
    end
    
    addon:Print("The grouping session has ended")
    self:ClearSessionState()
    self:UpdateUI()
end

function SessionManager:ClearSessionState()
    self.Debug("DEBUG", "SessionManager:ClearSessionState", "Clearing session state")
    
    sessionState.sessionId = nil
    sessionState.sessionOwner = nil
    sessionState.isOwner = false
    sessionState.whitelist = {}
    sessionState.isFinalized = false
    sessionState.sessionStartTime = nil
    sessionState.participants = {}
end

function SessionManager:UpdateUI()
    self.Debug("TRACE", "SessionManager:UpdateUI", "Updating UI for session state")
    
    if addon.MainFrame and addon.MainFrame.UpdateSessionUI then
        addon.MainFrame:UpdateSessionUI()
    end
end

function SessionManager:GenerateSessionId()
    local time = GetTime()
    local random = math.random(10000, 99999)
    local playerName = UnitName("player")
    return string.format("%s-%d-%d", playerName, time, random)
end

function SessionManager:GetTableSize(tbl)
    local count = 0
    if tbl then
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
end

return SessionManager