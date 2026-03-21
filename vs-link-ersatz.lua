-- Code from Malachite

local function apply(src, dst)
	for k, v in pairs(src) do
		if type(v) ~= "table" then
			dst[k] = v
		else
			dst[k] = {}
			apply(src[k], dst[k])
		end
	end
	return dst
end

local Stack = {
}

function Stack:new()
	local o = {
	}
	apply(Stack, o)
	return o;
end

function Stack:push(value)
	self["obj"] = {
		prev = self.obj,
		value = value
	}
end

function Stack:pop()
	local value = self.obj.value
	self.obj = self.obj.prev
	return value
end

function Stack:peek()
	return self.obj.value
end

local function fromJson(data)
	-- 0 = value
	-- 1 = symbol
	-- 2 = string
	-- 3 = key
	-- 4 = obj comma
	-- 5 = array comma
	-- 6 = colon
	local buffer = ""
	local mode = 0
	local escaped = false
	local stringStart = false
	local stack = Stack:new()
	stack:push({
		context = 0,
		currentKey = "value",
		ret = {}
	})
	local function applyValue(value)
		local top = stack:peek()
		if top.context == 0 then -- obj
			top.ret[top.currentKey] = value
			top.currentKey = nil
			mode = 4
		elseif top.context == 1 then -- array
			table.insert(top.ret, value)
			mode = 5
		end
	end
	for c in data:gmatch(".") do
        local continue = false
		if (buffer == "" and c:match("[ ]")) and (mode ~= 2) then
			continue = true
		end
		if not continue and mode == 1 then
			if c:match("[a-zA-Z0-9]") then
				buffer = buffer .. c
				continue = true
			else
				local val = ""
				if buffer == "null" then
					val = nil
				elseif buffer == "true" then
					val = true
				elseif buffer == "false" then
					val = false
				elseif buffer:match("[0-9]+") then
					val = tonumber(buffer)
				else
					return nil, "Unknown literal: " .. buffer
				end
				buffer = ""
				applyValue(val)
				-- parse next character
			end
		end
		if not continue and (mode == 0 or mode == 3 or mode == 4 or mode == 5) and (c == "]" or c == "}") then
			local top = stack:peek()
			if top.context == 0 and top.currentKey ~= nil then
				return nil, "Found closing bracket when searching for value"
			elseif (top.context == 0 and c == "]") or (top.context == 1 and c == "}") then
				return nil, "Wrong closing bracket used"
			else
				top = stack:pop()
				applyValue(top.ret)
				local c = stack:peek().context
				if c == 0 then
					mode = 4
				else
					mode = 5
				end
			end
			continue = true
		end
        if not continue then
            if mode == 0 then
                if c == "{" then
                    mode = 3
                    stringStart = false
                    stack:push({
                        context = 0, -- obj
                        ret = {}
                    })
                elseif c == "[" then
                    stack:push({
                        context = 1, -- array
                        ret = {}
                    })
                elseif c == "\"" then
                    mode = 2
                    stringStart = true;
                    continue = true
                else
                    buffer = buffer .. c
                    mode = 1
                end
            elseif mode == 2 or mode == 3 then -- string
                if stringStart ~= true then
                    if c ~= "\"" then
                        return nil, "Found " .. c .. " instead of \""
                    end
                    stringStart = true
                elseif c == "\"" and escaped == false then
                    if mode == 2 then
                        applyValue(buffer)
                    else
                        stack:peek().currentKey = buffer
                        mode = 6
                    end
                    buffer = ""
                elseif c == "\\" and escaped == false then
                    escaped = true
                else
                    buffer = buffer .. c
                    escaped = false
                end
            elseif mode == 4 or mode == 5 then
                if c == "," then
                    if mode == 4 then
                        mode = 3
                        stringStart = false
                    else
                        mode = 0
                    end
                else
                    return nil, "Found " .. c .. " instead of ,"
                end
            elseif mode == 6 then
                if c == ":" then
                    mode = 0
                else
                    return nil, "Found " .. c .. " instead of :"
                end
            end
        end
	end
	return stack:peek().ret.value, nil
end

-- End of Malachite library code

print("Loading Vs. Link Ersatz...")
local lib = require("vslinkcore")

local currentFrame = 0
local function frame()
    currentFrame = currentFrame + 1
    if currentFrame % 3 == 0 then
        local status = vs_pollServer()
        if status.status == "requested" then
            local json, err = fromJson(status.request)
            if err ~= nil then
                print("Error parsing JSON: " .. err)
            else
                local party = memory.readdword(0x02101D2C) + 0xD094
                local pc = memory.readdword(0x021C0794) + 0xCF44
                local partyData = memory.readbyterange(party, 236 * 6)
                local pcData = memory.readbyterange(pc, 136 * 540)
                vs_respond(partyData, pcData)
            end
        end
    end
end

gui.register(frame)
print("Successfully loaded Vs. Link Ersatz, by Emi")
