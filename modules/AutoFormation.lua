local addonName, addon = ...

local AutoFormation = {}

for k, v in pairs(addon.DebugMixin) do
    AutoFormation[k] = v
end
AutoFormation:InitDebug("AutoForm")

-- Role mapping for all specializations
local SPEC_ROLE_MAP = {
    -- Death Knight
    [250] = "TANK",   -- Blood
    [251] = "DPS",    -- Frost
    [252] = "DPS",    -- Unholy
    
    -- Demon Hunter
    [577] = "TANK",   -- Vengeance
    [581] = "DPS",    -- Havoc
    
    -- Druid
    [102] = "DPS",    -- Balance
    [103] = "DPS",    -- Feral
    [104] = "TANK",   -- Guardian
    [105] = "HEALER", -- Restoration
    
    -- Evoker
    [1467] = "DPS",   -- Devastation
    [1468] = "HEALER", -- Preservation
    [1473] = "DPS",   -- Augmentation
    
    -- Hunter
    [253] = "DPS",    -- Beast Mastery
    [254] = "DPS",    -- Marksmanship
    [255] = "DPS",    -- Survival
    
    -- Mage
    [62] = "DPS",     -- Arcane
    [63] = "DPS",     -- Fire
    [64] = "DPS",     -- Frost
    
    -- Monk
    [268] = "TANK",   -- Brewmaster
    [269] = "DPS",    -- Windwalker
    [270] = "HEALER", -- Mistweaver
    
    -- Paladin
    [65] = "HEALER",  -- Holy
    [66] = "TANK",    -- Protection
    [70] = "DPS",     -- Retribution
    
    -- Priest
    [256] = "HEALER", -- Discipline
    [257] = "HEALER", -- Holy
    [258] = "DPS",    -- Shadow
    
    -- Rogue
    [259] = "DPS",    -- Assassination
    [260] = "DPS",    -- Outlaw
    [261] = "DPS",    -- Subtlety
    
    -- Shaman
    [262] = "DPS",    -- Elemental
    [263] = "DPS",    -- Enhancement
    [264] = "HEALER", -- Restoration
    
    -- Warlock
    [265] = "DPS",    -- Affliction
    [266] = "DPS",    -- Demonology
    [267] = "DPS",    -- Destruction
    
    -- Warrior
    [71] = "DPS",     -- Arms
    [72] = "DPS",     -- Fury
    [73] = "TANK",    -- Protection
}

-- Class fallback roles (for when spec detection fails)
local CLASS_FALLBACK_ROLES = {
    DEATHKNIGHT = { "TANK", "DPS" },
    DEMONHUNTER = { "TANK", "DPS" },
    DRUID = { "TANK", "HEALER", "DPS" },
    EVOKER = { "HEALER", "DPS" },
    HUNTER = { "DPS" },
    MAGE = { "DPS" },
    MONK = { "TANK", "HEALER", "DPS" },
    PALADIN = { "TANK", "HEALER", "DPS" },
    PRIEST = { "HEALER", "DPS" },
    ROGUE = { "DPS" },
    SHAMAN = { "HEALER", "DPS" },
    WARLOCK = { "DPS" },
    WARRIOR = { "TANK", "DPS" }
}

