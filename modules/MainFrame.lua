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
local CreateNewGroup, EnsureEmptyGroupExists, CalculateGroupLayout, RepositionAllGroups
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
                table.insert(memberList, {
                    name = name,
                    class = classFileName or class,
                    classLocalized = class,
                    level = level
                })
                addon.Debug("TRACE", "UpdateGuildMemberList: Added member", name, "level", level, "class:", classFileName or class, "localized:", class)
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
    
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.text:SetJustifyH("LEFT")
    
    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.scoreText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.scoreText:SetJustifyH("RIGHT")
    row.scoreText:SetText("")
    
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetAlpha(0.5)
    
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    
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
        
        -- Force text positioning and parent refresh
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
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
            
            addon.Debug("INFO", "Recreated row", i, "for", member.name)
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

local function CreateGroupFrame(parent, groupIndex, groupWidth)
    addon.Debug("DEBUG", "CreateGroupFrame: Creating group frame", groupIndex, "with width", groupWidth)
    
    local groupFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    groupFrame:SetSize(groupWidth, 140)
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
    
    groupFrame.members = {}
    groupFrame.memberFrames = {}
    groupFrame.groupIndex = groupIndex
    
    local memberWidth = groupWidth - 20
    
    for i = 1, MAX_GROUP_SIZE do
        local memberFrame = CreateFrame("Button", nil, groupFrame)
        memberFrame:SetSize(memberWidth, 20)
        memberFrame:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", 10, -25 - ((i-1) * 22))
        
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
            end
        end)
        
        memberFrame:SetScript("OnLeave", function(self)
            addon.Debug("DEBUG", "Group slot OnLeave: group", groupIndex, "slot", i)
            if draggedMember and not groupFrame.members[i] then
                self.bg:Hide()
            elseif not draggedMember and not groupFrame.members[i] then
                self.bg:Hide()
            elseif groupFrame.members[i] then
                self.bg:SetColorTexture(0.2, 0.2, 0.3, 0.3)
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
            addon.Debug("DEBUG", "OnReceiveDrag condition check: draggedMember exists:", draggedMember ~= nil)
            addon.Debug("DEBUG", "OnReceiveDrag condition check: slot empty:", not groupFrame.members[slotIndex])
            if draggedMember and not groupFrame.members[slotIndex] then
                addon.Debug("INFO", "Dropped member", draggedMember.name, "on group", groupIndex, "slot", slotIndex)
                
                local memberName = draggedMember.name
                local sourceRow = draggedMember.sourceRow
                local fromGroup = draggedMember.fromGroup
                local sourceGroup = draggedMember.sourceGroup
                local sourceSlot = draggedMember.sourceSlot
                
                addon.Debug("DEBUG", "About to call AddMemberToGroup with:", memberName, groupIndex, slotIndex, "fromGroup:", fromGroup)
                addon.Debug("DEBUG", "AddMemberToGroup function exists:", AddMemberToGroup ~= nil)
                
                local success = false
                local errorMsg = nil
                local status, result = pcall(AddMemberToGroup, memberName, groupIndex, slotIndex)
                if status then
                    success = result
                    addon.Debug("DEBUG", "AddMemberToGroup returned:", success)
                else
                    errorMsg = result
                    addon.Debug("ERROR", "AddMemberToGroup failed with error:", errorMsg)
                end
                
                addon.Debug("DEBUG", "Checking success result:", success)
                if success then
                    addon.Debug("DEBUG", "Success=true, proceeding with member removal and UI updates")
                    if fromGroup and sourceGroup and sourceSlot then
                        addon.Debug("INFO", "Removing member from source group", sourceGroup, "slot", sourceSlot)
                        RemoveMemberFromGroup(sourceGroup, sourceSlot, true) -- Skip player list update when moving between groups
                    else
                        RemoveMemberFromPlayerList(memberName)
                        if sourceRow then
                            sourceRow:Hide()
                        end
                    end
                    addon.Debug("INFO", "Successfully dropped (OnReceiveDrag)", memberName, "on group", groupIndex, "slot", slotIndex, "- AddMemberToGroup returned:", success)
                else
                    addon.Debug("ERROR", "Failed to add member", memberName, "to group", groupIndex, "slot", slotIndex)
                end
                
                draggedMember = nil
                ResetCursor()
                HideDragFrame()
            else
                addon.Debug("WARN", "OnReceiveDrag: Cannot drop - draggedMember:", draggedMember and draggedMember.name or "nil", "slot occupied:", groupFrame.members[slotIndex] ~= nil)
            end
        end)
        
        memberFrame.slotIndex = i
        groupFrame.memberFrames[i] = memberFrame
    end
    
    addon.Debug("DEBUG", "CreateGroupFrame: Group frame", groupIndex, "created successfully with width", groupWidth)
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
        return 0, 0, 0
    end
    
    local containerWidth = groupsContainer:GetParent():GetWidth() - 46
    local numGroups = #dynamicGroups + 1
    local spacing = 10
    local totalSpacing = spacing * (numGroups + 1)
    local availableWidth = containerWidth - totalSpacing
    local groupWidth = math.max(200, math.floor(availableWidth / numGroups))
    
    addon.Debug("DEBUG", "CalculateGroupLayout: containerWidth", containerWidth, "numGroups", numGroups, "groupWidth", groupWidth)
    return containerWidth, numGroups, groupWidth
