package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:strings"

Camera :: struct {
	aspect_ratio:      f32,
	image_width:       int,
	image_height:      int,
	focal_length:      f32,
	center:            Vec3,
	target:            Vec3,
	up:                Vec3,
	vertical_fov:      f32,
	viewport_width:    f32,
	viewport_height:   f32,
	viewport_u:        Vec3,
	viewport_v:        Vec3,
	samples_per_pixel: int,
	max_bounces:       int,
	first_pixel_loc:   Vec3,
	pixel_du:          Vec3,
	pixel_dv:          Vec3,
}

@(require_results)
camera_init :: proc(
	aspect_ratio: f32 = DEFAULT_ASPECT_RATIO,
	image_width: int = DEFAULT_IMAGE_WIDTH,
	center: Vec3 = DEFAULT_CAMERA_CENTER,
	target: Vec3 = DEFAULT_CAMERA_TARGET,
	up: Vec3 = DEFAULT_CAMERA_UP,
	vertical_fov: f32 = DEFAULT_VERTICAL_FOV,
	samples_per_pixel: int = DEFAULT_SAMPLES_PER_PIXEL,
	max_bounces: int = DEFAULT_MAX_BOUNCES,
) -> Camera {
	image_height := max(1, int(f32(image_width) / aspect_ratio))

	focal_length := length(center - target)
	theta := degrees_to_radians(vertical_fov)
	h := math.tan(theta / 2)

	viewport_height := 2 * h * focal_length
	viewport_width := viewport_height * (f32(image_width) / f32(image_height))

	w := normalize(center - target)
	u := normalize(cross(up, w))
	v := cross(w, u)

	viewport_u := viewport_width * u
	viewport_v := viewport_height * -v

	pixel_du := viewport_u / f32(image_width)
	pixel_dv := viewport_v / f32(image_height)

	viewport_upper_left := center - (focal_length * w) - (viewport_u + viewport_v) / 2
	first_pixel_loc := viewport_upper_left + (pixel_du + pixel_dv) / 2

	return Camera {
		aspect_ratio,
		image_width,
		image_height,
		focal_length,
		center,
		target,
		up,
		vertical_fov,
		viewport_width,
		viewport_height,
		viewport_u,
		viewport_v,
		samples_per_pixel,
		max_bounces,
		first_pixel_loc,
		pixel_du,
		pixel_dv,
	}
}

@(require_results)
degrees_to_radians :: proc(deg: f32) -> f32 {
	return deg * math.PI / 180
}

@(require_results)
ray_color :: proc(ray: Ray, world: []Hittable, depth: int) -> Color {
	if depth <= 0 do return Color{0, 0, 0}

	if hit, did_hit := ray_hit_any(ray, Interval{0.001, pos_infinity}, world).?; did_hit {
		if scattered, attenuation, did_scatter := scatter(ray, hit, hit.mat); did_scatter {
			return attenuation * ray_color(scattered, world, depth - 1)
		} else {
			// this should only be possible to reachin weird floating point edge cases i think?
			return Color{0, 0, 0}
		}
	}

	// background 'sky'
	dir := normalize(ray.direction)
	a := (dir.y + 1.0) / 2.0
	return lerp(Color{1, 1, 1}, Color{0.5, 0.7, 1}, a)
}

@(require_results)
render :: proc(cam: Camera, world: []Hittable) -> [dynamic]byte {
	img := make([dynamic]byte)
	reserve(&img, cam.image_width * cam.image_height * 3)

	for j in 0 ..< cam.image_height {
		draw_progress_bar(int(j + 1), int(cam.image_height))
		for i in 0 ..< cam.image_width {
			pixel_color: Color

			for _ in 0 ..< cam.samples_per_pixel {
				offset := [2]f32{rand.float32(), rand.float32()} / 2.0
				pixel_sample :=
					cam.first_pixel_loc +
					(f32(i) * cam.pixel_du + (cam.pixel_du * offset.x)) +
					(f32(j) * cam.pixel_dv + (cam.pixel_dv * offset.y))

				ray := Ray {
					origin    = cam.center,
					direction = pixel_sample - cam.center,
				}

				pixel_color += ray_color(ray, world, cam.max_bounces) / f32(cam.samples_per_pixel)
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
DEFAULT_ASPECT_RATIO :: 16.0 / 9.0

@(private = "file")
DEFAULT_IMAGE_WIDTH :: 400

@(private = "file")
DEFAULT_CAMERA_CENTER :: Vec3{0, 0, 0}
@(private = "file")
DEFAULT_CAMERA_TARGET :: Vec3{0, 0, -1}
@(private = "file")
DEFAULT_CAMERA_UP :: Vec3{0, 1, 0}

@(private = "file")
DEFAULT_VERTICAL_FOV :: 90

@(private = "file")
DEFAULT_SAMPLES_PER_PIXEL :: 100
@(private = "file")
DEFAULT_MAX_BOUNCES :: 50
