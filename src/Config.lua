local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
---@type Db
local db
---@class Db
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

	Gap = 6,

	-- runic power bar config
	RunicPowerHeight = 20,
	ShowText = true,

	-- rune grid layout
	RuneRows = 3,
	RuneColumns = 2,
	RuneHeight = 20,

	RuneCooldownRed = 0.2,
	RuneCooldownGreen = 0.6,
	RuneCooldownBlue = 1.0,
}
local M = {
	DbDefaults = dbDefaults,
}

addon.Config = M

function M:Init()
	db = mini:GetSavedVars(dbDefaults)
	mini:CleanTable(db, dbDefaults, true, false)

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
		LabelText = "Width",
		Min = 50,
		Max = 500,
		Step = 10,
		Width = sliderWidth,
		GetValue = function()
			return db.Width
		end,
		SetValue = function(value)
			db.Width = mini:ClampInt(value, 50, 500, dbDefaults.Width)
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

	local gapSlider = mini:Slider({
		Parent = panel,
		LabelText = "Gap/Padding",
		Min = 0,
		Max = 20,
		Step = 1,
		Width = sliderWidth,
		GetValue = function()
			return db.Gap
		end,
		SetValue = function(value)
			db.Gap = mini:ClampInt(value, 0, 20, dbDefaults.Gap)
			addon:Refresh()
		end,
	})

	gapSlider.Slider:SetPoint("TOPLEFT", runesHeightSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 3)
end
