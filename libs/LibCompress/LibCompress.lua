--[[
Simplified LibCompress implementation for GrouperPlus
Based on the LibCompress library concept but simplified for our needs
]]

local MAJOR, MINOR = "LibCompress", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

-- Simple LZW compression implementation
local function CompressLZW(data)
    if type(data) ~= "string" then
        return nil
    end
    
    local dict = {}
    local dictSize = 256
    local result = {}
    
    -- Initialize dictionary with single characters
    for i = 0, 255 do
        dict[string.char(i)] = i
    end
    
    local w = ""
    for i = 1, #data do
        local c = data:sub(i, i)
        local wc = w .. c
        
        if dict[wc] then
            w = wc
        else
            table.insert(result, dict[w])
            dict[wc] = dictSize
            dictSize = dictSize + 1
            w = c
        end
    end
    
    if w ~= "" then
        table.insert(result, dict[w])
    end
    
    -- Convert numbers to string
    local compressed = ""
    for _, num in ipairs(result) do
        -- Use 2-byte encoding for simplicity
        compressed = compressed .. string.char(math.floor(num / 256)) .. string.char(num % 256)
    end
    
    return compressed
end

local function DecompressLZW(compressed)
    if type(compressed) ~= "string" or #compressed == 0 then
        return nil
    end
    
    -- Convert string back to numbers
    local codes = {}
    for i = 1, #compressed, 2 do
        if i + 1 <= #compressed then
            local high = compressed:byte(i)
            local low = compressed:byte(i + 1)
            table.insert(codes, high * 256 + low)
        end
    end
    
    if #codes == 0 then
        return nil
    end
    
    local dict = {}
    local dictSize = 256
    local result = {}
    
    -- Initialize dictionary
    for i = 0, 255 do
        dict[i] = string.char(i)
    end
    
    local w = dict[codes[1]]
    table.insert(result, w)
    
    for i = 2, #codes do
        local k = codes[i]
        local entry
        
        if dict[k] then
            entry = dict[k]
        elseif k == dictSize then
            entry = w .. w:sub(1, 1)
        else
            return nil -- Invalid compressed data
        end
        
        table.insert(result, entry)
        dict[dictSize] = w .. entry:sub(1, 1)
        dictSize = dictSize + 1
        w = entry
    end
    
    return table.concat(result)
end

-- Simple run-length encoding as fallback
local function CompressRLE(data)
    if type(data) ~= "string" then
        return nil
    end
    
    local result = {}
    local i = 1
    
    while i <= #data do
        local char = data:sub(i, i)
        local count = 1
        
        while i + count <= #data and data:sub(i + count, i + count) == char and count < 255 do
            count = count + 1
        end
        
        if count > 3 or char:byte() > 127 then
            -- Use RLE for runs > 3 or high-value bytes
            table.insert(result, string.char(255)) -- Escape character
            table.insert(result, char)
            table.insert(result, string.char(count))
        else
            -- Just store the characters normally
            for j = 1, count do
                table.insert(result, char)
            end
        end
        
        i = i + count
    end
    
    return table.concat(result)
end

local function DecompressRLE(compressed)
    if type(compressed) ~= "string" then
        return nil
    end
    
    local result = {}
    local i = 1
    
    while i <= #compressed do
        local char = compressed:sub(i, i)
        
        if char:byte() == 255 and i + 2 <= #compressed then
            -- RLE sequence
            local repeatChar = compressed:sub(i + 1, i + 1)
            local count = compressed:byte(i + 2)
            
            for j = 1, count do
                table.insert(result, repeatChar)
            end
            
            i = i + 3
        else
            table.insert(result, char)
            i = i + 1
        end
    end
    
    return table.concat(result)
end

function lib:Compress(data, algorithm)
    if not data then
        return nil
    end
    
    algorithm = algorithm or "auto"
    
    local originalSize = #data
    local compressed
    local method
    
    if algorithm == "lzw" or algorithm == "auto" then
        compressed = CompressLZW(data)
        method = "lzw"
    end
    
    if not compressed or (algorithm == "auto" and #compressed >= originalSize * 0.9) then
        -- Try RLE if LZW didn't compress well or failed
        local rleCompressed = CompressRLE(data)
        if rleCompressed and #rleCompressed < originalSize then
            compressed = rleCompressed
            method = "rle"
        end
    end
    
    if not compressed or #compressed >= originalSize then
        -- No compression benefit, return original with no compression marker
        return data, "none"
    end
    
    -- Prepend method identifier
    return method:sub(1,1) .. compressed, method
end

function lib:Decompress(compressed, method)
    if not compressed then
        return nil
    end
    
    if method == "none" then
        return compressed
    end
    
    -- Auto-detect method from first character if not specified
    if not method and #compressed > 0 then
        local firstChar = compressed:sub(1, 1)
        if firstChar == "l" then
            method = "lzw"
            compressed = compressed:sub(2)
        elseif firstChar == "r" then
            method = "rle"
            compressed = compressed:sub(2)
        else
            -- Assume no compression
            return compressed
        end
    end
    
    if method == "lzw" then
        return DecompressLZW(compressed)
    elseif method == "rle" then
        return DecompressRLE(compressed)
    else
        return compressed
    end
end

-- Additional utility functions
function lib:GetCompressionRatio(original, compressed)
    if not original or not compressed then
        return 0
    end
    
    return (#original - #compressed) / #original
end

function lib:IsCompressed(data)
    if not data or #data == 0 then
        return false
    end
    
    local firstChar = data:sub(1, 1)
    return firstChar == "l" or firstChar == "r"
end