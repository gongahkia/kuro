local Sprites = {}

local function load_strip(path, frame_w, frame_h)
	local img = love.graphics.newImage(path)
	img:setFilter("nearest", "nearest")
	local w = img:getWidth()
	local count = math.floor(w / frame_w)
	local quads = {}
	for i = 0, count - 1 do
		quads[#quads + 1] = love.graphics.newQuad(i * frame_w, 0, frame_w, frame_h, w, frame_h)
	end
	return { image = img, quads = quads, count = count, frame_w = frame_w, frame_h = frame_h }
end

local function load_static(path)
	local img = love.graphics.newImage(path)
	img:setFilter("nearest", "nearest")
	local w, h = img:getWidth(), img:getHeight()
	local quad = love.graphics.newQuad(0, 0, w, h, w, h)
	return { image = img, quads = { quad }, count = 1, frame_w = w, frame_h = h }
end

local function make_static_set(path)
	local s = load_static(path)
	return { idle = s }
end

local function load_skeleton(color)
	local base = "assets/sprites/skeleton/Skeleton_" .. color .. "/Skeleton_Without_VFX/"
	local prefix = "Skeleton_01_" .. color .. "_"
	return {
		idle = load_strip(base .. prefix .. "Idle.png", 96, 64),
		walk = load_strip(base .. prefix .. "Walk.png", 96, 64),
		attack = load_strip(base .. prefix .. "Attack1.png", 96, 64),
		hurt = load_strip(base .. prefix .. "Hurt.png", 96, 64),
		die = load_strip(base .. prefix .. "Die.png", 96, 64),
	}
end

local function load_flying_enemy()
	local base = "assets/sprites/flying_enemy/Enemy3/Enemy3-No-Movement-In-Animation/"
	return {
		idle = load_strip(base .. "Enemy3No-Move-Idle.png", 64, 64),
		walk = load_strip(base .. "Enemy3No-Move-Fly.png", 64, 64),
		attack = load_strip(base .. "Enemy3No-Move-AttackSmashStart.png", 64, 64),
		hurt = load_strip(base .. "Enemy3No-Move-Hit.png", 64, 64),
		die = load_strip(base .. "Enemy3No-Move-Die.png", 64, 64),
	}
end

local function load_mushroom()
	local base = "assets/sprites/forest_monsters/Mushroom/Mushroom without VFX/"
	return {
		idle = load_strip(base .. "Mushroom-Idle.png", 80, 64),
		walk = load_strip(base .. "Mushroom-Run.png", 80, 64),
		attack = load_strip(base .. "Mushroom-Attack.png", 80, 64),
		hurt = load_strip(base .. "Mushroom-Hit.png", 80, 64),
		die = load_strip(base .. "Mushroom-Die.png", 80, 64),
	}
end

function Sprites.load()
	local flying = load_flying_enemy()
	local pickups_base = "assets/sprites/scifi_pickups/PickUps/Individual_PNGs/"
	return {
		-- enemies
		stalker = load_skeleton("White"),
		rusher = load_skeleton("Yellow"),
		leech = flying,
		sentry = load_mushroom(),
		umbra = flying,
		-- pickups
		torch = make_static_set(pickups_base .. "medkit_item/tile000.png"),
		ration = make_static_set(pickups_base .. "ammo_box_item/tile000.png"),
		relic = make_static_set(pickups_base .. "access_card_item/tile000.png"),
		calming_tonic = make_static_set(pickups_base .. "chemical_pot_item/tile000.png"),
		speed_tonic = make_static_set(pickups_base .. "chemical_pot_item/tile002.png"),
		ward_charge = make_static_set(pickups_base .. "ammo_box_item/tile002.png"),
		-- world objects
		anchor = make_static_set("assets/sprites/vending_machines/Machine 1/Vending Machine 1.1.png"),
		anchor_lit = make_static_set("assets/sprites/vending_machines/Machine 1/Vending Machine 1.3.png"),
		pillar = make_static_set("assets/sprites/vending_machines/Machine 6/Vending Machine 6.1.png"),
		exit = make_static_set("assets/sprites/vending_machines/Machine 3/Vending Machine 3.1.png"),
		vending_machine = make_static_set("assets/sprites/vending_machines/Machine 5/Vending Machine 5.1.png"),
	}
end

function Sprites.get_anim(enemy)
	if enemy.alive == false then return "die" end
	if (enemy.retreat_time or 0) > 0 then return "hurt" end
	if (enemy.alert_time or 0) > 0 then return "walk" end
	return "idle"
end

function Sprites.get_frame(anim_data, time, fps)
	fps = fps or 8
	local idx = math.floor(time * fps) % anim_data.count
	return anim_data.quads[idx + 1], anim_data.image, anim_data.frame_w, anim_data.frame_h
end

return Sprites
