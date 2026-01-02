local addonName = ...
local loader
local eventFrame
local draggable
local runicPowerBar
local runicPowerText
local runeBars = {}
local runeContainer
local timer
local db
local dbDefaults = {
	-- parent frame config
	Point = "BOTTOM",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = 200,
	Scale = 1.0,
	Width = 120,

	-- visibility settings
	ShowOutOfCombat = true,
	CombatAlpha = 1.0,
	OutOfCombatAlpha = 0.3,

	-- runic power bar config
	RunicPowerHeight = 20,
	RunicPowerGap = 6,
	ShowText = true,

	-- rune grid layout
	RuneRows = 3,
	RuneColumns = 2,
	RuneGap = 3,
	RuneHeight = 20,

	RuneCooldownRed = 0.2,
	RuneCooldownGreen = 0.6,
	RuneCooldownBlue = 1.0,
}

local function IsDeathKnight()
	local _, classTag = UnitClass("player")
	return classTag == "DEATHKNIGHT"
end

local function AddBlackOutline(frame)
	local outline = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	outline:SetPoint("TOPLEFT", frame, -1, 1)
	outline:SetPoint("BOTTOMRIGHT", frame, 1, -1)

	outline:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})

	outline:SetBackdropBorderColor(0, 0, 0, 1)
end

local function CreateDraggable()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")

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
	bar:SetStatusBarColor(0.2, 0.9, 0.2, 1.0)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.35)

	AddBlackOutline(bar)

	return bar
end

local function Layout()
	local width = db.Width
	local rpHeight = db.RunicPowerHeight
	local gap = db.RuneGap
	local rows = db.RuneRows
	local cols = db.RuneColumns
	local runeHeight = db.RuneHeight
	local betweenGap = db.RunicPowerGap

	local gridHeight = rows * runeHeight + (rows - 1) * gap
	local runeWidth = (width - gap * (cols - 1)) / cols

	local totalHeight = gridHeight + betweenGap + rpHeight
	draggable:SetSize(width, totalHeight)

	-- RP bar at bottom
	runicPowerBar:ClearAllPoints()
	runicPowerBar:SetPoint("BOTTOMLEFT", draggable, "BOTTOMLEFT", 0, 0)
	runicPowerBar:SetPoint("BOTTOMRIGHT", draggable, "BOTTOMRIGHT", 0, 0)
	runicPowerBar:SetHeight(rpHeight)

	-- Rune container surrounding everything
	runeContainer:ClearAllPoints()
	runeContainer:SetPoint("TOPLEFT", draggable, "TOPLEFT", 0, 0)
	runeContainer:SetPoint("TOPRIGHT", draggable, "TOPRIGHT", 0, 0)
	runeContainer:SetPoint("BOTTOMLEFT", runicPowerBar, "TOPLEFT", 0, betweenGap)
	runeContainer:SetPoint("BOTTOMRIGHT", runicPowerBar, "TOPRIGHT", 0, betweenGap)

	-- Place rune bars starting at the top left
	for i = 1, 6 do
		local idx = i - 1
		local row = math.floor(idx / cols)
		local col = idx % cols

		local b = runeBars[i]
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", runeContainer, "TOPLEFT", col * (runeWidth + gap), -row * (runeHeight + gap))
		b:SetSize(runeWidth, runeHeight)
	end
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

local function GetRuneColorBySpec()
	local specIndex = GetSpecialization()

	if not specIndex then
		return 1, 1, 1
	end

	local specId = GetSpecializationInfo(specIndex)

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

	-- fallback (should never happen)
	return 1, 1, 1
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

local function UpdateRunes()
	local now = GetTime()
	local r, g, b = GetRuneColorBySpec()

	-- Build list of rune states
	local runes = {}
	for runeId = 1, 6 do
		local remaining, start, duration, ready = GetRuneRemaining(now, runeId)
		runes[#runes + 1] = {
			id = runeId,
			remaining = remaining,
			start = start,
			duration = duration,
			ready = ready,
		}
	end

	-- Sort by least remaining first
	table.sort(runes, function(a, b2)
		if a.remaining ~= b2.remaining then
			return a.remaining < b2.remaining
		end

		return a.id < b2.id
	end)

	-- Paint the 6 UI bars in that order
	for slot = 1, 6 do
		local state = runes[slot]
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
	for i = 1, 6 do
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

local function ApplyDefaults(src, defaults)
	for k, v in pairs(defaults) do
		if src[k] == nil then
			src[k] = v
		end
	end
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

local function ApplyConfig()
	draggable:ClearAllPoints()
	draggable:SetPoint(db.Point, UIParent, db.RelativePoint, db.X, db.Y)
	draggable:SetScale(db.Scale or 1.0)

	Layout()
	UpdateVisibility()
end

local function Load()
	MiniCompactRunesDB = MiniCompactRunesDB or {}

	ApplyDefaults(MiniCompactRunesDB, dbDefaults)

	db = MiniCompactRunesDB

	draggable = CreateDraggable()
	runicPowerBar, runicPowerText = CreateRunicPowerBar()

	runeContainer = CreateFrame("Frame", nil, draggable)
	runeContainer:EnableMouse(false)

	for i = 1, 6 do
		runeBars[i] = CreateRuneBar(runeContainer)
	end

	ApplyConfig()
	UpdateBar()
	UpdateRunes()

	eventFrame = CreateFrame("Frame")

	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

	-- runic power
	eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
	eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")

	-- rune events
	eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
	eventFrame:RegisterEvent("RUNE_TYPE_UPDATE")

	-- combat alpha switching
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	eventFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			UpdateVisibility()
			return
		end

		if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
			UpdateRunes()
			EnsureRuneTimer()
			return
		end

		UpdateBar()

		if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
			UpdateRunes()
			EnsureRuneTimer()
		end
	end)
end

loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, ...)
	local name = ...

	if name ~= addonName then
		return
	end

	if not IsDeathKnight() then
		return
	end

	Load()
end)
