package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:strings"

Camera :: struct {
	aspect_ratio:      f32,
	image_width:       int,
	image_height:      int,
	focal_length:      f32,
	center:            Vec3,
	viewport_height:   f32,
	viewport_width:    f32,
	viewport_u:        Vec3,
	viewport_v:        Vec3,
	samples_per_pixel: int,
	max_bounces:       int,
	pixel_du:          Vec3,
	pixel_dv:          Vec3,
}

default_camera :: Camera {
	default_aspect_ratio,
	default_image_width,
	default_image_height,
	default_focal_length,
	default_camera_center,
	default_viewport_height,
	default_viewport_width,
	default_viewport_u,
	default_viewport_v,
	default_samples_per_pixel,
	default_max_bounces,
	default_pixel_du,
	default_pixel_dv,
}

ray_color :: proc(ray: Ray, world: []Hittable, depth: int) -> Color {
	if depth <= 0 do return Color{0, 0, 0}

	if hit, did_hit := ray_hit_any(ray, Interval{0.001, pos_infinity}, world).?; did_hit {
		if scattered, attenuation, did_scatter := scatter(ray, hit, hit.mat); did_scatter {
			return attenuation * ray_color(scattered, world, depth - 1)
		} else {
			// this should be reached very rarely
			return Color{0, 0, 0}
		}
	}

	// background 'sky'
	dir := linalg.normalize(ray.direction)
	a := (dir.y + 1.0) / 2.0
	return lerp(Color{1, 1, 1}, Color{0.5, 0.7, 1}, a)
}

render :: proc(cam: Camera, world: []Hittable) -> [dynamic]byte {
	viewport_upper_left :=
		cam.center - Vec3{0, 0, cam.focal_length} - (cam.viewport_u + cam.viewport_v) / 2
	first_pixel_loc := viewport_upper_left + (cam.pixel_du + cam.pixel_dv) / 2

	img := make([dynamic]byte)
	reserve(&img, cam.image_width * cam.image_height * 3)

	for j in 0 ..< cam.image_height {
		draw_progress_bar(int(j + 1), int(cam.image_height))
		for i in 0 ..< cam.image_width {
			pixel_color: Color

			for _ in 0 ..< cam.samples_per_pixel {
				offset := [2]f32{rand.float32(), rand.float32()} / 2.0
				pixel_sample :=
					first_pixel_loc +
					(f32(i) * cam.pixel_du + (cam.pixel_du * offset.x)) +
					(f32(j) * cam.pixel_dv + (cam.pixel_dv * offset.y))

				ray := Ray {
					origin    = cam.center,
					direction = pixel_sample - cam.center,
				}

				pixel_color +=
					ray_color(ray, world[:], cam.max_bounces) / f32(cam.samples_per_pixel)
			}

			bytes := color_to_bytes(pixel_color)
			append_elems(&img, bytes.r, bytes.g, bytes.b)
		}
	}
	fmt.printf("\n  done\n")

	return img

	draw_progress_bar :: proc(current, target: int) {
		fmt.printf("  rendered %d/%d ", current, target)
		percent := f32(current) / f32(target)

		bars := strings.repeat("|", int(percent * 50), context.temp_allocator)
		dots := strings.repeat(".", 50 - len(bars), context.temp_allocator)
		fmt.print("[", bars, dots, "]\r", sep = "")

		mem.free_all(context.temp_allocator)
	}
}

@(private = "file")
default_aspect_ratio :: 16.0 / 9.0

@(private = "file")
default_image_width :: 400
@(private = "file")
default_image_height :: default_image_width / default_aspect_ratio

@(private = "file")
default_focal_length :: 1
@(private = "file")
default_camera_center :: Vec3{0, 0, 0}

@(private = "file")
default_viewport_height :: 2
@(private = "file")
default_viewport_width ::
	default_viewport_height * (f32(default_image_width) / f32(default_image_height))

@(private = "file")
default_viewport_u :: Vec3{default_viewport_width, 0, 0}
@(private = "file")
default_viewport_v :: Vec3{0, -default_viewport_height, 0}

@(private = "file")
default_samples_per_pixel :: 100
@(private = "file")
default_max_bounces :: 50

@(private = "file")
default_pixel_du :: Vec3{default_viewport_width / default_image_width, 0, 0}
@(private = "file")
default_pixel_dv :: Vec3{0, -default_viewport_height / default_image_height, 0}
