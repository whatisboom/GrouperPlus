local addonName, addon = ...

local Keystone = {}
addon.Keystone = Keystone

local keystoneInfo = {
    mapID = nil,
    level = nil,
    dungeonName = nil,
    lastUpdate = 0
}

local listeners = {}

-- Fallback dungeon name mapping for common mapIDs
local DUNGEON_NAMES = {
    [244] = "Atal'Dazar",
    [245] = "Freehold",
    [247] = "The MOTHERLODE!!",
    [248] = "The Underrot",
    [249] = "Temple of Sethraliss",
    [250] = "Shrine of the Storm",
    [251] = "Tol Dagor",
    [252] = "Waycrest Manor",
    [353] = "Siege of Boralus",
    [369] = "Operation: Mechagon - Junkyard",
    [370] = "Operation: Mechagon - Workshop",
    [375] = "Mists of Tirna Scithe",
    [376] = "The Necrotic Wake",
    [377] = "De Other Side",
    [378] = "Halls of Atonement",
    [379] = "Plaguefall",
    [380] = "Sanguine Depths",
    [381] = "Spires of Ascension",
    [382] = "Theater of Pain",
    [391] = "Streets of Wonder",
    [392] = "So'leah's Gambit",
    [399] = "Ruby Life Pools",
    [400] = "The Nokhud Offensive",
    [401] = "The Azure Vault",
    [402] = "Algeth'ar Academy",
    [403] = "Uldaman: Legacy of Tyr",
    [404] = "Neltharus",
    [405] = "Brackenhide Hollow",
    [406] = "Halls of Infusion",
    [463] = "Dawn of the Infinites: Galakrond's Fall",
    [464] = "Dawn of the Infinites: Murozond's Rise",
    [499] = "Priory of the Sacred Flame",
    [500] = "The Rookery",
    [501] = "The Stonevault",
    [502] = "City of Threads",
    [503] = "Ara-Kara, City of Echoes",
    [504] = "The Dawnbreaker",
    [505] = "Cinderbrew Meadery",
    [506] = "Darkflame Cleft",
    [542] = "Eco-Dome Al'dani"
}

function Keystone:Initialize()
    addon.Debug(addon.LOG_LEVEL.INFO, "Keystone module initializing")
    
    -- Create event frame for keystone updates
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
    frame:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("MYTHIC_PLUS_NEW_WEEKLY_RECORD")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    frame:SetScript("OnEvent", function(eventFrame, event, ...)
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Keystone event:", event)
        
        if event == "GROUP_ROSTER_UPDATE" then
            -- For group changes, rebroadcast existing keystone data immediately
            C_Timer.After(1, function()
                Keystone:RebroadcastKeystoneData()
            end)
        else
            -- For other events, do the normal keystone update check
            C_Timer.After(0.1, function()
                Keystone:UpdateKeystoneInfo()
            end)
        end
    end)
    
    -- Periodic update every 30 seconds to catch any missed keystone changes
    C_Timer.NewTicker(30, function()
        Keystone:UpdateKeystoneInfo()
    end)
    
    -- Periodic rebroadcast every 2 minutes to ensure new party members get keystone data
    C_Timer.NewTicker(120, function()
        Keystone:RebroadcastKeystoneData()
    end)
    
    -- Initial keystone check
    C_Timer.After(2, function()
        Keystone:UpdateKeystoneInfo()
    end)
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Keystone module initialized")
end

