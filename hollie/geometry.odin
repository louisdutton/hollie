package hollie

import "core:math"
import "renderer"

// Check collision between two rectangles
rects_intersect :: proc(a, b: renderer.Rect) -> bool {
	return(
		a.x < b.x + b.width &&
		a.x + a.width > b.x &&
		a.y < b.y + b.height &&
		a.y + a.height > b.y \
	)
}

// TODO: this shouldnt be here
// this is for accurate distance and shouldn't be used in performance-critical contexts
get_distance :: proc(a, b: Vec2) -> f32 {
	return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
}
