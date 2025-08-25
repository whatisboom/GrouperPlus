local addonName, addon = ...

-- Group Frame UI Module
-- Handles group frame creation, utility display, and visual management

local GroupFrameUI = addon.ModuleBase:New("GroupUI")
addon.GroupFrameUI = GroupFrameUI

-- Forward declarations for dependencies
local MAX_GROUP_SIZE = 5
local AddMemberToGroup, RemoveMemberFromGroup, GetDraggedMember, SetDraggedMember
local RemoveMemberFromPlayerList, ResetCursor, HideDragFrame, ShowDragFrame

function GroupFrameUI:OnInitialize()
    -- Dependencies are injected individually by MainFrame
    MAX_GROUP_SIZE = self:GetDependency("MAX_GROUP_SIZE") or 5
    AddMemberToGroup = self:GetDependency("AddMemberToGroup")
    RemoveMemberFromGroup = self:GetDependency("RemoveMemberFromGroup")
    GetDraggedMember = self:GetDependency("GetDraggedMember")
    SetDraggedMember = self:GetDependency("SetDraggedMember")
    RemoveMemberFromPlayerList = self:GetDependency("RemoveMemberFromPlayerList")
    ResetCursor = self:GetDependency("ResetCursor")
    HideDragFrame = self:GetDependency("HideDragFrame")
    ShowDragFrame = self:GetDependency("ShowDragFrame")
    
    if AddMemberToGroup and RemoveMemberFromGroup and GetDraggedMember and SetDraggedMember then
        self.Debug("DEBUG", "GroupFrameUI dependencies initialized successfully")
    else
        self.Debug("WARN", "GroupFrameUI: Some dependencies missing - MainFrame may not be fully loaded yet")
    end
end

-- Check what utilities are available in a group
function GroupFrameUI:CheckGroupUtilities(groupFrame)
    local utilities = {
        COMBAT_REZ = false,
        BLOODLUST = false,
        INTELLECT = false,
        STAMINA = false,
        ATTACK_POWER = false,
        VERSATILITY = false,
        SKYFURY = false,
        MYSTIC_TOUCH = false,
        CHAOS_BRAND = false
    }
    
    for _, member in pairs(groupFrame.members) do
        if member and member.class then
            local className = string.upper(member.class)
            local classUtilities = addon.CLASS_UTILITIES[className]
            
            if classUtilities then
                for _, utility in ipairs(classUtilities) do
                    if utilities[utility] ~= nil then
                        utilities[utility] = true
                    end
                end
            end
        end
    end
    
    GroupFrameUI.Debug("DEBUG", "GroupFrameUI: Group", groupFrame.groupIndex, 
        "brez:", utilities.COMBAT_REZ, "lust:", utilities.BLOODLUST,
        "int:", utilities.INTELLECT, "stam:", utilities.STAMINA,
        "ap:", utilities.ATTACK_POWER, "vers:", utilities.VERSATILITY,
        "sky:", utilities.SKYFURY, "mt:", utilities.MYSTIC_TOUCH,
        "cb:", utilities.CHAOS_BRAND)
    
    return utilities
end

