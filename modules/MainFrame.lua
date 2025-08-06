local addonName, addon = ...

local AceDB = LibStub("AceDB-3.0")

local mainFrame = nil
local memberList = {}
local scrollFrame = nil
local scrollChild = nil
local loadingMessage = nil
local groupsContainer = nil
local dynamicGroups = {}
local draggedMember = nil
local dragFrame = nil
local membersInGroups = {} -- Track which members are assigned to groups
local MAX_LEVEL = GetMaxPlayerLevel()
local MAX_GROUP_SIZE = 5

-- Forward declarations for drag frame functions
local CreateDragFrame, ShowDragFrame, HideDragFrame, UpdateDragFramePosition
local AddMemberToGroup, RemoveMemberFromGroup, RemoveMemberFromPlayerList, AddMemberBackToPlayerList
local CreateNewGroup, EnsureEmptyGroupExists, CalculateGroupLayout, RepositionAllGroups, GetMemberBackgroundColor
local ReorganizeGroupByRole, CheckRoleLimits

local function UpdateGuildMemberList()
    addon.Debug("DEBUG", "UpdateGuildMemberList: Starting guild roster update")
    addon.Debug("DEBUG", "UpdateGuildMemberList: Current membersInGroups count:", next(membersInGroups) and "has members" or "empty")
    
    
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
            -- Only add if not already in a group
            if not membersInGroups[name] then
                local memberData = {
                    name = name,
                    class = classFileName or class,
                    classLocalized = class,
                    level = level
                }
                
                -- Add role information for all members, especially the player
                if addon.AutoFormation and addon.AutoFormation.GetPlayerRole then
                    memberData.role = addon.AutoFormation:GetPlayerRole(name)
                    addon.Debug("TRACE", "UpdateGuildMemberList: Determined role for", name, ":", memberData.role)
                end
                
                -- For the player, ensure we get the most current role
                local playerName = UnitName("player")
                local playerFullName = UnitName("player") .. "-" .. GetRealmName()
                addon.Debug("DEBUG", "UpdateGuildMemberList: Checking if", name, "equals player", playerName, "or", playerFullName)
                if name == playerName or name == playerFullName then
                    memberData.role = addon.Utilities:GetPlayerRole("player")
                    addon.Debug("INFO", "UpdateGuildMemberList: Updated player's own role to:", memberData.role)
                else
                    addon.Debug("TRACE", "UpdateGuildMemberList: Member", name, "is not the player")
                end
                
                table.insert(memberList, memberData)
                addon.Debug("TRACE", "UpdateGuildMemberList: Added member", name, "level", level, "class:", classFileName or class, "role:", memberData.role or "unknown")
            else
                addon.Debug("INFO", "UpdateGuildMemberList: Skipped member", name, "- already in group")
            end
        else
            if not online then
                addon.Debug("TRACE", "UpdateGuildMemberList: Skipped member", name, "- offline")
            elseif level ~= MAX_LEVEL then
                addon.Debug("TRACE", "UpdateGuildMemberList: Skipped member", name, "- level", level, "(not max level", MAX_LEVEL, ")")
            end
        end
    end
    
    addon.Debug("INFO", "UpdateGuildMemberList: Found", #memberList, "online max level members (after filtering out grouped members)")
    
    return memberList
end


local function CreateMemberRow(parent, index)
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
    
    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.scoreText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.scoreText:SetJustifyH("RIGHT")
    row.scoreText:SetText("")
    
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetAlpha(0.5)
    
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    
    -- Add tooltip functionality
    row:SetScript("OnEnter", function(self)
        if not self.memberName then return end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.memberName, 1, 1, 1)
        
        -- Add keystone information if available
        if addon.Keystone then
            local receivedKeystones = addon.Keystone:GetReceivedKeystones()
            local keystoneData = receivedKeystones[self.memberName]
            
            if keystoneData and keystoneData.mapID and keystoneData.level then
                GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
                GameTooltip:AddLine("Keystone:", 0.8, 0.8, 0.8)
                local keystoneString = string.format("%s +%d", keystoneData.dungeonName or "Unknown Dungeon", keystoneData.level)
                GameTooltip:AddLine(keystoneString, 1, 0.8, 0)
            else
                -- Check if it's the current player (try both with and without realm)
                local playerName = UnitName("player")
                local playerFullName = UnitName("player") .. "-" .. GetRealmName()
                
                if self.memberName == playerName or self.memberName == playerFullName then
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
    end)
    
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    addon.Debug("DEBUG", "CreateMemberRow: Setting up drag handlers for row", index)
    
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
            local memberInfo = nil
            for _, member in ipairs(memberList) do
                if member.name == self.memberName then
                    memberInfo = member
                    addon.Debug("DEBUG", "Found memberInfo for", self.memberName, "class:", member.class)
                    break
                end
            end
            
            draggedMember = {
                name = self.memberName,
                sourceRow = self,
                memberInfo = memberInfo
            }
            addon.Debug("DEBUG", "draggedMember created:", draggedMember.name)
            
            addon.Debug("DEBUG", "About to call ShowDragFrame")
            ShowDragFrame(self.memberName, memberInfo)
            addon.Debug("DEBUG", "ShowDragFrame call completed")
            
            SetCursor("Interface\\Cursor\\Point")
            UpdateDragFramePosition()
            addon.Debug("DEBUG", "Drag started successfully, cursor and drag frame set")
            addon.Debug("DEBUG", "Drag frame visible:", dragFrame and dragFrame:IsShown() or "dragFrame is nil")
        else
            addon.Debug("ERROR", "OnDragStart: memberName is nil!")
        end
    end)
    
    row:SetScript("OnDragStop", function(self)
        addon.Debug("DEBUG", "Row OnDragStop triggered")
        addon.Debug("DEBUG", "Stopped dragging member, draggedMember was:", draggedMember and draggedMember.name or "nil")
        HideDragFrame()
        -- Don't clear draggedMember here - let OnReceiveDrag handle it
        -- This allows OnReceiveDrag to still access the dragged member info
        C_Timer.After(0.1, function()
            if draggedMember then
                addon.Debug("DEBUG", "Drag timeout: clearing draggedMember after failed drop")
                draggedMember = nil
                ResetCursor()
                HideDragFrame()
                HideDragFrame()
            end
        end)
    end)
    
    return row
end

