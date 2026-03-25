local Textures = {}

local function load_tex(path)
	local img = love.graphics.newImage(path)
	img:setWrap("repeat", "repeat")
	img:setFilter("nearest", "nearest")
	return img
end

function Textures.load()
	return {
		wall = load_tex("assets/textures/Bricks/DUNGEONBRICKS.png"),
		wall_deep = load_tex("assets/textures/Bricks/CASTLEBRICKS.png"),
		wall_cave = load_tex("assets/textures/Rocks/GRAYROCKS.png"),
		door = load_tex("assets/textures/Doors/CREAKYDOOR.png"),
		door_spooky = load_tex("assets/textures/Doors/SPOOKYDOOR.png"),
		shortcut = load_tex("assets/textures/Wood/DARKWOOD.png"),
		floor_rock = load_tex("assets/textures/Rocks/DIRT.png"),
		industrial = load_tex("assets/textures/Industrial/CROSSWALL.png"),
	}
end

function Textures.wall_for_floor(textures, floor_num)
	if floor_num >= 10 then return textures.industrial end
	if floor_num >= 7 then return textures.wall_cave end
	if floor_num >= 4 then return textures.wall_deep end
	return textures.wall
end

return Textures
