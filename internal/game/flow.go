package game

func BuildDistanceMap(level Level, starts []Point, occupied map[Point]bool) map[Point]int {
	queue := make([]Point, 0, len(starts))
	distances := map[Point]int{}
	for _, start := range starts {
		if !level.IsWalkable(start) {
			continue
		}
		if _, seen := distances[start]; seen {
			continue
		}
		queue = append(queue, start)
		distances[start] = 0
	}

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		for _, dir := range CardinalDirections {
			next := current.Add(dir)
			if !level.IsWalkable(next) {
				continue
			}
			if occupied != nil && occupied[next] {
				continue
			}
			if _, seen := distances[next]; seen {
				continue
			}
			distances[next] = distances[current] + 1
			queue = append(queue, next)
		}
	}
	return distances
}

func BuildDarknessMap(level Level, visible map[Point]bool, occupied map[Point]bool) map[Point]int {
	starts := []Point{}
	for y := 0; y < level.Height; y++ {
		for x := 0; x < level.Width; x++ {
			point := Point{X: x, Y: y}
			if !level.IsWalkable(point) || visible[point] {
				continue
			}
			starts = append(starts, point)
		}
	}
	return BuildDistanceMap(level, starts, occupied)
}

func stepByDistanceMap(level Level, start Point, distances map[Point]int, occupied map[Point]bool, chooseHigher bool) Point {
	best := start
	bestScore, ok := distances[start]
	if !ok {
		if chooseHigher {
			bestScore = -1
		} else {
			bestScore = 1 << 30
		}
	}
	for _, dir := range CardinalDirections {
		next := start.Add(dir)
		if !level.IsWalkable(next) {
			continue
		}
		if occupied[next] {
			continue
		}
		score, exists := distances[next]
		if !exists {
			continue
		}
		if chooseHigher {
			if score > bestScore {
				bestScore = score
				best = next
			}
		} else if score < bestScore {
			bestScore = score
			best = next
		}
	}
	return best
}
