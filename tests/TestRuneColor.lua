-- Ready runes take their colour from the player's spec. Two things make that worth pinning:
--
--   * Where the spec comes from. 12.1 moved the specialization functions onto
--     C_SpecializationInfo and the globals stopped answering, which painted every rune the
--     fallback colour on retail. The classic clients this addon also supports only have the
--     globals, so both shapes have to work. The mock defines both at once, so a test that does
--     not take one away cannot tell the difference.
--   * What happens when the spec cannot be read at all. The colour is cached so the client is
--     not asked ten times a second, and a fallback that gets stored is a wrong colour for the
--     rest of the session, with nothing to shake it out.

local fw = require("TestFramework")
local WowMock = require("WowMock")
local harness = require("AddonHarness")

local BLOOD, FROST, UNHOLY = 250, 251, 252

fw.describe("MiniCompactRunes - ready rune colour", function()
	local env

	---Loads the addon with the spec APIs under the test's control, recording every colour
	---written to a rune bar.
	---@param opts table specIndex, specId, and api: "modern" (12.1), "legacy", or both
	local function Build(opts)
		local context = harness.Load("MiniCompactRunes", { class = "DEATHKNIGHT" })

		env = { Writes = {}, SpecIndex = opts.specIndex, SpecId = opts.specId }

		local function Index()
			return env.SpecIndex
		end

		local function Info(index)
			if index ~= env.SpecIndex then
				return nil
			end
			return env.SpecId, "Spec", "A spec", 134400, "DAMAGER"
		end

		local api = opts.api or "both"

		if api == "modern" then
			-- What a 12.1 client looks like: the globals are gone.
			_G.GetSpecialization = nil
			_G.GetSpecializationInfo = nil
			_G.C_SpecializationInfo = { GetSpecialization = Index, GetSpecializationInfo = Info }
		elseif api == "legacy" then
			_G.C_SpecializationInfo = nil
			_G.GetSpecialization = Index
			_G.GetSpecializationInfo = Info
		else
			_G.C_SpecializationInfo = { GetSpecialization = Index, GetSpecializationInfo = Info }
			_G.GetSpecialization = Index
			_G.GetSpecializationInfo = Info
		end

		-- Every rune is off cooldown, so every bar takes the ready colour.
		_G.GetRuneCooldown = function()
			return 0, 0, true
		end

		local baseCreateFrame = _G.CreateFrame

		_G.CreateFrame = function(frameType, ...)
			local f = baseCreateFrame(frameType, ...)

			if frameType == "StatusBar" and f.SetStatusBarColor then
				local base = f.SetStatusBarColor
				f.SetStatusBarColor = function(self, r, g, b, a)
					env.Writes[#env.Writes + 1] = { r = r, g = g, b = b }
					return base(self, r, g, b, a)
				end
			end

			return f
		end

		harness.Login(context)

		return env
	end

	---The colour the most recent pass painted a ready rune.
	local function LastColour()
		env.Writes = {}
		WowMock.FireEvent("RUNE_POWER_UPDATE")

		local last = env.Writes[#env.Writes]
		fw.truthy(last, "a rune bar was painted")

		return last
	end

	local function IsWhite(c)
		return c.r == 1 and c.g == 1 and c.b == 1
	end

	local function AssertFrost(c, why)
		fw.eq(c.r, 0, why .. " red")
		fw.eq(c.g, 0.99, why .. " green")
		fw.eq(c.b, 1, why .. " blue")
	end

	-- Where the spec is read from

	fw.it("reads the spec through C_SpecializationInfo when the globals are gone", function()
		Build({ specIndex = 1, specId = FROST, api = "modern" })

		AssertFrost(LastColour(), "frost on a 12.1 client")
	end)

	fw.it("falls back to the globals on a client without C_SpecializationInfo", function()
		Build({ specIndex = 1, specId = FROST, api = "legacy" })

		AssertFrost(LastColour(), "frost on a classic client")
	end)

	-- The colours themselves

	fw.it("paints each spec its own colour", function()
		Build({ specIndex = 1, specId = FROST })
		AssertFrost(LastColour(), "frost")

		Build({ specIndex = 1, specId = BLOOD })
		fw.eq(LastColour().r, 0.51, "blood red")

		Build({ specIndex = 1, specId = UNHOLY })
		fw.eq(LastColour().g, 0.8, "unholy green")
	end)

	-- When the spec cannot be read

	fw.it("never paints a ready rune white when the spec cannot be read", function()
		-- Early in login the index resolves before its info does.
		Build({ specIndex = 1, specId = nil })
		fw.falsy(IsWhite(LastColour()), "unresolved spec info is not white")

		-- A client that answers the id in a shape this addon does not know.
		Build({ specIndex = 1, specId = "251" })
		fw.falsy(IsWhite(LastColour()), "unrecognised spec id is not white")

		Build({ specIndex = nil, specId = nil })
		fw.falsy(IsWhite(LastColour()), "no spec index at all is not white")

		-- Neither API present at all.
		Build({ specIndex = 1, specId = FROST, api = "legacy" })
		_G.GetSpecialization = nil
		_G.GetSpecializationInfo = nil
		fw.falsy(IsWhite(LastColour()), "no spec api at all is not white")
	end)

	fw.it("picks the colour up once the spec resolves, without the index changing", function()
		-- The index stays 1 throughout; only the info the client gives for it changes. A
		-- cached fallback would keep the first answer for the rest of the session.
		Build({ specIndex = 1, specId = nil })
		fw.falsy(IsWhite(LastColour()), "not white while unresolved")

		env.SpecId = FROST

		AssertFrost(LastColour(), "frost once resolved")
	end)

	fw.it("follows a respec", function()
		Build({ specIndex = 1, specId = FROST })
		fw.eq(LastColour().g, 0.99, "frost before the respec")

		env.SpecIndex = 3
		env.SpecId = UNHOLY

		fw.eq(LastColour().g, 0.8, "unholy after the respec")
	end)
end)
