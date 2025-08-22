local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    
    local Debug = addon.Debug
    local LOG_LEVEL = addon.LOG_LEVEL
    
    if not Debug or not LOG_LEVEL then
        print("[GrouperPlus:ERROR] RaiderIOIntegration - Missing addon references")
        return
    end
    
    Debug(LOG_LEVEL.DEBUG, "RaiderIOIntegration module initializing")
    
    local RaiderIOIntegration = {}
    
    function RaiderIOIntegration:IsAvailable()
        local raiderIOExists = RaiderIO ~= nil
        local hasGetProfile = RaiderIO and RaiderIO.GetProfile ~= nil
        local hasGetPlayerProfile = RaiderIO and RaiderIO.GetPlayerProfile ~= nil
        local hasGetScoreColor = RaiderIO and RaiderIO.GetScoreColor ~= nil
        local enabled = addon.settings and addon.settings.raiderIO and addon.settings.raiderIO.enabled
        
        local available = raiderIOExists and (hasGetProfile or hasGetPlayerProfile)
        Debug(LOG_LEVEL.DEBUG, "RaiderIO availability result:", available, "enabled:", enabled)
        return available and enabled
    end
    
    function RaiderIOIntegration:GetProfile(unitOrName)
        
        if not self:IsAvailable() then
            Debug(LOG_LEVEL.WARN, "RaiderIO not available")
            return nil, "RaiderIO not available"
        end
        
        -- Try GetProfile first
        if RaiderIO.GetProfile then
            local success, profile = pcall(RaiderIO.GetProfile, unitOrName)
            if success and profile then
                -- Check if we have usable M+ data instead of relying on hasRenderableData
                if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
                    return profile
                elseif profile.hasRenderableData then
                    return profile
                end
            end
        end
        
        -- Try GetPlayerProfile as fallback
        if RaiderIO.GetPlayerProfile then
            local success, profile = pcall(RaiderIO.GetPlayerProfile, unitOrName)
            if success and profile then
                -- Check if we have usable M+ data instead of relying on hasRenderableData
                if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
                    return profile
                elseif profile.hasRenderableData then
                    return profile
                end
            end
        end
        return nil, "No valid profile found"
    end
    
    function RaiderIOIntegration:GetMythicPlusScore(unitOrName)
        
        local profile, err = self:GetProfile(unitOrName)
        if not profile then
            return nil, err
        end
        
        if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
            local score = profile.mythicKeystoneProfile.currentScore
            return score
        end
        return nil, "No M+ data"
    end
    
    function RaiderIOIntegration:GetFormattedScoreWithFallback(characterName)
        
        local namesToTry = {}
        
        if string.find(characterName, "-") then
            table.insert(namesToTry, characterName)
            local nameOnly = string.match(characterName, "([^-]+)")
            if nameOnly then
                table.insert(namesToTry, nameOnly)
            end
        else
            table.insert(namesToTry, characterName)
            local playerRealm = GetRealmName()
            if playerRealm then
                table.insert(namesToTry, characterName .. "-" .. playerRealm)
            end
        end
        
        for _, nameVariant in ipairs(namesToTry) do
            local score, err = self:GetMythicPlusScore(nameVariant)
            if score then
                if self:IsAvailable() and RaiderIO.GetScoreColor then
                    local success, r, g, b = pcall(RaiderIO.GetScoreColor, score)
                    if success and r and g and b then
                        return string.format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, score)
                    end
                end
                return tostring(score)
            end
        end
        
        -- Return formatted 0 instead of nil
        if self:IsAvailable() and RaiderIO.GetScoreColor then
            local success, r, g, b = pcall(RaiderIO.GetScoreColor, 0)
            if success and r and g and b then
                return string.format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, 0)
            end
        end
        
        return "0"
    end

    function RaiderIOIntegration:GetFormattedScore(unitOrName)
        Debug(LOG_LEVEL.DEBUG, "Getting formatted score for unit/name:", unitOrName)
        
        local score, err = self:GetMythicPlusScore(unitOrName)
        if not score then
            return nil, err
        end
        
        if self:IsAvailable() and RaiderIO.GetScoreColor then
            local success, r, g, b = pcall(RaiderIO.GetScoreColor, score)
            if success and r and g and b then
                local formattedScore = string.format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, score)
                Debug(LOG_LEVEL.DEBUG, "Formatted score:", formattedScore)
                return formattedScore
            end
        end
        
        local fallbackScore = tostring(score)
        Debug(LOG_LEVEL.DEBUG, "Fallback score formatting:", fallbackScore)
        return fallbackScore
    end
    
    function RaiderIOIntegration:GetPreviousSeasonScore(unit)
        Debug(LOG_LEVEL.DEBUG, "Getting previous season score for unit:", unit)
        
        local profile, err = self:GetProfile(unit)
        if not profile then
            return nil, err
        end
        
        if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.previousScore then
            local score = profile.mythicKeystoneProfile.previousScore
            Debug(LOG_LEVEL.INFO, "Previous season score for", profile.name or unit, ":", score)
            return score
        end
        
        Debug(LOG_LEVEL.DEBUG, "No previous season data available for unit:", unit)
        return nil, "No previous season data"
    end
    
    function RaiderIOIntegration:GetKeystoneCompletions(unit)
        Debug(LOG_LEVEL.DEBUG, "Getting keystone completions for unit:", unit)
        
        local profile, err = self:GetProfile(unit)
        if not profile then
            return nil, err
        end
        
        if profile.mythicKeystoneProfile then
            local completions = {
                fifteenPlus = profile.mythicKeystoneProfile.keystoneFifteenPlus or 0,
                tenPlus = profile.mythicKeystoneProfile.keystoneTenPlus or 0
            }
            Debug(LOG_LEVEL.INFO, "Keystone completions for", profile.name or unit, ":", completions.fifteenPlus, "15+,", completions.tenPlus, "10+")
            return completions
        end
        
        Debug(LOG_LEVEL.DEBUG, "No keystone completion data available for unit:", unit)
        return nil, "No keystone completion data"
    end
    
    function RaiderIOIntegration:AddToTooltip(tooltip, unit)
        Debug(LOG_LEVEL.DEBUG, "Adding RaiderIO info to tooltip for unit:", unit)
        
        if not self:IsAvailable() or not RaiderIO.ShowProfile then
            Debug(LOG_LEVEL.DEBUG, "RaiderIO ShowProfile not available")
            return false
        end
        
        local success, result = pcall(RaiderIO.ShowProfile, tooltip, unit)
        return success and result or false
    end
    
    function RaiderIOIntegration:GetGroupMemberScores()
        Debug(LOG_LEVEL.DEBUG, "Getting scores for all group members")
        
        local scores = {}
        local numMembers = GetNumGroupMembers()
        
        if numMembers == 0 then
            Debug(LOG_LEVEL.DEBUG, "No group members found")
            return scores
        end
        
        for i = 1, numMembers do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name, realm = UnitName(unit)
                local fullName = realm and (name .. "-" .. realm) or (name .. "-" .. GetRealmName())
                local score = self:GetMythicPlusScore(unit)
                if score then
                    scores[fullName] = score
                    Debug(LOG_LEVEL.INFO, "Group member score -", fullName, ":", score)
                end
            end
        end
        
        local playerScore = self:GetMythicPlusScore("player")
        if playerScore then
            local playerFullName = UnitName("player") .. "-" .. GetRealmName()
            scores[playerFullName] = playerScore
            Debug(LOG_LEVEL.INFO, "Player score:", playerFullName, ":", playerScore)
        end
        
        Debug(LOG_LEVEL.INFO, "Total group members with scores:", #scores)
        return scores
    end
    
    function RaiderIOIntegration:PrintPlayerInfo(unit)
        unit = unit or "player"
        Debug(LOG_LEVEL.INFO, "Printing RaiderIO info for unit:", unit)
        
        if not self:IsAvailable() then
            Debug(LOG_LEVEL.WARN, "RaiderIO addon not available")
            return
        end
        
        local profile, err = self:GetProfile(unit)
        if not profile then
            Debug(LOG_LEVEL.INFO, "No RaiderIO data available for", (UnitName(unit) or unit), "(", err, ")")
            return
        end
        
        local name = profile.name or UnitName(unit) or unit
        Debug(LOG_LEVEL.DEBUG, "RaiderIO Info for", name, ":")
        
        local score = self:GetMythicPlusScore(unit)
        if score then
            Debug(LOG_LEVEL.DEBUG, "  Current M+ Score:", score)
        end
        
        local prevScore = self:GetPreviousSeasonScore(unit)
        if prevScore then
            Debug(LOG_LEVEL.DEBUG, "  Previous Season Score:", prevScore)
        end
        
        local completions = self:GetKeystoneCompletions(unit)
        if completions then
            Debug(LOG_LEVEL.DEBUG, "  Keystone Completions:", completions.fifteenPlus, "(15+),", completions.tenPlus, "(10+)")
        end
    end
    
    function RaiderIOIntegration:SetupTooltipIntegration()
        if not self:IsAvailable() then
            Debug(LOG_LEVEL.DEBUG, "RaiderIO not available, skipping tooltip integration")
            return
        end
        
        local function AddRaiderIOToTooltip(tooltip, unit)
            if not addon.settings or not addon.settings.raiderIO or not addon.settings.raiderIO.showInTooltips then
                return
            end
            
                RaiderIOIntegration:AddToTooltip(tooltip, unit)
        end
        
        GameTooltip:HookScript("OnShow", function(self)
            local _, unit = self:GetUnit()
            if unit and UnitIsPlayer(unit) then
                AddRaiderIOToTooltip(self, unit)
            end
        end)
        
        Debug(LOG_LEVEL.INFO, "RaiderIO tooltip integration enabled")
    end
    
    
    function RaiderIOIntegration:TestPlayer()
        Debug(LOG_LEVEL.INFO, "Testing RaiderIO integration with player character")
        local playerName = UnitName("player")
        local realmName = GetRealmName()
        local fullPlayerName = playerName .. "-" .. realmName
        
        Debug(LOG_LEVEL.INFO, "Player name:", playerName)
        Debug(LOG_LEVEL.INFO, "Realm name:", realmName)
        Debug(LOG_LEVEL.INFO, "Full name:", fullPlayerName)
        
        self:IsAvailable() -- This will print diagnostic info
        
        Debug(LOG_LEVEL.INFO, "Trying to get player score...")
        local score = self:GetFormattedScoreWithFallback(playerName)
        if score then
            Debug(LOG_LEVEL.INFO, "Player RaiderIO score:", score)
        else
            Debug(LOG_LEVEL.WARN, "Could not get player RaiderIO score")
        end
    end
    
    -- Shared data cache for received RaiderIO information
    local sharedDataCache = {}
    
    function RaiderIOIntegration:CacheSharedData(playerName, data)
        Debug(LOG_LEVEL.DEBUG, "Caching shared RaiderIO data for", playerName)
        
        if not playerName or not data then
            return
        end
        
        sharedDataCache[playerName] = {
            data = data,
            timestamp = GetServerTime()
        }
        
        Debug(LOG_LEVEL.DEBUG, "Cached RaiderIO data for", playerName, "score:", data.mythicKeystoneProfile and data.mythicKeystoneProfile.currentScore or "unknown")
    end
    
    function RaiderIOIntegration:GetSharedData(playerName)
        local cached = sharedDataCache[playerName]
        if not cached then
            return nil
        end
        
        -- Check if data is still fresh (within 30 minutes)
        local now = GetServerTime()
        if now - cached.timestamp > 1800 then
            sharedDataCache[playerName] = nil
            return nil
        end
        
        return cached.data
    end
    
    function RaiderIOIntegration:SharePlayerData(playerName)
        Debug(LOG_LEVEL.DEBUG, "Attempting to share RaiderIO data for", playerName)
        
        if not addon.AddonComm or not addon.settings.communication or not addon.settings.communication.enabled then
            Debug(LOG_LEVEL.DEBUG, "Communication disabled, not sharing RaiderIO data")
            return
        end
        
        local profile, err = self:GetProfile(playerName)
        if not profile then
            Debug(LOG_LEVEL.DEBUG, "No RaiderIO profile found for", playerName, "-", err)
            return
        end
        
        local shareData = {
            mythicPlusScore = 0,
            mainRole = nil,
            bestRuns = {}
        }
        
        if profile.mythicKeystoneProfile then
            shareData.mythicPlusScore = profile.mythicKeystoneProfile.currentScore or 0
            shareData.mainRole = profile.mythicKeystoneProfile.mainRole
            
            -- Include best runs if available
            if profile.mythicKeystoneProfile.runs then
                shareData.bestRuns = {}
                for i, run in ipairs(profile.mythicKeystoneProfile.runs) do
                    if i <= 5 then -- Limit to top 5 runs
                        table.insert(shareData.bestRuns, {
                            dungeon = run.dungeon,
                            level = run.level,
                            score = run.score,
                            time = run.time
                        })
                    end
                end
            end
        end
        
        if shareData.mythicPlusScore > 0 then
            addon.AddonComm:BroadcastMessage("RAIDERIO_DATA", {
                player = playerName,
                data = shareData,
                timestamp = GetServerTime()
            })
            Debug(LOG_LEVEL.INFO, "Shared RaiderIO data for", playerName, "score:", shareData.mythicPlusScore)
        else
            Debug(LOG_LEVEL.DEBUG, "No meaningful RaiderIO data to share for", playerName)
        end
    end
    
    function RaiderIOIntegration:GetProfileWithSharedData(playerName)
        -- First try to get data from RaiderIO addon
        local profile, err = self:GetProfile(playerName)
        if profile then
            return profile
        end
        
        -- If no local data, check shared data cache
        local sharedData = self:GetSharedData(playerName)
        if sharedData then
            Debug(LOG_LEVEL.DEBUG, "Using shared RaiderIO data for", playerName)
            return sharedData
        end
        
        return nil, err or "No data available"
    end
    
    function RaiderIOIntegration:GetMythicPlusScoreWithSharedData(playerName)
        local profile, err = self:GetProfileWithSharedData(playerName)
        if not profile then
            return nil, err
        end
        
        if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
            return profile.mythicKeystoneProfile.currentScore
        end
        
        return nil, "No M+ score data"
    end
    
    function RaiderIOIntegration:ShareGuildMemberData()
        Debug(LOG_LEVEL.INFO, "Sharing RaiderIO data for available guild members")
        
        if not addon.AddonComm or not addon.settings.communication or not addon.settings.communication.enabled then
            Debug(LOG_LEVEL.DEBUG, "Communication disabled, not sharing guild member data")
            return
        end
        
        if not IsInGuild() then
            Debug(LOG_LEVEL.DEBUG, "Not in guild, cannot share member data")
            return
        end
        
        local sharedCount = 0
        local numMembers = GetNumGuildMembers()
        
        for i = 1, numMembers do
            local name, _, _, level, _, _, _, _, online = GetGuildRosterInfo(i)
            if online and level == GetMaxPlayerLevel() then
                -- Try to share data for this member
                self:SharePlayerData(name)
                sharedCount = sharedCount + 1
                
                -- Don't spam too many at once
                if sharedCount >= 10 then
                    break
                end
            end
        end
        
        Debug(LOG_LEVEL.INFO, "Attempted to share RaiderIO data for", sharedCount, "guild members")
    end
    
    addon.RaiderIOIntegration = RaiderIOIntegration
    Debug(LOG_LEVEL.INFO, "RaiderIOIntegration module loaded successfully")
    
    C_Timer.After(1, function()
        RaiderIOIntegration:SetupTooltipIntegration()
    end)
    
    C_Timer.After(3, function()
        RaiderIOIntegration:TestPlayer()
    end)
    
    self:UnregisterEvent("ADDON_LOADED")
end)