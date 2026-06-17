package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strings"

import "vendor:stb/image"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		defer mem.tracking_allocator_destroy(&track)
		context.allocator = mem.tracking_allocator(&track)

		defer if len(track.allocation_map) > 0 {
			fmt.printfln("--- memory leaked ---")
			for _, leak in track.allocation_map {
				fmt.printfln("  - leaked %v bytes at %v", leak.size, leak.location)
			}
		}
	}

	out_filepath := strings.clone_to_cstring(os.args[1] if len(os.args) == 2 else "out.png")
	defer delete(out_filepath)

	world := make([dynamic]Hittable)
	defer delete(world)

	ground_mat := Material(Lambertian{Color{} + 0.5})
	append(&world, Hittable{Object(Sphere{Vec3{0, -1000, 0}, 1000}), &ground_mat})

	mats := make([dynamic]Material)
	defer delete(mats)

	for a := -11; a < 11; a += 1 {
		for b := -11; b < 11; b += 1 {
			choose_mat := rand.float32()
			center := Vec3{f32(a) + 0.9 * rand.float32(), 0.2, f32(b) + 0.9 * rand.float32()}

			if length(center - Vec3{4, 0.2, 0}) > 0.9 {
				if choose_mat < 0.8 {
					albedo := Color(vec3_random() * vec3_random())
					append(&mats, Material(Lambertian{albedo}))
				} else if choose_mat < 0.95 {
					albedo := Color(vec3_random_range(0.5, 1))
					fuzz := rand.float32_range(0, 0.5)
					append(&mats, Material(Metal{albedo, fuzz}))
				} else {
					append(&mats, Material(Dielectric{1.5}))
				}
				append(&world, Hittable{Object(Sphere{center, 0.2}), &mats[len(mats) - 1]})
			}
		}
	}

	mat1 := Material(Dielectric{1.5})
	append(&world, Hittable{Sphere{Vec3{0, 1, 0}, 1.0}, &mat1})

	mat2 := Material(Lambertian{Color{0.4, 0.2, 0.1}})
	append(&world, Hittable{Sphere{Vec3{-4, 1, 0}, 1.0}, &mat2})

	mat3 := Material(Metal{Color{0.7, 0.6, 0.5}, 0.0})
	append(&world, Hittable{Sphere{Vec3{4, 1, 0}, 1.0}, &mat3})

	cam := camera_init(
		image_width = 1200,
		vertical_fov = 20,
		center = Vec3{13, 2, 3},
		target = Vec3{},
		defocus_angle = 0.6,
		focus_dist = 10,
	)

	img := render(cam, world[:])
	defer delete(img)

	image.write_png(
		filename = out_filepath,
		w = c.int(cam.image_width),
		h = c.int(cam.image_height),
		comp = 3,
		data = raw_data(img),
		stride_in_bytes = c.int(cam.image_width * 3),
	)
}
