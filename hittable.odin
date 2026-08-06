package main

import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:testing"

Object :: union {
	Sphere,
	Mesh,
}

Hittable :: struct {
	obj: Object,
	mat: ^Material,
}

Hit_Record :: struct {
	// t value for collision
	t:          f32,
	// point where the collision happens
	point:      Vec3,
	// normal vector for collision on object
	normal:     Vec3,
	// whether the hit was on the object's front face
	front_face: bool,
	// the material of the surface hit
	mat:        ^Material,
}

@(require_results)
ray_hit :: proc(ray: Ray, interval: Interval, hittable: Hittable) -> Maybe(Hit_Record) {
	switch obj in hittable.obj {
	case Sphere:
		return ray_sphere_hit(ray, interval, obj, hittable.mat)
	case Mesh:
		return ray_mesh_hit(ray, interval, obj, hittable.mat)
	case:
		return nil
	}
}

@(require_results)
ray_hit_any :: proc(ray: Ray, interval: Interval, world: []Hittable) -> Maybe(Hit_Record) {
	maybe_hit: Maybe(Hit_Record)

	closest_so_far := interval.max
	for obj in world {
		if hit, did_hit := ray_hit(ray, Interval{interval.min, closest_so_far}, obj).?; did_hit {
			closest_so_far = hit.t
			maybe_hit = hit
		}
	}

	return maybe_hit
}

Sphere :: struct {
	center: Vec3,
	radius: f32,
}

@(require_results)
ray_sphere_hit :: proc(
	ray: Ray,
	interval: Interval,
	sphere: Sphere,
	mat: ^Material,
) -> Maybe(Hit_Record) {
	oc := sphere.center - ray.origin
	a := math.pow(length(ray.direction), 2)
	h := dot(ray.direction, oc)
	c := math.pow(length(oc), 2) - sphere.radius * sphere.radius

	discriminant := h * h - a * c
	if discriminant < 0 do return nil

	// find the nearest root within (ray_tmin, ray_tmax)
	disc_sqrt := math.sqrt(discriminant)
	root := (h - disc_sqrt) / a
	if !interval_surrounds(interval, root) do root = (h + disc_sqrt) / a
	if !interval_surrounds(interval, root) do return nil

	rec: Hit_Record
	rec.t = root
	rec.point = ray_at(ray, rec.t)
	rec.mat = mat

	outward_normal := (rec.point - sphere.center) / sphere.radius
	rec.front_face = dot(ray.direction, outward_normal) < 0
	rec.normal = outward_normal if rec.front_face else -outward_normal

	return rec
}

Mesh :: struct {
	verts: []Vec3,
	norms: []Vec3,
	faces: []Face,
}

Face :: struct {
	verts: [3]u32,
	norms: [3]u32,
}

@(require_results)
ray_mesh_hit :: proc(
	ray: Ray,
	interval: Interval,
	mesh: Mesh,
	mat: ^Material,
) -> Maybe(Hit_Record) {
	return nil
}

@(require_results)
mesh_load_from_file :: proc(filepath: string) -> (mesh: Mesh, ok: bool = false) {
	data, err := os.read_entire_file_from_path(filepath, context.temp_allocator)
	if err != nil do return
	defer delete(data)

	return mesh_load(string(data))
}

@(require_results)
mesh_load :: proc(data: string) -> (mesh: Mesh, ok: bool = false) {
	verts := make([dynamic]Vec3, context.temp_allocator)
	norms := make([dynamic]Vec3, context.temp_allocator)
	faces := make([dynamic]Face, context.temp_allocator)
	defer mem.free_all(context.temp_allocator)

	str := string(data)
	for line in strings.split_lines_iterator(&str) {
		line := strings.trim_space(line)
		if len(line) == 0 || line[0] == '#' do continue

		type := strings.fields_iterator(&line) or_return
		switch type {
		case "v":
			v := parse_vertex(line) or_return
			append(&verts, v)
		case "vn":
			vn := parse_normal(line) or_return
			append(&norms, vn)
		case "f":
			f := parse_face(line) or_return
			append(&faces, f)
		case:
			continue
		}
	}

	ok = true
	mesh.verts = slice.clone(verts[:])
	mesh.norms = slice.clone(norms[:])
	mesh.faces = slice.clone(faces[:])

	return

	parse_vertex :: proc(line: string) -> (vec: Vec3, ok: bool = false) {
		// x y z [w or 1.0]
		line := line
		x := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		y := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		z := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		w := strconv.parse_f32(strings.fields_iterator(&line) or_else "1.0") or_return
		if len(line) > 0 do return

		ok = true
		vec = Vec3{x, y, z} / w
		return
	}

	parse_normal :: proc(line: string) -> (vec: Vec3, ok: bool = false) {
		// x y z
		line := line
		x := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		y := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		z := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		if len(line) > 0 do return

		ok = true
		vec = Vec3{x, y, z}
		return
	}

	parse_face :: proc(line: string) -> (face: Face, ok: bool = false) {
		// 3 elems each made of 3 indices: vertex / texture / normal
		line := line
		e1 := strings.fields_iterator(&line) or_return
		e2 := strings.fields_iterator(&line) or_return
		e3 := strings.fields_iterator(&line) or_return
		if len(line) > 0 do return // we only support triangles right now

		verts: [3]u32
		norms: [3]u32

		es := [?]string{e1, e2, e3}
		for &e, i in es {
			vert := strings.split_iterator(&e, "/") or_return // we always need a vert
			text, has_text := strings.split_iterator(&e, "/") // returns ok = false when empty string
			norm, has_norm := strings.split_iterator(&e, "/")
			if len(e) > 0 do return

			verts[i] = u32(strconv.parse_uint(vert, 10) or_return)
			// if len(text) > 0 do return // we do not support textures yet
			if has_norm do norms[i] = u32(strconv.parse_uint(norm, 10) or_return)
		}

		ok = true
		face = Face{verts, norms}
		return
	}
}

mesh_delete :: proc(mesh: Mesh) {
	delete(mesh.verts)
	delete(mesh.norms)
	delete(mesh.faces)
}

@(test)
test_mesh_parsing :: proc(t: ^testing.T) {
	mesh_data := `
		# this is a comment
		v 1.2 2.3 3.4
		v 2 4 6 2
		v 3 3 3

		# now some norms
		vn -1 0 1
		vn 0 1 0
		vn 3 3 2

		# faces
		f 1 2 3
		f 3/2/12 2/3/42 1/17/38
	`

	m, ok := mesh_load(mesh_data)
	defer if ok do mesh_delete(m)
	testing.expect(t, ok, "parsing mesh returned failure")

	testing.expect_value(t, Vec3{1.2, 2.3, 3.4}, m.verts[0])
	testing.expect_value(t, Vec3{-1, 0, 1}, m.norms[0])
	testing.expect_value(t, [3]u32{1, 2, 3}, m.faces[0].verts)
	testing.expect_value(t, [3]u32{0, 0, 0}, m.faces[0].norms)
	testing.expect_value(t, [3]u32{3, 2, 1}, m.faces[1].verts)
	testing.expect_value(t, [3]u32{12, 42, 38}, m.faces[1].norms)
}
