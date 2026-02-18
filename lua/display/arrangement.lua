-- Display arrangement management module
-- Handles display mirroring, extended desktop, and primary display configuration

local M = {}
local shared = require("display.shared")

-- Get display arrangement configurations
-- @param active_icon string: icon for active/current state (default: "◍")
-- @param available_icon string: icon for available options (default: "○")
-- @return table: array of arrangement options (mirrored, extended, primary settings)
function M.list_arrangements(active_icon, available_icon)
	-- Set default icons if not provided
	active_icon = active_icon or "◍"
	available_icon = available_icon or "○"
	-- Check dependencies first
	local ok, err = shared.check_dependencies()
	if not ok then
		return { err }
	end

	local displays = shared.parse_display_info()

	if #displays == 0 then
		return { "No displays found" }
	end

	if #displays == 1 then
		return { "Single display - no arrangement options available" }
	end

	local arrangements = {}

	-- Check current mirroring status
	-- In mirrored mode, displayplacer shows: id:DISPLAY1+DISPLAY2
	-- In extended mode, it shows separate commands for each display
	local output = shared.get_current_config()
	local is_mirrored = output and output:match('displayplacer "id:[^"]+%+') ~= nil

	-- Current status
	if is_mirrored then
		table.insert(arrangements, active_icon .. " Current: Mirrored Displays")
	else
		table.insert(arrangements, active_icon .. " Current: Extended Desktop")
	end

	-- Toggle option
	if is_mirrored then
		table.insert(arrangements, available_icon .. " Switch to Extended Desktop")
	else
		table.insert(arrangements, available_icon .. " Switch to Mirrored Displays")
	end

	-- Mirror source or primary display options
	if is_mirrored then
		-- Show mirror source (first display in the joined ID is the source)
		-- Match the displayplacer command that contains a + (the mirrored config)
		local mirror_cmd = output:match('displayplacer "id:([^"]*%+[^"]*)"')
		if mirror_cmd then
			-- Extract just the first ID (before the +)
			local primary_id = mirror_cmd:match("^([^+]+)")
			-- Trim any whitespace
			if primary_id then
				primary_id = primary_id:match("^%s*(.-)%s*$")
			end

			for _, display in ipairs(displays) do
				local display_name = display.name or display.id
				local is_source = (display.id == primary_id)

				if is_source then
					table.insert(arrangements, string.format("%s Mirror Source: %s", active_icon, display_name))
				else
					table.insert(arrangements, string.format("%s Set Mirror Source: %s", available_icon, display_name))
				end
			end
		end
	else
		-- Primary display options for extended mode
		for _, display in ipairs(displays) do
			local display_name = display.name or display.id

			-- Find if this display is marked as main
			-- Search for this display's section and check for "main display" marker
			local is_primary = false
			local in_section = false

			-- Escape special pattern characters in the display ID
			local escaped_id = display.id:gsub("([%-])", "%%%1")

			for line in output:gmatch("[^\r\n]+") do
				-- Check if we're entering this display's section
				if line:match("Persistent screen id: " .. escaped_id) then
					in_section = true
				-- Check if we're entering a different display's section
				elseif line:match("Persistent screen id:") then
					in_section = false
				-- If we're in this display's section, check for main display marker
				elseif in_section and line:match("Origin:.*main display") then
					is_primary = true
					break
				end
			end

			if is_primary then
				table.insert(arrangements, string.format("%s Primary: %s", active_icon, display_name))
			else
				table.insert(arrangements, string.format("%s Set Primary: %s", available_icon, display_name))
			end
		end
	end

	return arrangements
end

