package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"

Camera :: struct {
	aspect_ratio:        f32,
	image_width:         int,
	image_height:        int,
	image_dimensions:    [2]int,
	focal_length:        f32,
	center:              Vec3,
	viewport_height:     f32,
	viewport_width:      f32,
	viewport_dimensions: [2]f32,
	viewport_u:          Vec3,
	viewport_v:          Vec3,
	samples_per_pixel:   int,
	pixel_du:            Vec3,
	pixel_dv:            Vec3,
}

default_camera :: Camera {
	default_aspect_ratio,
	default_image_width,
	default_image_height,
	default_image_dimensions,
	default_focal_length,
	default_camera_center,
	default_viewport_height,
	default_viewport_width,
	default_viewport_dimensions,
	default_viewport_u,
	default_viewport_v,
	default_samples_per_pixel,
	default_pixel_du,
	default_pixel_dv,
}

ray_color :: proc(ray: Ray, world: []Hittable) -> Color {
	if hit, did_hit := ray_hit_any(ray, Interval{0, pos_infinity}, world).?; did_hit {
		return Color(hit.normal + 1.0) / 2.0
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
		fmt.printf("\r  %d/%d lines rendered", int(j + 1), int(cam.image_height))
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

				pixel_color += ray_color(ray, world[:]) / f32(cam.samples_per_pixel)
			}

			bytes := color_to_bytes(pixel_color)
			append_elems(&img, bytes.r, bytes.g, bytes.b)
		}
	}
	fmt.printf("\n  done\n")

	return img
}

@(private = "file")
default_aspect_ratio :: 16.0 / 9.0

@(private = "file")
default_image_width :: 800
@(private = "file")
default_image_height :: default_image_width / default_aspect_ratio
@(private = "file")
default_image_dimensions :: [2]int{int(default_image_width), int(default_image_height)}

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
default_viewport_dimensions :: [2]f32{default_viewport_width, default_viewport_height}

@(private = "file")
default_viewport_u :: Vec3{default_viewport_width, 0, 0}
@(private = "file")
default_viewport_v :: Vec3{0, -default_viewport_height, 0}

@(private = "file")
default_samples_per_pixel :: 16
@(private = "file")
default_pixel_du :: Vec3{default_viewport_width / default_image_width, 0, 0}
@(private = "file")
default_pixel_dv :: Vec3{0, -default_viewport_height / default_image_height, 0}
