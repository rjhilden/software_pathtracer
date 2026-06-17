package main

import "core:math"

Object :: union {
	Sphere,
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
	mat:        Material,
}

ray_hit :: proc(ray: Ray, interval: Interval, hittable: Hittable) -> Maybe(Hit_Record) {
	switch obj in hittable.obj {
	case Sphere:
		return ray_sphere_hit(ray, interval, obj, hittable.mat^)
	case:
		return nil
	}
}

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

ray_sphere_hit :: proc(
	ray: Ray,
	interval: Interval,
	sphere: Sphere,
	mat: Material,
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