-- Update group title with utility indicators
function GroupFrameUI:UpdateGroupTitle(groupFrame)
    if not groupFrame.keystoneText or not groupFrame.utilityText then return end
    
    local utilities = self:CheckGroupUtilities(groupFrame)
    
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
    local mtText = utilities.MYSTIC_TOUCH and "|cFF00FF00MT|r" or "|cFFAAAAAAMT|r"
    local cbText = utilities.CHAOS_BRAND and "|cFF00FF00CB|r" or "|cFFAAAAAAChB|r"
    
    -- Keystone information (left side)
    local keystoneDisplayText = "Group " .. groupFrame.groupIndex
    if addon.GroupStateManager and groupFrame.groupIndex then
        local keystoneInfo = addon.GroupStateManager:GetGroupKeystone(groupFrame.groupIndex)
        if keystoneInfo and keystoneInfo.hasKeystone then
            keystoneDisplayText = keystoneDisplayText .. "\n|cFFFF7D0AKeystone:|r |cFFFFFFFF" .. keystoneInfo.dungeonName .. " +" .. keystoneInfo.level .. "|r"
            if keystoneInfo.assignedPlayer then
                keystoneDisplayText = keystoneDisplayText .. "\n|cFFAAAAAAby " .. keystoneInfo.assignedPlayer .. "|r"
            end
        else
            keystoneDisplayText = keystoneDisplayText .. "\n|cFFFF0000No Keystone|r"
        end
    end
    
    -- Utility information (right side)
    local utilityDisplayText = brezText .. " " .. lustText .. "\n" .. intText .. " " .. stamText .. " " .. apText .. " " .. versText .. " " .. skyText .. "\n" .. mtText .. " " .. cbText
    
    groupFrame.keystoneText:SetText(keystoneDisplayText)
    groupFrame.utilityText:SetText(utilityDisplayText)
    
    -- Update legacy header reference for backward compatibility
    if groupFrame.header then
        groupFrame.header:SetText(keystoneDisplayText)
    end
    
    GroupFrameUI.Debug("DEBUG", "GroupFrameUI: Updated group", groupFrame.groupIndex, "title with separated layout")
end

-- Create drag and drop handlers for member slot
local function CreateMemberSlotDragHandlers(memberFrame, groupFrame, groupIndex, slotIndex)
    -- OnDragStart - Allow dragging members out of group frames
    memberFrame:SetScript("OnDragStart", function(self)
        local member = groupFrame.members[slotIndex]
        if member then
            GroupFrameUI.Debug("INFO", "=== Group OnDragStart ENTRY ===")
            GroupFrameUI.Debug("INFO", "Group slot OnDragStart: dragging", member.name, "from group", groupIndex, "slot", slotIndex)
            SetDraggedMember({
                name = member.name,
                memberInfo = member,
                fromGroup = true,
                sourceGroup = groupIndex,
                sourceSlot = slotIndex
            })
            
            -- Create drag visual feedback
            if ShowDragFrame then
                ShowDragFrame(member.name, member)
                GroupFrameUI.Debug("DEBUG", "Group drag: ShowDragFrame called for", member.name)
            else
                GroupFrameUI.Debug("DEBUG", "Group drag visual feedback - ShowDragFrame not available via dependencies")
            end
            
            SetCursor("Interface\\Cursor\\Point")
        else
            GroupFrameUI.Debug("DEBUG", "Group slot OnDragStart: No member in slot", slotIndex, "to drag")
        end
    end)
    
    -- OnDragStop - Clean up drag state (with delay to allow OnReceiveDrag to process)
    memberFrame:SetScript("OnDragStop", function(self)
        GroupFrameUI.Debug("DEBUG", "Group slot OnDragStop")
        if HideDragFrame then
            HideDragFrame()
        end
        -- Delay clearing draggedMember to allow OnReceiveDrag to process
        C_Timer.After(0.1, function()
            local currentDraggedMember = GetDraggedMember()
            if currentDraggedMember then
                GroupFrameUI.Debug("DEBUG", "Group OnDragStop: Delayed clear of draggedMember")
                SetDraggedMember(nil)
            end
        end)
    end)
    
    memberFrame:SetScript("OnReceiveDrag", function(self)
        local draggedMember = GetDraggedMember()
        GroupFrameUI.Debug("INFO", "=== OnReceiveDrag ENTRY ===")
        GroupFrameUI.Debug("INFO", "Group slot OnReceiveDrag: group", groupIndex, "slot", slotIndex, "draggedMember:", draggedMember and draggedMember.name or "nil")
        GroupFrameUI.Debug("DEBUG", "OnReceiveDrag: AddMemberToGroup function available:", AddMemberToGroup ~= nil)
        
        if not draggedMember then
            GroupFrameUI.Debug("WARN", "OnReceiveDrag: No draggedMember")
            return
        end
        
        local targetMember = groupFrame.members[slotIndex]
        GroupFrameUI.Debug("DEBUG", "OnReceiveDrag: Target slot has member:", targetMember and targetMember.name or "empty")
        
        -- Case 1: Dropping on empty slot (existing behavior)
        if not targetMember then
            GroupFrameUI.Debug("INFO", "Case 1: Dropping", draggedMember.name, "on empty slot", slotIndex, "in group", groupIndex)
            
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
                GroupFrameUI.Debug("ERROR", "AddMemberToGroup failed with error:", result)
            end
            
            if success then
                -- For group-to-group moves, the source removal is handled in AddMemberToGroup
                if not fromGroup then
                    RemoveMemberFromPlayerList(memberName)
                    if sourceRow then
                        sourceRow:Hide()
                    end
                end
                GroupFrameUI.Debug("INFO", "Successfully dropped", memberName, "on empty slot")
            end
            
            -- Clear drag state immediately after successful drop
            SetDraggedMember(nil)
            ResetCursor()
            if HideDragFrame then
                HideDragFrame()
            end
            return
        end
        
        -- Additional drag/drop logic would go here for member swapping, etc.
        GroupFrameUI.Debug("DEBUG", "OnReceiveDrag: Complex drop scenarios not yet implemented in GroupFrameUI")
    end)
    
    -- Add tooltip handlers for group member frames
    memberFrame:SetScript("OnEnter", function(self)
        local member = groupFrame.members[slotIndex]
        if member and member.name then
            -- Use the shared tooltip function from MemberRowUI
            if addon.MemberRowUI and addon.MemberRowUI.CreateMemberTooltip then
                addon.MemberRowUI:CreateMemberTooltip(self, member.name)
            end
        end
    end)
    
    memberFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- Create drag and drop handlers for group-level operations
