local addonName, addon = ...

-- Utilities module for common helper functions
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    
    local Debug = addon.Debug
    local LOG_LEVEL = addon.LOG_LEVEL
    
    if not Debug or not LOG_LEVEL then
        print("[GrouperPlus:ERROR] Utilities - Missing addon references")
        return
    end
    
    Debug(LOG_LEVEL.DEBUG, "Utilities module loaded")
    
    -- Utility functions namespace
    addon.Utils = addon.Utils or {}
    
    -- Color interpolation function
    -- Interpolates between two colors based on a factor (0.0 to 1.0)
    -- @param color1: First color {r, g, b} (factor = 0.0)
    -- @param color2: Second color {r, g, b} (factor = 1.0)
    -- @param factor: Interpolation factor between 0.0 and 1.0
    -- @return: Interpolated color {r, g, b}
    function addon.Utils.InterpolateColors(color1, color2, factor)
        if not color1 or not color2 then
            Debug(LOG_LEVEL.ERROR, "InterpolateColors: Invalid color parameters")
            return {r = 1.0, g = 1.0, b = 1.0} -- Default to white
        end
        
        -- Clamp factor between 0 and 1
        factor = math.max(0.0, math.min(1.0, factor))
        
        local r = color1.r + (color2.r - color1.r) * factor
        local g = color1.g + (color2.g - color1.g) * factor
        local b = color1.b + (color2.b - color1.b) * factor
        
        Debug(LOG_LEVEL.TRACE, "InterpolateColors: factor", factor, "result", string.format("%.2f,%.2f,%.2f", r, g, b))
        
        return {r = r, g = g, b = b}
    end
    
    -- Color interpolation with multiple stops
    -- Interpolates through multiple colors based on a factor (0.0 to 1.0)
    -- @param colors: Array of colors {r, g, b}
    -- @param factor: Interpolation factor between 0.0 and 1.0
    -- @return: Interpolated color {r, g, b}
    function addon.Utils.InterpolateMultiColors(colors, factor)
        if not colors or #colors < 2 then
            Debug(LOG_LEVEL.ERROR, "InterpolateMultiColors: Need at least 2 colors")
            return {r = 1.0, g = 1.0, b = 1.0} -- Default to white
        end
        
        -- Clamp factor between 0 and 1
        factor = math.max(0.0, math.min(1.0, factor))
        
        -- If factor is 0 or 1, return first or last color
        if factor == 0.0 then
            return colors[1]
        end
        if factor == 1.0 then
            return colors[#colors]
        end
        
        -- Calculate which segment we're in
        local segments = #colors - 1
        local segmentSize = 1.0 / segments
        local segmentIndex = math.floor(factor / segmentSize) + 1
        
        -- Handle edge case where factor is exactly 1.0
        if segmentIndex > segments then
            segmentIndex = segments
        end
        
        -- Calculate local factor within the segment
        local localFactor = (factor - (segmentIndex - 1) * segmentSize) / segmentSize
        
        -- Interpolate between the two colors in this segment
        local color1 = colors[segmentIndex]
        local color2 = colors[segmentIndex + 1]
        
        Debug(LOG_LEVEL.TRACE, "InterpolateMultiColors: segment", segmentIndex, "localFactor", localFactor)
        
        return addon.Utils.InterpolateColors(color1, color2, localFactor)
    end
    
    -- Get color for a score based on predefined quality thresholds
    -- @param score: Numeric score to evaluate
    -- @param minScore: Minimum score (maps to first color)
    -- @param maxScore: Maximum score (maps to last color)
    -- @param colors: Optional array of colors (defaults to item quality colors)
    -- @return: Interpolated color {r, g, b}
    function addon.Utils.GetScoreColor(score, minScore, maxScore, colors)
        if not score or not minScore or not maxScore then
            Debug(LOG_LEVEL.ERROR, "GetScoreColor: Invalid parameters")
            return {r = 1.0, g = 1.0, b = 1.0} -- Default to white
        end
        
        -- Default to item quality progression if no colors provided
        colors = colors or {
            addon.ITEM_QUALITY_COLORS.POOR,      -- Gray (lowest)
            addon.ITEM_QUALITY_COLORS.COMMON,    -- White
            addon.ITEM_QUALITY_COLORS.UNCOMMON,  -- Green
            addon.ITEM_QUALITY_COLORS.RARE,      -- Blue
            addon.ITEM_QUALITY_COLORS.EPIC,      -- Purple
            addon.ITEM_QUALITY_COLORS.LEGENDARY  -- Orange (highest)
        }
        
        -- Calculate factor based on score range
        local factor = (score - minScore) / (maxScore - minScore)
        
        -- If score exceeds maxScore, clamp to legendary color instead of interpolating beyond
        if factor >= 1.0 then
            Debug(LOG_LEVEL.TRACE, "GetScoreColor: score", score, "exceeds max, using legendary color")
            return colors[#colors] -- Return the last color (legendary)
        end
        
        Debug(LOG_LEVEL.TRACE, "GetScoreColor: score", score, "factor", factor)
        
        return addon.Utils.InterpolateMultiColors(colors, factor)
    end
    
    -- Clamp a value between min and max
    -- @param value: Value to clamp
    -- @param min: Minimum value
    -- @param max: Maximum value
    -- @return: Clamped value
    function addon.Utils.Clamp(value, min, max)
        return math.max(min, math.min(max, value))
    end
    
    -- Linear interpolation between two numbers
    -- @param a: First number (factor = 0.0)
    -- @param b: Second number (factor = 1.0)
    -- @param factor: Interpolation factor between 0.0 and 1.0
    -- @return: Interpolated number
    function addon.Utils.Lerp(a, b, factor)
        factor = addon.Utils.Clamp(factor, 0.0, 1.0)
        return a + (b - a) * factor
    end
    
    -- Parse semantic version string into components
    -- @param version: Version string like "1.2.3" or "0.6.0"
    -- @return: Table with {major, minor, patch} or nil if invalid
    function addon.Utils.ParseVersion(version)
        if not version or type(version) ~= "string" then
            Debug(LOG_LEVEL.DEBUG, "ParseVersion: Invalid version parameter")
            return nil
        end
        
        local major, minor, patch = string.match(version, "^(%d+)%.(%d+)%.(%d+)")
        if not major or not minor or not patch then
            Debug(LOG_LEVEL.DEBUG, "ParseVersion: Failed to parse version:", version)
            return nil
        end
        
        return {
            major = tonumber(major),
            minor = tonumber(minor), 
            patch = tonumber(patch)
        }
    end
    
    -- Compare two semantic versions
    -- @param version1: First version string
    -- @param version2: Second version string
    -- @return: -1 if v1 < v2, 0 if equal, 1 if v1 > v2, nil if error
    function addon.Utils.CompareVersions(version1, version2)
        local v1 = addon.Utils.ParseVersion(version1)
        local v2 = addon.Utils.ParseVersion(version2)
        
        if not v1 or not v2 then
            Debug(LOG_LEVEL.WARN, "CompareVersions: Failed to parse versions:", version1, version2)
            return nil
        end
        
        -- Compare major version first
        if v1.major ~= v2.major then
            return v1.major < v2.major and -1 or 1
        end
        
        -- Compare minor version
        if v1.minor ~= v2.minor then
            return v1.minor < v2.minor and -1 or 1
        end
        
        -- Compare patch version
        if v1.patch ~= v2.patch then
            return v1.patch < v2.patch and -1 or 1
        end
        
        -- Versions are equal
        return 0
    end
    
    -- Check if a version is newer than another
    -- @param newVersion: Version to check if newer
    -- @param currentVersion: Current/reference version
    -- @return: true if newVersion > currentVersion
    function addon.Utils.IsVersionNewer(newVersion, currentVersion)
        local result = addon.Utils.CompareVersions(newVersion, currentVersion)
        return result == 1
    end
    
    -- Check if update is significant (major or minor version increase)
    -- @param newVersion: Newer version string
    -- @param currentVersion: Current version string
    -- @return: true if major or minor version increased
    function addon.Utils.IsSignificantUpdate(newVersion, currentVersion)
        local v1 = addon.Utils.ParseVersion(newVersion)
        local v2 = addon.Utils.ParseVersion(currentVersion)
        
        if not v1 or not v2 then
            return false
        end
        
        -- Significant if major or minor version is higher
        return v1.major > v2.major or (v1.major == v2.major and v1.minor > v2.minor)
    end
    
    Debug(LOG_LEVEL.INFO, "Utilities module initialized with color interpolation and version comparison functions")
end)