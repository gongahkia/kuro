package game

func FindPath(level Level, start, goal Point, occupied map[Point]bool) []Point {
	if start == goal {
		return []Point{start}
	}

	queue := []Point{start}
	parents := map[Point]Point{}
	visited := map[Point]bool{start: true}

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		for _, dir := range CardinalDirections {
			next := current.Add(dir)
			if !level.IsWalkable(next) {
				continue
			}
			if occupied != nil && occupied[next] && next != goal {
				continue
			}
			if visited[next] {
				continue
			}
			visited[next] = true
			parents[next] = current
			if next == goal {
				return unwindPath(parents, start, goal)
			}
			queue = append(queue, next)
		}
	}
	return nil
}

func NextStepToward(level Level, start, goal Point, occupied map[Point]bool) Point {
	path := FindPath(level, start, goal, occupied)
	if len(path) >= 2 {
		return path[1]
	}
	return start
}

func unwindPath(parents map[Point]Point, start, goal Point) []Point {
	path := []Point{goal}
	current := goal
	for current != start {
		parent, ok := parents[current]
		if !ok {
			return nil
		}
		path = append(path, parent)
		current = parent
	}
	for i, j := 0, len(path)-1; i < j; i, j = i+1, j-1 {
		path[i], path[j] = path[j], path[i]
	}
	return path
}
