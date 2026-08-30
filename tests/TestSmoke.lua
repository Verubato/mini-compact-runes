-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.
--
-- Logs in as a Death Knight so this suite exercises the rune display as well as the settings
-- page. The settings-only path for every other class is covered by TestNonDeathKnight.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

---The section rule is built by the framework and never handed back to the addon, so a test
---finds it the way a player sees it, by its label.
---@param text string
---@return boolean
local function HasDivider(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == text then
			return true
		end
	end

	return false
end

---The confirmation dialog is a frame the framework owns, so a test reaches it by its button label.
---@param label string
---@return table?
local function FindButton(label)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.GetText and frame:GetText() == label and frame.Click then
			return frame
		end
	end

	return nil
end

smoke.Run("MiniCompactRunes", {
	class = "DEATHKNIGHT",
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.truthy(HasDivider("SETTINGS"), "the settings section rule under the header")

		local db = _G["MiniCompactRunesDB"]
		db.RunicPowerWidth = 400
		db.ShowOutOfCombat = not context.Addon.Config.DbDefaults.ShowOutOfCombat

		local resetBtn = FindButton("Reset to Defaults")
		fw.not_nil(resetBtn, "reset button exists")
		resetBtn:Click()

		local confirmAccept = FindButton("Reset")
		fw.not_nil(confirmAccept, "the confirmation dialog opened")
		confirmAccept:Click()

		fw.eq(db.RunicPowerWidth, context.Addon.Config.DbDefaults.RunicPowerWidth, "reset restored RunicPowerWidth")
		fw.eq(db.ShowOutOfCombat, context.Addon.Config.DbDefaults.ShowOutOfCombat, "reset restored ShowOutOfCombat")
	end,
})
