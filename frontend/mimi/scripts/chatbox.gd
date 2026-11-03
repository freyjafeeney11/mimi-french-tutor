extends Control

# ---------------------------------------------------------------------------
# Bubble styling and layout configuration.
# ---------------------------------------------------------------------------
@export_group("Old look")
## Reuse the previous ChatDisplay theme when available.
@export var inherit_old_text_style := true
@export var keep_old_background := true

@export_group("Bubble art")
@export var mimi_bubble_texture: Texture2D
@export var user_bubble_texture: Texture2D
@export var tip_bubble_texture: Texture2D
## Bubble corner sizes that must not stretch.
@export var slice_margins := Vector4(24, 24, 24, 24)
## Padding between the bubble border and the text.
@export var padding := Vector4(18, 12, 18, 12)

@export_group("Mimi")
@export var mimi_avatar: Texture2D
@export var avatar_size := 64.0

@export_group("Text (ignored while 'Inherit Old Text Style' is on, except Chat Font if set)")
@export var chat_font: Font
@export var font_size := 20
@export var tip_font_size := 16
@export var text_color := Color("3b2f2f")

@export_group("Placeholder colors (used when no art is set)")
@export var mimi_color := Color("f3e6dd")
@export var user_color := Color("cfe3f5")
@export var tip_color := Color("fff2b8")

@export_group("Layout")
@export_range(0.3, 0.95) var bubble_max_ratio := 0.72
@export var message_spacing := 10

# ---------------------------------------------------------------------------

@onready var chat_display: Control = $VBoxContainer/ChatDisplay
@onready var input_field = $VBoxContainer/InputField
@onready var send_button = $VBoxContainer/SendButton
@onready var mode_toggle = $VBoxContainer/ModeToggle  # CheckBox: on = lesson mode

const CHAT_URL := "http://127.0.0.1:8000/chat"
const CORRECT_URL := "http://127.0.0.1:8000/correct"
const LESSON_START_URL := "http://127.0.0.1:8000/lesson/start"
const PROGRESS_URL := "http://127.0.0.1:8000/progress/"
const PROGRESS_DASHBOARD := preload("res://scenes/progress_dashboard.tscn")
const LEVELS := ["A1", "A2", "B1", "B2", "C1"]
const ACCENTS := ["à", "â", "ä", "ç", "é", "è", "ê", "ë", "î", "ï", "ô", "ö", "ù", "û", "ü", "ÿ", "œ", "æ"]

var is_lesson_mode := false
var level := "A2"
var session_id := ""
var user_id := ""
var waiting := false

var scroll: ScrollContainer
var messages: VBoxContainer
var typing_row: Control = null
var accent_bar: FlowContainer
var accent_buttons: Array[Button] = []
var _last_sender := ""
var recent_context: Array[Dictionary] = []
var lesson_starting := false
var lesson_topic_pending := false


func _ready() -> void:
	session_id = generate_session_id()
	user_id = _load_user_id()
	_replace_chat_display()
	_build_accent_menu()
	_update_input_placeholder()

	send_button.pressed.connect(_on_send_pressed)
	mode_toggle.toggled.connect(_on_mode_toggled)

	var progress_layer := CanvasLayer.new()
	progress_layer.name = "ProgressButtonLayer"
	add_child(progress_layer)
	var progress_overlay := Control.new()
	progress_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_layer.add_child(progress_overlay)

	var progress_button := Button.new()
	progress_button.name = "ProgressButton"
	progress_button.text = "MY PROGRESS"
	progress_button.anchor_left = 0.18
	progress_button.anchor_top = 0.82
	progress_button.anchor_right = 0.38
	progress_button.anchor_bottom = 0.89
	progress_button.offset_left = 0
	progress_button.offset_top = 0
	progress_button.offset_right = 0
	progress_button.offset_bottom = 0
	progress_button.custom_minimum_size = Vector2(150, 38)
	progress_overlay.add_child(progress_button)
	if chat_font:
		progress_button.add_theme_font_override("font", chat_font)
	progress_button.add_theme_font_size_override("font_size", font_size)
	progress_button.add_theme_color_override("font_color", text_color)
	progress_button.add_theme_stylebox_override("normal", _progress_button_style())
	progress_button.add_theme_stylebox_override("hover", _progress_button_style())
	progress_button.add_theme_stylebox_override("pressed", _progress_button_style())
	progress_button.pressed.connect(_open_progress_dashboard)

	if input_field is LineEdit:
		input_field.text_submitted.connect(func(_text): _on_send_pressed())

	var level_picker = get_node_or_null("VBoxContainer/LevelPicker")
	if level_picker is OptionButton:
		level_picker.clear()
		for l in LEVELS:
			level_picker.add_item(l)
		level_picker.select(LEVELS.find(level))
		level_picker.item_selected.connect(func(i): level = LEVELS[i])


