package main

import "core:fmt"
import "vendor:stb/image"

main :: proc() {
	Image_Dimensions :: [2]int{256, 256}

	img := make([dynamic]byte)
	defer delete(img)
	reserve(&img, Image_Dimensions.x * Image_Dimensions.y * 3)

	for j in 0 ..< Image_Dimensions.y {
		for i in 0 ..< Image_Dimensions.x {
			r := f32(i) / f32(Image_Dimensions.x - 1)
			g := f32(j) / f32(Image_Dimensions.y - 1)
			b := f32(0)

			ir := cast(byte)(255 * r)
			ig := cast(byte)(255 * g)
			ib := cast(byte)(255 * b)

			append(&img, ir)
			append(&img, ig)
			append(&img, ib)
		}
	}

	image.write_png(
		"out.png",
		auto_cast Image_Dimensions.x,
		auto_cast Image_Dimensions.y,
		3,
		raw_data(img),
		auto_cast Image_Dimensions.x * 3,
	)
}
