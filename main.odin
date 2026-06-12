package main

import "core:c"
import "core:fmt"
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

	// append(
	// 	&world,
	// 	Hittable{Material{.Lambertian, Color{0.5, 0.5, 0.5}}, Sphere{Vec3{0, 0, -1}, 0.5}},
	// )
	// append(
	// 	&world,
	// 	Hittable{Material{.Lambertian, Color{0.5, 0.5, 0.5}}, Sphere{Vec3{0, -100.5, -1}, 100}},
	// )
	ground_mat := Material{.Lambertian, Color{0.8, 0.8, 0}}
	center_mat := Material{.Lambertian, Color{0.1, 0.2, 0.5}}
	left_mat := Material{.Metal, Color{0.8, 0.8, 0.8}}
	right_mat := Material{.Metal, Color{0.8, 0.6, 0.2}}

	append_elems(
		&world,
		Hittable{Sphere{Vec3{0, -100.5, -1}, 100}, &ground_mat},
		Hittable{Sphere{Vec3{0, 0, -2}, 0.5}, &center_mat},
		Hittable{Sphere{Vec3{-1, 0, -1}, 0.5}, &left_mat},
		Hittable{Sphere{Vec3{1, 0, -1}, 0.5}, &right_mat},
	)

	cam := default_camera

	img := render(cam, world[:])
	defer delete(img)

	image.write_png(
		out_filepath,
		c.int(cam.image_width),
		c.int(cam.image_height),
		3,
		raw_data(img),
		c.int(cam.image_width * 3),
	)
}
