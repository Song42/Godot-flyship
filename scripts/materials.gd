extends RefCounted
## Original, texture-free surface library. All dimensions are in metres.

const METAL_SHADER = preload("res://shaders/aged_metal.gdshader")
const CRT_SHADER = preload("res://shaders/crt.gdshader")
const WOOD_SHADER = preload("res://shaders/wood.gdshader")

static func metal(base: Color, wear: Color, metallic: float, roughness: float, weathering: float = 0.35) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = METAL_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("wear_color", wear)
	material.set_shader_parameter("metallic_amount", minf(metallic, 0.5))
	material.set_shader_parameter("roughness_amount", maxf(roughness, 0.78))
	material.set_shader_parameter("weathering", weathering)
	return material

static func solid(color: Color, metallic: float = 0.0, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.metallic_specular = 0.16
	return material

static func luminous(color: Color, energy: float = 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.95
	material.metallic_specular = 0.0
	return material

static func timber(base: Color, grain: Color, planked: bool = false, width: float = 0.18, length_m: float = 1.75) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("grain_color", grain)
	material.set_shader_parameter("planked", planked)
	material.set_shader_parameter("plank_width", width)
	material.set_shader_parameter("plank_length", length_m)
	return material

static func build() -> Dictionary:
	var materials: Dictionary = {}
	materials["iron"] = metal(Color(0.18, 0.17, 0.145), Color(0.28, 0.26, 0.21), 0.3, 0.89, 0.45)
	materials["steel"] = metal(Color(0.29, 0.28, 0.25), Color(0.39, 0.37, 0.31), 0.38, 0.84, 0.35)
	materials["brass"] = metal(Color(0.39, 0.29, 0.16), Color(0.48, 0.37, 0.21), 0.45, 0.82, 0.4)
	materials["copper"] = metal(Color(0.34, 0.21, 0.13), Color(0.43, 0.29, 0.18), 0.42, 0.84, 0.43)
	materials["dark"] = metal(Color(0.085, 0.078, 0.064), Color(0.19, 0.17, 0.14), 0.2, 0.93, 0.38)
	materials["rubber"] = solid(Color(0.038, 0.033, 0.028), 0.0, 0.98)
	materials["red"] = metal(Color(0.27, 0.11, 0.075), Color(0.32, 0.24, 0.17), 0.2, 0.88, 0.45)
	materials["paint"] = metal(Color(0.48, 0.43, 0.32), Color(0.29, 0.25, 0.19), 0.12, 0.92, 0.4)
	materials["wood"] = timber(Color(0.31, 0.195, 0.105), Color(0.15, 0.08, 0.035))
	materials["wood_dark"] = timber(Color(0.18, 0.105, 0.055), Color(0.085, 0.043, 0.02))
	materials["wood_light"] = timber(Color(0.43, 0.31, 0.185), Color(0.25, 0.16, 0.08))
	materials["floor"] = timber(Color(0.31, 0.205, 0.12), Color(0.17, 0.095, 0.045), true, 0.18, 1.75)
	materials["wall"] = timber(Color(0.35, 0.235, 0.135), Color(0.19, 0.11, 0.055), true, 0.23, 1.9)
	materials["ceiling"] = timber(Color(0.24, 0.16, 0.09), Color(0.13, 0.075, 0.035), true, 0.24, 1.8)
	materials["cloth"] = solid(Color(0.22, 0.19, 0.135), 0.0, 0.98)
	materials["canvas"] = solid(Color(0.46, 0.405, 0.3), 0.0, 0.98)
	materials["leather"] = solid(Color(0.17, 0.085, 0.048), 0.0, 0.93)
	materials["paper"] = solid(Color(0.66, 0.58, 0.43), 0.0, 0.99)
	materials["ceramic"] = solid(Color(0.54, 0.50, 0.39), 0.0, 0.87)
	materials["rope"] = solid(Color(0.37, 0.28, 0.17), 0.0, 1.0)
	var warning_material := metal(Color(0.39, 0.29, 0.14), Color(0.30, 0.26, 0.19), 0.2, 0.89, 0.7)
	warning_material.set_shader_parameter("hazard_stripe", true)
	materials["warning"] = warning_material
	materials["glow_amber"] = luminous(Color(0.80, 0.47, 0.21), 0.65)
	materials["glow_cyan"] = luminous(Color(0.45, 0.55, 0.42), 0.38)
	materials["glow_red"] = luminous(Color(0.45, 0.10, 0.055), 0.45)
	materials["glow_white"] = luminous(Color(0.64, 0.54, 0.39), 0.5)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.13, 0.12, 0.095, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.0
	glass.metallic_specular = 0.12
	glass.roughness = 0.55
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["glass"] = glass
	var screen := ShaderMaterial.new()
	screen.shader = CRT_SHADER
	screen.set_shader_parameter("phosphor", Color(0.72, 0.49, 0.24))
	screen.set_shader_parameter("intensity", 0.42)
	materials["screen"] = screen
	return materials
