return {
	archetypes = {
		stalker = {
			speed = 1.35,
			damage = 1,
			range = 7.0,
			attack_cooldown = 0.85,
			health = 35,
		},
		rusher = {
			speed = 1.55,
			damage = 2,
			range = 8.0,
			attack_cooldown = 1.0,
			health = 45,
		},
		leech = {
			speed = 1.45,
			damage = 1,
			range = 6.0,
			attack_cooldown = 1.0,
			health = 45,
		},
		sentry = {
			speed = 0.75,
			damage = 1,
			range = 7.5,
			attack_cooldown = 1.2,
			health = 45,
		},
		umbra = {
			speed = 1.25,
			damage = 2,
			range = 10.0,
			attack_cooldown = 1.1,
			health = 999,
		},
	},
	modifiers = {
		swift = { speed_mult = 1.4, health_mult = 0.8, label = "Swift" },
		armored = { speed_mult = 0.85, health_mult = 1.8, label = "Armored" },
		splitting = { on_death = "split", split_kind = "stalker", split_count = 2, label = "Splitting" },
		phasing = { phase_through_doors = true, phase_interval = 3.0, label = "Phasing" },
		cursed = { on_hit_player = "drain_light", drain_amount = 15, label = "Cursed" },
	},
}
