local addonName, addon = ...

-- Member Row UI Module
-- Handles creation, display, and interaction of member rows in the guild member list

local MemberRowUI = {}
addon.MemberRowUI = MemberRowUI

-- Forward declarations for MainFrame dependencies
local ShowDragFrame, HideDragFrame, UpdateDragFramePosition, GetDraggedMember, SetDraggedMember

-- Initialize dependencies from MainFrame
function MemberRowUI:SetDependencies(deps)
    ShowDragFrame = deps.ShowDragFrame
    HideDragFrame = deps.HideDragFrame 
    UpdateDragFramePosition = deps.UpdateDragFramePosition
    GetDraggedMember = deps.GetDraggedMember
    SetDraggedMember = deps.SetDraggedMember
end

-- Create tooltip content for member row
local function CreateMemberTooltip(row)
    if not row.memberName then return end
    
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.memberName, 1, 1, 1)
    
    -- Add keystone information if available
    if addon.Keystone then
        local receivedKeystones = addon.Keystone:GetReceivedKeystones()
        local keystoneData = receivedKeystones[row.memberName]
        
        if keystoneData and keystoneData.mapID and keystoneData.level then
            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
            GameTooltip:AddLine("Keystone:", 0.8, 0.8, 0.8)
            local keystoneString = string.format("%s +%d", keystoneData.dungeonName or "Unknown Dungeon", keystoneData.level)
            GameTooltip:AddLine(keystoneString, 1, 0.8, 0)
        else
            -- Check if it's the current player (try both with and without realm)
            local playerName = UnitName("player")
            local playerFullName = UnitName("player") .. "-" .. GetRealmName()
            
            if row.memberName == playerName or row.memberName == playerFullName then
                local playerKeystoneInfo = addon.Keystone:GetKeystoneInfo()
                if playerKeystoneInfo.hasKeystone then
                    GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
                    GameTooltip:AddLine("Keystone:", 0.8, 0.8, 0.8)
                    local keystoneString = addon.Keystone:GetKeystoneString()
                    GameTooltip:AddLine(keystoneString, 1, 0.8, 0)
                end
            end
        end
    end
    
    GameTooltip:Show()
end

-- Set up drag and drop handlers for member row
local function SetupRowDragHandlers(row, index)
    addon.Debug("DEBUG", "MemberRowUI: Setting up drag handlers for row", index)
    
    row:SetScript("OnMouseDown", function(self, button)
        addon.Debug("DEBUG", "Row OnMouseDown:", button, "memberName:", self.memberName or "nil")
    end)
    
    row:SetScript("OnMouseUp", function(self, button)
        addon.Debug("DEBUG", "Row OnMouseUp:", button, "memberName:", self.memberName or "nil")
    end)
    
    row:SetScript("OnDragStart", function(self)
        addon.Debug("INFO", "Row OnDragStart triggered, memberName:", self.memberName or "nil")
        if self.memberName then
            addon.Debug("INFO", "Started dragging member:", self.memberName)
            
            -- Find the member info for class colors
            local memberInfo = addon.GuildMemberManager:FindMemberByName(self.memberName)
            if memberInfo then
                addon.Debug("DEBUG", "Found memberInfo for", self.memberName, "class:", memberInfo.class)
            end
            
            SetDraggedMember({
                name = self.memberName,
                sourceRow = self,
                memberInfo = memberInfo
            })
            addon.Debug("DEBUG", "draggedMember created:", self.memberName)
            
            addon.Debug("DEBUG", "About to call ShowDragFrame")
            ShowDragFrame(self.memberName, memberInfo)
            addon.Debug("DEBUG", "ShowDragFrame call completed")
            
            SetCursor("Interface\\Cursor\\Point")
            UpdateDragFramePosition()
            addon.Debug("DEBUG", "Drag started successfully, cursor and drag frame set")
        else
            addon.Debug("ERROR", "OnDragStart: memberName is nil!")
        end
    end)
    
    row:SetScript("OnDragStop", function(self)
        local draggedMember = GetDraggedMember()
        addon.Debug("DEBUG", "Row OnDragStop triggered")
        addon.Debug("DEBUG", "Stopped dragging member, draggedMember was:", draggedMember and draggedMember.name or "nil")
        HideDragFrame()
        -- Don't clear draggedMember here - let OnReceiveDrag handle it
        -- This allows OnReceiveDrag to still access the dragged member info
        C_Timer.After(0.1, function()
            local currentDraggedMember = GetDraggedMember()
            if currentDraggedMember then
                addon.Debug("DEBUG", "Drag timeout: clearing draggedMember after failed drop")
                SetDraggedMember(nil)
                ResetCursor()
                HideDragFrame()
            end
        end)
    end)
