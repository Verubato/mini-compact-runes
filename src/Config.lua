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
	local vars = mini:GetSavedVars(dbDefaults)
	mini:CleanTable(vars, dbDefaults, true, false)

	if not vars.Version or vars.Version == 1 then
		vars.RunicPowerWidth = vars.Width
		vars.RuneWidth = vars.Width / 2
		vars.RunesGap = vars.Gap
		vars.Version = 2
	end

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

	local sliderWidth = (columns * columnWidth) - horizontalSpacing

	local widthSlider = mini:Slider({
		Parent = panel,
		LabelText = "Power Width",
		Min = 50,
		Max = 500,
		Step = 10,
		Width = sliderWidth,
		GetValue = function()
			return db.RunicPowerWidth
		end,
		SetValue = function(value)
			db.RunicPowerWidth = mini:ClampInt(value, 50, 500, dbDefaults.RunicPowerWidth)
			addon:Refresh()
		end,
	})

	widthSlider.Slider:SetPoint("TOPLEFT", alwaysShow, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local runicPowerHeightSlider = mini:Slider({
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

	runicPowerHeightSlider.Slider:SetPoint("TOPLEFT", widthSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

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

	runesHeightSlider.Slider:SetPoint("TOPLEFT", runicPowerHeightSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local powerGapSlider = mini:Slider({
		Parent = panel,
		LabelText = "Power Gap",
		Min = 0,
		Max = 20,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.RunicPowerGap
		end,
		SetValue = function(value)
			db.RunicPowerGap = mini:ClampInt(value, 0, 20, dbDefaults.RunicPowerGap)
			addon:Refresh()
		end,
	})

	powerGapSlider.Slider:SetPoint("TOPLEFT", runesHeightSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

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

	gapSlider.Slider:SetPoint("TOPLEFT", powerGapSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)
end
