--- AceDB-3.0 provides a simplified database API for World of Warcraft AddOns.
-- @class file
-- @name AceDB-3.0.lua
-- @release $Id: AceDB-3.0.lua 1202 2019-05-15 23:11:22Z nevcairiel $

local ACEDB_MAJOR, ACEDB_MINOR = "AceDB-3.0", 27
local AceDB, oldminor = LibStub:NewLibrary(ACEDB_MAJOR, ACEDB_MINOR)

if not AceDB then return end -- No upgrade needed

-- Lua APIs
local type, pairs, next, error = type, pairs, next, error
local setmetatable, getmetatable, rawset, rawget = setmetatable, getmetatable, rawset, rawget

-- WoW APIs
local _G = _G

AceDB.db_registry = AceDB.db_registry or {}
AceDB.frame = AceDB.frame or CreateFrame("Frame", "AceDB30Frame")

local CallbackHandler = LibStub("CallbackHandler-1.0")

local db_registry = AceDB.db_registry
local frame = AceDB.frame
local callbacks = AceDB.callbacks or CallbackHandler:New(AceDB)
AceDB.callbacks = callbacks

-- Utility functions
local function copyTable(src, dest)
	if type(dest) ~= "table" then dest = {} end
	if type(src) == "table" then
		for k,v in pairs(src) do
			if type(v) == "table" then
				-- try to index the key first so that the metatable creates the defaults, if set, and use that table
				v = copyTable(v, dest[k])
			end
			dest[k] = v
		end
	end
	return dest
end

local function copyDefaults(dest, src)
	-- this happens if some value in the SV overwrites our default value with a non-table
	--if type(dest) ~= "table" then return end
	for k, v in pairs(src) do
		if k == "*" or k == "**" then
			if type(v) == "table" then
				-- This is a metatable used for table defaults
				local mt = {
					-- This handles the lookup and creation of new subtables
					__index = function(t,k2)
							if k2 == nil then return nil end
							local tbl = {}
							copyDefaults(tbl, v)
							rawset(t, k2, tbl)
							return tbl
					end,
				}
				setmetatable(dest, mt)
				-- handle already existing tables in the SV
				for dk, dv in pairs(dest) do
					if not rawget(src, dk) and type(dv) == "table" then
						copyDefaults(dv, v)
					end
				end
			else
				-- Values are not tables, so this is just a simple return
				local mt = {__index = function(t,k2) return k2~=nil and v or nil end}
				setmetatable(dest, mt)
			end
		elseif type(v) == "table" then
			if not rawget(dest, k) then rawset(dest, k, {}) end
			if type(dest[k]) == "table" then
				copyDefaults(dest[k], v)
			end
		else
			if rawget(dest, k) == nil then
				rawset(dest, k, v)
			end
		end
	end
end

local function removeDefaults(db, defaults, blocker)
	-- remove all metatables from the db, so we don't accidentally create new sub-tables through them
	setmetatable(db, nil)
	-- loop through the defaults and remove their content from the db
	for k,v in pairs(defaults) do
		if k == "*" or k == "**" then
			if type(v) == "table" then
				-- Loop through all the actual k,v pairs and remove
				for key, value in pairs(db) do
					if type(value) == "table" then
						removeDefaults(value, v, true)
						if next(value) == nil then
							db[key] = nil
						end
					else
						if value == v then
							db[key] = nil
						end
					end
				end
			else
				-- check if the current value matches the default, and that its not blocked by another defaults table
				for key, value in pairs(db) do
					if value == v and not blocker then
						db[key] = nil
					end
				end
			end
		elseif type(v) == "table" and type(db[k]) == "table" then
			removeDefaults(db[k], v, blocker)
			if next(db[k]) == nil then
				db[k] = nil
			end
		else
			-- check if the current value matches the default, and that its not blocked by another defaults table
			if db[k] == v and not blocker then
				db[k] = nil
			end
		end
	end
end

-- This is called when a table section is first accessed, to set up the defaults
local function initSection(db, section, svstore, key, defaults)
	local sv = rawget(db, "sv")

	local tableCreated
	if not sv[svstore] then sv[svstore] = {} end
	if not sv[svstore][key] then
		sv[svstore][key] = {}
		tableCreated = true
	end

	local tbl = sv[svstore][key]

	if defaults then
		copyDefaults(tbl, defaults)
	end
	rawset(db, section, tbl)

	return tableCreated, tbl
end

