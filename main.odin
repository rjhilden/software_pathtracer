package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "vendor:stb/image"

aspect_ratio :: 16.0 / 9.0

image_width :: 400
image_height :: image_width / aspect_ratio
image_dimensions :: [2]int{image_width, image_height}

focal_length :: 1
camera_center :: Vec3{0, 0, 0}

viewport_height :: 2
viewport_width :: viewport_height * (f32(image_width) / f32(image_height))
viewport_dimensions :: [2]f32{viewport_width, viewport_height}

viewport_u :: Vec3{viewport_width, 0, 0}
viewport_v :: Vec3{0, -viewport_height, 0}

pixel_du :: Vec3{viewport_width / image_width, 0, 0}
pixel_dv :: Vec3{0, -viewport_height / image_height, 0}

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

ray_color :: proc(ray: Ray, hittables: []Hittable) -> Color {
	sphere := Hittable(Sphere{Vec3{0, 0, -1}, 0.5})

	ray_tmin: f32 = 0
	ray_tmax: f32 = math.inf_f32(1)

	closest_so_far := ray_tmax
	maybe_hit: Maybe(Hit_Record)
	for hittable in hittables {
		if hit, did_hit := ray_hit(ray, ray_tmin, closest_so_far, hittable).?; did_hit {
			closest_so_far = hit.t
			maybe_hit = hit
		}
	}

	if hit, did_hit := maybe_hit.?; did_hit {
		return Color(hit.normal + 1.0) / 2.0
	}

	// background 'sky'
	dir := linalg.normalize(ray.direction)
	a := (dir.y + 1.0) / 2.0
	return lerp(Color{1, 1, 1}, Color{0.5, 0.7, 1}, a)
}

Hittable :: union {
	Sphere,
}

Hit_Record :: struct {
	t:          f32, // t value for collision
	point:      Vec3, // point where the collision happens
	normal:     Vec3, // normal vector for collision on object
	front_face: bool, // whether the hit was on the object's front face
}

ray_hit :: proc(ray: Ray, ray_tmin, ray_tmax: f32, hittable: Hittable) -> Maybe(Hit_Record) {
	switch obj in hittable {
	case Sphere:
		return ray_sphere_hit(ray, ray_tmin, ray_tmax, obj)
	case:
		return nil
	}
}

Sphere :: struct {
	center: Vec3,
	radius: f32,
}

ray_sphere_hit :: proc(ray: Ray, ray_tmin, ray_tmax: f32, sphere: Sphere) -> Maybe(Hit_Record) {
	oc := sphere.center - ray.origin
	a := math.pow(linalg.length(ray.direction), 2)
	h := linalg.dot(ray.direction, oc)
	c := math.pow(linalg.length(oc), 2) - sphere.radius * sphere.radius

	discriminant := h * h - a * c
	if discriminant < 0 do return nil

	// find the nearest root within (ray_tmin, ray_tmax)
	disc_sqrt := math.sqrt(discriminant)
	root := (h - disc_sqrt) / a
	if root <= ray_tmin || ray_tmax <= root {
		root = (h + disc_sqrt) / a
		if root <= ray_tmin || ray_tmax <= root do return nil
	}

	rec: Hit_Record
	rec.t = root
	rec.point = ray_at(ray, rec.t)

	outward_normal := (rec.point - sphere.center) / sphere.radius
	rec.front_face = linalg.dot(ray.direction, outward_normal) < 0
	rec.normal = outward_normal if rec.front_face else -outward_normal

	return rec
}

main :: proc() {
	viewport_upper_left :=
		camera_center - Vec3{0, 0, focal_length} - viewport_u / 2 - viewport_v / 2
	first_pixel_loc := viewport_upper_left + (pixel_du + pixel_dv) / 2

	world := make([dynamic]Hittable)
	defer delete(world)

	append(&world, Hittable(Sphere{Vec3{0, 0, -1}, 0.5}))
	append(&world, Hittable(Sphere{Vec3{0.2, -0.1, -0.5}, 0.10}))
	append(&world, Hittable(Sphere{Vec3{0, -100.5, -1}, 100}))

	img := make([dynamic]byte)
	defer delete(img)
	reserve(&img, image_width * image_height * 3)

	for j in 0 ..< image_height {
		fmt.printf("\r  %d/%d lines rendered", int(j + 1), int(image_height))
		for i in 0 ..< image_width {
			pixel_center := first_pixel_loc + (f32(i) * pixel_du) + (f32(j) * pixel_dv)
			ray := Ray {
				origin    = camera_center,
				direction = pixel_center - camera_center,
			}

			pixel_color := ray_color(ray, world[:])
			bytes := color_to_bytes(pixel_color)
			append_elems(&img, bytes.r, bytes.g, bytes.b)
		}
	}
	fmt.printf("\n  done\n")

	image.write_png(
		"out.png",
		auto_cast image_width,
		auto_cast image_height,
		3,
		raw_data(img),
		auto_cast image_width * 3,
	)
}
