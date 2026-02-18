-- Display resolution management module
-- Handles listing and switching display resolutions via displayplacer

local M = {}
local shared = require("display.shared")

-- Get list of all available resolutions across all displays
-- Returns simplified list similar to macOS System Settings > Display
-- @param active_icon string: icon for active/current resolution (default: "◍")
-- @param available_icon string: icon for available resolutions (default: "○")
-- @return table: array of resolution strings with display names and indicators
function M.list_resolutions(active_icon, available_icon)
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
		return { "No displays found. Run 'displayplacer list' to debug." }
	end

	-- Check if displays are currently mirrored
	local output = shared.get_current_config()
	local is_mirrored = output and output:match('displayplacer "id:[^"]+%+') ~= nil

	-- If mirrored, only show resolutions for the mirror source
	local mirror_source_id = nil
	if is_mirrored then
		local mirror_cmd = output:match('displayplacer "id:([^"]*%+[^"]*)"')
		if mirror_cmd then
			-- Extract the first ID (mirror source)
			mirror_source_id = mirror_cmd:match("^([^+]+)")
			if mirror_source_id then
				mirror_source_id = mirror_source_id:match("^%s*(.-)%s*$")
			end
		end
	end

	local resolution_items = {}

	for _, display in ipairs(displays) do
		-- If mirrored, skip displays that are not the mirror source
		if is_mirrored and mirror_source_id and display.id ~= mirror_source_id then
			goto continue
		end

		local display_name = display.name or display.id

		if #display.resolutions == 0 then
			-- If no resolutions found in modes, use current resolution
			if display.current_res and display.current_hz then
				local item = string.format("%s %s - %sx%s @ %sHz",
					active_icon,
					display_name,
					display.current_res:match("(%d+)x(%d+)"),
					display.current_hz)
				table.insert(resolution_items, item)
			end
		else
			-- Group resolutions by unique width x height x hz combinations
			-- Track the "best" mode for each resolution (prefer scaling:on, current mode, etc.)
			local unique_resolutions = {}

			for _, resolution in ipairs(display.resolutions) do
				local res_key = string.format("%sx%s@%s",
					resolution.width,
					resolution.height,
					resolution.hz)

				-- Only keep one instance per unique resolution
				-- Prefer: current mode > any mode (first occurrence)
				if not unique_resolutions[res_key] or resolution.is_current then
					unique_resolutions[res_key] = resolution
				end
			end

			-- Convert unique resolutions to sorted array
			-- FILTER: Group scaled resolutions only (scaling:on), keeping highest Hz
			-- This matches macOS System Settings behavior for Retina displays
			local best_resolution = {}

			for _, resolution in pairs(unique_resolutions) do
				-- Only show scaling:on modes (Retina scaled resolutions)
				-- Skip native/unscaled modes to match macOS behavior
				if resolution.scaling == "on" then
					local res_key = string.format("%sx%s", resolution.width, resolution.height)
					local hz_num = tonumber(resolution.hz)

					-- Keep only the mode with highest Hz for this resolution
					if not best_resolution[res_key] or hz_num > tonumber(best_resolution[res_key].hz) then
						best_resolution[res_key] = resolution
					end
				end
			end

			-- Convert to array and sort by area (largest to smallest)
			local all_scaled = {}
			for _, resolution in pairs(best_resolution) do
				table.insert(all_scaled, resolution)
			end

			table.sort(all_scaled, function(a, b)
				local area_a = tonumber(a.width) * tonumber(a.height)
				local area_b = tonumber(b.width) * tonumber(b.height)
				if area_a ~= area_b then
					return area_a > area_b
				end
				return tonumber(a.hz) > tonumber(b.hz)
			end)

			-- If no scaling:on modes found (non-Retina displays), fall back to all resolutions
			if #all_scaled == 0 then
				for _, resolution in pairs(unique_resolutions) do
					local res_key = string.format("%sx%s", resolution.width, resolution.height)
					local hz_num = tonumber(resolution.hz)

					-- Keep only the mode with highest Hz for this resolution
					if not best_resolution[res_key] or hz_num > tonumber(best_resolution[res_key].hz) then
						best_resolution[res_key] = resolution
					end
				end

				for _, resolution in pairs(best_resolution) do
					table.insert(all_scaled, resolution)
				end

				table.sort(all_scaled, function(a, b)
					local area_a = tonumber(a.width) * tonumber(a.height)
					local area_b = tonumber(b.width) * tonumber(b.height)
					if area_a ~= area_b then
						return area_a > area_b
					end
					return tonumber(a.hz) > tonumber(b.hz)
				end)
			end

			-- Select evenly-spaced subset (~5-6 options) to match macOS behavior
			local sorted_resolutions = {}
			local total = #all_scaled
			local step = math.max(1, math.floor(total / 6))  -- Target ~6 options

			for i = 1, total, step do
				table.insert(sorted_resolutions, all_scaled[i])
			end

			-- Always include current resolution if not already in list
			local has_current = false
			for _, res in ipairs(sorted_resolutions) do
				if res.is_current then
					has_current = true
					break
				end
			end

			if not has_current then
				-- Find and add current resolution
				for _, res in ipairs(all_scaled) do
					if res.is_current then
						table.insert(sorted_resolutions, res)
						-- Re-sort after adding
						table.sort(sorted_resolutions, function(a, b)
							local area_a = tonumber(a.width) * tonumber(a.height)
							local area_b = tonumber(b.width) * tonumber(b.height)
							if area_a ~= area_b then
								return area_a > area_b
							end
							return tonumber(a.hz) > tonumber(b.hz)
						end)
						break
					end
				end
			end

			-- Add formatted items
			for _, resolution in ipairs(sorted_resolutions) do
				local indicator = resolution.is_current and (active_icon .. " ") or (available_icon .. " ")
				local item = string.format("%s%s - %sx%s @ %sHz",
					indicator,
					display_name,
					resolution.width,
					resolution.height,
					resolution.hz)
				table.insert(resolution_items, item)
			end
		end

		::continue::
	end

	if #resolution_items == 0 then
		return { "No resolutions available" }
	end

	return resolution_items
