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

	expensive_cam := camera_init(
		image_width = 1600,
		center = Vec3{0.5, 0.5, 1},
		target = Vec3{0.5, 0.5, -1},
		samples_per_pixel = 1000,
		vertical_fov = 60,
		aspect_ratio = 1,
		max_bounces = 500,
	)
	cheap_cam := camera_init(
		image_width = 800,
		center = Vec3{0.5, 0.5, 1},
		target = Vec3{0.5, 0.5, -1},
		samples_per_pixel = 100,
		vertical_fov = 60,
		aspect_ratio = 1,
	)

	cam := expensive_cam

	world, mats := cornell_box()
	defer {
		world_delete(world[:])
		delete(world)
		delete(mats)
	}

	img := render(cam, world[:], Color{})
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

cornell_box :: proc() -> ([dynamic]Hittable, [dynamic]Material) {
	mats := make([dynamic]Material, 10)
	world := make([dynamic]Hittable, 10)

	mesh := `
		v 0 0 0
		v 1 0 0
		v 1 0 -1
		v 0 0 -1

		f 1 2 3
		f 1 3 4
	`

	floor, _ := mesh_load(mesh)
	ceiling, _ := mesh_load(mesh)
	left_wall, _ := mesh_load(mesh)
	right_wall, _ := mesh_load(mesh)
	back_wall, _ := mesh_load(mesh)
	front_wall, _ := mesh_load(mesh)
	light, _ := mesh_load(mesh)

	floor.transformation = transformation_matrix()
	ceiling.transformation = transformation_matrix(
		translation = {0, 1, -1},
		rotation_degrees = {180, 0, 0},
	)
	left_wall.transformation = transformation_matrix(
		translation = {0, 1, 0},
		rotation_degrees = {0, 0, -90},
	)
	right_wall.transformation = transformation_matrix(
		translation = {1, 0, 0},
		rotation_degrees = {0, 0, 90},
	)
	back_wall.transformation = transformation_matrix(
		translation = {0, 0, -1},
		rotation_degrees = {90, 0, 0},
	)
	front_wall.transformation = transformation_matrix(rotation_degrees = {-90, 0, 0})
	light.transformation = transformation_matrix(
		translation = {0.375, 0.9999, -0.625},
		scale = {0.25, 1, 0.25},
		rotation_degrees = {180, 0, 0},
	)

	white_lamb := Lambertian{Color{} + 1}
	red_lamb := Lambertian{Color{1, 0, 0}}
	green_lamb := Lambertian{Color{0, 1, 0}}
	light_mat := Diffuse_Light{Color{} + 1}

	append(&mats, Material(white_lamb))
	append(&world, Hittable{Object(floor), &mats[len(mats) - 1], mesh_make_bounding_box(floor)})
	append(
		&world,
		Hittable{Object(back_wall), &mats[len(mats) - 1], mesh_make_bounding_box(back_wall)},
	)
	append(
		&world,
		Hittable{Object(ceiling), &mats[len(mats) - 1], mesh_make_bounding_box(ceiling)},
	)
	// append(&world, Hittable{Object(front_wall), &mats[len(mats) - 1]})

	append(&mats, Material(red_lamb))
	append(
		&world,
		Hittable{Object(left_wall), &mats[len(mats) - 1], mesh_make_bounding_box(left_wall)},
	)

	append(&mats, Material(green_lamb))
	append(
		&world,
		Hittable{Object(right_wall), &mats[len(mats) - 1], mesh_make_bounding_box(right_wall)},
	)

	append(&mats, Material(light_mat))
	append(&world, Hittable{Object(light), &mats[len(mats) - 1], mesh_make_bounding_box(light)})
	// append(&world, Hittable{Object(Sphere{Vec3{0.5, 0.95, -0.5}, 0.1}), &mats[len(mats) - 1]}) // sphere light

	// glass sphere
	// append(&mats, Material(Dielectric{1.5}))
	// append(&world, Hittable{Object(Sphere{Vec3{0.5, 0.5, -0.5}, 0.2}), &mats[len(mats) - 1], {}})

	// lambertian teapot (needs bounding box optimization to be feasible)
	teapot, _ := mesh_load_from_file("objs/utah_teapot_mediumpoly.obj")
	teapot.transformation = transformation_matrix(
		translation = Vec3{0.5, 0.4, -0.5},
		rotation_degrees = Vec3{30, 45, 30},
		scale = Vec3{} + 0.1,
	)
	append(&mats, Material(white_lamb))
	append(&world, Hittable{Object(teapot), &mats[len(mats) - 1], mesh_make_bounding_box(teapot)})

	return world, mats
}

teapot_test :: proc() -> ([dynamic]Hittable, [dynamic]Material) {
	mats := make([dynamic]Material, 3)
	world := make([dynamic]Hittable, 3)

	mesh, ok := mesh_load_from_file("objs/utah_teapot_mediumpoly.obj")
	assert(ok)

	mesh.transformation = transformation_matrix(
		translation = Vec3{-0.1, 0.01, -2},
		rotation_degrees = Vec3{0, -45, 0},
		scale = Vec3{} + 0.5,
	)

	// teapot
	append(&mats, Material(Lambertian{Color{} + 1}))
	append(&world, Hittable{Object(mesh), &mats[len(mats) - 1], mesh_make_bounding_box(mesh)})

	// ground
	append(&mats, Material(Lambertian{Color{0, 0.7, 0.2}}))
	append(&world, Hittable{Object(Sphere{Vec3{0, -1000, 0}, 1000}), &mats[len(mats) - 1], {}})

	// sun
	append(&mats, Material(Diffuse_Light{Color{1, 1, 1}}))
	append(&world, Hittable{Sphere{Vec3{100, 1200, -100}, 800}, &mats[len(mats) - 1], {}})

	return world, mats
}

/*
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
*/