end

-- Create a member row UI element
function MemberRowUI:CreateMemberRow(parent, index)
    addon.Debug("DEBUG", "MemberRowUI: Creating member row", index)
    
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
    
    addon.Debug("DEBUG", "MemberRowUI: Created member row", index, "successfully")
    return row
end

-- Update member row with member data and styling
function MemberRowUI:UpdateMemberRow(row, member, index)
    addon.Debug("DEBUG", "MemberRowUI: Updating row", index, "with member", member.name)
    
    -- Always reposition and reset the row completely
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 5, -((index - 1) * 22) - 5)
    row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", -5, -((index - 1) * 22) - 5)
    
    -- Ensure row interaction is enabled
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    
    -- Set up class color
    local classColor = nil
    if member.class then
        classColor = RAID_CLASS_COLORS[member.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[member.class])
        addon.Debug("DEBUG", "MemberRowUI: Looking up class color for", member.name, "class token:", member.class, "localized:", member.classLocalized or "nil")
    else
        addon.Debug("WARN", "MemberRowUI: No class data for", member.name)
    end
    
    if classColor then
        row.text:SetTextColor(classColor.r, classColor.g, classColor.b)
        addon.Debug("INFO", "MemberRowUI: Applied class color for", member.name, "class:", member.class, "color:", string.format("%.2f,%.2f,%.2f", classColor.r, classColor.g, classColor.b))
    else
        row.text:SetTextColor(1, 1, 1)
        addon.Debug("WARN", "MemberRowUI: No class color found for", member.name, "class:", member.class or "nil", "- using white")
    end
    
    -- Force complete text element reset and proper setup
    row.text:Hide()       -- Hide first
    row.text:SetText("")  -- Clear text
    row.text:Show()       -- Show again
    row.text:SetText(member.name)  -- Set the text
    row.memberName = member.name
    addon.Debug("DEBUG", "MemberRowUI: Set memberName for row", index, "to:", member.name)
    
    -- Set role text
    if row.roleText then
        local roleDisplay, roleColor = addon:GetRoleDisplay(member.role)
        
        row.roleText:SetText(roleDisplay)
        row.roleText:SetTextColor(roleColor.r, roleColor.g, roleColor.b)
        addon.Debug("DEBUG", "MemberRowUI: Set role for", member.name, ":", roleDisplay)
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
            addon.Debug("DEBUG", "MemberRowUI: Set RaiderIO score for", member.name, ":", score)
        else
            row.scoreText:SetText("")
        end
    else
        row.scoreText:SetText("")
    end
    
    -- Show the row
    row:Show()
    addon.Debug("DEBUG", "MemberRowUI: Row", index, "updated and shown for member", member.name)
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
    addon.Debug("TRACE", "MemberRowUI: Row cleared")
end

-- Initialize or get rows array for a scroll child
function MemberRowUI:InitializeRows(scrollChild)
    if not scrollChild.rows then
        scrollChild.rows = {}
        addon.Debug("DEBUG", "MemberRowUI: Initialized rows array for scrollChild")
    end
    return scrollChild.rows
end