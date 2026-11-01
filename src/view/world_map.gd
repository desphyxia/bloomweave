class_name WorldMap
extends Control
## The overlay for the 3D region overview (RegionView): the region's name,
## its stars and a Back button. Everything else passes through to the 3D
## view underneath (drag to pan, tap a valley).

signal closed

var _title: Label
var _stars: Label
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title)
	_stars = Label.new()
	_stars.add_theme_font_size_override("font_size", 17)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stars)
	_back = Button.new()
	_back.text = "Back"
	_back.focus_mode = Control.FOCUS_NONE
	_back.custom_minimum_size = Vector2(80, 38)
	_back.pressed.connect(func() -> void: closed.emit())
	row.add_child(_back)
	visible = false


func open(data: GameData, progress: Progress, region_index: int, can_close: bool) -> void:
	var region: Dictionary = data.regions[region_index]
	_title.text = region.get("name", "Valleys")
	_stars.text = "★ %d / %d" % [progress.region_stars(region), region.levels.size() * 3]
	_back.visible = can_close
	visible = true
