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

local function format_time(seconds)
	local minutes = math.floor((seconds or 0) / 60)
	local secs = (seconds or 0) - minutes * 60
	return string.format("%02d:%05.2f", minutes, secs)
end

local function format_delta(value)
	return value and string.format("%+0.2fs", value) or "--"
end

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
	if run_state.settings.runner_ghost_visible ~= false and run_state.ghost_compare and run_state.ghost_compare.breadcrumbs then
		lg.setColor(0.42, 0.84, 1.0, 0.55)
		for _, frame in ipairs(run_state.ghost_compare.breadcrumbs) do
			local gx, gy = World.world_to_cell(frame.x, frame.y)
			lg.circle("fill", panel_x + (gx - 1) * cell_size + cell_size * 0.5 + 8, panel_y + (gy - 1) * cell_size + cell_size * 0.5 + 8, math.max(1, cell_size * 0.10))
		end
		local marker = run_state.ghost_compare.marker
		if marker and marker.floor == run_state.floor then
			local gx, gy = World.world_to_cell(marker.x, marker.y)
			lg.setColor(0.76, 0.94, 1.0, 0.95)
			lg.circle("line", panel_x + (gx - 1) * cell_size + cell_size * 0.5 + 8, panel_y + (gy - 1) * cell_size + cell_size * 0.5 + 8, math.max(2, cell_size * 0.24))
		end
	end
	local player_cell_x, player_cell_y = World.world_to_cell(run_state.player.x, run_state.player.y)
	local px = panel_x + (player_cell_x - 1) * cell_size + cell_size * 0.5 + 8
	local py = panel_y + (player_cell_y - 1) * cell_size + cell_size * 0.5 + 8
	local facing_x = math.cos(run_state.player.angle)
	local facing_y = math.sin(run_state.player.angle)
	lg.setColor(0.95, 0.95, 0.98)
	lg.circle("fill", px, py, math.max(2, cell_size * 0.24))
	lg.line(px, py, px + facing_x * 8, py + facing_y * 8)
	if run_state.player.blacklight or (run_state.relics and run_state.relics:has_effect("automap_enemies")) or (run_state.assist and run_state.assist.enemy_highlight) then
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
		run_state.fx:draw_speed_lines()
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
	if run_state.momentum and run_state.momentum:is_sliding() then
		lg.setColor(0.4, 0.95, 0.8)
		lg.print("[sliding]", 230, 12)
	elseif run_state.stealth and run_state.stealth:is_crouching() then
		lg.setColor(0.5, 0.7, 0.9)
		lg.print("[crouching]", 230, 12)
	end
	lg.setColor(0.92, 0.94, 0.97)
	lg.print("Time " .. format_time(run_state.clock or 0), 230, 12)
	if run_state.mode == "time_attack" then
		lg.setColor(0.95, 0.8, 0.28)
		lg.print(string.format("Pressure Lvl %d", run_state.time_attack_level or 0), 230, 34)
	elseif run_state.mode == "daily" and run_state.daily_label then
		lg.setColor(0.66, 0.82, 0.96)
		lg.print("Daily " .. run_state.daily_label, 230, 34)
	elseif run_state.mode == "sprint" then
		lg.setColor(0.94, 0.88, 0.42)
		lg.print(string.format("Sprint %s", run_state.sprint_ruleset == "practice" and "Practice" or "Official"), 230, 34)
		local stack = run_state.get_split_stack and run_state:get_split_stack() or nil
		if run_state.settings.runner_show_split_delta ~= false and stack then
			local delta = run_state.last_split_delta
			if delta then
				lg.setColor(delta <= 0 and 0.42 or 0.95, delta <= 0 and 0.95 or 0.42, 0.42)
			else
				lg.setColor(0.82, 0.84, 0.88)
			end
			lg.print(string.format("Prev %s  %s", stack.last and stack.last.label or "Start", format_delta(delta)), 230, 54)
			lg.setColor(0.82, 0.84, 0.88)
			lg.print(string.format("Live Segment %s", format_time(stack.current_segment_time or 0)), 230, 74)
			if stack.last_segment_time and stack.last_segment_best then
				lg.print(string.format("Last Seg %s / %s", format_time(stack.last_segment_time), format_time(stack.last_segment_best)), 230, 94)
			else
				lg.print("Last Seg --", 230, 94)
			end
			lg.print(string.format("Next %s", stack.next and stack.next.label or "Finish"), 230, 114)
			if stack.projected_finish then
				lg.print(string.format("Proj %s  %s", format_time(stack.projected_finish), format_delta(stack.projected_delta)), 230, 134)
			end
			if stack.best_possible_time then
				lg.print("Sum of Best " .. format_time(stack.best_possible_time), 230, 154)
			end
		end
		if run_state.settings.runner_show_medal_pace ~= false then
			local pace = run_state:get_medal_pace()
			if pace then
				lg.setColor(0.7, 0.86, 1.0)
				lg.print(string.format("Gold Pace %s %+0.2fs", pace.medal, pace.delta or 0), 230, 174)
			end
		end
		if run_state.pack_version_mismatch or run_state.mixed_split_versions then
			lg.setColor(0.72, 0.9, 1.0)
			local warning = run_state.pack_version_mismatch and string.format("Legacy PB %s", run_state.pb_pack_version or "?") or "Mixed split versions"
			if run_state.pack_version_mismatch and run_state.mixed_split_versions then
				warning = warning .. "  Mixed splits"
			end
			lg.print(warning, 230, 194)
		end
		local cue = run_state.get_ghost_cue and run_state:get_ghost_cue() or nil
		if cue and run_state.settings.runner_ghost_visible ~= false then
			lg.setColor(0.72, 0.9, 1.0)
			local heading = math.deg(cue.angle_delta or 0)
			local direction = math.abs(heading) < 18 and "ahead"
				or (heading < 0 and "left" or "right")
			lg.print(string.format("Ghost %.1fm  %s %.0f deg", cue.distance or 0, direction, math.abs(heading)), 230, (run_state.pack_version_mismatch or run_state.mixed_split_versions) and 214 or 194)
		end
		local route = run_state.get_route_indicator and run_state:get_route_indicator() or nil
		if route then
			lg.setColor(0.8, 0.96, 0.76)
			local route_y = 214
			if run_state.pack_version_mismatch or run_state.mixed_split_versions then
				route_y = route_y + 20
			end
			if cue and run_state.settings.runner_ghost_visible ~= false then
				route_y = route_y + 20
			end
			lg.print(string.format("Route %s  %.1fm  %+.0f deg", route.label or route.type or "target", route.distance or 0, math.deg(route.angle_delta or 0)), 230, route_y)
		end
		local tech_y = 214
		if run_state.pack_version_mismatch or run_state.mixed_split_versions then
			tech_y = tech_y + 20
		end
		if cue and run_state.settings.runner_ghost_visible ~= false then
			tech_y = tech_y + 20
		end
		if route then
			tech_y = tech_y + 20
		end
		lg.setColor(0.96, 0.82, 0.46)
		local dash_ready = run_state.player.burst_charge >= 0.55 and run_state.player.dash_cooldown <= 0 and run_state.player.light_charge >= 12
		local dash_text = run_state.player.dash_feedback_time > 0 and "Burn Dash landed"
			or (dash_ready and "Burn Dash armed" or string.format("Burn cooldown %.2f", run_state.player.dash_cooldown or 0))
		lg.print(dash_text, 230, tech_y)
		local flare_hot = false
		for _, flare in ipairs(run_state.flares or {}) do
			if flare.boosted ~= true and (flare.boost_window or 0) > 0 then
				flare_hot = true
				break
			end
		end
		lg.setColor(1.0, 0.84, 0.42)
		local flare_text = run_state.player.flare_feedback_time > 0 and "Flare line caught"
			or (run_state.player.flare_line_window > 0 and string.format("Flare window %.2fs", run_state.player.flare_line_window))
			or (flare_hot and "Flare line primed" or "Flare line idle")
		lg.print(flare_text, 230, tech_y + 20)
	else
		lg.setColor(0.82, 0.84, 0.88)
		lg.print("Descent timer active", 230, 34)
	end
	lg.print(run_state.objective_text or "", 16, height - 86)
	if run_state.assist_active then
		lg.setColor(0.72, 0.5, 0.95)
		lg.print("[ASSIST]", 16, height - 106)
	end
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
	self:draw_velocity(run_state, lg)
	self:draw_style_meter(run_state, lg)
	self:draw_input_display(run_state, lg)
	self:draw_automap(run_state, lg)
	if run_state.bonfire_screen then
		self:draw_bonfire(run_state, lg)
	end
