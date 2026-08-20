local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
local eventFrame
local draggable
local runicPowerBar
local runicPowerText
local runeBars = {}
local runeContainer
local timer
local runesCount = 6
-- Rune state, reused across passes. UpdateRunes runs ten times a second for as long as any
-- rune is recharging, so the six entries are refilled rather than rebuilt.
local runeStates = {}
-- The spec color, and the spec it was read for. The color only moves when the player respecs.
local runeColorR, runeColorG, runeColorB
local runeColorSpec
-- Drawn on a ready rune until the client can say which spec the player is. A DK who has not
-- picked one, and the first moments of a login, both land here; white reads as a fault rather
-- than a colour, so this matches how a bar is drawn before anything paints it.
local defaultRuneR, defaultRuneG, defaultRuneB = 0.2, 0.9, 0.2
---@type Db
local db

local function IsDeathKnight()
	local _, classTag = UnitClass("player")
	return classTag == "DEATHKNIGHT"
end

local function AddBlackOutline(frame)
	local outline = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	outline:SetPoint("TOPLEFT", frame, 0, 0)
	outline:SetPoint("BOTTOMRIGHT", frame, 0, 0)

	outline:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})

	outline:SetBackdropBorderColor(0, 0, 0, 1)
end

local function CreateDraggable()
	local frame = CreateFrame("Frame", addonName .. "Container", UIParent)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")

	if frame.SetDontSavePosition then
		frame:SetDontSavePosition(true)
	end

	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)

	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()

		local point, _, relativePoint, x, y = self:GetPoint(1)
		db.Point = point
		db.RelativePoint = relativePoint
		db.X = x
		db.Y = y
	end)

	return frame
end

local function CreateRunicPowerBar()
	local bar = CreateFrame("StatusBar", nil, draggable)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	bar:SetStatusBarColor(0.0, 0.75, 1.0, 1.0)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.35)

	local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	text:SetText("0")

	AddBlackOutline(bar)

	return bar, text
end

local function GetRunicPower()
	local powerType = Enum.PowerType.RunicPower
	local cur = UnitPower("player", powerType)
	local max = UnitPowerMax("player", powerType)
	if not max or max <= 0 then
		max = 100
	end
	return cur or 0, max
end

local function CreateRuneBar(container)
	local bar = CreateFrame("StatusBar", nil, container)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)

	-- simple coloring: ready = bright, cooling = dim
	bar:SetStatusBarColor(defaultRuneR, defaultRuneG, defaultRuneB, 1.0)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.35)

	AddBlackOutline(bar)

	return bar
end

local function Layout()
	local rows = db.RuneRows
	local cols = db.RuneColumns
	local runeHeight = db.RuneHeight
	local runeWidth = db.RuneWidth
	local runeGap = db.RunesGap
	local rpWidth = db.RunicPowerWidth
	local rpHeight = db.RunicPowerHeight
	local rpGap = db.RunicPowerGap
	local gridHeight = rows * runeHeight + (rows - 1) * runeGap
	local gridWidth = cols * runeWidth + (cols - 1) * runeGap
	local totalHeight = gridHeight + rpGap + rpHeight
	local totalWidth = math.max(rpWidth, gridWidth)

	draggable:SetSize(totalWidth, totalHeight)

	-- power bar at bottom
	runicPowerBar:ClearAllPoints()
	runicPowerBar:SetPoint("BOTTOM", draggable, "BOTTOM", 0, 0)
	runicPowerBar:SetSize(rpWidth, rpHeight)

	-- runes container
	runeContainer:ClearAllPoints()
	runeContainer:SetPoint("TOP", draggable, "TOP", 0, 0)
	runeContainer:SetPoint("BOTTOM", runicPowerBar, "TOP", 0, rpGap)
	runeContainer:SetWidth(gridWidth)

	-- place runes in column order (fill down then across)
	for i = 1, runesCount do
		local idx = i - 1
		local col = math.floor(idx / rows)
		local row = idx % rows

		local b = runeBars[i]
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", runeContainer, "TOPLEFT", col * (runeWidth + runeGap), -row * (runeHeight + runeGap))
		b:SetSize(runeWidth, runeHeight)
	end
end

local function ApplyLock()
	local locked = db.Locked
	draggable:EnableMouse(not locked)
	draggable:SetMovable(not locked)
end

local function UpdateVisibility()
	local inCombat = UnitAffectingCombat("player")
	local alpha = inCombat and (db.CombatAlpha or 1.0) or (db.OutOfCombatAlpha or 0.3)

	draggable:SetAlpha(alpha)

	if not inCombat and not db.ShowOutOfCombat then
		draggable:Hide()
	else
		draggable:Show()
	end
end

-- 12.1 moved the specialization functions onto C_SpecializationInfo and the globals stopped
-- answering, which left every rune painted the fallback color. The classic clients this addon
-- also supports only have the globals, so both shapes are tried.

---@return number? specIndex
local function GetPlayerSpecIndex()
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		return C_SpecializationInfo.GetSpecialization()
	end

	if GetSpecialization then
		return GetSpecialization()
	end

	return nil
end

---@return number? specId
local function GetPlayerSpecId(specIndex)
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		return (C_SpecializationInfo.GetSpecializationInfo(specIndex))
	end

	if GetSpecializationInfo then
		return (GetSpecializationInfo(specIndex))
	end

	return nil
end

---@return number? r nil unless the spec is one this addon has a color for
local function ReadRuneColorBySpec(specIndex)
	if not specIndex then
		return nil
	end

	local specId = GetPlayerSpecId(specIndex)

	-- Blood
	if specId == 250 then
		return 0.51, 0, 0

	-- Frost
	elseif specId == 251 then
		return 0, 0.99, 1

	-- Unholy
	elseif specId == 252 then
		return 0.2, 0.8, 0.2
	end

	-- No color to give: the info is not ready yet, or this client reports the id in a shape
	-- the branches above do not recognise. Either way there is nothing worth remembering.
	return nil
