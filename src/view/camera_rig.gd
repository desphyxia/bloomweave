class_name CameraRig
extends Node3D
## Tilted camera over the valley.
##   One finger / left mouse drag: pan (the ground follows the pointer).
##   Two fingers: pinch to zoom, twist to rotate.
##   Right mouse drag or Q / E: rotate. Scroll: zoom.
## A press-and-release without much movement is reported as a tap.

signal tapped(screen_pos: Vector2)

const TAP_SLOP := 12.0
const PAN_LIMIT := 8.0   # how far the view centre may move from the valley centre

@export var yaw := 0.0
@export var pitch := deg_to_rad(52.0)
@export var distance := 20.0
@export var target := Vector3(0.0, 0.0, 1.8)
@export var min_distance := 7.0
@export var max_distance := 32.0
@export var min_pitch := deg_to_rad(25.0)
@export var max_pitch := deg_to_rad(85.0)

var camera: Camera3D
var _button := MOUSE_BUTTON_NONE   # which mouse button is held, if any
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO     # previous pointer position (event.relative is unreliable for touch on scaled screens)
var _dragging := false
var _touches := {}                 # touch index -> position
var _multi_touch := false
var _pinch_start_distance := 0.0
var _pinch_start_spread := 0.0
var _twist_start_yaw := 0.0
var _twist_start_angle := 0.0


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
	var flat := Vector2(target.x, target.z).limit_length(PAN_LIMIT)
	target = Vector3(flat.x, 0.0, flat.y)
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


## Move the view so the ground point under `from` ends up under `to`.
func _pan(from: Vector2, to: Vector2) -> void:
	var a: Variant = pick(from, 0.0)
	var b: Variant = pick(to, 0.0)
	if a == null or b == null:
		return
	target += (a as Vector3) - (b as Vector3)
	_apply()


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
			_pinch_start_distance = distance
			_pinch_start_spread = _touch_spread()
			_twist_start_yaw = yaw
			_twist_start_angle = _touch_angle()
		elif _touches.is_empty():
			_multi_touch = false
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_start_spread > 0.0:
			distance = _pinch_start_distance * _pinch_start_spread / maxf(_touch_spread(), 1.0)
			yaw = _twist_start_yaw - angle_difference(_twist_start_angle, _touch_angle())
			_apply()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					distance *= 0.9
					_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					distance *= 1.1
					_apply()
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_button = mb.button_index
					_dragging = false
					_press_pos = mb.position
					_last_pos = mb.position
				else:
					var was_tap := _button == MOUSE_BUTTON_LEFT and not _dragging and not _multi_touch
					_button = MOUSE_BUTTON_NONE
					_dragging = false
					if was_tap and mb.button_index == MOUSE_BUTTON_LEFT:
						tapped.emit(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _button == MOUSE_BUTTON_NONE or _multi_touch:
			_last_pos = mm.position
			return
		if not _dragging and mm.position.distance_to(_press_pos) > TAP_SLOP:
			_dragging = true
		if not _dragging:
			return
		var delta := mm.position - _last_pos
		if _button == MOUSE_BUTTON_RIGHT:
			yaw -= delta.x * 0.008
			pitch += delta.y * 0.006
			_apply()
		else:
			_pan(_last_pos, mm.position)
		_last_pos = mm.position
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		distance /= mg.factor
		_apply()
	elif event is InputEventPanGesture:
		# Two-finger trackpad scroll on laptops: pan.
		var pg := event as InputEventPanGesture
		var center := get_viewport().get_visible_rect().size / 2.0
		_pan(center + pg.delta * 8.0, center)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	if k.keycode == KEY_Q:
		yaw += 0.15
		_apply()
	elif k.keycode == KEY_E:
		yaw -= 0.15
		_apply()


func _touch_spread() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _touch_angle() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()