end

function HUD:draw_bonfire(run_state, lg)
	local width, height = lg.getDimensions()
	local bf = run_state.bonfire_screen
	local alpha = math.min(1.0, bf.timer * 2)
	lg.setColor(0, 0, 0, 0.65 * alpha)
	lg.rectangle("fill", 0, 0, width, height)
	lg.setColor(1.0, 0.75, 0.2, alpha)
	lg.printf("BONFIRE REST", 0, height * 0.3, width, "center")
	lg.setColor(0.9, 0.85, 0.7, alpha * 0.9)
	if bf.restored_hp > 0 then
		lg.printf(string.format("HP restored +%d    Sanity restored +%d    Light fully recharged", bf.restored_hp, bf.restored_sanity), 0, height * 0.45, width, "center")
	else
		lg.printf("The bonfire still burns. Its warmth lingers.", 0, height * 0.45, width, "center")
	end
	lg.setColor(0.95, 0.6, 0.15, alpha * (0.5 + 0.5 * math.sin(love.timer.getTime() * 4)))
	local flame_y = height * 0.55
	for i = 1, 5 do
		local fx = width * 0.5 + (i - 3) * 18
		local fh = 12 + math.sin(love.timer.getTime() * 6 + i) * 6
		lg.rectangle("fill", fx - 4, flame_y - fh, 8, fh)
	end
