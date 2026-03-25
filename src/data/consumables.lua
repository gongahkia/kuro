local Consumables = {
	order = {
		"calming_tonic",
		"speed_tonic",
		"ward_charge",
	},
	defs = {
		calming_tonic = {
			id = "calming_tonic",
			label = "Calming Tonic",
			short_label = "Tonic",
			desc = "Restore a large amount of sanity.",
			drop_weight = 4,
			kind = "calming_tonic",
		},
		speed_tonic = {
			id = "speed_tonic",
			label = "Speed Tonic",
			short_label = "Speed",
			desc = "Sprint and strafe faster for a short burst.",
			drop_weight = 3,
			duration = 8.0,
			speed_mult = 1.28,
			kind = "speed_tonic",
		},
		ward_charge = {
			id = "ward_charge",
			label = "Ward Charge",
			short_label = "Ward",
			desc = "Adds one emergency ward against the next hit.",
			drop_weight = 2,
			restore_sanity = 16,
			kind = "ward_charge",
		},
	},
}

function Consumables.get(id)
	return Consumables.defs[id]
end

return Consumables
