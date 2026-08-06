package main

import "core:c"
import "core:fmt"
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

	cam := camera_init(
		image_width = 400,
		vertical_fov = 90,
		center = Vec3{0, 1.5, 0},
		target = Vec3{0, 0, -2},
		samples_per_pixel = 200,
	)

	world, mats := teapot_test()
	defer delete(world)
	defer delete(mats)

	img := render(cam, world[:], Color{0, 0.2, 0.7})
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

mesh_test :: proc() -> ([dynamic]Hittable, [dynamic]Material) {
	mats := make([dynamic]Material, 3)
	world := make([dynamic]Hittable, 3)

	object := `
	# Simple Square Pyramid OBJ File

	v -1.0 0.0 -1.0
	v  1.0 0.0 -1.0
	v  1.0 0.0  1.0
	v -1.0 0.0  1.0
	v  0.0 1.5  0.0

	f 1 3 4
	f 1 2 3
	f 1 5 2
	f 2 5 3
	f 3 5 4
	f 4 5 1
	`
	mesh, ok := mesh_load(string(object))
	assert(ok)

	mesh.transformation = transformation_matrix(
		translation = Vec3{-0.1, 0.01, -2},
		rotation_degrees = Vec3{0, -30, 0},
		scale = Vec3{1, 1, 1},
	)

	// pyramid
	append(&mats, Material(Metal{Color{0.4, 0.6, 0.5}, 0}))
	append(&world, Hittable{Object(mesh), &mats[len(mats) - 1]})

	// ground
	append(&mats, Material(Lambertian{Color{} + 0.5}))
	append(&world, Hittable{Object(Sphere{Vec3{0, -1000, 0}, 1000}), &mats[len(mats) - 1]})

	// sun
	append(&mats, Material(Diffuse_Light{Color{1, 1, 1}}))
	append(&world, Hittable{Sphere{Vec3{1000, 200, 200}, 1000}, &mats[len(mats) - 1]})

	return world, mats
}

teapot_test :: proc() -> ([dynamic]Hittable, [dynamic]Material) {
	mats := make([dynamic]Material, 3)
	world := make([dynamic]Hittable, 3)

	mesh, ok := mesh_load_from_file("objs/utah_teapot_mediumpoly.obj")
	assert(ok)

	mesh.transformation = transformation_matrix(
		translation = Vec3{-0.1, 0.01, -2},
		rotation_degrees = Vec3{0, -15, 0},
		scale = Vec3{} + 0.5,
	)

	// teapot
	append(&mats, Material(Lambertian{Color{} + 1}))
	append(&world, Hittable{Object(mesh), &mats[len(mats) - 1]})

	// ground
	append(&mats, Material(Lambertian{Color{0, 0.7, 0.2}}))
	append(&world, Hittable{Object(Sphere{Vec3{0, -1000, 0}, 1000}), &mats[len(mats) - 1]})

	// sun
	append(&mats, Material(Diffuse_Light{Color{1, 1, 1}}))
	append(&world, Hittable{Sphere{Vec3{1000, 200, 200}, 1000}, &mats[len(mats) - 1]})

	return world, mats
}

many_spheres :: proc() -> ([dynamic]Hittable, [dynamic]Material) {
	mats := make([dynamic]Material, 50)
	world := make([dynamic]Hittable, 50)

	append(&mats, Material(Lambertian{Color{} + 0.5}))
	append(&world, Hittable{Object(Sphere{Vec3{0, -1000, 0}, 1000}), &mats[len(mats) - 1]})

	for a := -12; a < 12; a += 2 {
		for b := -12; b < 12; b += 2 {
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

	append(&mats, Material(Dielectric{1.5}))
	append(&world, Hittable{Sphere{Vec3{0, 1, 0}, 1.0}, &mats[len(mats) - 1]})

	append(&mats, Material(Lambertian{Color{0.4, 0.2, 0.1}}))
	append(&world, Hittable{Sphere{Vec3{-4, 1, 0}, 1.0}, &mats[len(mats) - 1]})

	append(&mats, Material(Metal{Color{0.7, 0.6, 0.5}, 0.0}))
	append(&world, Hittable{Sphere{Vec3{4, 1, 0}, 1.0}, &mats[len(mats) - 1]})

	append(&mats, Material(Diffuse_Light{Color{1, 1, 1}}))
	append(&world, Hittable{Sphere{Vec3{1000, 200, 200}, 1000}, &mats[len(mats) - 1]})

	return world, mats
}