end

function HUD:draw_velocity(run_state, lg)
	if not run_state.momentum then return end
	if run_state.settings and run_state.settings.runner_show_velocity == false then return end
	local width, height = lg.getDimensions()
	local speed = run_state.momentum:get_speed()
	local r, g, b = 0.92, 0.94, 0.97
	if speed >= 8 then r, g, b = 0.95, 0.3, 0.25
	elseif speed >= 5 then r, g, b = 0.95, 0.6, 0.2
	elseif speed >= 3 then r, g, b = 0.95, 0.9, 0.3 end
	lg.setColor(r, g, b)
	lg.print(string.format("%.1f u/s", speed), width - 140, 12)
	if not (run_state.settings and run_state.settings.runner_show_technique_state == false) then
		local tech = run_state.momentum:get_technique()
		if tech ~= "none" then
			lg.setColor(0.4, 0.95, 0.8)
			lg.print(tech, width - 140, 30)
		end
	end
end

function HUD:draw_style_meter(run_state, lg)
	if not run_state.style then return end
	if run_state.settings and run_state.settings.runner_show_style == false then return end
	local width = lg.getDimensions()
	local rank = run_state.style:get_rank()
	local score = run_state.style:get_score()
	local flash = run_state.style:get_flash()
	local colors = { D = {0.5,0.5,0.5}, C = {0.6,0.8,0.6}, B = {0.4,0.9,0.9}, A = {0.9,0.8,0.3}, S = {1.0,0.6,0.2}, SS = {1.0,0.3,0.3} }
	local color = colors[rank] or colors.D
	local alpha = 0.9 + flash * 0.4
	lg.setColor(color[1], color[2], color[3], alpha)
	lg.print(rank, width - 80, 50)
	lg.setColor(0.15, 0.15, 0.18, 0.6)
	lg.rectangle("fill", width - 140, 70, 80, 6)
	lg.setColor(color[1], color[2], color[3], 0.8)
	lg.rectangle("fill", width - 140, 70, 80 * (score / 100), 6)
