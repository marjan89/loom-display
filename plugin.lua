-- Display resolution plugin
-- Provides tasks for switching display resolutions on macOS

local resolution = require("display.resolution")
local arrangement = require("display.arrangement")
local info = require("display.info")

-- Default configuration
local default_config = {
	active_icon = "◍",  -- Unicode filled circle for active/current resolution
	available_icon = "○",  -- Unicode empty circle for available resolution
}

-- Get configuration with fallback to defaults
local function get_config()
	local plugin = display  -- Plugin is stored in globals with its name
	return plugin and plugin.config or default_config
end

-- Get icon configuration
local function get_icons()
	local config = get_config()
	return config.active_icon, config.available_icon
end

---@type PluginDefinition
return {
	metadata = {
		name = "display",
		version = "1.0.0",
		icon = "󰍹",
		description = "Manage macOS display configurations with ease. Switch resolutions and refresh rates across multiple displays, toggle between mirrored and extended desktop modes, set primary displays, and view detailed display information. Requires displayplacer for seamless display management through an intuitive interface.",
		platforms = { "macos" },
	},

	tasks = {
		-- Resolution switching task
		resolution = {
			name = "Switch Resolution",
			description = "Change display resolution and refresh rate",
			mode = "none",
			exit_on_execute = true,

			item_sources = {
				resolutions = {
					tag = "res",

					items = function()
						local active_icon, available_icon = get_icons()
						return resolution.list_resolutions(active_icon, available_icon)
					end,

					preview = function(item)
						local active_icon, available_icon = get_icons()
						local display_name, width, height, hz = resolution.parse_resolution_item(item)

						if not display_name then
							return "Invalid resolution format"
						end

						-- Escape special characters in icons for pattern matching
						local active_escaped = active_icon:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

						local is_current = item:match("^" .. active_escaped .. " ") ~= nil

						local status_icon = is_current and active_icon or available_icon
						local status_text = is_current and "Current" or "Available"

						return string.format(
							"%s %s Resolution\n\n%s\n%sx%s @ %s Hz\n\n%s",
							status_icon,
							status_text,
							display_name,
							width or "?",
							height or "?",
							hz or "?",
							is_current and "Currently active" or "Select to switch"
						)
					end,

					execute = function(items)
						if not items or #items == 0 then
							return "Error: No resolution selected", 1
						end

						return resolution.switch_resolution(items[1])
					end,
				},
			},
		},

		-- Display arrangement configuration
		arrangement = {
			name = "Display Arrangement",
			description = "Configure display mirroring, extended desktop, and primary display",
			mode = "none",
			exit_on_execute = false,

			item_sources = {
				arrangements = {
					tag = "cfg",

					items = function()
						local active_icon, available_icon = get_icons()
						return arrangement.list_arrangements(active_icon, available_icon)
					end,

					preview = function(item)
						local active_icon, available_icon = get_icons()

						if item:match("Current: Mirrored") then
							return active_icon .. " Mirrored Displays\n\nAll displays show the same content.\nUseful for presentations and demos."

						elseif item:match("Current: Extended") then
							return active_icon .. " Extended Desktop\n\nDisplays form one large desktop.\nYou can drag windows between displays."

						elseif item:match("Switch to Mirrored") then
							return available_icon .. " Enable Mirroring\n\nMirror all displays to show the same content.\nUseful for presentations and demos.\n\nNote: All displays will use the same resolution."

						elseif item:match("Switch to Extended") then
							return available_icon .. " Enable Extended Desktop\n\nArrange displays side-by-side.\nExpands your workspace across multiple screens.\n\nDisplays will be arranged left to right."

						elseif item:match("Set Primary: (.+)") then
							local display_name = item:match("Set Primary: (.+)")
							return string.format("Set as Primary Display\n\n%s\n\nThis display will show:\n- Menu bar\n- Dock\n- New windows by default", display_name)

						elseif item:match("Set Mirror Source: (.+)") then
							local display_name = item:match("Set Mirror Source: (.+)")
							return string.format("Set as Mirror Source\n\n%s\n\nOther displays will mirror this display's content.", display_name)

						elseif item:match("Mirror Source: (.+)") then
							local display_name = item:match("Mirror Source: (.+)")
							return string.format(active_icon .. " Mirror Source\n\n%s\n\nThis display is the source.\nOther displays mirror its content.", display_name)

						elseif item:match("Primary: (.+)") then
							local display_name = item:match("Primary: (.+)")
							return string.format(active_icon .. " Primary Display\n\n%s\n\nThe primary display shows:\n- Menu bar\n- Dock\n- New windows by default", display_name)
						end

						return "Display arrangement option"
					end,

					execute = function(items)
						if not items or #items == 0 then
							return "Error: No arrangement selected", 1
						end

						return arrangement.apply_arrangement(items[1])
					end,
				},
			},
		},

		-- Get current display configuration (useful for debugging)
		info = {
			name = "Display Info",
			description = "Show current display configuration details",
			mode = "none",
			exit_on_execute = false,

			execute = function()
				local config, err = info.get_display_info()
				if not config then
					return "Error: " .. (err or "Could not get display configuration"), 1
				end

				return config, 0
			end,
		},
	},
}
