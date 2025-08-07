local addonName, addon = ...

local AddonComm = {}
addon.AddonComm = AddonComm

-- Simple serialization functions for addon communication
function addon:Serialize(data)
    if type(data) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(data) do
            if not first then
                result = result .. ","
            end
            first = false
            
            local key = type(k) == "string" and ("[" .. string.format("%q", k) .. "]") or ("[" .. tostring(k) .. "]")
            local value = self:Serialize(v)
            result = result .. key .. "=" .. value
        end
        result = result .. "}"
        return result
    elseif type(data) == "string" then
        return string.format("%q", data)
    else
        return tostring(data)
    end
end

function addon:Deserialize(str)
    if not str or str == "" then
        return false, nil
    end
    
    local success, result = pcall(loadstring("return " .. str))
    return success, result
end

local COMM_PREFIX = "GrouperPlus"
local COMM_VERSION = "1.0"
local MESSAGE_TYPES = {
    VERSION_CHECK = "VERSION_CHECK",
    VERSION_RESPONSE = "VERSION_RESPONSE",
    GROUP_SYNC = "GROUP_SYNC",
    PLAYER_DATA = "PLAYER_DATA",
    RAIDERIO_DATA = "RAIDERIO_DATA",
    FORMATION_REQUEST = "FORMATION_REQUEST",
    FORMATION_RESPONSE = "FORMATION_RESPONSE",
    KEYSTONE_DATA = "KEYSTONE_DATA",
    SESSION_CREATE = "SESSION_CREATE",
    SESSION_JOIN = "SESSION_JOIN",
    SESSION_LEAVE = "SESSION_LEAVE",
    SESSION_WHITELIST = "SESSION_WHITELIST",
    SESSION_FINALIZE = "SESSION_FINALIZE",
    SESSION_STATE = "SESSION_STATE",
    SESSION_END = "SESSION_END"
}

local connectedUsers = {}
local messageQueue = {}
local lastSyncTime = {}
local playerRole = nil
local lastKnownSpec = nil
local messageHandlers = {}

local function EncodeMessage(messageType, data)
    local message = {
        version = COMM_VERSION,
        type = messageType,
        timestamp = GetServerTime(),
        sender = UnitName("player"),
        data = data or {}
    }
    
    local serialized = addon:Serialize(message)
    
    -- Use compression if enabled and LibCompress is available
    if addon.settings and addon.settings.communication and addon.settings.communication.compression then
        local LibCompress = LibStub("LibCompress", true)
        if LibCompress then
            local compressed, method = LibCompress:Compress(serialized)
            if compressed and method ~= "none" then
                return "C" .. compressed -- Prefix with 'C' to indicate compression
            end
        end
    end
    
    return serialized
end

local function DecodeMessage(encodedMessage)
    local messageData = encodedMessage
    
    -- Check if message is compressed
    if encodedMessage and #encodedMessage > 0 and encodedMessage:sub(1, 1) == "C" then
        local LibCompress = LibStub("LibCompress", true)
        if LibCompress then
            local decompressed = LibCompress:Decompress(encodedMessage:sub(2))
            if decompressed then
                messageData = decompressed
            else
                addon.Debug(addon.LOG_LEVEL.WARN, "Failed to decompress message")
                return nil
            end
        else
            addon.Debug(addon.LOG_LEVEL.WARN, "Received compressed message but LibCompress not available")
            return nil
        end
    end
    
    local success, message = addon:Deserialize(messageData)
    
    if not success or not message or not message.version or not message.type then
        return nil
    end
    
    return message
end

local function IsVersionCompatible(theirVersion)
    local ourMajor, ourMinor = string.match(COMM_VERSION, "(%d+)%.(%d+)")
    local theirMajor, theirMinor = string.match(theirVersion or "", "(%d+)%.(%d+)")
    
    if not ourMajor or not theirMajor then
        return false
    end
    
    return tonumber(ourMajor) == tonumber(theirMajor)
end