end

function HUD:draw_input_display(run_state, lg)
	if not run_state.keys then return end
	if run_state.settings and run_state.settings.runner_input_display == false then return end
	local width, height = lg.getDimensions()
	local base_x = width - 120
	local base_y = height - 80
	local size = 18
	local gap = 2
	local keys_layout = {
		{ key = "w", label = "W", col = 1, row = 0 },
		{ key = "a", label = "A", col = 0, row = 1 },
		{ key = "s", label = "S", col = 1, row = 1 },
		{ key = "d", label = "D", col = 2, row = 1 },
		{ key = "q", label = "Q", col = 0, row = 0 },
		{ key = "c", label = "C", col = 2, row = 0 },
		{ key = "space", label = "SP", col = 3.5, row = 1 },
		{ key = "lshift", label = "SH", col = 3.5, row = 0 },
		{ key = "lctrl", label = "CT", col = 5, row = 1 },
		{ key = "f", label = "F", col = 5, row = 0 },
		{ key = "g", label = "G", col = 6, row = 0 },
	}
	for _, k in ipairs(keys_layout) do
		local x = base_x + k.col * (size + gap)
		local y = base_y + k.row * (size + gap)
		local active = run_state.keys[k.key]
		if active then
			lg.setColor(0.4, 0.95, 0.8, 0.85)
			lg.rectangle("fill", x, y, size, size)
			lg.setColor(0, 0, 0)
		else
			lg.setColor(0.3, 0.32, 0.35, 0.5)
			lg.rectangle("fill", x, y, size, size)
			lg.setColor(0.6, 0.62, 0.65)
		end
		lg.print(k.label, x + 2, y + 2)
	end
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
				string.format("Burn dashes: %d", stats.burn_dashes or 0),
				string.format("Flare boosts: %d", stats.flare_boosts or 0),
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
			local toggles = {
				"screen_shake",
				"flash_on_kill",
				"pulse_light",
				"death_animations",
				"footstep_bob",
				"title_flicker",
				"runner_ghost_visible",
				"runner_auto_save_pb_replay",
				"runner_restart_confirmation",
				"runner_practice_auto_restart",
				"runner_show_medal_pace",
				"runner_show_split_delta",
				"runner_show_velocity",
				"runner_show_technique_state",
				"runner_input_display",
				"runner_show_ghost_3d",
			}
			for i, key in ipairs(toggles) do
				local val = self.settings[key]
				lg.print(string.format("[%s] %s: %s", string.char(96 + i), key, val and "ON" or "OFF"), width * 0.3, content_y)
				content_y = content_y + 22
			end
		end
		lg.setColor(0.5, 0.5, 0.55)
		lg.printf("[Esc] Resume  [R] Restart  [1-4] Tab  [V] Save Replay", 0, height * 0.88, width, "center")
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
	elseif key == "g" then self:toggle_setting("runner_ghost_visible")
	elseif key == "h" then self:toggle_setting("runner_auto_save_pb_replay")
	elseif key == "i" then self:toggle_setting("runner_restart_confirmation")
	elseif key == "j" then self:toggle_setting("runner_practice_auto_restart")
	elseif key == "k" then self:toggle_setting("runner_show_medal_pace")
	elseif key == "l" then self:toggle_setting("runner_show_split_delta")
	elseif key == "m" then self:toggle_setting("runner_show_velocity")
	elseif key == "n" then self:toggle_setting("runner_show_technique_state")
	elseif key == "o" then self:toggle_setting("runner_input_display")
	elseif key == "p" then self:toggle_setting("runner_show_ghost_3d")
	end
