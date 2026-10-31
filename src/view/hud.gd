class_name Hud
extends CanvasLayer
## On-screen interface: valley info, animals, pieces, placement and seed
## actions, messages, the end screen and the list of valleys (levels).
## Emits signals; holds no rules.

signal action(name: String)

const INK := Color(0.2, 0.22, 0.18)
const PAPER := Color(0.98, 0.96, 0.9, 0.94)
const ACCENT := Color(0.76, 0.27, 0.42)

var data: GameData
var game: ValleyGame

var _root: Control
var _info: Label
var _animals_box: VBoxContainer
var _blooms_box: VBoxContainer
var _current: PieceIcon
var _upcoming_box: HBoxContainer
var _reserve: PieceIcon
var _buttons := {}
var _toast: Label
var _toast_tween: Tween
var _hint: Label
var _hint_panel: PanelContainer
var _flow: HFlowContainer
var _cards: PanelContainer
var _card_labels: Array[Label] = []
var _compact := false             # phone layout: small piece panel on the right
var _small_icon := Vector2(64, 64)
var _end: PanelContainer
var _end_label: Label
var _end_stars: StarRow
var _end_note: Label
var _levels: Control
var _levels_list: VBoxContainer
var _levels_total: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_top()
	_build_bottom()
	_build_toast()
	_build_end()
	_build_levels()


func setup(p_game: ValleyGame) -> void:
	game = p_game
	data = game.data
	_current.data = data
	_reserve.data = data
	_end.visible = false
	_hint_panel.visible = true
	_hint.text = "Tap a glowing plot to try the piece there. Tap it again to turn it. Press and hold to place it."
	_hint.text += "\nBlooms grow on the stitched stars, where three pieces meet. Buds show which biome a corner still needs."
	if game.clockwise_blooms():
		_hint.text += "\nIn this valley the biomes must go clockwise (see Blooms)."
	if game.valley.has("intro"):
		_hint.text = "%s\n%s" % [game.valley.intro, _hint.text]
	_hint.text += "\n(Tap here to close.)"
	_build_bloom_guide()


## Update everything from the game state. `arranged` is the current piece as
## it would be placed; `selected` tells whether a plot is chosen.
func refresh(arranged: Array, selected: bool, preview_count: int) -> void:
	var s := game.score_breakdown()
	# Phones get a narrower panel: tighter dots and the build on its own line,
	# so the top row never runs off the screen with longer valley names.
	var dot := "  ·  " if _compact else "   ·   "
	var build := _build_id()
	var lines := [
		"%s%sgame #%d" % [game.valley.get("name", "Valley"), dot, game.game_seed],
		"Seeds %d%sScore %d%sPieces left %d" % [game.seeds, dot, s.total, dot, game.pieces_left()],
	]
	if build != "":
		if _compact:
			lines.append("build %s" % build)
		else:
			lines[0] += "%sbuild %s" % [dot, build]
	_info.text = "\n".join(lines)
	_current.biomes = arranged
	for c in _upcoming_box.get_children():
		c.queue_free()
	for p: Array in game.upcoming():
		var icon := _icon(_small_icon)
		icon.biomes = p
		icon.dimmed = true
		_upcoming_box.add_child(icon)
	if game.upcoming().is_empty():
		var none := _icon(_small_icon)
		none.empty_text = "—"
		_upcoming_box.add_child(none)
	_reserve.biomes = game.reserve
	_reserve.empty_text = "empty"
	_buttons.rotate.disabled = not selected
	_buttons.mirror.disabled = not selected
	_buttons.place.disabled = not selected
	_buttons.place.text = "Place  +%d pts" % game.combo_points(preview_count) if selected and preview_count > 0 else "Place"
	_buttons.set_aside.disabled = not game.can_set_aside()
	_buttons.use_reserve.disabled = not game.can_use_reserve()
	_buttons.swap.disabled = not game.can_swap()
	_buttons.look_ahead.disabled = not game.can_look_ahead()
	_refresh_animals()


## "  · build abc1234" when CI stamped the build (data/build.json), else "".
func _build_id() -> String:
	if not has_meta("build"):
		var build := ""
		if FileAccess.file_exists("res://data/build.json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/build.json"))
			if typeof(parsed) == TYPE_DICTIONARY:
				build = str(parsed.get("build", ""))
		set_meta("build", build)
	return get_meta("build")