local function CreateGroupDragHandlers(groupFrame, groupIndex)
    groupFrame:SetScript("OnReceiveDrag", function(self)
        local draggedMember = GetDraggedMember()
        GroupFrameUI.Debug("INFO", "=== Group-level OnReceiveDrag ENTRY ===")
        GroupFrameUI.Debug("INFO", "Group OnReceiveDrag: group", groupIndex, "draggedMember:", draggedMember and draggedMember.name or "nil")
        
        if not draggedMember then
            GroupFrameUI.Debug("WARN", "Group OnReceiveDrag: No draggedMember")
            return
        end
        
        -- Find the first empty slot in the group
        local emptySlotIndex = nil
        for slot = 1, MAX_GROUP_SIZE do
            if not groupFrame.members[slot] then
                emptySlotIndex = slot
                GroupFrameUI.Debug("DEBUG", "Group OnReceiveDrag: Found empty slot", slot, "in group", groupIndex)
                break
            end
        end
        
        if emptySlotIndex then
            -- Use the member slot drag handler for the empty slot
            local memberFrame = groupFrame.memberFrames[emptySlotIndex]
            if memberFrame and memberFrame:GetScript("OnReceiveDrag") then
                memberFrame:GetScript("OnReceiveDrag")(memberFrame)
            end
        else
            GroupFrameUI.Debug("WARN", "Group OnReceiveDrag: No empty slots available in group", groupIndex)
        end
    end)
end

