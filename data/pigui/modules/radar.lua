-- Copyright © 2008-2024 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game = require 'Game'
local Event = require 'Event'
local Input = require 'Input'

local Lang = require 'Lang'
local lui = Lang.GetResource("ui-core");

local ui = require 'pigui'

local player = nil
local pionillium = ui.fonts.pionillium
local colors = ui.theme.colors
local icons = ui.theme.icons

local SCREEN_BORDER = 4

local MAX_RADAR_SIZE = 1000000000
local MIN_RADAR_SIZE = 1000
local DEFAULT_RADAR_SIZE = 10000

local shouldDisplay2DRadar = false
local blobSize = 6.0

local keys = {
	radar_toggle_mode = Input.GetActionBinding('BindRadarToggleMode'),
	radar_reset = Input.GetActionBinding('BindRadarZoomReset'),
	-- TODO: Convert to Axis?
	radar_zoom_in = Input.GetActionBinding('BindRadarZoomIn'),
	radar_zoom_out = Input.GetActionBinding('BindRadarZoomOut'),
}

local function getColorFor(item)
	local body = item.body
	if body == player:GetNavTarget() then
		return colors.radarNavTarget
	elseif body == player:GetCombatTarget() then
		return colors.radarCombatTarget
	elseif body:IsShip() then
		return colors.radarShip
	elseif body:IsHyperspaceCloud() then
		return colors.radarCloud
	elseif body:IsMissile() then
		return colors.radarMissile
	elseif body:IsStation() then
		return colors.radarStation
	elseif body:IsCargoContainer() then
		return colors.radarCargo
	end
	return colors.radarUnknown
end

local radar2d = {
	zoom = DEFAULT_RADAR_SIZE,
	size = ui.reticuleCircleRadius * 0.66,
	getRadius = function(self) return self.size end,
	zoomIn = function(self)
		self.zoom = math.max(self.zoom / 10, MIN_RADAR_SIZE)
	end,
	zoomOut = function(self)
		self.zoom = math.min(self.zoom * 10, MAX_RADAR_SIZE)
	end,
	resetZoom = function(self)
		self.zoom = DEFAULT_RADAR_SIZE
	end,
	getZoom = function(self) return self.zoom end,
	isAutoZoom = function(self) return false end,
}

local radar = require 'PiGui.Modules.RadarWidget'()
radar.minZoom = MIN_RADAR_SIZE
radar.maxZoom = MAX_RADAR_SIZE
radar.zoom = DEFAULT_RADAR_SIZE
local radar3d = {
	auto_zoom = true,
	size = Vector2(ui.reticuleCircleRadius * 1.8, ui.reticuleCircleRadius * 1.4),
	getRadius = function(self) return self.size.x end,
	zoomIn = function(self)
		if self.auto_zoom then
			radar.zoom = 10 ^ math.floor(math.log(radar.zoom, 10))
		else
			radar.zoom = math.max(radar.zoom / 10, MIN_RADAR_SIZE)
		end
		self.auto_zoom = false
	end,
	zoomOut = function(self)
		if self.auto_zoom then
			radar.zoom = 10 ^ math.ceil(math.log(radar.zoom, 10))
		else
			radar.zoom = math.min(radar.zoom * 10, MAX_RADAR_SIZE)
		end
		self.auto_zoom = false
	end,
	resetZoom = function(self)
		radar.zoom = DEFAULT_RADAR_SIZE
		self.auto_zoom = true
	end,
	getZoom = function(self) return radar.zoom end,
	isAutoZoom = function(self) return self.auto_zoom end,
}

