package game

type basicAI struct {
	kind EnemyKind
}

func aiForKind(kind EnemyKind) EnemyAI {
	return basicAI{kind: kind}
}

func (ai basicAI) NextAction(view LevelView, state ActorState) Action {
	level := *view.Level
	enemy := state.Self
	player := state.Player
	occupied := cloneOccupied(view.Occupied)
	delete(occupied, enemy.Pos)

	if manhattan(enemy.Pos, player.Pos) == 1 {
		switch ai.kind {
		case EnemyRusher:
			return Action{Kind: ActionAttack, Target: player.Pos, Power: 2}
		case EnemyLeech:
			return Action{Kind: ActionDim, Target: player.Pos, Power: 1}
		case EnemyBoss:
			return Action{Kind: ActionAttack, Target: player.Pos, Power: 2}
		default:
			return Action{Kind: ActionAttack, Target: player.Pos, Power: 1}
		}
	}

	switch ai.kind {
	case EnemyStalker:
		return stalkerAction(level, view, enemy, player, occupied)
	case EnemyRusher:
		return rusherAction(level, view, enemy, player, occupied)
	case EnemySentry:
		return sentryAction(level, view, enemy, player, occupied)
	case EnemyLeech:
		return leechAction(level, view, enemy, player, occupied)
	case EnemyBoss:
		return bossAction(level, view, enemy, player, occupied)
	default:
		return Action{Kind: ActionWait}
	}
}

func stalkerAction(level Level, view LevelView, enemy Enemy, player Player, occupied map[Point]bool) Action {
	switch enemy.State {
	case EnemyStateChase:
		if step := stepByDistanceMap(level, enemy.Pos, view.DistanceToPlayer, occupied, false); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	case EnemyStateSearch:
		target := enemy.LastSeen
		if target == (Point{}) {
			target = enemy.Home
		}
		if step := NextStepToward(level, enemy.Pos, target, occupied); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	case EnemyStateRetreat:
		if step := stepByDistanceMap(level, enemy.Pos, view.DistanceFromPlayer, occupied, false); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	default:
		if view.VisibleToPlayer[enemy.Pos] {
			if step := stepByDistanceMap(level, enemy.Pos, view.DistanceFromPlayer, occupied, false); step != enemy.Pos {
				return Action{Kind: ActionMove, Target: step}
			}
		}
		if step := stepTowardPatrol(level, enemy, occupied); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	return Action{Kind: ActionWait}
}

func rusherAction(level Level, view LevelView, enemy Enemy, player Player, occupied map[Point]bool) Action {
	if enemy.State == EnemyStateChase && (enemy.Pos.X == player.Pos.X || enemy.Pos.Y == player.Pos.Y) && enemyCanSeePlayer(level, enemy, player) {
		path := FindPath(level, enemy.Pos, player.Pos, occupied)
		if len(path) >= 2 {
			steps := min(3, len(path)-1)
			return Action{Kind: ActionMove, Target: path[steps], Power: steps}
		}
	}
	if enemy.State == EnemyStateChase || enemy.State == EnemyStateSearch {
		if step := stepByDistanceMap(level, enemy.Pos, view.DistanceToPlayer, occupied, false); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	if step := stepTowardPatrol(level, enemy, occupied); step != enemy.Pos {
		return Action{Kind: ActionMove, Target: step}
	}
	return Action{Kind: ActionWait}
}

func sentryAction(level Level, view LevelView, enemy Enemy, player Player, occupied map[Point]bool) Action {
	if enemyCanSeePlayer(level, enemy, player) {
		return Action{Kind: ActionAlarm, Target: player.Pos, Power: 4}
	}
	if enemy.State == EnemyStateSearch {
		if step := NextStepToward(level, enemy.Pos, enemy.LastSeen, occupied); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	if manhattan(enemy.Pos, enemy.Home) > 2 {
		if step := NextStepToward(level, enemy.Pos, enemy.Home, occupied); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	return Action{Kind: ActionWait}
}

func leechAction(level Level, view LevelView, enemy Enemy, player Player, occupied map[Point]bool) Action {
	if enemy.State == EnemyStateRetreat {
		if step := stepByDistanceMap(level, enemy.Pos, view.DistanceFromPlayer, occupied, false); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	if enemy.State == EnemyStateChase || enemy.State == EnemyStateSearch {
		next := bestLeechStep(level, view, enemy.Pos, occupied)
		if next != enemy.Pos {
			return Action{Kind: ActionMove, Target: next}
		}
	}
	if step := stepTowardPatrol(level, enemy, occupied); step != enemy.Pos {
		return Action{Kind: ActionMove, Target: step}
	}
	return Action{Kind: ActionWait}
}

func bossAction(level Level, view LevelView, enemy Enemy, player Player, occupied map[Point]bool) Action {
	distance := manhattan(enemy.Pos, player.Pos)
	if distance >= 4 {
		if step := stepByDistanceMap(level, enemy.Pos, view.DistanceToPlayer, occupied, false); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	if distance <= 2 {
		if step := stepByDistanceMap(level, enemy.Pos, view.DistanceToPlayer, occupied, true); step != enemy.Pos {
			return Action{Kind: ActionMove, Target: step}
		}
	}
	if step := NextStepToward(level, enemy.Pos, player.Pos, occupied); step != enemy.Pos {
		return Action{Kind: ActionMove, Target: step}
	}
	return Action{Kind: ActionWait}
}

func enemyCanSeePlayer(level Level, enemy Enemy, player Player) bool {
	switch enemy.Kind {
	case EnemySentry:
		return InCone(enemy.Pos, enemy.Facing, player.Pos, 7) && HasLineOfSight(level, enemy.Pos, player.Pos)
	case EnemyBoss:
		return HasLineOfSight(level, enemy.Pos, player.Pos) && manhattan(enemy.Pos, player.Pos) <= 10
	default:
		return HasLineOfSight(level, enemy.Pos, player.Pos) && manhattan(enemy.Pos, player.Pos) <= 8
	}
}

func bestLeechStep(level Level, view LevelView, start Point, occupied map[Point]bool) Point {
	best := start
	bestScore := 1 << 30
	for _, dir := range CardinalDirections {
		next := start.Add(dir)
		if !level.IsWalkable(next) || occupied[next] {
			continue
		}
		playerDist, ok := view.DistanceToPlayer[next]
		if !ok {
			continue
		}
		darknessDist := view.DistanceFromPlayer[next]
		score := playerDist*2 + darknessDist
		if !view.VisibleToPlayer[next] {
			score -= 2
		}
		if score < bestScore {
			bestScore = score
			best = next
		}
	}
	return best
}

func stepTowardPatrol(level Level, enemy Enemy, occupied map[Point]bool) Point {
	target := enemy.Patrol
	if target == (Point{}) {
		target = enemy.Home
	}
	if enemy.Pos == target {
		target = enemy.Home
	}
	if target == (Point{}) || target == enemy.Pos {
		return enemy.Pos
	}
	return NextStepToward(level, enemy.Pos, target, occupied)
}

func cloneOccupied(input map[Point]bool) map[Point]bool {
	output := make(map[Point]bool, len(input))
	for key, value := range input {
		output[key] = value
	}
	return output
}

func manhattan(a, b Point) int {
	return abs(a.X-b.X) + abs(a.Y-b.Y)
}