-- Create a group frame with member slots and drag/drop handling
function GroupFrameUI:CreateGroupFrame(parent, groupIndex, groupWidth)
    GroupFrameUI.Debug("DEBUG", "GroupFrameUI: Creating group frame", groupIndex, "with width", groupWidth)
    
    local groupFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    groupFrame:SetSize(groupWidth, 220)
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
    
    -- Create header container frame for layout control
    local headerContainer = CreateFrame("Frame", nil, groupFrame)
    headerContainer:SetSize(groupWidth - 20, 45)
    headerContainer:SetPoint("TOP", groupFrame, "TOP", 0, -8)
    
    -- Create keystone text (upper left)
    local keystoneText = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keystoneText:SetPoint("TOPLEFT", headerContainer, "TOPLEFT", 0, 0)
    keystoneText:SetText("Group " .. groupIndex)
    keystoneText:SetTextColor(0.8, 0.8, 1)
    keystoneText:SetJustifyH("LEFT")
    keystoneText:SetWidth(groupWidth - 120)
    
    -- Create utility text (right aligned)
    local utilityText = headerContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    utilityText:SetPoint("TOPRIGHT", headerContainer, "TOPRIGHT", 0, 0)
    utilityText:SetText("")
    utilityText:SetTextColor(0.8, 0.8, 1)
    utilityText:SetJustifyH("RIGHT")
    utilityText:SetWidth(110)
    
    groupFrame.header = keystoneText  -- Keep for backward compatibility
    groupFrame.keystoneText = keystoneText
    groupFrame.utilityText = utilityText
    groupFrame.headerContainer = headerContainer
    groupFrame.members = {}
    groupFrame.memberFrames = {}
    groupFrame.groupIndex = groupIndex
    
    local memberWidth = groupWidth - 20
    
    -- Create member slots
    for i = 1, MAX_GROUP_SIZE do
        local memberFrame = CreateFrame("Button", nil, groupFrame)
        memberFrame:SetSize(memberWidth, 20)
        memberFrame:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", 10, -55 - ((i - 1) * 22))
        
        local bg = memberFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.3, 0.3)
        bg:Hide()
        
        local text = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", memberFrame, "LEFT", 35, 0)
        text:SetText("Empty")
        text:SetTextColor(0.5, 0.5, 0.5)
        text:SetJustifyH("LEFT")
        
        local roleText = memberFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        roleText:SetPoint("LEFT", memberFrame, "LEFT", 5, 0)
        roleText:SetJustifyH("LEFT")
        roleText:SetWidth(25)
        roleText:SetText("")
        
        memberFrame.bg = bg
        memberFrame.text = text
        memberFrame.roleText = roleText
        
        -- Create remove button for member slots
        local removeBtn = CreateFrame("Button", nil, memberFrame)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", memberFrame, "RIGHT", -5, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
        removeBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        removeBtn:Hide()
        
        removeBtn:SetScript("OnClick", function()
            GroupFrameUI.Debug("INFO", "Remove button clicked for group", groupIndex, "slot", i)
            if RemoveMemberFromGroup then
                RemoveMemberFromGroup(groupIndex, i)
            end
        end)
        
        memberFrame.removeBtn = removeBtn
        
        memberFrame:EnableMouse(true)
        memberFrame:RegisterForDrag("LeftButton")
        
        -- Set up drag and drop handling for this member slot
        CreateMemberSlotDragHandlers(memberFrame, groupFrame, groupIndex, i)
        
        groupFrame.memberFrames[i] = memberFrame
        
        GroupFrameUI.Debug("DEBUG", "GroupFrameUI: Setting up drag and drop handlers for group", groupIndex, "slot", i)
    end
    
    -- Set up group-level drag and drop handling
    groupFrame:EnableMouse(true)
    groupFrame:RegisterForDrag("LeftButton")
    CreateGroupDragHandlers(groupFrame, groupIndex)
    
    -- Set up right-click context menu for keystone management
    groupFrame:SetScript("OnMouseUp", function(frame, button)
        if button == "RightButton" then
            GroupFrameUI:ShowKeystoneContextMenu(groupFrame)
        end
    end)
    
    GroupFrameUI.Debug("DEBUG", "GroupFrameUI: Group frame", groupIndex, "created successfully with width", groupWidth, "and group-level drag handling")
    
    -- Initialize with default title showing missing utilities
    self:UpdateGroupTitle(groupFrame)
    
    return groupFrame
end

