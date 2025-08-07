local addonName, addon = ...

-- Group Frame UI Module
-- Handles group frame creation, utility display, and visual management

local GroupFrameUI = {}
addon.GroupFrameUI = GroupFrameUI

-- Forward declarations for dependencies
local MAX_GROUP_SIZE = 5
local AddMemberToGroup, RemoveMemberFromGroup, GetDraggedMember, SetDraggedMember
local RemoveMemberFromPlayerList, ResetCursor, HideDragFrame

-- Initialize dependencies from MainFrame
function GroupFrameUI:SetDependencies(deps)
    MAX_GROUP_SIZE = deps.MAX_GROUP_SIZE or 5
    AddMemberToGroup = deps.AddMemberToGroup
    RemoveMemberFromGroup = deps.RemoveMemberFromGroup
    GetDraggedMember = deps.GetDraggedMember
    SetDraggedMember = deps.SetDraggedMember
    RemoveMemberFromPlayerList = deps.RemoveMemberFromPlayerList
    ResetCursor = deps.ResetCursor
    HideDragFrame = deps.HideDragFrame
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
    
    addon.Debug("DEBUG", "GroupFrameUI: Group", groupFrame.groupIndex, 
        "brez:", utilities.COMBAT_REZ, "lust:", utilities.BLOODLUST,
        "int:", utilities.INTELLECT, "stam:", utilities.STAMINA,
        "ap:", utilities.ATTACK_POWER, "vers:", utilities.VERSATILITY,
        "sky:", utilities.SKYFURY, "mt:", utilities.MYSTIC_TOUCH,
        "cb:", utilities.CHAOS_BRAND)
    
    return utilities
end

-- Update group title with utility indicators
function GroupFrameUI:UpdateGroupTitle(groupFrame)
    if not groupFrame.header then return end
    
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
    local mtText = utilities.MYSTIC_TOUCH and "|cFF00FF00Mystic Touch|r" or "|cFFAAAAAAMystic Touch|r"
    local cbText = utilities.CHAOS_BRAND and "|cFF00FF00Chaos Brand|r" or "|cFFAAAAAAChaos Brand|r"
    
    groupFrame.header:SetText(brezText .. " " .. lustText .. "\n" .. intText .. " " .. stamText .. " " .. apText .. " " .. versText .. " " .. skyText .. "\n" .. mtText .. " " .. cbText)
    addon.Debug("DEBUG", "GroupFrameUI: Updated group", groupFrame.groupIndex, "title with all utilities")
end

-- Create drag and drop handlers for member slot
local function CreateMemberSlotDragHandlers(memberFrame, groupFrame, groupIndex, slotIndex)
    memberFrame:SetScript("OnReceiveDrag", function(self)
        local draggedMember = GetDraggedMember()
        addon.Debug("INFO", "=== OnReceiveDrag ENTRY ===")
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
            
            SetDraggedMember(nil)
            ResetCursor()
            HideDragFrame()
            return
        end
        
        -- Additional drag/drop logic would go here for member swapping, etc.
        addon.Debug("DEBUG", "OnReceiveDrag: Complex drop scenarios not yet implemented in GroupFrameUI")
    end)
end

-- Create drag and drop handlers for group-level operations
local function CreateGroupDragHandlers(groupFrame, groupIndex)
    groupFrame:SetScript("OnReceiveDrag", function(self)
        local draggedMember = GetDraggedMember()
        addon.Debug("INFO", "=== Group-level OnReceiveDrag ENTRY ===")
        addon.Debug("INFO", "Group OnReceiveDrag: group", groupIndex, "draggedMember:", draggedMember and draggedMember.name or "nil")
        
        if not draggedMember then
            addon.Debug("WARN", "Group OnReceiveDrag: No draggedMember")
            return
        end
        
        -- Find the first empty slot in the group
        local emptySlotIndex = nil
        for slot = 1, MAX_GROUP_SIZE do
            if not groupFrame.members[slot] then
                emptySlotIndex = slot
                addon.Debug("DEBUG", "Group OnReceiveDrag: Found empty slot", slot, "in group", groupIndex)
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
            addon.Debug("WARN", "Group OnReceiveDrag: No empty slots available in group", groupIndex)
        end
    end)
end

-- Create a group frame with member slots and drag/drop handling
function GroupFrameUI:CreateGroupFrame(parent, groupIndex, groupWidth)
    addon.Debug("DEBUG", "GroupFrameUI: Creating group frame", groupIndex, "with width", groupWidth)
    
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
    
    local header = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOP", groupFrame, "TOP", 0, -8)
    header:SetText("Group " .. groupIndex)
    header:SetTextColor(0.8, 0.8, 1)
    
    groupFrame.header = header
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
            addon.Debug("INFO", "Remove button clicked for group", groupIndex, "slot", i)
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
        
        addon.Debug("DEBUG", "GroupFrameUI: Setting up drag and drop handlers for group", groupIndex, "slot", i)
    end
    
    -- Set up group-level drag and drop handling
    groupFrame:EnableMouse(true)
    groupFrame:RegisterForDrag("LeftButton")
    CreateGroupDragHandlers(groupFrame, groupIndex)
    
    addon.Debug("DEBUG", "GroupFrameUI: Group frame", groupIndex, "created successfully with width", groupWidth, "and group-level drag handling")
    
    -- Initialize with default title showing missing utilities
    self:UpdateGroupTitle(groupFrame)
    
    return groupFrame
end