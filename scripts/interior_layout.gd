extends RefCounted
## Compact naval interior. Central corridor and exterior decks are built by world.
## Shared partitions are built once to avoid overlapping surfaces.

static func build(w: Node3D) -> void:
	_bridge_and_chartroom(w)
	_crew_and_captain(w)
	_mess_and_galley(w)
	_engine_and_shop(w)
	_cargo(w)

static func _bridge_and_chartroom(w: Node3D) -> void:
	var rect := Rect2(-3.4, -23, 6.8, 11)
	w._floor(rect)
	w._roof(rect, 2.85)
	for x in [-3.4, 3.4]:
		w._wall_x(x, -23, -12, 2.85, [w._opening(-15.0)])
		w._door(Vector3(x, 0, -15), "DECK", "PORT WALK" if x < 0 else "STARBOARD WALK", true)
	w._wall_z(-12, -3.4, 3.4, 2.85, [Vector2(-0.9, 0.9)])
	w._wall_z(-18, -3.4, 3.4, 2.85, [Vector2(-0.85, 0.85)])
	# Forward mullioned windows frame an empty black night. A centre door
	# connects directly to the bow deck without crossing the helm station.
	for side in [-1.0, 1.0]:
		w._box("Forward outer post", Vector3(side * 3.2, 1.43, -23), Vector3(0.4, 2.85, 0.22), "wood_dark")
		w._box("Forward inner post", Vector3(side * 0.8, 1.43, -23), Vector3(0.16, 2.85, 0.22), "wood_dark")
		w._window(Vector3(side * 1.94, 1.73, -23), Vector2(2.12, 1.6), 0.0)
	w._box("Forward lintel", Vector3(0, 2.69, -23), Vector3(6.8, 0.32, 0.22), "wood_dark")
	w._box("Bow hatch transom", Vector3(0, 2.4, -23), Vector3(1.44, 0.58, 0.2), "wood_dark")
	w._door(Vector3(0, 0, -23), "BOW", "FOREDECK", false)
	for x in [-1.95, 1.95]:
		var console: Node3D = w.kit.make_console(w, Vector3(x, 0, -21.5), PI)
		console.scale = Vector3.ONE * 0.67
	_helm(w, Vector3(-1.05, 0, -20.2))
	w.furniture.chair(w, Vector3(-1.05, 0, -19.25))
	w._lantern(Vector3(-2.85, 2.26, -20.2), 0.85, 4.0)
	w._lantern(Vector3(2.85, 2.26, -20.2), 0.85, 4.0)
	w._sign("H A R T W E L L   /   N O C T U R N E", Vector3(0, 2.52, -22.82), 0.0, 23, 0.0038)
	w.furniture.desk(w, Vector3(-2.4, 0, -16.8), -PI / 2.0)
	w.furniture.bookshelf(w, Vector3(-2.92, 0, -13.3), -PI / 2.0)
	w.furniture.locker(w, Vector3(2.88, 0, -13.4), PI / 2.0)
	w.furniture.table(w, Vector3(2.35, 0, -16.6), Vector2(1.2, 1.5), 0.0, false)
	w._box("Folded navigation chart", Vector3(2.35, 0.79, -16.6), Vector3(0.95, 0.012, 1.2), "paper", false)
	for x in [2.0, 2.2, 2.4, 2.6]:
		w._box("Chart meridian", Vector3(x, 0.801, -16.6), Vector3(0.003, 0.002, 1.0), "wood_dark", false)
	for z in [-16.9, -16.6, -16.3]:
		w._box("Chart parallel", Vector3(2.35, 0.802, z), Vector3(0.8, 0.002, 0.003), "wood_dark", false)
	w._lantern(Vector3(-2.8, 2.25, -15.4), 0.8, 4.1)
	w._lantern(Vector3(2.8, 2.25, -16.8), 0.65, 3.8)
	w._sign("CHART ROOM", Vector3(-1.9, 2.25, -17.87), 0.0, 27, 0.004)
	w._note(Vector3(-1.99, 1.09, -16.8), "CHARTMASTER'S JOURNAL\n\nWe made no landfall tonight.\nThe barometer is steady; the compass is not.\n\nKeep the bow lantern burning.", PI / 2.0)

static func _helm(w: Node3D, pos: Vector3) -> void:
	w._box("Helm oak pedestal", pos + Vector3(0, 0.58, 0.05), Vector3(0.32, 1.16, 0.34), "wood_dark")
	w._box("Helm pedestal foot", pos + Vector3(0, 0.07, 0.05), Vector3(0.56, 0.14, 0.55), "wood")
	var center := pos + Vector3(0, 1.32, -0.06)
	w._ring(center, 0.43, 0.035, "wood_light", PI / 2.0)
	w._ring(center, 0.39, 0.009, "brass", PI / 2.0)
	w._pipe(center + Vector3(0, 0, -0.09), center + Vector3(0, 0, 0.15), 0.075, "brass")
	for i in range(8):
		var angle: float = float(i) * TAU / 8.0
		var direction := Vector3(cos(angle), sin(angle), 0)
		w._pipe(center + direction * 0.07, center + direction * 0.5, 0.021, "wood")
		w._pipe(center + direction * 0.42, center + direction * 0.55, 0.03, "wood_light")

