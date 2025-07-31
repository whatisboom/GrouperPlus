local addonName, addon = ...

local AceDB = LibStub("AceDB-3.0")

local mainFrame = nil
local memberList = {}
local scrollFrame = nil
local scrollChild = nil
local MAX_LEVEL = GetMaxPlayerLevel()

local function UpdateGuildMemberList()
    addon.Debug("DEBUG", "UpdateGuildMemberList: Starting guild roster update")
    
    table.wipe(memberList)
    
    if not IsInGuild() then
        addon.Debug("WARN", "UpdateGuildMemberList: Player is not in a guild")
        return memberList
    end
    
    local numMembers = GetNumGuildMembers()
    addon.Debug("DEBUG", "UpdateGuildMemberList: Found", numMembers, "guild members")
    
    for i = 1, numMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(i)
        if online and level == MAX_LEVEL then
            table.insert(memberList, {
                name = name,
                class = classFileName or class,
                classLocalized = class,
                level = level
            })
            addon.Debug("TRACE", "UpdateGuildMemberList: Added member", name, "level", level, "class:", classFileName or class, "localized:", class)
        end
    end
    
    addon.Debug("INFO", "UpdateGuildMemberList: Found", #memberList, "online max level members")
    
    return memberList
end

local function CreateMemberRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -((index - 1) * 22) - 5)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -((index - 1) * 22) - 5)
    
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.text:SetJustifyH("LEFT")
    
    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.scoreText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.scoreText:SetJustifyH("RIGHT")
    row.scoreText:SetText("")
    
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetAlpha(0.5)
    
    return row
end

