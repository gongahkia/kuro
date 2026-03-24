return {
	fragments = {
		{ id = 1, text = "The walls remember names the same way bones remember weight.", tier = 1, floor_min = 1 },
		{ id = 2, text = "A torch can wound Umbra only when the light is offered.", tier = 1, floor_min = 1 },
		{ id = 3, text = "The sentries were pilgrims who stared into the pit too long.", tier = 1, floor_min = 1 },
		{ id = 4, text = "The black water reflects a ceiling that does not exist.", tier = 1, floor_min = 1 },
		{ id = 5, text = "Every shrine marks a place where someone almost escaped.", tier = 1, floor_min = 1 },
		{ id = 6, text = "Leeches drink light, not blood. They were lantern-bearers once.", tier = 2, floor_min = 1 },
		{ id = 7, text = "The corridors shift when no one is watching. The walls are not stone.", tier = 2, floor_min = 2 },
		{ id = 8, text = "Rushers lost their patience before they lost their shape.", tier = 2, floor_min = 2 },
		{ id = 9, text = "Three anchors are not enough. The fourth was swallowed.", tier = 2, floor_min = 2 },
		{ id = 10, text = "Umbra is not the dark. Umbra is what happens when the dark gets hungry.", tier = 3, floor_min = 2 },
		{ id = 11, text = "The first descender carved these halls by burning. The second by running.", tier = 3, floor_min = 3 },
		{ id = 12, text = "What sleeps beneath the anchors is older than Umbra. Umbra is its breath.", tier = 3, floor_min = 3, secret = true },
	},
	codex_entries = {
		{ id = "origin", title = "The Descent", text = "They came seeking what the dark promised. The dark promised nothing — that was the point.", requires_fragments = { 1, 5 } },
		{ id = "sentries", title = "The Watchers", text = "Before they were sentries, they were faithful. The pit rewards devotion with paralysis.", requires_fragments = { 3, 7 } },
		{ id = "leeches", title = "The Hollow Bearers", text = "Each leech still carries the ghost of a lantern. They drain light because they remember warmth.", requires_fragments = { 6, 8 } },
		{ id = "umbra", title = "Umbra's Nature", text = "Not a creature. Not a god. A symptom. The darkness metabolizing itself.", requires_fragments = { 2, 10 } },
		{ id = "anchors", title = "The Binding", text = "Three anchors seal the breach. The fourth anchor failed because its bearer looked back.", requires_fragments = { 9, 11 } },
		{ id = "truth", title = "What Lies Beneath", text = "Umbra is exhaled. What inhales has no name and no light has ever reached it.", requires_fragments = { 10, 12 } },
	},
}
