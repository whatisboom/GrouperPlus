local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    
    local Debug = addon.Debug
    local LOG_LEVEL = addon.LOG_LEVEL
    
    if not Debug or not LOG_LEVEL then
        print("GrouperPlus: RaiderIOIntegration - Missing addon references")
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
        
        Debug(LOG_LEVEL.INFO, "RaiderIO diagnostic:")
        Debug(LOG_LEVEL.INFO, "  RaiderIO exists:", raiderIOExists)
        Debug(LOG_LEVEL.INFO, "  Has GetProfile:", hasGetProfile)
        Debug(LOG_LEVEL.INFO, "  Has GetPlayerProfile:", hasGetPlayerProfile)
        Debug(LOG_LEVEL.INFO, "  Has GetScoreColor:", hasGetScoreColor)
        Debug(LOG_LEVEL.INFO, "  Settings enabled:", enabled)
        
        if raiderIOExists and RaiderIO then
            Debug(LOG_LEVEL.INFO, "  RaiderIO version:", RaiderIO.version or "unknown")
            if RaiderIO.API then
                Debug(LOG_LEVEL.INFO, "  Has API module:", true)
            end
        end
        
        local available = raiderIOExists and (hasGetProfile or hasGetPlayerProfile)
        Debug(LOG_LEVEL.DEBUG, "RaiderIO availability result:", available, "enabled:", enabled)
        return available and enabled
    end
    
    function RaiderIOIntegration:GetProfile(unitOrName)
        Debug(LOG_LEVEL.DEBUG, "Getting RaiderIO profile for unit/name:", unitOrName)
        
        if not self:IsAvailable() then
            Debug(LOG_LEVEL.WARN, "RaiderIO not available")
            return nil, "RaiderIO not available"
        end
        
        -- Try GetProfile first
        if RaiderIO.GetProfile then
            Debug(LOG_LEVEL.INFO, "Calling RaiderIO.GetProfile for:", unitOrName)
            local success, profile = pcall(RaiderIO.GetProfile, unitOrName)
            Debug(LOG_LEVEL.INFO, "GetProfile result - Success:", success, "Profile exists:", profile ~= nil)
            if success and profile then
                Debug(LOG_LEVEL.INFO, "Profile details - Name:", profile.name, "hasRenderableData:", profile.hasRenderableData)
                if profile.mythicKeystoneProfile then
                    Debug(LOG_LEVEL.INFO, "Has mythicKeystoneProfile:", true)
                    Debug(LOG_LEVEL.INFO, "Current score:", profile.mythicKeystoneProfile.currentScore)
                else
                    Debug(LOG_LEVEL.INFO, "Has mythicKeystoneProfile:", false)
                end
                -- Check if we have usable M+ data instead of relying on hasRenderableData
                if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
                    Debug(LOG_LEVEL.INFO, "Successfully retrieved profile via GetProfile for:", profile.name or unitOrName)
                    return profile
                elseif profile.hasRenderableData then
                    Debug(LOG_LEVEL.INFO, "Profile has renderable data but no M+ score for:", unitOrName)
                    return profile
                else
                    Debug(LOG_LEVEL.INFO, "GetProfile returned profile but no usable M+ data for:", unitOrName)
                end
            else
                Debug(LOG_LEVEL.INFO, "GetProfile failed for", unitOrName, "- Error:", profile or "unknown")
            end
        end
        
        -- Try GetPlayerProfile as fallback
        if RaiderIO.GetPlayerProfile then
            Debug(LOG_LEVEL.INFO, "Calling RaiderIO.GetPlayerProfile for:", unitOrName)
            local success, profile = pcall(RaiderIO.GetPlayerProfile, unitOrName)
            Debug(LOG_LEVEL.INFO, "GetPlayerProfile result - Success:", success, "Profile exists:", profile ~= nil)
            if success and profile then
                Debug(LOG_LEVEL.INFO, "Profile details - Name:", profile.name, "hasRenderableData:", profile.hasRenderableData)
                if profile.mythicKeystoneProfile then
                    Debug(LOG_LEVEL.INFO, "Has mythicKeystoneProfile:", true)
                    Debug(LOG_LEVEL.INFO, "Current score:", profile.mythicKeystoneProfile.currentScore)
                else
                    Debug(LOG_LEVEL.INFO, "Has mythicKeystoneProfile:", false)
                end
                -- Check if we have usable M+ data instead of relying on hasRenderableData
                if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
                    Debug(LOG_LEVEL.INFO, "Successfully retrieved profile via GetPlayerProfile for:", profile.name or unitOrName)
                    return profile
                elseif profile.hasRenderableData then
                    Debug(LOG_LEVEL.INFO, "Profile has renderable data but no M+ score for:", unitOrName)
                    return profile
                else
                    Debug(LOG_LEVEL.INFO, "GetPlayerProfile returned profile but no usable M+ data for:", unitOrName)
                end
            else
                Debug(LOG_LEVEL.INFO, "GetPlayerProfile failed for", unitOrName, "- Error:", profile or "unknown")
            end
        end
        
        Debug(LOG_LEVEL.DEBUG, "No valid profile found for:", unitOrName)
        return nil, "No valid profile found"
    end
    
    function RaiderIOIntegration:GetMythicPlusScore(unitOrName)
        Debug(LOG_LEVEL.DEBUG, "Getting M+ score for unit/name:", unitOrName)
        
        local profile, err = self:GetProfile(unitOrName)
        if not profile then
            return nil, err
        end
        
        if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.currentScore then
            local score = profile.mythicKeystoneProfile.currentScore
            Debug(LOG_LEVEL.INFO, "M+ score for", profile.name or unitOrName, ":", score)
            return score
        end
        
        Debug(LOG_LEVEL.DEBUG, "No M+ data available for unit/name:", unitOrName)
        return nil, "No M+ data"
    end
    
    function RaiderIOIntegration:GetFormattedScoreWithFallback(characterName)
        Debug(LOG_LEVEL.DEBUG, "Getting formatted score with fallback for:", characterName)
        
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
            Debug(LOG_LEVEL.INFO, "Trying name variant:", nameVariant)
            local score, err = self:GetMythicPlusScore(nameVariant)
            Debug(LOG_LEVEL.INFO, "Result for", nameVariant, "- Score:", score, "Error:", err)
            if score then
                if self:IsAvailable() and RaiderIO.GetScoreColor then
                    local success, r, g, b = pcall(RaiderIO.GetScoreColor, score)
                    if success and r and g and b then
                        local formattedScore = string.format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, score)
                        Debug(LOG_LEVEL.DEBUG, "Formatted score for", nameVariant, ":", formattedScore)
                        return formattedScore
                    else
                        Debug(LOG_LEVEL.WARN, "GetScoreColor failed for score", score, "- Error:", r)
                    end
                end
                
                local fallbackScore = tostring(score)
                Debug(LOG_LEVEL.DEBUG, "Fallback score formatting for", nameVariant, ":", fallbackScore)
                return fallbackScore
            else
                Debug(LOG_LEVEL.INFO, "No score for", nameVariant, "- Reason:", err or "unknown")
            end
        end
        
        Debug(LOG_LEVEL.DEBUG, "No valid score found for any name variant of:", characterName, "- returning 0")
        
        -- Return formatted 0 instead of nil
        if self:IsAvailable() and RaiderIO.GetScoreColor then
            local success, r, g, b = pcall(RaiderIO.GetScoreColor, 0)
            if success and r and g and b then
                local formattedScore = string.format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, 0)
                Debug(LOG_LEVEL.DEBUG, "Formatted 0 score:", formattedScore)
                return formattedScore
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
        if success then
            Debug(LOG_LEVEL.DEBUG, "Successfully added RaiderIO tooltip info")
            return result
        else
            Debug(LOG_LEVEL.ERROR, "Failed to add RaiderIO tooltip info:", result)
            return false
        end
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
                local name = UnitName(unit)
                local score = self:GetMythicPlusScore(unit)
                if score then
                    scores[name] = score
                    Debug(LOG_LEVEL.INFO, "Group member score -", name, ":", score)
                end
            end
        end
        
        local playerScore = self:GetMythicPlusScore("player")
        if playerScore then
            scores[UnitName("player")] = playerScore
            Debug(LOG_LEVEL.INFO, "Player score:", UnitName("player"), ":", playerScore)
        end
        
        Debug(LOG_LEVEL.INFO, "Total group members with scores:", #scores)
        return scores
    end
    
    function RaiderIOIntegration:PrintPlayerInfo(unit)
        unit = unit or "player"
        Debug(LOG_LEVEL.INFO, "Printing RaiderIO info for unit:", unit)
        
        if not self:IsAvailable() then
            print("GrouperPlus: RaiderIO addon not available")
            return
        end
        
        local profile, err = self:GetProfile(unit)
        if not profile then
            print("GrouperPlus: No RaiderIO data available for " .. (UnitName(unit) or unit) .. " (" .. err .. ")")
            return
        end
        
        local name = profile.name or UnitName(unit) or unit
        print("GrouperPlus: RaiderIO Info for " .. name .. ":")
        
        local score = self:GetMythicPlusScore(unit)
        if score then
            print("  Current M+ Score: " .. score)
        end
        
        local prevScore = self:GetPreviousSeasonScore(unit)
        if prevScore then
            print("  Previous Season Score: " .. prevScore)
        end
        
        local completions = self:GetKeystoneCompletions(unit)
        if completions then
            print("  Keystone Completions: " .. completions.fifteenPlus .. " (15+), " .. completions.tenPlus .. " (10+)")
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
            
            Debug(LOG_LEVEL.TRACE, "Adding RaiderIO info to tooltip for unit:", unit)
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