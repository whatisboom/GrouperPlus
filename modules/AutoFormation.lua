local addonName, addon = ...

local AutoFormation = {}

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
    return addon.Utilities:GetPlayerRole(unitOrNameOrMember)
end

function AutoFormation:GetRoleFromClass(playerNameOrMember)
    -- Deprecated - now using shared utilities
    return addon.Utilities:GetPlayerRole(playerNameOrMember)
end

function AutoFormation:ValidateRoleComposition(members)
    local isValid, counts = addon.Utilities:ValidateGroupComposition(members, {
        maxTanks = 1,
        maxHealers = 1,
        maxDPS = 3,
        maxTotal = 5
    })
    
    -- Check for exact composition (1/1/3)
    local perfectComp = counts.TANK == 1 and counts.HEALER == 1 and counts.DPS == 3
    addon.Debug("INFO", "Role composition - Tanks:", counts.TANK, "Healers:", counts.HEALER, "DPS:", counts.DPS, "Valid:", perfectComp)
    
    return perfectComp, counts
end

function AutoFormation:GetMemberUtilities(member)
    addon.Debug("DEBUG", "AutoFormation:GetMemberUtilities called for:", member.name)
    
    local className = member.class
    if not className then
        _, className = UnitClass(member.name)
    end
    
    if not className then
        addon.Debug("DEBUG", "Could not determine class for", member.name, "checking guild roster")
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
        addon.Debug("DEBUG", "Found utilities for", member.name, "class:", className, "utilities:", table.concat(utilities, ", "))
        return utilities
    end
    
    addon.Debug("DEBUG", "No utilities found for", member.name, "class:", className or "unknown")
    return {}
end