local function UpdateMemberDisplay()
    addon.Debug("DEBUG", "UpdateMemberDisplay: Updating member display - ENTRY")
    
    if not scrollChild then
        addon.Debug("WARN", "UpdateMemberDisplay: scrollChild not initialized")
        return
    end
    
    local members = UpdateGuildMemberList()
    addon.Debug("DEBUG", "UpdateMemberDisplay: Retrieved", #members, "available members from guild list")
    
    -- Show/hide loading message based on member availability
    -- Only show loading message if we're in a guild but have no guild roster data at all
    local totalGuildMembers = GetNumGuildMembers()
    local shouldShowLoading = #members == 0 and IsInGuild() and totalGuildMembers == 0
    
    if shouldShowLoading then
        addon.Debug("INFO", "UpdateMemberDisplay: No guild roster data loaded - showing loading message")
        if loadingMessage then
            loadingMessage:Show()
            loadingMessage:SetText("Loading guild members...")
        end
        -- Hide all existing rows since we're showing loading message
        if scrollChild and scrollChild.rows then
            for i = 1, #scrollChild.rows do
                if scrollChild.rows[i] then
                    scrollChild.rows[i]:Hide()
                end
            end
        end
        return
    else
        -- Hide loading message when we have guild data (even if all members are assigned to groups)
        if loadingMessage then
            loadingMessage:Hide()
        end
        if #members == 0 and totalGuildMembers > 0 then
            addon.Debug("DEBUG", "UpdateMemberDisplay: All eligible members are assigned to groups")
        else
            addon.Debug("DEBUG", "UpdateMemberDisplay: Have member data or not in guild - proceeding with display")
        end
    end
    
    
    
    -- Initialize scrollChild.rows if it doesn't exist
    if not scrollChild.rows then
        scrollChild.rows = {}
    end
    
    -- Hide all existing rows first and clear their content
    addon.Debug("DEBUG", "UpdateMemberDisplay: Hiding", #scrollChild.rows, "existing rows")
    for i = 1, #scrollChild.rows do
        if scrollChild.rows[i] then
            scrollChild.rows[i]:Hide()
            -- Clear the row content to prevent showing stale data
            scrollChild.rows[i].text:SetText("")
            scrollChild.rows[i].scoreText:SetText("")
            if scrollChild.rows[i].roleText then
                scrollChild.rows[i].roleText:SetText("")
            end
            scrollChild.rows[i].memberName = nil
            addon.Debug("TRACE", "UpdateMemberDisplay: Hid and cleared row", i)
        end
    end
    
    -- Now process each member and assign to rows
    for i, member in ipairs(members) do
        addon.Debug("DEBUG", "UpdateMemberDisplay: Processing member", i, ":", member.name)
        
        -- Get or create row for this position
        local row = scrollChild.rows[i]
        if not row then
            addon.Debug("DEBUG", "UpdateMemberDisplay: Creating new row at position", i, "for member:", member.name)
            row = CreateMemberRow(scrollChild, i)
            scrollChild.rows[i] = row
        else
            addon.Debug("DEBUG", "UpdateMemberDisplay: Reusing existing row at position", i, "for member:", member.name)
        end
        
        -- Always reposition and reset the row completely
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 5, -((i - 1) * 22) - 5)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -5, -((i - 1) * 22) - 5)
        
        -- Ensure row interaction is enabled
        row:EnableMouse(true)
        row:RegisterForDrag("LeftButton")
        
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
        -- Force complete text element reset and proper setup
        row.text:Hide()       -- Hide first
        row.text:SetText("")  -- Clear text
        row.text:Show()       -- Show again
        row.text:SetText(member.name)  -- Set the text
        row.memberName = member.name
        addon.Debug("DEBUG", "UpdateMemberDisplay: Set memberName for row", i, "to:", member.name)
        
        -- Set role text
        if row.roleText then
            local roleDisplay, roleColor = addon:GetRoleDisplay(member.role)
            
            row.roleText:SetText(roleDisplay)
            row.roleText:SetTextColor(roleColor.r, roleColor.g, roleColor.b)
            addon.Debug("DEBUG", "UpdateMemberDisplay: Set role for", member.name, ":", roleDisplay)
        end
        
        -- Force text positioning and parent refresh
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row.roleText, "RIGHT", 5, 0)
        row.text:SetParent(row)  -- Ensure proper parent relationship
        
        -- Verify the text was actually set and force row recreation if needed
        local actualText = row.text:GetText()
        if actualText ~= member.name then
            addon.Debug("ERROR", "Row", i, "text verification failed for", member.name, "- recreating row")
            -- Destroy the problematic row and create a new one
            row:Hide()
            row:SetParent(nil)
            row = CreateMemberRow(scrollChild, i)
            scrollChild.rows[i] = row
            
            -- Set up the new row completely
            local classColor = nil
            if member.class then
                classColor = RAID_CLASS_COLORS[member.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[member.class])
            end
            if classColor then
                row.text:SetTextColor(classColor.r, classColor.g, classColor.b)
            else
                row.text:SetTextColor(1, 1, 1)
            end
            row.text:SetText(member.name)
            row.memberName = member.name
            
            -- Set role text for recreated row
            if row.roleText then
                local roleDisplay, roleColor = addon:GetRoleDisplay(member.role)
                
                row.roleText:SetText(roleDisplay)
                row.roleText:SetTextColor(roleColor.r, roleColor.g, roleColor.b)
            end
            
            addon.Debug("INFO", "Recreated row", i, "for", member.name, "with role:", member.role or "unknown")
        end
        
        if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
            local formattedScore = addon.RaiderIOIntegration:GetFormattedScoreWithFallback(member.name)
            row.scoreText:SetText(formattedScore or "0")
            addon.Debug("DEBUG", "UpdateMemberDisplay: Set RaiderIO score for", member.name, ":", formattedScore or "0")
        else
            row.scoreText:SetText("")
            addon.Debug("TRACE", "UpdateMemberDisplay: RaiderIO integration not available")
        end
        
        row:Show()
        addon.Debug("TRACE", "UpdateMemberDisplay: Showed row", i, "for", member.name, "at position", string.format("y=%.0f", -((i - 1) * 22) - 5))
        
        
    end
    
    scrollChild:SetHeight(math.max(#members * 22 + 10, scrollFrame:GetHeight()))
    
    -- Force a complete UI refresh to ensure all text elements render correctly
    C_Timer.After(0.01, function()
        if scrollChild and scrollChild.rows then
            for i = 1, #members do
                local row = scrollChild.rows[i]
                if row and row.text then
                    row.text:SetText(row.text:GetText())  -- Force text refresh
                end
            end
        end
    end)
    
    local totalRows = scrollChild.rows and #scrollChild.rows or 0
    addon.Debug("DEBUG", "UpdateMemberDisplay: Display updated with", #members, "members, total rows created:", totalRows)
    
    
end

CreateDragFrame = function()
    if dragFrame then
        return dragFrame
    end
    
    dragFrame = CreateFrame("Frame", nil, UIParent)
    dragFrame:SetSize(200, 20)
    dragFrame:SetFrameStrata("TOOLTIP")
    dragFrame:Hide()
    
    dragFrame.bg = dragFrame:CreateTexture(nil, "BACKGROUND")
    dragFrame.bg:SetAllPoints()
    dragFrame.bg:SetColorTexture(0.1, 0.1, 0.2, 0.9)
    
    dragFrame.border = dragFrame:CreateTexture(nil, "BORDER")
    dragFrame.border:SetAllPoints()
    dragFrame.border:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    dragFrame.border:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    dragFrame.text = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragFrame.text:SetPoint("CENTER")
    dragFrame.text:SetJustifyH("CENTER")
    dragFrame.text:SetTextColor(1, 1, 1)
    
    addon.Debug("DEBUG", "CreateDragFrame: Drag frame created")
    return dragFrame
end

ShowDragFrame = function(memberName, memberInfo)
    addon.Debug("DEBUG", "ShowDragFrame: Called for", memberName)
    if not dragFrame then
        addon.Debug("DEBUG", "ShowDragFrame: Creating drag frame")
        CreateDragFrame()
    else
        addon.Debug("DEBUG", "ShowDragFrame: Using existing drag frame")
    end
    
    addon.Debug("DEBUG", "ShowDragFrame: Setting text to", memberName)
    dragFrame.text:SetText(memberName)
    
    if memberInfo and memberInfo.class then
        local classColor = RAID_CLASS_COLORS[memberInfo.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[memberInfo.class])
        if classColor then
            dragFrame.text:SetTextColor(classColor.r, classColor.g, classColor.b)
            addon.Debug("DEBUG", "ShowDragFrame: Set class color for", memberInfo.class)
        else
            dragFrame.text:SetTextColor(1, 1, 1)
            addon.Debug("DEBUG", "ShowDragFrame: No class color found, using white")
        end
    else
        dragFrame.text:SetTextColor(1, 1, 1)
        addon.Debug("DEBUG", "ShowDragFrame: No class info, using white")
    end
    
    addon.Debug("DEBUG", "ShowDragFrame: Calling dragFrame:Show()")
    dragFrame:Show()
    addon.Debug("DEBUG", "ShowDragFrame: dragFrame:IsShown():", dragFrame:IsShown())
    addon.Debug("DEBUG", "ShowDragFrame: dragFrame strata:", dragFrame:GetFrameStrata())
    addon.Debug("DEBUG", "ShowDragFrame: Showing drag frame for", memberName, "- complete")
end

HideDragFrame = function()
    if dragFrame then
        dragFrame:Hide()
        addon.Debug("DEBUG", "HideDragFrame: Hiding drag frame")
    end
end

UpdateDragFramePosition = function()
    if not dragFrame or not dragFrame:IsShown() then
        return
    end
    
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    dragFrame:ClearAllPoints()
    dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale + 10)
    -- addon.Debug("TRACE", "UpdateDragFramePosition: Updated position to", x / scale + 10, y / scale + 10)
end

-- Helper function to get the proper background color for a member based on RaiderIO score
GetMemberBackgroundColor = function(memberName)
    local defaultColor = {r = 0.2, g = 0.2, b = 0.3} -- Default background color
    
    if not memberName or not addon.RaiderIOIntegration or not addon.RaiderIOIntegration:IsAvailable() or not addon.Utils then
        return defaultColor
    end
    
    local score = addon.RaiderIOIntegration:GetMythicPlusScore(memberName)
    if score and score > 0 then
        return addon.Utils.GetScoreColor(score, 0, 3000)
    end
    
    return defaultColor
end

local function CheckGroupUtilities(groupFrame)
    return addon.Utilities:CheckGroupUtilities(groupFrame.members)
end

local function UpdateGroupTitle(groupFrame)
    if not groupFrame.header then return end
    
    local utilities = CheckGroupUtilities(groupFrame)
    
    -- Priority 1 buffs (red when missing)
    local brezText = utilities.COMBAT_REZ and "|cFF00FF00brez|r" or "|cFFFF0000brez|r"
    local lustText = utilities.BLOODLUST and "|cFF00FF00lust|r" or "|cFFFF0000lust|r"
    
    -- Priority 2 buffs (yellow when missing)
    local intText = utilities.INTELLECT and "|cFF00FF00int|r" or "|cFFFFFF00int|r"
    local stamText = utilities.STAMINA and "|cFF00FF00stam|r" or "|cFFFFFF00stam|r"
    local apText = utilities.ATTACK_POWER and "|cFF00FF00ap|r" or "|cFFFFFF00ap|r"
    local versText = utilities.VERSATILITY and "|cFF00FF00vers|r" or "|cFFFFFF00vers|r"
    local skyText = utilities.SKYFURY and "|cFF00FF00sky|r" or "|cFFFFFF00sky|r"
    
    -- Priority 3 buffs (gray when missing)
    local mtText = utilities.MYSTIC_TOUCH and "|cFF00FF00Mystic Touch|r" or "|cFFAAAAAAMystic Touch|r"
    local cbText = utilities.CHAOS_BRAND and "|cFF00FF00Chaos Brand|r" or "|cFFAAAAAAChaos Brand|r"
    
    groupFrame.header:SetText(brezText .. " " .. lustText .. "\n" .. intText .. " " .. stamText .. " " .. apText .. " " .. versText .. " " .. skyText .. "\n" .. mtText .. " " .. cbText)
    addon.Debug("DEBUG", "UpdateGroupTitle: Updated group", groupFrame.groupIndex, "title with all utilities")
end

local function CreateGroupFrame(parent, groupIndex, groupWidth)
    addon.Debug("DEBUG", "CreateGroupFrame: Creating group frame", groupIndex, "with width", groupWidth)
    
    local groupFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    groupFrame:SetSize(groupWidth, 180)
    groupFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    groupFrame:SetBackdropColor(0.1, 0.1, 0.2, 0.8)
    groupFrame:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    
    local header = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOP", groupFrame, "TOP", 0, -8)
    header:SetText("Group " .. groupIndex)
    header:SetTextColor(0.8, 0.8, 1)
    
    groupFrame.header = header
    groupFrame.members = {}
    groupFrame.memberFrames = {}
    groupFrame.groupIndex = groupIndex
    
    local memberWidth = groupWidth - 20
    
    for i = 1, MAX_GROUP_SIZE do
        local memberFrame = CreateFrame("Button", nil, groupFrame)
        memberFrame:SetSize(memberWidth, 20)
        memberFrame:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", 10, -60 - ((i-1) * 22))
        
        memberFrame.bg = memberFrame:CreateTexture(nil, "BACKGROUND")
        memberFrame.bg:SetAllPoints()
        memberFrame.bg:SetColorTexture(0.2, 0.2, 0.3, 0.3)
        memberFrame.bg:Hide()
        
        memberFrame.roleText = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        memberFrame.roleText:SetPoint("LEFT", memberFrame, "LEFT", 5, 0)
        memberFrame.roleText:SetJustifyH("LEFT")
        memberFrame.roleText:SetText("")
        memberFrame.roleText:SetWidth(35)
        
        memberFrame.text = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        memberFrame.text:SetPoint("LEFT", memberFrame.roleText, "RIGHT", 5, 0)
        memberFrame.text:SetJustifyH("LEFT")
        memberFrame.text:SetText("Empty")
        memberFrame.text:SetTextColor(0.5, 0.5, 0.5)
        
        memberFrame.removeBtn = CreateFrame("Button", nil, memberFrame)
        memberFrame.removeBtn:SetSize(16, 16)
        memberFrame.removeBtn:SetPoint("RIGHT", memberFrame, "RIGHT", -5, 0)
        memberFrame.removeBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        memberFrame.removeBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
        memberFrame.removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        memberFrame.removeBtn:Hide()
        
        memberFrame.removeBtn:SetScript("OnClick", function()
            addon.Debug("INFO", "Group member remove button clicked for slot", i, "in group", groupIndex)
            RemoveMemberFromGroup(groupIndex, i)
        end)
        
        memberFrame:EnableMouse(true)
        memberFrame:RegisterForDrag("LeftButton")
        
        addon.Debug("DEBUG", "CreateGroupFrame: Setting up drag and drop handlers for group", groupIndex, "slot", i)
        
        memberFrame:SetScript("OnEnter", function(self)
            addon.Debug("DEBUG", "Group slot OnEnter: group", groupIndex, "slot", i, "draggedMember:", draggedMember and draggedMember.name or "nil")
            if draggedMember then
                addon.Debug("DEBUG", "Group slot highlighting for potential drop")
                self.bg:SetColorTexture(0.3, 0.5, 0.3, 0.7)
                self.bg:Show()
            else
                -- Show tooltip if member exists in this slot
                if groupFrame.members[i] then
                    local memberInfo = groupFrame.members[i]
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(memberInfo.name, 1, 1, 1)
                    
                    -- Add keystone information if available
                    if addon.Keystone then
                        local receivedKeystones = addon.Keystone:GetReceivedKeystones()
                        local keystoneData = receivedKeystones[memberInfo.name]
                        
                        if keystoneData and keystoneData.mapID and keystoneData.level then
                            GameTooltip:AddLine(" ", 1, 1, 1) -- Spacer
                            GameTooltip:AddLine("Keystone:", 0.8, 0.8, 0.8)
                            local keystoneString = string.format("%s +%d", keystoneData.dungeonName or "Unknown Dungeon", keystoneData.level)
                            GameTooltip:AddLine(keystoneString, 1, 0.8, 0)
                        else
                            -- Check if it's the current player (try both with and without realm)
                            local playerName = UnitName("player")
                            local playerFullName = UnitName("player") .. "-" .. GetRealmName()
                            
                            if memberInfo.name == playerName or memberInfo.name == playerFullName then
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
            end
        end)
        
        memberFrame:SetScript("OnLeave", function(self)
            addon.Debug("DEBUG", "Group slot OnLeave: group", groupIndex, "slot", i)
            
            -- Always hide tooltip when leaving
            GameTooltip:Hide()
            
            if draggedMember and not groupFrame.members[i] then
                self.bg:Hide()
            elseif not draggedMember and not groupFrame.members[i] then
                self.bg:Hide()
            elseif groupFrame.members[i] then
                -- Restore the proper background color based on RaiderIO score
                local memberName = groupFrame.members[i].name
                local bgColor = GetMemberBackgroundColor(memberName)
                self.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.4)
                self.bg:Show()
            end
        end)
        
        memberFrame:SetScript("OnMouseDown", function(self, button)
            addon.Debug("DEBUG", "Group slot OnMouseDown: group", groupIndex, "slot", i, "button:", button)
        end)
        
        memberFrame:SetScript("OnDragStart", function(self)
            local slotIndex = i
            addon.Debug("INFO", "Group member OnDragStart: group", groupIndex, "slot", slotIndex)
            
            if groupFrame.members[slotIndex] then
                local memberInfo = groupFrame.members[slotIndex]
                addon.Debug("INFO", "Started dragging group member:", memberInfo.name, "from group", groupIndex, "slot", slotIndex)
                
                draggedMember = {
                    name = memberInfo.name,
                    sourceGroup = groupIndex,
                    sourceSlot = slotIndex,
                    memberInfo = memberInfo,
                    fromGroup = true
                }
                addon.Debug("DEBUG", "draggedMember created from group:", draggedMember.name)
                
                ShowDragFrame(memberInfo.name, memberInfo)
                SetCursor("Interface\\Cursor\\Point")
                UpdateDragFramePosition()
                addon.Debug("DEBUG", "Group member drag started successfully")
            else
                addon.Debug("DEBUG", "OnDragStart: No member in slot", slotIndex, "of group", groupIndex)
            end
        end)
        
        memberFrame:SetScript("OnDragStop", function(self)
            addon.Debug("DEBUG", "Group member OnDragStop triggered")
            if draggedMember and draggedMember.fromGroup then
                addon.Debug("DEBUG", "Stopped dragging group member:", draggedMember.name)
                HideDragFrame()
                C_Timer.After(0.1, function()
                    if draggedMember then
                        addon.Debug("DEBUG", "Group drag timeout: clearing draggedMember after failed drop")
                        draggedMember = nil
                        ResetCursor()
                        HideDragFrame()
                    end
                end)
            end
        end)
        
        memberFrame:SetScript("OnMouseUp", function(self, button)
            local slotIndex = i  -- Capture the slot index in local scope
            addon.Debug("DEBUG", "Group slot OnMouseUp: group", groupIndex, "slot", slotIndex, "button:", button, "draggedMember:", draggedMember and draggedMember.name or "nil")
            if draggedMember and not groupFrame.members[slotIndex] and button == "LeftButton" then
                addon.Debug("INFO", "Manual drop detected on group", groupIndex, "slot", slotIndex)
                
                local memberName = draggedMember.name
                local sourceRow = draggedMember.sourceRow
                local fromGroup = draggedMember.fromGroup
                local sourceGroup = draggedMember.sourceGroup
                local sourceSlot = draggedMember.sourceSlot
                
                addon.Debug("DEBUG", "About to call AddMemberToGroup (manual) with:", memberName, groupIndex, slotIndex, "fromGroup:", fromGroup)
                
                local success = false
                local errorMsg = nil
                local status, result = pcall(AddMemberToGroup, memberName, groupIndex, slotIndex)
                if status then
                    success = result
                    addon.Debug("DEBUG", "AddMemberToGroup (manual) returned:", success)
                else
                    errorMsg = result
                    addon.Debug("ERROR", "AddMemberToGroup (manual) failed with error:", errorMsg)
                end
                
                if success then
                    if fromGroup and sourceGroup and sourceSlot then
                        addon.Debug("INFO", "Removing member from source group", sourceGroup, "slot", sourceSlot)
                        RemoveMemberFromGroup(sourceGroup, sourceSlot, true) -- Skip player list update when moving between groups
                    else
                        RemoveMemberFromPlayerList(memberName)
                        if sourceRow then
                            sourceRow:Hide()
                        end
                    end
                    addon.Debug("INFO", "Successfully dropped (OnMouseUp)", memberName, "on group", groupIndex, "slot", slotIndex)
                else
                    addon.Debug("ERROR", "Failed to manually add member", memberName, "to group", groupIndex, "slot", slotIndex)
                end
                
                draggedMember = nil
                ResetCursor()
                HideDragFrame()
            end
        end)
        
        memberFrame:SetScript("OnReceiveDrag", function(self)
            addon.Debug("INFO", "=== OnReceiveDrag ENTRY ===")
            local slotIndex = i  -- Capture the slot index in local scope
            addon.Debug("INFO", "Group slot OnReceiveDrag: group", groupIndex, "slot", slotIndex, "draggedMember:", draggedMember and draggedMember.name or "nil")
            
            if not draggedMember then
                addon.Debug("WARN", "OnReceiveDrag: No draggedMember")
                return
            end
            
            local targetMember = groupFrame.members[slotIndex]
            addon.Debug("DEBUG", "OnReceiveDrag: Target slot has member:", targetMember and targetMember.name or "empty")
            
            -- Case 1: Dropping on empty slot (existing behavior)
            if not targetMember then
                addon.Debug("INFO", "Case 1: Dropping", draggedMember.name, "on empty slot", slotIndex, "in group", groupIndex)
                
                local memberName = draggedMember.name
                local sourceRow = draggedMember.sourceRow
                local fromGroup = draggedMember.fromGroup
                local sourceGroup = draggedMember.sourceGroup
                local sourceSlot = draggedMember.sourceSlot
                
                local success = false
                local status, result = pcall(AddMemberToGroup, memberName, groupIndex, slotIndex)
                if status then
                    success = result
                else
                    addon.Debug("ERROR", "AddMemberToGroup failed with error:", result)
                end
                
                if success then
                    if fromGroup and sourceGroup and sourceSlot then
                        addon.Debug("INFO", "Removing member from source group", sourceGroup, "slot", sourceSlot)
                        RemoveMemberFromGroup(sourceGroup, sourceSlot, true)
                    else
                        RemoveMemberFromPlayerList(memberName)
                        if sourceRow then
                            sourceRow:Hide()
                        end
                    end
                    addon.Debug("INFO", "Successfully dropped", memberName, "on empty slot")
                end
                
                draggedMember = nil
                ResetCursor()
                HideDragFrame()
                return
            end
            
            -- Case 2: Dropping on occupied slot - check for available slots in the group first
            local emptySlotIndex = nil
            for slot = 1, MAX_GROUP_SIZE do
                if not groupFrame.members[slot] then
                    emptySlotIndex = slot
                    break
                end
            end
            
            if emptySlotIndex then
                addon.Debug("INFO", "Case 2: Group has empty slot", emptySlotIndex, "- adding", draggedMember.name, "there instead")
                
                local memberName = draggedMember.name
                local sourceRow = draggedMember.sourceRow
                local fromGroup = draggedMember.fromGroup
                local sourceGroup = draggedMember.sourceGroup
                local sourceSlot = draggedMember.sourceSlot
                
                local success = false
                local status, result = pcall(AddMemberToGroup, memberName, groupIndex, emptySlotIndex)
                if status then
                    success = result
                else
                    addon.Debug("ERROR", "AddMemberToGroup failed with error:", result)
                end
                
                if success then
                    if fromGroup and sourceGroup and sourceSlot then
                        RemoveMemberFromGroup(sourceGroup, sourceSlot, true)
                    else
                        RemoveMemberFromPlayerList(memberName)
                        if sourceRow then
                            sourceRow:Hide()
                        end
                    end
                    addon.Debug("INFO", "Successfully added", memberName, "to available slot", emptySlotIndex)
                end
                
                draggedMember = nil
                ResetCursor()
                HideDragFrame()
                return
            end
            
            -- Case 3: Group is full - replace/swap logic
            addon.Debug("INFO", "Case 3: Group is full - handling replacement/swap")
            
            local draggedMemberName = draggedMember.name
            local draggedFromGroup = draggedMember.fromGroup
            local draggedSourceGroup = draggedMember.sourceGroup
            local draggedSourceSlot = draggedMember.sourceSlot
            local draggedSourceRow = draggedMember.sourceRow
            
            if draggedFromGroup and draggedSourceGroup and draggedSourceSlot then
                -- Case 3a: Both members are from groups - swap them
                addon.Debug("INFO", "Case 3a: Swapping", draggedMemberName, "from group", draggedSourceGroup, "with", targetMember.name, "from group", groupIndex)
                
                -- Store both member info before removal
                local targetMemberInfo = {
                    name = targetMember.name,
                    class = targetMember.class,
                    role = targetMember.role,
                    score = targetMember.score
                }
                
                local draggedMemberInfo = {
                    name = draggedMemberName,
                    class = draggedMember.class,
                    role = draggedMember.role,
                    score = draggedMember.score
                }
                
                -- Remove both members from their current positions (this will reorganize both groups)
                RemoveMemberFromGroup(groupIndex, slotIndex, true)
                RemoveMemberFromGroup(draggedSourceGroup, draggedSourceSlot, true)
                
                -- Temporarily clear members from tracking to allow re-adding to different groups
                membersInGroups[targetMemberInfo.name] = nil
                membersInGroups[draggedMemberName] = nil
                addon.Debug("DEBUG", "Temporarily cleared both members from membersInGroups tracking for swap")
                
                -- Find available slots in both groups after reorganization
                local targetGroupSlot = nil
                local sourceGroupSlot = nil
                
                for slot = 1, MAX_GROUP_SIZE do
                    if not groupFrame.members[slot] then
                        targetGroupSlot = slot
                        break
                    end
                end
                
                for slot = 1, MAX_GROUP_SIZE do
                    if not dynamicGroups[draggedSourceGroup].members[slot] then
                        sourceGroupSlot = slot
                        break
                    end
                end
                
                -- Add them to their new positions
                local success1 = false
                local success2 = false
                
                if targetGroupSlot then
                    success1 = AddMemberToGroup(draggedMemberName, groupIndex, targetGroupSlot)
                end
                
                if sourceGroupSlot then
                    -- Temporarily update draggedMember.memberInfo for the second AddMemberToGroup call
                    local originalMemberInfo = draggedMember.memberInfo
                    draggedMember.memberInfo = targetMemberInfo
                    success2 = AddMemberToGroup(targetMemberInfo.name, draggedSourceGroup, sourceGroupSlot)
                    -- Restore original memberInfo (though draggedMember will be cleared after this anyway)
                    draggedMember.memberInfo = originalMemberInfo
                end
                
                if success1 and success2 then
                    addon.Debug("INFO", "Successfully swapped", draggedMemberName, "and", targetMemberInfo.name)
                else
                    addon.Debug("ERROR", "Swap failed - success1:", success1, "success2:", success2)
                    -- Rollback: try to put members back in available slots
                    if not success1 and targetGroupSlot then
                        AddMemberToGroup(targetMemberInfo.name, groupIndex, targetGroupSlot)
                    end
                    if not success2 and sourceGroupSlot then
                        AddMemberToGroup(draggedMemberName, draggedSourceGroup, sourceGroupSlot)
                    end
                end
                
            else
                -- Case 3b: Dragged member is from player list - replace target member
                addon.Debug("INFO", "Case 3b: Replacing", targetMember.name, "in group", groupIndex, "with", draggedMemberName, "from player list")
                
                -- Store target member info before removal
                local targetMemberInfo = {
                    name = targetMember.name,
                    class = targetMember.class,
                    role = targetMember.role,
                    score = targetMember.score
                }
                
                -- Remove target member from group (this will reorganize the group)
                RemoveMemberFromGroup(groupIndex, slotIndex, true)
                
                -- Temporarily clear target member from tracking to allow replacement
                membersInGroups[targetMemberInfo.name] = nil
                addon.Debug("DEBUG", "Temporarily cleared", targetMemberInfo.name, "from membersInGroups tracking for replacement")
                
                -- Find the first available slot in the group after reorganization
                local availableSlot = nil
                for slot = 1, MAX_GROUP_SIZE do
                    if not groupFrame.members[slot] then
                        availableSlot = slot
                        break
                    end
                end
                
                if availableSlot then
                    -- Add dragged member to available slot
                    local success = AddMemberToGroup(draggedMemberName, groupIndex, availableSlot)
                    
                    if success then
                        -- Remove dragged member from player list and add target member back
                        RemoveMemberFromPlayerList(draggedMemberName)
                        if draggedSourceRow then
                            draggedSourceRow:Hide()
                        end
                        AddMemberBackToPlayerList(targetMemberInfo)
                        addon.Debug("INFO", "Successfully replaced", targetMemberInfo.name, "with", draggedMemberName, "in slot", availableSlot)
                    else
                        addon.Debug("ERROR", "Failed to add replacement member")
                        -- Rollback: add target member back to group
                        AddMemberToGroup(targetMemberInfo.name, groupIndex, availableSlot)
                    end
                else
                    addon.Debug("ERROR", "No available slot found after member removal")
                    -- Rollback: add target member back - find any available slot
                    for slot = 1, MAX_GROUP_SIZE do
                        if not groupFrame.members[slot] then
                            AddMemberToGroup(targetMemberInfo.name, groupIndex, slot)
                            break
                        end
                    end
                end
            end
            
            draggedMember = nil
            ResetCursor()
            HideDragFrame()
        end)
        
        memberFrame.slotIndex = i
        groupFrame.memberFrames[i] = memberFrame
    end
    
    -- Add group-level drag and drop handling to allow dropping anywhere in the group
    groupFrame:EnableMouse(true)
    groupFrame:RegisterForDrag("LeftButton")
    
    groupFrame:SetScript("OnReceiveDrag", function(self)
        addon.Debug("INFO", "=== Group-level OnReceiveDrag ENTRY ===")
        addon.Debug("INFO", "Group OnReceiveDrag: group", groupIndex, "draggedMember:", draggedMember and draggedMember.name or "nil")
        
        if not draggedMember then
            addon.Debug("WARN", "Group OnReceiveDrag: No draggedMember")
            return
        end
        
        -- Find the first available slot in the group
        local availableSlot = nil
        for slot = 1, MAX_GROUP_SIZE do
            if not groupFrame.members[slot] then
                availableSlot = slot
                addon.Debug("DEBUG", "Group OnReceiveDrag: Found available slot", slot, "in group", groupIndex)
                break
            end
        end
        
        if availableSlot then
            -- Case 1: Group has available slots - add member there
            addon.Debug("INFO", "Group drop case 1: Adding", draggedMember.name, "to available slot", availableSlot, "in group", groupIndex)
            
            local memberName = draggedMember.name
            local sourceRow = draggedMember.sourceRow
            local fromGroup = draggedMember.fromGroup
            local sourceGroup = draggedMember.sourceGroup
            local sourceSlot = draggedMember.sourceSlot
            
            local success = false
            local status, result = pcall(AddMemberToGroup, memberName, groupIndex, availableSlot)
            if status then
                success = result
            else
                addon.Debug("ERROR", "Group drop: AddMemberToGroup failed with error:", result)
            end
            
            if success then
                if fromGroup and sourceGroup and sourceSlot then
                    addon.Debug("INFO", "Group drop: Removing member from source group", sourceGroup, "slot", sourceSlot)
                    RemoveMemberFromGroup(sourceGroup, sourceSlot, true)
                else
                    RemoveMemberFromPlayerList(memberName)
                    if sourceRow then
                        sourceRow:Hide()
                    end
                end
                addon.Debug("INFO", "Group drop: Successfully added", memberName, "to available slot", availableSlot)
            else
                addon.Debug("ERROR", "Group drop: Failed to add member", memberName, "to group", groupIndex)
            end
            
        else
            -- Case 2: Group is full - replace the last member (or could implement different logic)
            addon.Debug("INFO", "Group drop case 2: Group", groupIndex, "is full - replacing last member")
            
            -- Find the last occupied slot
            local lastSlot = nil
            for slot = MAX_GROUP_SIZE, 1, -1 do
                if groupFrame.members[slot] then
                    lastSlot = slot
                    break
                end
            end
            
            if lastSlot then
                local targetMember = groupFrame.members[lastSlot]
                local draggedMemberName = draggedMember.name
                local draggedFromGroup = draggedMember.fromGroup
                local draggedSourceGroup = draggedMember.sourceGroup
                local draggedSourceSlot = draggedMember.sourceSlot
                local draggedSourceRow = draggedMember.sourceRow
                
                if draggedFromGroup and draggedSourceGroup and draggedSourceSlot then
                    -- Swap with last member
                    addon.Debug("INFO", "Group drop: Swapping", draggedMemberName, "with last member", targetMember.name)
                    
                    local targetMemberInfo = {
                        name = targetMember.name,
                        class = targetMember.class,
                        role = targetMember.role,
                        score = targetMember.score
                    }
                    
                    -- Remove both members and clear tracking
                    RemoveMemberFromGroup(groupIndex, lastSlot, true)
                    RemoveMemberFromGroup(draggedSourceGroup, draggedSourceSlot, true)
                    membersInGroups[targetMember.name] = nil
                    membersInGroups[draggedMemberName] = nil
                    
                    -- Find available slots after reorganization
                    local targetGroupSlot = nil
                    local sourceGroupSlot = nil
                    
                    for slot = 1, MAX_GROUP_SIZE do
                        if not groupFrame.members[slot] then
                            targetGroupSlot = slot
                            break
                        end
                    end
                    
                    for slot = 1, MAX_GROUP_SIZE do
                        if not dynamicGroups[draggedSourceGroup].members[slot] then
                            sourceGroupSlot = slot
                            break
                        end
                    end
                    
                    -- Perform the swap
                    local success1 = targetGroupSlot and AddMemberToGroup(draggedMemberName, groupIndex, targetGroupSlot)
                    local success2 = false
                    if sourceGroupSlot then
                        -- Temporarily update draggedMember.memberInfo for the second AddMemberToGroup call
                        local originalMemberInfo = draggedMember.memberInfo
                        draggedMember.memberInfo = targetMemberInfo
                        success2 = AddMemberToGroup(targetMemberInfo.name, draggedSourceGroup, sourceGroupSlot)
                        -- Restore original memberInfo
                        draggedMember.memberInfo = originalMemberInfo
                    end
                    
                    if success1 and success2 then
                        addon.Debug("INFO", "Group drop: Successfully swapped", draggedMemberName, "and", targetMemberInfo.name)
                    else
                        addon.Debug("ERROR", "Group drop: Swap failed - success1:", success1, "success2:", success2)
                    end
                    
                else
                    -- Replace last member with dragged member from player list
                    addon.Debug("INFO", "Group drop: Replacing last member", targetMember.name, "with", draggedMemberName)
                    
                    local targetMemberInfo = {
                        name = targetMember.name,
                        class = targetMember.class,
                        role = targetMember.role,
                        score = targetMember.score
                    }
                    
                    -- Remove target member and clear tracking
                    RemoveMemberFromGroup(groupIndex, lastSlot, true)
                    membersInGroups[targetMember.name] = nil
                    
                    -- Find available slot after reorganization
                    local availableSlotAfterRemoval = nil
                    for slot = 1, MAX_GROUP_SIZE do
                        if not groupFrame.members[slot] then
                            availableSlotAfterRemoval = slot
                            break
                        end
                    end
                    
                    if availableSlotAfterRemoval then
                        local success = AddMemberToGroup(draggedMemberName, groupIndex, availableSlotAfterRemoval)
                        if success then
                            RemoveMemberFromPlayerList(draggedMemberName)
                            if draggedSourceRow then
                                draggedSourceRow:Hide()
                            end
                            AddMemberBackToPlayerList(targetMemberInfo)
                            addon.Debug("INFO", "Group drop: Successfully replaced", targetMemberInfo.name, "with", draggedMemberName)
                        else
                            -- Rollback
                            AddMemberToGroup(targetMemberInfo.name, groupIndex, availableSlotAfterRemoval)
                            addon.Debug("ERROR", "Group drop: Failed to replace member")
                        end
                    end
                end
            end
        end
        
        draggedMember = nil
        ResetCursor()
        HideDragFrame()
    end)
    
    addon.Debug("DEBUG", "CreateGroupFrame: Group frame", groupIndex, "created successfully with width", groupWidth, "and group-level drag handling")
    
    -- Initialize with default title showing missing utilities
    UpdateGroupTitle(groupFrame)
    
    return groupFrame
end

EnsureEmptyGroupExists = function()
    addon.Debug("DEBUG", "EnsureEmptyGroupExists: Checking for empty group")
    
    local hasEmptyGroup = false
    for i, group in ipairs(dynamicGroups) do
        local memberCount = 0
        for j = 1, MAX_GROUP_SIZE do
            if group.members[j] then
                memberCount = memberCount + 1
            end
        end
        if memberCount == 0 then
            hasEmptyGroup = true
            addon.Debug("DEBUG", "EnsureEmptyGroupExists: Found empty group at index", i)
            break
        end
    end
    
    if not hasEmptyGroup then
        addon.Debug("INFO", "EnsureEmptyGroupExists: Creating new empty group")
        CreateNewGroup()
    end
end

RemoveExcessEmptyGroups = function()
    addon.Debug("DEBUG", "RemoveExcessEmptyGroups: Checking for excess empty groups")
    
    local emptyGroupIndices = {}
    
    -- Find all empty groups
    for i, group in ipairs(dynamicGroups) do
        local memberCount = 0
        for j = 1, MAX_GROUP_SIZE do
            if group.members[j] then
                memberCount = memberCount + 1
            end
        end
        if memberCount == 0 then
            table.insert(emptyGroupIndices, i)
            addon.Debug("DEBUG", "RemoveExcessEmptyGroups: Found empty group at index", i)
        end
    end
    
    -- Keep only one empty group, remove the rest
    if #emptyGroupIndices > 1 then
        addon.Debug("INFO", "RemoveExcessEmptyGroups: Found", #emptyGroupIndices, "empty groups, removing", #emptyGroupIndices - 1)
        
        -- Remove excess empty groups (keep the first one)
        for i = #emptyGroupIndices, 2, -1 do
            local groupIndex = emptyGroupIndices[i]
            local groupFrame = dynamicGroups[groupIndex]
            
            -- Hide and cleanup the group frame
            if groupFrame then
                groupFrame:Hide()
                groupFrame:SetParent(nil)
            end
            
            -- Remove from dynamicGroups array
            table.remove(dynamicGroups, groupIndex)
            addon.Debug("DEBUG", "RemoveExcessEmptyGroups: Removed empty group at index", groupIndex)
        end
        
        -- Reposition remaining groups
        RepositionAllGroups()
    end
end

CalculateGroupLayout = function()
    if not groupsContainer then
        return 0, 0, 0, 0
    end
    
    local containerWidth = groupsContainer:GetParent():GetWidth() - 46
    local numGroups = #dynamicGroups + 1
    local spacing = 10
    
    -- Limit to 2 groups per row, each taking 50% of container width
    local groupsPerRow = 2
    local numRows = math.ceil(numGroups / groupsPerRow)
    local groupWidth = math.floor((containerWidth - (spacing * 3)) / 2) -- 3 spacing: left, middle, right
    
    addon.Debug("DEBUG", "CalculateGroupLayout: containerWidth", containerWidth, "numGroups", numGroups, "groupWidth", groupWidth, "numRows", numRows)
    return containerWidth, numGroups, groupWidth, numRows
end

RepositionAllGroups = function()
    addon.Debug("DEBUG", "RepositionAllGroups: Repositioning all groups")
    
    if not groupsContainer or #dynamicGroups == 0 then
        return
    end
    
    local containerWidth, numGroups, groupWidth, numRows = CalculateGroupLayout()
    local spacing = 10
    local groupsPerRow = 2
    local rowHeight = 190 -- Group height (180) + spacing (10)
    
    for i, groupFrame in ipairs(dynamicGroups) do
        groupFrame:ClearAllPoints()
        groupFrame:SetSize(groupWidth, 180)
        
        -- Calculate row and column position
        local row = math.ceil(i / groupsPerRow) - 1  -- 0-based row index
        local col = ((i - 1) % groupsPerRow)         -- 0-based column index
        
        local xOffset = spacing + (col * (groupWidth + spacing))
        local yOffset = -10 - (row * rowHeight)
        
        groupFrame:SetPoint("TOPLEFT", groupsContainer, "TOPLEFT", xOffset, yOffset)
        
        local memberWidth = groupWidth - 20
        for j = 1, MAX_GROUP_SIZE do
            if groupFrame.memberFrames[j] then
                groupFrame.memberFrames[j]:SetSize(memberWidth, 20)
            end
        end
        
        addon.Debug("DEBUG", "RepositionAllGroups: Positioned group", i, "at row", row, "col", col, "xOffset", xOffset, "yOffset", yOffset, "width", groupWidth)
    end
    
    -- Set container size to accommodate all rows
    local totalHeight = math.max((numRows * rowHeight) + 20, 160)
    groupsContainer:SetWidth(containerWidth)
    groupsContainer:SetHeight(totalHeight)
end

CreateNewGroup = function()
    addon.Debug("DEBUG", "CreateNewGroup: Creating new group")
    
    if not groupsContainer then
        addon.Debug("ERROR", "CreateNewGroup: groupsContainer is nil")
        return
    end
    
    local groupIndex = #dynamicGroups + 1
    local containerWidth, numGroups, groupWidth, numRows = CalculateGroupLayout()
    
    local groupFrame = CreateGroupFrame(groupsContainer, groupIndex, groupWidth)
    groupFrame.members = {}
    table.insert(dynamicGroups, groupFrame)
    
    RepositionAllGroups()
    
    addon.Debug("INFO", "CreateNewGroup: Created group", groupIndex, "with horizontal layout")
end

AddMemberToGroup = function(memberName, groupIndex, slotIndex)
    addon.Debug("INFO", "AddMemberToGroup: ENTRY - Adding", memberName, "to group", groupIndex, "slot", slotIndex)
    addon.Debug("DEBUG", "AddMemberToGroup: dynamicGroups count:", #dynamicGroups)
    
    -- Check if member is already in a group (unless being moved between groups)
    if membersInGroups[memberName] and not (draggedMember and draggedMember.fromGroup) then
        addon.Debug("ERROR", "AddMemberToGroup: Member", memberName, "is already in a group - RETURNING FALSE")
        return false
    end
    
    if not dynamicGroups[groupIndex] then
        addon.Debug("ERROR", "AddMemberToGroup: Invalid group index", groupIndex, "- RETURNING FALSE")
        return false
    end
    addon.Debug("DEBUG", "AddMemberToGroup: Group index valid")
    
    local group = dynamicGroups[groupIndex]
    addon.Debug("DEBUG", "AddMemberToGroup: Group found, checking slot", slotIndex)
    if group.members[slotIndex] then
        addon.Debug("WARN", "AddMemberToGroup: Slot", slotIndex, "already occupied in group", groupIndex, "by:", group.members[slotIndex].name, "- RETURNING FALSE")
        return false
    end
    addon.Debug("DEBUG", "AddMemberToGroup: Slot is empty, proceeding")
    
    local memberInfo = nil
    addon.Debug("DEBUG", "AddMemberToGroup: Searching for member in memberList, count:", #memberList)
    for _, member in ipairs(memberList) do
        if member.name == memberName then
            memberInfo = member
            addon.Debug("DEBUG", "AddMemberToGroup: Found member in list:", member.name)
            break
        end
    end
    
    -- If not found in memberList, check if it's being moved from another group
    if not memberInfo and draggedMember and draggedMember.fromGroup and draggedMember.memberInfo then
        memberInfo = draggedMember.memberInfo
        addon.Debug("DEBUG", "AddMemberToGroup: Using member info from draggedMember (group-to-group move):", memberName)
    end
    
    if not memberInfo then
        addon.Debug("ERROR", "AddMemberToGroup: Member", memberName, "not found in member list or draggedMember - RETURNING FALSE")
        addon.Debug("DEBUG", "AddMemberToGroup: Available members:")
        for i, member in ipairs(memberList) do
            addon.Debug("DEBUG", "  ", i, ":", member.name)
        end
        return false
    end
    addon.Debug("DEBUG", "AddMemberToGroup: Member found, proceeding to validate")
    
    -- Ensure member has role information before validation
    if not memberInfo.role and addon.AutoFormation then
        memberInfo.role = addon.AutoFormation:GetPlayerRole(memberInfo)
        addon.Debug("DEBUG", "AddMemberToGroup: Detected role for", memberInfo.name, ":", memberInfo.role)
    end
    
    -- Check role limits BEFORE making any changes
    local canAdd, reason = CheckRoleLimits(groupIndex, memberInfo.role)
    if not canAdd then
        addon.Debug("ERROR", "AddMemberToGroup: Cannot add", memberInfo.name, "to group", groupIndex, "-", reason)
        addon.Debug(addon.LOG_LEVEL.ERROR, "Cannot add member:", reason)
        return false
    end
    
    -- Now it's safe to add the member
    addon.Debug("DEBUG", "AddMemberToGroup: Role limit check passed, adding member")
    addon.Debug("DEBUG", "AddMemberToGroup: Setting member info in group.members[", slotIndex, "]")
    group.members[slotIndex] = memberInfo
    
    -- Add to tracking list
    membersInGroups[memberName] = true
    addon.Debug("DEBUG", "AddMemberToGroup: Added", memberName, "to membersInGroups tracking")
    addon.Debug("DEBUG", "AddMemberToGroup: Current membersInGroups:")
    for name, _ in pairs(membersInGroups) do
        addon.Debug("DEBUG", "  - ", name)
    end
    addon.Debug("DEBUG", "AddMemberToGroup: Member info set successfully")
    
    local memberFrame = group.memberFrames[slotIndex]
    addon.Debug("DEBUG", "AddMemberToGroup: Got memberFrame:", memberFrame ~= nil)
    if memberFrame then
        addon.Debug("DEBUG", "AddMemberToGroup: Updating memberFrame display")
        
        -- Set background color based on RaiderIO score
        local bgColor = GetMemberBackgroundColor(memberInfo.name)
        memberFrame.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.4)
        addon.Debug("DEBUG", "AddMemberToGroup: Set background color for", memberInfo.name)
        memberFrame.bg:Show()
        
        -- Include RaiderIO score in display text
        local displayText = memberInfo.name
        if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
            local formattedScore = addon.RaiderIOIntegration:GetFormattedScoreWithFallback(memberInfo.name)
            if formattedScore and formattedScore ~= "0" then
                displayText = memberInfo.name .. " (" .. formattedScore .. ")"
            end
        end
        
        memberFrame.text:SetText(displayText)
        addon.Debug("DEBUG", "AddMemberToGroup: Set member text to:", displayText)
        
        local classColor = nil
        if memberInfo.class then
            classColor = RAID_CLASS_COLORS[memberInfo.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[memberInfo.class])
            addon.Debug("DEBUG", "AddMemberToGroup: Found class color for", memberInfo.class)
        end
        
        if classColor then
            memberFrame.text:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            memberFrame.text:SetTextColor(1, 1, 1)
        end
        
        memberFrame.removeBtn:Show()
        addon.Debug("DEBUG", "AddMemberToGroup: Member frame updated successfully")
    else
        addon.Debug("ERROR", "AddMemberToGroup: memberFrame is nil!")
    end
    
    -- Ensure member has score information
    if not memberInfo.score and addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
        local profile = addon.RaiderIOIntegration:GetProfile(memberInfo.name)
        if profile and profile.mythicKeystoneProfile then
            memberInfo.score = profile.mythicKeystoneProfile.currentScore or 0
            addon.Debug("DEBUG", "AddMemberToGroup: Found RaiderIO score for", memberInfo.name, ":", memberInfo.score)
        else
            memberInfo.score = 0
        end
    end
    
    addon.Debug("DEBUG", "AddMemberToGroup: Calling EnsureEmptyGroupExists")
    EnsureEmptyGroupExists()
    
    -- Apply role-based positioning after adding the member
    addon.Debug("DEBUG", "AddMemberToGroup: About to call ReorganizeGroupByRole for group", groupIndex)
    addon.Debug("DEBUG", "AddMemberToGroup: Member info before reorganize - name:", memberInfo and memberInfo.name or "nil", "role:", memberInfo and memberInfo.role or "nil", "score:", memberInfo and memberInfo.score or "nil")
    ReorganizeGroupByRole(groupIndex)
    
    -- Update group title to reflect utility availability
    UpdateGroupTitle(group)
    
    addon.Debug("INFO", "AddMemberToGroup: Successfully added", memberName, "to group", groupIndex, "with role-based positioning - RETURNING TRUE")
    return true
end

local function GetRolePriority(role)
    return addon.Utilities:GetRolePriority(role)
end

CheckRoleLimits = function(groupIndex, newMemberRole)
    -- Role limits removed - allow any composition
    if not dynamicGroups[groupIndex] then
        return false, "Invalid group"
    end
    
    addon.Debug("DEBUG", "CheckRoleLimits: Role limits disabled, allowing", newMemberRole, "in group", groupIndex)
    return true
end

ReorganizeGroupByRole = function(groupIndex)
    addon.Debug("INFO", "ReorganizeGroupByRole: Reorganizing group", groupIndex, "by role")
    
    if not dynamicGroups[groupIndex] then
        addon.Debug("ERROR", "ReorganizeGroupByRole: Invalid group index", groupIndex)
        return
    end
    
    local group = dynamicGroups[groupIndex]
    local members = {}
    
    -- Collect all current members
    for slotIndex = 1, MAX_GROUP_SIZE do
        if group.members[slotIndex] then
            local member = group.members[slotIndex]
            -- Ensure role is set
            if not member.role and addon.AutoFormation then
                member.role = addon.AutoFormation:GetPlayerRole(member)
                addon.Debug("DEBUG", "ReorganizeGroupByRole: Detected role for", member.name, ":", member.role)
            end
            addon.Debug("DEBUG", "ReorganizeGroupByRole: Member", member.name, "has role:", member.role or "NONE")
            table.insert(members, member)
        end
    end
    
    -- Sort members by role priority
    addon.Debug("DEBUG", "ReorganizeGroupByRole: Sorting", #members, "members by role")
    table.sort(members, function(a, b)
        local priorityA = GetRolePriority(a.role)
        local priorityB = GetRolePriority(b.role)
        addon.Debug("TRACE", "Comparing", a.name, "(", a.role, "priority:", priorityA, ") vs", b.name, "(", b.role, "priority:", priorityB, ")")
        if priorityA == priorityB then
            -- If same role, sort by score if available
            local scoreA = a.score or 0
            local scoreB = b.score or 0
            return scoreA > scoreB
        end
        return priorityA < priorityB
    end)
    addon.Debug("DEBUG", "ReorganizeGroupByRole: Sorting complete")
    
    -- Clear all slots
    for slotIndex = 1, MAX_GROUP_SIZE do
        group.members[slotIndex] = nil
        local memberFrame = group.memberFrames[slotIndex]
        if memberFrame then
            memberFrame.bg:Hide()
            memberFrame.text:SetText("Empty")
            memberFrame.text:SetTextColor(0.5, 0.5, 0.5)
            memberFrame.roleText:SetText("")
            memberFrame.removeBtn:Hide()
        end
    end
    
    -- Re-add members in sorted order
    for i, member in ipairs(members) do
        group.members[i] = member
        local memberFrame = group.memberFrames[i]
        if memberFrame then
            -- Set background color based on RaiderIO score
            local bgColor = GetMemberBackgroundColor(member.name)
            memberFrame.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.4)
            addon.Debug("DEBUG", "ReorganizeGroupByRole: Set background color for", member.name)
            memberFrame.bg:Show()
            
            -- Include RaiderIO score in display text
            local displayText = member.name
            if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
                local formattedScore = addon.RaiderIOIntegration:GetFormattedScoreWithFallback(member.name)
                if formattedScore and formattedScore ~= "0" then
                    displayText = member.name .. " (" .. formattedScore .. ")"
                end
            end
            
            memberFrame.text:SetText(displayText)
            
            -- Display role using centralized constants
            local roleDisplay, roleColor = addon:GetRoleDisplay(member.role)
            memberFrame.roleText:SetText(roleDisplay)
            memberFrame.roleText:SetTextColor(roleColor.r, roleColor.g, roleColor.b)
            
            local classColor = nil
            if member.class then
                classColor = RAID_CLASS_COLORS[member.class] or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[member.class])
            end
            
            if classColor then
                memberFrame.text:SetTextColor(classColor.r, classColor.g, classColor.b)
            else
                memberFrame.text:SetTextColor(1, 1, 1)
            end
            
            memberFrame.removeBtn:Show()
        end
    end
    
    addon.Debug("INFO", "ReorganizeGroupByRole: Reorganized group", groupIndex, "- new order:")
    for i, member in ipairs(members) do
        addon.Debug("DEBUG", "  Slot", i, ":", member.name, "role:", member.role or "unknown")
    end
end

RemoveMemberFromGroup = function(groupIndex, slotIndex, skipPlayerListUpdate)
    addon.Debug("INFO", "RemoveMemberFromGroup: Removing member from group", groupIndex, "slot", slotIndex, "skipPlayerListUpdate:", skipPlayerListUpdate)
    
    if not dynamicGroups[groupIndex] then
        addon.Debug("ERROR", "RemoveMemberFromGroup: Invalid group index", groupIndex)
        return false
    end
    
    local group = dynamicGroups[groupIndex]
    if not group.members[slotIndex] then
        addon.Debug("WARN", "RemoveMemberFromGroup: Slot", slotIndex, "already empty in group", groupIndex)
        return false
    end
    
    local memberInfo = group.members[slotIndex]
    local memberName = memberInfo.name
    group.members[slotIndex] = nil
    
    -- Only remove from tracking list if not moving to another group
    if not skipPlayerListUpdate then
        membersInGroups[memberName] = nil
        addon.Debug("DEBUG", "RemoveMemberFromGroup: Removed", memberName, "from membersInGroups tracking")
    else
        addon.Debug("DEBUG", "RemoveMemberFromGroup: Keeping", memberName, "in membersInGroups tracking (moving between groups)")
    end
    
    local memberFrame = group.memberFrames[slotIndex]
    if memberFrame then
        memberFrame.bg:Hide()
        memberFrame.text:SetText("Empty")
        memberFrame.text:SetTextColor(0.5, 0.5, 0.5)
        memberFrame.roleText:SetText("")
        memberFrame.removeBtn:Hide()
    end
    
    if not skipPlayerListUpdate then
        AddMemberBackToPlayerList(memberInfo)
    end
    
    -- Reorganize the group to maintain role-based positioning
    ReorganizeGroupByRole(groupIndex)
    
    -- Update group title to reflect utility availability
    UpdateGroupTitle(group)
    
    -- Check and remove excess empty groups (keep only one)
    RemoveExcessEmptyGroups()
    
    addon.Debug("INFO", "RemoveMemberFromGroup: Successfully removed", memberName, "from group", groupIndex, "and reorganized by role")
    return true
end

RemoveMemberFromPlayerList = function(memberName)
    addon.Debug("INFO", "RemoveMemberFromPlayerList: Member", memberName, "now tracked in groups - will be excluded from next UpdateMemberDisplay")
    
    addon.Debug("DEBUG", "RemoveMemberFromPlayerList: About to call UpdateMemberDisplay")
    -- Defer the display update to ensure drag operations are fully complete
    C_Timer.After(0.01, function()
        -- No need to manually remove from memberList since UpdateGuildMemberList will handle this
        UpdateMemberDisplay()
        addon.Debug("DEBUG", "RemoveMemberFromPlayerList: Deferred UpdateMemberDisplay call completed")
    end)
end

AddMemberBackToPlayerList = function(memberInfo)
    addon.Debug("INFO", "AddMemberBackToPlayerList: Member", memberInfo.name, "no longer tracked in groups - will appear in next UpdateMemberDisplay")
    -- No need to manually add to memberList since UpdateGuildMemberList will handle this
    UpdateMemberDisplay()
end

local function UpdateGroupsDisplay()
    addon.Debug("DEBUG", "UpdateGroupsDisplay: Updating groups display")
    
    if not groupsContainer then
        addon.Debug("WARN", "UpdateGroupsDisplay: groupsContainer not initialized")
        return
    end
    
    EnsureEmptyGroupExists()
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
        
        RepositionAllGroups()
    end)
    
    local leftPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    leftPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -5)
    leftPanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 12, 12)
    leftPanel:SetWidth(320)
    
    local memberHeader = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    memberHeader:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -10)
    memberHeader:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -30, -10)
    memberHeader:SetText("Online Members (Lvl " .. MAX_LEVEL .. ")")
    memberHeader:SetJustifyH("CENTER")
    
    -- Auto-formation buttons
    local autoFormButton = CreateFrame("Button", "GrouperPlusAutoFormButton", leftPanel, "UIPanelButtonTemplate")
    autoFormButton:SetSize(120, 22)
    autoFormButton:SetPoint("TOPLEFT", memberHeader, "BOTTOMLEFT", 0, -8)
    autoFormButton:SetText("Auto-Form")
    autoFormButton:EnableMouse(true)
    autoFormButton:SetFrameLevel(leftPanel:GetFrameLevel() + 10)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Auto-Form button created successfully!")
    addon.Debug("DEBUG", "Created Auto-Form button with name:", autoFormButton:GetName())
    autoFormButton:SetScript("OnClick", function()
        addon.Debug(addon.LOG_LEVEL.INFO, "Auto-Form button clicked!")
        addon:AutoFormGroups()
    end)
    addon.Debug("DEBUG", "Auto-Form button click handler set")
    
    local clearButton = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    clearButton:SetSize(120, 22)
    clearButton:SetPoint("TOPRIGHT", memberHeader, "BOTTOMRIGHT", 0, -8)
    clearButton:SetText("Clear Groups")
    clearButton:SetScript("OnClick", function()
        addon.Debug("INFO", "Clear groups button clicked")
        addon:ClearAllGroups()
    end)
    
    local columnHeader = CreateFrame("Frame", nil, leftPanel)
    columnHeader:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -60)
    columnHeader:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -30, -60)
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
    scrollFrame:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -30, 8)
    
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Create loading message
    loadingMessage = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loadingMessage:SetPoint("CENTER", scrollChild, "TOP", 0, -50)
    loadingMessage:SetText("Loading guild members...")
    loadingMessage:SetTextColor(0.8, 0.8, 0.8)
    loadingMessage:Hide() -- Initially hidden
    
    local rightPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 340, -5)
    rightPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -12, 12)
    
    local groupsHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    groupsHeader:SetPoint("TOP", rightPanel, "TOP", 0, -10)
    groupsHeader:SetText("Dynamic Groups")
    
    local groupsScrollFrame = CreateFrame("ScrollFrame", nil, rightPanel, "UIPanelScrollFrameTemplate")
    groupsScrollFrame:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 8, -35)
    groupsScrollFrame:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -30, 8)
    
    groupsContainer = CreateFrame("Frame", nil, groupsScrollFrame)
    groupsContainer:SetSize(groupsScrollFrame:GetWidth(), 1)
    groupsScrollFrame:SetScrollChild(groupsContainer)
    
    CreateNewGroup()
    
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
            local members = UpdateGuildMemberList()
            if #members > 0 then
                addon.Debug("INFO", "CreateMainFrame: GUILD_ROSTER_UPDATE found", #members, "members - updating display")
                UpdateMemberDisplay()
                UpdateGroupsDisplay()
            else
                addon.Debug("DEBUG", "CreateMainFrame: GUILD_ROSTER_UPDATE still shows 0 members")
            end
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
        addon.Debug("INFO", "CreateMainFrame: OnShow script triggered!")
        addon.Debug("DEBUG", "CreateMainFrame: Initializing drag and drop system")
        draggedMember = nil
        HideDragFrame()
        
        -- Request fresh roster data first
        C_GuildInfo.GuildRoster()
        
        -- Force immediate update (will show loading message if no data available)
        addon.Debug("DEBUG", "CreateMainFrame: Forcing immediate member list update from OnShow")
        UpdateMemberDisplay()
        UpdateGroupsDisplay()
        
        addon.Debug("DEBUG", "CreateMainFrame: OnShow complete, update performed (loading message shown if needed)")
    end)
    
    mainFrame:SetScript("OnUpdate", function(self, elapsed)
        if draggedMember and dragFrame and dragFrame:IsShown() then
            UpdateDragFramePosition()
        end
    end)
    
    -- Perform initial update to show loading message if needed
    addon.Debug("DEBUG", "CreateMainFrame: Performing initial member list update")
    C_GuildInfo.GuildRoster()
    UpdateMemberDisplay()
    UpdateGroupsDisplay()
    
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
        addon.Debug("DEBUG", "ShowMainFrame: Guild roster request will be handled by OnShow script")
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

