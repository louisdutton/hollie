package tween

import "core:math/ease"
import "core:time"

F :: f32

flux: ease.Flux_Map(F)

init :: proc() {
	flux = ease.flux_init(F)
}

// creates a tween
to :: #force_inline proc(
	from: ^F,
	to: F,
	easing := ease.Ease.Quadratic_Out,
	duration := time.Second,
	delay: f64 = 0,
) -> ^ease.Flux_Tween {
	tween := ease.flux_to(&flux, from, to, easing, duration, delay)
	return tween
}

// updates all active tweens
update :: #force_inline proc(dt: f32) {
	ease.flux_update(&flux, f64(dt))
}

// clears all active tweens (does not de-allocate)
clear :: #force_inline proc() {
	ease.flux_clear(&flux)
}

// de-allocates all tweens
destroy :: #force_inline proc() {
	ease.flux_destroy(flux)
}