function AutoFormation:CalculateGroupUtilityScore(group)
    addon.Debug("DEBUG", "AutoFormation:CalculateGroupUtilityScore called for group with", #group, "members")
    
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
    
    addon.Debug("DEBUG", "Group utility score:", score, 
        "critical missing:", table.concat(criticalMissing, ", "),
        "important missing:", table.concat(importantMissing, ", "))
    
    return score, utilities, criticalMissing, importantMissing
end

function AutoFormation:GetUtilityCoverageGaps(groups)
    addon.Debug("DEBUG", "AutoFormation:GetUtilityCoverageGaps called for", #groups, "groups")
    
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
    
    addon.Debug("INFO", "Utility coverage analysis complete - groups with critical gaps:", 
        overallGaps.critical.COMBAT_REZ or 0, "missing combat rez,",
        overallGaps.critical.BLOODLUST or 0, "missing bloodlust")
    
    return groupUtilities, overallGaps
end

function AutoFormation:GetMemberScore(memberName)
    addon.Debug("DEBUG", "AutoFormation:GetMemberScore called for:", memberName)
    
    -- Use existing RaiderIO integration with shared data support
    if addon.RaiderIOIntegration and addon.RaiderIOIntegration:IsAvailable() then
        -- First try local RaiderIO data
        local profile = addon.RaiderIOIntegration:GetProfile(memberName)
        if profile and profile.mythicKeystoneProfile then
            local score = profile.mythicKeystoneProfile.currentScore or 0
            addon.Debug("INFO", "Found local RaiderIO score for", memberName, ":", score)
            return score
        end
        
        -- If no local data, try shared data from other addon users
        if addon.RaiderIOIntegration.GetMythicPlusScoreWithSharedData then
            local sharedScore = addon.RaiderIOIntegration:GetMythicPlusScoreWithSharedData(memberName)
            if sharedScore and sharedScore > 0 then
                addon.Debug("INFO", "Found shared RaiderIO score for", memberName, ":", sharedScore)
                return sharedScore
            end
        end
    end
    
    addon.Debug("DEBUG", "No RaiderIO score found for", memberName, "using default score 0")
    return 0 -- Default score if no RaiderIO data
end

function AutoFormation:SortMembersByScore(members)
    addon.Debug("DEBUG", "AutoFormation:SortMembersByScore called with", #members, "members")
    
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
        addon.Debug("TRACE", "Member", member.name, "score:", memberCopy.score, "role:", memberCopy.role)
    end
    
    table.sort(membersWithScores, function(a, b)
        return a.score > b.score
    end)
    
    addon.Debug("INFO", "Sorted members by score - highest:", membersWithScores[1] and membersWithScores[1].score or "none")
    return membersWithScores
end

function AutoFormation:CreateBalancedGroups(availableMembers, groupSize)
    addon.Debug("INFO", "AutoFormation:CreateBalancedGroups called with", #availableMembers, "members, group size:", groupSize or 5)
    
    -- Debug the input members
    for i, member in ipairs(availableMembers) do
        addon.Debug("DEBUG", "Input member", i, ":", member.name, "class:", member.class)
    end
    
    groupSize = groupSize or 5
    local sortedMembers = self:SortMembersByScore(availableMembers)
    local groups = {}
    
    if #sortedMembers == 0 then
        addon.Debug("WARN", "No members available for grouping")
        return groups
    end
    
    addon.Debug("INFO", "After sorting, have", #sortedMembers, "members with scores")
    
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
    
    addon.Debug("INFO", "Available roles - Tanks:", #tanks, "Healers:", #healers, "DPS:", #dps)
    
    -- Try ideal composition first (1 tank, 1 healer, 3 DPS)
    local idealGroups = math.min(#tanks, #healers, math.floor(#dps / 3))
    addon.Debug("INFO", "Can create", idealGroups, "ideal groups")
    
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
        
        addon.Debug("INFO", "Created ideal group", i, "with 5 members")
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
    
    addon.Debug("INFO", "Remaining members - Tanks:", #remainingTanks, "Healers:", #remainingHealers, "DPS:", #remainingDPS)
    
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
            addon.Debug("WARN", "No more members can be added while respecting role limits")
            break
        end
        
        -- Add the group
        table.insert(groups, currentGroup)
        addon.Debug("INFO", "Created leftover group with", #currentGroup, "members - Tanks:", groupTanks, "Healers:", groupHealers, "DPS:", groupDPS)
    end
    
    addon.Debug("INFO", "Auto-formation complete - created", #groups, "total groups")
    
    -- Apply utility optimization to improve group compositions
    if #groups > 1 then
        addon.Debug("INFO", "Applying utility optimization to", #groups, "groups")
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
        
        addon.Debug("INFO", "Final group", i, "has", #group, "members, utility score:", utilityScore)
        addon.Debug("INFO", "  Utilities:", table.concat(utilityList, ", "))
        for j, member in ipairs(group) do
            addon.Debug("DEBUG", "  Member", j, ":", member.name, "role:", member.role, "score:", member.score)
        end
    end
    
    -- Sync group formation with other addon users
    if addon.AddonComm and addon.settings.communication and addon.settings.communication.enabled then
        addon.AddonComm:SyncGroupFormation(groups)
    end
    
    return groups
end

function AutoFormation:OptimizeGroupUtilities(groups)
    addon.Debug("INFO", "AutoFormation:OptimizeGroupUtilities called with", #groups, "groups")
    
    local maxIterations = 10 -- Prevent infinite loops
    local improved = true
    local iteration = 0
    
    while improved and iteration < maxIterations do
        improved = false
        iteration = iteration + 1
        addon.Debug("DEBUG", "Utility optimization iteration", iteration)
        
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
                            addon.Debug("INFO", "Beneficial swap found: exchanging", 
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
            addon.Debug("DEBUG", "No more beneficial swaps found after", iteration, "iterations")
        end
    end
    
    if iteration >= maxIterations then
        addon.Debug("WARN", "Utility optimization reached maximum iterations (", maxIterations, ")")
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
    
    addon.Debug("INFO", "Utility optimization complete after", iteration, "iterations")
    addon.Debug("INFO", "Final gaps - Critical:", totalCriticalGaps, "Important:", totalImportantGaps)
    
    return groups
end

-- Make the module available to the addon
addon.AutoFormation = AutoFormation