function Keystone:UpdateKeystoneInfo()
    addon.Debug(addon.LOG_LEVEL.TRACE, "Updating keystone information")
    
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Keystone detection - API results: mapID=" .. tostring(mapID) .. ", level=" .. tostring(level))
    
    local hasKeystone = mapID and level
    local dungeonName = nil
    
    -- If API doesn't work, try scanning bags as fallback
    if not hasKeystone then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "API returned no keystone, scanning bags as fallback")
        mapID, level, dungeonName = self:ScanBagsForKeystone()
        hasKeystone = mapID and level
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Bag scan results: mapID=" .. tostring(mapID) .. ", level=" .. tostring(level))
    end
    
    if hasKeystone then
        if not dungeonName then
            local mapInfo = C_ChallengeMode.GetMapUIInfo(mapID)
            addon.Debug(addon.LOG_LEVEL.DEBUG, "GetMapUIInfo result for mapID", mapID, ":", mapInfo and "found" or "nil")
            if mapInfo then
                addon.Debug(addon.LOG_LEVEL.DEBUG, "MapInfo name:", mapInfo.name)
                dungeonName = mapInfo.name
            end
            
            -- Fallback: try getting name from challenge mode maps
            if not dungeonName then
                local maps = C_ChallengeMode.GetMapTable()
                if maps then
                    for _, challengeMapID in ipairs(maps) do
                        if challengeMapID == mapID then
                            local mapInfo2 = C_ChallengeMode.GetMapUIInfo(challengeMapID)
                            if mapInfo2 and mapInfo2.name then
                                dungeonName = mapInfo2.name
                                addon.Debug(addon.LOG_LEVEL.DEBUG, "Found name via map table:", dungeonName)
                                break
                            end
                        end
                    end
                end
            end
            
            -- Final fallback: use our static lookup table
            if not dungeonName then
                dungeonName = DUNGEON_NAMES[mapID]
                if dungeonName then
                    addon.Debug(addon.LOG_LEVEL.DEBUG, "Found name via static lookup:", dungeonName)
                end
            end
            
            dungeonName = dungeonName or "Unknown Dungeon"
        end
        
        addon.Debug(addon.LOG_LEVEL.INFO, "Player has keystone: " .. tostring(dungeonName) .. " level " .. tostring(level))
    else
        addon.Debug(addon.LOG_LEVEL.INFO, "Player has no keystone detected")
    end
    
    -- Check if keystone changed
    local keystoneChanged = (keystoneInfo.mapID ~= mapID) or (keystoneInfo.level ~= level)
    
    if keystoneChanged then
        addon.Debug(addon.LOG_LEVEL.INFO, "Keystone changed - was:", keystoneInfo.dungeonName, keystoneInfo.level, "now:", dungeonName, level)
        
        -- Update stored info
        keystoneInfo.mapID = mapID
        keystoneInfo.level = level
        keystoneInfo.dungeonName = dungeonName
        keystoneInfo.lastUpdate = GetServerTime()
        
        -- Notify listeners
        self:NotifyListeners()
        
        -- Transmit to other addon users via StateSync
        if addon.StateSync then
            self:TransmitKeystoneData()
        end
    end
end

function Keystone:GetKeystoneInfo()
    return {
        mapID = keystoneInfo.mapID,
        level = keystoneInfo.level,
        dungeonName = keystoneInfo.dungeonName,
        lastUpdate = keystoneInfo.lastUpdate,
        hasKeystone = keystoneInfo.mapID ~= nil and keystoneInfo.level ~= nil
    }
end

function Keystone:GetKeystoneString()
    if keystoneInfo.mapID and keystoneInfo.level then
        return string.format("%s +%d", keystoneInfo.dungeonName or "Unknown", keystoneInfo.level)
    else
        return "No Keystone"
    end
end

function Keystone:TransmitKeystoneData()
    if not addon.StateSync then
        addon.Debug(addon.LOG_LEVEL.WARN, "StateSync not available for keystone transmission")
        return
    end
    
    local playerName = addon.WoWAPIWrapper:NormalizePlayerName(UnitName("player"))
    if not playerName then
        addon.Debug(addon.LOG_LEVEL.ERROR, "Failed to get normalized player name for keystone data")
        return
    end
    
    local keystoneData = {
        player = playerName,
        mapID = keystoneInfo.mapID or 0,
        level = keystoneInfo.level or 0,
        dungeonName = keystoneInfo.dungeonName or "Unknown",
        timestamp = keystoneInfo.lastUpdate or addon.WoWAPIWrapper:GetServerTime()
    }
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Broadcasting keystone data:", self:GetKeystoneString())
    -- Send keystone data via StateSync
    if addon.StateSync then
        addon.StateSync:BroadcastMessage("KEYSTONE_DATA", keystoneData)
    end
end

function Keystone:RebroadcastKeystoneData()
    -- Only rebroadcast if we have a keystone and are in a group
    if not keystoneInfo.mapID or not keystoneInfo.level then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "No keystone to rebroadcast")
        return
    end
    
    -- Only rebroadcast if we're in a party or raid (no point broadcasting to guild constantly)
    if not IsInGroup() and not IsInRaid() then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Not in group, skipping keystone rebroadcast")
        return
    end
    
    if not addon.StateSync then
        addon.Debug(addon.LOG_LEVEL.DEBUG, "StateSync not available for keystone rebroadcast")
        return
    end
    
    local playerName = addon.WoWAPIWrapper:NormalizePlayerName(UnitName("player"))
    if not playerName then
        addon.Debug(addon.LOG_LEVEL.ERROR, "Failed to get normalized player name for keystone rebroadcast")
        return
    end
    
    local keystoneData = {
        player = playerName,
        mapID = keystoneInfo.mapID or 0,
        level = keystoneInfo.level or 0,
        dungeonName = keystoneInfo.dungeonName or "Unknown",
        timestamp = keystoneInfo.lastUpdate or addon.WoWAPIWrapper:GetServerTime()
    }
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Rebroadcasting keystone data:", self:GetKeystoneString())
    if addon.StateSync then
        addon.StateSync:BroadcastMessage("KEYSTONE_DATA", keystoneData)
    end
