local addonName, addon = ...
local Utilities = {}
addon.Utilities = Utilities

local Debug = addon.Debug or function() end

local function GetPlayerRoleFromSpec(unit)
    Debug("TRACE", "GetPlayerRoleFromSpec called for unit:", unit)
    
    if not unit or not UnitExists(unit) then
        Debug("DEBUG", "GetPlayerRoleFromSpec: Unit does not exist:", unit)
        return nil
    end
    
    local specIndex
    if unit == "player" then
        specIndex = GetSpecialization()
    else
        specIndex = GetInspectSpecialization(unit)
    end
    
    if not specIndex or specIndex == 0 then
        Debug("DEBUG", "GetPlayerRoleFromSpec: No spec found for unit:", unit)
        return nil
    end
    
    local role = GetSpecializationRole(specIndex)
    Debug("DEBUG", "GetPlayerRoleFromSpec: Found role", role, "for spec", specIndex)
    
    if role == "TANK" then
        return "TANK"
    elseif role == "HEALER" then
        return "HEALER"
    elseif role == "DAMAGER" then
        return "DPS"
    else
        return "DPS"
    end
end

local function GetRoleFromClass(className)
    Debug("TRACE", "GetRoleFromClass called for class:", className)
    
    if not className then
        Debug("DEBUG", "GetRoleFromClass: No class provided")
        return "DPS"
    end
    
    local classUpper = string.upper(className)
    
    local tankCapableClasses = {
        WARRIOR = true,
        PALADIN = true,
        DEATHKNIGHT = true,
        DEMONHUNTER = true,
        MONK = true,
        DRUID = true
    }
    
    local healerCapableClasses = {
        PRIEST = true,
        PALADIN = true,
        SHAMAN = true,
        DRUID = true,
        MONK = true,
        EVOKER = true
    }
    
    if healerCapableClasses[classUpper] then
        return "HEALER"
    elseif tankCapableClasses[classUpper] then
        return "TANK"
    else
        return "DPS"
    end
end

function Utilities:GetPlayerRole(unitOrNameOrMember)
    Debug("DEBUG", "Utilities:GetPlayerRole called for:", 
        type(unitOrNameOrMember) == "table" and unitOrNameOrMember.name or unitOrNameOrMember)
    
    local unit = unitOrNameOrMember
    local playerName = nil
    local memberData = nil
    local className = nil
    
    if type(unitOrNameOrMember) == "table" then
        memberData = unitOrNameOrMember
        playerName = memberData.name
        className = memberData.class
        unit = playerName
    elseif type(unitOrNameOrMember) == "string" then
        if UnitExists(unitOrNameOrMember) then
            unit = unitOrNameOrMember
            playerName = UnitName(unit)
            className = select(2, UnitClass(unit))
        else
            playerName = unitOrNameOrMember
            unit = nil
        end
    end
    
    if unit and UnitExists(unit) then
        local specRole = GetPlayerRoleFromSpec(unit)
        if specRole then
            Debug("INFO", "Utilities:GetPlayerRole: Found spec-based role", specRole, "for", playerName or unit)
            return specRole
        end
        
        if not className then
            className = select(2, UnitClass(unit))
        end
    end
    
    if unit == "player" or (playerName and playerName == UnitName("player")) then
        local specRole = GetPlayerRoleFromSpec("player")
        if specRole then
            Debug("INFO", "Utilities:GetPlayerRole: Found player spec role:", specRole)
            return specRole
        end
        
        if not className then
            className = select(2, UnitClass("player"))
        end
    end
    
    if className then
        local classRole = GetRoleFromClass(className)
        Debug("INFO", "Utilities:GetPlayerRole: Using class-based role", classRole, "for", playerName or unit)
        return classRole
    end
    
    if memberData and memberData.role then
        Debug("INFO", "Utilities:GetPlayerRole: Using cached role", memberData.role, "for", playerName)
        return memberData.role
    end
    
    Debug("WARN", "Utilities:GetPlayerRole: Could not determine role for", playerName or unit, "- defaulting to DPS")
    return "DPS"
