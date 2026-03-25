local util = require("src.core.util")
local World = require("src.world.world")
local Consumables = require("src.data.consumables")

local HUD = {}
HUD.__index = HUD

local palette = {
	anchor = { 0.2, 0.9, 0.9, 1.0 },
	anchor_lit = { 1.0, 0.85, 0.42, 1.0 },
	exit = { 0.35, 0.75, 0.95, 1.0 },
	flare = { 1.0, 0.96, 0.55, 1.0 },
}

local flame_palette = {
	amber = { 0.92, 0.74, 0.24 },
	red = { 0.94, 0.38, 0.28 },
	blue = { 0.46, 0.72, 0.98 },
}

function HUD.new(settings)
	return setmetatable({
		settings = settings or {},
		paused = false,
		pause_tab = 1, -- 1=stats 2=bestiary 3=codex 4=settings
	}, HUD)
end

function HUD:toggle_pause()
	self.paused = not self.paused
end

function HUD:is_paused()
	return self.paused
end

function HUD:draw_bars(player, lg, flame_color)
	local bar_x = 16
	local bar_y = 100
	local bar_w = 200
	local flame = flame_palette[flame_color or "amber"] or flame_palette.amber
	lg.setColor(0.15, 0.15, 0.18)
	lg.rectangle("fill", bar_x, bar_y, bar_w, 12)
	lg.setColor(0.92, 0.25, 0.22)
	lg.rectangle("fill", bar_x, bar_y, bar_w * (player.health / player.max_health), 12)
	lg.setColor(0.15, 0.15, 0.18)
	lg.rectangle("fill", bar_x, bar_y + 18, bar_w, 12)
	lg.setColor(flame[1], flame[2], flame[3])
	lg.rectangle("fill", bar_x, bar_y + 18, bar_w * (player.light_charge / player.max_light_charge), 12)
	lg.setColor(0.15, 0.15, 0.18)
	lg.rectangle("fill", bar_x, bar_y + 36, bar_w, 10)
	lg.setColor(0.72, 0.85, 1.0)
	lg.rectangle("fill", bar_x, bar_y + 36, bar_w * (player.burst_charge / 1.5), 10)
end

function HUD:draw_sanity_bar(sanity, lg)
	if not sanity then return end
	local status = sanity:get_status()
	local bar_x = 16
	local bar_y = 152
	local bar_w = 140
	lg.setColor(0.15, 0.15, 0.18)
	lg.rectangle("fill", bar_x, bar_y, bar_w, 8)
	local color = { 0.46, 0.82, 0.95 }
	if status.tier == "strained" then
		color = { 0.95, 0.76, 0.28 }
	elseif status.tier == "broken" then
		color = { 0.95, 0.36, 0.36 }
	end
	lg.setColor(color)
	lg.rectangle("fill", bar_x, bar_y, bar_w * (status.sanity / status.max_sanity), 8)
	lg.setColor(0.5, 0.5, 0.55)
	lg.print(string.format("Sanity %.0f%%  %s", (status.sanity / status.max_sanity) * 100, status.tier), bar_x, bar_y + 16)
end

function HUD:draw_consumables(player, lg)
	local base_x = 16
	local base_y = 186
	lg.setColor(0.82, 0.84, 0.88)
	lg.print("Belt", base_x, base_y)
	for index = 1, 3 do
		local kind = player.consumables[index]
		local label = "---"
		if kind and Consumables.get(kind) then
			label = Consumables.get(kind).short_label or kind
		elseif kind then
			label = kind
		end
		lg.setColor(0.5, 0.5, 0.56)
		lg.rectangle("line", base_x + 36 + (index - 1) * 70, base_y - 2, 60, 16)
		lg.setColor(0.82, 0.84, 0.88)
		lg.print(string.format("%d:%s", index, label), base_x + 40 + (index - 1) * 70, base_y)
	end
	lg.setColor(0.55, 0.58, 0.64)
	lg.print(string.format("Wards %d", player.ward_charges or 0), base_x, base_y + 20)
end

