local addonName, addon = ...

local SessionNotificationManager = {}
addon.SessionNotificationManager = SessionNotificationManager

for k, v in pairs(addon.DebugMixin) do
    SessionNotificationManager[k] = v
end
SessionNotificationManager:InitDebug("SessionNotification")

-- AceEvent will be embedded safely during initialization

local notificationState = {
    isInitialized = false,
    activeRecruitment = nil,
    recruitmentStartTime = nil,
    recruitmentTimeout = 60,
    detectedAddons = {},
    responses = {},
    whisperResponses = {},
    lastDetectionTime = 0,
    detectionCooldown = 30
}

local RECRUITMENT_STATUS = {
    DETECTING = "DETECTING",
    RECRUITING = "RECRUITING", 
    FINALIZING = "FINALIZING",
    COMPLETE = "COMPLETE"
}

local DEFAULT_SETTINGS = {
    sessionNotifications = {
        enabled = true,
        style = "POPUP_AND_CHAT", -- or "CHAT_ONLY"
        responseTimeout = 60,
        snoozeDuration = 300,
        channels = {
            GUILD = true,
            PARTY = false,
            RAID = false
        },
        messageTemplate = "GrouperPlus session starting! Join through your addon or whisper me '1' to join the session"
    }
}

function SessionNotificationManager:OnInitialize()
    self.Debug("INFO", "Initializing SessionNotificationManager")
    
    -- Safely embed required Ace3 libraries
    if not self:EmbedLibraries() then
        self.Debug("ERROR", "Failed to embed required libraries")
        return false
    end
    
    self.notificationState = notificationState
    self.RECRUITMENT_STATUS = RECRUITMENT_STATUS
    self.DEFAULT_SETTINGS = DEFAULT_SETTINGS
    
    -- Initialize default settings if not present (defer if settings not ready)
    if addon.settings then
        if not addon.settings.sessionNotifications then
            addon.settings.sessionNotifications = self:DeepCopy(DEFAULT_SETTINGS.sessionNotifications)
        end
    else
        self.Debug("WARN", "Settings not yet loaded, will initialize defaults later")
    end
    
    -- Register for whisper messages during active recruitment
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisperReceived")
    
    -- Register for session events
    self:RegisterMessage("GROUPERPLUS_SESSION_CREATED", "OnSessionCreated")
    
    notificationState.isInitialized = true
    self.Debug("DEBUG", "SessionNotificationManager initialized successfully")
    return true
end

function SessionNotificationManager:EnsureSettingsInitialized()
    if not addon.settings then
        return false
    end
    
    if not addon.settings.sessionNotifications then
        addon.settings.sessionNotifications = self:DeepCopy(DEFAULT_SETTINGS.sessionNotifications)
        self.Debug("DEBUG", "Initialized session notification settings")
    end
    
    return true
end

function SessionNotificationManager:OnSessionCreated(event, sessionInfo)
    if not sessionInfo then
        self.Debug("WARN", "Received session created event without session info")
        return
    end
    
    -- Only start recruitment if this is our session and notifications are enabled
    if sessionInfo.isOwner and self:EnsureSettingsInitialized() and addon.settings.sessionNotifications.enabled then
        self.Debug("INFO", "Starting recruitment for newly created session:", sessionInfo.sessionId)
        
        -- Start recruitment automatically
        self:StartSessionRecruitment(sessionInfo)
    end
end

function SessionNotificationManager:StartSessionRecruitment(sessionData)
    if notificationState.activeRecruitment then
        self.Debug("WARN", "Recruitment already in progress")
        return false, "Recruitment already in progress"
    end
    
    if not self:CanStartRecruitment() then
        self.Debug("WARN", "Cannot start recruitment - cooldown or other restrictions")
        return false, "Cannot start recruitment yet"
    end
    
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if not playerInfo then
        self.Debug("ERROR", "Failed to get player info for recruitment")
        return false, "Failed to get player info"
    end
    
    -- Ensure settings are initialized
    if not self:EnsureSettingsInitialized() then
        self.Debug("ERROR", "Settings not available for recruitment")
        return false, "Settings not available"
    end
    
    -- Initialize recruitment state
    notificationState.activeRecruitment = {
        sessionId = sessionData.sessionId,
        leaderId = playerInfo.fullName,
        status = RECRUITMENT_STATUS.DETECTING,
        startTime = addon.WoWAPIWrapper:GetServerTime(),
        timeout = addon.settings.sessionNotifications.responseTimeout,
        detectedAddons = {},
        responses = {},
        whisperResponses = {}
    }
    
    self.Debug("INFO", "Starting session recruitment for session:", sessionData.sessionId)
    
    -- Phase 1: Detect addon users
    self:StartAddonDetection()
    
    return true, "Recruitment started"
