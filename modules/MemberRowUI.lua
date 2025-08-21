local addonName, addon = ...

-- Member Row UI Module
-- Handles creation, display, and interaction of member rows in the guild member list

local MemberRowUI = addon.ModuleBase:New("MemberUI")
addon.MemberRowUI = MemberRowUI

-- Forward declarations for MainFrame dependencies
local ShowDragFrame, HideDragFrame, UpdateDragFramePosition, GetDraggedMember, SetDraggedMember

function MemberRowUI:OnInitialize()
    -- Dependencies are injected individually by MainFrame
    ShowDragFrame = self:GetDependency("ShowDragFrame")
    HideDragFrame = self:GetDependency("HideDragFrame")
    UpdateDragFramePosition = self:GetDependency("UpdateDragFramePosition")
    GetDraggedMember = self:GetDependency("GetDraggedMember")
    SetDraggedMember = self:GetDependency("SetDraggedMember")
    
    if ShowDragFrame and HideDragFrame and UpdateDragFramePosition and GetDraggedMember and SetDraggedMember then
        self.Debug("DEBUG", "MemberRowUI dependencies initialized successfully")
    else
        self.Debug("WARN", "MemberRowUI: Some dependencies missing - MainFrame may not be fully loaded yet")
    end
end

-- Create tooltip content for member row
local function CreateMemberTooltip(row)
    if not row.memberName then return end
    
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.memberName, 1, 1, 1)
    
    -- Add keystone information if available
    if addon.Keystone then
        local playerName = UnitName("player")
        local playerFullName = UnitName("player") .. "-" .. GetRealmName()
        local isCurrentPlayer = (row.memberName == playerName or row.memberName == playerFullName)
        
        -- Always show the current player's keystone from their own data
        if isCurrentPlayer then
            local playerKeystoneInfo = addon.Keystone:GetKeystoneInfo()
            if playerKeystoneInfo.hasKeystone then
                GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
                GameTooltip:AddLine("Keystone:", 0.8, 0.8, 0.8)
                local keystoneString = addon.Keystone:GetKeystoneString()
                GameTooltip:AddLine(keystoneString, 1, 0.8, 0)
            end
        else
            -- For other players, check received keystone data
            local receivedKeystones = addon.Keystone:GetReceivedKeystones()
            local keystoneData = receivedKeystones[row.memberName]
            
            if keystoneData and keystoneData.mapID and keystoneData.level then
                GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
                GameTooltip:AddLine("Keystone:", 0.8, 0.8, 0.8)
                local keystoneString = string.format("%s +%d", keystoneData.dungeonName or "Unknown Dungeon", keystoneData.level)
                GameTooltip:AddLine(keystoneString, 1, 0.8, 0)
            end
        end
    end
    
    -- Add addon version information if available
    if addon.AddonComm then
        local connectedUsers = addon.AddonComm:GetConnectedUsers()
        local playerName = UnitName("player")
        local playerFullName = UnitName("player") .. "-" .. GetRealmName()
        local isCurrentPlayer = (row.memberName == playerName or row.memberName == playerFullName)
        
        if isCurrentPlayer then
            -- Show current player's addon version
            local currentVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
            GameTooltip:AddLine("GrouperPlus:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("v" .. currentVersion .. " (You)", 0.0, 1.0, 0.0) -- Green for current player
        else
            -- Check if this member has GrouperPlus installed
            local memberAddonInfo = connectedUsers[row.memberName]
            if memberAddonInfo then
                GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
                GameTooltip:AddLine("GrouperPlus:", 0.8, 0.8, 0.8)
                local versionColor = {1.0, 1.0, 0.0} -- Yellow for other users
                local timeSinceLastSeen = memberAddonInfo.lastSeen and (GetServerTime() - memberAddonInfo.lastSeen) or nil
                
                local statusText = "v" .. (memberAddonInfo.addonVersion or memberAddonInfo.version or "Unknown")
                if timeSinceLastSeen and timeSinceLastSeen < 60 then
                    statusText = statusText .. " (Online)"
                    versionColor = {0.0, 1.0, 0.0} -- Green for recently active
                elseif timeSinceLastSeen and timeSinceLastSeen < 300 then
                    statusText = statusText .. " (Recent)"
                end
                
                GameTooltip:AddLine(statusText, versionColor[1], versionColor[2], versionColor[3])
            end
        end
    end
    
    GameTooltip:Show()
end

-- Set up drag and drop handlers for member row
local function SetupRowDragHandlers(row, index)
    MemberRowUI.Debug("DEBUG", "MemberRowUI: Setting up drag handlers for row", index)
    
    row:SetScript("OnMouseDown", function(self, button)
        MemberRowUI.Debug("DEBUG", "Row OnMouseDown:", button, "memberName:", self.memberName or "nil")
    end)
    
    row:SetScript("OnMouseUp", function(self, button)
        MemberRowUI.Debug("DEBUG", "Row OnMouseUp:", button, "memberName:", self.memberName or "nil")
        
        -- Right-click for session whitelist management
        if button == "RightButton" and self.memberName and addon.SessionManager then
            local sessionInfo = addon.SessionManager:GetSessionInfo()
            if sessionInfo and sessionInfo.isOwner then
                local memberName = self.memberName
                local whitelist = addon.SessionManager:GetWhitelist()
                local isWhitelisted = whitelist[memberName] == true
                local isSessionOwner = (memberName == sessionInfo.owner)
                
                -- Create a simple tooltip-style menu instead of dropdown
                local menuFrame = CreateFrame("Frame", "GrouperPlusWhitelistTooltip", UIParent, "BackdropTemplate")
                menuFrame:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true,
                    tileSize = 16,
                    edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                menuFrame:SetBackdropColor(0, 0, 0, 0.8)
                menuFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                menuFrame:SetFrameStrata("TOOLTIP")
                menuFrame:SetSize(200, 60)
                
                -- Position near cursor
                local x, y = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()
                menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x/scale + 10, y/scale - 10)
                
                -- Add text
                local titleText = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                titleText:SetPoint("TOP", menuFrame, "TOP", 0, -8)
                titleText:SetText("Session Permissions: " .. memberName)
                titleText:SetTextColor(1, 1, 1)
                
                -- Add action button (but not for session owner)
                if not isSessionOwner then
                    local actionBtn = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
                    actionBtn:SetSize(160, 20)
                    actionBtn:SetPoint("TOP", titleText, "BOTTOM", 0, -8)
                    
                    if isWhitelisted then
                        actionBtn:SetText("Remove Edit Permission")
                        actionBtn:SetScript("OnClick", function()
                            addon.SessionManager:RemoveFromWhitelist(memberName)
                            addon:Print("Removed edit permission from " .. memberName)
                            menuFrame:Hide()
                        end)
                    else
                        actionBtn:SetText("Grant Edit Permission") 
                        actionBtn:SetScript("OnClick", function()
                            addon.SessionManager:AddToWhitelist(memberName)
                            addon:Print("Granted edit permission to " .. memberName)
                            menuFrame:Hide()
                        end)
                    end
                else
                    -- For session owner, show a note that they always have permissions
                    local noteText = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    noteText:SetPoint("TOP", titleText, "BOTTOM", 0, -8)
                    noteText:SetText("(Session Leader - Always has edit permissions)")
                    noteText:SetTextColor(0.8, 0.8, 0.8)
                end
                
                -- Auto-hide after 5 seconds or on any click outside
                menuFrame:SetScript("OnMouseDown", function() menuFrame:Hide() end)
                C_Timer.After(5, function() if menuFrame then menuFrame:Hide() end end)
                
                menuFrame:Show()
            end
        end
    end)
    
    row:SetScript("OnDragStart", function(self)
        MemberRowUI.Debug("INFO", "Row OnDragStart triggered, memberName:", self.memberName or "nil")
        if self.memberName then
            MemberRowUI.Debug("INFO", "Started dragging member:", self.memberName)
            
            -- Find the member info for class colors
            local memberInfo = addon.GuildMemberManager:FindMemberByName(self.memberName)
            if memberInfo then
                MemberRowUI.Debug("DEBUG", "Found memberInfo for", self.memberName, "class:", memberInfo.class)
            end
            
            SetDraggedMember({
                name = self.memberName,
                sourceRow = self,
                memberInfo = memberInfo
            })
            MemberRowUI.Debug("DEBUG", "draggedMember created:", self.memberName)
            
            MemberRowUI.Debug("DEBUG", "About to call ShowDragFrame")
            ShowDragFrame(self.memberName, memberInfo)
            MemberRowUI.Debug("DEBUG", "ShowDragFrame call completed")
            
            SetCursor("Interface\\Cursor\\Point")
            UpdateDragFramePosition()
            MemberRowUI.Debug("DEBUG", "Drag started successfully, cursor and drag frame set")
        else
            MemberRowUI.Debug("ERROR", "OnDragStart: memberName is nil!")
        end
    end)
    
    row:SetScript("OnDragStop", function(self)
        local draggedMember = GetDraggedMember()
        MemberRowUI.Debug("DEBUG", "Row OnDragStop triggered")
        MemberRowUI.Debug("DEBUG", "Stopped dragging member, draggedMember was:", draggedMember and draggedMember.name or "nil")
        HideDragFrame()
        -- Don't clear draggedMember here - let OnReceiveDrag handle it
        -- This allows OnReceiveDrag to still access the dragged member info
        C_Timer.After(0.1, function()
            local currentDraggedMember = GetDraggedMember()
            if currentDraggedMember then
                MemberRowUI.Debug("DEBUG", "Drag timeout: clearing draggedMember after failed drop")
                SetDraggedMember(nil)
                ResetCursor()
                HideDragFrame()
            end
        end)
    end)