function HUD:draw_messages(messages, lg, height)
	local message_y = height - 62
	for index = math.max(1, #messages - 2), #messages do
		local message = messages[index]
		lg.setColor(0.74, 0.78, 0.84)
		lg.print(message, 16, message_y)
		message_y = message_y + 18
	end
end

function HUD:draw_automap(run_state, lg)
	if not run_state.automap_enabled then return end
	if run_state.sanity and not run_state.sanity:can_show_automap(love.timer.getTime()) then return end
	local width = lg.getDimensions()
	local panel_size = 220
	local panel_x = width - panel_size - 16
	local panel_y = 16
	local cell_size = math.floor(panel_size / math.max(run_state.world.width, run_state.world.height))
	local automap_alpha = run_state.sanity and run_state.sanity:get_effects().automap_alpha or 0.84
	lg.setColor(0.04, 0.05, 0.06, automap_alpha)
	lg.rectangle("fill", panel_x, panel_y, panel_size, panel_size, 10, 10)
	for y = 1, run_state.world.height do
		for x = 1, run_state.world.width do
			local key = string.format("%d:%d", x, y)
			if run_state.revealed[key] then
				local cell = run_state.world.cells[y][x]
				if cell.walkable then
					local color = { 0.22, 0.28, 0.34, 0.9 }
					if run_state.guidance_cells[key] then
						color = { 0.95, 0.85, 0.42, 0.95 }
					end
					lg.setColor(color)
					lg.rectangle("fill", panel_x + (x - 1) * cell_size + 8, panel_y + (y - 1) * cell_size + 8, cell_size - 1, cell_size - 1)
				end
			end
		end
	end
	for _, anchor in ipairs(run_state.world.anchors) do
		local key = string.format("%d:%d", anchor.cell.x, anchor.cell.y)
		if run_state.revealed[key] then
			lg.setColor(anchor.lit and palette.anchor_lit or palette.anchor)
			lg.rectangle("fill", panel_x + (anchor.cell.x - 1) * cell_size + 10, panel_y + (anchor.cell.y - 1) * cell_size + 10, cell_size - 5, cell_size - 5)
		end
	end
	if run_state.world.exit then
		local key = string.format("%d:%d", run_state.world.exit.cell.x, run_state.world.exit.cell.y)
		if run_state.revealed[key] then
			lg.setColor(palette.exit)
			lg.rectangle("fill", panel_x + (run_state.world.exit.cell.x - 1) * cell_size + 10, panel_y + (run_state.world.exit.cell.y - 1) * cell_size + 10, cell_size - 5, cell_size - 5)
		end
	end
	for _, flare in ipairs(run_state.flares) do
		local fx = panel_x + (flare.cell.x - 1) * cell_size + cell_size * 0.5 + 8
		local fy = panel_y + (flare.cell.y - 1) * cell_size + cell_size * 0.5 + 8
		lg.setColor(palette.flare)
		lg.circle("fill", fx, fy, math.max(2, cell_size * 0.22))
	end
	local player_cell_x, player_cell_y = World.world_to_cell(run_state.player.x, run_state.player.y)
	local px = panel_x + (player_cell_x - 1) * cell_size + cell_size * 0.5 + 8
	local py = panel_y + (player_cell_y - 1) * cell_size + cell_size * 0.5 + 8
	local facing_x = math.cos(run_state.player.angle)
	local facing_y = math.sin(run_state.player.angle)
	lg.setColor(0.95, 0.95, 0.98)
	lg.circle("fill", px, py, math.max(2, cell_size * 0.24))
	lg.line(px, py, px + facing_x * 8, py + facing_y * 8)
	if run_state.player.blacklight or (run_state.relics and run_state.relics:has_effect("automap_enemies")) then
		for _, enemy in ipairs(run_state.world.enemies) do
			if enemy.alive ~= false then
				local ex, ey = World.world_to_cell(enemy.x, enemy.y)
				local key = string.format("%d:%d", ex, ey)
				if run_state.revealed[key] then
					lg.setColor(0.58, 0.72, 1.0, 0.8)
					lg.circle("fill", panel_x + (ex - 1) * cell_size + cell_size * 0.5 + 8, panel_y + (ey - 1) * cell_size + cell_size * 0.5 + 8, math.max(2, cell_size * 0.16))
				end
			end
		end
	end
end

function HUD:draw_overlay_fx(run_state, lg)
	local width, height = lg.getDimensions()
	if run_state.damage_flash > 0 then
		lg.setColor(0.8, 0.1, 0.1, util.clamp(run_state.damage_flash, 0, 0.35))
		lg.rectangle("fill", 0, 0, width, height)
	end
	if run_state.blackout_time > 0 then
		lg.setColor(0.0, 0.0, 0.0, util.clamp(run_state.blackout_time * 0.28, 0.1, 0.45))
		lg.rectangle("fill", 0, 0, width, height)
	end
	if run_state.sanity then
		local effects = run_state.sanity:get_effects()
		if effects.tier == "strained" then
			lg.setColor(0.28, 0.18, 0.05, 0.08)
			lg.rectangle("fill", 0, 0, width, height)
		elseif effects.tier == "broken" then
			lg.setColor(0.35, 0.05, 0.05, 0.14)
			lg.rectangle("fill", 0, 0, width, height)
		end
	end
end

function HUD:draw_crosshair(lg)
	local width, height = lg.getDimensions()
	lg.setColor(1.0, 1.0, 1.0, 0.5)
	lg.line(width * 0.5 - 6, height * 0.5, width * 0.5 + 6, height * 0.5)
	lg.line(width * 0.5, height * 0.5 - 6, width * 0.5, height * 0.5 + 6)
end

function HUD:draw(run_state, lg)
	local _, height = lg.getDimensions()
	local player = run_state.player
	self:draw_overlay_fx(run_state, lg)
	if run_state.fx then
		run_state.fx:draw_particles()
		run_state.fx:draw_low_charge_pulse(player.light_charge, player.max_light_charge)
	end
	self:draw_crosshair(lg)
	lg.setColor(0.92, 0.94, 0.97)
	lg.print(string.format("KURO  Floor %d/%d  %s  %s", run_state.floor, run_state.total_floors, run_state.difficulty_label, run_state.mode_label or "Classic"), 16, 12)
	lg.print(string.format("HP %d/%d", player.health, player.max_health), 16, 34)
	lg.print(string.format("Torches %d  Goal %d", player.inventory_torches, player.torch_goal), 16, 54)
	lg.print(string.format("Charge %d%%  Flares %d  Seed %d", math.floor(player.light_charge), player.flares, run_state.seed), 16, 74)
	if run_state.relics and run_state.relics:count() > 0 then
		local relic_names = {}
		for _, r in ipairs(run_state.relics:list()) do relic_names[#relic_names + 1] = r.label end
		lg.setColor(0.85, 0.75, 0.4)
		lg.print("Relics: " .. table.concat(relic_names, ", "), 16, 90)
	end
	if run_state.stealth and run_state.stealth:is_crouching() then
		lg.setColor(0.5, 0.7, 0.9)
		lg.print("[crouching]", 230, 12)
	end
	if run_state.mode == "time_attack" then
		local minutes = math.floor((run_state.time_attack_elapsed or 0) / 60)
		local seconds = math.floor((run_state.time_attack_elapsed or 0) % 60)
		lg.setColor(0.95, 0.8, 0.28)
		lg.print(string.format("Timer %02d:%02d  Lvl %d", minutes, seconds, run_state.time_attack_level or 0), 230, 34)
	elseif run_state.mode == "daily" and run_state.daily_label then
		lg.setColor(0.66, 0.82, 0.96)
		lg.print("Daily " .. run_state.daily_label, 230, 34)
	end
	lg.print(run_state.objective_text or "", 16, height - 86)
	self:draw_bars(player, lg, run_state.flame_color)
	self:draw_sanity_bar(run_state.sanity, lg)
	self:draw_consumables(player, lg)
	self:draw_messages(run_state.messages, lg, height)
	local objective = run_state:current_objective_cell()
	if objective then
		local width = lg.getDimensions()
		local target_x, target_y = World.cell_to_world(objective)
		local angle_to_target = math.atan(target_y - run_state.player.y, target_x - run_state.player.x)
		local delta = ((angle_to_target - run_state.player.angle + math.pi) % (math.pi * 2)) - math.pi
		lg.setColor(0.95, 0.85, 0.42)
		lg.print(string.format("Guide %.0f deg", math.deg(delta)), width - 180, height - 34)
	end
	self:draw_automap(run_state, lg)
end

function HUD:draw_pause(run_state, lg)
	local width, height = lg.getDimensions()
	lg.setColor(0, 0, 0, 0.72)
	lg.rectangle("fill", 0, 0, width, height)
	lg.setColor(0.87, 0.89, 0.95)
	lg.printf("PAUSED", 0, height * 0.12, width, "center")
	local tabs = { "Stats", "Bestiary", "Codex", "Settings" }
	local tab_y = height * 0.20
	for i, name in ipairs(tabs) do
		lg.setColor(i == self.pause_tab and 1 or 0.5, i == self.pause_tab and 1 or 0.5, i == self.pause_tab and 1 or 0.6)
		lg.printf(string.format("[%d] %s", i, name), 0, tab_y, width, "center")
		tab_y = tab_y + 22
	end
	local content_y = height * 0.38
	if self.pause_tab == 1 then -- stats
		local stats = run_state.stats
		lg.setColor(0.82, 0.84, 0.88)
		local lines = {
			string.format("Floor: %d / %d", run_state.floor, run_state.total_floors),
			string.format("Difficulty: %s", run_state.difficulty_label),
			string.format("Floors cleared: %d", stats.floors_cleared),
			string.format("Damage taken: %d", stats.damage_taken),
			string.format("Torches collected: %d", stats.torches_collected),
			string.format("Enemies burned: %d", stats.enemies_burned),
			string.format("Encounters triggered: %d", stats.encounters_triggered),
			string.format("Anchors lit: %d", stats.anchors_lit),
			string.format("Flares used: %d", stats.flares_used),
			string.format("Consumables used: %d", stats.consumables_used or 0),
			string.format("Wards triggered: %d", stats.wards_triggered or 0),
			string.format("Secrets revealed: %d", stats.secrets_revealed or 0),
		}
		for _, line in ipairs(lines) do
			lg.print(line, width * 0.3, content_y)
			content_y = content_y + 22
		end
	elseif self.pause_tab == 2 then -- bestiary
		lg.setColor(0.82, 0.84, 0.88)
		if run_state.codex then
			for kind, count in pairs(run_state.codex.bestiary or {}) do
				lg.print(string.format("%s: %d killed", kind, count), width * 0.3, content_y)
				content_y = content_y + 22
			end
		else
			lg.print("No bestiary data yet.", width * 0.3, content_y)
		end
	elseif self.pause_tab == 3 then -- codex
		lg.setColor(0.82, 0.84, 0.88)
		if run_state.codex then
			for id in pairs(run_state.codex.found_fragments or {}) do
				lg.print(string.format("Fragment #%s discovered", tostring(id)), width * 0.3, content_y)
				content_y = content_y + 22
			end
		else
			lg.print("No lore discovered yet.", width * 0.3, content_y)
		end
	elseif self.pause_tab == 4 then -- settings
		lg.setColor(0.82, 0.84, 0.88)
		local toggles = { "screen_shake", "flash_on_kill", "pulse_light", "death_animations", "footstep_bob", "title_flicker" }
		for i, key in ipairs(toggles) do
			local val = self.settings[key]
			lg.print(string.format("[%s] %s: %s", string.char(96 + i), key, val and "ON" or "OFF"), width * 0.3, content_y)
			content_y = content_y + 22
		end
	end
	lg.setColor(0.5, 0.5, 0.55)
	lg.printf("[Esc] Resume  [1-4] Tab  [V] Save Replay", 0, height * 0.88, width, "center")
end

function HUD:pause_keypressed(key)
	if key == "1" then self.pause_tab = 1
	elseif key == "2" then self.pause_tab = 2
	elseif key == "3" then self.pause_tab = 3
	elseif key == "4" then self.pause_tab = 4
	elseif key == "a" then self:toggle_setting("screen_shake")
	elseif key == "b" then self:toggle_setting("flash_on_kill")
	elseif key == "c" then self:toggle_setting("pulse_light")
	elseif key == "d" then self:toggle_setting("death_animations")
	elseif key == "e" then self:toggle_setting("footstep_bob")
	elseif key == "f" then self:toggle_setting("title_flicker")
	end
end

function HUD:toggle_setting(key)
	if self.settings[key] ~= nil then
		self.settings[key] = not self.settings[key]
	end
end

return HUD