end

function SessionNotificationManager:StartAddonDetection()
    if not notificationState.activeRecruitment then
        return false
    end
    
    self.Debug("DEBUG", "Starting addon detection phase")
    notificationState.activeRecruitment.status = RECRUITMENT_STATUS.DETECTING
    
    -- Use existing ping system to detect addon users
    if addon.StateSync then
        addon.StateSync:SendPing()
    end
    
    -- Schedule transition to recruitment phase
    self:ScheduleTimer("TransitionToRecruitment", 5.0)
    
    return true
end

function SessionNotificationManager:TransitionToRecruitment()
    if not notificationState.activeRecruitment then
        return
    end
    
    self.Debug("DEBUG", "Transitioning to recruitment phase")
    notificationState.activeRecruitment.status = RECRUITMENT_STATUS.RECRUITING
    
    local detectedCount = self:GetTableSize(notificationState.activeRecruitment.detectedAddons)
    self.Debug("INFO", "Detected", detectedCount, "addon users, starting recruitment")
    
    -- Send recruitment notifications
    self:SendRecruitmentNotifications()
    
    -- Send chat announcements
    self:SendChatAnnouncements()
    
    -- Schedule recruitment timeout
    self:ScheduleTimer("FinalizeRecruitment", notificationState.activeRecruitment.timeout)
end

function SessionNotificationManager:SendRecruitmentNotifications()
    if not notificationState.activeRecruitment then
        return false
    end
    
    -- Only send to detected addon users if popup notifications are enabled
    if self:EnsureSettingsInitialized() and addon.settings.sessionNotifications.style == "POPUP_AND_CHAT" then
        local message = addon.MessageProtocol:CreateSessionRecruitment({
            sessionId = notificationState.activeRecruitment.sessionId,
            leaderId = notificationState.activeRecruitment.leaderId,
            timeout = notificationState.activeRecruitment.timeout,
            description = "M+ Groups forming - Join now!"
        })
        
        if message then
            addon.StateSync:SendMessage(message)
            self.Debug("DEBUG", "Sent recruitment notifications to addon users")
        end
    end
    
    return true
end

function SessionNotificationManager:SendChatAnnouncements()
    if not notificationState.activeRecruitment then
        return false
    end
    
    if not self:EnsureSettingsInitialized() then
        self.Debug("ERROR", "Settings not available for chat announcements")
        return false
    end
    
    local settings = addon.settings.sessionNotifications
    local channels = settings.channels
    local message = settings.messageTemplate
    
    -- Send to enabled channels
    if channels.GUILD and addon.WoWAPIWrapper:IsInGuild() then
        SendChatMessage(message, "GUILD")
        self.Debug("DEBUG", "Sent recruitment announcement to GUILD")
    end
    
    if channels.PARTY and addon.WoWAPIWrapper:IsInGroup() and not addon.WoWAPIWrapper:IsInRaid() then
        SendChatMessage(message, "PARTY")
        self.Debug("DEBUG", "Sent recruitment announcement to PARTY")
    end
    
    if channels.RAID and addon.WoWAPIWrapper:IsInRaid() then
        SendChatMessage(message, "RAID")
        self.Debug("DEBUG", "Sent recruitment announcement to RAID")
    end
    
    return true
end

function SessionNotificationManager:HandleAddonResponse(playerName, accepted)
    if not notificationState.activeRecruitment then
        self.Debug("WARN", "Received addon response but no active recruitment")
        return false
    end
    
    if notificationState.activeRecruitment.status ~= RECRUITMENT_STATUS.RECRUITING then
        self.Debug("WARN", "Received response outside of recruiting phase")
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(playerName)
    notificationState.activeRecruitment.responses[normalizedName] = {
        type = "ADDON",
        accepted = accepted,
        timestamp = addon.WoWAPIWrapper:GetServerTime()
    }
    
    self.Debug("INFO", "Recorded addon response from:", normalizedName, "accepted:", accepted)
    
    if accepted and addon.SessionStateManager then
        addon.SessionStateManager:AddParticipant(normalizedName)
    end
    
    return true
end

function SessionNotificationManager:OnWhisperReceived(event, message, sender, ...)
    if not notificationState.activeRecruitment then
        return
    end
    
    if notificationState.activeRecruitment.status ~= RECRUITMENT_STATUS.RECRUITING then
        return
    end
    
    -- Parse whisper for recruitment response
    local trimmedMessage = strtrim(message)
    
    if trimmedMessage == "1" then
        self:HandleWhisperResponse(sender, true)
    end