func generate_session_id() -> String:
	return "session_%d_%d" % [Time.get_unix_time_from_system(), randi()]


func _load_user_id() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://mimi.cfg") == OK and cfg.has_section_key("user", "id"):
		return str(cfg.get_value("user", "id"))
	var id := "user_%d_%d" % [Time.get_unix_time_from_system(), randi()]
	cfg.set_value("user", "id", id)
	cfg.save("user://mimi.cfg")
	return id


func _replace_chat_display() -> void:
	var old := chat_display
	var parent := old.get_parent()
	var idx := old.get_index()

	var bg_style: StyleBox = null
	if inherit_old_text_style:
		_inherit_text_style(old)
	if keep_old_background and (old is TextEdit or old is RichTextLabel):
		bg_style = old.get_theme_stylebox("normal")

	var bg := PanelContainer.new()
	bg.name = "ChatBackground"
	bg.size_flags_horizontal = old.size_flags_horizontal
	bg.size_flags_vertical = old.size_flags_vertical
	bg.custom_minimum_size = old.custom_minimum_size
	bg.add_theme_stylebox_override("panel", bg_style if bg_style else StyleBoxEmpty.new())

	scroll = ScrollContainer.new()
	scroll.name = "ChatScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)

	messages = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_theme_constant_override("separation", message_spacing)
	margin.add_child(messages)

	parent.add_child(bg)
	parent.move_child(bg, idx)
	old.queue_free()

	var bar := scroll.get_v_scroll_bar()
	bar.changed.connect(func(): scroll.scroll_vertical = int(bar.max_value))


func _inherit_text_style(old: Control) -> void:
	var font_name := "font"
	var size_name := "font_size"
	var color_name := "font_color"
	if old is RichTextLabel:
		font_name = "normal_font"
		size_name = "normal_font_size"
		color_name = "default_color"

	if chat_font == null:
		chat_font = old.get_theme_font(font_name)
	font_size = old.get_theme_font_size(size_name)
	tip_font_size = maxi(font_size - 4, 10)
	text_color = old.get_theme_color(color_name)

	# Light text means the old background was dark, so use darker placeholder bubbles.
	if text_color.get_luminance() > 0.6:
		mimi_color = Color("3a3340")
		user_color = Color("46587a")
		tip_color = Color("5c5230")


# ------------------------------------------------------------------ input

func _on_mode_toggled(checked: bool) -> void:
	is_lesson_mode = checked
	lesson_topic_pending = checked
	recent_context.clear()
	_update_input_placeholder()
	if is_lesson_mode:
		_add_notice("Lesson mode · choose what you'd like to work on")
		_start_lesson()
	else:
		_add_notice("Conversational mode")




func _update_input_placeholder() -> void:
	# Mimi currently accepts typed answers only; there is no microphone or speech input.
	var hint := "Message Mimi..."
	if lesson_topic_pending:
		hint = "What would you like to work on today?"
	elif is_lesson_mode:
		hint = "Answer in French..."
	if input_field is LineEdit:
		input_field.placeholder_text = hint
	elif input_field is TextEdit:
		input_field.placeholder_text = hint


