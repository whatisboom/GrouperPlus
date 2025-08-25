local addonName, addon = ...
addon = addon or {}

local mainModule = {}
for k, v in pairs(addon.DebugMixin) do
    mainModule[k] = v
end
mainModule:InitDebug("Main")

local Debug = function(...) return mainModule.Debug(...) end

-- Print function for user messages
function addon:Print(...)
    local args = {...}
    local message = ""
    
    for i, arg in ipairs(args) do
        if i > 1 then
            message = message .. " "
        end
        message = message .. tostring(arg)
    end
    
    print("|cFFFFD700[GrouperPlus]|r " .. message)
end

-- Export to addon namespace for use in modules (for backward compatibility)
addon.Debug = Debug

local db
local settings

local minimapLDB = {
    type = "launcher",
    text = "GrouperPlus",
    icon = "Interface\\AddOns\\GrouperPlus\\textures\\icon",
    OnClick = function(self, button)
        if button == "LeftButton" then
            Debug(addon.LOG_LEVEL.INFO, "Minimap icon clicked with left button")
            if addon.ToggleMainFrame then
                addon:ToggleMainFrame()
            else
                Debug(addon.LOG_LEVEL.WARN, "MainFrame module not yet loaded")
            end
        elseif button == "RightButton" then
            if addon.dropdownFrame then
                ToggleDropDownMenu(1, nil, addon.dropdownFrame, self, 0, 0)
            else
                Debug(addon.LOG_LEVEL.WARN, "Dropdown menu not yet initialized")
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("GrouperPlus")
        tooltip:AddLine("|cFFFFFFFFLeft-click|r to toggle main frame", 1, 1, 1)
        tooltip:AddLine("|cFFFFFFFFRight-click|r for options", 1, 1, 1)
        tooltip:AddLine("|cFF00FF00Drag|r to move this button", 0, 1, 0)
    end,
}

local function InitializeMinimap()
    local LibDBIcon = addon.LibraryManager:GetLibrary("LibDBIcon-1.0")
    if LibDBIcon and not LibDBIcon:IsRegistered("GrouperPlus") and settings then
        LibDBIcon:Register("GrouperPlus", minimapLDB, settings.minimap)
        Debug(addon.LOG_LEVEL.INFO, "Minimap icon registered successfully")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            -- Initialize library manager first
            addon.LibraryManager:Initialize()
            
            -- Validate critical library dependencies
            local dependenciesOk, missingLibs = addon.LibraryManager:CheckDependencies()
            if not dependenciesOk then
                Debug(addon.LOG_LEVEL.ERROR, "Critical libraries missing:", missingLibs)
                addon:Print("ERROR: Critical libraries missing -", missingLibs)
                return
            end
            Debug(addon.LOG_LEVEL.DEBUG, "All required libraries loaded successfully")
            
            -- Initialize new unified state management system
            -- Note: WoWAPIWrapper doesn't need initialization - it's just a collection of wrapper functions
            
            -- Initialize state management modules with improved error handling
            local initSuccess = true
            
            if addon.MessageProtocol then
                local success = addon.MessageProtocol:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "MessageProtocol initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "MessageProtocol initialization failed")
                    initSuccess = false
                end
            else
                Debug(addon.LOG_LEVEL.ERROR, "MessageProtocol module not loaded")
                initSuccess = false
            end
            
            if addon.MemberStateManager then
                local success = addon.MemberStateManager:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "MemberStateManager initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "MemberStateManager initialization failed")
                end
            end
            
            if addon.GroupStateManager then
                local success = addon.GroupStateManager:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "GroupStateManager initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "GroupStateManager initialization failed")
                end
            end
            
            if addon.SessionStateManager then
                local success = addon.SessionStateManager:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "SessionStateManager initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "SessionStateManager initialization failed")
                end
            end
            
            if addon.StateSync then
                local success = addon.StateSync:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "StateSync initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "StateSync initialization failed")
                    initSuccess = false
                end
            else
                Debug(addon.LOG_LEVEL.ERROR, "StateSync module not loaded")
                initSuccess = false
            end
            
            
            if not initSuccess then
                Debug(addon.LOG_LEVEL.WARN, "Some core modules failed to initialize - addon may have reduced functionality")
            end
            
            -- Initialize AddonComm after libraries are loaded (legacy support)
            if addon.AddonComm then
                local commInitialized = addon.AddonComm:Initialize()
                if commInitialized then
                    Debug(addon.LOG_LEVEL.INFO, "AddonComm initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "Failed to initialize AddonComm")
                end
            else
                Debug(addon.LOG_LEVEL.ERROR, "AddonComm module not loaded")
            end
            
            local AceDB = addon.LibraryManager:GetLibrary("AceDB-3.0")
            if not AceDB then
                Debug(addon.LOG_LEVEL.ERROR, "AceDB-3.0 not available")
                return
            end
            
            GrouperDB = GrouperDB or {}
            db = AceDB:New("GrouperDB", addon.defaults, true)
            settings = db.profile
            
            -- Export to addon namespace
            addon.db = db
            addon.settings = settings
            addon.Debug = Debug
            
            Debug(addon.LOG_LEVEL.INFO, "GrouperPlus addon loaded successfully!")
            Debug(addon.LOG_LEVEL.DEBUG, "Settings initialized with debugLevel:", settings.debugLevel)
            InitializeMinimap()
            
            -- Initialize SessionNotificationUI (needs to be done after settings are available)
            if addon.SessionNotificationUI then
                local success = addon.SessionNotificationUI:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "SessionNotificationUI initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "SessionNotificationUI initialization failed")
                end
            end
            
            -- Initialize SessionNotificationManager (needs to be done after settings are available)
            if addon.SessionNotificationManager then
                local success = addon.SessionNotificationManager:OnInitialize()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "SessionNotificationManager initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "SessionNotificationManager initialization failed")
                end
            end
            
            -- Register modules with ModuleManager
            addon.ModuleManager:RegisterModule("SessionManager", addon.SessionManager, {})
            addon.ModuleManager:RegisterModule("MinimapMenu", addon.MinimapMenu, {})
            addon.ModuleManager:RegisterModule("OptionsPanel", addon.OptionsPanel, {})
            
            -- Note: UI modules (GroupFrameUI, MemberRowUI) will be initialized by MainFrame when it's first shown
            
            -- Initialize all modules
            C_Timer.After(1, function()
                local success = addon.ModuleManager:InitializeAll()
                if success then
                    Debug(addon.LOG_LEVEL.INFO, "All modules initialized successfully")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "Module initialization failed")
                end
            end)
            
            -- Initialize legacy modules that haven't been refactored yet
            if addon.Keystone then
                C_Timer.After(2, function()
                    addon.Keystone:Initialize()
                end)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        Debug(addon.LOG_LEVEL.INFO, "Welcome to GrouperPlus!")
    end
