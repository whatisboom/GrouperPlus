local addonName, addon = ...

local MinimapMenu = addon.ModuleBase:New("MinimapMenu")
addon.MinimapMenu = MinimapMenu

function MinimapMenu:OnInitialize()
    local LibDBIcon = addon.LibraryManager:GetLibrary("LibDBIcon-1.0")
    if not LibDBIcon then
        self.Debug("ERROR", "MinimapMenu: LibDBIcon not available")
        return
    end
    
    self:CreateDropdownMenu(LibDBIcon)
    self.Debug("DEBUG", "MinimapMenu initialized successfully")
end

function MinimapMenu:CreateDropdownMenu(LibDBIcon)
    local dropdownFrame = CreateFrame("Frame", "GrouperPlusDropdown", UIParent, "UIDropDownMenuTemplate")
    
    local function GetSettings()
        return addon.settings
    end
    
    local function SetDebugLevel(newLevel)
        local currentSettings = GetSettings()
        if not currentSettings then
            self.Debug("ERROR", "Settings not available yet")
            return
        end
        currentSettings.debugLevel = newLevel
        self.Debug("INFO", "Debug level changed to:", newLevel)
    end
    
    local function InitializeDropdown(dropdownSelf, level)
        if not level then return end
        
        self.Debug("DEBUG", "InitializeDropdown called with level:", level)
        
        local info = UIDropDownMenu_CreateInfo()
        
        if level == 1 then
            info.text = "GrouperPlus Options"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            info = UIDropDownMenu_CreateInfo()
            info.hasArrow = false
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            info = UIDropDownMenu_CreateInfo()
            info.text = "Debug Level"
            info.hasArrow = true
            info.notCheckable = true
            info.value = "debuglevel"
            info.menuList = "debuglevel"
            UIDropDownMenu_AddButton(info, level)
            
            info = UIDropDownMenu_CreateInfo()
            info.text = "Show Addon Users"
            info.notCheckable = true
            info.func = function()
                if addon.AddonUserList then
                    addon.AddonUserList:ToggleUserList()
                    self.Debug("INFO", "Toggled addon user list from minimap menu")
                else
                    self.Debug("WARN", "AddonUserList module not available")
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
            
            info = UIDropDownMenu_CreateInfo()
            info.hasArrow = false
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            
            info = UIDropDownMenu_CreateInfo()
            info.text = "Hide Minimap Button"
            info.notCheckable = true
            info.func = function()
                local currentSettings = GetSettings()
                if currentSettings and currentSettings.minimap then
                    currentSettings.minimap.hide = true
                    LibDBIcon:Hide("GrouperPlus")
                    self.Debug("INFO", "Minimap button hidden. Type /grouper minimap to show again.")
                end
            end
            UIDropDownMenu_AddButton(info, level)
            
        elseif level == 2 then
            self.Debug("DEBUG", "Level 2 menu, UIDROPDOWNMENU_MENU_VALUE:", UIDROPDOWNMENU_MENU_VALUE)
            if UIDROPDOWNMENU_MENU_VALUE == "debuglevel" then
                self.Debug("DEBUG", "Creating debug level submenu")
                for _, levelName in ipairs({"ERROR", "WARN", "INFO", "DEBUG", "TRACE"}) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = levelName
                    local currentSettings = GetSettings()
                    info.checked = (currentSettings and currentSettings.debugLevel == levelName)
                    info.func = function()
                        SetDebugLevel(levelName)
                        CloseDropDownMenus()
                    end
                    self.Debug("DEBUG", "Adding debug level option:", levelName, "checked:", info.checked)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end
    
    UIDropDownMenu_Initialize(dropdownFrame, InitializeDropdown, "MENU")
    addon.dropdownFrame = dropdownFrame
end