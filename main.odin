package main

import "core:fmt"
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

ray_color :: proc(ray: Ray) -> Color {
	dir := linalg.normalize(ray.direction)
	a := (dir.y + 1.0) / 2.0
	return lerp(Color{1, 1, 1}, Color{0.5, 0.7, 1}, a)
}

main :: proc() {
	viewport_upper_left :=
		camera_center - Vec3{0, 0, focal_length} - viewport_u / 2 - viewport_v / 2
	first_pixel_loc := viewport_upper_left + (pixel_du + pixel_dv) / 2

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

			pixel_color := ray_color(ray)
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