func _refresh_animals() -> void:
	for c in _animals_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Residents (best corridor)"
	title.add_theme_font_size_override("font_size", 17)
	_animals_box.add_child(title)
	for id: String in game.residents():
		var a: Dictionary = game.animal(id)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		if game.settled.has(id):
			l.text = "%s — moved in!" % a.name
			l.add_theme_color_override("font_color", ACCENT)
		else:
			var parts := []
			for c: Dictionary in game.animal_progress(id):
				parts.append("%d/%d %s" % [mini(c.have, c.need), c.need, c.label])
			l.text = "%s: %s" % [a.name, ", ".join(parts)]
		l.tooltip_text = a.description
		_animals_box.add_child(l)
	# The hidden visitor: a riddle until it comes, then what brought it.
	var v := game.visitor()
	if not v.is_empty():
		var vl := Label.new()
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.custom_minimum_size.x = 260 if _compact else 300
		vl.add_theme_font_size_override("font_size", 13 if _compact else 15)
		if game.visitor_found:
			vl.text = "%s visited! (%s)" % [v.name, v.get("found_text", "")]
			vl.add_theme_color_override("font_color", ACCENT)
		else:
			vl.text = "Visitor?  \"%s\"" % v.get("riddle", "")
			vl.add_theme_color_override("font_color", Color(0.42, 0.36, 0.44))
		_animals_box.add_child(vl)


## The valley's blooms, each drawn as a mini piece with its biomes in
## clockwise order (piece slots run clockwise).
func _build_bloom_guide() -> void:
	for c in _blooms_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Blooms (clockwise)" if game.clockwise_blooms() else "Blooms (any order)"
	title.add_theme_font_size_override("font_size", 17)
	_blooms_box.add_child(title)
	for bloom: Dictionary in game.recipes():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := CornerIcon.new()
		icon.data = data
		icon.clockwise = game.clockwise_blooms()
		icon.custom_minimum_size = Vector2(34, 34) if icon.clockwise else Vector2(62, 24)
		icon.bloom_color = Color(bloom.get("color", "#ffffff"))
		icon.biomes = bloom.trio
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var l := Label.new()
		l.text = bloom.name
		l.add_theme_font_size_override("font_size", 15)
		row.add_child(l)
		_blooms_box.add_child(row)


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


func _hide_toast() -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.visible = false


func hide_hint() -> void:
	_hint_panel.visible = false


## The end screen. `result`: "stars" (this level's stars, after this game),
## "fresh" (which of them this game added), "next_name" (the next level, or
## "" if this was the last) and "next_open".
func show_end(result: Dictionary = {}) -> void:
	var s := game.score_breakdown()
	var lines := ["%s is restored." % game.valley.get("name", "The valley"), ""]
	lines.append("Blooms: %d  (%d points)" % [game.blooms.size(), s.blooms])
	var names := []
	for id: String in game.settled:
		names.append(game.animal(id).name)
	if game.visitor_found:
		names.append(game.visitor().name)
	lines.append("Animals: %s  (%d points)" % [", ".join(names) if not names.is_empty() else "none yet", s.animals])
	lines.append("Seeds left: %d  (%d points)" % [game.seeds, s.seeds])
	lines.append("")
	lines.append("Score: %d" % s.total)
	_end_label.text = "\n".join(lines)
	var stars: Dictionary = result.get("stars", game.stars())
	var fresh: Dictionary = result.get("fresh", {})
	_end_stars.earned = [stars.restored, stars.residents, stars.visitor]
	_end_stars.fresh = [fresh.get("restored", false), fresh.get("residents", false), fresh.get("visitor", false)]
	var next_name: String = result.get("next_name", "")
	var open: bool = result.get("next_open", false)
	_buttons.next.visible = next_name != "" and open
	_buttons.next.text = "Next: %s" % next_name
	if next_name == "":
		_end_note.text = "That's every valley for now. More are coming."
	elif fresh.get("restored", false):
		_end_note.text = "%s is now open!" % next_name
	else:
		_end_note.text = ""
	_end_note.visible = _end_note.text != ""
	_hide_toast()
	_hint_panel.visible = false
	_end.visible = true


