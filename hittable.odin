package main

import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:testing"

Hittable :: struct {
	obj: Object,
	mat: ^Material,
}

Object :: union {
	Sphere,
	Mesh,
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
ray_hit_any :: proc(ray: Ray, interval: Interval, world: []Hittable) -> Maybe(Hit_Record) {
	maybe_hit: Maybe(Hit_Record)

	closest_so_far := interval.max
	for obj in world {
		hit := ray_hit(ray, Interval{interval.min, closest_so_far}, obj).? or_continue
		closest_so_far = hit.t
		maybe_hit = hit
	}

	return maybe_hit
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
	rec.point = ray_at(ray, root)
	rec.mat = mat

	outward_normal := (rec.point - sphere.center) / sphere.radius
	rec.front_face = dot(ray.direction, outward_normal) < 0
	rec.normal = outward_normal if rec.front_face else -outward_normal

	return rec
}

Mesh :: struct {
	transformation: matrix[4, 4]f32,
	verts:          []Vec3,
	norms:          []Vec3,
	faces:          []Face,
}

Face :: struct {
	verts: [3]u32,
	norms: [3]u32,
}

@(require_results)
face_flat_normal :: proc(face: Face, vert_array: []Vec3) -> Vec3 {
	e1 := vert_array[face.verts[1]] - vert_array[face.verts[0]]
	e2 := vert_array[face.verts[2]] - vert_array[face.verts[0]]
	return normalize(cross(e1, e2))
}

@(require_results)
ray_mesh_hit :: proc(
	ray: Ray,
	interval: Interval,
	mesh: Mesh,
	mat: ^Material,
) -> Maybe(Hit_Record) {
	maybe_hit: Maybe(Hit_Record)

	closest_so_far := interval.max
	for face in mesh.faces {
		hit := ray_triangle_hit(
			ray,
			Interval{interval.min, closest_so_far},
			mesh,
			mat,
			face,
		).? or_continue

		closest_so_far = hit.t
		maybe_hit = hit
	}

	return maybe_hit

	// Möller–Trumbore intersection algorithm
	// https://en.wikipedia.org/wiki/M%C3%B6ller%E2%80%93Trumbore_intersection_algorithm
	ray_triangle_hit :: #force_inline proc(
		ray: Ray,
		interval: Interval,
		mesh: Mesh,
		mat: ^Material,
		face: Face,
	) -> Maybe(Hit_Record) {
		inverse_transformation := linalg.inverse(mesh.transformation)
		local_ray := Ray {
			vec3_transform(ray.origin, 1, inverse_transformation),
			vec3_transform(ray.direction, 0, inverse_transformation),
		}

		v1 := mesh.verts[face.verts[0]]
		v2 := mesh.verts[face.verts[1]]
		v3 := mesh.verts[face.verts[2]]

		e1 := v2 - v1
		e2 := v3 - v1

		// backface culling, assumes CCW-wound triangles
		// if dot(cross(e1, e2), local_ray.direction) > 0 do return nil

		ray_cross_e2 := cross(local_ray.direction, e2)
		det := dot(e1, ray_cross_e2)

		// ray is parallel to triangle
		if abs(det) < math.F32_EPSILON do return nil

		inv_det := 1.0 / det
		s := local_ray.origin - v1
		u := inv_det * dot(s, ray_cross_e2)

		// ray passes outside e2's bounds
		if u < -math.F32_EPSILON || u - 1 > math.F32_EPSILON do return nil

		s_cross_e1 := cross(s, e1)
		v := inv_det * dot(local_ray.direction, s_cross_e1)

		// ray passes outside e1's bounds
		if v < -math.F32_EPSILON || u + v - 1 > math.F32_EPSILON do return nil

		// the ray intersects with the triangle, compute t to find where on the ray
		t := inv_det * dot(e2, s_cross_e1)
		if t <= math.F32_EPSILON do return nil // edge case, there was a line intersection but not a ray intersection

		if !interval_surrounds(interval, t) do return nil // hit is outside interval

		rec: Hit_Record
		rec.point = ray_at(ray, t)
		rec.t = t
		rec.mat = mat

		normal := normalize(
			vec3_transform(
				face_flat_normal(face, mesh.verts),
				0,
				linalg.transpose(inverse_transformation),
			),
		)

		rec.front_face = dot(ray.direction, normal) < 0
		rec.normal = normal if rec.front_face else -normal

		return rec
	}
}

