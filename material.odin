package main

import "core:math"
import "core:math/rand"

Lambertian :: struct {
	albedo: Color,
}

Metal :: struct {
	albedo: Color,
	fuzz:   f32,
}

Dielectric :: struct {
	refractive_index: f32,
}

Material :: union {
	Lambertian,
	Metal,
	Dielectric,
}

scatter :: proc(
	ray: Ray,
	rec: Hit_Record,
	mat: Material,
) -> (
	scattered: Ray,
	attenuation: Color,
	hit: bool = false,
) {
	switch m in mat {
	case Lambertian:
		return scatter_lambertian(ray, rec, m)
	case Metal:
		return scatter_metal(ray, rec, m)
	case Dielectric:
		return scatter_dielectric(ray, rec, m)
	}
	return
}

scatter_lambertian :: proc(
	ray: Ray,
	rec: Hit_Record,
	mat: Lambertian,
) -> (
	scattered: Ray,
	attenuation: Color,
	hit: bool = false,
) {
	scatter_direction := rec.normal + vec3_random_unit()
	if vec3_near_zero(scatter_direction) do scatter_direction = rec.normal

	scattered = Ray{rec.point, scatter_direction}
	attenuation = mat.albedo
	hit = true
	return
}

scatter_metal :: proc(
	ray: Ray,
	rec: Hit_Record,
	mat: Metal,
) -> (
	scattered: Ray,
	attenuation: Color,
	hit: bool = false,
) {
	reflected :=
		normalize(vec3_reflect(ray.direction, rec.normal)) + (mat.fuzz * vec3_random_unit())

	scattered = Ray{rec.point, reflected}
	attenuation = mat.albedo
	hit = true
	return
}

scatter_dielectric :: proc(
	ray: Ray,
	rec: Hit_Record,
	mat: Dielectric,
) -> (
	scattered: Ray,
	attenuation: Color,
	hit: bool = false,
) {
	refract_ratio := 1.0 / mat.refractive_index if rec.front_face else mat.refractive_index

	unit_direction := normalize(ray.direction)
	cos_theta := math.min(1.0, dot(-unit_direction, rec.normal))
	sin_theta := math.sqrt(1.0 - cos_theta * cos_theta)

	direction := Vec3{}
	if refract_ratio * sin_theta > 1.0 || reflectance(cos_theta, refract_ratio) > rand.float32() {
		// must reflect: total internal reflection
		direction = vec3_reflect(unit_direction, rec.normal)
	} else {
		// can refract
		direction = vec3_refract(unit_direction, rec.normal, refract_ratio)
	}

	scattered = Ray{rec.point, direction}
	attenuation = Color{1, 1, 1}
	hit = true
	return

	@(require_results)
	reflectance :: proc(cosine, refractive_index: f32) -> f32 {
		// Schlick's approximation
		r0 := (1 - refractive_index) / (1 + refractive_index)
		r0 = r0 * r0
		return r0 + (1 - r0) * math.pow(1 - cosine, 5)
	}
}
