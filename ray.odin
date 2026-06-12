package main

Vec3 :: distinct [3]f32
Color :: distinct Vec3

lerp :: proc(x, y: $T/[$N]$E, a: E) -> T {
	return (1.0 - a) * x + a * y
}

color_to_bytes :: proc(color: Color) -> [3]byte {
	return cast([3]byte)(color * 255)
}

Ray :: struct {
	origin, direction: Vec3,
}

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

interval_contains :: proc(interval: Interval, x: f32) -> bool {
	return interval.min <= x && x <= interval.max
}

interval_surrounds :: proc(interval: Interval, x: f32) -> bool {
	return interval.min < x && x < interval.max
}