local function UpdateMemberDisplay()
    addon.Debug("DEBUG", "UpdateMemberDisplay: Updating member display")
    
    if not scrollChild then
        addon.Debug("WARN", "UpdateMemberDisplay: scrollChild not initialized")
        return
    end
    
    for i = 1, scrollChild:GetNumChildren() do
        local child = select(i, scrollChild:GetChildren())
        child:Hide()
    end
    
    local members = UpdateGuildMemberList()
    
    for i, member in ipairs(members) do
        local row = scrollChild.rows and scrollChild.rows[i]
        if not row then
            row = CreateMemberRow(scrollChild, i)
            if not scrollChild.rows then
                scrollChild.rows = {}
            end
            scrollChild.rows[i] = row
        end
        
        local classColor = nil
        if member.class then
            classColor = RAID_CLASS_COLORS[member.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[member.class])
            addon.Debug("DEBUG", "UpdateMemberDisplay: Looking up class color for", member.name, "class token:", member.class, "localized:", member.classLocalized or "nil")
        else
            addon.Debug("WARN", "UpdateMemberDisplay: No class data for", member.name)
        end
        
        if classColor then
            row.text:SetTextColor(classColor.r, classColor.g, classColor.b)
            addon.Debug("INFO", "UpdateMemberDisplay: Applied class color for", member.name, "class:", member.class, "color:", string.format("%.2f,%.2f,%.2f", classColor.r, classColor.g, classColor.b))
        else
            row.text:SetTextColor(1, 1, 1)
            addon.Debug("WARN", "UpdateMemberDisplay: No class color found for", member.name, "class:", member.class or "nil", "- using white")
        end
        row.text:SetText(member.name)
        
        if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
            local formattedScore = addon.RaiderIOIntegration:GetFormattedScoreWithFallback(member.name)
            row.scoreText:SetText(formattedScore or "0")
            addon.Debug("DEBUG", "UpdateMemberDisplay: Set RaiderIO score for", member.name, ":", formattedScore or "0")
        else
            row.scoreText:SetText("")
            addon.Debug("TRACE", "UpdateMemberDisplay: RaiderIO integration not available")
        end
        
        row:Show()
    end
    
    scrollChild:SetHeight(math.max(#members * 22 + 10, scrollFrame:GetHeight()))
    
    addon.Debug("DEBUG", "UpdateMemberDisplay: Display updated with", #members, "members")
end

local function CreateMainFrame()
    addon.Debug("INFO", "CreateMainFrame: Creating main frame")
    
    if mainFrame then
        addon.Debug("WARN", "CreateMainFrame: Main frame already exists")
        return mainFrame
    end
    
    mainFrame = CreateFrame("Frame", "GrouperPlusMainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(1050, 600)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.8)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetResizable(true)
    mainFrame:EnableKeyboard(true)
    mainFrame:SetPropagateKeyboardInput(false)
    
    local titleBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -12, -12)
    titleBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    title:SetText("GrouperPlus - Guild Members")
    
    local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        addon.Debug("INFO", "CreateMainFrame: Close button clicked")
        mainFrame:Hide()
    end)
    
    local resizeHandle = CreateFrame("Button", nil, mainFrame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -5, 5)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:EnableMouse(true)
    resizeHandle:RegisterForDrag("LeftButton")
    resizeHandle:SetScript("OnDragStart", function()
        addon.Debug("DEBUG", "CreateMainFrame: Started resizing")
        mainFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        local width, height = mainFrame:GetSize()
        addon.Debug("INFO", "CreateMainFrame: Stopped resizing - new size:", width, "x", height)
        
        if addon.db and addon.db.profile then
            if not addon.db.profile.mainFrame then
                addon.db.profile.mainFrame = {}
            end
            addon.db.profile.mainFrame.width = width
            addon.db.profile.mainFrame.height = height
            addon.Debug("DEBUG", "CreateMainFrame: Saved size to database")
        end
    end)
    
    local leftPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 12, 12)
    leftPanel:SetWidth(320)
    leftPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    
    local memberHeader = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    memberHeader:SetPoint("TOP", leftPanel, "TOP", 0, -10)
    memberHeader:SetText("Online Members (Lvl " .. MAX_LEVEL .. ")")
    
    local columnHeader = CreateFrame("Frame", nil, leftPanel)
    columnHeader:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -30)
    columnHeader:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -30, -30)
    columnHeader:SetHeight(15)
    
    local nameHeader = columnHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("LEFT", columnHeader, "LEFT", 5, 0)
    nameHeader:SetText("Name")
    nameHeader:SetTextColor(0.8, 0.8, 0.8)
    
    local scoreHeader = columnHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scoreHeader:SetPoint("RIGHT", columnHeader, "RIGHT", -5, 0)
    scoreHeader:SetText("M+ Score")
    scoreHeader:SetTextColor(0.8, 0.8, 0.8)
    
    scrollFrame = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -30, 8)
    
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    mainFrame:SetScript("OnDragStart", function(self)
        addon.Debug("DEBUG", "CreateMainFrame: Started dragging")
        self:StartMoving()
    end)
    
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        addon.Debug("INFO", "CreateMainFrame: Stopped dragging at", point, relativePoint, x, y)
        
        if addon.db and addon.db.profile then
            if not addon.db.profile.mainFrame then
                addon.db.profile.mainFrame = {}
            end
            addon.db.profile.mainFrame.point = point
            addon.db.profile.mainFrame.relativePoint = relativePoint
            addon.db.profile.mainFrame.x = x
            addon.db.profile.mainFrame.y = y
            addon.Debug("DEBUG", "CreateMainFrame: Saved position to database")
        end
    end)
    
    if addon.db and addon.db.profile and addon.db.profile.mainFrame then
        local saved = addon.db.profile.mainFrame
        if saved.width and saved.height then
            mainFrame:SetSize(saved.width, saved.height)
            addon.Debug("DEBUG", "CreateMainFrame: Restored saved size", saved.width, "x", saved.height)
        end
        if saved.point then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
            addon.Debug("DEBUG", "CreateMainFrame: Restored saved position", saved.point, saved.x, saved.y)
        end
    end
    
    mainFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    mainFrame:SetScript("OnEvent", function(self, event)
        if event == "GUILD_ROSTER_UPDATE" then
            addon.Debug("DEBUG", "CreateMainFrame: GUILD_ROSTER_UPDATE event received")
            UpdateMemberDisplay()
        end
    end)
    
    mainFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            addon.Debug("INFO", "CreateMainFrame: Escape key pressed, hiding main frame")
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    
    mainFrame:SetScript("OnShow", function()
        addon.Debug("INFO", "CreateMainFrame: Main frame shown")
        C_GuildInfo.GuildRoster()
        UpdateMemberDisplay()
    end)
    
    addon.Debug("INFO", "CreateMainFrame: Main frame created successfully")
    addon.Debug("DEBUG", "CreateMainFrame: Frame size:", mainFrame:GetWidth(), "x", mainFrame:GetHeight())
    addon.Debug("DEBUG", "CreateMainFrame: Frame visibility:", mainFrame:IsVisible(), "shown:", mainFrame:IsShown())
    return mainFrame
end

function addon:ShowMainFrame()
    addon.Debug("INFO", "ShowMainFrame: Called")
    if not mainFrame then
        addon.Debug("DEBUG", "ShowMainFrame: Creating new main frame")
        mainFrame = CreateMainFrame()
    else
        addon.Debug("DEBUG", "ShowMainFrame: Using existing main frame")
    end
    
    if mainFrame then
        addon.Debug("DEBUG", "ShowMainFrame: Calling Show() on main frame")
        mainFrame:Show()
        addon.Debug("DEBUG", "ShowMainFrame: Frame visibility after Show():", mainFrame:IsVisible(), "shown:", mainFrame:IsShown())
        C_GuildInfo.GuildRoster()
    else
        addon.Debug("ERROR", "ShowMainFrame: mainFrame is nil after creation attempt")
    end
end

function addon:HideMainFrame()
    addon.Debug("INFO", "HideMainFrame: Called")
    if mainFrame then
        mainFrame:Hide()
    end
end

function addon:ToggleMainFrame()
    addon.Debug("INFO", "ToggleMainFrame: Called")
    if not mainFrame then
        addon.Debug("DEBUG", "ToggleMainFrame: No existing frame, showing new frame")
        self:ShowMainFrame()
        return
    end
    
    addon.Debug("DEBUG", "ToggleMainFrame: Frame exists, current state - IsShown:", mainFrame:IsShown())
    if mainFrame:IsShown() then
        self:HideMainFrame()
    else
        self:ShowMainFrame()
    end
end