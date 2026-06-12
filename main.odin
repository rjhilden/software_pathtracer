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

	append(&world, Hittable(Sphere{Vec3{0, 0, -1}, 0.5}))
	append(&world, Hittable(Sphere{Vec3{0.2, -0.1, -0.5}, 0.10}))
	append(&world, Hittable(Sphere{Vec3{0, -100.5, -1}, 100}))

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
