-- Shared utilities for display plugin modules
-- Common functions used across resolution, arrangement, and info modules

local M = {}

-- Check if displayplacer is installed
function M.check_dependencies()
	local _, code = syntropy.shell("command -v displayplacer >/dev/null 2>&1")
	if code ~= 0 then
		return false, "displayplacer not found. Install with: brew install jakehilborn/jakehilborn/displayplacer"
	end
	return true, nil
end

-- Get current display configuration
-- @return string: current configuration, or nil on error
function M.get_current_config()
	local output, code = syntropy.shell("displayplacer list 2>&1")

	if code ~= 0 then
		return nil
	end

	return output
end

-- Parse display information from displayplacer list output
-- @return table: array of displays with their available resolutions
function M.parse_display_info()
	local output = M.get_current_config()
	if not output then
		return {}
	end

	local displays = {}
	local current_display = nil

	for line in output:gmatch("[^\r\n]+") do
		-- Match display ID
		local persistent_id = line:match("Persistent screen id: ([%w%-]+)")
		if persistent_id then
			current_display = {
				id = persistent_id,
				name = nil,
				current_res = nil,
				current_hz = nil,
				resolutions = {}
			}
			table.insert(displays, current_display)
		end

		-- Match display name/type
		local display_type = line:match("Type: (.+)")
		if display_type and current_display then
			current_display.name = display_type
		end

		-- Match current resolution and hertz
		if line:match("Resolution:") and current_display and not current_display.current_res then
			local width, height = line:match("Resolution: (%d+)x(%d+)")
			if width and height then
				current_display.current_res = width .. "x" .. height
			end
		end

		if line:match("Hertz:") and current_display and not current_display.current_hz then
			local hz = line:match("Hertz: ([%d%.]+)")
			if hz then
				current_display.current_hz = hz
			end
		end

		-- Match available resolution modes
		-- Example: "  mode 130: res:3008x1692 hz:120 color_depth:8 scaling:on <-- current mode"
		-- Example: "  mode 131: res:3008x1692 hz:60 color_depth:8 scaling:off"
		if line:match("mode %d+:") and current_display then
			local width, height, hz = line:match("res:(%d+)x(%d+) hz:([%d%.]+)")
			if width and height and hz then
				local is_current = line:match("<-- current mode") ~= nil
				local scaling = line:match("scaling:(%w+)") or "off"  -- Extract "on" or "off"
				local color_depth = line:match("color_depth:(%d+)") or "8"

				local resolution = {
					width = width,
					height = height,
					hz = hz,
					is_current = is_current,
					scaling = scaling,          -- NEW: Track if scaled
					color_depth = color_depth   -- NEW: Track color depth
				}
				table.insert(current_display.resolutions, resolution)
			end
		end
	end

	return displays
end

-- Find display ID by name
-- @param target_name string: display name to find
-- @return string: display ID, or nil if not found
function M.find_display_id(target_name)
	local displays = M.parse_display_info()

	for _, display in ipairs(displays) do
		if display.name == target_name then
			return display.id
		end
	end

	return nil
end

-- Extract origin coordinates for a display from displayplacer list output
-- @param display_id string: display ID to find origin for
-- @return string: origin string like "(0,0)" or "(3008,0)", or nil if not found
function M.get_display_origin(display_id)
	local output = M.get_current_config()
	if not output then
		return nil
	end

	local in_section = false
	local escaped_id = display_id:gsub("([%-])", "%%%1")

	for line in output:gmatch("[^\r\n]+") do
		-- Check if we're entering this display's section
		if line:match("Persistent screen id: " .. escaped_id) then
			in_section = true
		-- Check if we're entering a different display's section
		elseif line:match("Persistent screen id:") then
			in_section = false
		-- If we're in this display's section, extract origin
		elseif in_section then
			local origin = line:match("Origin:%s*(%b())")
			if origin then
				return origin
			end
		end
	end

	-- Fallback to (0,0) if not found
	return "(0,0)"
end

-- Extract rotation degree for a display from displayplacer list output
-- @param display_id string: display ID to find rotation for
-- @return string: degree string like "0", "90", "180", or "270"
function M.get_display_degree(display_id)
	local output = M.get_current_config()
	if not output then
		return "0"
	end

	local in_section = false
	local escaped_id = display_id:gsub("([%-])", "%%%1")

	for line in output:gmatch("[^\r\n]+") do
		-- Check if we're entering this display's section
		if line:match("Persistent screen id: " .. escaped_id) then
			in_section = true
		-- Check if we're entering a different display's section
		elseif line:match("Persistent screen id:") then
			in_section = false
		-- If we're in this display's section, extract rotation
		elseif in_section then
			local rotation = line:match("Rotation:%s*(%d+)")
			if rotation then
				return rotation
			end
		end
	end

	-- Fallback to 0 degrees if not found
	return "0"
end

return M