-- display the 2D radar
radar2d.draw = function(self, center)
	local targets = ui.getTargetsNearby(self.zoom)
	local halfsize = self.size * 0.5
	local thirdsize = self.size * 0.3
	local twothirdsize = self.size * 0.7
	local fgColor = colors.uiPrimary
	local bgColor = colors.uiBackground:opacity(0.54)
	local lineThickness = 1.5

	local function line(x,y)
		-- ui.addLine(center + Vector2(x, y) * halfsize, center + Vector2(x,y) * size, colors.uiPrimaryDark, lineThickness)
		ui.addLine(center + Vector2(x, y) * thirdsize, center + Vector2(x,y) * twothirdsize, fgColor, lineThickness)
	end

	-- radar background and border
	ui.addCircleFilled(center, self.size, bgColor, ui.circleSegments(self.size), 1)
	ui.addCircle(center, self.size, fgColor, ui.circleSegments(self.size), lineThickness * 2)

	-- inner circles
	--	ui.addCircle(center, halfsize, fgColor, ui.circleSegments(halfsize), lineThickness)
	ui.addCircle(center, thirdsize, fgColor, ui.circleSegments(thirdsize), lineThickness)
	ui.addCircle(center, twothirdsize, fgColor, ui.circleSegments(twothirdsize), lineThickness)
	local l = ui.oneOverSqrtTwo
	-- cross-lines
	line(-l, l)
	line(-l, -l)
	line(l, -l)
	line(l, l)

	-- Draw target markers
	local combatTarget = player:GetCombatTarget()
	local navTarget = player:GetNavTarget()
	local tooltip = {}
	for k,v in pairs(targets) do
		if v.distance < self.zoom then
			local halfRadarSize = self.zoom / 2
			local alpha = 255
			if v.distance > halfRadarSize then
				alpha = 255 * (1 - (v.distance - halfRadarSize) / halfRadarSize)
			end
			local position = center + v.aep * self.size * 2
			if v.body == navTarget then
				local color = Color(colors.navTarget.r, colors.navTarget.g, colors.navTarget.b, alpha)
				ui.addIcon(position, icons.square, color, Vector2(12, 12), ui.anchor.center, ui.anchor.center)
			elseif v.body == combatTarget then
				local color = Color(colors.combatTarget.r, colors.combatTarget.g, colors.combatTarget.b, alpha)
				ui.addIcon(position, icons.square, color, Vector2(12, 12), ui.anchor.center, ui.anchor.center)
			else
				local color = getColorFor(v)
				ui.addCircleFilled(position, 2, color, 4, 1)
			end
			local mouse_position = ui.getMousePos()
			if (mouse_position - position):length() < 4 then
				table.insert(tooltip, v.label)
			end
		end
	end
	if #tooltip > 0 then
		ui.setTooltip(table.concat(tooltip, "\n"))
	end
end

-- Return tooltip for target
local function drawTarget(target, scale, center, color)
	local pos = target.rel_position
	local basePos = Vector2(pos.x * scale.x + center.x, pos.z * scale.y + center.y)
	local blobPos = Vector2(basePos.x, basePos.y - pos.y * scale.y);
	local blobHalfSize = Vector2(blobSize / 2)
	local tooltip = {}

	ui.addLine(basePos, blobPos, color:shade(0.1), 2)
	ui.addRectFilled(blobPos - blobHalfSize, blobPos + blobHalfSize, color, 0, 0)
	local mouse_position = ui.getMousePos()
	if (mouse_position - blobPos):length() < 4 then
		table.insert(tooltip, target.label)
	end
	return tooltip
end

radar3d.draw = function(self, center)
	local targets = ui.getTargetsNearby(MAX_RADAR_SIZE)
	local tooltip = {}

	local combatTarget = player:GetCombatTarget()
	local navTarget = player:GetNavTarget()
	local maxBodyDist = 0.0
	local maxShipDist = 0.0
	local maxCargoDist = 0.0

	radar.size = self.size
	radar.zoom = radar.zoom or DEFAULT_RADAR_SIZE
	local scale = radar.radius / radar.zoom
	ui.setCursorPos(center - self.size / 2.0)

	-- draw targets below the plane
	for k, v in pairs(targets) do
		-- collect some values for zoom updates later
		maxBodyDist = math.max(maxBodyDist, v.distance)
		-- only snap to ships if they're less than 50km away (arbitrary constant based on crime range)
		if v.body:IsShip() and v.distance < 50000 then
			maxShipDist = math.max(maxShipDist, v.distance)
		end

		-- only snap to cargo containers if they're less than 25km away (arbitrary)
		if v.body:IsCargoContainer() and v.distance < 25000 then
			maxCargoDist = math.max(maxCargoDist, v.distance)
		end

		if v.distance < radar.zoom and v.rel_position.y < 0.0 then
			local color = (v.body == navTarget and colors.navTarget) or
			              (v.body == combatTarget and colors.combatTarget) or
						  getColorFor(v)
			table.append(tooltip, drawTarget(v, scale, center, color))
		end
	end

	-- draw the radar plane itself
	ui.withStyleColors({
		FrameBg = colors.radarBackground,
		FrameBgActive = colors.radarFrame,
	}, function()
		radar:Draw()
	end)

	-- draw targets above the plane
	for k, v in pairs(targets) do
		if v.distance < radar.zoom and v.rel_position.y >= 0.0 then
			local color = (v.body == navTarget and colors.navTarget) or
			              (v.body == combatTarget and colors.combatTarget) or
						  getColorFor(v)
			table.append(tooltip, drawTarget(v, scale, center, color))
		end
	end

	-- return tooltip if mouse is over a target
	if #tooltip > 0 then
		ui.setTooltip(table.concat(tooltip, "\n"))
	end

	-- handle automatic radar zoom based on player surroundings
	if self.auto_zoom then
		local maxDist = maxBodyDist
		if combatTarget then
			maxDist = combatTarget:GetPositionRelTo(player):length() * 1.4
		elseif maxShipDist > 0 then
			maxDist = maxShipDist * 1.4
		elseif maxCargoDist > 0 then
			maxDist = maxCargoDist * 1.4
		elseif navTarget then
			local dist = navTarget:GetPositionRelTo(player):length()
			maxDist = dist > MAX_RADAR_SIZE and maxBodyDist or dist * 1.4
		end
		radar.zoom = math.clamp(radar.zoom + (maxDist - radar.zoom) * 0.03, MIN_RADAR_SIZE, MAX_RADAR_SIZE)
	end
