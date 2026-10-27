class_name CameraRig
extends Node3D
## Tilted orbit camera. Drag to orbit, scroll or pinch to zoom.
## A press-and-release without much movement is reported as a tap.

signal tapped(screen_pos: Vector2)

const TAP_SLOP := 12.0

@export var yaw := 0.0
@export var pitch := deg_to_rad(52.0)
@export var distance := 20.0
@export var target := Vector3(0.0, 0.0, 1.8)
@export var min_distance := 7.0
@export var max_distance := 32.0
@export var min_pitch := deg_to_rad(25.0)
@export var max_pitch := deg_to_rad(85.0)

var camera: Camera3D
var _pressed := false
var _press_pos := Vector2.ZERO
var _dragging := false
var _touches := {}       # index -> position
var _pinch_start := 0.0
var _pinch_distance := 0.0
var _multi_touch := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	_apply()


## Adjust to the screen shape: in portrait, fit the width instead of the height.
func fit(aspect: float) -> void:
	if aspect < 1.0:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 62.0
		distance = 12.5
		target = Vector3(0.0, 0.0, 1.6)
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 45.0
		distance = 21.0
		target = Vector3(0.0, 0.0, 2.6)
	_apply()


func _apply() -> void:
	pitch = clampf(pitch, min_pitch, max_pitch)
	distance = clampf(distance, min_distance, max_distance)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)) * distance
	camera.position = target + offset
	camera.look_at(target, Vector3.UP)


## Ray from the camera through a screen point, hit against the plane y = h.
func pick(screen_pos: Vector2, h: float) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (h - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_multi_touch = true
			_dragging = true
			_pinch_start = distance
			_pinch_distance = _touch_spread()
		elif _touches.is_empty():
			_multi_touch = false
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_distance > 0.0:
			distance = _pinch_start * _pinch_distance / maxf(_touch_spread(), 1.0)
			_apply()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance *= 0.9
			_apply()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance *= 1.1
			_apply()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_pressed = true
				_dragging = false
				_press_pos = mb.position
			else:
				if _pressed and not _dragging and not _multi_touch and mb.button_index == MOUSE_BUTTON_LEFT:
					tapped.emit(mb.position)
				_pressed = false
				_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _pressed or _multi_touch:
			return
		if not _dragging and mm.position.distance_to(_press_pos) > TAP_SLOP:
			_dragging = true
		if _dragging:
			yaw -= mm.relative.x * 0.008
			pitch += mm.relative.y * 0.006
			_apply()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		distance /= mg.factor
		_apply()


func _touch_spread() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)
