local addonName, addon = ...

local SessionNotificationUI = {}
addon.SessionNotificationUI = SessionNotificationUI

addon.DebugMixin:InjectInto(SessionNotificationUI, "SessionNotificationUI")

local activeNotifications = {}
local NOTIFICATION_WIDTH = 300
local NOTIFICATION_HEIGHT = 80
local NOTIFICATION_DURATION = 30
local NOTIFICATION_FADE_TIME = 2

function SessionNotificationUI:OnInitialize()
    self.Debug("INFO", "Initializing SessionNotificationUI")
    
    self.activeNotifications = activeNotifications
    
    self.Debug("DEBUG", "SessionNotificationUI initialized successfully")
    return true
end

function SessionNotificationUI:ShowRecruitmentNotification(recruitmentData, sender)
    if not recruitmentData or not sender then
        self.Debug("WARN", "Invalid recruitment notification data")
        return
    end
    
    -- Check if we already have a notification from this sender
    if activeNotifications[sender] then
        self:HideRecruitmentNotification(sender)
    end
    
    local notification = self:CreateNotificationFrame(recruitmentData, sender)
    if not notification then
        self.Debug("ERROR", "Failed to create notification frame")
        return
    end
    
    activeNotifications[sender] = {
        frame = notification,
        sessionId = recruitmentData.sessionId,
        startTime = GetTime()
    }
    
    -- Position the notification
    self:PositionNotification(notification, sender)
    
    -- Show the notification
    notification:Show()
    notification:SetAlpha(0)
    
    -- Fade in animation
    local fadeIn = notification:CreateAnimationGroup()
    local alpha = fadeIn:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.3)
    alpha:SetSmoothing("OUT")
    fadeIn:Play()
    
    -- Schedule auto-hide
    C_Timer.After(NOTIFICATION_DURATION, function()
        self:HideRecruitmentNotification(sender)
    end)
    
    self.Debug("DEBUG", "Showed recruitment notification from:", sender)
end

function SessionNotificationUI:CreateNotificationFrame(recruitmentData, sender)
    local frame = CreateFrame("Frame", "GrouperPlusNotification_" .. sender, UIParent, "BackdropTemplate")
    if not frame then
        return nil
    end
    
    -- Set up backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.3, 0.3, 1, 1)
    
    -- Set size and properties
    frame:SetSize(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    frame:SetMovable(false)
    
    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    title:SetText("GrouperPlus Session")
    title:SetTextColor(1, 1, 0)
    
    -- Sender text
    local senderText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    senderText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    senderText:SetText("From: " .. (sender or "Unknown"))
    senderText:SetTextColor(0.8, 0.8, 0.8)
    
    -- Description text
    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    description:SetPoint("TOPLEFT", senderText, "BOTTOMLEFT", 0, -4)
    description:SetText(recruitmentData.description or "Join organized groups!")
    description:SetTextColor(1, 1, 1)
    
    -- Join button
    local joinButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    joinButton:SetSize(60, 20)
    joinButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
    joinButton:SetText("Join")
    joinButton:SetScript("OnClick", function()
        self:OnJoinClicked(recruitmentData, sender)
    end)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        self:HideRecruitmentNotification(sender)
    end)
    
    -- Decline button
    local declineButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    declineButton:SetSize(60, 20)
    declineButton:SetPoint("RIGHT", joinButton, "LEFT", -5, 0)
    declineButton:SetText("Decline")
    declineButton:SetScript("OnClick", function()
        self:OnDeclineClicked(recruitmentData, sender)
    end)
    
    return frame
end

function SessionNotificationUI:PositionNotification(frame, sender)
    if not frame then
        return
    end
    
    -- Position notifications stacked vertically on the right side
    local notificationCount = 0
    for _ in pairs(activeNotifications) do
        notificationCount = notificationCount + 1
    end
    
    local xOffset = -20
    local yOffset = -100 - (notificationCount * (NOTIFICATION_HEIGHT + 10))
    
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOffset, yOffset)
end

function SessionNotificationUI:HideRecruitmentNotification(sender)
    local notification = activeNotifications[sender]
    if not notification or not notification.frame then
        return
    end
    
    local frame = notification.frame
    
    -- Fade out animation
    local fadeOut = frame:CreateAnimationGroup()
    local alpha = fadeOut:CreateAnimation("Alpha")
    alpha:SetFromAlpha(frame:GetAlpha())
    alpha:SetToAlpha(0)
    alpha:SetDuration(NOTIFICATION_FADE_TIME)
    alpha:SetSmoothing("IN")
    
    fadeOut:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetParent(nil)
        activeNotifications[sender] = nil
    end)
    
    fadeOut:Play()
    
    self.Debug("DEBUG", "Hiding recruitment notification from:", sender)
end

function SessionNotificationUI:OnJoinClicked(recruitmentData, sender)
    self.Debug("INFO", "User clicked join for session:", recruitmentData.sessionId, "from:", sender)
    
    -- Send join request
    if addon.SessionNotificationManager then
        local message = addon.MessageProtocol:CreateSessionJoinRequest(recruitmentData.sessionId)
        if message and addon.StateSync then
            addon.StateSync:SendMessage(message, "WHISPER", sender)
            self.Debug("DEBUG", "Sent join request to:", sender)
        end
    end
    
    -- Hide the notification
    self:HideRecruitmentNotification(sender)
    
    -- Show feedback to user
    local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
    if playerInfo then
        print("|cFF00FF00GrouperPlus:|r Join request sent to " .. sender)
    end
end

function SessionNotificationUI:OnDeclineClicked(recruitmentData, sender)
    self.Debug("INFO", "User declined session:", recruitmentData.sessionId, "from:", sender)
    
    -- Send decline response
    if addon.SessionNotificationManager then
        local message = addon.MessageProtocol:CreateSessionJoinResponse(recruitmentData.sessionId, false)
        if message and addon.StateSync then
            addon.StateSync:SendMessage(message, "WHISPER", sender)
            self.Debug("DEBUG", "Sent decline response to:", sender)
        end
    end
    
    -- Hide the notification
    self:HideRecruitmentNotification(sender)
end

function SessionNotificationUI:HideAllNotifications()
    for sender, _ in pairs(activeNotifications) do
        self:HideRecruitmentNotification(sender)
    end
    
    self.Debug("DEBUG", "Hidden all recruitment notifications")
end

function SessionNotificationUI:GetActiveNotificationCount()
    local count = 0
    for _ in pairs(activeNotifications) do
        count = count + 1
    end
    return count
end

function SessionNotificationUI:OnDisable()
    self.Debug("INFO", "Disabling SessionNotificationUI")
    
    self:HideAllNotifications()
    
    self.Debug("DEBUG", "SessionNotificationUI disabled successfully")
end

return SessionNotificationUI