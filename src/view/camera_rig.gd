class_name CameraRig
extends Node3D
## Tilted camera over the valley.
##   One finger / left mouse drag: pan (the ground follows the pointer).
##   Two fingers: pinch to zoom, twist to rotate, or move up/down together to
##   tilt. Each two-finger gesture does only one of these: the first clear
##   movement picks it, and it stays until the fingers lift.
##   Right mouse drag or Q / E: rotate. Scroll: zoom.
## A press-and-release without much movement is reported as a tap; holding
## still for LONG_PRESS_MS is reported as a long press instead.

signal tapped(screen_pos: Vector2)
signal long_pressed(screen_pos: Vector2)

const TAP_SLOP := 12.0
const LONG_PRESS_MS := 450
const PAN_LIMIT := 8.0   # how far the view centre may move from the valley centre
const TILT_PER_SCREEN := 2.2  # radians of tilt for a two-finger move the full screen height
# How far a two-finger gesture must move before it picks a mode.
const ZOOM_THRESHOLD := 24.0     # change in finger spread, px
const ROTATE_THRESHOLD := 0.17   # change in finger angle, radians (~10°)
const TILT_THRESHOLD := 24.0     # vertical move of the finger midpoint, px

enum Gesture { NONE, ZOOM, ROTATE, TILT }

@export var yaw := 0.0
@export var pitch := deg_to_rad(52.0)
@export var distance := 20.0
@export var target := Vector3(0.0, 0.0, 1.8)
@export var min_distance := 3.0
@export var max_distance := 32.0
@export var min_pitch := deg_to_rad(25.0)
@export var max_pitch := deg_to_rad(85.0)

var camera: Camera3D
var _button := MOUSE_BUTTON_NONE   # which mouse button is held, if any
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO     # previous pointer position (event.relative is unreliable for touch on scaled screens)
var _dragging := false
var _press_ms := 0
var _long_fired := false
var _touches := {}                 # touch index -> position
var _multi_touch := false
var _pinch_start_distance := 0.0
var _pinch_start_spread := 0.0
var _twist_start_yaw := 0.0
var _twist_start_angle := 0.0
var _tilt_start_pitch := 0.0
var _tilt_start_mid := 0.0
var _gesture := Gesture.NONE


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


func _process(_delta: float) -> void:
	if _button == MOUSE_BUTTON_LEFT and not _dragging and not _multi_touch and not _long_fired \
			and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_long_fired = true
		long_pressed.emit(_press_pos)


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
			_gesture = Gesture.NONE
			_start_two_finger_baseline()
		elif _touches.is_empty():
			_multi_touch = false
			_gesture = Gesture.NONE
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_start_spread > 0.0:
			_two_finger_drag()
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
					_press_ms = Time.get_ticks_msec()
					_long_fired = false
				else:
					var was_tap := _button == MOUSE_BUTTON_LEFT and not _dragging and not _multi_touch and not _long_fired
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


func _start_two_finger_baseline() -> void:
	_pinch_start_distance = distance
	_pinch_start_spread = _touch_spread()
	_twist_start_yaw = yaw
	_twist_start_angle = _touch_angle()
	_tilt_start_pitch = pitch
	_tilt_start_mid = _touch_mid_y()


func _two_finger_drag() -> void:
	if _gesture == Gesture.NONE:
		# Pick the mode whose movement is furthest past its threshold.
		var zoom := absf(_touch_spread() - _pinch_start_spread) / ZOOM_THRESHOLD
		var rotate := absf(angle_difference(_twist_start_angle, _touch_angle())) / ROTATE_THRESHOLD
		var tilt := absf(_touch_mid_y() - _tilt_start_mid) / TILT_THRESHOLD
		var best := maxf(zoom, maxf(rotate, tilt))
		if best < 1.0:
			return
		if best == zoom:
			_gesture = Gesture.ZOOM
		elif best == rotate:
			_gesture = Gesture.ROTATE
		else:
			_gesture = Gesture.TILT
		# Start from here so the view doesn't jump by the threshold amount.
		_start_two_finger_baseline()
		return
	match _gesture:
		Gesture.ZOOM:
			distance = _pinch_start_distance * _pinch_start_spread / maxf(_touch_spread(), 1.0)
		Gesture.ROTATE:
			yaw = _twist_start_yaw + angle_difference(_twist_start_angle, _touch_angle())
		Gesture.TILT:
			# Both fingers moving up lowers the view toward the horizon (like maps).
			var screen_h := get_viewport().get_visible_rect().size.y
			pitch = _tilt_start_pitch + (_touch_mid_y() - _tilt_start_mid) / maxf(screen_h, 1.0) * TILT_PER_SCREEN
	_apply()


func _touch_mid_y() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return ((pts[0] as Vector2).y + (pts[1] as Vector2).y) / 2.0


func _touch_angle() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()