-- Parse arrangement item and execute the configuration change
-- @param item string: arrangement item selected by user
-- @return string, number: message, exit_code
function M.apply_arrangement(item)
	if not item or item == "" then
		return "Error: No arrangement selected", 1
	end

	-- Skip current status items (matches items that contain "Current:")
	if item:match("Current:") then
		return "No change - this is the current configuration", 0
	end

	local displays = shared.parse_display_info()

	if #displays < 2 then
		return "Error: Need at least 2 displays for arrangement changes", 1
	end

	-- Handle mirroring toggle
	if item:match("Switch to Mirrored Displays") then
		-- Mirror all displays - use + to join display IDs
		local display_ids = {}
		for _, display in ipairs(displays) do
			table.insert(display_ids, display.id)
		end

		local mirror_id = table.concat(display_ids, "+")

		-- Use the current resolution of the first display
		local first_display = displays[1]
		local res = first_display.current_res or "1920x1080"
		local hz = first_display.current_hz or "60"

		-- Get the degree from the first display to apply to all mirrored displays
		local degree = shared.get_display_degree(first_display.id) or "0"

		local cmd = string.format(
			"displayplacer \"id:%s res:%s hz:%s origin:(0,0) degree:%s\" 2>&1",
			mirror_id,
			res,
			hz,
			degree
		)

		local output, code = syntropy.shell(cmd)
		if code ~= 0 then
			return string.format("Error enabling mirroring: %s", output), 1
		end

		return "Displays are now mirrored", 0

	elseif item:match("Switch to Extended Desktop") then
		-- Arrange displays side-by-side
		local cmds = {}
		local x_offset = 0

		for i, display in ipairs(displays) do
			local res = display.current_res or "1920x1080"
			local hz = display.current_hz or "60"
			local width = tonumber(res:match("(%d+)x%d+")) or 1920

			-- First display is primary at (0,0)
			local origin = (i == 1) and "(0,0)" or string.format("(%d,0)", x_offset)

			-- Preserve rotation
			local degree = shared.get_display_degree(display.id) or "0"

			table.insert(cmds, string.format(
				"\"id:%s res:%s hz:%s origin:%s degree:%s\"",
				display.id,
				res,
				hz,
				origin,
				degree
			))

			x_offset = x_offset + width
		end

		local cmd = string.format("displayplacer %s 2>&1", table.concat(cmds, " "))

		local output, code = syntropy.shell(cmd)
		if code ~= 0 then
			return string.format("Error enabling extended desktop: %s", output), 1
		end

		return "Displays are now extended", 0

	elseif item:match("Set Primary: (.+)") then
		local target_name = item:match("Set Primary: (.+)")

		-- Find the target display
		local target_display = nil
		for _, display in ipairs(displays) do
			if (display.name or display.id) == target_name then
				target_display = display
				break
			end
		end

		if not target_display then
			return string.format("Error: Display '%s' not found", target_name), 1
		end

		-- Rebuild extended desktop with new primary display first
		local cmds = {}
		local x_offset = 0

		-- Add target display first (becomes primary at 0,0)
		local res = target_display.current_res or "1920x1080"
		local hz = target_display.current_hz or "60"
		local width = tonumber(res:match("(%d+)x%d+")) or 1920

		-- Preserve rotation
		local degree = shared.get_display_degree(target_display.id) or "0"

		table.insert(cmds, string.format(
			"\"id:%s res:%s hz:%s origin:(0,0) degree:%s\"",
			target_display.id,
			res,
			hz,
			degree
		))

		x_offset = width

		-- Add other displays
		for _, display in ipairs(displays) do
			if display.id ~= target_display.id then
				res = display.current_res or "1920x1080"
				hz = display.current_hz or "60"
				width = tonumber(res:match("(%d+)x%d+")) or 1920

				-- Preserve rotation
				degree = shared.get_display_degree(display.id) or "0"

				table.insert(cmds, string.format(
					"\"id:%s res:%s hz:%s origin:(%d,0) degree:%s\"",
					display.id,
					res,
					hz,
					x_offset,
					degree
				))

				x_offset = x_offset + width
			end
		end

		local cmd = string.format("displayplacer %s 2>&1", table.concat(cmds, " "))

		local output, code = syntropy.shell(cmd)
		if code ~= 0 then
			return string.format("Error setting primary display: %s", output), 1
		end

		return string.format("Primary display set to: %s", target_name), 0

	elseif item:match("Set Mirror Source: (.+)") then
		local target_name = item:match("Set Mirror Source: (.+)")

		-- Find the target display
		local target_display = nil
		local other_displays = {}

		for _, display in ipairs(displays) do
			if (display.name or display.id) == target_name then
				target_display = display
			else
				table.insert(other_displays, display)
			end
		end

		if not target_display then
			return string.format("Error: Display '%s' not found", target_name), 1
		end

		-- Build mirrored command with new source (target_display first)
		local display_ids = { target_display.id }
		for _, display in ipairs(other_displays) do
			table.insert(display_ids, display.id)
		end

		local mirror_id = table.concat(display_ids, "+")
		local res = target_display.current_res or "1920x1080"
		local hz = target_display.current_hz or "60"

		-- Get the degree from the target display to apply to all mirrored displays
		local degree = shared.get_display_degree(target_display.id) or "0"

		local cmd = string.format(
			"displayplacer \"id:%s res:%s hz:%s origin:(0,0) degree:%s\" 2>&1",
			mirror_id,
			res,
			hz,
			degree
		)

		local output, code = syntropy.shell(cmd)
		if code ~= 0 then
			return string.format("Error setting mirror source: %s", output), 1
		end

		return string.format("Mirror source set to: %s", target_name), 0
	end

	return "Unknown arrangement option", 1
end

return M
