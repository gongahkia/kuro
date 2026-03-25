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

function Sprites.load()
	return {
		stalker = load_skeleton("White"),
		rusher = load_skeleton("Yellow"),
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