static func _crew_and_captain(w: Node3D) -> void:
	var rect := Rect2(-5.6, -12, 4.7, 15)
	w._floor(rect)
	w._roof(rect, 2.75)
	w._window_wall_x(-5.6, -12, 3, [-10.0, -6.0, 0.0], 2.75)
	for z in [-12.0, -8.0, -4.0]:
		w._wall_z(z, -5.6, -0.9, 2.75)
	for center in [-10.0, -6.0]:
		for side in [-1.0, 1.0]:
			w.furniture.bed(w, Vector3(-3.5, 0, center + side * 1.25), PI / 2.0)
			w.furniture.locker(w, Vector3(-1.55, 0, center + side * 1.15), PI / 2.0)
		w._lantern(Vector3(-2.5, 2.25, center), 0.65, 3.8)
		w._lantern(Vector3(-5.3, 2.18, center + 0.65), 0.45, 2.8)
		w._sign("CREW BERTHS   /   " + ("I" if center < -8 else "II"), Vector3(-3.4, 2.44, center - 1.82), 0.0, 22, 0.0035)
	w._note(Vector3(-2.6, 1.25, -4.16), "BERTH FOUR\n\nMarlow says he heard footsteps outside the hull.\nThere was nobody on the starboard walk.\n\nI have pulled the curtains.", PI)
	_captains_bed(w, Vector3(-4.1, 0, 1.2))
	w.furniture.desk(w, Vector3(-3.8, 0, -3.4), PI)
	w.furniture.chair(w, Vector3(-3.8, 0, -2.45))
	w.furniture.bookshelf(w, Vector3(-5.15, 0, -1.4), -PI / 2.0)
	w.furniture.locker(w, Vector3(-1.5, 0, 2.25), PI / 2.0)
	w._lantern(Vector3(-4.65, 2.22, -2.6), 0.72, 3.8)
	w._lantern(Vector3(-2.1, 2.22, 1.55), 0.6, 3.7)
	w._note(Vector3(-3.8, 1.03, -3.17), "CAPTAIN'S PRIVATE LOG\n\nThe watch has been relieved.\nThe engines will remain at half pressure until dawn.\n\nIt has been night for thirty-six hours.")

static func _captains_bed(w: Node3D, pos: Vector3) -> void:
	w._box("Captain berth frame", pos + Vector3(0, 0.34, 0), Vector3(1.65, 0.24, 2.3), "wood_dark")
	w._box("Captain mattress", pos + Vector3(0, 0.55, 0), Vector3(1.52, 0.2, 2.15), "canvas")
	w._box("Captain quilt", pos + Vector3(0, 0.68, -0.27), Vector3(1.56, 0.07, 1.58), "cloth", false)
	for x in [-0.4, 0.4]:
		w._box("Linen pillow", pos + Vector3(x, 0.72, 0.74), Vector3(0.62, 0.15, 0.39), "canvas", false)
	for x in [-0.8, 0.8]:
		for z in [-1.12, 1.12]:
			w._box("Canopy carved post", pos + Vector3(x, 1.17, z), Vector3(0.065, 2.34, 0.065), "wood_dark")
		w._box("Canopy side rail", pos + Vector3(x, 2.31, 0), Vector3(0.09, 0.09, 2.32), "wood")
	w._box("Canopy headboard", pos + Vector3(0, 0.83, 1.12), Vector3(1.65, 0.81, 0.07), "wood")
	for z in [-1.12, 1.12]:
		w._box("Canopy end rail", pos + Vector3(0, 2.31, z), Vector3(1.67, 0.1, 0.09), "wood")
	w._box("Canopy drape", pos + Vector3(0, 2.29, 0), Vector3(1.57, 0.025, 2.19), "cloth", false)
	w._box("Canopy tied curtain", pos + Vector3(-0.77, 1.62, 0.8), Vector3(0.045, 1.32, 0.5), "cloth", false)
	for z in [-0.9, -0.74]:
		w._box("Quilt stitched band", pos + Vector3(0, 0.721, z), Vector3(1.55, 0.008, 0.018), "canvas", false)