@(require_results)
mesh_load_from_file :: proc(filepath: string) -> (mesh: Mesh, ok: bool = false) {
	data, err := os.read_entire_file_from_path(filepath, context.allocator)
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

	str := data
	for line in strings.split_lines_iterator(&str) {
		line := strings.trim_space(line)
		if len(line) == 0 || line[0] == '#' do continue

		type := strings.fields_iterator(&line) or_return
		switch type {
		case "v":
			v := #force_inline parse_vertex(line) or_return
			append(&verts, v)
		case "vn":
			vn := #force_inline parse_normal(line) or_return
			append(&norms, vn)
		case "f":
			f := #force_inline parse_face(line) or_return
			append(&faces, f)
		case:
			continue
		}
	}

	ok = true
	mesh.verts = slice.clone(verts[:])
	mesh.norms = slice.clone(norms[:])
	mesh.faces = slice.clone(faces[:])
	mesh.transformation = transformation_matrix()

	return

	parse_vertex :: proc(line: string) -> (vec: Vec3, ok: bool = false) {
		// x y z [w or 1.0]
		line := line
		x := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		y := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		z := strconv.parse_f32(strings.fields_iterator(&line) or_return) or_return
		w: f32 = 1

		w_str := strings.fields_iterator(&line) or_else "1.0"
		if w_str[0] != '#' do w = strconv.parse_f32(w_str) or_return
		// if have_non_comment(&line) do return

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
		if have_non_comment(&line) do return

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
		if have_non_comment(&line) do return

		verts: [3]u32
		norms: [3]u32

		es := [?]string{e1, e2, e3}
		for &e, i in es {
			vert := strings.split_iterator(&e, "/") or_return // we always need a vert
			text, has_text := strings.split_iterator(&e, "/") // returns ok = false when empty string
			norm, has_norm := strings.split_iterator(&e, "/")
			if have_non_comment(&e) do return

			// indices are 1-based so subtract 1
			verts[i] = u32(strconv.parse_uint(vert, 10) or_return) - 1
			// if has_text do stuff // we do not support textures yet
			if has_norm do norms[i] = u32(strconv.parse_uint(norm, 10) or_return) - 1
		}

		ok = true
		face = Face{verts, norms}
		return
	}

	have_non_comment :: proc(s: ^string) -> bool {
		if last, have_more := strings.fields_iterator(s); have_more do return last[0] != '#'
		return false
	}
}

mesh_delete :: proc(mesh: Mesh) {
	delete(mesh.verts)
	delete(mesh.norms)
	delete(mesh.faces)
}

world_delete :: proc(world: []Hittable) {
	for item in world do if m, ok := item.obj.(Mesh); ok do mesh_delete(m)
}

@(test)
test_mesh_parsing :: proc(t: ^testing.T) {
	mesh_data := `
		# this is a comment
		v 1.2 2.3 3.4
		v 2 4 6 2 # inline comment
		v 3 3 3 # one here too

		# now some norms
		vn -1 0 1
		vn 0 1 0
		vn 3 3 2 # another inline comment for fun

		# faces
		f 1 2 3 # one more here
		f 3/2/12 2/3/42 1/17/38
	`

	m, ok := mesh_load(mesh_data)
	defer if ok do mesh_delete(m)
	testing.expect(t, ok, "parsing mesh returned failure")

	testing.expect_value(t, Vec3{1.2, 2.3, 3.4}, m.verts[0])
	testing.expect_value(t, Vec3{-1, 0, 1}, m.norms[0])
	testing.expect_value(t, [3]u32{0, 1, 2}, m.faces[0].verts)
	testing.expect_value(t, [3]u32{0, 0, 0}, m.faces[0].norms)
	testing.expect_value(t, [3]u32{2, 1, 0}, m.faces[1].verts)
	testing.expect_value(t, [3]u32{11, 41, 37}, m.faces[1].norms)
}
