extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
    _run.call_deferred()
func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
func key(action: String) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    return event
func _run() -> void:
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await physics_frame
    await process_frame
    var ui = scene.ui
    var player = scene.player
    expect(not player.active, "Intro must release player control")
    expect(ui._intro.visible and not ui._hud.visible, "Intro visibility")
    ui._begin()
    expect(player.active and ui._hud.visible and not ui._intro.visible, "Begin transition")
    ui._input(key("deck_map"))
    expect(ui._map_open and not player.active and ui._map.visible, "Map opens and releases cursor")
    ui._input(key("pause"))
    expect(not ui._map_open and player.active and not ui._paused, "Escape closes map without pausing")
    ui._input(key("pause"))
    expect(ui._paused and not player.active and ui._pause.visible, "Escape pauses")
    ui._input(key("deck_map"))
    expect(not ui._map_open and ui._paused, "Map disabled while paused")
    ui._input(key("pause"))
    expect(not ui._paused and player.active and ui._hud.visible, "Escape resumes")
    ui._input(key("deck_map"))
    ui._input(key("deck_map"))
    expect(not ui._map_open and player.active, "Map key toggles back")
    player._unhandled_input(key("flashlight"))
    expect(not player.flashlight.visible, "Flashlight turns off")
    player._unhandled_input(key("flashlight"))
    expect(player.flashlight.visible, "Flashlight turns on")
    ui.notify("ENGINEERING / STATUS\n\nBoiler pressure: nominal.\nDo not disturb the sleeping vessel.")
    expect(ui._log_open and not player.active and ui._log.visible, "Archive opens and releases control")
    ui._input(key("pause"))
    expect(not ui._log_open and player.active and not ui._paused, "Escape closes archive without pause")
    ui.notify("CARGO MANIFEST\n\n24 sealed containers.")
    ui._input(key("interact"))
    expect(not ui._log_open and player.active, "Interact key closes archive")
    expect(ui._map_drawing.rooms.size() == scene.room_bounds.size(), "Map uses authoritative room data")
    ui._map_drawing.fit_rooms()
    var map_inset := Rect2(Vector2(20, 20), ui._map_drawing.size - Vector2(40, 40))
    for room: Dictionary in scene.room_bounds:
        var bounds: Rect2 = room.rect
        expect(map_inset.has_point(ui._map_drawing._point(bounds.position)), "Map contains upper corner: " + room.name)
        expect(map_inset.has_point(ui._map_drawing._point(bounds.end)), "Map contains lower corner: " + room.name)
    scene.ambience.set_zone("BALCONY")
    scene.ambience._process(2.0)
    expect(scene.ambience._wind.volume_db > -28.0, "Outdoor wind is audible on balcony")
    scene.ambience.set_zone("CREW QUARTERS")
    scene.ambience._process(2.0)
    expect(scene.ambience._wind.volume_db < -40.0, "Cabin walls shelter outdoor wind")
    scene.ambience.play_door()
    expect(scene.ambience._door.playing, "Door hinge sound starts")
    await process_frame
    var viewport_size: Vector2 = root.get_visible_rect().size
    expect(ui._bearing_label.get_rect().position.x > viewport_size.x * 0.6, "Right HUD anchor")
    expect(ui._flash_label.get_rect().position.y > viewport_size.y * 0.75, "Bottom HUD anchor")
    expect(is_equal_approx(ui._map_drawing.size.x, 520.0), "Deck plan exact dimensions")
    print("UI CHECK: viewport=", viewport_size, " bearing=", ui._bearing_label.get_rect(), " map=", ui._map_drawing.get_rect())
    scene.queue_free()
    await process_frame
    # Let the audio mixer release stopped playback handles before shutdown.
    await create_timer(0.08).timeout
    if failures.is_empty():
        print("UI SMOKE PASS: intro, movement capture, pause, fitted map, lantern, interior/exterior audio, anchors")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        quit(1)
