-- Every class gets the options page, even one that has no runes to track. Only the death
-- knight display is withheld.

local fw = require("TestFramework")
local harness = require("AddonHarness")

fw.describe("MiniCompactRunes - non death knight", function()
	fw.it("builds the options page but never creates the rune display", function()
		local context = harness.Load("MiniCompactRunes", { class = "WARRIOR" })

		harness.Login(context)

		fw.eq(context.Addon.IsDeathKnight, false, "class field reads false for a warrior")
		fw.not_nil(_G.SlashCmdList["MINICOMPACTRUNES"], "the slash command is still registered")
		fw.eq(_G["MiniCompactRunesContainer"], nil, "the rune display frame was never created")

		local handler = _G.SlashCmdList["MINICOMPACTRUNES"]
		local ok, err = pcall(handler, "")

		fw.truthy(ok, "the settings slash command still errors nothing: " .. tostring(err))

		-- The config panel calls this from every checkbox and slider, for every class now
		-- that the panel is always built.
		local refreshOk, refreshErr = pcall(function()
			context.Addon:Refresh()
		end)

		fw.truthy(refreshOk, "Refresh does not error without a rune display: " .. tostring(refreshErr))
	end)
end)
