package main

Material :: struct {
	kind:   enum {
		Lambertian,
		Metal,
	},
	albedo: Color,
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
	switch mat.kind {
	case .Lambertian:
		return scatter_lambertian(ray, rec, mat)
	case .Metal:
		return scatter_metal(ray, rec, mat)
	}
	return
}

scatter_lambertian :: proc(
	ray: Ray,
	rec: Hit_Record,
	mat: Material,
) -> (
	scattered: Ray,
	attenuation: Color,
	hit: bool = false,
) {
	when ODIN_DEBUG {assert(mat.kind == .Lambertian)}

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
	mat: Material,
) -> (
	scattered: Ray,
	attenuation: Color,
	hit: bool = false,
) {
	when ODIN_DEBUG {assert(mat.kind == .Metal)}

	reflected := vec3_reflect(ray.direction, rec.normal)
	scattered = Ray{rec.point, reflected}
	attenuation = mat.albedo
	hit = true
	return
}
