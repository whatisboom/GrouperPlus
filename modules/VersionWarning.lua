local addonName, addon = ...

local VersionWarning = {}
addon.VersionWarning = VersionWarning

local warningFrame = nil
local dismissedVersions = {}
local currentVersion = nil

-- Settings for version warnings
local WARNING_SETTINGS = {
    showPatchUpdates = false,      -- Only show major/minor updates by default
    autoCheckInterval = 300,       -- Check every 5 minutes
    dismissDuration = 86400,       -- Dismiss for 24 hours (in seconds)
}

function VersionWarning:Initialize()
    -- Get current addon version
    currentVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.6.0"
    addon.Debug(addon.LOG_LEVEL.DEBUG, "VersionWarning initialized with version:", currentVersion)
    
    -- Load dismissed versions from saved variables
    if addon.settings and addon.settings.dismissedVersions then
        dismissedVersions = addon.settings.dismissedVersions
    end
    
    -- Clean up old dismissals
    self:CleanupDismissedVersions()
end

function VersionWarning:CleanupDismissedVersions()
    local now = GetServerTime()
    local cleaned = 0
    
    for version, dismissTime in pairs(dismissedVersions) do
        if now - dismissTime > WARNING_SETTINGS.dismissDuration then
            dismissedVersions[version] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Cleaned up", cleaned, "old version dismissals")
        self:SaveDismissedVersions()
    end
end

function VersionWarning:SaveDismissedVersions()
    if addon.settings then
        addon.settings.dismissedVersions = dismissedVersions
    end
end

function VersionWarning:CheckForNewerVersions()
    if not addon.AddonComm or not addon.Utils then
        return
    end
    
    local connectedUsers = addon.AddonComm:GetConnectedUsers()
    local newerVersions = {}
    
    -- Check all connected users for newer versions
    local playerFullName = UnitName("player") .. "-" .. GetRealmName()
    for user, info in pairs(connectedUsers) do
        if info.addonVersion and user ~= playerFullName then
            if addon.Utils.IsVersionNewer(info.addonVersion, currentVersion) then
                -- Check if we should show this update
                local shouldShow = WARNING_SETTINGS.showPatchUpdates or 
                                  addon.Utils.IsSignificantUpdate(info.addonVersion, currentVersion)
                
                if shouldShow and not dismissedVersions[info.addonVersion] then
                    if not newerVersions[info.addonVersion] then
                        newerVersions[info.addonVersion] = {}
                    end
                    table.insert(newerVersions[info.addonVersion], user)
                end
            end
        end
    end
    
    -- Show warning for the highest version found
    if next(newerVersions) then
        local highestVersion = self:GetHighestVersion(newerVersions)
        if highestVersion then
            self:ShowVersionWarning(highestVersion, newerVersions[highestVersion])
        end
    end
end

function VersionWarning:GetHighestVersion(versions)
    local highest = nil
    
    for version, users in pairs(versions) do
        if not highest or addon.Utils.IsVersionNewer(version, highest) then
            highest = version
        end
    end
    
    return highest
end

-- Removed popup UI - now using chat messages for version warnings

function VersionWarning:ShowVersionWarning(newVersion, users)
    if not newVersion or not users then
        return
    end
    
    -- Store this version as the current warning to track dismissals
    local dismissKey = newVersion
    
    -- Build user list text
    local userCount = #users
    local userText = ""
    if userCount == 1 then
        userText = string.format("(used by %s)", users[1])
    elseif userCount <= 3 then
        userText = string.format("(used by %s)", table.concat(users, ", "))
    else
        userText = string.format("(used by %s and %d others)", users[1], userCount - 1)
    end
    
    -- Determine update significance
    local isSignificant = addon.Utils.IsSignificantUpdate(newVersion, currentVersion)
    local updateType = isSignificant and "significant update" or "update"
    
    -- Show single-line chat message
    print("|cFFFFD700[GrouperPlus]|r |cFFFF6B6BUpdate available:|r |cFFFFFFFF" .. currentVersion .. "|r -> |cFF00FF00" .. newVersion .. "|r " .. userText .. " |cFFFFD700/grouper versiondismiss|r to dismiss.")
    
    -- Store the version for potential dismissal
    self.lastWarnedVersion = newVersion
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Showing version warning for version", newVersion, "detected from", userCount, "users")
end

function VersionWarning:DismissWarning()
    if not self.lastWarnedVersion then
        print("|cFFFFD700[GrouperPlus]|r No version warning to dismiss.")
        return
    end
    
    local version = self.lastWarnedVersion
    dismissedVersions[version] = GetServerTime()
    self:SaveDismissedVersions()
    
    print("|cFFFFD700[GrouperPlus]|r Version " .. version .. " warning dismissed. You won't see this warning again for 24 hours.")
    addon.Debug(addon.LOG_LEVEL.INFO, "Version warning dismissed for version", version)
    
    self.lastWarnedVersion = nil
end

-- RemindLater function removed - no longer needed for chat-based warnings

-- Auto-initialize when other modules are available
local function InitializeWhenReady()
    if addon.AddonComm and addon.Utils and addon.settings then
        VersionWarning:Initialize()
        
        -- Start periodic version checking
        C_Timer.NewTicker(WARNING_SETTINGS.autoCheckInterval, function()
            VersionWarning:CheckForNewerVersions()
        end)
        
        addon.Debug(addon.LOG_LEVEL.DEBUG, "VersionWarning system started with auto-checking")
        return
    end
    
    -- Wait for dependencies
    C_Timer.After(2, InitializeWhenReady)
end

-- Initialize after a short delay
C_Timer.After(3, InitializeWhenReady)