function addon:AutoFormGroups()
    addon.Debug(addon.LOG_LEVEL.INFO, "AutoFormGroups function called")
    addon.Debug("INFO", "AutoFormGroups: Starting auto-formation process")
    
    if not self.AutoFormation then
        addon.Debug("ERROR", "AutoFormGroups: AutoFormation module not loaded")
        addon.Debug(addon.LOG_LEVEL.WARN, "Auto-formation module not available")
        return
    end
    
    -- Clear existing groups before auto-formation
    addon.Debug("DEBUG", "AutoFormGroups: Clearing existing groups")
    self:ClearAllGroups()
    
    -- Get available members from the member list
    if not memberList or #memberList == 0 then
        addon.Debug("WARN", "AutoFormGroups: No members available for auto-formation")
        addon.Debug(addon.LOG_LEVEL.WARN, "No guild members available. Please wait for the guild roster to load, then try again.")
        -- Try to refresh the guild roster
        C_GuildInfo.GuildRoster()
        return
    end
    
    addon.Debug("INFO", "AutoFormGroups: Found", #memberList, "available members")
    
    -- Create balanced groups using the auto-formation algorithm
    local groups = self.AutoFormation:CreateBalancedGroups(memberList, 5)
    
    if not groups or #groups == 0 then
        addon.Debug("WARN", "AutoFormGroups: No valid groups could be formed")
        addon.Debug(addon.LOG_LEVEL.WARN, "Unable to form balanced groups with current members")
        return
    end
    
    addon.Debug("INFO", "AutoFormGroups: Created", #groups, "balanced groups")
    
    -- Apply the groups to the UI
    for i, group in ipairs(groups) do
        addon.Debug("DEBUG", "AutoFormGroups: Processing group", i, "with", #group, "members")
        
        -- Ensure we have enough group frames
        while #dynamicGroups < i do
            CreateNewGroup()
            addon.Debug("DEBUG", "AutoFormGroups: Created new group frame, total groups:", #dynamicGroups)
        end
        
        -- Add members to the group  
        for j, member in ipairs(group) do
            addon.Debug("INFO", "AutoFormGroups: Adding member", j, ":", member.name, "to group", i, "slot", j)
            addon.Debug("DEBUG", "Member details - name:", member.name, "class:", member.class, "score:", member.score, "role:", member.role)
            
            local success = AddMemberToGroup(member.name, i, j)
            addon.Debug("DEBUG", "AddMemberToGroup result:", success)
            
            if not success then
                addon.Debug("ERROR", "Failed to add", member.name, "to group", i, "slot", j)
            end
        end
        
        addon.Debug("INFO", "AutoFormGroups: Completed group", i, "- members should now be visible")
    end
    
    -- Update the UI
    UpdateMemberDisplay()
    RepositionAllGroups()
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Auto-formed", #groups, "balanced groups")
    addon.Debug("INFO", "AutoFormGroups: Auto-formation completed successfully")
end

function addon:ClearAllGroups()
    addon.Debug("INFO", "ClearAllGroups: Clearing all group assignments")
    
    -- Move all members back to the available pool
    for memberName, _ in pairs(membersInGroups) do
        addon.Debug("DEBUG", "ClearAllGroups: Returning", memberName, "to available pool")
        membersInGroups[memberName] = nil
    end
    
    -- Clear all group member frames
    for _, groupFrame in ipairs(dynamicGroups) do
        if groupFrame.members then
            table.wipe(groupFrame.members)
        end
        -- Clear all member frame displays
        if groupFrame.memberFrames then
            for i = 1, MAX_GROUP_SIZE do
                local memberFrame = groupFrame.memberFrames[i]
                if memberFrame then
                    memberFrame.bg:Hide()
                    memberFrame.text:SetText("Empty")
                    memberFrame.text:SetTextColor(0.5, 0.5, 0.5)
                    memberFrame.roleText:SetText("")
                    memberFrame.removeBtn:Hide()
                end
            end
        end
        -- Update group title to show no buffs
        UpdateGroupTitle(groupFrame)
    end
    
    -- Reset group member counts
    for _, groupFrame in ipairs(dynamicGroups) do
        if groupFrame.memberCount then
            groupFrame.memberCount:SetText("0/5")
        end
    end
    
    -- Prune empty groups, keeping only one empty group
    addon.Debug("DEBUG", "ClearAllGroups: Pruning empty groups")
    while #dynamicGroups > 1 do
        local groupFrame = table.remove(dynamicGroups)
        if groupFrame then
            groupFrame:Hide()
            groupFrame:SetParent(nil)
            addon.Debug("DEBUG", "ClearAllGroups: Removed empty group frame", #dynamicGroups + 1)
        end
    end
    
    -- Ensure we have at least one empty group available
    EnsureEmptyGroupExists()
    
    -- Update the member list to show all available members again
    UpdateMemberDisplay()
    RepositionAllGroups()
    
    addon.Debug("DEBUG", "ClearAllGroups: All groups cleared and pruned successfully - remaining groups:", #dynamicGroups)
end

-- Addon Communication Callbacks
function addon:OnGroupSyncReceived(data, sender)
    addon.Debug(addon.LOG_LEVEL.INFO, "Received group sync from", sender, "- applying to UI if enabled")
    
    if not addon.settings.communication or not addon.settings.communication.acceptGroupSync then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Group sync disabled in settings")
        return
    end
    
    if not mainFrame or not mainFrame:IsVisible() then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Main frame not visible, storing sync data for later")
        return
    end
    
    -- Clear existing groups before applying sync
    addon:ClearAllGroups()
    
    -- Apply the synced groups
    for i, groupData in ipairs(data.groups) do
        if groupData.members and #groupData.members > 0 then
            -- Ensure we have enough group frames
            while #dynamicGroups < i do
                CreateNewGroup()
            end
            
            local group = dynamicGroups[i]
            if group then
                -- Add members to the group
                for j, memberData in ipairs(groupData.members) do
                    if memberData.name and j <= MAX_GROUP_SIZE then
                        -- Check if member exists in guild
                        local guildMember = nil
                        for _, member in ipairs(memberList) do
                            if member.name == memberData.name then
                                guildMember = member
                                break
                            end
                        end
                        
                        if guildMember then
                            AddMemberToGroup(i, j, guildMember)
                        else
                            addon.Debug(addon.LOG_LEVEL.WARN, "Synced member", memberData.name, "not found in guild roster")
                        end
                    end
                end
            end
        end
    end
    
    RepositionAllGroups()
    addon.Debug(addon.LOG_LEVEL.INFO, "Group sync from", sender, "applied successfully")
end

function addon:UpdatePlayerRoleInUI()
    addon.Debug(addon.LOG_LEVEL.INFO, "UpdatePlayerRoleInUI: Triggered - refreshing member display")
    
    -- Always refresh the member list when called
    if mainFrame then
        UpdateMemberDisplay()
        addon.Debug(addon.LOG_LEVEL.INFO, "UpdatePlayerRoleInUI: Member display refreshed")
        
        -- Also update player's role in any existing dynamic groups
        local playerName = UnitName("player")
        local playerFullName = playerName .. "-" .. GetRealmName()
        
        -- Get current role
        local currentRole = nil
        currentRole = addon.Utilities:GetPlayerRole("player")
        
        addon.Debug(addon.LOG_LEVEL.DEBUG, "UpdatePlayerRoleInUI: Player current role:", currentRole)
        
        -- Update in all dynamic groups
        for groupIndex, group in ipairs(dynamicGroups) do
            if group and group.members then
                for slotIndex, member in pairs(group.members) do
                    if member and (member.name == playerName or member.name == playerFullName) then
                        -- Update the member data
                        member.role = currentRole
                        
                        -- Update the group display
                        local memberFrame = group.memberFrames[slotIndex]
                        if memberFrame and memberFrame.roleText then
                            local roleDisplay, roleColor = addon:GetRoleDisplay(currentRole)
                            
                            memberFrame.roleText:SetText(roleDisplay)
                            memberFrame.roleText:SetTextColor(roleColor.r, roleColor.g, roleColor.b)
                            
                            addon.Debug(addon.LOG_LEVEL.INFO, "UpdatePlayerRoleInUI: Updated player role in group", groupIndex, "slot", slotIndex, "to:", currentRole)
                        end
                        break
                    end
                end
            end
        end
    else
        addon.Debug(addon.LOG_LEVEL.WARN, "UpdatePlayerRoleInUI: MainFrame not available")
    end
end

function addon:OnPlayerDataReceived(data, sender)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Received player data from", sender, "for", data.player)
    
    if not addon.settings.communication or not addon.settings.communication.acceptPlayerData then
        return
    end
    
    -- Update local member data if we have this player
    local memberFound = false
    for _, member in ipairs(memberList) do
        if member.name == data.player then
            if data.rating then
                member.rating = data.rating
            end
            if data.role then
                member.role = data.role
            end
            if data.class then
                member.class = data.class
            end
            if data.level then
                member.level = data.level
            end
            memberFound = true
            addon.Debug(addon.LOG_LEVEL.INFO, "Updated role data for", data.player, "- Role:", data.role, "Rating:", data.rating or "none")
            break
        end
    end
    
    -- If member not in current list but in guild, they might be offline/different level
    if not memberFound then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Player", data.player, "not in current member list, but received role data")
    end
    
    -- Update any existing group assignments
    for _, group in ipairs(dynamicGroups) do
        if group and group.members then
            for slotIndex, member in pairs(group.members) do
                if member and member.name == data.player then
                    if data.role then
                        member.role = data.role
                    end
                    if data.rating then
                        member.rating = data.rating
                    end
                    
                    -- Update the group display
                    local memberFrame = group.memberFrames[slotIndex]
                    if memberFrame and memberFrame.roleText then
                        memberFrame.roleText:SetText(data.role or "")
                    end
                    
                    addon.Debug(addon.LOG_LEVEL.INFO, "Updated group assignment for", data.player, "with new role:", data.role)
                    break
                end
            end
        end
    end
    
    -- Refresh UI if main frame is visible
    if mainFrame and mainFrame:IsVisible() then
        UpdateMemberDisplay()
    end
end

function addon:OnRaiderIODataReceived(data, sender)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Received RaiderIO data from", sender, "for", data.player)
    
    if not addon.settings.communication or not addon.settings.communication.acceptRaiderIOData then
        return
    end
    
    -- Store RaiderIO data for use by RaiderIO integration
    if addon.RaiderIOIntegration then
        addon.RaiderIOIntegration:CacheSharedData(data.player, {
            mythicKeystoneProfile = {
                currentScore = data.mythicPlusScore,
                mainRole = data.mainRole
            },
            bestRuns = data.bestRuns
        })
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Cached shared RaiderIO data for", data.player)
    end
    
    -- Update member data
    for _, member in ipairs(memberList) do
        if member.name == data.player then
            member.rating = data.mythicPlusScore
            member.role = data.mainRole
            break
        end
    end
    
    -- Update any existing group assignments with new score data
    for _, group in ipairs(dynamicGroups) do
        if group and group.members then
            for slotIndex, member in pairs(group.members) do
                if member and member.name == data.player then
                    -- Update member data
                    member.rating = data.mythicPlusScore
                    member.role = data.mainRole
                    
                    -- Update the group display text and background with new score
                    local memberFrame = group.memberFrames[slotIndex]
                    if memberFrame and memberFrame.text then
                        -- Update background color based on new RaiderIO score
                        local bgColor = GetMemberBackgroundColor(member.name)
                        memberFrame.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 0.4)
                        addon.Debug(addon.LOG_LEVEL.DEBUG, "OnRaiderIODataReceived: Updated background color for", member.name)
                        
                        local displayText = member.name
                        if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
                            local formattedScore = addon.RaiderIOIntegration:GetFormattedScoreWithFallback(member.name)
                            if formattedScore and formattedScore ~= "0" then
                                displayText = member.name .. " (" .. formattedScore .. ")"
                            end
                        end
                        memberFrame.text:SetText(displayText)
                        
                        addon.Debug(addon.LOG_LEVEL.INFO, "Updated group display for", data.player, "with new RaiderIO score")
                    end
                    break
                end
            end
        end
    end
    
    -- Refresh UI if main frame is visible
    if mainFrame and mainFrame:IsVisible() then
        UpdateMemberDisplay()
    end
end

function addon:OnFormationRequestReceived(data, sender)
    addon.Debug(addon.LOG_LEVEL.INFO, "Formation request received from", sender)
    
    if not addon.settings.communication or not addon.settings.communication.respondToRequests then
        return
    end
    
    -- For now, just log the request. Could add UI prompts in the future
    addon.Debug(addon.LOG_LEVEL.INFO, "Formation request criteria:", data.criteria and "provided" or "none")
end

function addon:OnFormationResponseReceived(data, sender)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Formation response received from", sender)
    
    -- Handle formation responses - could be used for coordinated group forming
    if data.response then
        addon.Debug(addon.LOG_LEVEL.INFO, "Response from", sender, ":", data.response)
    end
end