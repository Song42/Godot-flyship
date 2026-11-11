extends CanvasLayer
## Diegetic-inspired overlay: orientation, an accurate deck plan, and accessibility.

signal game_started
signal quality_changed(high: bool)
signal master_volume_changed(value: float)

const PAPER := Color("e3ded0")
const MUTED := Color("8b9995")
const AMBER := Color("d8ad68")
const TEAL := Color("74aaa1")

var player = null
var deck_rooms: Array = []
var _root: Control
var _intro: Control
var _hud: Control
var _pause: Control
var _map: Control
var _log: Control
var _log_title: Label
var _log_body: Label
var _log_open: bool = false
var _map_drawing: Control
var _zone_label: Label
var _detail_label: Label
var _bearing_label: Label
var _flash_label: Label
var _interaction_label: Label
var _notification_label: Label
var _intro_hint: Label
var _started: bool = false
var _paused: bool = false
var _map_open: bool = false
var _zone: String = "CENTRAL SPINE"
var _notice_time: float = 0.0
var _elapsed: float = 0.0
var _font: SystemFont
var _mono: SystemFont


func _ready() -> void:
	layer = 10
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "Malgun Gothic"])
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_root = Control.new()
	_root.name = "ShipInterface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 17
	_root.theme = theme
	_build_vignette()
	_build_hud()
	_build_intro()
	_build_pause()
	_build_map()
	_build_log()
	if is_instance_valid(player):
		player.flashlight_changed.connect(_on_flashlight)
		player.set_control_enabled(false)
	set_zone(_zone)


func set_zone(zone_name: String, detail: String = "DECK 01  /  PRESSURIZED INTERIOR") -> void:
	_zone = zone_name.to_upper()
	if is_instance_valid(_zone_label):
		_zone_label.text = _zone
		_detail_label.text = detail.to_upper()
	if is_instance_valid(_map_drawing):
		_map_drawing.current_zone = _zone


func set_interaction(text: String) -> void:
	if is_instance_valid(_interaction_label):
		_interaction_label.text = "[ E ]  " + text.to_upper() if not text.is_empty() else ""


