package main

import "core:c"
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

ray_hit_any :: proc(ray: Ray, interval: Interval, world: []Hittable) -> Maybe(Hit_Record) {
	maybe_hit: Maybe(Hit_Record)
	closest_so_far := interval.max
	for obj in world {
		if hit, did_hit := ray_hit(ray, Interval{interval.min, closest_so_far}, obj).?; did_hit {
			closest_so_far = hit.t
			maybe_hit = hit
		}
	}

	return maybe_hit
}

ray_color :: proc(ray: Ray, world: []Hittable) -> Color {
	sphere := Hittable(Sphere{Vec3{0, 0, -1}, 0.5})

	ray_tmin: f32 = 0
	ray_tmax: f32 = math.inf_f32(1)

	if hit, did_hit := ray_hit_any(ray, Interval{0, pos_infinity}, world).?; did_hit {
		return Color(hit.normal + 1.0) / 2.0
	}

	// background 'sky'
	dir := linalg.normalize(ray.direction)
	a := (dir.y + 1.0) / 2.0
	return lerp(Color{1, 1, 1}, Color{0.5, 0.7, 1}, a)
}

main :: proc() {
	viewport_upper_left := camera_center - Vec3{0, 0, focal_length} - (viewport_u + viewport_v) / 2
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
		c.int(image_width),
		c.int(image_height),
		3,
		raw_data(img),
		c.int(image_width * 3),
	)
}