end

function SessionNotificationManager:HandleWhisperResponse(playerName, accepted)
    if not notificationState.activeRecruitment then
        return false
    end
    
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(playerName)
    
    -- Check if this player already responded
    if notificationState.activeRecruitment.responses[normalizedName] or 
       notificationState.activeRecruitment.whisperResponses[normalizedName] then
        self.Debug("DEBUG", "Duplicate response from:", normalizedName)
        return false
    end
    
    notificationState.activeRecruitment.whisperResponses[normalizedName] = {
        type = "WHISPER",
        accepted = accepted,
        timestamp = addon.WoWAPIWrapper:GetServerTime()
    }
    
    self.Debug("INFO", "Recorded whisper response from:", normalizedName, "accepted:", accepted)
    
    if accepted then
        -- Send confirmation whisper
        SendChatMessage("Added to session! You'll receive group assignments shortly.", "WHISPER", playerName)
        
        -- Add to session as manual participant
        if addon.SessionStateManager then
            addon.SessionStateManager:AddParticipant(normalizedName)
        end
    end
    
    return true
end

function SessionNotificationManager:FinalizeRecruitment()
    if not notificationState.activeRecruitment then
        return
    end
    
    self.Debug("INFO", "Finalizing recruitment phase")
    notificationState.activeRecruitment.status = RECRUITMENT_STATUS.FINALIZING
    
    local addonResponses = self:GetTableSize(notificationState.activeRecruitment.responses)
    local whisperResponses = self:GetTableSize(notificationState.activeRecruitment.whisperResponses)
    local totalResponses = addonResponses + whisperResponses
    
    self.Debug("INFO", "Recruitment complete - Addon responses:", addonResponses, "Whisper responses:", whisperResponses, "Total:", totalResponses)
    
    -- Trigger group formation if we have participants
    if totalResponses > 0 then
        self:TriggerGroupFormation()
    end
    
    -- Clean up recruitment state
    self:EndRecruitment()
end

function SessionNotificationManager:TriggerGroupFormation()
    if not notificationState.activeRecruitment then
        return
    end
    
    -- This would trigger the existing auto-formation system
    if addon.AutoFormation and addon.AutoFormation.FormGroups then
        self:ScheduleTimer(function()
            addon.AutoFormation:FormGroups()
        end, 1.0)
    end
    
    self.Debug("INFO", "Triggered group formation")
end

function SessionNotificationManager:EndRecruitment()
    if notificationState.activeRecruitment then
        notificationState.activeRecruitment.status = RECRUITMENT_STATUS.COMPLETE
        
        -- Clear active recruitment after delay to allow final processing
        self:ScheduleTimer(function()
            notificationState.activeRecruitment = nil
        end, 5.0)
    end
    
    self.Debug("DEBUG", "Recruitment ended")
end

function SessionNotificationManager:CanStartRecruitment()
    if notificationState.activeRecruitment then
        return false
    end
    
    -- Check cooldown
    local now = addon.WoWAPIWrapper:GetTime()
    if (now - notificationState.lastDetectionTime) < notificationState.detectionCooldown then
        return false
    end
    
    -- Check if notifications are enabled
    if not self:EnsureSettingsInitialized() or not addon.settings.sessionNotifications.enabled then
        return false
    end
    
    return true
end

function SessionNotificationManager:IsRecruitmentActive()
    return notificationState.activeRecruitment ~= nil
end

function SessionNotificationManager:GetRecruitmentStatus()
    if not notificationState.activeRecruitment then
        return nil
    end
    
    return {
        status = notificationState.activeRecruitment.status,
        sessionId = notificationState.activeRecruitment.sessionId,
        startTime = notificationState.activeRecruitment.startTime,
        timeout = notificationState.activeRecruitment.timeout,
        detectedAddons = self:GetTableSize(notificationState.activeRecruitment.detectedAddons),
        addonResponses = self:GetTableSize(notificationState.activeRecruitment.responses),
        whisperResponses = self:GetTableSize(notificationState.activeRecruitment.whisperResponses)
    }
end

function SessionNotificationManager:HandlePongResponse(playerName)
    local normalizedName = addon.WoWAPIWrapper:NormalizePlayerName(playerName)
    
    if notificationState.activeRecruitment then
        notificationState.activeRecruitment.detectedAddons[normalizedName] = {
            timestamp = addon.WoWAPIWrapper:GetServerTime(),
            source = "PING_PONG"
        }
    end
    
    -- Also update global detection cache
    notificationState.detectedAddons[normalizedName] = addon.WoWAPIWrapper:GetServerTime()
    
    self.Debug("TRACE", "Recorded addon presence for:", normalizedName)
