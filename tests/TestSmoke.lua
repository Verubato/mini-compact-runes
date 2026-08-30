-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.
--
-- Logs in as a Death Knight: the addon checks the player's class before it sets anything up,
-- so any other class would smoke test an addon that deliberately did nothing.

local fw = require("TestFramework")
local smoke = require("SmokeTest")

smoke.Run("MiniCompactRunes", {
	class = "DEATHKNIGHT",
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
	end,
})
