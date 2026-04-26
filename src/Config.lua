local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
---@type Db
local db
---@class Db
local dbDefaults = {
	Version = 2,

	-- parent frame config
	Point = "BOTTOM",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = 200,
	Scale = 1.0,

	Locked = false,

	-- visibility settings
	ShowOutOfCombat = true,
	CombatAlpha = 1.0,
	OutOfCombatAlpha = 0.3,

	ShowText = true,

	-- runic power bar config
	RunicPowerWidth = 120,
	RunicPowerHeight = 20,
	RunicPowerGap = 0,

	-- rune grid layout
	RuneRows = 3,
	RuneColumns = 2,
	RuneWidth = 120,
	RuneHeight = 20,
	RunesGap = 6,

	RuneCooldownRed = 0.2,
	RuneCooldownGreen = 0.6,
	RuneCooldownBlue = 1.0,
}
local M = {
	DbDefaults = dbDefaults,
}

addon.Config = M

local function GetAndUpdateDb()
	local isFirstInit = MiniCompactRunesDB == nil
	local vars

	if isFirstInit then
		vars = mini:GetSavedVars(dbDefaults)
	else
		-- get a copy without db defaults applied, as we don't want to automatically place a version on it yet
		vars = mini:GetSavedVars()
	end

	if not vars.Version or vars.Version == 1 then
		vars.RunicPowerWidth = vars.Width
		vars.RuneWidth = vars.Width / 2
		vars.RunesGap = vars.Gap
		vars.Version = 2
		mini:CleanTable(vars, dbDefaults, true, false)
	end

	vars = mini:GetSavedVars(dbDefaults)

	return vars
end

function M:Init()
	db = GetAndUpdateDb()

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	local verticalSpacing = mini.VerticalSpacing
	local horizontalSpacing = mini.HorizontalSpacing
	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)

	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetText("Runes and runic power tracker.")

	mini:RegisterSlashCommand(category, panel, {
		"/minicompactrunes",
		"/minicr",
		"/mcr",
	})

	local alwaysShow = mini:Checkbox({
		Parent = panel,
		LabelText = "Always show",
		GetValue = function()
			return db.ShowOutOfCombat
		end,
		SetValue = function(value)
			db.ShowOutOfCombat = value
			addon:Refresh()
		end,
	})

	alwaysShow:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -verticalSpacing)

	local showText = mini:Checkbox({
		Parent = panel,
		LabelText = "Show text",
		GetValue = function()
			return db.ShowText
		end,
		SetValue = function(value)
			db.ShowText = value
			addon:Refresh()
		end,
	})

	showText:SetPoint("TOP", alwaysShow, "TOP", 0, 0)
	showText:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)

	local lockFrame = mini:Checkbox({
		Parent = panel,
		LabelText = "Locked",
		GetValue = function()
			return db.Locked
		end,
		SetValue = function(value)
			db.Locked = value
			addon:Refresh()
		end,
	})

	lockFrame:SetPoint("TOP", alwaysShow, "TOP", 0, 0)
	lockFrame:SetPoint("LEFT", panel, "LEFT", columnWidth * 2, 0)

	local sliderWidth = (columns / 2 * columnWidth) - horizontalSpacing
	local rpWidthSlider = mini:Slider({
		Parent = panel,
		LabelText = "Power Width",
		Min = 50,
		Max = 800,
		Step = 10,
		Width = sliderWidth,
		GetValue = function()
			return db.RunicPowerWidth
		end,
		SetValue = function(value)
			db.RunicPowerWidth = mini:ClampInt(value, 50, 800, dbDefaults.RunicPowerWidth)
			addon:Refresh()
		end,
	})

	rpWidthSlider.Slider:SetPoint("TOPLEFT", alwaysShow, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local rpHeightSlider = mini:Slider({
		Parent = panel,
		LabelText = "Power Height",
		Min = 10,
		Max = 100,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RunicPowerHeight
		end,
		SetValue = function(value)
			db.RunicPowerHeight = mini:ClampInt(value, 10, 100, dbDefaults.RunicPowerHeight)
			addon:Refresh()
		end,
	})

	rpHeightSlider.Slider:SetPoint("LEFT", rpWidthSlider.Slider, "RIGHT", horizontalSpacing, 0)

	local runesWidthSlider = mini:Slider({
		Parent = panel,
		LabelText = "Runes Width",
		Min = 10,
		Max = 300,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RuneWidth
		end,
		SetValue = function(value)
			db.RuneWidth = mini:ClampInt(value, 10, 300, dbDefaults.RuneWidth)
			addon:Refresh()
		end,
	})

	runesWidthSlider.Slider:SetPoint("TOPLEFT", rpWidthSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local runesHeightSlider = mini:Slider({
		Parent = panel,
		LabelText = "Runes Height",
		Min = 10,
		Max = 100,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RuneHeight
		end,
		SetValue = function(value)
			db.RuneHeight = mini:ClampInt(value, 10, 100, dbDefaults.RuneHeight)
			addon:Refresh()
		end,
	})

	runesHeightSlider.Slider:SetPoint("LEFT", runesWidthSlider.Slider, "RIGHT", horizontalSpacing, 0)

	local powerGapSlider = mini:Slider({
		Parent = panel,
		LabelText = "Power Gap",
		Min = 0,
		Max = 50,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RunicPowerGap
		end,
		SetValue = function(value)
			db.RunicPowerGap = mini:ClampInt(value, 0, 50, dbDefaults.RunicPowerGap)
			addon:Refresh()
		end,
	})

	powerGapSlider.Slider:SetPoint("TOPLEFT", runesWidthSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local gapSlider = mini:Slider({
		Parent = panel,
		LabelText = "Runes Gap",
		Min = 0,
		Max = 20,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RunesGap
		end,
		SetValue = function(value)
			db.RunesGap = mini:ClampInt(value, 0, 20, dbDefaults.RunesGap)
			addon:Refresh()
		end,
	})

	gapSlider.Slider:SetPoint("LEFT", powerGapSlider.Slider, "RIGHT", horizontalSpacing, 0)

	local columnsSlider = mini:Slider({
		Parent = panel,
		LabelText = "Columns",
		Min = 1,
		Max = 3,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RuneColumns
		end,
		SetValue = function(value)
			db.RuneColumns = mini:ClampInt(value, 1, 3, dbDefaults.RuneColumns)
			db.RuneRows = 6 / db.RuneColumns
			addon:Refresh()
		end,
	})

	columnsSlider.Slider:SetPoint("TOPLEFT", powerGapSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)
end
