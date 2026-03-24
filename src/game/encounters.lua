local EncounterData = require("src.data.encounters")
local LoreData = require("src.data.lore")
local World = require("src.world.world")

local Encounters = {}

local ghost_dialogues = {
	{ name = "The Lamplighter", lines = { "I carried fire for three days.", "On the fourth, the fire carried me.", "Do not let them take your flame." } },
	{ name = "Warden Kael", lines = { "The sentries were my brothers.", "We watched the pit until it watched us back.", "Turn away before you hear the singing." } },
	{ name = "The Unnamed", lines = { "Names dissolve here.", "I had one once. It tasted like copper.", "You will forget yours too, eventually." } },
}

local riddle_pool = {
	{ clue = "Face where shadows are longest.", answer = "west", reward = "torch" },
	{ clue = "Look toward the ceiling's weep.", answer = "north", reward = "light" },
	{ clue = "Turn to the corridor that exhales.", answer = "east", reward = "flare" },
}

function Encounters.build_pool(floor, has_threat)
	local pool = {}
	for _, enc in ipairs(EncounterData) do
		if floor >= enc.min_floor then
			if has_threat or enc.kind ~= "combat" then
				for _ = 1, enc.weight do
					pool[#pool + 1] = enc.id
				end
			end
		end
	end
	return pool
end

function Encounters.pick(rng, floor, has_threat)
	if not has_threat then
		local safe = { "torch-cache", "shrine", "revelation", "lore", "riddle", "gamble_shrine" }
		return rng:choice(safe)
	end
	local pool = Encounters.build_pool(floor, true)
	if #pool == 0 then return "lore" end
	return rng:choice(pool)
end

function Encounters.apply(run, node, kind)
	local handlers = Encounters.handlers
	local handler = handlers[kind]
	if handler then
		handler(run, node)
	end
end

Encounters.handlers = {}

Encounters.handlers["lore"] = function(run, _node)
	local lore = LoreData.fragments
	run.director.lore_index = run.director.lore_index + 1
	local entry = lore[((run.director.lore_index - 1) % #lore) + 1]
	run:push_message("Lore " .. run.director.lore_index .. ": " .. entry.text)
	if run.codex then run.codex:discover_fragment(entry.id) end
	if run.mutators.echoes then run.player.flares = run.player.flares + 1 end
end

Encounters.handlers["torch-cache"] = function(run, _node)
	run.player.inventory_torches = run.player.inventory_torches + 1
	run.player.collected_torches = run.player.collected_torches + 1
	run.stats.torches_collected = run.stats.torches_collected + 1
	run:push_message("A hidden cache gifts you another torch.")
end

Encounters.handlers["shrine"] = function(run, _node)
	run.player.health = math.min(run.player.max_health, run.player.health + 2)
	run.player.light_charge = run.player.max_light_charge
	run:push_message("A shrine quiets the panic in your chest.")
end

Encounters.handlers["revelation"] = function(run, _node)
	run:reveal_path_to_objective()
end

Encounters.handlers["ambush"] = function(run, node)
	run:spawn_enemy("stalker", node.cell)
	run:spawn_enemy("leech", node.cell)
	run:push_message("[scratch] shapes peel out of the wall.")
	run.director.threat_remaining = run.director.threat_remaining - 1
end

Encounters.handlers["blackout"] = function(run, node)
	run.blackout_time = math.max(run.blackout_time, 5.0)
	run:spawn_enemy("sentry", node.cell)
	run:push_message("[hush] the room gutters into a deeper black.")
	run.director.threat_remaining = run.director.threat_remaining - 1
end

Encounters.handlers["trap"] = function(run, node)
	local origin_x, origin_y = node.cell.x, node.cell.y
	for dy = -1, 1 do
		for dx = -1, 1 do
			if World.is_walkable(run.world, origin_x + dx, origin_y + dy) then
				run:queue_hazard({ x = origin_x + dx, y = origin_y + dy }, 0.8, 1.5, 1)
			end
		end
	end
	run:push_message("[click] the floor memorizes your shape.")
	run.director.threat_remaining = run.director.threat_remaining - 1
end

Encounters.handlers["elite"] = function(run, node)
	run:spawn_enemy("rusher", node.cell)
	run:push_message("[thud] something heavier is running at you.")
	run.director.threat_remaining = run.director.threat_remaining - 1
end

Encounters.handlers["gauntlet"] = function(run, node)
	run:spawn_enemy("stalker", node.cell)
	run:spawn_enemy("rusher", node.cell)
	run:spawn_enemy("sentry", node.cell)
	run:push_message("[chorus] the corridor answers your steps.")
	run.director.threat_remaining = run.director.threat_remaining - 1
end

Encounters.handlers["riddle"] = function(run, _node)
	local riddle = riddle_pool[run.rng:int(1, #riddle_pool)]
	run:push_message("[whisper] " .. riddle.clue)
	run:push_message("Face the answer and interact to claim your reward.")
	run.pending_riddle = { answer = riddle.answer, reward = riddle.reward }
end

Encounters.handlers["sacrifice"] = function(run, _node)
	run:push_message("[altar] Sacrifice 2 HP for full light? Interact to accept.")
	run.pending_sacrifice = { cost = 2 }
end

Encounters.handlers["gamble_shrine"] = function(run, node)
	if run.rng:chance(0.5) then
		if run.relics then
			local RelicData = require("src.data.relics")
			local pool = {}
			for _, r in ipairs(RelicData) do pool[#pool + 1] = r end
			if #pool > 0 then
				local relic = run.rng:choice(pool)
				if run.relics:add(relic) then
					run:push_message("[shimmer] the shrine yields: " .. relic.label)
				else
					run:push_message("[shimmer] the shrine yields nothing. Your hands are full.")
				end
			end
		else
			run:push_message("[shimmer] the shrine hums but yields nothing yet.")
		end
	else
		run:spawn_enemy("rusher", node.cell)
		run:push_message("[crack] the shrine shatters and something rushes out.")
		run.director.threat_remaining = run.director.threat_remaining - 1
	end
end

Encounters.handlers["ghost_npc"] = function(run, _node)
	local ghost = ghost_dialogues[run.rng:int(1, #ghost_dialogues)]
	run:push_message("[apparition] " .. ghost.name .. " speaks:")
	for _, line in ipairs(ghost.lines) do
		run:push_message("  \"" .. line .. "\"")
	end
	if run.codex then
		local lore = LoreData.fragments
		run.director.lore_index = run.director.lore_index + 1
		local entry = lore[((run.director.lore_index - 1) % #lore) + 1]
		run.codex:discover_fragment(entry.id)
	end
end

return Encounters