local function HandleIncomingMessage(message, distribution, sender)
    if not message or message.sender == UnitName("player") then
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Received message from", sender, "type:", message.type)
    
    if not IsVersionCompatible(message.version) then
        addon.Debug(addon.LOG_LEVEL.WARN, "Version incompatible with", sender, "- their version:", message.version, "our version:", COMM_VERSION)
        return
    end
    
    if message.type == MESSAGE_TYPES.VERSION_CHECK then
        addon.Debug(addon.LOG_LEVEL.INFO, "Received version check from", sender, "- version:", message.data.addonVersion)
        AddonComm:SendVersionResponse(sender)
        connectedUsers[sender] = {
            version = message.version,
            addonVersion = message.data.addonVersion,
            lastSeen = GetServerTime()
        }
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Added/updated user in connected list:", sender)
        
        -- Trigger version check when we receive version info
        if addon.VersionWarning then
            C_Timer.After(1, function()
                addon.VersionWarning:CheckForNewerVersions()
            end)
        end
        
    elseif message.type == MESSAGE_TYPES.VERSION_RESPONSE then
        addon.Debug(addon.LOG_LEVEL.INFO, "Received version response from", sender, "- version:", message.data.addonVersion)
        connectedUsers[sender] = {
            version = message.version,
            addonVersion = message.data.addonVersion,
            lastSeen = GetServerTime()
        }
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Added/updated user in connected list:", sender)
        
        -- Trigger version check when we receive version response
        if addon.VersionWarning then
            C_Timer.After(1, function()
                addon.VersionWarning:CheckForNewerVersions()
            end)
        end
        
    elseif message.type == MESSAGE_TYPES.GROUP_SYNC then
        AddonComm:HandleGroupSync(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.PLAYER_DATA then
        AddonComm:HandlePlayerData(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.RAIDERIO_DATA then
        AddonComm:HandleRaiderIOData(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.FORMATION_REQUEST then
        AddonComm:HandleFormationRequest(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.FORMATION_RESPONSE then
        AddonComm:HandleFormationResponse(message.data, sender)
        
    elseif message.type == MESSAGE_TYPES.KEYSTONE_DATA then
        AddonComm:HandleKeystoneData(message.data, sender)
        
    -- Session message handling
    elseif message.type == MESSAGE_TYPES.SESSION_CREATE or
           message.type == MESSAGE_TYPES.SESSION_JOIN or
           message.type == MESSAGE_TYPES.SESSION_LEAVE or
           message.type == MESSAGE_TYPES.SESSION_WHITELIST or
           message.type == MESSAGE_TYPES.SESSION_FINALIZE or
           message.type == MESSAGE_TYPES.SESSION_STATE or
           message.type == MESSAGE_TYPES.SESSION_END then
        
        -- Call registered handlers for session messages
        local handler = messageHandlers[message.type]
        if handler then
            handler(message.data, sender)
        else
            addon.Debug(addon.LOG_LEVEL.DEBUG, "No handler registered for message type:", message.type)
        end
    end
end

function AddonComm:RegisterHandler(messageType, handler)
    if not messageType or not handler then
        addon.Debug(addon.LOG_LEVEL.WARN, "RegisterHandler: Invalid messageType or handler")
        return
    end
    
    messageHandlers[messageType] = handler
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Registered handler for message type:", messageType)
end

function AddonComm:BroadcastMessage(messageType, data)
    if not self.initialized then
        addon.Debug(addon.LOG_LEVEL.WARN, "BroadcastMessage: AddonComm not initialized")
        return
    end
    
    if not addon.settings or not addon.settings.communication or not addon.settings.communication.enabled then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "BroadcastMessage: Communication disabled")
        return
    end
    
    local encoded = EncodeMessage(messageType, data)
    if encoded then
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, encoded, "GUILD")
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Broadcasted message type:", messageType)
    else
        addon.Debug(addon.LOG_LEVEL.WARN, "BroadcastMessage: Failed to encode message")
    end
end

function AddonComm:Initialize()
    if not self.initialized then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
        
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("CHAT_MSG_ADDON")
        frame:SetScript("OnEvent", function(self, event, prefix, message, distribution, sender)
            if prefix == COMM_PREFIX then
                local decodedMessage = DecodeMessage(message)
                if decodedMessage then
                    HandleIncomingMessage(decodedMessage, distribution, sender)
                end
            end
        end)
        
        self.initialized = true
        addon.Debug(addon.LOG_LEVEL.INFO, "AddonComm initialized with prefix:", COMM_PREFIX)
        
        C_Timer.After(2, function()
            self:BroadcastVersionCheck()
        end)
        
        -- Start role monitoring after initialization
        C_Timer.After(1, function()
            self:StartRoleMonitoring()
        end)
    end
end

function AddonComm:SendMessage(messageType, data, target, distribution)
    if not self.initialized then
        addon.Debug(addon.LOG_LEVEL.WARN, "AddonComm not initialized, cannot send message")
        return false
    end
    
    distribution = distribution or (target and "WHISPER" or "GUILD")
    local encodedMessage = EncodeMessage(messageType, data)
    
    if string.len(encodedMessage) > 255 then
        addon.Debug(addon.LOG_LEVEL.WARN, "Message too large, breaking into chunks")
        return false
    end
    
    local success = C_ChatInfo.SendAddonMessage(COMM_PREFIX, encodedMessage, distribution, target)
    
    if success then
        addon.Debug(addon.LOG_LEVEL.TRACE, "Sent message type", messageType, "to", target or distribution)
    else
        addon.Debug(addon.LOG_LEVEL.ERROR, "Failed to send message type", messageType)
    end
    
    return success
end

function AddonComm:BroadcastVersionCheck()
    if not IsInGuild() then
        addon.Debug(addon.LOG_LEVEL.WARN, "Not in guild, skipping version check broadcast")
        return
    end
    
    if not self.initialized then
        addon.Debug(addon.LOG_LEVEL.WARN, "AddonComm not initialized, skipping version check broadcast")
        return
    end
    
    local addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    addon.Debug(addon.LOG_LEVEL.INFO, "Broadcasting version check to guild - addon version:", addonVersion)
    
    self:SendMessage(MESSAGE_TYPES.VERSION_CHECK, {
        addonVersion = addonVersion
    })
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Version check broadcast sent successfully")
end

function AddonComm:SendVersionResponse(target)
    self:SendMessage(MESSAGE_TYPES.VERSION_RESPONSE, {
        addonVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    }, target)
end

function AddonComm:SyncGroupFormation(groups)
    if not groups or #groups == 0 then
        return
    end
    
    local now = GetServerTime()
    if lastSyncTime.groups and (now - lastSyncTime.groups) < 5 then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Group sync throttled - too recent")
        return
    end
    
    local syncData = {
        groups = {},
        timestamp = now,
        leader = UnitName("player")
    }
    
    for i, group in ipairs(groups) do
        if group and group.members then
            syncData.groups[i] = {
                members = {},
                avgRating = group.avgRating or 0
            }
            
            for j, member in ipairs(group.members) do
                if member and member.name then
                    syncData.groups[i].members[j] = {
                        name = member.name,
                        role = member.role,
                        rating = member.rating,
                        class = member.class
                    }
                end
            end
        end
    end
    
    self:SendMessage(MESSAGE_TYPES.GROUP_SYNC, syncData)
    lastSyncTime.groups = now
    addon.Debug(addon.LOG_LEVEL.INFO, "Synced group formation with", #syncData.groups, "groups")
end

function AddonComm:HandleGroupSync(data, sender)
    if not addon.settings.communication or not addon.settings.communication.acceptGroupSync then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Group sync disabled, ignoring message from", sender)
        return
    end
    
    if not data or not data.groups or not data.timestamp then
        addon.Debug(addon.LOG_LEVEL.WARN, "Invalid group sync data from", sender)
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Received group sync from", sender, "with", #data.groups, "groups")
    
    if addon.OnGroupSyncReceived then
        addon:OnGroupSyncReceived(data, sender)
    end
end

function AddonComm:SharePlayerData(playerName, playerData)
    if not playerName or not playerData then
        return
    end
    
    local shareData = {
        player = playerName,
        rating = playerData.rating,
        role = playerData.role,
        class = playerData.class,
        timestamp = GetServerTime()
    }
    
    self:SendMessage(MESSAGE_TYPES.PLAYER_DATA, shareData)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Shared player data for", playerName)
end

function AddonComm:HandlePlayerData(data, sender)
    if not addon.settings.communication or not addon.settings.communication.acceptPlayerData then
        return
    end
    
    if not data or not data.player then
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Received player data from", sender, "for player", data.player)
    
    if addon.OnPlayerDataReceived then
        addon:OnPlayerDataReceived(data, sender)
    end
end

function AddonComm:ShareRaiderIOData(playerName, raiderIOData)
    if not playerName or not raiderIOData then
        return
    end
    
    local shareData = {
        player = playerName,
        mythicPlusScore = raiderIOData.mythicPlusScore,
        mainRole = raiderIOData.mainRole,
        bestRuns = raiderIOData.bestRuns,
        timestamp = GetServerTime()
    }
    
    self:SendMessage(MESSAGE_TYPES.RAIDERIO_DATA, shareData)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Shared RaiderIO data for", playerName)
end

function AddonComm:HandleRaiderIOData(data, sender)
    if not addon.settings.communication or not addon.settings.communication.acceptRaiderIOData then
        return
    end
    
    if not data or not data.player then
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Received RaiderIO data from", sender, "for player", data.player)
    
    if addon.OnRaiderIODataReceived then
        addon:OnRaiderIODataReceived(data, sender)
    end
end

function AddonComm:RequestFormation(criteria)
    local requestData = {
        criteria = criteria,
        requester = UnitName("player"),
        timestamp = GetServerTime()
    }
    
    self:SendMessage(MESSAGE_TYPES.FORMATION_REQUEST, requestData)
    addon.Debug(addon.LOG_LEVEL.INFO, "Requested group formation from guild")
end

function AddonComm:HandleFormationRequest(data, sender)
    if not addon.settings.communication or not addon.settings.communication.respondToRequests then
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Formation request received from", sender)
    
    if addon.OnFormationRequestReceived then
        addon:OnFormationRequestReceived(data, sender)
    end
end

function AddonComm:RespondToFormation(requester, response)
    local responseData = {
        requester = requester,
        response = response,
        responder = UnitName("player"),
        timestamp = GetServerTime()
    }
    
    self:SendMessage(MESSAGE_TYPES.FORMATION_RESPONSE, responseData, requester)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Sent formation response to", requester)
end

function AddonComm:HandleFormationResponse(data, sender)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Formation response received from", sender)
    
    if addon.OnFormationResponseReceived then
        addon:OnFormationResponseReceived(data, sender)
    end
end

function AddonComm:HandleKeystoneData(data, sender)
    if not addon.settings.communication or not addon.settings.communication.acceptKeystoneData then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Keystone data sharing disabled, ignoring message from", sender)
        return
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Keystone data received from", sender)
    
    if addon.Keystone and addon.Keystone.HandleKeystoneData then
        addon.Keystone:HandleKeystoneData(data, sender)
    end
end

function AddonComm:GetConnectedUsers()
    local now = GetServerTime()
    local activeUsers = {}
    local totalUsers = 0
    local activeCount = 0
    
    for user, info in pairs(connectedUsers) do
        totalUsers = totalUsers + 1
        local timeSinceLastSeen = info.lastSeen and (now - info.lastSeen) or nil
        
        if info.lastSeen and timeSinceLastSeen < 300 then
            activeUsers[user] = info
            activeCount = activeCount + 1
            addon.Debug(addon.LOG_LEVEL.TRACE, "Active user:", user, "last seen", timeSinceLastSeen, "seconds ago")
        else
            addon.Debug(addon.LOG_LEVEL.TRACE, "Inactive user:", user, "last seen", timeSinceLastSeen and (timeSinceLastSeen .. " seconds ago") or "never")
        end
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "GetConnectedUsers: Found", activeCount, "active users out of", totalUsers, "total users")
    return activeUsers
end

function AddonComm:CleanupStaleConnections()
    local now = GetServerTime()
    local cleaned = 0
    
    for user, info in pairs(connectedUsers) do
        if info.lastSeen and (now - info.lastSeen) > 600 then
            connectedUsers[user] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Cleaned up", cleaned, "stale connections")
    end
end

local function GetPlayerCurrentRole()
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end
    
    -- Use the AutoFormation module's role detection if available
    if addon.AutoFormation and addon.AutoFormation.GetPlayerRole then
        return addon.AutoFormation:GetPlayerRole("player")
    end
    
    -- Fallback to basic role detection using the spec index
    local role = GetSpecializationRole(specIndex)
    if role == "TANK" then
        return "TANK"
    elseif role == "HEALER" then
        return "HEALER"
    else
        return "DPS"
    end
end

function AddonComm:SharePlayerRole(forceUpdate)
    if not self.initialized or not addon.settings.communication or not addon.settings.communication.enabled then
        return
    end
    
    local currentRole = GetPlayerCurrentRole()
    local currentSpec = GetSpecialization()
    
    -- Only share if role changed or forced update
    if not forceUpdate and playerRole == currentRole and lastKnownSpec == currentSpec then
        return
    end
    
    if not currentRole then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Could not determine player role, skipping share")
        return
    end
    
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    
    local roleData = {
        player = playerName,
        role = currentRole,
        class = playerClass,
        specID = currentSpec,
        level = UnitLevel("player")
    }
    
    -- Include RaiderIO score if available
    if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
        local score = addon.RaiderIOIntegration:GetMythicPlusScore("player")
        if score then
            roleData.rating = score
        end
    end
    
    self:SendMessage(MESSAGE_TYPES.PLAYER_DATA, roleData)
    
    -- Update tracking variables
    playerRole = currentRole
    lastKnownSpec = currentSpec
    
    -- Update UI if available
    if addon.UpdatePlayerRoleInUI then
        addon:UpdatePlayerRoleInUI()
    end
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Shared player role:", currentRole, "for", playerName)
end

function AddonComm:CheckForRoleChange()
    if not self.initialized then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "CheckForRoleChange: Not initialized, skipping")
        return
    end
    
    local currentSpec = GetSpecialization()
    local currentRole = GetPlayerCurrentRole()
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "CheckForRoleChange: Current spec:", currentSpec, "role:", currentRole)
    addon.Debug(addon.LOG_LEVEL.DEBUG, "CheckForRoleChange: Last known spec:", lastKnownSpec, "role:", playerRole)
    
    -- Check if spec or role changed
    if currentSpec ~= lastKnownSpec or currentRole ~= playerRole then
        addon.Debug(addon.LOG_LEVEL.INFO, "Player role/spec changed - was spec:", lastKnownSpec, "role:", playerRole, "now spec:", currentSpec, "role:", currentRole)
        self:SharePlayerRole(true)
    else
        addon.Debug(addon.LOG_LEVEL.DEBUG, "CheckForRoleChange: No role/spec change detected")
    end
end

function AddonComm:StartRoleMonitoring()
    if not self.initialized then
        return
    end
    
    -- Register events for spec changes
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Role monitoring event:", event)
        -- Small delay to ensure spec info is updated
        C_Timer.After(0.5, function()
            AddonComm:CheckForRoleChange()
        end)
    end)
    
    -- Initial role sharing after login
    C_Timer.After(3, function()
        AddonComm:SharePlayerRole(true)
    end)
    
    -- Periodic role updates (every 5 minutes) to ensure sync
    C_Timer.NewTicker(300, function()
        AddonComm:SharePlayerRole(false)
    end)
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Role monitoring and sharing started")
end

local cleanupTimer = C_Timer.NewTicker(60, function()
    AddonComm:CleanupStaleConnections()
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        C_Timer.After(1, function()
            AddonComm:Initialize()
        end)
    end
end)