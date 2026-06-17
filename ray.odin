package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

Vec3 :: distinct [3]f32

dot :: linalg.dot
cross :: linalg.cross
length :: linalg.length
normalize :: linalg.normalize

@(require_results)
vec3_reflect :: proc(vec, normal: Vec3) -> Vec3 {
	return vec - 2 * dot(vec, normal) * normal
}

@(require_results)
vec3_refract :: proc(vec, normal: Vec3, refract_ratio: f32) -> Vec3 {
	cos_theta := math.min(1.0, dot(-vec, normal))
	refracted_perp := refract_ratio * (vec + cos_theta * normal)
	refracted_parallel := -math.sqrt(math.abs(1.0 - vec3_length_squared(refracted_perp))) * normal
	return refracted_perp + refracted_parallel
}

@(require_results)
vec3_length_squared :: proc(vec: Vec3) -> f32 {
	return dot(vec, vec)
}

@(require_results)
vec3_near_zero :: proc(vec: Vec3) -> bool {
	s :: 1e-8
	return math.abs(vec.x) < s && math.abs(vec.y) < s && math.abs(vec.z) < s
}

@(require_results)
vec3_random :: proc() -> Vec3 {
	return Vec3{rand.float32(), rand.float32(), rand.float32()}
}

@(require_results)
vec3_random_range :: proc(min, max: f32) -> Vec3 {
	return Vec3 {
		rand.float32_range(min, max),
		rand.float32_range(min, max),
		rand.float32_range(min, max),
	}
}

@(require_results)
vec3_random_unit :: proc() -> Vec3 {
	for true {
		vec := vec3_random_range(-1, 1)
		len_sq := vec3_length_squared(vec)
		if 1e-30 < len_sq && len_sq <= 1 do return normalize(vec)
	}
	unreachable()
}

@(require_results)
vec3_random_in_unit_disk :: proc() -> Vec3 {
	for true {
		vec := Vec3{rand.float32_range(-1, 1), rand.float32_range(-1, 1), 0}
		if vec3_length_squared(vec) < 1 do return vec
	}
	unreachable()
}

@(require_results)
vec3_random_unit_on_hemisphere :: proc(normal: Vec3) -> Vec3 {
	vec := vec3_random_unit()
	return vec if dot(vec, normal) > 0.0 else -vec
}

Color :: distinct Vec3

@(require_results)
lerp :: proc(x, y: $T/[$N]$E, a: E) -> T {
	return (1.0 - a) * x + a * y
}

@(require_results)
color_linear_to_gamma :: proc(color: Color) -> Color {
	return Color {
		0 if color.r < 0 else math.sqrt(color.r),
		0 if color.g < 0 else math.sqrt(color.g),
		0 if color.b < 0 else math.sqrt(color.b),
	}
}

// Convert raw color data to a byte array [r, g, b] for writing to an image.
// Converts linear color to gamma-space, clamps it to [0, 1), then scales it to [0, 255].
@(require_results)
color_to_bytes :: proc(color: Color) -> [3]byte {
	return cast([3]byte)(linalg.clamp(color_linear_to_gamma(color), Color{}, Color{1, 1, 1}) * 255)
}

Ray :: struct {
	origin, direction: Vec3,
}

@(require_results)
ray_at :: proc(ray: Ray, t: f32) -> Vec3 {
	return ray.origin + t * ray.direction
}

Interval :: struct {
	min, max: f32,
}

pos_infinity: f32 : 0h7F800000
neg_infinity: f32 : 0hFF800000

interval_empty :: Interval{pos_infinity, neg_infinity}
interval_universe :: Interval{neg_infinity, pos_infinity}

@(require_results)
interval_contains :: proc(interval: Interval, x: f32) -> bool {
	return interval.min <= x && x <= interval.max
}

@(require_results)
interval_surrounds :: proc(interval: Interval, x: f32) -> bool {
	return interval.min < x && x < interval.max
}