static func _mess_and_galley(w: Node3D) -> void:
	var rect := Rect2(0.9, -12, 4.9, 18)
	w._floor(rect)
	w._roof(rect, 2.85)
	w._window_wall_x(5.8, -12, 6, [-10.5, -5.0, 0.0, 4.3], 2.85, [w._opening(-8.0)])
	w._door(Vector3(5.8, 0, -8), "WALK", "STARBOARD WALK", true)
	w._wall_z(-12, 0.9, 5.8, 2.85)
	w._wall_z(-3, 0.9, 5.8, 2.85, [Vector2(2.5, 3.9)])
	w._wall_z(6, 0.9, 5.8, 2.85)
	w.furniture.table(w, Vector3(3.25, 0, -7.2), Vector2(1.2, 3.8))
	for z in [-8.65, -7.2, -5.75]:
		w.furniture.chair(w, Vector3(2.15, 0, z), -PI / 2.0)
		w.furniture.chair(w, Vector3(4.35, 0, z), PI / 2.0)
	w.furniture.bookshelf(w, Vector3(1.25, 0, -10.8), -PI / 2.0)
	w._lantern(Vector3(3.25, 2.38, -9.5), 0.8, 4.0)
	w._lantern(Vector3(3.25, 2.38, -4.6), 0.75, 4.0)
	w._sign("OFFICERS & CREW MESS", Vector3(3.35, 2.3, -11.85), 0.0, 27, 0.004)
	w._note(Vector3(3.5, 1.4, -11.82), "MESS NOTICE\n\nSupper is served at eight bells.\nLeave the last place at the table empty.\n\nThe captain's orders.")
	for z in [-1.7, 0.0, 3.7, 5.1]:
		_galley_counter(w, Vector3(5.25, 0, z))
		w._box("Galley wall shelf", Vector3(5.57, 2.35, z), Vector3(0.43, 0.055, 1.05), "wood_dark", false)
		for dz in [-0.3, 0.0, 0.3]:
			w._box("Galley storage tin", Vector3(5.55, 2.49, z + dz), Vector3(0.16, 0.23, 0.16), "ceramic", false)
	w.furniture.stove(w, Vector3(4.95, 0, 2)).rotation.y = PI / 2.0
	w.furniture.bookshelf(w, Vector3(1.3, 0, -1.4), -PI / 2.0)
	w.furniture.bookshelf(w, Vector3(1.3, 0, 4.7), -PI / 2.0)
	w.furniture.barrel(w, Vector3(1.5, 0, 0.3))
	w.furniture.barrel(w, Vector3(2.0, 0, 5.4))
	w._pipe(Vector3(5.5, 2.4, -2.8), Vector3(5.5, 2.4, 5.7), 0.035, "copper")
	w._lantern(Vector3(3.4, 2.35, -0.6), 0.7, 4.0)
	w._lantern(Vector3(3.4, 2.35, 4.1), 0.7, 4.0)
	w._sign("GALLEY", Vector3(4.65, 2.36, -2.85), 0.0, 25, 0.004)

static func _galley_counter(w: Node3D, pos: Vector3) -> void:
	w._box("Galley oak cupboard", pos + Vector3(0, 0.41, 0), Vector3(0.6, 0.82, 1.2), "wood_dark")
	w._box("Galley scrubbed worktop", pos + Vector3(0, 0.86, 0), Vector3(0.66, 0.08, 1.26), "wood_light")
	for z in [-0.29, 0.29]:
		w._box("Galley cupboard door", pos + Vector3(-0.316, 0.43, z), Vector3(0.035, 0.65, 0.53), "wood")
		w._box("Cupboard brass pull", pos + Vector3(-0.35, 0.49, z * 0.28), Vector3(0.035, 0.08, 0.025), "brass", false)
	w._box("Chopping board", pos + Vector3(-0.03, 0.915, -0.21), Vector3(0.3, 0.022, 0.39), "wood", false)
	w._box("Galley knife", pos + Vector3(-0.04, 0.93, -0.21), Vector3(0.025, 0.009, 0.22), "iron", false)
	w._box("Knife wooden handle", pos + Vector3(-0.04, 0.937, -0.34), Vector3(0.034, 0.02, 0.09), "wood_dark", false)
	w.furniture._mug(w, pos + Vector3(0.02, 0.905, 0.31))