end)

SLASH_GROUPER1 = "/grouper"
SlashCmdList["GROUPER"] = function(msg)
    local command = msg:lower()
    
    -- Primary user commands
    if command == "form" or command == "autoform" or command == "auto" then
        if addon.AutoFormGroups then
            Debug(addon.LOG_LEVEL.INFO, "SLASH COMMAND - Triggering auto-formation")
            addon:AutoFormGroups()
        else
            Debug(addon.LOG_LEVEL.WARN, "AutoFormGroups function not yet loaded")
        end
    elseif command == "config" or command == "options" or command == "settings" then
        if addon.OptionsPanel and addon.OptionsPanel.OpenOptionsPanel then
            addon.OptionsPanel:OpenOptionsPanel()
            Debug(addon.LOG_LEVEL.INFO, "Options panel opened")
        else
            Debug(addon.LOG_LEVEL.WARN, "Options panel not available")
        end
    elseif command == "toggle" then
        if addon.ToggleMainFrame then
            addon:ToggleMainFrame()
            Debug(addon.LOG_LEVEL.INFO, "Main frame toggled via slash command")
        else
            Debug(addon.LOG_LEVEL.WARN, "MainFrame module not yet loaded")
        end
    elseif command == "minimap" then
        local LibDBIcon = addon.LibraryManager:GetLibrary("LibDBIcon-1.0")
        if LibDBIcon then
            if settings.minimap.hide then
                settings.minimap.hide = false
                LibDBIcon:Show("GrouperPlus")
                Debug(addon.LOG_LEVEL.INFO, "Minimap button shown")
            else
                settings.minimap.hide = true
                LibDBIcon:Hide("GrouperPlus")
                Debug(addon.LOG_LEVEL.INFO, "Minimap button hidden")
            end
        end
    elseif command == "test-recruitment" then
        Debug(addon.LOG_LEVEL.INFO, "SLASH COMMAND - Testing recruitment system")
        if addon.SessionNotificationManager then
            -- Create a test session
            if addon.SessionStateManager then
                local success, sessionId = addon.SessionStateManager:CreateSession({})
                if success then
                    print("|cFF00FF00GrouperPlus:|r Started test recruitment for session " .. sessionId)
                else
                    print("|cFFFF0000GrouperPlus:|r Failed to start test session")
                end
            else
                print("|cFFFF0000GrouperPlus:|r SessionStateManager not available")
            end
        else
            print("|cFFFF0000GrouperPlus:|r SessionNotificationManager not available")
        end
    elseif command == "help" or command == "" then
        addon:ShowUserHelp()
    
    -- Legacy/compatibility commands (hidden from main help)
    elseif command == "minimap" or command == "show" then
        settings.minimap.hide = false
        local LibDBIcon = addon.LibraryManager:GetLibrary("LibDBIcon-1.0")
        if LibDBIcon then
            LibDBIcon:Show("GrouperPlus")
            Debug(addon.LOG_LEVEL.INFO, "Minimap button shown")
        end
    elseif command == "hide" then
        settings.minimap.hide = true
        local LibDBIcon = addon.LibraryManager:GetLibrary("LibDBIcon-1.0")
        if LibDBIcon then
            LibDBIcon:Hide("GrouperPlus")
            Debug(addon.LOG_LEVEL.INFO, "Minimap button hidden")
        end
    elseif command == "main" or command == "frame" or command == "gui" then
        if addon.ShowMainFrame then
            addon:ShowMainFrame()
            Debug(addon.LOG_LEVEL.INFO, "Main frame shown via slash command")
        else
            Debug(addon.LOG_LEVEL.WARN, "MainFrame module not yet loaded")
        end
    elseif command == "test" or command == "raiderio" then
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:TestPlayer()
            Debug(addon.LOG_LEVEL.INFO, "RaiderIO test completed - check debug output")
        else
            Debug(addon.LOG_LEVEL.WARN, "RaiderIO integration module not yet loaded")
        end
    elseif command == "button" or command == "check" then
        local button = _G["GrouperPlusAutoFormButton"]
        if button then
            Debug(addon.LOG_LEVEL.DEBUG, "Button found! Enabled:", button:IsEnabled(), "Shown:", button:IsShown(), "Visible:", button:IsVisible())
            Debug(addon.LOG_LEVEL.DEBUG, "Manually triggering button click...")
            button:Click()
        else
            Debug(addon.LOG_LEVEL.WARN, "Button not found! Frame might not be created yet.")
        end
    elseif command == "session" or command == "sess" then
        if addon.SessionManager then
            local sessionInfo = addon.SessionManager:GetSessionInfo()
            if sessionInfo then
                Debug(addon.LOG_LEVEL.INFO, "Session ID:", sessionInfo.sessionId)
                Debug(addon.LOG_LEVEL.INFO, "Session Owner:", sessionInfo.owner)
                Debug(addon.LOG_LEVEL.INFO, "Is Owner:", sessionInfo.isOwner)
                Debug(addon.LOG_LEVEL.INFO, "Is Finalized:", sessionInfo.isFinalized)
                Debug(addon.LOG_LEVEL.INFO, "Participants:", sessionInfo.participantCount)
            else
                Debug(addon.LOG_LEVEL.INFO, "No active session")
            end
        else
            Debug(addon.LOG_LEVEL.WARN, "SessionManager not yet loaded")
        end
    elseif command == "refresh" or command == "perms" then
        if addon.UpdateEditPermissions then
            addon:UpdateEditPermissions()
            Debug(addon.LOG_LEVEL.INFO, "Manually refreshed edit permissions")
        else
            Debug(addon.LOG_LEVEL.WARN, "UpdateEditPermissions function not available")
        end
    
    -- Developer/debug commands
    elseif command == "dev" or command == "debug" or command == "developer" then
        addon:ShowDeveloperHelp()
    elseif command == "test-unified" or command == "test-state" then
        addon:TestUnifiedStateSystem()
    elseif command == "test-keystone" or command == "test-keystones" then
        addon:TestKeystoneSystem()
    elseif command == "comm" or command == "communication" then
        if addon.AddonComm then
            local connectedUsers = addon.AddonComm:GetConnectedUsers()
            local count = 0
            for user, info in pairs(connectedUsers) do
                count = count + 1
                Debug(addon.LOG_LEVEL.INFO, "Connected user:", user, "version:", info.version)
            end
            if count == 0 then
                Debug(addon.LOG_LEVEL.INFO, "No other GrouperPlus users detected")
            else
                Debug(addon.LOG_LEVEL.INFO, "Found", count, "connected users")
            end
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "version" or command == "broadcast" then
        if addon.AddonComm then
            addon.AddonComm:BroadcastVersionCheck()
            Debug(addon.LOG_LEVEL.INFO, "Version check broadcast sent to guild")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "share" then
        if addon.RaiderIOIntegration then
            addon.RaiderIOIntegration:ShareGuildMemberData()
            Debug(addon.LOG_LEVEL.INFO, "Attempted to share RaiderIO data for guild members")
        else
            Debug(addon.LOG_LEVEL.WARN, "RaiderIO integration not loaded")
        end
    elseif command == "role" then
        if addon.AddonComm then
            addon.AddonComm:SharePlayerRole(true)
            Debug(addon.LOG_LEVEL.INFO, "Forced role share sent to guild")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "checkrole" then
        Debug(addon.LOG_LEVEL.INFO, "Role monitoring is automatic in new AceComm implementation")
    elseif command == "debugspec" or command == "spec" then
        local playerName = UnitName("player")
        local currentSpec = GetSpecialization()
        local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "Unknown"
        local role = currentSpec and GetSpecializationRole(currentSpec) or "Unknown"
        
        Debug(addon.LOG_LEVEL.DEBUG, "Player Debug Info:")
        Debug(addon.LOG_LEVEL.DEBUG, "  Player Name:", (playerName or "nil"))
        Debug(addon.LOG_LEVEL.DEBUG, "  Spec ID:", (currentSpec or "nil"))
        Debug(addon.LOG_LEVEL.DEBUG, "  Spec Name:", (specName or "nil"))
        Debug(addon.LOG_LEVEL.DEBUG, "  Role:", (role or "nil"))
        
        if addon.AutoFormation then
            local detectedRole = addon.AutoFormation:GetPlayerRole("player")
            Debug(addon.LOG_LEVEL.DEBUG, "  AutoFormation Role:", (detectedRole or "nil"))
        end
    elseif command == "refresh" or command == "update" then
        if addon.UpdatePlayerRoleInUI then
            addon:UpdatePlayerRoleInUI()
            Debug(addon.LOG_LEVEL.INFO, "Forced UI refresh")
        else
            Debug(addon.LOG_LEVEL.WARN, "UI refresh function not available")
        end
    elseif command == "versioncheck" or command == "checkversion" then
        if addon.VersionWarning then
            addon.VersionWarning:CheckForNewerVersions()
            Debug(addon.LOG_LEVEL.INFO, "Manual version check triggered")
        else
            Debug(addon.LOG_LEVEL.WARN, "VersionWarning module not loaded")
        end
    elseif command == "versiontest" then
        if addon.VersionWarning then
            -- Test with fake newer version
            addon.VersionWarning:ShowVersionWarning("0.7.0", {"TestUser"})
            Debug(addon.LOG_LEVEL.INFO, "Test version warning shown")
        else
            Debug(addon.LOG_LEVEL.WARN, "VersionWarning module not loaded")
        end
    elseif command == "versiondismiss" then
        if addon.VersionWarning then
            addon.VersionWarning:DismissWarning()
            Debug(addon.LOG_LEVEL.INFO, "Version warning dismissed")
        else
            Debug(addon.LOG_LEVEL.WARN, "VersionWarning module not loaded")
        end
    elseif command == "keystone" or command == "key" then
        if addon.Keystone then
            local info = addon.Keystone:GetKeystoneInfo()
            local keystoneString = addon.Keystone:GetKeystoneString()
            Debug(addon.LOG_LEVEL.INFO, "Current keystone:", keystoneString)
            
            local received = addon.Keystone:GetReceivedKeystones()
            local count = 0
            for player, data in pairs(received) do
                count = count + 1
                local playerKeystone = "No Keystone"
                if data.mapID and data.level then
                    playerKeystone = string.format("%s +%d", data.dungeonName or "Unknown", data.level)
                end
                Debug(addon.LOG_LEVEL.INFO, "  " .. player .. ":", playerKeystone)
            end
            
            if count == 0 then
                Debug(addon.LOG_LEVEL.INFO, "No keystone data received from other players")
            end
            
            addon.Keystone:ForceUpdate()
        else
            Debug(addon.LOG_LEVEL.WARN, "Keystone module not loaded")
        end
    elseif command == "clear" or command == "cleargroups" then
        if addon.ClearAllGroups then
            Debug(addon.LOG_LEVEL.INFO, "Clearing all groups via slash command")
            addon:ClearAllGroups()
        else
            Debug(addon.LOG_LEVEL.WARN, "ClearAllGroups function not available")
        end
    elseif command == "channels" or command == "commstatus" then
        if addon.AddonComm then
            local enabled = addon.AddonComm:GetEnabledChannels()
            Debug(addon.LOG_LEVEL.INFO, "Enabled channels:", table.concat(enabled, ", "))
            
            for _, channel in ipairs(enabled) do
                local available = addon.AddonComm:IsChannelAvailable(channel)
                Debug(addon.LOG_LEVEL.INFO, "Channel", channel .. ":", available and "AVAILABLE" or "NOT AVAILABLE")
            end
            
            Debug(addon.LOG_LEVEL.INFO, "Communication enabled:", addon.settings.communication.enabled and "YES" or "NO")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not loaded")
        end
    elseif command == "testsize" or command == "size" then
        if addon.GetCurrentGroupFormation and addon.AddonComm then
            local currentGroups = addon:GetCurrentGroupFormation()
            if currentGroups and #currentGroups > 0 then
                Debug(addon.LOG_LEVEL.INFO, "Testing AceComm sync for current group formation with", #currentGroups, "groups")
                addon.AddonComm:SyncGroupFormation(currentGroups)
            else
                Debug(addon.LOG_LEVEL.INFO, "No groups found to test sync")
            end
        else
            Debug(addon.LOG_LEVEL.WARN, "Group formation or communication modules not available")
        end
    elseif command == "roster" then
        if addon.AddonComm then
            addon.AddonComm:ShareMemberRoster()
            Debug(addon.LOG_LEVEL.INFO, "Member roster shared to all connected users")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not available")
        end
    elseif command == "rosterreq" or command == "requestroster" then
        if addon.AddonComm then
            addon.AddonComm:RequestMemberRoster()
            Debug(addon.LOG_LEVEL.INFO, "Requested member rosters from connected users")
        else
            Debug(addon.LOG_LEVEL.WARN, "Communication module not available")
        end
    elseif command == "rosterstatus" then
        if addon.MemberManager then
            local members = addon.MemberManager:UpdateMemberList()
            local sharedCount = 0
            local totalCount = #members
            
            for _, member in ipairs(members) do
                if member.source and string.find(member.source, "SHARED_") then
                    sharedCount = sharedCount + 1
                end
            end
            
            Debug(addon.LOG_LEVEL.INFO, "Member roster status:")
            Debug(addon.LOG_LEVEL.INFO, "  Total members:", totalCount)
            Debug(addon.LOG_LEVEL.INFO, "  Shared members:", sharedCount)
            Debug(addon.LOG_LEVEL.INFO, "  Local members:", totalCount - sharedCount)
        else
            Debug(addon.LOG_LEVEL.WARN, "MemberManager not available")
        end
    else
        addon:ShowUserHelp()
    end
end

function addon:ShowUserHelp()
    Debug(addon.LOG_LEVEL.INFO, "GrouperPlus Commands:")
    Debug(addon.LOG_LEVEL.INFO, "/grouper form - Auto-form balanced groups with utility distribution")
    Debug(addon.LOG_LEVEL.INFO, "/grouper toggle - Show/hide main window")
    Debug(addon.LOG_LEVEL.INFO, "/grouper config - Open addon settings")
    Debug(addon.LOG_LEVEL.INFO, "/grouper minimap - Show/hide minimap icon")
    Debug(addon.LOG_LEVEL.INFO, "/grouper help - Show this help")
    Debug(addon.LOG_LEVEL.INFO, "/grouper dev - Show developer commands")
    Debug(addon.LOG_LEVEL.INFO, "")
    Debug(addon.LOG_LEVEL.INFO, "Also available: /grouperopt - Quick access to options")
end

-- Addon cleanup function for proper shutdown
function addon:OnDisable()
    Debug(addon.LOG_LEVEL.INFO, "Shutting down GrouperPlus addon")
    
    -- Disable state management modules
    if addon.StateSync and addon.StateSync.OnDisable then
        addon.StateSync:OnDisable()
    end
    
    if addon.SessionStateManager and addon.SessionStateManager.OnDisable then
        addon.SessionStateManager:OnDisable()
    end
    
    if addon.SessionNotificationManager and addon.SessionNotificationManager.OnDisable then
        addon.SessionNotificationManager:OnDisable()
    end
    
    if addon.SessionNotificationUI and addon.SessionNotificationUI.OnDisable then
        addon.SessionNotificationUI:OnDisable()
    end
    
    Debug(addon.LOG_LEVEL.INFO, "GrouperPlus shutdown complete")
end

function addon:ShowDeveloperHelp()
    Debug(addon.LOG_LEVEL.INFO, "GrouperPlus Developer Commands:")
    Debug(addon.LOG_LEVEL.INFO, "/grouper test-unified - Test all state management systems")
    Debug(addon.LOG_LEVEL.INFO, "/grouper test-state - Alias for test-unified")
    Debug(addon.LOG_LEVEL.INFO, "/grouper test-keystone - Test keystone assignment system")
    Debug(addon.LOG_LEVEL.INFO, "/grouper test-recruitment - Test session recruitment system")
    Debug(addon.LOG_LEVEL.INFO, "/grouper comm - Check connected users")
    Debug(addon.LOG_LEVEL.INFO, "/grouper broadcast - Send version check")
    Debug(addon.LOG_LEVEL.INFO, "/grouper share - Share RaiderIO data")
    Debug(addon.LOG_LEVEL.INFO, "/grouper role - Force share current role")
    Debug(addon.LOG_LEVEL.INFO, "/grouper spec - Debug player specialization info")
    Debug(addon.LOG_LEVEL.INFO, "/grouper refresh - Force UI refresh")
    Debug(addon.LOG_LEVEL.INFO, "/grouper versioncheck - Check for newer versions")
    Debug(addon.LOG_LEVEL.INFO, "/grouper versiontest - Test version warning display")
    Debug(addon.LOG_LEVEL.INFO, "/grouper versiondismiss - Dismiss current version warning")
    Debug(addon.LOG_LEVEL.INFO, "/grouper keystone - Show current keystone and received keystones")
    Debug(addon.LOG_LEVEL.INFO, "/grouper channels - Show communication channel status")
    Debug(addon.LOG_LEVEL.INFO, "/grouper testsize - Test group formation sync via AceComm")
    Debug(addon.LOG_LEVEL.INFO, "/grouper roster - Share member roster with connected users")
    Debug(addon.LOG_LEVEL.INFO, "/grouper rosterreq - Request member rosters from others")
    Debug(addon.LOG_LEVEL.INFO, "/grouper rosterstatus - Show member roster statistics")
    Debug(addon.LOG_LEVEL.INFO, "/grouper show - Show minimap button")
    Debug(addon.LOG_LEVEL.INFO, "/grouper hide - Hide minimap button")
    Debug(addon.LOG_LEVEL.INFO, "/grouper test - Test RaiderIO integration")
    Debug(addon.LOG_LEVEL.INFO, "/grouper session - Show session info")
    Debug(addon.LOG_LEVEL.INFO, "/grouper perms - Refresh edit permissions")
    Debug(addon.LOG_LEVEL.INFO, "/grouper version - Send version check")
    Debug(addon.LOG_LEVEL.INFO, "/grouper clear - Clear all groups")
    Debug(addon.LOG_LEVEL.INFO, "")
    Debug(addon.LOG_LEVEL.INFO, "Legacy commands available: /grouperopt (options)")
end

function addon:TestUnifiedStateSystem()
    Debug(addon.LOG_LEVEL.INFO, "=== TESTING UNIFIED STATE MANAGEMENT SYSTEM ===")
    
    -- Test 0: Library Dependencies
    Debug(addon.LOG_LEVEL.INFO, "0. Testing library dependencies...")
    if addon.LibraryManager then
        local dependenciesOk, missingLibs = addon.LibraryManager:CheckDependencies()
        if dependenciesOk then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ All required libraries loaded")
            local loadedLibs = addon.LibraryManager:GetLoadedLibraries()
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Loaded libraries:", table.concat(loadedLibs, ", "))
        else
            Debug(addon.LOG_LEVEL.ERROR, "   ✗ Missing libraries:", missingLibs)
        end
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ LibraryManager not available")
    end
    
    -- Test 1: WoW API Wrapper
    Debug(addon.LOG_LEVEL.INFO, "1. Testing WoWAPIWrapper...")
    if addon.WoWAPIWrapper then
        local playerInfo = addon.WoWAPIWrapper:GetPlayerInfo()
        if playerInfo then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Player info: " .. playerInfo.fullName .. " (" .. playerInfo.class .. ")")
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Player role: " .. addon.WoWAPIWrapper:GetPlayerRole())
        else
            Debug(addon.LOG_LEVEL.ERROR, "   ✗ Failed to get player info")
        end
        
        local channels = addon.WoWAPIWrapper:GetEnabledChannels()
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Available channels: " .. table.concat(channels, ", "))
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ WoWAPIWrapper not available")
    end
    
    -- Test 2: Member State Manager
    Debug(addon.LOG_LEVEL.INFO, "2. Testing MemberStateManager...")
    if addon.MemberStateManager then
        addon.MemberStateManager:RefreshFromSources()
        local members = addon.MemberStateManager:GetAllMembers()
        local availableMembers = addon.MemberStateManager:GetAvailableMembers()
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Total members: " .. #members)
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Available members: " .. #availableMembers)
        
        -- Test adding a dummy member
        local testMember = {
            name = "TestPlayer-TestRealm",
            class = "WARRIOR",
            level = 80,
            role = "TANK",
            source = "MANUAL"
        }
        if addon.MemberStateManager:AddMember(testMember) then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Successfully added test member")
            addon.MemberStateManager:RemoveMember("TestPlayer-TestRealm")
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Successfully removed test member")
        else
            Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to add test member")
        end
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ MemberStateManager not available")
    end
    
    -- Test 3: Group State Manager
    Debug(addon.LOG_LEVEL.INFO, "3. Testing GroupStateManager...")
    if addon.GroupStateManager then
        local testGroup = addon.GroupStateManager:CreateGroup({name = "Test Group"})
        if testGroup then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Created test group: " .. testGroup.id)
            
            local playerInfo = addon.WoWAPIWrapper and addon.WoWAPIWrapper:GetPlayerInfo()
            if playerInfo then
                if addon.GroupStateManager:AddMemberToGroup(playerInfo.fullName, testGroup.id) then
                    Debug(addon.LOG_LEVEL.INFO, "   ✓ Added player to test group")
                    
                    local composition = addon.GroupStateManager:GetGroupComposition(testGroup.id)
                    if composition then
                        Debug(addon.LOG_LEVEL.INFO, "   ✓ Group composition: " .. composition.totalMembers .. " members")
                    end
                    
                    addon.GroupStateManager:RemoveMemberFromGroup(playerInfo.fullName, testGroup.id)
                    Debug(addon.LOG_LEVEL.INFO, "   ✓ Removed player from test group")
                else
                    Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to add player to test group")
                end
            end
            
            addon.GroupStateManager:RemoveGroup(testGroup.id)
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Removed test group")
        else
            Debug(addon.LOG_LEVEL.ERROR, "   ✗ Failed to create test group")
        end
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ GroupStateManager not available")
    end
    
    -- Test 4: Session State Manager
    Debug(addon.LOG_LEVEL.INFO, "4. Testing SessionStateManager...")
    if addon.SessionStateManager then
        local success, sessionId = addon.SessionStateManager:CreateSession({locked = false})
        if success then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Created test session: " .. sessionId)
            
            local sessionInfo = addon.SessionStateManager:GetSessionInfo()
            if sessionInfo then
                Debug(addon.LOG_LEVEL.INFO, "   ✓ Session owner: " .. sessionInfo.ownerId)
                Debug(addon.LOG_LEVEL.INFO, "   ✓ Can edit members: " .. tostring(addon.SessionStateManager:CanEditMembers()))
                Debug(addon.LOG_LEVEL.INFO, "   ✓ Can edit groups: " .. tostring(addon.SessionStateManager:CanEditGroups()))
            end
            
            addon.SessionStateManager:EndSession()
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Ended test session")
        else
            Debug(addon.LOG_LEVEL.ERROR, "   ✗ Failed to create test session: " .. (sessionId or "unknown error"))
        end
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ SessionStateManager not available")
    end
    
    -- Test 5: Message Protocol
    Debug(addon.LOG_LEVEL.INFO, "5. Testing MessageProtocol...")
    if addon.MessageProtocol then
        local testMessage = addon.MessageProtocol:CreatePing()
        if testMessage then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Created test message: " .. testMessage.type)
            
            local serialized = addon.MessageProtocol:SerializeMessage(testMessage)
            if serialized then
                Debug(addon.LOG_LEVEL.INFO, "   ✓ Serialized message (" .. string.len(serialized) .. " bytes)")
                
                local deserialized = addon.MessageProtocol:DeserializeMessage(serialized)
                if deserialized and deserialized.type == testMessage.type then
                    Debug(addon.LOG_LEVEL.INFO, "   ✓ Successfully deserialized message")
                else
                    Debug(addon.LOG_LEVEL.ERROR, "   ✗ Failed to deserialize message")
                end
            else
                Debug(addon.LOG_LEVEL.ERROR, "   ✗ Failed to serialize message")
            end
        else
            Debug(addon.LOG_LEVEL.ERROR, "   ✗ Failed to create test message")
        end
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ MessageProtocol not available")
    end
    
    -- Test 6: State Sync
    Debug(addon.LOG_LEVEL.INFO, "6. Testing StateSync...")
    if addon.StateSync then
        Debug(addon.LOG_LEVEL.INFO, "   ✓ StateSync initialized: " .. tostring(addon.StateSync.syncState and addon.StateSync.syncState.isInitialized))
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Sync in progress: " .. tostring(addon.StateSync:IsSyncInProgress()))
        
        local history = addon.StateSync:GetSyncHistory()
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Sync history entries: " .. #history)
        
        -- Test ping
        if addon.StateSync:SendPing() then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Successfully sent test ping")
        else
            Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to send test ping (may be no available channels)")
        end
    else
        Debug(addon.LOG_LEVEL.ERROR, "   ✗ StateSync not available")
    end
    
    -- Test 7: Integration Test
    Debug(addon.LOG_LEVEL.INFO, "7. Testing Full Integration...")
    if addon.MemberStateManager and addon.GroupStateManager and addon.SessionStateManager then
        Debug(addon.LOG_LEVEL.INFO, "   ✓ All state managers available")
        
        -- Test session permissions affecting group edits
        local canEditBefore = addon.SessionStateManager:CanEditGroups()
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Can edit groups (no session): " .. tostring(canEditBefore))
        
        -- Create locked session and test permissions
        local success, sessionId = addon.SessionStateManager:CreateSession({locked = true})
        if success then
            addon.SessionStateManager:LockSession()
            local canEditAfter = addon.SessionStateManager:CanEditGroups()
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Can edit groups (locked session): " .. tostring(canEditAfter))
            addon.SessionStateManager:EndSession()
        end
    else
        Debug(addon.LOG_LEVEL.WARN, "   ⚠ Some state managers not available for integration test")
    end
    
    Debug(addon.LOG_LEVEL.INFO, "=== UNIFIED STATE SYSTEM TEST COMPLETE ===")
    Debug(addon.LOG_LEVEL.INFO, "Use '/grouper test-unified' to run this test again")
end

function addon:TestKeystoneSystem()
    Debug(addon.LOG_LEVEL.INFO, "=== KEYSTONE ASSIGNMENT SYSTEM TEST ===")
    
    -- Test 1: Check keystone detection
    Debug(addon.LOG_LEVEL.INFO, "1. Testing keystone detection...")
    if addon.Keystone then
        local keystoneInfo = addon.Keystone:GetKeystoneInfo()
        if keystoneInfo and keystoneInfo.hasKeystone then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Player has keystone:", keystoneInfo.dungeonName, "+", keystoneInfo.level)
        else
            Debug(addon.LOG_LEVEL.INFO, "   ℹ Player has no keystone (this is normal)")
        end
        
        local receivedKeystones = addon.Keystone:GetReceivedKeystones()
        local count = 0
        for player, keystone in pairs(receivedKeystones) do
            count = count + 1
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Received keystone from", player, ":", keystone.dungeonName, "+", keystone.level)
        end
        if count == 0 then
            Debug(addon.LOG_LEVEL.INFO, "   ℹ No keystones received from other players")
        end
    else
        Debug(addon.LOG_LEVEL.WARN, "   ⚠ Keystone module not available")
    end
    
    -- Test 2: Test group state manager keystone functions
    Debug(addon.LOG_LEVEL.INFO, "2. Testing group keystone management...")
    if addon.GroupStateManager then
        local testGroup = addon.GroupStateManager:CreateGroup({ name = "Test Group" })
        if testGroup then
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Created test group:", testGroup.id)
            
            local testKeystoneData = {
                mapID = 501,
                level = 10,
                dungeonName = "The Stonevault",
                assignedPlayer = "TestPlayer"
            }
            
            local success = addon.GroupStateManager:AssignKeystoneToGroup(testGroup.id, testKeystoneData)
            if success then
                Debug(addon.LOG_LEVEL.INFO, "   ✓ Successfully assigned test keystone")
                
                local assignedKeystone = addon.GroupStateManager:GetGroupKeystone(testGroup.id)
                if assignedKeystone and assignedKeystone.hasKeystone then
                    Debug(addon.LOG_LEVEL.INFO, "   ✓ Retrieved assigned keystone:", assignedKeystone.dungeonName, "+", assignedKeystone.level)
                else
                    Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to retrieve assigned keystone")
                end
                
                local removeSuccess = addon.GroupStateManager:RemoveKeystoneFromGroup(testGroup.id)
                if removeSuccess then
                    Debug(addon.LOG_LEVEL.INFO, "   ✓ Successfully removed keystone")
                else
                    Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to remove keystone")
                end
            else
                Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to assign test keystone")
            end
            
            addon.GroupStateManager:RemoveGroup(testGroup.id)
            Debug(addon.LOG_LEVEL.INFO, "   ✓ Cleaned up test group")
        else
            Debug(addon.LOG_LEVEL.WARN, "   ⚠ Failed to create test group")
        end
    else
        Debug(addon.LOG_LEVEL.WARN, "   ⚠ GroupStateManager not available")
    end
    
    -- Test 3: Test auto-formation with keystones
    Debug(addon.LOG_LEVEL.INFO, "3. Testing auto-formation keystone collection...")
    if addon.AutoFormation then
        local testMembers = {
            { name = "TestPlayer1", class = "PALADIN", score = 2500 },
            { name = "TestPlayer2", class = "DRUID", score = 2400 },
            { name = "TestPlayer3", class = "MAGE", score = 2300 }
        }
        
        local keystones, playerKeystones = addon.AutoFormation:CollectAvailableKeystones(testMembers)
        Debug(addon.LOG_LEVEL.INFO, "   ✓ Keystone collection completed -", #keystones, "keystones found")
        
        for i, keystone in ipairs(keystones) do
            Debug(addon.LOG_LEVEL.INFO, "     -", keystone.dungeonName, "+", keystone.level, "from", keystone.assignedPlayer)
        end
    else
        Debug(addon.LOG_LEVEL.WARN, "   ⚠ AutoFormation module not available")
    end
    
    Debug(addon.LOG_LEVEL.INFO, "=== KEYSTONE SYSTEM TEST COMPLETE ===")
    Debug(addon.LOG_LEVEL.INFO, "Use '/grouper test-keystone' to run this test again")
end