end

function Utilities:GetRolePriority(role)
    local priorities = {
        TANK = 1,
        HEALER = 2,
        DPS = 3
    }
    return priorities[role] or 999
end

function Utilities:CheckGroupUtilities(members)
    Debug("TRACE", "Utilities:CheckGroupUtilities called with", members and #members or 0, "members")
    
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
    
    if not members then
        return utilities
    end
    
    for _, member in pairs(members) do
        if member and member.class then
            local className = string.upper(member.class)
            local classUtilities = addon.CLASS_UTILITIES and addon.CLASS_UTILITIES[className]
            
            if classUtilities then
                for _, utility in ipairs(classUtilities) do
                    utilities[utility] = true
                end
            end
        end
    end
    
    Debug("DEBUG", "Utilities:CheckGroupUtilities results:", 
        "brez:", utilities.COMBAT_REZ, "lust:", utilities.BLOODLUST,
        "int:", utilities.INTELLECT, "stam:", utilities.STAMINA)
    
    return utilities
end

function Utilities:ValidateGroupComposition(members, requirements)
    Debug("TRACE", "Utilities:ValidateGroupComposition called")
    
    requirements = requirements or {
        maxTanks = 1,
        maxHealers = 1,
        maxDPS = 3,
        maxTotal = 5
    }
    
    local counts = {
        TANK = 0,
        HEALER = 0,
        DPS = 0,
        total = 0
    }
    
    if not members then
        return true, counts
    end
    
    for _, member in pairs(members) do
        if member then
            local role = member.role or self:GetPlayerRole(member)
            if role then
                counts[role] = (counts[role] or 0) + 1
                counts.total = counts.total + 1
            end
        end
    end
    
    local isValid = true
    local issues = {}
    
    if counts.TANK > requirements.maxTanks then
        isValid = false
        table.insert(issues, "Too many tanks")
    end
    
    if counts.HEALER > requirements.maxHealers then
        isValid = false
        table.insert(issues, "Too many healers")
    end
    
    if counts.DPS > requirements.maxDPS then
        isValid = false
        table.insert(issues, "Too many DPS")
    end
    
    if counts.total > requirements.maxTotal then
        isValid = false
        table.insert(issues, "Group is full")
    end
    
    Debug("DEBUG", "Utilities:ValidateGroupComposition:", 
        "Valid:", isValid, "Tanks:", counts.TANK, "Healers:", counts.HEALER, "DPS:", counts.DPS)
    
    return isValid, counts, issues
end

function Utilities:CanAddMemberToGroup(members, newMemberRole, requirements)
    Debug("TRACE", "Utilities:CanAddMemberToGroup called for role:", newMemberRole)
    
    requirements = requirements or {
        maxTanks = 1,
        maxHealers = 1,
        maxDPS = 3,
        maxTotal = 5
    }
    
    local _, counts = self:ValidateGroupComposition(members, requirements)
    
    if counts.total >= requirements.maxTotal then
        Debug("DEBUG", "Utilities:CanAddMemberToGroup: Group is full")
        return false, "Group is full"
    end
    
    if newMemberRole == "TANK" and counts.TANK >= requirements.maxTanks then
        Debug("DEBUG", "Utilities:CanAddMemberToGroup: Too many tanks")
        return false, "Too many tanks"
    end
    
    if newMemberRole == "HEALER" and counts.HEALER >= requirements.maxHealers then
        Debug("DEBUG", "Utilities:CanAddMemberToGroup: Too many healers")
        return false, "Too many healers"
    end
    
    if newMemberRole == "DPS" and counts.DPS >= requirements.maxDPS then
        Debug("DEBUG", "Utilities:CanAddMemberToGroup: Too many DPS")
        return false, "Too many DPS"
    end
    
    Debug("DEBUG", "Utilities:CanAddMemberToGroup: Can add member with role", newMemberRole)
    return true
end

return Utilities