package tween

import "core:math/ease"
import "core:time"

f :: f32

flux := ease.flux_init(f)

// creates a tween
to :: #force_inline proc(
	from: ^f,
	to: f,
	easing := ease.Ease.Quadratic_Out,
	duration := time.Second,
	delay: f64 = 0,
) -> ^ease.Flux_Tween {
	tween := ease.flux_to(&flux, from, to, easing, duration, delay)
	return tween
}

// updates all active tweens
update :: #force_inline proc(dt: f64) {
	ease.flux_update(&flux, dt)
}

// clears all active tweens (does not de-allocate)
clear :: #force_inline proc() {
	ease.flux_clear(&flux)
}

// de-allocates all tweens
destroy :: #force_inline proc() {
	ease.flux_destroy(flux)
}
