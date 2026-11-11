extends RefCounted
## Original, texture-free surface library. All dimensions are in metres.

const METAL_SHADER = preload("res://shaders/aged_metal.gdshader")
const CRT_SHADER = preload("res://shaders/crt.gdshader")

static func metal(base: Color, wear: Color, metallic: float, roughness: float, weathering: float = 0.35) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = METAL_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("wear_color", wear)
	material.set_shader_parameter("metallic_amount", metallic)
	material.set_shader_parameter("roughness_amount", roughness)
	material.set_shader_parameter("weathering", weathering)
	return material

static func solid(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

static func luminous(color: Color, energy: float = 2.2) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

static func build() -> Dictionary:
	var materials: Dictionary = {}
	materials["iron"] = metal(Color(0.15, 0.22, 0.23), Color(0.35, 0.38, 0.35), 0.64, 0.67, 0.5)
	materials["steel"] = metal(Color(0.26, 0.29, 0.29), Color(0.46, 0.47, 0.43), 0.8, 0.52, 0.35)
	materials["brass"] = metal(Color(0.47, 0.32, 0.13), Color(0.64, 0.48, 0.23), 0.82, 0.4, 0.4)
	materials["copper"] = metal(Color(0.40, 0.18, 0.085), Color(0.58, 0.30, 0.14), 0.78, 0.43, 0.43)
	materials["dark"] = metal(Color(0.075, 0.09, 0.095), Color(0.24, 0.26, 0.25), 0.56, 0.72, 0.38)
	materials["rubber"] = solid(Color(0.025, 0.032, 0.034), 0.03, 0.93)
	materials["red"] = metal(Color(0.31, 0.065, 0.033), Color(0.39, 0.29, 0.2), 0.35, 0.63, 0.48)
	materials["paint"] = metal(Color(0.54, 0.53, 0.42), Color(0.32, 0.33, 0.30), 0.18, 0.77, 0.48)
	materials["wall"] = materials["iron"]
	materials["ceiling"] = metal(Color(0.095, 0.125, 0.13), Color(0.25, 0.27, 0.26), 0.45, 0.76, 0.4)
	var floor_material := metal(Color(0.22, 0.245, 0.24), Color(0.43, 0.45, 0.41), 0.72, 0.6, 0.6)
	floor_material.set_shader_parameter("tread_plate", true)
	floor_material.set_shader_parameter("bump_strength", 0.5)
	materials["floor"] = floor_material
	var warning_material := metal(Color(0.6, 0.39, 0.12), Color(0.36, 0.35, 0.29), 0.28, 0.66, 0.7)
	warning_material.set_shader_parameter("hazard_stripe", true)
	materials["warning"] = warning_material
	materials["glow_amber"] = luminous(Color(1.0, 0.48, 0.13), 2.8)
	materials["glow_cyan"] = luminous(Color(0.38, 0.79, 0.76), 1.8)
	materials["glow_red"] = luminous(Color(1.0, 0.075, 0.025), 2.0)
	materials["glow_white"] = luminous(Color(0.83, 0.85, 0.70), 1.5)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.15, 0.16, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.35
	glass.roughness = 0.12
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["glass"] = glass
	var screen := ShaderMaterial.new()
	screen.shader = CRT_SHADER
	materials["screen"] = screen
	materials["wood"] = metal(Color(0.18, 0.12, 0.075), Color(0.29, 0.22, 0.14), 0.0, 0.92, 0.5)
	return materials
