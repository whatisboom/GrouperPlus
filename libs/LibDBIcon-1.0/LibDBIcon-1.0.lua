--[[
Name: LibDBIcon-1.0
Revision: $Revision: 243 $
Author: Rabbit
Description: Allows addons to easily create a lightweight minimap icon as an alternative to more heavy LDB displays.
]]

local MAJOR, MINOR = "LibDBIcon-1.0", 49
assert(LibStub, MAJOR.." requires LibStub")
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib, nil, nil, false)
lib.notCreated = lib.notCreated or {}
lib.radius = lib.radius or 5
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", "LibDBIconTooltip", UIParent, "GameTooltipTemplate")

local callbacks = lib.callbacks
local next, Minimap = next, Minimap
local isDraggingButton = false

function lib:IconCallback(event, name, key, value, dataobj)
    if lib.objects[name] then
        if key == "icon" then
            lib.objects[name].icon:SetTexture(value)
        elseif key == "iconCoords" then
            if value then
                lib.objects[name].icon:SetTexCoord(value[1], value[2], value[3], value[4])
            else
                lib.objects[name].icon:SetTexCoord(0, 1, 0, 1)
            end
        elseif key == "iconR" then
            local _, g, b = lib.objects[name].icon:GetVertexColor()
            lib.objects[name].icon:SetVertexColor(value, g, b)
        elseif key == "iconG" then
            local r, _, b = lib.objects[name].icon:GetVertexColor()
            lib.objects[name].icon:SetVertexColor(r, value, b)
        elseif key == "iconB" then
            local r, g, _ = lib.objects[name].icon:GetVertexColor()
            lib.objects[name].icon:SetVertexColor(r, g, value)
        end
    end
end

if not lib.callbackRegistered then
    lib.callbackRegistered = true
end

local function getAnchors(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return "CENTER" end
    local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
    local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
    return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

local function onEnter(self, motion)
    if isDraggingButton then return end
    
    for _, button in next, lib.objects do
        if button == self then
            if button.dataObject.OnTooltipShow then
                lib.tooltip:SetOwner(button, "ANCHOR_NONE")
                lib.tooltip:SetPoint(getAnchors(button))
                button.dataObject.OnTooltipShow(lib.tooltip)
                lib.tooltip:Show()
            elseif button.dataObject.OnEnter then
                button.dataObject.OnEnter(button)
            end
            break
        end
    end
end

local function onLeave(self, motion)
    lib.tooltip:Hide()
    
    for _, button in next, lib.objects do
        if button == self then
            if button.dataObject.OnLeave then
                button.dataObject.OnLeave(button)
            end
            break
        end
    end
end

local function onClick(self, b)
    if isDraggingButton then return end
    for _, button in next, lib.objects do
        if button == self then
            if button.dataObject.OnClick then
                button.dataObject.OnClick(button, b)
            end
            break
        end
    end
end

local function updatePosition(button, position)
    local angle = math.rad(position or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local round = minimapShape == "ROUND"
    local w = (Minimap:GetWidth() / 2) + lib.radius
    local h = (Minimap:GetHeight() / 2) + lib.radius
    if round then
        x, y = x*w, y*h
    else
        x = math.max(-w, math.min(x*w, w))
        y = math.max(-h, math.min(y*h, h))
    end
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onDragStart(self)
    self:LockHighlight()
    isDraggingButton = true
end

local function onDragStop(self)
    self:UnlockHighlight()
    isDraggingButton = false
end

local function onUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.atan2(py - my, px - mx)
    local position = math.deg(angle)
    if position < 0 then
        position = position + 360
    end
    for _, button in next, lib.objects do
        if button == self then
            button.db.minimapPos = position
            updatePosition(button, position)
            break
        end
    end
end

local function createButton(name, object, db)
    local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
    button.dataObject = object
    button.db = db
    button:SetFrameStrata("MEDIUM") 
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) --"Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430) --"Interface\\Minimap\\MiniMap-TrackingBorder"
    overlay:SetPoint("TOPLEFT")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(136467) --"Interface\\Minimap\\UI-Minimap-Background"
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon
    button.isMoving = false

    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnDragStart", onDragStart)
    button:SetScript("OnDragStop", onDragStop)
    button:SetScript("OnUpdate", onUpdate)

    button.icon:SetTexture(object.icon)
    if object.iconCoords then
        button.icon:SetTexCoord(object.iconCoords[1], object.iconCoords[2], object.iconCoords[3], object.iconCoords[4])
    end
    
    updatePosition(button, db.minimapPos)
    
    if not db.hide then
        button:Show()
    else
        button:Hide()
    end
    
    return button
end

function lib:Register(name, object, db)
    if not object.icon then error("LibDBIcon-1.0: Missing icon in object '"..name.."'") end
    if lib.objects[name] or lib.notCreated[name] then error("LibDBIcon-1.0: Object '"..name.."' is already registered") end
    if not db or not db.hide then
        lib.objects[name] = createButton(name, object, db)
    else
        lib.notCreated[name] = {object, db}
    end
end

function lib:Hide(name)
    if not lib.objects[name] then return end
    lib.objects[name]:Hide()
end

function lib:Show(name)
    local object = lib.objects[name]
    if object then
        object:Show()
        return
    end
    
    object = lib.notCreated[name]
    if object then
        lib.objects[name] = createButton(name, object[1], object[2])
        lib.notCreated[name] = nil
    end
end

function lib:IsRegistered(name)
    return (lib.objects[name] and true) or (lib.notCreated[name] and true) or false
end

function lib:Refresh(name, db)
    local button = lib.objects[name]
    if button then
        updatePosition(button, db and db.minimapPos or button.db.minimapPos)
        if db then
            button.db = db
        end
        if button.db.hide then
            button:Hide()
        else
            button:Show()
        end
    end
end

function lib:GetMinimapButton(name)
    return lib.objects[name]
end

local function OnMinimapEnter(self)
    if isDraggingButton then return end
    for _, button in next, lib.objects do
        if button.showOnMouseover then
            button.fadeOut = nil
            button:SetAlpha(1)
        end
    end
end

local function OnMinimapLeave(self)
    if isDraggingButton then return end
    for _, button in next, lib.objects do
        if button.showOnMouseover then
            button.fadeOut = true
        end
    end
end

Minimap:HookScript("OnEnter", OnMinimapEnter)
Minimap:HookScript("OnLeave", OnMinimapLeave)

local function getDatabase(name)
    return _G[name.."IconDB"] or _G[name.."DB"] or _G["LibDBIcon10_"..name.."DB"]
end

function lib:GetAnchors(frame)
    return getAnchors(frame)
end