static func _engine_and_shop(w: Node3D) -> void:
	var engine_rect := Rect2(-6, 3, 5.1, 9)
	w._floor(engine_rect)
	w._roof(engine_rect, 3.45)
	w._wall_x(-6, 3, 12, 3.45)
	w._wall_z(3, -6, -0.9, 3.45)
	w._wall_z(12, -6, -0.9, 3.45)
	var engine: Node3D = w.kit.make_engine(w, Vector3(-4.1, 0, 7.2))
	engine.scale = Vector3.ONE * 0.55
	var boiler: Node3D = w.kit.make_boiler(w, Vector3(-4.65, 0, 10.8))
	boiler.scale = Vector3.ONE * 0.48
	var console: Node3D = w.kit.make_console(w, Vector3(-1.65, 0, 4), PI / 2.0)
	console.scale = Vector3.ONE * 0.48
	for x in [-5.6, -5.25, -4.9]:
		w._pipe(Vector3(x, 2.87, 3.3), Vector3(x, 2.87, 11.7), 0.07, "copper")
	for z in [4.3, 7.2, 10.2]:
		w._pipe(Vector3(-5.75, 1.05, z), Vector3(-5.75, 2.8, z), 0.09, "copper")
		w._pipe(Vector3(-5.75, 2.8, z), Vector3(-1.25, 2.8, z), 0.09, "copper")
		w.kit.make_valve(w, Vector3(-5.56, 1.55, z), -PI / 2.0).scale = Vector3.ONE * 0.65
	w._lantern(Vector3(-1.35, 2.72, 5.4), 0.82, 4.3)
	w._lantern(Vector3(-3.5, 2.93, 10.8), 0.8, 4.3)
	w._sign("ENGINE ROOM  /  LIVE STEAM", Vector3(-3.5, 2.63, 3.17), 0.0, 24, 0.004)
	w._note(Vector3(-1.13, 1.45, 5.3), "ENGINEER'S WATCH\n\nBoiler: fourteen atmospheres.\nOil both crossheads before changing watch.\n\nThat knocking is not a loose bearing.", -PI / 2.0)
	var shop_rect := Rect2(-5.6, 12, 4.7, 5)
	w._floor(shop_rect)
	w._roof(shop_rect, 2.75)
	w._window_wall_x(-5.6, 12, 17, [14.5], 2.75)
	w._wall_z(17, -5.6, -0.9, 2.75)
	w.kit.make_bench(w, Vector3(-3.5, 0, 16.15))
	w.furniture.bookshelf(w, Vector3(-5.15, 0, 13.2), -PI / 2.0)
	w.furniture.barrel(w, Vector3(-5.05, 0, 15.1))
	w.kit.make_crate(w, Vector3(-1.6, 0, 12.7), Vector3(0.95, 0.75, 0.95))
	for x in [-4.3, -4.0, -3.7, -3.4, -3.1, -2.8]:
		w._box("Hanging workshop tool", Vector3(x, 1.62, 16.74), Vector3(0.035, 0.42, 0.055), "iron", false)
		w._box("Wooden tool handle", Vector3(x, 1.38, 16.74), Vector3(0.055, 0.19, 0.065), "wood_light", false)
	w._lantern(Vector3(-3.5, 2.26, 15.6), 0.8, 3.8)
	w._lantern(Vector3(-4.9, 2.26, 12.8), 0.5, 3.3)
	w._note(Vector3(-3.5, 1.19, 16.5), "CARPENTER'S BOOK\n\nRepair the port window latch.\nReplace three planks on the aft balcony.\n\nDo not go out alone after midnight.", PI)

static func _cargo(w: Node3D) -> void:
	var rect := Rect2(0.9, 6, 4.9, 11)
	w._floor(rect)
	w._roof(rect, 3.05)
	w._window_wall_x(5.8, 6, 17, [8.0, 15.3], 3.05, [w._opening(12.0)])
	w._door(Vector3(5.8, 0, 12), "HOLD", "CARGO WALK", true)
	w._wall_z(17, 0.9, 5.8, 3.05)
	for x in [1.68, 4.95]:
		for z in [6.9, 9.1, 14.3, 16.15]:
			w.kit.make_crate(w, Vector3(x, 0, z), Vector3(1.1, 0.92, 1.2))
			if (x > 4.0 and z < 7.0) or (x < 2.0 and z > 14.0):
				w.kit.make_crate(w, Vector3(x + 0.02, 0.95, z), Vector3(1.02, 0.8, 1.05))
	for z in [7.0, 10.4, 15.9]:
		w.furniture.barrel(w, Vector3(3.3, 0, z))
	# Lashings and overhead cargo battens make a compact, occupied hold.
	for z in [7.0, 9.0, 14.4, 16.2]:
		w._pipe(Vector3(1.1, 2.63, z), Vector3(5.6, 2.63, z), 0.045, "wood_dark")
	w._pipe(Vector3(5.45, 2.65, 9.0), Vector3(5.45, 1.15, 9.0), 0.017, "rope")
	w._lantern(Vector3(3.35, 2.52, 8.5), 0.7, 4.0)
	w._lantern(Vector3(3.35, 2.52, 13.0), 0.7, 4.0)
	w._sign("HOLD No. 1   /   DRY STORES", Vector3(3.3, 2.46, 6.18), 0.0, 24, 0.004)
	w._note(Vector3(1.09, 1.45, 12.5), "CARGO MANIFEST\n\nFlour, lamp oil, coal, copper fittings.\nOne cedar trunk, sealed by the captain.\n\nThe trunk is not listed at departure.", PI / 2.0)
