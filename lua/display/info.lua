-- Display information module
-- Retrieves current display configuration details

local M = {}
local shared = require("display.shared")

-- Get formatted display configuration
-- @return string, string: config or nil, error message or nil
function M.get_display_info()
	local ok, err = shared.check_dependencies()
	if not ok then
		return nil, err
	end

	local config = shared.get_current_config()
	if not config then
		return nil, "Could not get display configuration"
	end

	return config, nil
end

return M