## The list of valleys: each with its stars and best score; locked ones say
## what opens them. `can_close` adds a way back to the current game.
func show_levels(progress: Progress, can_close: bool) -> void:
	for c in _levels_list.get_children():
		c.queue_free()
	var n := 0
	for id: String in progress.levels:
		n += 1
		var v := data.valley(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(210, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		var open := progress.is_unlocked(id)
		b.text = "%d.  %s" % [n, v.get("name", id)]
		b.disabled = not open
		b.pressed.connect(func() -> void: action.emit("level:" + id))
		row.add_child(b)
		var stars := StarRow.new()
		var st := progress.stars(id)
		stars.earned = [st.restored, st.residents, st.visitor]
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(stars)
		var note := Label.new()
		note.add_theme_font_size_override("font_size", 14)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not open:
			var prev := data.valley(progress.levels[n - 2])
			note.text = "Restore %s to open" % prev.get("name", "")
		elif progress.best(id) > 0:
			note.text = "Best %d" % progress.best(id)
		row.add_child(note)
		_levels_list.add_child(row)
	_levels_total.text = "Stars: %d of %d   (restore · all residents · hidden visitor)" % [
		progress.total_stars(), progress.levels.size() * 3]
	if progress.unlock_all:
		_levels_total.text += "\nDev mode: every valley is open."
	_buttons.close_levels.visible = can_close
	_end.visible = false
	_hint_panel.visible = false
	_hide_toast()
	_levels.visible = true


func hide_levels() -> void:
	_levels.visible = false


func levels_shown() -> bool:
	return _levels.visible


# --- Layout -------------------------------------------------------------------

func _build_top() -> void:
	var top := HFlowContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var info_panel := _panel()
	info_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	info_panel.add_child(info_row)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 19)
	info_row.add_child(_info)
	_add_button(info_row, "levels", "Valleys")
	_buttons.levels.custom_minimum_size = Vector2(84, 40)
	_buttons.levels.add_theme_font_size_override("font_size", 15)
	_buttons.levels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(info_panel)

	top.add_theme_constant_override("h_separation", 10)
	top.add_theme_constant_override("v_separation", 8)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	var animals_panel := _panel()
	animals_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_animals_box = VBoxContainer.new()
	animals_panel.add_child(_animals_box)
	top.add_child(animals_panel)

	var blooms_panel := _panel()
	blooms_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_blooms_box = VBoxContainer.new()
	_blooms_box.add_theme_constant_override("separation", 2)
	blooms_panel.add_child(_blooms_box)
	top.add_child(blooms_panel)



func _build_bottom() -> void:
	var flow := HFlowContainer.new()
	_flow = flow
	flow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	flow.grow_vertical = Control.GROW_DIRECTION_BEGIN
	flow.offset_left = 12
	flow.offset_right = -12
	flow.offset_bottom = -12
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The first-turn hint sits just above the bottom panels, so it never
	# covers the info panels at the top.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -12
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_hint_panel = _panel()
	_hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Tap the hint to dismiss it (the tap doesn't reach the board).
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_panel.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
				or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			hide_hint()
			_hint_panel.accept_event())
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 420
	_hint.add_theme_font_size_override("font_size", 16)
	_hint_panel.add_child(_hint)
	bottom.add_child(_hint_panel)
	flow.offset_left = 0
	flow.offset_right = 0
	flow.offset_bottom = 0
	flow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bottom.add_child(flow)

	# Pieces: current, upcoming, reserve.
	var cards := _panel()
	_cards = cards
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.name = "row"
	cards.add_child(row)
	_current = _icon(Vector2(104, 104))
	row.add_child(_labeled("Current", _current))
	_upcoming_box = HBoxContainer.new()
	row.add_child(_labeled("Next", _upcoming_box))
	_reserve = _icon(Vector2(64, 64))
	row.add_child(_labeled("Set aside", _reserve))
	flow.add_child(cards)

	# Placement (top row) and seed actions (bottom row).
	var actions_panel := _panel()
	var grid := GridContainer.new()
	grid.columns = 4
	actions_panel.add_child(grid)
	_add_button(grid, "rotate", "Turn")
	_add_button(grid, "mirror", "Mirror")
	_add_button(grid, "place", "Place")
	_add_button(grid, "cancel", "Cancel")
	_add_button(grid, "set_aside", "Set aside")
	_add_button(grid, "use_reserve", "Use set-aside")
	_add_button(grid, "swap", "Swap next")
	_add_button(grid, "look_ahead", "Look ahead")
	flow.add_child(actions_panel)
	_buttons.place.add_theme_color_override("font_color", ACCENT)


## Phone layout: a smaller piece panel aligned to the right, smaller labels.
func set_compact(on: bool) -> void:
	if on == _compact and _current.custom_minimum_size.x > 0:
		return
	_compact = on
	_current.custom_minimum_size = Vector2(68, 68) if on else Vector2(104, 104)
	_small_icon = Vector2(42, 42) if on else Vector2(64, 64)
	_reserve.custom_minimum_size = _small_icon
	_reserve.empty_font_size = 13 if on else 18
	_reserve.queue_redraw()
	for c in _upcoming_box.get_children():
		(c as Control).custom_minimum_size = _small_icon
	for l in _card_labels:
		l.add_theme_font_size_override("font_size", 12 if on else 15)
	(_cards.get_node("row") as HBoxContainer).add_theme_constant_override("separation", 8 if on else 14)
	_cards.add_theme_stylebox_override("panel", _panel_style(6 if on else 12))
	_flow.alignment = FlowContainer.ALIGNMENT_END if on else FlowContainer.ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 17 if on else 19)