end

function HUD:draw_results(run_state, lg)
	local width, height = lg.getDimensions()
	lg.setColor(0, 0, 0, 0.85)
	lg.rectangle("fill", 0, 0, width, height)
	local outcome = run_state.player.health <= 0 and "DEFEATED" or "VICTORY"
	lg.setColor(run_state.player.health <= 0 and {0.95, 0.3, 0.25} or {0.95, 0.85, 0.35})
	lg.printf(outcome, 0, height * 0.06, width, "center")
	lg.setColor(0.82, 0.84, 0.88)
	local y = height * 0.14
	lg.printf(string.format("Time: %s    Floor: %d/%d    Difficulty: %s",
		format_time(run_state.clock), run_state.floor, run_state.total_floors, run_state.difficulty_label), 0, y, width, "center")
	y = y + 30
	if run_state.splits and #run_state.splits > 0 then -- splits breakdown
		lg.setColor(0.72, 0.76, 0.82)
		lg.printf("-- SPLITS --", 0, y, width, "center")
		y = y + 22
		for _, split in ipairs(run_state.splits) do
			local delta_str = split.delta and string.format("  %+.2fs", split.delta) or ""
			local gold_mark = split.gold and " *" or ""
			local color = (split.delta and split.delta <= 0) and {0.42, 0.95, 0.42} or {0.95, 0.42, 0.42}
			if not split.delta then color = {0.72, 0.76, 0.82} end
			lg.setColor(color)
			lg.printf(string.format("%-20s  %s%s%s", split.label, format_time(split.time), delta_str, gold_mark), width * 0.2, y, width * 0.6, "left")
			y = y + 18
		end
		y = y + 10
	end
	lg.setColor(0.72, 0.76, 0.82) -- stats
	lg.printf("-- STATS --", 0, y, width, "center")
	y = y + 22
	local stats = run_state.stats or {}
	local lines = {
		string.format("Enemies burned: %d", stats.enemies_burned or 0),
		string.format("Damage taken: %d", stats.damage_taken or 0),
		string.format("Torches: %d    Flares: %d    Burn dashes: %d", stats.torches_collected or 0, stats.flares_used or 0, stats.burn_dashes or 0),
		string.format("Secrets: %d    Encounters: %d", stats.secrets_revealed or 0, stats.encounters_triggered or 0),
	}
	lg.setColor(0.82, 0.84, 0.88)
	for _, line in ipairs(lines) do
		lg.printf(line, 0, y, width, "center")
		y = y + 18
	end
	if run_state.momentum then -- momentum stats
		y = y + 10
		lg.setColor(0.72, 0.76, 0.82)
		lg.printf("-- MOVEMENT --", 0, y, width, "center")
		y = y + 22
		local ms = run_state.momentum.stats or {}
		lg.setColor(0.82, 0.84, 0.88)
		lg.printf(string.format("Slides: %d    Bhops: %d    Wall runs: %d    Chains: %d",
			ms.slides or 0, ms.bhops or 0, ms.wall_runs or 0, ms.chains or 0), 0, y, width, "center")
		y = y + 18
	end
	if run_state.style then -- style rank
		local rank = run_state.style:get_rank()
		lg.setColor(0.95, 0.85, 0.35)
		lg.printf(string.format("Style rank: %s", rank), 0, y + 10, width, "center")
	end
	lg.setColor(0.5, 0.5, 0.55) -- controls
	lg.printf("[R] Restart    [V] Save Replay    [Esc] Menu", 0, height * 0.92, width, "center")
end

function HUD:toggle_setting(key)
	if self.settings[key] ~= nil then
		self.settings[key] = not self.settings[key]
	end
end

return HUD
