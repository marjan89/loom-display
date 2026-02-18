-- Configuration example for syntropy-display plugin
--
-- This file shows how to override the default display plugin settings.
--
-- To use this configuration:
-- 1. Create the directory: ~/.config/syntropy/plugins/syntropy-display/
-- 2. Copy this file to: ~/.config/syntropy/plugins/syntropy-display/plugin.lua
-- 3. Modify the config values as desired
--
-- The configuration will be automatically loaded when the plugin starts.

---@type PluginOverride
return {
	metadata = {
		name = "display",  -- Must match the plugin name
		version = "1.0.0",
	},

	config = {
		-- Icons used to indicate resolution and arrangement status
		-- Default values use standard Unicode circles:
		active_icon = "◍",     -- Icon for current/active resolution or state
		available_icon = "○",  -- Icon for available resolutions or options

		-- Example: Use Nerd Font icons (requires a Nerd Font to be installed)
		-- active_icon = "󰍹",     -- Nerd Font display icon (filled)
		-- available_icon = "󰍺", -- Nerd Font display icon (outline)

		-- Example: Use emoji
		-- active_icon = "✓",
		-- available_icon = "○",

		-- Example: Use simple ASCII
		-- active_icon = "*",
		-- available_icon = "-",
	},
}