func _start_lesson() -> void:
	if lesson_starting:
		return
	lesson_starting = true
	_set_waiting(true)
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_lesson_start_completed.bind(http))
	var body := JSON.stringify({
		"session_id": session_id,
		"user_id": user_id,
		"message": "",
		"mode": "lesson",
		"level": level
	})
	var err := http.request(LESSON_START_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		lesson_starting = false
		_set_waiting(false)
		_add_bubble("[Could not start lesson mode. Check that the backend is running.]", "note")


func _on_lesson_start_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	lesson_starting = false
	_set_waiting(false)
	if response_code != 200:
		_add_bubble("[Lesson mode could not start (server code %d).]" % response_code, "note")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_add_bubble("[Invalid lesson response from server.]", "note")
		return
	for item in data.get("messages", []):
		if typeof(item) == TYPE_DICTIONARY:
			var lesson_prompt := str(item.get("text", ""))
			_add_bubble(lesson_prompt, "mimi")
			recent_context.append({"role": "assistant", "content": lesson_prompt})
			_trim_context()


func _open_progress_dashboard() -> void:
	var dashboard = PROGRESS_DASHBOARD.instantiate()
	dashboard.user_id = user_id
	dashboard.chat_font = chat_font
	get_tree().root.add_child(dashboard)


func _progress_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("dce2ea")
	style.border_color = Color("30323b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _request_progress() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_progress_completed.bind(http))
	var err := http.request(PROGRESS_URL + user_id)
	if err != OK:
		http.queue_free()
		_add_bubble("[Could not load progress.]", "note")


func _on_progress_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if response_code != 200:
		_add_bubble("[Could not load progress (server code %d).]" % response_code, "note")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var lines := ["ton niveau de départ : %s" % str(data.get("starting_level", level)),
		"tentatives enregistrées : %s" % str(data.get("recorded_lesson_attempts", 0))]
	var skills: Array = data.get("skills", [])
	if skills.is_empty():
		lines.append("on commence tout juste à mesurer tes compétences — fais quelques exercices !")
	else:
		for skill in skills:
			lines.append("%s : %s%% (%s essais)" % [str(skill.get("skill", "skill")).replace("_", " "), str(skill.get("score", 0)), str(skill.get("attempts", 0))])
	_add_bubble("\n".join(lines), "tip")


func _on_send_pressed() -> void:
	if waiting:
		return

	var user_text: String = input_field.text.strip_edges()
	if user_text == "":
		return

	var user_row := _add_bubble(user_text, "user")
	recent_context.append({"role": "user", "content": user_text})
	_trim_context()
	input_field.text = ""
	_send_message(user_text, user_row)


func _send_message(text: String, user_row: Control) -> void:
	_set_waiting(true)
	typing_row = _add_typing()

	var http := HTTPRequest.new()
	add_child(http)
	var topic_to_save := text if is_lesson_mode and lesson_topic_pending else ""
	http.request_completed.connect(_on_request_completed.bind(http, text, user_row, topic_to_save))

	var body := JSON.stringify({
		"session_id": session_id,
		"user_id": user_id,
		"message": text,
		"mode": "lesson" if is_lesson_mode else "chat",
		"level": level,
		"is_new_conversation": false,
		"lesson_started": false,
		"lesson_topic": topic_to_save,
	})
	var headers := ["Content-Type: application/json"]

	var err := http.request(CHAT_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_clear_typing()
		_add_bubble("[Error: could not send request (code %d)]" % err, "note")
		_set_waiting(false)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, text: String, user_row: Control, topic_to_save: String) -> void:
	http.queue_free()

	if response_code != 200:
		_clear_typing()
		if response_code == 0:
			_add_bubble("[Error: can't reach the server. Is uvicorn running?]", "note")
		else:
			_add_bubble("[Error: server returned code %d]" % response_code, "note")
		_set_waiting(false)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("messages"):
		_clear_typing()
		_add_bubble("[Error: invalid response from server]", "note")
		_set_waiting(false)
		return
	if topic_to_save != "" and is_lesson_mode and lesson_topic_pending:
		lesson_topic_pending = false
		_update_input_placeholder()

	# In lesson mode Mimi gives the feedback; casual chat uses the separate checker.
	if not is_lesson_mode:
		_request_correction(text, user_row)

	var bubbles: Array = data["messages"]
	for i in bubbles.size():
		var m: Dictionary = bubbles[i]
		var delay_s := float(m.get("delay_ms", 800)) / 1000.0
		if i == 0:
			delay_s = minf(delay_s, 1.0)  # the server already took a while
		if typing_row == null:
			typing_row = _add_typing()
		await get_tree().create_timer(delay_s).timeout
		_clear_typing()
		var mimi_text := str(m.get("text", ""))
		_add_bubble(mimi_text, "mimi")
		recent_context.append({"role": "assistant", "content": mimi_text})
		_trim_context()

	_set_waiting(false)


func _request_correction(text: String, user_row: Control) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_correction_completed.bind(http, user_row))

	var body := JSON.stringify({
		"message": text,
		"level": level,
		"user_id": user_id,
		"session_id": session_id,
		"context": recent_context
	})
	var err := http.request(CORRECT_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()


func _on_correction_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, user_row: Control) -> void:
	http.queue_free()
	if response_code != 200:
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return

	var correction = data.get("correction", null)
	if typeof(correction) != TYPE_DICTIONARY or not is_instance_valid(user_row):
		return
	var tip_parts: Array[String] = []
	var incorrect := str(correction.get("incorrect", "")).strip_edges()
	var corrected := str(correction.get("corrected", "")).strip_edges()
	var explanation := str(correction.get("explanation", "")).strip_edges()
	if incorrect != "" and corrected != "":
		tip_parts.append(incorrect + " → " + corrected)
	if explanation != "":
		tip_parts.append(explanation)
	var alternative := str(correction.get("natural_alternative", "")).strip_edges()
	if alternative != "":
		tip_parts.append("plus naturel : " + alternative)
	var tip := "\n".join(tip_parts)
	if tip == "":
		return

	var prev := _last_sender
	var row := _add_bubble(tip, "tip")
	_last_sender = prev
	messages.move_child(row, user_row.get_index() + 1)


func _trim_context() -> void:
	while recent_context.size() > 8:
		recent_context.pop_front()


func _set_waiting(value: bool) -> void:
	waiting = value
	send_button.disabled = value


func _add_bubble(text: String, sender: String) -> Control:
	var label := _make_label(text, sender)
	var panel := _make_panel(sender, label)
	var row := _wrap_row(sender, panel)
	messages.add_child(row)
	_fade_in(row)
	_last_sender = sender
	return row


func _add_typing() -> Control:
	var label := _make_label("...", "mimi")
	var panel := _make_panel("mimi", label)
	var row := _wrap_row("mimi", panel)
	messages.add_child(row)
	_fade_in(row)

	var tw := row.create_tween().set_loops()
	tw.tween_callback(func(): label.text = ".")
	tw.tween_interval(0.3)
	tw.tween_callback(func(): label.text = "..")
	tw.tween_interval(0.3)
	tw.tween_callback(func(): label.text = "...")
	tw.tween_interval(0.3)
	return row


func _clear_typing() -> void:
	if is_instance_valid(typing_row):
		typing_row.queue_free()
	typing_row = null


func _add_notice(text: String) -> void:
	var label := Label.new()
	label.text = "— " + text + " —"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", tip_font_size)
	if chat_font:
		label.add_theme_font_override("font", chat_font)
	label.add_theme_color_override("font_color", text_color.lightened(0.3))
	messages.add_child(label)
	_last_sender = "notice"


func _make_label(text: String, sender: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fs := tip_font_size if (sender == "tip" or sender == "note") else font_size
	label.add_theme_font_size_override("font_size", fs)
	if chat_font:
		label.add_theme_font_override("font", chat_font)
	label.add_theme_color_override("font_color", text_color)

	var font := label.get_theme_font("font")
	var natural := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	label.custom_minimum_size.x = clampf(natural + 2.0, 10.0, _max_bubble_width())
	return label


func _make_panel(sender: String, label: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _style_for(sender))
	panel.add_child(label)
	return panel


func _style_for(sender: String) -> StyleBox:
	var tex: Texture2D = null
	var color := mimi_color
	match sender:
		"user":
			tex = user_bubble_texture
			color = user_color
		"tip", "note":
			tex = tip_bubble_texture
			color = tip_color
		_:
			tex = mimi_bubble_texture

	if tex:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = slice_margins.x
		sb.texture_margin_top = slice_margins.y
		sb.texture_margin_right = slice_margins.z
		sb.texture_margin_bottom = slice_margins.w
		sb.content_margin_left = padding.x
		sb.content_margin_top = padding.y
		sb.content_margin_right = padding.z
		sb.content_margin_bottom = padding.w
		return sb

	var flat := StyleBoxFlat.new()
	flat.bg_color = color
	flat.set_corner_radius_all(18)
	flat.content_margin_left = padding.x
	flat.content_margin_top = padding.y
	flat.content_margin_right = padding.z
	flat.content_margin_bottom = padding.w
	return flat


func _wrap_row(sender: String, panel: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on_right := sender == "user" or sender == "tip"
	row.alignment = BoxContainer.ALIGNMENT_END if on_right else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)

	if not on_right and mimi_avatar:
		if sender == "mimi" and _last_sender != "mimi":
			# Avatar only on the first bubble of each Mimi message group.
			var avatar := TextureRect.new()
			avatar.texture = mimi_avatar
			avatar.custom_minimum_size = Vector2(avatar_size, avatar_size)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(avatar)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(avatar_size, 0)
			row.add_child(spacer)

	row.add_child(panel)
	return row


func _max_bubble_width() -> float:
	var w := scroll.size.x if scroll else 0.0
	if w < 100.0:
		w = 600.0  # window not laid out yet
	var avatar_w := avatar_size + 8.0 if mimi_avatar else 0.0
	return w * bubble_max_ratio - avatar_w - padding.x - padding.z


func _fade_in(node: Control) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.18)



func _build_accent_menu() -> void:
	var parent := input_field.get_parent()
	var idx := input_field.get_index()

	var row := HBoxContainer.new()
	row.name = "InputRow"
	parent.add_child(row)
	parent.move_child(row, idx)
	input_field.reparent(row)
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var toggle := Button.new()
	toggle.text = "é"
	toggle.tooltip_text = "Accents"
	toggle.toggle_mode = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on: bool): accent_bar.visible = on)
	row.add_child(toggle)

	accent_bar = FlowContainer.new()
	accent_bar.visible = false
	parent.add_child(accent_bar)
	parent.move_child(accent_bar, idx + 1)

	var shift := Button.new()
	shift.text = "⇧"
	shift.tooltip_text = "Capital letters"
	shift.toggle_mode = true
	shift.focus_mode = Control.FOCUS_NONE
	shift.toggled.connect(_on_accent_case_toggled)
	accent_bar.add_child(shift)

	for ch in ACCENTS:
		var b := Button.new()
		b.text = ch
		b.set_meta("base", ch)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(36, 0)
		b.pressed.connect(_insert_accent.bind(b))
		accent_bar.add_child(b)
		accent_buttons.append(b)


func _on_accent_case_toggled(on: bool) -> void:
	for b in accent_buttons:
		var base: String = b.get_meta("base")
		b.text = base.to_upper() if on else base


func _insert_accent(b: Button) -> void:
	input_field.insert_text_at_caret(b.text)
	input_field.grab_focus()