function AutoFormation:GetPlayerRole(unitOrNameOrMember)
    AutoFormation.Debug("DEBUG", "AutoFormation:GetPlayerRole called for:", type(unitOrNameOrMember) == "table" and unitOrNameOrMember.name or unitOrNameOrMember)
    
    local unit = unitOrNameOrMember
    local playerName = nil
    local memberData = nil
    
    -- If we got a member table, extract the name
    if type(unitOrNameOrMember) == "table" then
        memberData = unitOrNameOrMember
        playerName = memberData.name
        unit = playerName
    end
    
    -- Handle both unit strings and player names
    if not UnitExists(unit) then
        -- Try to find the player by name
        playerName = unit
        local currentPlayerName = UnitName("player")
        local currentPlayerFullName = currentPlayerName .. "-" .. GetRealmName()
        if playerName == currentPlayerName or playerName == currentPlayerFullName then
            unit = "player"
        else
            -- For guild members not in group, we can't get their spec directly
            -- Fall back to class-based role detection
            AutoFormation.Debug("DEBUG", "Player not in unit range, using class fallback for:", playerName)
            return self:GetRoleFromClass(memberData or playerName)
        end
    else
        local name, realm = UnitName(unit)
        playerName = realm and (name .. "-" .. realm) or name
    end
    
    -- Check for received player data first (more recent than inspect API)
    -- But skip this for the current player - we always want fresh data for ourselves
    if addon.receivedPlayerData and playerName and unit ~= "player" then
        AutoFormation.Debug("DEBUG", "Checking received player data for:", playerName)
        if addon.receivedPlayerData then
            local keys = {}
            for k, _ in pairs(addon.receivedPlayerData) do
                table.insert(keys, k)
            end
            AutoFormation.Debug("DEBUG", "Available received data keys:", table.concat(keys, ", "))
        else
            AutoFormation.Debug("DEBUG", "No receivedPlayerData table found")
        end
        
        -- Try direct match first
        local receivedData = addon.receivedPlayerData[playerName]
        if not receivedData and playerName then
            -- Try cross-realm matching
            local baseName = string.match(playerName, "^(.+)%-") or playerName
            AutoFormation.Debug("DEBUG", "No direct match, trying cross-realm match for base name:", baseName)
            for name, data in pairs(addon.receivedPlayerData) do
                local nameBase = string.match(name, "^(.+)%-") or name
                if nameBase == baseName then
                    AutoFormation.Debug("DEBUG", "Found cross-realm match:", name)
                    receivedData = data
                    break
                end
            end
        end
        
        if receivedData and receivedData.role then
            AutoFormation.Debug("INFO", "Using received player data for", playerName, "role:", receivedData.role)
            return receivedData.role
        else
            AutoFormation.Debug("DEBUG", "No received data found for", playerName, "or data missing role")
        end
    end
    
    -- Try to get the player's current specialization
    local specIndex
    if unit == "player" then
        -- For the current player, use GetSpecializationInfo to get the spec ID
        local currentSpec = GetSpecialization()
        if currentSpec then
            local specID, specName, description, icon, role, isRecommended, isAllowed = GetSpecializationInfo(currentSpec)
            specIndex = specID
        end
    else
        -- For other units, use GetInspectSpecialization
        specIndex = GetInspectSpecialization(unit)
    end
    
    if specIndex and specIndex > 0 then
        local role = SPEC_ROLE_MAP[specIndex]
        if role then
            AutoFormation.Debug("INFO", "Found role for", playerName, "spec", specIndex, "role:", role)
            return role
        end
    end
    
    -- Fallback to class-based detection
    AutoFormation.Debug("DEBUG", "Spec detection failed, using class fallback for:", playerName)
    return self:GetRoleFromClass(playerName)
end

function AutoFormation:GetRoleFromClass(playerNameOrMember)
    AutoFormation.Debug("DEBUG", "AutoFormation:GetRoleFromClass called for:", type(playerNameOrMember) == "table" and playerNameOrMember.name or playerNameOrMember)
    
    local playerName = playerNameOrMember
    local className = nil
    
    -- If we got a member table with class info, use it directly
    if type(playerNameOrMember) == "table" then
        className = playerNameOrMember.class
        playerName = playerNameOrMember.name
        AutoFormation.Debug("DEBUG", "Using class from member object:", className)
    end
    
    -- If no class yet, try UnitClass
    if not className then
        _, className = UnitClass(playerName)
    end
    
    if not className then
        AutoFormation.Debug("DEBUG", "UnitClass failed for", playerName, ", checking guild roster")
        -- Try to get class from guild roster
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name == playerName then
                className = classFileName
                AutoFormation.Debug("DEBUG", "Found class in guild roster:", className)
                break
            end
        end
    end
    
    if className and CLASS_FALLBACK_ROLES[className] then
        local possibleRoles = CLASS_FALLBACK_ROLES[className]
        AutoFormation.Debug("DEBUG", "Class fallback for", playerName, "class:", className, "possible roles:", table.concat(possibleRoles, ", "))
        
        -- For multi-role classes, prefer DPS as the default since it's most common
        -- Unless the class can ONLY tank or ONLY heal
        for _, role in ipairs(possibleRoles) do
            if role == "DPS" then
                AutoFormation.Debug("DEBUG", "Defaulting to DPS role for multi-role class:", className)
                return "DPS"
            end
        end
        
        -- If class can't DPS, return the first available role
        return possibleRoles[1]
    end
    
    AutoFormation.Debug("WARN", "Could not determine role for player:", playerName)
    return "DPS" -- Default fallback
