extends RefCounted
## Shared rounded-edge box meshes. A 3-by-3 grid on six faces gives 108 triangles.
## Dimensions include the bevel. Central faces stay perfectly flat.

static var _box_cache: Dictionary = {}

static func clear_cache() -> void:
	_box_cache.clear()

static func beveled_box(size: Vector3, bevel: float = 0.025) -> ArrayMesh:
	var dimensions := Vector3(maxf(absf(size.x), 0.001), maxf(absf(size.y), 0.001), maxf(absf(size.z), 0.001))
	var radius := clampf(bevel, 0.0001, minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.25)
	var cache_key := "%0.5f,%0.5f,%0.5f:%0.5f" % [dimensions.x, dimensions.y, dimensions.z, radius]
	if _box_cache.has(cache_key):
		return _box_cache[cache_key]
	var half := dimensions * 0.5
	var core := half - Vector3.ONE * radius
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each tangent cross bitangent points outward. Triangles reverse that order
	# because Godot uses clockwise front faces.
	var bases: Array = [
		[Vector3.RIGHT, Vector3.BACK, Vector3.DOWN],
		[Vector3.LEFT, Vector3.FORWARD, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	for face in bases:
		var normal: Vector3 = face[0]
		var tangent: Vector3 = face[1]
		var bitangent: Vector3 = face[2]
		var tangent_half := half.dot(tangent.abs())
		var bitangent_half := half.dot(bitangent.abs())
		var tangent_steps := PackedFloat32Array([-tangent_half, -tangent_half + radius, tangent_half - radius, tangent_half])
		var bitangent_steps := PackedFloat32Array([-bitangent_half, -bitangent_half + radius, bitangent_half - radius, bitangent_half])
		var center := normal * half.dot(normal.abs())
		for y in range(3):
			for x in range(3):
				var coordinates: Array[Vector2i] = [Vector2i(x, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1), Vector2i(x, y), Vector2i(x + 1, y + 1), Vector2i(x + 1, y)]
				for coordinate in coordinates:
					var u := tangent_steps[coordinate.x]
					var v := bitangent_steps[coordinate.y]
					var point := center + tangent * u + bitangent * v
					var nearest := point.clamp(-core, core)
					var smooth_normal := (point - nearest).normalized()
					builder.set_normal(smooth_normal)
					builder.set_uv(Vector2(u / (2.0 * tangent_half) + 0.5, 0.5 - v / (2.0 * bitangent_half)))
					builder.add_vertex(nearest + smooth_normal * radius)
	builder.index()
	var mesh := builder.commit()
	mesh.resource_name = "BeveledBox_%s" % cache_key
	_box_cache[cache_key] = mesh
	return mesh