end

-- This variable needs to be outside the function in order to capture state
-- between frames. We are trying to ensure that a mouse right-click started and
-- finished inside the radar area in order to trigger the popup.
local click_on_radar = false

-- display either the 3D or the 2D radar, show a popup on right click to select
local function displayRadar()
	if ui.optionsWindow.isOpen or Game.CurrentView() ~= "world" then return end
	player = Game.player

	-- only display if there actually *is* a radar installed
	local equipped_radar = player:GetComponent("EquipSet"):GetInstalledOfType("sensor.radar")
	-- TODO: get ship radar capability and determine functionality based on level of radar installed
	if #equipped_radar  == 0 then return end

	local instrument = shouldDisplay2DRadar and radar2d or radar3d
	local center = Vector2(ui.screenWidth / 2, ui.screenHeight - radar2d.size - SCREEN_BORDER)
	local zoom = 0
	local toggle_radar = false

	-- Handle keyboard
	-- TODO: Convert to axis?
	if keys.radar_zoom_in:IsJustActive() then
		zoom = 1
	elseif keys.radar_zoom_out:IsJustActive() then
		zoom = -1
	end
	if keys.radar_reset:IsJustActive() then
		zoom = 0
		instrument:resetZoom()
	end
	if keys.radar_toggle_mode:IsJustActive() then
		toggle_radar = true
	end

	-- Handle mouse if it is in the radar area
	local mp = ui.getMousePos()
	if (mp - center):length() < radar2d.getRadius(radar2d) then
		ui.popup("radarselector", function()
			if ui.selectable(lui.HUD_2D_RADAR, shouldDisplay2DRadar, {}) then
				toggle_radar = true
			end
			if ui.selectable(lui.HUD_3D_RADAR, not shouldDisplay2DRadar, {}) then
				toggle_radar = true
			end
		end)

		if ui.isMouseClicked(1) then
			click_on_radar = true
		end
		if not toggle_radar and click_on_radar and ui.isMouseReleased(1) then
			ui.openPopup("radarselector")
		end
		-- TODO: figure out how to "capture" the mouse wheel to prevent
		-- the game engine from using it to also zoom the viewport
		if zoom == 0 then
			zoom = ui.getMouseWheel()
		end
	end

	-- Update the zoom level
	if zoom > 0 then
		instrument:zoomIn()
	elseif zoom < 0 then
		instrument:zoomOut()
	end

	-- Draw the actual radar
	instrument:draw(center)

	-- Draw the radar buttons and info - this needs to be in a window, otherwise the buttons don't work.
	local window_width = ui.reticuleCircleRadius * 1.8
	local window_height = radar2d.size / 3.5
	local pos = Vector2(center.x - window_width / 2, center.y + radar2d.size - window_height - ui.getWindowPadding().y - SCREEN_BORDER)
	-- ui.setCursorPos(pos)
	ui.setNextWindowPos(pos, "Always")
	-- ui.setNextWindowSize(Vector2(window_width, window_height), "Always")
	local windowFlags = ui.WindowFlags {"NoTitleBar", "NoResize", "NoFocusOnAppearing", "NoBringToFrontOnFocus", "NoSavedSettings", "AlwaysAutoResize"}
	ui.window("radar_buttons", windowFlags, function()
		-- Draw mode-toggle button
		local icon = shouldDisplay2DRadar and icons.radar_3d or icons.radar_2d
		local clicked = ui.mainMenuButton(icon, "Toggle scanner mode", false, Vector2(window_height))
		if toggle_radar or clicked then
			shouldDisplay2DRadar = not shouldDisplay2DRadar
		end

		-- Draw zoom mode indicator
		if not shouldDisplay2DRadar then
			-- local mode = manual_zoom and '[M]' or '[A]'
			local radar_mode = instrument:isAutoZoom() and ' A ' or ' M '
			local button_size = window_height / 1.5
			ui.sameLine()
			ui.setCursorScreenPos(Vector2(ui.getCursorScreenPos().x, ui.getCursorScreenPos().y + window_height - button_size))
			-- local pos2 = Vector2(ui.getCursorScreenPos().x, ui.getCursorScreenPos().y + window_height - button_size)
			-- ui.setCursorPos(Vector2(ui.getCursorPos().x, center.y + size - button_size - SCREEN_BORDER))
			-- ui.setCursorPos(Vector2(center.x, center.y - radar2d:getRadius()))
			-- ui.button(radar_mode, Vector2(button_size), false, "Zoom Mode")
			icon = instrument:isAutoZoom() and icons.radar_automatic or icons.radar_manual
			-- icon = instrument:isAutoZoom() and icons.retrograde or icons.normal
			ui.mainMenuButton(icon, "Radar Zoom Mode", false, Vector2(button_size))
			--  ui.button(radar_mode, Vector2(button_size), false, "Zoom Mode")
			-- ui.addStyledText(pos2, ui.anchor.left, ui.anchor.bottom, radar_mode, colors.frame, ui.fonts.orbiteer.small, "Zoom Mode", colors.lightBlackBackground)
		end

		-- Draw current radar range
		-- ui.sameLine(center.x + window_width / 2)
		-- local pos3= Vector2(pos.x + window_width / 2, pos.y + window_height - SCREEN_BORDER)
		-- local distance = ui.Format.Distance(instrument:getZoom())
		-- local textpos = Vector2(center.x + ui.reticuleCircleRadius * 0.9, center.y + window_height - SCREEN_BORDER - 2)
		-- ui.addStyledText(textpos, ui.anchor.right, ui.anchor.bottom, distance, colors.frame, pionillium.small, lui.HUD_RADAR_DISTANCE, colors.lightBlackBackground)
	end) -- window

	-- -- Draw the range indicator - base the offsets and sizes on the 2D radar
	local size = radar2d:getRadius()
	local distance = ui.Format.Distance(instrument:getZoom())
	local textpos = Vector2(center.x + ui.reticuleCircleRadius * 0.9, center.y + size - SCREEN_BORDER - 2)
	local textsize = ui.addStyledText(textpos, ui.anchor.right, ui.anchor.bottom, distance, colors.frame, pionillium.small, lui.HUD_RADAR_DISTANCE, colors.lightBlackBackground)
	-- -- Draw the radar mode button in bottom-left corner
	-- -- Button currently does not react to mouse click nor shows tooltip on hover - WHY??
	-- local button_size = size / 3.5 -- 25
	-- ui.setCursorPos(Vector2(center.x - ui.reticuleCircleRadius * 0.9, center.y + size - button_size - SCREEN_BORDER))
	-- local icon = shouldDisplay2DRadar and icons.radar_3d or icons.radar_2d
	-- -- local icon = icons.random
	-- -- local icon = shouldDisplay2DRadar and icons.body_semi_major_axis or icons.inclination
	-- local clicked = ui.mainMenuButton(icon, "Toggle scanner mode", false, Vector2(button_size))
	-- if toggle_radar or clicked then
	-- 	shouldDisplay2DRadar = not shouldDisplay2DRadar
	-- end
	-- -- Draw zoom mode indicator
	-- if not shouldDisplay2DRadar then
	-- 	-- local mode = manual_zoom and '[M]' or '[A]'
	-- 	local radar_mode = instrument:isAutoZoom() and ' A ' or ' M '
	-- 	-- button_size = button_size / 1.5
	-- 	ui.sameLine()
		-- pos = Vector2(ui.getCursorPos().x, center.y + window_height - SCREEN_BORDER - 2) -- 2: styled text background border
	-- 	-- ui.setCursorPos(Vector2(ui.getCursorPos().x, center.y + size - button_size - SCREEN_BORDER))
	-- 	-- ui.button(mode, Vector2(button_size), false, "Zoom Mode")
		-- ui.addStyledText(pos, ui.anchor.left, ui.anchor.bottom, radar_mode, colors.frame, ui.fonts.orbiteer.small, "Zoom Mode", colors.lightBlackBackground)
	-- end
end

-- reset radar to default at game end
Event.Register("onGameEnd", function()
	shouldDisplay2DRadar = false,
	radar2d:resetZoom(),
	radar3d:resetZoom()
end)

-- save/load preference
require 'Serializer':Register("PiguiRadar",
	function () return { shouldDisplay2DRadar = shouldDisplay2DRadar } end,
	function (data) shouldDisplay2DRadar = data.shouldDisplay2DRadar end)

ui.registerModule("game", {
	id = "game-view-radar-module",
	draw = displayRadar,
	debugReload = function()
		package.reimport()
	end
})

return {}