func notify(text: String) -> void:
	if "\n" in text:
		_show_log(text)
		return
	_notification_label.text = text.to_upper()
	_notification_label.modulate.a = 1.0
	_notice_time = 4.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if not _started and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE):
			_begin()
			get_viewport().set_input_as_handled()
			return
	if not _started:
		return
	if _log_open:
		if event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_close_log()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if _map_open:
			_toggle_map()
		else:
			_set_pause(not _paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("deck_map") and not _paused:
		_toggle_map()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(player) and is_instance_valid(_bearing_label):
		var bearing: int = int(fposmod(-rad_to_deg(player.rotation.y), 360.0))
		_bearing_label.text = "HDG  %03d°     ALT  1,840 M" % bearing
	if _notice_time > 0.0:
		_notice_time -= delta
		_notification_label.modulate.a = minf(1.0, _notice_time)
	if _map_open and is_instance_valid(player):
		_map_drawing.observer_position = Vector2(player.global_position.x, player.global_position.z)
		_map_drawing.observer_heading = player.rotation.y
		_map_drawing.queue_redraw()
	if not _started:
		_intro_hint.modulate.a = 0.62 + sin(_elapsed * 1.5) * 0.16


func _build_vignette() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment(){ vec2 p=UV*2.0-1.0; float v=smoothstep(0.32,1.42,length(p)); float n=fract(sin(dot(FRAGCOORD.xy+TIME,vec2(12.9898,78.233)))*43758.5453); COLOR=vec4(vec3(0.008,0.012,0.011),v*0.31+n*0.018); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	vignette.material = material
	_root.add_child(vignette)


func _build_hud() -> void:
	_hud = _full_control(_root)
	_hud.visible = false
	_label(_hud, "N / 07", Vector2(42, 32), 14, AMBER, _mono)
	_line(_hud, Vector2(42, 58), Vector2(55, 1), AMBER)
	_zone_label = _label(_hud, _zone, Vector2(42, 70), 23, PAPER)
	_detail_label = _label(_hud, "DECK 01 / PRESSURIZED INTERIOR", Vector2(43, 102), 11, MUTED, _mono)
	_bearing_label = _label(_hud, "HDG  000°     ALT  1,840 M", Vector2(-322, 38), 12, MUTED, _mono)
	_bearing_label.set_anchor(SIDE_LEFT, 1.0, true, true)
	_bearing_label.set_anchor(SIDE_RIGHT, 1.0, true, true)
	var lower := _label(_hud, "WASD  MOVE     SHIFT  WALK FASTER     F  LAMP     M  DECK PLAN     ESC  MENU", Vector2(42, -48), 11, MUTED, _mono)
	lower.set_anchor(SIDE_TOP, 1.0, true, true)
	lower.set_anchor(SIDE_BOTTOM, 1.0, true, true)
	_flash_label = _label(_hud, "INSPECTION LAMP  /  ON", Vector2(-235, -48), 11, AMBER, _mono)
	_flash_label.set_anchor(SIDE_LEFT, 1.0, true, true)
	_flash_label.set_anchor(SIDE_RIGHT, 1.0, true, true)
	_flash_label.set_anchor(SIDE_TOP, 1.0, true, true)
	_flash_label.set_anchor(SIDE_BOTTOM, 1.0, true, true)
	var crosshair := ColorRect.new()
	crosshair.color = Color(0.85, 0.83, 0.73, 0.5)
	crosshair.position = Vector2(-1, -1)
	crosshair.size = Vector2(2, 2)
	crosshair.set_anchor(SIDE_LEFT, 0.5, true, true)
	crosshair.set_anchor(SIDE_RIGHT, 0.5, true, true)
	crosshair.set_anchor(SIDE_TOP, 0.5, true, true)
	crosshair.set_anchor(SIDE_BOTTOM, 0.5, true, true)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(crosshair)
	_interaction_label = _label(_hud, "", Vector2(-250, 32), 13, PAPER, _mono)
	_interaction_label.set_anchor(SIDE_LEFT, 0.5, true, true)
	_interaction_label.set_anchor(SIDE_RIGHT, 0.5, true, true)
	_interaction_label.set_anchor(SIDE_TOP, 0.5, true, true)
	_interaction_label.set_anchor(SIDE_BOTTOM, 0.5, true, true)
	_interaction_label.custom_minimum_size.x = 500
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label = _label(_hud, "", Vector2(-350, -110), 13, AMBER, _mono)
	_notification_label.set_anchor(SIDE_LEFT, 0.5, true, true)
	_notification_label.set_anchor(SIDE_RIGHT, 0.5, true, true)
	_notification_label.set_anchor(SIDE_TOP, 1.0, true, true)
	_notification_label.set_anchor(SIDE_BOTTOM, 1.0, true, true)
	_notification_label.custom_minimum_size.x = 700
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_intro() -> void:
	_intro = _full_control(_root)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.018, 0.028, 0.028, 0.96))
	gradient.set_color(1, Color(0.015, 0.022, 0.025, 0.1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0)
	var veil := TextureRect.new()
	veil.texture = texture
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(veil)
	_label(_intro, "N / 07     AERIAL RESEARCH DIVISION", Vector2(64, 42), 12, MUTED, _mono)
	var edition := _label(_intro, "INTERIOR EXPLORATION  /  01", Vector2(-310, 42), 11, MUTED, _mono)
	edition.set_anchor(SIDE_LEFT, 1.0, true, true)
	edition.set_anchor(SIDE_RIGHT, 1.0, true, true)
	var content := Control.new()
	content.position = Vector2(72, -182)
	content.set_anchor(SIDE_TOP, 0.5, true, true)
	content.set_anchor(SIDE_BOTTOM, 0.5, true, true)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(content)
	_line(content, Vector2(0, 0), Vector2(44, 2), AMBER)
	_label(content, "AERIAL RESEARCH VESSEL", Vector2(0, 22), 14, AMBER, _mono)
	var title := _label(content, "NOCTURNE", Vector2(-5, 49), 84, PAPER)
	title.add_theme_constant_override("outline_size", 0)
	_label(content, "H U L L   0 7", Vector2(1, 147), 17, MUTED, _mono)
	_label(content, "Somewhere above the world.\nNothing beyond the glass.", Vector2(0, 201), 21, PAPER)
	_label(content, "A quiet descent into the machinery of a sleeping vessel.", Vector2(0, 266), 13, MUTED)
	var start_button := _button(content, "ENTER THE VESSEL     →", Vector2(0, 316), Vector2(322, 56))
	start_button.pressed.connect(_begin)
	_intro_hint = _label(content, "PRESS ENTER TO BEGIN", Vector2(0, 391), 11, MUTED, _mono)
	var footer := _label(_intro, "EXPLORE AT YOUR OWN PACE     /     HEADPHONES RECOMMENDED", Vector2(72, -50), 11, MUTED, _mono)
	footer.set_anchor(SIDE_TOP, 1.0, true, true)
	footer.set_anchor(SIDE_BOTTOM, 1.0, true, true)


func _build_pause() -> void:
	_pause = _full_control(_root)
	_pause.visible = false
	_backdrop(_pause, Color(0.012, 0.02, 0.023, 0.88))
	var panel := Control.new()
	panel.position = Vector2(-240, -245)
	panel.set_anchor(SIDE_LEFT, 0.5, true, true)
	panel.set_anchor(SIDE_RIGHT, 0.5, true, true)
	panel.set_anchor(SIDE_TOP, 0.5, true, true)
	panel.set_anchor(SIDE_BOTTOM, 0.5, true, true)
	_pause.add_child(panel)
	_label(panel, "N / 07   •   OBSERVER CONTROLS", Vector2.ZERO, 12, AMBER, _mono)
	_label(panel, "STAND BY", Vector2(-2, 33), 44, PAPER)
	_line(panel, Vector2(0, 96), Vector2(480, 1), Color(0.45, 0.56, 0.53, 0.35))
	var resume := _button(panel, "RESUME EXPLORATION    →", Vector2(0, 118), Vector2(480, 48))
	resume.pressed.connect(func(): _set_pause(false))
	_label(panel, "AMBIENT AUDIO", Vector2(0, 190), 12, MUTED, _mono)
	var volume := HSlider.new()
	volume.position = Vector2(235, 189)
	volume.size = Vector2(245, 20)
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = 0.72
	volume.value_changed.connect(func(value: float): master_volume_changed.emit(value))
	panel.add_child(volume)
	var bob := _check(panel, "CAMERA WALKING MOTION", Vector2(0, 232), true)
	bob.toggled.connect(func(value: bool):
		if is_instance_valid(player):
			player.head_bob_enabled = value
	)
	var quality := _check(panel, "CINEMATIC LIGHTING", Vector2(0, 278), true)
	quality.toggled.connect(func(value: bool): quality_changed.emit(value))
	_label(panel, "Disable cinematic lighting for lighter rendering.", Vector2(0, 324), 12, MUTED)
	_line(panel, Vector2(0, 362), Vector2(480, 1), Color(0.45, 0.56, 0.53, 0.35))
	_label(panel, "WASD / ARROWS    MOVE       M / TAB    DECK PLAN\nMOUSE            LOOK       E          INTERACT\nSHIFT            HURRY      CTRL       CROUCH\nF                LAMP       ESC        RESUME", Vector2(0, 387), 12, MUTED, _mono)
	var quit := _button(panel, "LEAVE VESSEL", Vector2(0, 492), Vector2(480, 42))
	quit.pressed.connect(func(): get_tree().quit())


func _build_map() -> void:
	_map = _full_control(_root)
	_map.visible = false
	_backdrop(_map, Color(0.013, 0.023, 0.026, 0.95))
	_label(_map, "N / 07     NAVIGATION ARCHIVE", Vector2(54, 42), 12, AMBER, _mono)
	_label(_map, "DECK PLAN", Vector2(52, 82), 38, PAPER)
	_label(_map, "01  /  HABITABLE DECK", Vector2(54, 136), 12, MUTED, _mono)
	_line(_map, Vector2(54, 181), Vector2(232, 1), Color(0.45, 0.56, 0.53, 0.4))
	_label(_map, "COMPARTMENT INDEX\n\n01    COMMAND BRIDGE\n02    ENGINE CATHEDRAL\n03    CARGO HOLD\n04    MACHINE SHOP\n05    OBSERVATION\n06    AFT AIRLOCK\n —    CENTRAL SPINE", Vector2(54, 211), 14, MUTED, _mono)
	_label(_map, "●  OBSERVER POSITION\n\nPlan is shown to scale.\nAll sections are connected.\nNo external flight controls.", Vector2(54, 510), 12, TEAL, _mono)
	var close_button := _button(_map, "M / ESC     CLOSE PLAN", Vector2(-275, -75), Vector2(230, 40))
	close_button.set_anchor(SIDE_LEFT, 1.0, true, true)
	close_button.set_anchor(SIDE_RIGHT, 1.0, true, true)
	close_button.set_anchor(SIDE_TOP, 1.0, true, true)
	close_button.set_anchor(SIDE_BOTTOM, 1.0, true, true)
	close_button.pressed.connect(_toggle_map)
	_map_drawing = DeckPlan.new()
	_map_drawing.position = Vector2(-260, -290)
	_map_drawing.set_anchor(SIDE_LEFT, 0.65, true, true)
	_map_drawing.set_anchor(SIDE_RIGHT, 0.65, true, true)
	_map_drawing.set_anchor(SIDE_TOP, 0.5, true, true)
	_map_drawing.set_anchor(SIDE_BOTTOM, 0.5, true, true)
	_map_drawing.size = Vector2(520, 580)
	_map_drawing.map_font = _mono
	if not deck_rooms.is_empty():
		_map_drawing.rooms = []
		for room: Dictionary in deck_rooms:
			var number: String = str(room.detail).get_slice(" / ", 0)
			if "DECK" in number:
				number = "—"
			_map_drawing.rooms.append([room.rect, number, room.name])
	_map.add_child(_map_drawing)


func _build_log() -> void:
	_log = _full_control(_root)
	_log.visible = false
	_backdrop(_log, Color(0.012, 0.02, 0.023, 0.88))
	var panel := Control.new()
	panel.position = Vector2(-330, -222)
	panel.set_anchor(SIDE_LEFT, 0.5, true, true)
	panel.set_anchor(SIDE_RIGHT, 0.5, true, true)
	panel.set_anchor(SIDE_TOP, 0.5, true, true)
	panel.set_anchor(SIDE_BOTTOM, 0.5, true, true)
	_log.add_child(panel)
	_label(panel, "NOCTURNE    /    SHIPBOARD ARCHIVE", Vector2.ZERO, 12, AMBER, _mono)
	_line(panel, Vector2(0, 38), Vector2(660, 1), Color(0.45, 0.56, 0.53, 0.35))
	_log_title = _label(panel, "SHIP LOG", Vector2(0, 62), 26, PAPER)
	_log_title.custom_minimum_size = Vector2(660, 38)
	_log_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_body = _label(panel, "", Vector2(0, 124), 20, PAPER, _mono)
	_log_body.custom_minimum_size = Vector2(660, 200)
	_log_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_body.add_theme_constant_override("line_spacing", 8)
	var close_button := _button(panel, "E / ESC    CLOSE ARCHIVE", Vector2(0, 389), Vector2(660, 48))
	close_button.pressed.connect(_close_log)


func _show_log(text: String) -> void:
	var divider: int = text.find("\n")
	_log_title.text = text.substr(0, divider).to_upper()
	_log_body.text = text.substr(divider + 1).strip_edges()
	_log_open = true
	_log.visible = true
	_hud.visible = false
	if is_instance_valid(player):
		player.set_control_enabled(false)


func _close_log() -> void:
	_log_open = false
	_log.visible = false
	_hud.visible = true
	if is_instance_valid(player):
		player.set_control_enabled(true)


func _begin() -> void:
	if _started:
		return
	_started = true
	_intro.visible = false
	_hud.visible = true
	if is_instance_valid(player):
		player.start()
	game_started.emit()
	notify("VESSEL ACCESS GRANTED  /  PRESS M FOR DECK PLAN")


func _set_pause(value: bool) -> void:
	_paused = value
	_pause.visible = value
	_hud.visible = not value
	if is_instance_valid(player):
		player.set_control_enabled(not value)


func _toggle_map() -> void:
	_map_open = not _map_open
	_map.visible = _map_open
	_hud.visible = not _map_open
	if is_instance_valid(player):
		player.set_control_enabled(not _map_open)


func _on_flashlight(value: bool) -> void:
	_flash_label.text = "INSPECTION LAMP  /  " + ("ON" if value else "OFF")
	_flash_label.modulate.a = 1.0 if value else 0.5


func _full_control(parent: Node) -> Control:
	var control := Control.new()
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


func _backdrop(parent: Control, color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP


func _label(parent: Node, text: String, pos: Vector2, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_y", 1)
	if font != null:
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _line(parent: Node, pos: Vector2, dimensions: Vector2, color: Color) -> void:
	var line := ColorRect.new()
	line.color = color
	line.position = pos
	line.size = dimensions
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _mono)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("fff1d4"))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.19, 0.18, 0.7), Color(0.60, 0.56, 0.42, 0.7)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.27, 0.25, 0.18, 0.9), AMBER))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.34, 0.30, 0.19, 1.0), AMBER))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), AMBER))
	parent.add_child(button)
	return button


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


