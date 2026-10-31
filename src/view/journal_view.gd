class_name JournalView
extends ColorRect
## The journal: tabs for Blooms, Residents and Visitors. Found entries show
## a picture, name, a nature note and where they were first found; others
## show hints only (a bloom's greyed recipe, what a resident asks for, a
## visitor's riddle). Reads Progress; changes nothing.

signal closed

const INK := Color(0.2, 0.22, 0.18)
const MUTED := Color(0.42, 0.39, 0.34)
const TABS := {"blooms": "Blooms", "residents": "Residents", "visitors": "Visitors"}

var data: GameData
var progress: Progress
var textile := Textile.new()

var _tab := "blooms"
var _list: VBoxContainer
var _tab_buttons := {}
var _panel: PanelContainer
var _scroll: ScrollContainer
var _compact := false


func _ready() -> void:
	color = Color(0.2, 0.18, 0.14, 0.45)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Journal"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	for kind: String in TABS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110, 42)
		b.pressed.connect(func() -> void: _show_tab(kind))
		tabs.add_child(b)
		_tab_buttons[kind] = b
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var close := Button.new()
	close.text = "Back to the valley"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(180, 46)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	box.add_child(close)
	visible = false


func open(p_data: GameData, p_progress: Progress, compact: bool) -> void:
	data = p_data
	progress = p_progress
	_compact = compact
	var view := get_viewport_rect().size
	var w := minf(560.0, view.x - 24.0)
	_panel.custom_minimum_size.x = w
	_scroll.custom_minimum_size = Vector2(w - 24.0, minf(view.y * 0.62, 620.0))
	visible = true
	_show_tab(_tab)


func _show_tab(kind: String) -> void:
	_tab = kind
	var entries := Journal.entries(data)
	for k: String in TABS:
		var found := 0
		for e: Dictionary in entries[k]:
			if progress.is_found(k, e.id):
				found += 1
		_tab_buttons[k].text = "%s %d/%d" % [TABS[k], found, entries[k].size()]
		_tab_buttons[k].button_pressed = k == kind
	for c in _list.get_children():
		c.queue_free()
	for e: Dictionary in entries[kind]:
		_list.add_child(_entry(kind, e))
	_scroll.scroll_vertical = 0


func _entry(kind: String, e: Dictionary) -> Control:
	var found := progress.is_found(kind, e.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	var names := []
	for level: String in e.levels:
		names.append(data.valley(level).get("name", level))
	var title := ""
	var note := ""
	var meta := ""
	if kind == "blooms":
		var bloom: Dictionary = data.blooms_by_id[e.id]
		var icon := CornerIcon.new()
		icon.data = data
		icon.custom_minimum_size = Vector2(64, 30)
		icon.bloom_color = Color(bloom.get("color", "#ffffff"))
		icon.biomes = bloom.trio
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not found:
			icon.modulate = Color(1, 1, 1, 0.35)
		row.add_child(icon)
		var biomes := []
		for b: String in bloom.trio:
			biomes.append(data.biomes[b].name.to_lower())
		if found:
			title = bloom.name
			note = bloom.get("note", "")
			meta = "First grown in %s  ·  Grows in %s" % [_name_of(progress.found_in(kind, e.id)), ", ".join(names)]
		else:
			title = "Not yet grown"
			note = "Recipe: %s" % " + ".join(biomes)
			meta = "Grows in %s" % ", ".join(names)
	else:
		var a: Dictionary = data.animals[e.id]
		var pic := AnimalPortrait.new()
		pic.textile = textile
		pic.id = e.id if found else ""
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		if found:
			title = a.name
			note = a.get("note", "")
			if kind == "visitors":
				note += "  (%s)" % a.get("found_text", "")
			meta = "First %s in %s  ·  %s %s" % ["seen" if kind == "visitors" else "settled",
				_name_of(progress.found_in(kind, e.id)), "Visits" if kind == "visitors" else "Lives in", ", ".join(names)]
		elif kind == "visitors":
			title = "?"
			note = "\"%s\"" % a.get("riddle", "")
			meta = "Visits %s" % ", ".join(names)
		else:
			title = "Not yet met"
			note = "Asks for: %s" % a.get("description", "")
			meta = "Lives in %s" % ", ".join(names)
	text.add_child(_label(title, 17 if not _compact else 15, INK))
	text.add_child(_label(note, 14 if not _compact else 13, INK if found else MUTED))
	text.add_child(_label(meta, 12, MUTED))
	row.add_child(text)
	return row


func _name_of(level: String) -> String:
	return data.valley(level).get("name", level) if level != "" else ""


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