end

function AutoFormation:ValidateRoleComposition(members)
    AutoFormation.Debug("DEBUG", "AutoFormation:ValidateRoleComposition called with", #members, "members")
    
    local roleCounts = {
        TANK = 0,
        HEALER = 0,
        DPS = 0
    }
    
    for _, member in ipairs(members) do
        local role = self:GetPlayerRole(member.name)
        roleCounts[role] = roleCounts[role] + 1
        AutoFormation.Debug("TRACE", "Member", member.name, "assigned role:", role)
    end
    
    AutoFormation.Debug("INFO", "Role composition - Tanks:", roleCounts.TANK, "Healers:", roleCounts.HEALER, "DPS:", roleCounts.DPS)
    
    -- Check if composition follows mythic+ rules (1 tank, 1 healer, 3 DPS)
    local isValid = roleCounts.TANK == 1 and roleCounts.HEALER == 1 and roleCounts.DPS == 3
    AutoFormation.Debug("INFO", "Role composition valid:", isValid)
    
    return isValid, roleCounts
end

function AutoFormation:GetMemberUtilities(member)
    AutoFormation.Debug("DEBUG", "AutoFormation:GetMemberUtilities called for:", member.name)
    
    local className = member.class
    if not className then
        _, className = UnitClass(member.name)
    end
    
    if not className then
        AutoFormation.Debug("DEBUG", "Could not determine class for", member.name, "checking guild roster")
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name == member.name then
                className = classFileName
                break
            end
        end
    end
    
    if className and addon.CLASS_UTILITIES[className] then
        local utilities = addon.CLASS_UTILITIES[className]
        AutoFormation.Debug("DEBUG", "Found utilities for", member.name, "class:", className, "utilities:", table.concat(utilities, ", "))
        return utilities
    end
    
    AutoFormation.Debug("DEBUG", "No utilities found for", member.name, "class:", className or "unknown")
    return {}
end

function AutoFormation:CalculateGroupUtilityScore(group)
    AutoFormation.Debug("DEBUG", "AutoFormation:CalculateGroupUtilityScore called for group with", #group, "members")
    
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
    
    -- Check what utilities this group provides
    for _, member in ipairs(group) do
        local memberUtilities = self:GetMemberUtilities(member)
        for _, utility in ipairs(memberUtilities) do
            if utilities[utility] ~= nil then
                utilities[utility] = true
            end
        end
    end
    
    local score = 0
    local criticalMissing = {}
    local importantMissing = {}
    
    -- Calculate penalties and bonuses based on utility priorities
    for utilityName, hasUtility in pairs(utilities) do
        local utilityInfo = addon.UTILITY_INFO[utilityName]
        if utilityInfo then
            if hasUtility then
                -- Bonus for having the utility
                if utilityInfo.priority == 1 then
                    score = score + 100 -- Critical utilities
                elseif utilityInfo.priority == 2 then
                    score = score + 50  -- Important utilities
                else
                    score = score + 25  -- Nice-to-have utilities
                end
            else
                -- Penalty for missing the utility
                if utilityInfo.priority == 1 then
                    score = score - 200 -- Heavy penalty for missing critical utilities
                    table.insert(criticalMissing, utilityName)
                elseif utilityInfo.priority == 2 then
                    score = score - 75  -- Moderate penalty for missing important utilities
                    table.insert(importantMissing, utilityName)
                end
                -- No penalty for missing nice-to-have utilities
            end
        end
    end
    
    AutoFormation.Debug("DEBUG", "Group utility score:", score, 
        "critical missing:", table.concat(criticalMissing, ", "),
        "important missing:", table.concat(importantMissing, ", "))
    
    return score, utilities, criticalMissing, importantMissing
end

function AutoFormation:GetUtilityCoverageGaps(groups)
    AutoFormation.Debug("DEBUG", "AutoFormation:GetUtilityCoverageGaps called for", #groups, "groups")
    
    local groupUtilities = {}
    local overallGaps = {
        critical = {},
        important = {}
    }
    
    for i, group in ipairs(groups) do
        local score, utilities, criticalMissing, importantMissing = self:CalculateGroupUtilityScore(group)
        groupUtilities[i] = {
            score = score,
            utilities = utilities,
            criticalMissing = criticalMissing,
            importantMissing = importantMissing
        }
        
        -- Track overall gaps
        for _, utility in ipairs(criticalMissing) do
            overallGaps.critical[utility] = (overallGaps.critical[utility] or 0) + 1
        end
        for _, utility in ipairs(importantMissing) do
            overallGaps.important[utility] = (overallGaps.important[utility] or 0) + 1
        end
    end
    
    AutoFormation.Debug("INFO", "Utility coverage analysis complete - groups with critical gaps:", 
        overallGaps.critical.COMBAT_REZ or 0, "missing combat rez,",
        overallGaps.critical.BLOODLUST or 0, "missing bloodlust")
    
    return groupUtilities, overallGaps
end

function AutoFormation:GetMemberScore(memberName)
    AutoFormation.Debug("DEBUG", "AutoFormation:GetMemberScore called for:", memberName)
    
    -- Use existing RaiderIO integration with shared data support
    if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
        -- First try local RaiderIO data
        local profile = addon.RaiderIOIntegration:GetProfile(memberName)
        if profile and profile.mythicKeystoneProfile then
            local score = profile.mythicKeystoneProfile.currentScore or 0
            AutoFormation.Debug("INFO", "Found local RaiderIO score for", memberName, ":", score)
            return score
        end
        
        -- If no local data, try shared data from other addon users
        if addon.RaiderIOIntegration.GetMythicPlusScoreWithSharedData then
            local sharedScore = addon.RaiderIOIntegration:GetMythicPlusScoreWithSharedData(memberName)
            if sharedScore and sharedScore > 0 then
                AutoFormation.Debug("INFO", "Found shared RaiderIO score for", memberName, ":", sharedScore)
                return sharedScore
            end
        end
    end
    
    AutoFormation.Debug("DEBUG", "No RaiderIO score found for", memberName, "using default score 0")
    return 0 -- Default score if no RaiderIO data
end

function AutoFormation:SortMembersByScore(members)
    AutoFormation.Debug("DEBUG", "AutoFormation:SortMembersByScore called with", #members, "members")
    
    -- Add scores to members and sort by score descending
    local membersWithScores = {}
    for _, member in ipairs(members) do
        local memberCopy = {}
        for k, v in pairs(member) do
            memberCopy[k] = v
        end
        memberCopy.score = self:GetMemberScore(member.name)
        memberCopy.role = self:GetPlayerRole(member.name)
        table.insert(membersWithScores, memberCopy)
        AutoFormation.Debug("TRACE", "Member", member.name, "score:", memberCopy.score, "role:", memberCopy.role)
    end
    
    table.sort(membersWithScores, function(a, b)
        return a.score > b.score
    end)
    
    AutoFormation.Debug("INFO", "Sorted members by score - highest:", membersWithScores[1] and membersWithScores[1].score or "none")
    return membersWithScores
end

function AutoFormation:CreateBalancedGroups(availableMembers, groupSize)
    AutoFormation.Debug("INFO", "AutoFormation:CreateBalancedGroups called with", #availableMembers, "members, group size:", groupSize or 5)
    
    -- Debug the input members
    for i, member in ipairs(availableMembers) do
        AutoFormation.Debug("DEBUG", "Input member", i, ":", member.name, "class:", member.class)
    end
    
    groupSize = groupSize or 5
    local sortedMembers = self:SortMembersByScore(availableMembers)
    local groups = {}
    
    if #sortedMembers == 0 then
        AutoFormation.Debug("WARN", "No members available for grouping")
        return groups
    end
    
    AutoFormation.Debug("INFO", "After sorting, have", #sortedMembers, "members with scores")
    
    -- Separate members by role
    local tanks = {}
    local healers = {}
    local dps = {}
    
    for _, member in ipairs(sortedMembers) do
        if member.role == "TANK" then
            table.insert(tanks, member)
        elseif member.role == "HEALER" then
            table.insert(healers, member)
        else
            table.insert(dps, member)
        end
    end
    
    AutoFormation.Debug("INFO", "Available roles - Tanks:", #tanks, "Healers:", #healers, "DPS:", #dps)
    
    -- Try ideal composition first (1 tank, 1 healer, 3 DPS)
    local idealGroups = math.min(#tanks, #healers, math.floor(#dps / 3))
    AutoFormation.Debug("INFO", "Can create", idealGroups, "ideal groups")
    
    local usedTanks, usedHealers, usedDPS = 0, 0, 0
    
    -- Create ideal groups first
    for i = 1, idealGroups do
        local group = {
            tanks[i],
            healers[i],
            dps[usedDPS + 1],
            dps[usedDPS + 2],
            dps[usedDPS + 3]
        }
        
        table.insert(groups, group)
        usedTanks = usedTanks + 1
        usedHealers = usedHealers + 1
        usedDPS = usedDPS + 3
        
        AutoFormation.Debug("INFO", "Created ideal group", i, "with 5 members")
    end
    
    -- Now handle remaining members - create groups respecting role limits
    local remainingTanks = {}
    local remainingHealers = {}
    local remainingDPS = {}
    
    -- Collect unused members by role
    for i = usedTanks + 1, #tanks do
        table.insert(remainingTanks, tanks[i])
    end
    
    for i = usedHealers + 1, #healers do
        table.insert(remainingHealers, healers[i])
    end
    
    for i = usedDPS + 1, #dps do
        table.insert(remainingDPS, dps[i])
    end
    
    AutoFormation.Debug("INFO", "Remaining members - Tanks:", #remainingTanks, "Healers:", #remainingHealers, "DPS:", #remainingDPS)
    
    -- Create additional groups with remaining members, respecting role limits
    while #remainingTanks > 0 or #remainingHealers > 0 or #remainingDPS > 0 do
        local currentGroup = {}
        local groupTanks = 0
        local groupHealers = 0
        local groupDPS = 0
        
        -- Add up to 1 tank
        if #remainingTanks > 0 and groupTanks < 1 then
            table.insert(currentGroup, table.remove(remainingTanks, 1))
            groupTanks = groupTanks + 1
        end
        
        -- Add up to 1 healer
        if #remainingHealers > 0 and groupHealers < 1 then
            table.insert(currentGroup, table.remove(remainingHealers, 1))
            groupHealers = groupHealers + 1
        end
        
        -- Add up to 3 DPS
        while #remainingDPS > 0 and groupDPS < 3 and #currentGroup < groupSize do
            table.insert(currentGroup, table.remove(remainingDPS, 1))
            groupDPS = groupDPS + 1
        end
        
        -- If we couldn't add any members, break to avoid infinite loop
        if #currentGroup == 0 then
            AutoFormation.Debug("WARN", "No more members can be added while respecting role limits")
            break
        end
        
        -- Add the group
        table.insert(groups, currentGroup)
        AutoFormation.Debug("INFO", "Created leftover group with", #currentGroup, "members - Tanks:", groupTanks, "Healers:", groupHealers, "DPS:", groupDPS)
    end
    
    AutoFormation.Debug("INFO", "Auto-formation complete - created", #groups, "total groups")
    
    -- Apply utility optimization to improve group compositions
    if #groups > 1 then
        AutoFormation.Debug("INFO", "Applying utility optimization to", #groups, "groups")
        groups = self:OptimizeGroupUtilities(groups)
    end
    
    -- Debug the final groups with utility information
    for i, group in ipairs(groups) do
        local utilityScore, utilities = self:CalculateGroupUtilityScore(group)
        local utilityList = {}
        for utilityName, hasUtility in pairs(utilities) do
            if hasUtility then
                table.insert(utilityList, utilityName)
            end
        end
        
        AutoFormation.Debug("INFO", "Final group", i, "has", #group, "members, utility score:", utilityScore)
        AutoFormation.Debug("INFO", "  Utilities:", table.concat(utilityList, ", "))
        for j, member in ipairs(group) do
            AutoFormation.Debug("DEBUG", "  Member", j, ":", member.name, "role:", member.role, "score:", member.score)
        end
    end
    
    -- Sync group formation with other addon users
    if addon.AddonComm and addon.settings.communication and addon.settings.communication.enabled then
        addon.AddonComm:SyncGroupFormation(groups)
    end
    
    return groups
end

function AutoFormation:OptimizeGroupUtilities(groups)
    AutoFormation.Debug("INFO", "AutoFormation:OptimizeGroupUtilities called with", #groups, "groups")
    
    local maxIterations = 10 -- Prevent infinite loops
    local improved = true
    local iteration = 0
    
    while improved and iteration < maxIterations do
        improved = false
        iteration = iteration + 1
        AutoFormation.Debug("DEBUG", "Utility optimization iteration", iteration)
        
        -- Get current utility analysis
        local groupUtilities, overallGaps = self:GetUtilityCoverageGaps(groups)
        
        -- Try to improve groups by swapping DPS members
        for i = 1, #groups do
            for j = i + 1, #groups do
                local group1 = groups[i]
                local group2 = groups[j]
                
                -- Find DPS members in both groups
                local group1DPS = {}
                local group2DPS = {}
                
                for k, member in ipairs(group1) do
                    if member.role == "DPS" then
                        table.insert(group1DPS, {index = k, member = member})
                    end
                end
                
                for k, member in ipairs(group2) do
                    if member.role == "DPS" then
                        table.insert(group2DPS, {index = k, member = member})
                    end
                end
                
                -- Try swapping DPS members between groups
                for _, dps1 in ipairs(group1DPS) do
                    for _, dps2 in ipairs(group2DPS) do
                        -- Calculate current utility scores
                        local currentScore1 = groupUtilities[i].score
                        local currentScore2 = groupUtilities[j].score
                        local currentTotal = currentScore1 + currentScore2
                        
                        -- Temporarily swap members
                        group1[dps1.index] = dps2.member
                        group2[dps2.index] = dps1.member
                        
                        -- Calculate new utility scores
                        local newScore1 = self:CalculateGroupUtilityScore(group1)
                        local newScore2 = self:CalculateGroupUtilityScore(group2)
                        local newTotal = newScore1 + newScore2
                        
                        -- Check if this swap improves overall utility distribution
                        if newTotal > currentTotal then
                            AutoFormation.Debug("INFO", "Beneficial swap found: exchanging", 
                                dps1.member.name, "and", dps2.member.name,
                                "improved total score from", currentTotal, "to", newTotal)
                            
                            -- Keep the swap and update our tracking
                            groupUtilities[i].score = newScore1
                            groupUtilities[j].score = newScore2
                            improved = true
                            break
                        else
                            -- Revert the swap
                            group1[dps1.index] = dps1.member
                            group2[dps2.index] = dps2.member
                        end
                    end
                    
                    if improved then break end
                end
                
                if improved then break end
            end
            
            if improved then break end
        end
        
        if not improved then
            AutoFormation.Debug("DEBUG", "No more beneficial swaps found after", iteration, "iterations")
        end
    end
    
    if iteration >= maxIterations then
        AutoFormation.Debug("WARN", "Utility optimization reached maximum iterations (", maxIterations, ")")
    end
    
    -- Final utility analysis
    local finalUtilities, finalGaps = self:GetUtilityCoverageGaps(groups)
    local totalCriticalGaps = 0
    local totalImportantGaps = 0
    
    for utility, count in pairs(finalGaps.critical) do
        totalCriticalGaps = totalCriticalGaps + count
    end
    for utility, count in pairs(finalGaps.important) do
        totalImportantGaps = totalImportantGaps + count
    end
    
    AutoFormation.Debug("INFO", "Utility optimization complete after", iteration, "iterations")
    AutoFormation.Debug("INFO", "Final gaps - Critical:", totalCriticalGaps, "Important:", totalImportantGaps)
    
    return groups
end

-- Make the module available to the addon
addon.AutoFormation = AutoFormation