end

function Keystone:HandleKeystoneData(data, sender)
    if not data or not data.player then
        addon.Debug(addon.LOG_LEVEL.WARN, "Invalid keystone data received from", sender)
        return
    end
    
    local keystoneString = "No Keystone"
    if data.mapID and data.level then
        keystoneString = string.format("%s +%d", data.dungeonName or "Unknown", data.level)
    end
    
    addon.Debug(addon.LOG_LEVEL.INFO, "Received keystone data from", data.player, ":", keystoneString)
    
    -- Store received keystone data for other modules
    if addon.receivedKeystones then
        addon.receivedKeystones[data.player] = {
            mapID = data.mapID,
            level = data.level,
            dungeonName = data.dungeonName,
            timestamp = data.timestamp or GetServerTime(),
            sender = sender
        }
    else
        addon.receivedKeystones = {
            [data.player] = {
                mapID = data.mapID,
                level = data.level,
                dungeonName = data.dungeonName,
                timestamp = data.timestamp or GetServerTime(),
                sender = sender
            }
        }
    end
    
    -- Notify UI components that keystone data was received
    if addon.OnKeystoneDataReceived then
        addon:OnKeystoneDataReceived(data, sender)
    end
end

function Keystone:GetReceivedKeystones()
    if not addon.receivedKeystones then
        return {}
    end
    
    local now = GetServerTime()
    local activeKeystones = {}
    
    -- Return keystones received in the last 10 minutes
    for player, data in pairs(addon.receivedKeystones) do
        if data.timestamp and (now - data.timestamp) < 600 then
            activeKeystones[player] = data
        end
    end
    
    return activeKeystones
end

function Keystone:RegisterListener(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
        addon.Debug(addon.LOG_LEVEL.DEBUG, "Registered keystone listener")
    end
end

function Keystone:NotifyListeners()
    local info = self:GetKeystoneInfo()
    for _, callback in ipairs(listeners) do
        pcall(callback, info)
    end
end

function Keystone:ScanBagsForKeystone()
    addon.Debug(addon.LOG_LEVEL.DEBUG, "Scanning bags for keystone...")
    
    for bagID = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots then
            for slotID = 1, numSlots do
                local itemID = C_Container.GetContainerItemID(bagID, slotID)
                if itemID then
                    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                          itemEquipLoc, itemTexture, sellPrice, classID, subClassID = C_Item.GetItemInfo(itemID)
                    
                    -- Check if it's a keystone (classID 15, subClassID 12)
                    if classID == 15 and subClassID == 12 then
                        addon.Debug(addon.LOG_LEVEL.DEBUG, "Found keystone item:", itemName, "itemID:", itemID)
                        
                        -- Try to extract keystone level and mapID from item link
                        if itemLink then
                            local keystoneLevel = itemLink:match("|Hkeystone:(%d+):")
                            local mapID = itemLink:match("|Hkeystone:%d+:(%d+):")
                            
                            if keystoneLevel and mapID then
                                keystoneLevel = tonumber(keystoneLevel)
                                mapID = tonumber(mapID)
                                
                                local mapInfo = C_ChallengeMode.GetMapUIInfo(mapID)
                                local dungeonName = mapInfo and mapInfo.name or "Unknown Dungeon"
                                
                                addon.Debug(addon.LOG_LEVEL.DEBUG, "Extracted keystone data - mapID:", mapID, "level:", keystoneLevel, "dungeon:", dungeonName)
                                return mapID, keystoneLevel, dungeonName
                            end
                        end
                    end
                end
            end
        end
    end
    
    addon.Debug(addon.LOG_LEVEL.DEBUG, "No keystone found in bags")
    return nil, nil, nil
end

function Keystone:ForceUpdate()
    addon.Debug(addon.LOG_LEVEL.INFO, "Forcing keystone update")
    self:UpdateKeystoneInfo()
end