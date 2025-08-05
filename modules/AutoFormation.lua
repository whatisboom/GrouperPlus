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
    addon.Debug("DEBUG", "AutoFormation:GetPlayerRole called for:", type(unitOrNameOrMember) == "table" and unitOrNameOrMember.name or unitOrNameOrMember)
    
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
        if playerName == UnitName("player") then
            unit = "player"
        else
            -- For guild members not in group, we can't get their spec directly
            -- Fall back to class-based role detection
            addon.Debug("DEBUG", "Player not in unit range, using class fallback for:", playerName)
            return self:GetRoleFromClass(memberData or playerName)
        end
    else
        playerName = UnitName(unit)
    end
    
    -- Try to get the player's current specialization
    local specIndex = GetInspectSpecialization(unit)
    if specIndex and specIndex > 0 then
        local role = SPEC_ROLE_MAP[specIndex]
        if role then
            addon.Debug("INFO", "Found role for", playerName, "spec", specIndex, "role:", role)
            return role
        end
    end
    
    -- Fallback to class-based detection
    addon.Debug("DEBUG", "Spec detection failed, using class fallback for:", playerName)
    return self:GetRoleFromClass(playerName)
end

function AutoFormation:GetRoleFromClass(playerNameOrMember)
    addon.Debug("DEBUG", "AutoFormation:GetRoleFromClass called for:", type(playerNameOrMember) == "table" and playerNameOrMember.name or playerNameOrMember)
    
    local playerName = playerNameOrMember
    local className = nil
    
    -- If we got a member table with class info, use it directly
    if type(playerNameOrMember) == "table" then
        className = playerNameOrMember.class
        playerName = playerNameOrMember.name
        addon.Debug("DEBUG", "Using class from member object:", className)
    end
    
    -- If no class yet, try UnitClass
    if not className then
        _, className = UnitClass(playerName)
    end
    
    if not className then
        addon.Debug("DEBUG", "UnitClass failed for", playerName, ", checking guild roster")
        -- Try to get class from guild roster
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local name, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name == playerName then
                className = classFileName
                addon.Debug("DEBUG", "Found class in guild roster:", className)
                break
            end
        end
    end
    
    if className and CLASS_FALLBACK_ROLES[className] then
        local possibleRoles = CLASS_FALLBACK_ROLES[className]
        addon.Debug("DEBUG", "Class fallback for", playerName, "class:", className, "possible roles:", table.concat(possibleRoles, ", "))
        
        -- For multi-role classes, prefer DPS as the default since it's most common
        -- Unless the class can ONLY tank or ONLY heal
        for _, role in ipairs(possibleRoles) do
            if role == "DPS" then
                addon.Debug("DEBUG", "Defaulting to DPS role for multi-role class:", className)
                return "DPS"
            end
        end
        
        -- If class can't DPS, return the first available role
        return possibleRoles[1]
    end
    
    addon.Debug("WARN", "Could not determine role for player:", playerName)
    return "DPS" -- Default fallback
end

function AutoFormation:ValidateRoleComposition(members)
    addon.Debug("DEBUG", "AutoFormation:ValidateRoleComposition called with", #members, "members")
    
    local roleCounts = {
        TANK = 0,
        HEALER = 0,
        DPS = 0
    }
    
    for _, member in ipairs(members) do
        local role = self:GetPlayerRole(member.name)
        roleCounts[role] = roleCounts[role] + 1
        addon.Debug("TRACE", "Member", member.name, "assigned role:", role)
    end
    
    addon.Debug("INFO", "Role composition - Tanks:", roleCounts.TANK, "Healers:", roleCounts.HEALER, "DPS:", roleCounts.DPS)
    
    -- Check if composition follows mythic+ rules (1 tank, 1 healer, 3 DPS)
    local isValid = roleCounts.TANK == 1 and roleCounts.HEALER == 1 and roleCounts.DPS == 3
    addon.Debug("INFO", "Role composition valid:", isValid)
    
    return isValid, roleCounts
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
    
    -- Debug the final groups
    for i, group in ipairs(groups) do
        addon.Debug("INFO", "Final group", i, "has", #group, "members:")
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

-- Make the module available to the addon
addon.AutoFormation = AutoFormation