func _panel_style(margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(margin)
	sb.border_color = Color(0.2, 0.24, 0.2, 0.25)
	sb.set_border_width_all(1)
	return sb


## Label seed costs from the valley data once it is known.
func set_costs(costs: Dictionary) -> void:
	_buttons.set_aside.text = "Set aside (%d)" % int(costs.get("set_aside", 1))
	_buttons.swap.text = "Swap next (%d)" % int(costs.get("swap", 1))
	_buttons.look_ahead.text = "Look ahead (%d)" % int(costs.get("look_ahead", 2))


func _build_toast() -> void:
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.custom_minimum_size.x = 520
	_toast.offset_left = -260
	_toast.offset_right = 260
	_toast.offset_top = -120
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_color", ACCENT)
	_toast.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.92))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)


func _build_end() -> void:
	_end = _panel()
	_end.set_anchors_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_end.add_child(box)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_end_label)
	_end_stars = StarRow.new()
	_end_stars.custom_minimum_size = Vector2(150, 44)
	_end_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_end_stars)
	var legend := Label.new()
	legend.text = "Restored  ·  All residents  ·  Hidden visitor"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 14)
	box.add_child(legend)
	_end_note = Label.new()
	_end_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_note.add_theme_font_size_override("font_size", 18)
	_end_note.add_theme_color_override("font_color", ACCENT)
	box.add_child(_end_note)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	box.add_child(row)
	_add_button(row, "next", "Next valley")
	_buttons.next.add_theme_color_override("font_color", ACCENT)
	_add_button(row, "restart", "Play again")
	_add_button(row, "levels_end", "Valleys")
	_end.visible = false
	_root.add_child(_end)


func _build_levels() -> void:
	_levels = ColorRect.new()
	(_levels as ColorRect).color = Color(0.2, 0.18, 0.14, 0.45)
	_levels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_levels.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levels.add_child(center)
	var panel := _panel()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Bloomweave  ·  Valleys"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_levels_list = VBoxContainer.new()
	_levels_list.add_theme_constant_override("separation", 8)
	box.add_child(_levels_list)
	_levels_total = Label.new()
	_levels_total.add_theme_font_size_override("font_size", 14)
	_levels_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_levels_total)
	_add_button(box, "close_levels", "Back to the valley")
	_buttons.close_levels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_levels.visible = false
	_root.add_child(_levels)


# --- Helpers ------------------------------------------------------------------

func _icon(min_size: Vector2) -> PieceIcon:
	var icon := PieceIcon.new()
	icon.data = data
	icon.custom_minimum_size = min_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _labeled(text: String, content: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	_card_labels.append(l)
	box.add_child(l)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	return box


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _add_button(parent: Control, id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(122, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: action.emit(id))
	parent.add_child(b)
	_buttons[id] = b


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(12)
	panel.border_color = Color(0.2, 0.24, 0.2, 0.25)
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		match state:
			"normal":
				sb.bg_color = Color(0.93, 0.9, 0.82)
			"hover":
				sb.bg_color = Color(0.9, 0.86, 0.76)
			"pressed":
				sb.bg_color = Color(0.84, 0.79, 0.68)
			"disabled":
				sb.bg_color = Color(0.93, 0.9, 0.82, 0.45)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.draw_center = false
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.35))
	t.set_color("font_color", "Label", INK)
	return t