end

function SessionNotificationManager:HandleRecruitmentNotification(recruitmentData, sender)
    -- Check if notifications are enabled and this isn't from ourselves
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if not playerInfo or sender == playerInfo.fullName then
        return
    end
    
    if not self:EnsureSettingsInitialized() then
        self.Debug("DEBUG", "Settings not available, ignoring recruitment from:", sender)
        return
    end
    
    if not addon.settings.sessionNotifications.enabled then
        self.Debug("DEBUG", "Session notifications disabled, ignoring recruitment from:", sender)
        return
    end
    
    -- Only show popup if style is set to popup+chat
    if addon.settings.sessionNotifications.style == "POPUP_AND_CHAT" then
        self:ShowRecruitmentNotification(recruitmentData, sender)
    end
    
    self.Debug("INFO", "Received recruitment notification from:", sender, "session:", recruitmentData.sessionId)
end

function SessionNotificationManager:HandleJoinRequest(requestData, sender)
    -- This would handle incoming join requests (for session leaders)
    self.Debug("DEBUG", "Received join request from:", sender, "for session:", requestData.sessionId)
    
    -- Forward to session manager if we're the leader of this session
    if addon.SessionStateManager and addon.SessionStateManager:IsSessionOwner() then
        local sessionInfo = addon.SessionStateManager:GetSessionInfo()
        if sessionInfo and sessionInfo.sessionId == requestData.sessionId then
            -- Auto-accept for now - could add approval workflow later
            self:SendJoinResponse(requestData.sessionId, true, sender)
            addon.SessionStateManager:AddParticipant(sender)
        end
    end
end

function SessionNotificationManager:HandleJoinResponse(responseData, sender)
    -- This would handle responses from potential participants
    self.Debug("DEBUG", "Received join response from:", sender, "accepted:", responseData.accepted)
    
    if responseData.accepted then
        self:HandleAddonResponse(sender, true)
    end
end

function SessionNotificationManager:SendJoinResponse(sessionId, accepted, targetPlayer)
    local message = addon.MessageProtocol:CreateSessionJoinResponse(sessionId, accepted)
    if message and addon.StateSync then
        addon.StateSync:SendMessage(message, "WHISPER", targetPlayer)
        self.Debug("DEBUG", "Sent join response to:", targetPlayer, "accepted:", accepted)
    end
end

function SessionNotificationManager:ShowRecruitmentNotification(recruitmentData, sender)
    if addon.SessionNotificationUI then
        addon.SessionNotificationUI:ShowRecruitmentNotification(recruitmentData, sender)
    else
        self.Debug("WARN", "SessionNotificationUI not available")
    end
end

function SessionNotificationManager:GetTableSize(tbl)
    local count = 0
    if tbl then
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
end

function SessionNotificationManager:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[self:DeepCopy(orig_key)] = self:DeepCopy(orig_value)
        end
        setmetatable(copy, self:DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function SessionNotificationManager:EmbedLibraries()
    local LibraryManager = addon.LibraryManager
    if not LibraryManager then
        self.Debug("ERROR", "LibraryManager not available")
        return false
    end
    
    -- Embed AceEvent-3.0
    if not LibraryManager:SafeEmbed(self, "AceEvent-3.0") then
        self.Debug("ERROR", "Failed to embed AceEvent-3.0")
        return false
    end
    
    -- Embed AceTimer-3.0
    if not LibraryManager:SafeEmbed(self, "AceTimer-3.0") then
        self.Debug("ERROR", "Failed to embed AceTimer-3.0")
        return false
    end
    
    return true
end

function SessionNotificationManager:OnDisable()
    self.Debug("INFO", "Disabling SessionNotificationManager")
    
    -- End any active recruitment
    if notificationState.activeRecruitment then
        self:EndRecruitment()
    end
    
    -- Cancel all timers
    if self.CancelAllTimers then
        self:CancelAllTimers()
        self.Debug("DEBUG", "Cancelled all timers")
    end
    
    -- Unregister all events
    if self.UnregisterAllEvents then
        self:UnregisterAllEvents()
        self.Debug("DEBUG", "Unregistered all events")
    end
    
    -- Clear state
    notificationState.isInitialized = false
    notificationState.activeRecruitment = nil
    
    self.Debug("DEBUG", "SessionNotificationManager disabled successfully")
end

return SessionNotificationManager