-- Metatable to handle the dynamic creation of sections and copying of sections.
local dbmt = {
	__index = function(t, section)
		local keys = rawget(t, "keys")
		local key = keys and keys[section]
		if key then
			local defaultTbl = rawget(t, "defaults") and rawget(t.defaults, section)

			if section == "profile" then
				local new = initSection(t, section, "profiles", key, defaultTbl)
				if new then
					callbacks:Fire("OnNewProfile", t, key)
				end
			elseif section == "profiles" then
				local sv = rawget(t, "sv")
				if not sv.profiles then sv.profiles = {} end
				rawset(t, "profiles", sv.profiles)
			elseif section == "global" then
				local sv = rawget(t, "sv")
				if not sv.global then sv.global = {} end
				if defaultTbl then
					copyDefaults(sv.global, defaultTbl)
				end
				rawset(t, "global", sv.global)
			else
				initSection(t, section, section, key, defaultTbl)
			end
		end

		return rawget(t, section)
	end
}

local function validateDefaults(defaults, keyTbl, offset)
	if not defaults then return end
	offset = offset or 0
	for k in pairs(defaults) do
		if not keyTbl[k] or k == "profiles" then
			error(("Usage: AceDBObject:RegisterDefaults(defaults): '%s' is not a valid datatype."):format(k), 3 + offset)
		end
	end
end

local preserve_keys = {
	["callbacks"] = true,
	["RegisterCallback"] = true,
	["UnregisterCallback"] = true,
	["UnregisterAllCallbacks"] = true,
	["children"] = true,
}

local realmKey = GetRealmName()
local charKey = UnitName("player") .. " - " .. realmKey
local _, classKey = UnitClass("player")

-- Actual database initialization function
local function initdb(sv, defaults, defaultProfile, olddb, parent)
	-- Generate the database keys for each section

	-- Make a container for profile keys
	if not sv.profileKeys then sv.profileKeys = {} end

	-- Try to get the profile selected by the user
	local profileKey
	if defaultProfile then
		-- clear the old profile key in case we do a reset, and we don't have any prof chars anymore
		sv.profileKeys[charKey] = nil
		profileKey = defaultProfile
	else
		profileKey = sv.profileKeys[charKey] or "Default"
	end
	sv.profileKeys[charKey] = profileKey

	-- This table contains keys that enable the dynamic creation of each section
	local keyTbl= {
		["char"] = charKey,
		["realm"] = realmKey,
		["class"] = classKey,
		["profile"] = profileKey,
		["global"] = true,
	}

	validateDefaults(defaults, keyTbl, 1)

	-- Generate and insert the child object
	local db = {
		["sv"] = sv,
		["keys"] = keyTbl,
		["defaults"] = defaults,
		["parent"] = parent,
		["children"] = {},
	}
	if not parent then db.callbacks = callbacks:New(db) end
	setmetatable(db, dbmt)

	return db
end

-- handle PLAYER_LOGOUT
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGOUT" then
		for db in next, db_registry do
			db.callbacks:Fire("OnDatabaseShutdown", db)
		end
	end
end)

--- Creates a new database object that can be used to handle database settings and profiles.
-- By default, an empty DB is created, using a character specific profile.
--
-- You can also specify a list of defaults, and even a list of accepted profiles.
-- The defaults table can also contain a special "*" key, that will be used for all
-- profiles, that dont have a key that matches their name.
--
-- @param sv The name of the variable, or table to use for the database
-- @param defaults A table of database defaults
-- @param defaultProfile A default profile name to use
function AceDB:New(sv, defaults, defaultProfile)
	if type(sv) == "string" then
		sv = _G[sv]
	end
	if type(sv) ~= "table" then
		error("Usage: AceDB:New(savedVariables, defaults, defaultProfile): 'savedVariables' - table or string expected.", 2)
	end

	if defaultProfile and type(defaultProfile) ~= "string" and type(defaultProfile) ~= "function" then
		error("Usage: AceDB:New(savedVariables, defaults, defaultProfile): 'defaultProfile' - string or function or nil expected.", 2)
	end

	if type(defaultProfile) == "function" then
		defaultProfile = defaultProfile()
	end

	-- try to load the database (value might be nil)
	local db = initdb(sv, defaults, defaultProfile)

	-- validate the database
	-- this registers the database table to the registry
	db_registry[db] = true

	return db
end

-- upgrade existing databases
for db, v in pairs(db_registry) do
	if not db.parent then db.callbacks = callbacks:New(db) end
end