end

local function GetRuneColorBySpec()
	local specIndex = GetPlayerSpecIndex()

	-- Keyed on the spec rather than refreshed by event, so a respec is picked up on the next
	-- pass whether or not the event announcing it reached this file.
	if specIndex ~= runeColorSpec or runeColorR == nil then
		local r, g, b = ReadRuneColorBySpec(specIndex)

		-- Only a real answer is cached. Remembering the fallback would hold the wrong color
		-- for the rest of the session, because the index it was read for does not change.
		if not r then
			return defaultRuneR, defaultRuneG, defaultRuneB
		end

		runeColorSpec = specIndex
		runeColorR, runeColorG, runeColorB = r, g, b
	end

	return runeColorR, runeColorG, runeColorB
end

local function GetRuneRemaining(now, runeId)
	local start, duration, ready = GetRuneCooldown(runeId)

	-- Ready runes have 0 remaining
	if ready or not duration or duration <= 0 then
		return 0, start, duration, true
	end

	local remaining = (start + duration) - now

	if remaining < 0 then
		remaining = 0
	end

	return remaining, start, duration, false
end

---Orders rune states by how much of their cooldown is left. Kept out of UpdateRunes because an
---inline comparator is a fresh closure per sort, and this one sorts ten times a second.
local function ByRemaining(x, y)
	return (x.remaining < y.remaining)
end

local function UpdateRunes()
	local now = GetTime()
	local r, g, b = GetRuneColorBySpec()

	-- Refilled in place; table.sort then reorders the same six entries.
	for runeId = 1, runesCount do
		local remaining, start, duration, ready = GetRuneRemaining(now, runeId)
		local state = runeStates[runeId]

		if not state then
			state = {}
			runeStates[runeId] = state
		end

		state.id = runeId
		state.remaining = remaining
		state.start = start
		state.duration = duration
		state.ready = ready
	end

	table.sort(runeStates, ByRemaining)

	-- Paint the 6 UI bars in reverse column order
	-- so our runes are 123456, but we paint their cooldowns in 654321
	for slot = 1, runesCount do
		local state = runeStates[slot]
		local bar = runeBars[slot]

		if state.ready or not state.duration or state.duration <= 0 then
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
			bar:SetStatusBarColor(r, g, b, 1.0)
		else
			bar:SetMinMaxValues(0, state.duration)
			bar:SetValue(now - state.start)
			bar:SetStatusBarColor(
				db.RuneCooldownRed or 0.2,
				db.RuneCooldownGreen or 0.6,
				db.RuneCooldownBlue or 1.0,
				1.0
			)
		end
	end
end

local function AnyRuneCoolingDown()
	for i = 1, runesCount do
		local _, duration, ready = GetRuneCooldown(i)
		if ready == false and duration and duration > 0 then
			return true
		end
	end
	return false
end

local function StopRuneTimer()
	if timer then
		timer:Cancel()
		timer = nil
	end
end

local function EnsureRuneTimer()
	-- already running
	if timer then
		return
	end

	-- only run while needed
	if not AnyRuneCoolingDown() then
		return
	end

	-- update 10x/sec; smooth enough, cheap
	timer = C_Timer.NewTicker(0.10, function()
		UpdateRunes()

		-- stop once everything is ready again
		if not AnyRuneCoolingDown() then
			StopRuneTimer()
			-- one last refresh to ensure full bars/colors
			UpdateRunes()
		end
	end)
end

local function UpdateBar()
	local cur, max = GetRunicPower()
	runicPowerBar:SetMinMaxValues(0, max)
	runicPowerBar:SetValue(cur)

	if db.ShowText then
		runicPowerText:Show()
		runicPowerText:SetText(cur)
	else
		runicPowerText:Hide()
	end
end

local function OnEvent(_, event, _, powerType)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		UpdateVisibility()
		return
	end

	if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
		UpdateRunes()
		EnsureRuneTimer()
		return
	end

	-- The power events cover every power type the player has, and an energy tick has nothing
	-- to say about a runic power bar.
	if event == "UNIT_POWER_UPDATE" and powerType ~= "RUNIC_POWER" then
		return
	end

	UpdateBar()

	if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
		UpdateRunes()
		EnsureRuneTimer()
	end
end

local function Init()
	if not IsDeathKnight() then
		return
	end

	addon.Config:Init()
	db = mini:GetSavedVars()

	draggable = CreateDraggable()
	runicPowerBar, runicPowerText = CreateRunicPowerBar()

	runeContainer = CreateFrame("Frame", nil, draggable)
	runeContainer:EnableMouse(false)

	for i = 1, runesCount do
		runeBars[i] = CreateRuneBar(runeContainer)
	end

	draggable:ClearAllPoints()
	draggable:SetPoint(db.Point, UIParent, db.RelativePoint, db.X, db.Y)
	draggable:SetScale(db.Scale or 1.0)

	Layout()
	ApplyLock()
	UpdateVisibility()
	UpdateBar()
	UpdateRunes()

	eventFrame = CreateFrame("Frame")

	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

	-- runic power. Unit filtered, or every nearby unit's energy and mana ticks land here too
	-- and each one repaints the player's bar.
	eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")

	-- rune events
	eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
	eventFrame:RegisterEvent("RUNE_TYPE_UPDATE")

	-- combat alpha switching
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	eventFrame:SetScript("OnEvent", OnEvent)
end

function addon:Refresh()
	Layout()
	ApplyLock()
	UpdateVisibility()
end

mini:WaitForAddonLoad(Init)