end

RepositionAllGroups = function()
    addon.Debug("DEBUG", "RepositionAllGroups: Repositioning all groups")
    
    if not groupsContainer or #dynamicGroups == 0 then
        return
    end
    
    local containerWidth, numGroups, groupWidth = CalculateGroupLayout()
    local spacing = 10
    
    for i, groupFrame in ipairs(dynamicGroups) do
        groupFrame:ClearAllPoints()
        groupFrame:SetSize(groupWidth, 140)
        
        local xOffset = spacing + ((i - 1) * (groupWidth + spacing))
        groupFrame:SetPoint("TOPLEFT", groupsContainer, "TOPLEFT", xOffset, -10)
        
        local memberWidth = groupWidth - 20
        for j = 1, MAX_GROUP_SIZE do
            if groupFrame.memberFrames[j] then
                groupFrame.memberFrames[j]:SetSize(memberWidth, 20)
            end
        end
        
        addon.Debug("DEBUG", "RepositionAllGroups: Positioned group", i, "at xOffset", xOffset, "with width", groupWidth)
    end
    
    local totalWidth = (numGroups * groupWidth) + ((numGroups + 1) * spacing)
    groupsContainer:SetWidth(math.max(totalWidth, containerWidth))
end

CreateNewGroup = function()
    addon.Debug("DEBUG", "CreateNewGroup: Creating new group")
    
    if not groupsContainer then
        addon.Debug("ERROR", "CreateNewGroup: groupsContainer is nil")
        return
    end
    
    local groupIndex = #dynamicGroups + 1
    local containerWidth, numGroups, groupWidth = CalculateGroupLayout()
    
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
        addon.Debug("DEBUG", "AddMemberToGroup: Using member info from draggedMember (group-to-group move):", memberInfo.name)
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
        print("|cFFFF0000GrouperPlus:|r " .. reason)
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
        memberFrame.bg:Show()
        memberFrame.text:SetText(memberInfo.name)
        addon.Debug("DEBUG", "AddMemberToGroup: Set member text to:", memberInfo.name)
        
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
    
    addon.Debug("INFO", "AddMemberToGroup: Successfully added", memberName, "to group", groupIndex, "with role-based positioning - RETURNING TRUE")
    return true
end

local function GetRolePriority(role)
    -- Define role priorities for sorting (lower number = higher priority)
    local priorities = {
        TANK = 1,
        HEALER = 2,
        DPS = 3
    }
    return priorities[role] or 999
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
            memberFrame.bg:Show()
            memberFrame.text:SetText(member.name)
            
            -- Display role
            local roleDisplay = ""
            local roleColor = {r = 1, g = 1, b = 1}
            if member.role == "TANK" then
                roleDisplay = "[T]"
                roleColor = {r = 0.78, g = 0.61, b = 0.43} -- Tank brown
            elseif member.role == "HEALER" then
                roleDisplay = "[H]"
                roleColor = {r = 0.0, g = 1.0, b = 0.59} -- Healer green
            elseif member.role == "DPS" then
                roleDisplay = "[D]"
                roleColor = {r = 0.77, g = 0.12, b = 0.23} -- DPS red
            end
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
    print("GrouperPlus: Auto-Form button created successfully!")
    addon.Debug("DEBUG", "Created Auto-Form button with name:", autoFormButton:GetName())
    autoFormButton:SetScript("OnClick", function()
        print("GrouperPlus: Auto-Form button clicked!")
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
    print("GrouperPlus: AutoFormGroups function called")
    addon.Debug("INFO", "AutoFormGroups: Starting auto-formation process")
    
    if not self.AutoFormation then
        addon.Debug("ERROR", "AutoFormGroups: AutoFormation module not loaded")
        print("GrouperPlus: Auto-formation module not available")
        return
    end
    
    -- Clear existing groups before auto-formation
    addon.Debug("DEBUG", "AutoFormGroups: Clearing existing groups")
    self:ClearAllGroups()
    
    -- Get available members from the member list
    if not memberList or #memberList == 0 then
        addon.Debug("WARN", "AutoFormGroups: No members available for auto-formation")
        print("GrouperPlus: No guild members available. Please wait for the guild roster to load, then try again.")
        -- Try to refresh the guild roster
        C_GuildInfo.GuildRoster()
        return
    end
    
    addon.Debug("INFO", "AutoFormGroups: Found", #memberList, "available members")
    
    -- Create balanced groups using the auto-formation algorithm
    local groups = self.AutoFormation:CreateBalancedGroups(memberList, 5)
    
    if not groups or #groups == 0 then
        addon.Debug("WARN", "AutoFormGroups: No valid groups could be formed")
        print("GrouperPlus: Unable to form balanced groups with current members")
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
    
    print("GrouperPlus: Auto-formed", #groups, "balanced groups")
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
    end
    
    -- Reset group member counts
    for _, groupFrame in ipairs(dynamicGroups) do
        if groupFrame.memberCount then
            groupFrame.memberCount:SetText("0/5")
        end
    end
    
    -- Update the member list to show all available members again
    UpdateMemberDisplay()
    RepositionAllGroups()
    
    addon.Debug("DEBUG", "ClearAllGroups: All groups cleared successfully")
end