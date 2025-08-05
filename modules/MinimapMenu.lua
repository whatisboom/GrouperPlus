local addonName, addon = ...

-- Wait for addon to be fully loaded
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    
    -- Get references from addon namespace
    local Debug = addon.Debug
    local LOG_LEVEL = addon.LOG_LEVEL
    local settings = addon.settings
    local db = addon.db
    
    -- Ensure we have valid references
    if not Debug or not LOG_LEVEL then
        print("[GrouperPlus:ERROR] MinimapMenu - Missing addon references")
        return
    end
    
    local LibDBIcon = LibStub("LibDBIcon-1.0")
    
    -- Create dropdown frame
    local dropdownFrame = CreateFrame("Frame", "GrouperPlusDropdown", UIParent, "UIDropDownMenuTemplate")
    
    local function GetSettings()
        return addon.settings or settings
    end
    
    local function SetDebugLevel(newLevel)
        local currentSettings = GetSettings()
        if not currentSettings then
            Debug(LOG_LEVEL.ERROR, "Settings not available yet")
            return
        end
        currentSettings.debugLevel = newLevel
        Debug(LOG_LEVEL.INFO, "Debug level changed to:", newLevel)
    end
    
    local function InitializeDropdown(self, level)
        if not level then return end
        
        Debug(LOG_LEVEL.DEBUG, "InitializeDropdown called with level:", level)
        
        local info = UIDropDownMenu_CreateInfo()
        
        if level == 1 then
            -- Title
            info.text = "GrouperPlus Options"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            -- Separator
            info = UIDropDownMenu_CreateInfo()
            info.hasArrow = false
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            -- Debug Level submenu
            info = UIDropDownMenu_CreateInfo()
            info.text = "Debug Level"
            info.hasArrow = true
            info.notCheckable = true
            info.value = "debuglevel"
            info.menuList = "debuglevel"
            UIDropDownMenu_AddButton(info, level)
            
            -- Show Addon Users
            info = UIDropDownMenu_CreateInfo()
            info.text = "Show Addon Users"
            info.notCheckable = true
            info.func = function()
                if addon.AddonUserList then
                    addon.AddonUserList:ToggleUserList()
                    Debug(LOG_LEVEL.INFO, "Toggled addon user list from minimap menu")
                else
                    Debug(LOG_LEVEL.WARN, "AddonUserList module not available")
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
            
            -- Separator
            info = UIDropDownMenu_CreateInfo()
            info.hasArrow = false
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            -- Hide Minimap Button
            info = UIDropDownMenu_CreateInfo()
            info.text = "Hide Minimap Button"
            info.notCheckable = true
            info.func = function()
                local currentSettings = GetSettings()
                if currentSettings and currentSettings.minimap then
                    currentSettings.minimap.hide = true
                    LibDBIcon:Hide("GrouperPlus")
                    Debug(LOG_LEVEL.INFO, "Minimap button hidden. Type /grouper minimap to show again.")
                end
            end
            UIDropDownMenu_AddButton(info, level)
            
        elseif level == 2 then
            Debug(LOG_LEVEL.DEBUG, "Level 2 menu, UIDROPDOWNMENU_MENU_VALUE:", UIDROPDOWNMENU_MENU_VALUE)
            if UIDROPDOWNMENU_MENU_VALUE == "debuglevel" then
                Debug(LOG_LEVEL.DEBUG, "Creating debug level submenu")
                for _, levelName in ipairs({"ERROR", "WARN", "INFO", "DEBUG", "TRACE"}) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = levelName
                    local currentSettings = GetSettings()
                    info.checked = (currentSettings and currentSettings.debugLevel == levelName)
                    info.func = function()
                        SetDebugLevel(levelName)
                        CloseDropDownMenus()
                    end
                    Debug(LOG_LEVEL.DEBUG, "Adding debug level option:", levelName, "checked:", info.checked)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end
    
    UIDropDownMenu_Initialize(dropdownFrame, InitializeDropdown, "MENU")
    
    -- Export dropdown frame to addon namespace
    addon.dropdownFrame = dropdownFrame
    
    -- Unregister event after initialization
    self:UnregisterEvent("ADDON_LOADED")
end)