func _check(parent: Node, text: String, pos: Vector2, value: bool) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.position = pos
	check.size = Vector2(480, 36)
	check.button_pressed = value
	check.add_theme_font_override("font", _mono)
	check.add_theme_font_size_override("font_size", 12)
	check.add_theme_color_override("font_color", PAPER)
	parent.add_child(check)
	return check


class DeckPlan extends Control:
	var observer_position := Vector2.ZERO
	var observer_heading: float = 0.0
	var current_zone: String = ""
	var map_font: Font
	var rooms: Array = [
		[Rect2(-3.6, -28, 7.2, 60), "04", "SPINE"],
		[Rect2(-10, -46, 20, 18), "01", "FLIGHT DECK"],
		[Rect2(-19, -12, 15.4, 25), "03", "ENGINE HALL"],
		[Rect2(3.6, -6, 17.4, 26), "05", "CARGO HOLD"],
		[Rect2(-16, 18, 12.4, 14), "06", "WORKSHOP"],
		[Rect2(3.6, -25, 11.4, 12), "02", "OBSERVATION"],
		[Rect2(-6, 32, 12, 8), "07", "AIRLOCK"]
	]

	func _point(world: Vector2) -> Vector2:
		return Vector2(250, 290) + Vector2(world.x, world.y + 3) * 6.0


	func _draw() -> void:
		var grid := Color(0.30, 0.43, 0.42, 0.09)
		for x in range(10, 520, 30):
			draw_line(Vector2(x, 10), Vector2(x, 570), grid)
		for y in range(10, 580, 30):
			draw_line(Vector2(10, y), Vector2(510, y), grid)
		for room: Array in rooms:
			var bounds: Rect2 = room[0]
			var rect := Rect2(_point(bounds.position), bounds.size * 6.0)
			var inside: bool = bounds.has_point(observer_position)
			var stroke := Color(0.57, 0.66, 0.61, 0.78)
			draw_rect(rect, Color(0.075, 0.13, 0.13, 0.95))
			if inside:
				draw_rect(rect.grow(-2), Color(0.23, 0.39, 0.35, 0.34))
				stroke = Color("d8ad68")
			draw_rect(rect, stroke, false, 1.5)
			var center: Vector2 = rect.get_center()
			if map_font:
				draw_string(map_font, center + Vector2(-8, 4), room[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, stroke)
		var point: Vector2 = _point(observer_position)
		var facing := Vector2(-sin(observer_heading), -cos(observer_heading))
		var tangent := facing.orthogonal()
		draw_circle(point, 10, Color(0.46, 0.77, 0.68, 0.12))
		draw_circle(point, 4, Color("9ad7c5"))
		draw_colored_polygon(PackedVector2Array([point + facing * 17, point + facing * 8 + tangent * 4, point + facing * 8 - tangent * 4]), Color("9ad7c5"))
		if map_font:
			draw_string(map_font, Vector2(230, 20), "BOW ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8b9995"))
			draw_string(map_font, Vector2(18, 560), "0       5       10 M", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8b9995"))
		draw_line(Vector2(18, 542), Vector2(78, 542), Color("8b9995"), 1)
		for x: int in [18, 48, 78]:
			draw_line(Vector2(x, 539), Vector2(x, 545), Color("8b9995"), 1)