end

-- Create a member row UI element
function MemberRowUI:CreateMemberRow(parent, index)
    self.Debug("DEBUG", "MemberRowUI: Creating member row", index)
    
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -((index - 1) * 22) - 5)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -((index - 1) * 22) - 5)
    
    -- Create role text (left side)
    row.roleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.roleText:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.roleText:SetJustifyH("LEFT")
    row.roleText:SetWidth(35)
    row.roleText:SetText("")
    
    -- Create member name text (after role)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", row.roleText, "RIGHT", 5, 0)
    row.text:SetJustifyH("LEFT")
    
    -- Create score text (right side)
    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.scoreText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.scoreText:SetJustifyH("RIGHT")
    row.scoreText:SetText("")
    
    -- Set up visual styling
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetAlpha(0.5)
    
    -- Enable mouse interaction and drag
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    
    -- Set up tooltip handlers
    row:SetScript("OnEnter", function(self)
        CreateMemberTooltip(self)
    end)
    
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Set up drag and drop handlers
    SetupRowDragHandlers(row, index)
    
    self.Debug("DEBUG", "MemberRowUI: Created member row", index, "successfully")
    return row
end

-- Update member row with member data and styling
function MemberRowUI:UpdateMemberRow(row, member, index)
    self.Debug("DEBUG", "MemberRowUI: Updating row", index, "with member", member.name)
    
    -- Always reposition and reset the row completely
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 5, -((index - 1) * 22) - 5)
    row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", -5, -((index - 1) * 22) - 5)
    
    -- Ensure row interaction respects session permissions
    local canEdit = true
    if addon.SessionManager then
        local sessionInfo = addon.SessionManager:GetSessionInfo()
        if sessionInfo then
            -- Only apply restrictions if we're actually in a session
            canEdit = addon.SessionManager:CanEdit()
        end
        -- If no session info, leave canEdit = true (allow free dragging)
    end
    
    row:EnableMouse(canEdit)
    if canEdit then
        row:RegisterForDrag("LeftButton")
    else
        row:RegisterForDrag()
    end
    
    self.Debug("TRACE", "MemberRowUI: Set drag permissions for", member.name, "canEdit:", canEdit)
    
    -- Set up class color
    local classColor = nil
    if member.class then
        classColor = RAID_CLASS_COLORS[member.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[member.class])
        self.Debug("DEBUG", "MemberRowUI: Looking up class color for", member.name, "class token:", member.class, "localized:", member.classLocalized or "nil")
    else
        self.Debug("WARN", "MemberRowUI: No class data for", member.name)
    end
    
    if classColor then
        row.text:SetTextColor(classColor.r, classColor.g, classColor.b)
        self.Debug("INFO", "MemberRowUI: Applied class color for", member.name, "class:", member.class, "color:", string.format("%.2f,%.2f,%.2f", classColor.r, classColor.g, classColor.b))
    else
        row.text:SetTextColor(1, 1, 1)
        self.Debug("WARN", "MemberRowUI: No class color found for", member.name, "class:", member.class or "nil", "- using white")
    end
    
    -- Force complete text element reset and proper setup
    row.text:Hide()       -- Hide first
    row.text:SetText("")  -- Clear text
    row.text:Show()       -- Show again
    
    -- Build display name with session permissions
    local displayName = member.name
    
    -- Add session permission indicators
    if addon.SessionManager and addon.SessionManager:IsInSession() then
        local sessionInfo = addon.SessionManager:GetSessionInfo()
        if sessionInfo then
            local fullName = member.name
            if not string.find(fullName, "-") then
                fullName = fullName .. "-" .. GetRealmName()
            end
            
            if sessionInfo.owner == fullName then
                -- Session owner gets a crown icon
                displayName = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:14:14|t " .. displayName
            else
                local whitelist = addon.SessionManager:GetWhitelist()
                if whitelist[fullName] then
                    -- Whitelisted players get an assist icon
                    displayName = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:14:14|t " .. displayName
                end
            end
        end
    end
    
    row.text:SetText(displayName)  -- Set the text with icons
    row.memberName = member.name
    self.Debug("DEBUG", "MemberRowUI: Set memberName for row", index, "to:", member.name)
    
    -- Set role text
    if row.roleText then
        local roleDisplay, roleColor = addon:GetRoleDisplay(member.role)
        
        row.roleText:SetText(roleDisplay)
        row.roleText:SetTextColor(roleColor.r, roleColor.g, roleColor.b)
        self.Debug("DEBUG", "MemberRowUI: Set role for", member.name, ":", roleDisplay)
    end
    
    -- Force text positioning and parent refresh
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.roleText, "RIGHT", 5, 0)
    row.text:SetParent(row)  -- Ensure proper parent relationship
    
    -- Set RaiderIO score if available
    if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
        local score = addon.RaiderIOIntegration:GetMythicPlusScore(member.name)
        if score and score > 0 then
            row.scoreText:SetText(tostring(score))
            self.Debug("DEBUG", "MemberRowUI: Set RaiderIO score for", member.name, ":", score)
        else
            row.scoreText:SetText("")
        end
    else
        row.scoreText:SetText("")
    end
    
    -- Show the row
    row:Show()
    self.Debug("DEBUG", "MemberRowUI: Row", index, "updated and shown for member", member.name)
end

-- Clear member row content
function MemberRowUI:ClearMemberRow(row)
    if not row then return end
    
    row:Hide()
    -- Clear the row content to prevent showing stale data
    row.text:SetText("")
    row.scoreText:SetText("")
    if row.roleText then
        row.roleText:SetText("")
    end
    row.memberName = nil
    self.Debug("TRACE", "MemberRowUI: Row cleared")
end

-- Initialize or get rows array for a scroll child
function MemberRowUI:InitializeRows(scrollChild)
    if not scrollChild.rows then
        scrollChild.rows = {}
        self.Debug("DEBUG", "MemberRowUI: Initialized rows array for scrollChild")
    end
    return scrollChild.rows
end