function GroupFrameUI:ShowKeystoneContextMenu(groupFrame)
    if not addon.GroupStateManager or not addon.Keystone then
        self.Debug("WARN", "Required modules not available for keystone context menu")
        return
    end
    
    local groupIndex = groupFrame.groupIndex
    if not groupIndex then
        self.Debug("WARN", "Group frame missing groupIndex")
        return
    end
    
    local currentKeystone = addon.GroupStateManager:GetGroupKeystone(groupIndex)
    local availableKeystones = self:GetAvailableKeystones()
    
    local dropdownFrame = CreateFrame("Frame", "GrouperPlusKeystoneDropdown", UIParent, "UIDropDownMenuTemplate")
    
    local function InitializeKeystoneMenu(frame, level)
        if level == 1 then
            local info = UIDropDownMenu_CreateInfo()
            
            if currentKeystone and currentKeystone.hasKeystone then
                info.text = "Current: " .. currentKeystone.dungeonName .. " +" .. currentKeystone.level
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
                
                info = UIDropDownMenu_CreateInfo()
                info.text = "Remove Keystone"
                info.func = function()
                    addon.GroupStateManager:RemoveKeystoneFromGroup(groupIndex)
                    self:UpdateGroupTitle(groupFrame)
                    self.Debug("INFO", "Removed keystone from group", groupIndex)
                    CloseDropDownMenus()
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
                
                if #availableKeystones > 0 then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "Change Keystone"
                    info.hasArrow = true
                    info.notCheckable = true
                    info.value = "change_keystone"
                    UIDropDownMenu_AddButton(info, level)
                end
            else
                info.text = "No Keystone Assigned"
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
                
                if #availableKeystones > 0 then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "Assign Keystone"
                    info.hasArrow = true
                    info.notCheckable = true
                    info.value = "assign_keystone"
                    UIDropDownMenu_AddButton(info, level)
                else
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "No keystones available"
                    info.disabled = true
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info, level)
                end
            end
            
            info = UIDropDownMenu_CreateInfo()
            info.text = "Cancel"
            info.func = function() CloseDropDownMenus() end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
        elseif level == 2 then
            local parentValue = UIDROPDOWNMENU_MENU_VALUE
            if parentValue == "assign_keystone" or parentValue == "change_keystone" then
                local assignedKeystones = addon.GroupStateManager:GetAllGroupKeystones()
                
                for _, keystoneData in ipairs(availableKeystones) do
                    local isAssigned, assignedGroupId = false, nil
                    
                    for groupId, groupKeystone in pairs(assignedKeystones) do
                        if groupKeystone.hasKeystone and 
                           groupKeystone.mapID == keystoneData.mapID and 
                           groupKeystone.level == keystoneData.level and
                           groupId ~= groupFrame.groupIndex then
                            isAssigned = true
                            assignedGroupId = groupId
                            break
                        end
                    end
                    
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = keystoneData.dungeonName .. " +" .. keystoneData.level .. " (" .. keystoneData.assignedPlayer .. ")"
                    if isAssigned then
                        info.text = info.text .. " [Assigned to Group " .. assignedGroupId .. "]"
                        info.disabled = true
                    else
                        info.func = function()
                            addon.GroupStateManager:AssignKeystoneToGroup(groupFrame.groupIndex, keystoneData)
                            self:UpdateGroupTitle(groupFrame)
                            self.Debug("INFO", "Manually assigned keystone", keystoneData.dungeonName, "+", keystoneData.level, "to group", groupFrame.groupIndex)
                            CloseDropDownMenus()
                        end
                    end
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info, level)
                end
                
                if #availableKeystones == 0 then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = "No keystones available"
                    info.disabled = true
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end
    
    UIDropDownMenu_Initialize(dropdownFrame, InitializeKeystoneMenu, "MENU")
    ToggleDropDownMenu(1, nil, dropdownFrame, "cursor", 0, 0)
end

function GroupFrameUI:GetAvailableKeystones()
    local keystones = {}
    
    if not addon.Keystone then
        return keystones
    end
    
    local playerInfo = addon.WoWAPIWrapper and addon.WoWAPIWrapper:GetPlayerInfo()
    if playerInfo then
        local playerKeystone = addon.Keystone:GetKeystoneInfo()
        if playerKeystone and playerKeystone.hasKeystone then
            table.insert(keystones, {
                mapID = playerKeystone.mapID,
                level = playerKeystone.level,
                dungeonName = playerKeystone.dungeonName,
                assignedPlayer = playerInfo.name,
                source = "own"
            })
        end
    end
    
    local receivedKeystones = addon.Keystone:GetReceivedKeystones()
    for playerName, keystoneData in pairs(receivedKeystones) do
        if keystoneData.mapID and keystoneData.level then
            table.insert(keystones, {
                mapID = keystoneData.mapID,
                level = keystoneData.level,
                dungeonName = keystoneData.dungeonName,
                assignedPlayer = playerName,
                source = "received"
            })
        end
    end
    
    table.sort(keystones, function(a, b)
        if a.level == b.level then
            return a.dungeonName < b.dungeonName
        end
        return a.level > b.level
    end)
    
    return keystones
end

