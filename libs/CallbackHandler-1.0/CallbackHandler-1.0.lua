--[[ $Id: CallbackHandler-1.0.lua 22 2018-07-21 14:17:22Z nevcairiel $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

local type = type
local pcall = pcall
local pairs = pairs
local assert = assert
local concat = table.concat
local loadstring = loadstring
local next = next
local select = select
local type = type
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
	local next, xpcall, eh = ...

	local method, ARGS
	local function call() method(ARGS) end

	local function dispatch(handlers, ...)
		local index, method = next(handlers)
		if not method then return end
		repeat
			ARGS = ...
			if not xpcall(call, eh) then
				handlers[index] = nil
			end
			index, method = next(handlers, index)
		until not method
	end

	return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", concat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(next, xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we could use setmetatable instead of this loop, but then we'd create
	-- a new closure for every cycle of GetLibrary(). That's not really viable
	-- from a memory standpoint, so we'll do the simple thing here.

	target = target or {}
	target.callbacks = target.callbacks or setmetatable({}, meta)
	target.insertQueue = target.insertQueue or {}
	target.argCount = target.argCount or setmetatable({}, meta)

	assert(target.RegisterCallback == nil, "Attempting to RegisterCallback through CallbackHandler that already has a RegisterCallback API.")

	local callbacks = target.callbacks
	local insertQueue = target.insertQueue
	local Dispatchers = Dispatchers

	-- Insert a list of callbacks when iterating through callbacks is not safe
	local function processQueue()
		for eventname, callbacks in pairs(insertQueue) do
			local first = true
			for self, func in pairs(callbacks) do
				if first then
					target.callbacks[eventname] = target.callbacks[eventname] or {}
					callbacks, first = target.callbacks[eventname], false
				end
				callbacks[self] = func
			end
			insertQueue[eventname] = nil
		end
	end

	-- Register a callback
	target[RegisterName] = function(self, eventname, method, arg)
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method [, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		local first = rawget(callbacks, eventname)
		if not first then
			callbacks[eventname] = {}
		elseif first == true then
			callbacks[eventname] = insertQueue[eventname] or {}
		end

		local reg = callbacks[eventname]

		if type(method) == "string" then
			-- self[method] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): self was not a table?", 2)
			elseif self == target then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): do not use Library:"..RegisterName.."(), use your own 'self'", 2)
			elseif type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - method '"..tostring(method).."' not found on self.", 2)
			end

			if reg[self] or insertQueue[eventname] and insertQueue[eventname][self] then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): event \""..tostring(eventname).."\" already registered.", 2)
			end
			-- remember this function for Dispatchers
			target.argCount[eventname][self] = arg and 3 or 2

			if first == true then
				insertQueue[eventname] = insertQueue[eventname] or setmetatable({}, meta)
				insertQueue[eventname][self] = method
			else
				reg[self] = method
			end
		elseif type(method) == "function" then
			-- function ref with self=arg
			if reg[method] or insertQueue[eventname] and insertQueue[eventname][method] then
				error("Usage: "..RegisterName.."(\"eventname\", function): event \""..tostring(eventname).."\" already registered.", 2)
			end
			-- remember this function for Dispatchers
			target.argCount[eventname][method] = arg and 2 or 1
			if first == true then
				insertQueue[eventname] = insertQueue[eventname] or setmetatable({}, meta)
				insertQueue[eventname][method] = arg or false
			else
				reg[method] = arg or false
			end
		end
	end

	-- Unregister a callback
	target[UnregisterName] = function(self, eventname)
		if not self or self == target then
			error("Usage: "..UnregisterName.."(eventname): bad 'self'", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
		end
		if rawget(callbacks, eventname) and callbacks[eventname][self] then
			callbacks[eventname][self] = nil
		end
		if target.insertQueue[eventname] and target.insertQueue[eventname][self] then
			target.insertQueue[eventname][self] = nil
		end
	end

	-- OPTIONAL: Unregister all callbacks for given selfs/repos
	if UnregisterAllName then
		target[UnregisterAllName] = function(...)
			if select("#",...)<1 then
				error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or \"eventname\" to unregister events for.", 2)
			end
			if select("#",...)==1 and ...==target then
				error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or \"eventname\"", 2)
			end


			for i=1,select("#",...) do
				local self = select(i,...)
				if type(self)=="string" then
					-- unregister all callbacks for the named event
					rawset(callbacks, self, nil)
					rawset(insertQueue, self, nil)
				else
					-- unregister all callbacks having the object as the beneficiary
					for eventname, callbacks in pairs(callbacks) do
						if callbacks[self] then
							callbacks[self] = nil
						end
					end
					for eventname, callbacks in pairs(insertQueue) do
						if callbacks[self] then
							callbacks[self] = nil
						end
					end
				end
			end
		end
	end

	return target
end

function CallbackHandler:Fire(eventname, ...)
	if type(eventname) ~= "string" then
		error("Usage: Fire(eventname, ...): 'eventname' - string expected.", 2)
	end

	local first = rawget(self.callbacks, eventname)
	if first == true then
		-- we have to make sure we process the insertqueue before firing
		local insertQueue = rawget(self.insertQueue, eventname)
		if insertQueue then
			self.callbacks[eventname] = {}
			for self, func in pairs(insertQueue) do
				self.callbacks[eventname][self] = func
			end
			self.insertQueue[eventname] = nil
		end
		first = self.callbacks[eventname]
	end

	if first then
		local argCount = 0
		for self, func in pairs(first) do
			argCount = self.argCount[eventname][self]
			if argCount == 0 then
				argCount = select("#", ...)
			end
			if argCount > 0 then
				Dispatchers[argCount](first, ...)
			else
				Dispatchers[0](first)
			end
			break
		end
	end
end