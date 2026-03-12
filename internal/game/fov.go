package game

func ComputeFOV(level Level, origin Point, radius int) map[Point]bool {
	visible := map[Point]bool{}
	visible[origin] = true
	multipliers := [8][4]int{
		{1, 0, 0, 1},
		{0, 1, 1, 0},
		{0, -1, 1, 0},
		{-1, 0, 0, 1},
		{-1, 0, 0, -1},
		{0, -1, -1, 0},
		{0, 1, -1, 0},
		{1, 0, 0, -1},
	}
	for _, m := range multipliers {
		castLight(level, origin.X, origin.Y, 1, 1.0, 0.0, radius, m[0], m[1], m[2], m[3], visible)
	}
	return visible
}

func castLight(level Level, cx, cy, row int, start, end float64, radius int, xx, xy, yx, yy int, visible map[Point]bool) {
	if start < end {
		return
	}
	radiusSquared := radius * radius
	newStart := start
	for distance := row; distance <= radius; distance++ {
		blocked := false
		for dx, dy := -distance, -distance; dx <= 0; dx++ {
			currentX := cx + dx*xx + dy*xy
			currentY := cy + dx*yx + dy*yy
			leftSlope := (float64(dx) - 0.5) / (float64(dy) + 0.5)
			rightSlope := (float64(dx) + 0.5) / (float64(dy) - 0.5)
			if start < rightSlope {
				continue
			}
			if end > leftSlope {
				break
			}

			point := Point{X: currentX, Y: currentY}
			if dx*dx+dy*dy <= radiusSquared && level.InBounds(point) {
				visible[point] = true
			}

			if blocked {
				if level.BlocksSight(point) {
					newStart = rightSlope
					continue
				}
				blocked = false
				start = newStart
			} else if level.BlocksSight(point) && distance < radius {
				blocked = true
				castLight(level, cx, cy, distance+1, start, leftSlope, radius, xx, xy, yx, yy, visible)
				newStart = rightSlope
			}
		}
		if blocked {
			break
		}
	}
}

func HasLineOfSight(level Level, from, to Point) bool {
	x0, y0 := from.X, from.Y
	x1, y1 := to.X, to.Y
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	sx := -1
	if x0 < x1 {
		sx = 1
	}
	sy := -1
	if y0 < y1 {
		sy = 1
	}
	err := dx + dy

	for {
		point := Point{X: x0, Y: y0}
		if point != from && point != to && level.BlocksSight(point) {
			return false
		}
		if x0 == x1 && y0 == y1 {
			return true
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
	}
}

func InCone(origin, facing, target Point, distance int) bool {
	if target == origin {
		return true
	}
	dx := target.X - origin.X
	dy := target.Y - origin.Y
	if abs(dx)+abs(dy) > distance {
		return false
	}
	if facing.X == 0 && facing.Y == 0 {
		return true
	}
	if facing.X != 0 {
		if dx*facing.X <= 0 {
			return false
		}
		return abs(dy) <= abs(dx)
	}
	if dy*facing.Y <= 0 {
		return false
	}
	return abs(dx) <= abs(dy)
}