end

-- Extract resolution details from item string
-- @param item string: item in format "󰍹 Display Name - 3840x2160 @ 60Hz"
-- @return string, string, string, string: display_name, width, height, hz
function M.parse_resolution_item(item)
	-- Parse the full string: "[indicator] Display Name - 3840x2160 @ 60Hz"
	-- Match everything after any leading icon/space and before the resolution
	local pattern = "^.-%s+(.-)%s+%-%s+(%d+)x(%d+)%s+@%s+([%d%.]+)Hz"
	local display_name, width, height, hz = item:match(pattern)

	if not display_name then
		-- Fallback: try without icon prefix
		display_name, width, height, hz = item:match("^(.-)%s+%-%s+(%d+)x(%d+)%s+@%s+([%d%.]+)Hz")
	end

	return display_name, width, height, hz
end

-- Switch to a specific resolution
-- @param item string: resolution item (may include indicator prefix)
-- @return string, number: message, exit_code
function M.switch_resolution(item)
	if not item or item == "" then
		return "Error: No resolution specified", 1
	end

	local display_name, width, height, hz = M.parse_resolution_item(item)

	if not display_name or not width or not height or not hz then
		return "Error: Could not parse resolution from item", 1
	end

	local target_id = shared.find_display_id(display_name)
	if not target_id then
		return string.format("Error: Could not find display '%s'", display_name), 1
	end

	-- Get all displays to preserve their configurations
	local displays = shared.parse_display_info()
	if #displays == 0 then
		return "Error: No displays found", 1
	end

	-- Check if displays are currently mirrored
	local output = shared.get_current_config()
	local is_mirrored = output and output:match('displayplacer "id:[^"]+%+') ~= nil

	local cmd

	if is_mirrored then
		-- Mirrored mode: preserve mirror configuration and source order
		-- Extract the current mirror command to get display order
		local mirror_cmd = output:match('displayplacer "id:([^"]*%+[^"]*)"')

		if not mirror_cmd then
			return "Error: Could not parse mirror configuration", 1
		end

		-- Parse display IDs in order (preserves mirror source)
		local display_ids = {}
		for id in mirror_cmd:gmatch("([^+]+)") do
			-- Trim whitespace
			id = id:match("^%s*(.-)%s*$")
			table.insert(display_ids, id)
		end

		-- In mirrored mode, all displays share the same resolution
		-- Use the new resolution for all displays
		local mirror_id = table.concat(display_ids, "+")
		local res = string.format("%sx%s", width, height)
		local display_hz = hz

		-- Preserve rotation from the mirror source (first display)
		local degree = shared.get_display_degree(display_ids[1]) or "0"

		cmd = string.format(
			"displayplacer \"id:%s res:%s hz:%s scaling:on origin:(0,0) degree:%s\" 2>&1",
			mirror_id,
			res,
			display_hz,
			degree
		)
	else
		-- Extended mode: build multi-display command to preserve arrangement
		local cmds = {}

		for _, display in ipairs(displays) do
			local display_id = display.id
			local res, display_hz, origin, degree

			if display_id == target_id then
				-- Target display: use new resolution, preserve position and rotation
				res = string.format("%sx%s", width, height)
				display_hz = hz
				origin = shared.get_display_origin(display_id)
				degree = shared.get_display_degree(display_id)
			else
				-- Other displays: preserve all current settings
				res = display.current_res or "1920x1080"
				display_hz = display.current_hz or "60"
				origin = shared.get_display_origin(display_id)
				degree = shared.get_display_degree(display_id)
			end

			table.insert(cmds, string.format(
				"\"id:%s res:%s hz:%s scaling:on origin:%s degree:%s\"",
				display_id,
				res,
				display_hz,
				origin,
				degree
			))
		end

		cmd = string.format("displayplacer %s 2>&1", table.concat(cmds, " "))
	end

	local output, code = syntropy.shell(cmd)

	if code ~= 0 then
		return string.format("Error switching resolution: %s", output), 1
	end

	return string.format("Switched %s to %sx%s @ %sHz", display_name, width, height, hz), 0
end

return M
