extends CanvasLayer
## Full-screen, text-first learner dashboard.
## Values are fetched from the existing FastAPI /progress/{user_id} endpoint.
signal closed

const PROGRESS_URL := "http://127.0.0.1:8000/progress/"

var user_id := ""
var chat_font: Font
var root_control: Control
var content: VBoxContainer
var topic_status_label: Label
var topic_list: VBoxContainer
var topic_scroll: ScrollContainer
var topic_viewport: Control
var focus_label: Label
var topics_label: Label

const BG := Color("#30323B")
const INK := Color("#292A2E")
const MUTED := Color("#777873")
const GREEN := Color("#527A68")
const CARD := Color("#DCE2EA")
const PANEL_TEXTURE := preload("res://art/background.png")
const MIMI_TEXTURE := preload("res://art/mimi_Face.png")

func _ready() -> void:
    _build_ui()
    _load_progress()

func _build_ui() -> void:
    root_control = Control.new()
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_STOP
    var background := ColorRect.new()
    background.color = BG
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.add_child(background)

    var layout_margin := MarginContainer.new()
    layout_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout_margin.add_theme_constant_override("margin_left", 18)
    layout_margin.add_theme_constant_override("margin_right", 18)
    layout_margin.add_theme_constant_override("margin_top", 12)
    layout_margin.add_theme_constant_override("margin_bottom", 12)
    root_control.add_child(layout_margin)

    var layout := HBoxContainer.new()
    layout.add_theme_constant_override("separation", 0)
    layout_margin.add_child(layout)

    var portrait_area := Control.new()
    portrait_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portrait_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    portrait_area.size_flags_stretch_ratio = 0.85
    layout.add_child(portrait_area)

    var portrait_background := TextureRect.new()
    portrait_background.texture = PANEL_TEXTURE
    portrait_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    portrait_area.add_child(portrait_background)

    var portrait := TextureRect.new()
    portrait.texture = MIMI_TEXTURE
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    portrait_area.add_child(portrait)

    var panel := Control.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.size_flags_stretch_ratio = 1.15
    layout.add_child(panel)

    var panel_background := TextureRect.new()
    panel_background.texture = PANEL_TEXTURE
    panel_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    panel_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    panel_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.add_child(panel_background)

    var panel_margin := MarginContainer.new()
    panel_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel_margin.add_theme_constant_override("margin_left", 72)
    panel_margin.add_theme_constant_override("margin_right", 72)
    panel_margin.add_theme_constant_override("margin_top", 54)
    panel_margin.add_theme_constant_override("margin_bottom", 54)
    panel.add_child(panel_margin)

    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 14)
    panel_margin.add_child(page)

    var header := HBoxContainer.new()
    page.add_child(header)
    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)
    title_box.add_child(_label("MON FRANÇAIS", 13, MUTED, true))
    title_box.add_child(_label("Learning overview", 32, INK, true))
    var back := Button.new()
    back.text = "←  BACK TO MIMI"
    back.custom_minimum_size = Vector2(150, 44)
    if chat_font:
        back.add_theme_font_override("font", chat_font)
    back.add_theme_color_override("font_color", INK)
    back.add_theme_stylebox_override("normal", _flat(CARD, 12))
    back.pressed.connect(func(): closed.emit(); queue_free())
    header.add_child(back)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    page.add_child(scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    scroll.add_child(content)

    var topics_card := _card()
    content.add_child(topics_card)
    topics_card.get_child(0).add_child(_label("TOPICS YOU'VE CHOSEN", 18, INK, true))
    topic_status_label = _label("Loading lesson topics…", 14, MUTED)
    topics_card.get_child(0).add_child(topic_status_label)

    topic_viewport = Control.new()
    topic_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topics_card.get_child(0).add_child(topic_viewport)

    topic_scroll = ScrollContainer.new()
    topic_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    topic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    topic_viewport.add_child(topic_scroll)

    topic_list = VBoxContainer.new()
    topic_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topic_list.add_theme_constant_override("separation", 4)
    topic_scroll.add_child(topic_list)

    var focus_card := _card()
    content.add_child(focus_card)
    focus_card.get_child(0).add_child(_label("WHAT TO DO NEXT", 12, MUTED, true))
    focus_label = _label("Switch on Lesson Mode and tell Mimi what you'd like to practise.", 18, INK, true)
    focus_card.get_child(0).add_child(focus_label)

    var activity_card := _card()
    content.add_child(activity_card)
    activity_card.get_child(0).add_child(_label("YOUR LEARNING LIST", 18, INK, true))
    topics_label = _label("0 saved lesson topics", 15, MUTED)
    activity_card.get_child(0).add_child(topics_label)

    var note := _label("This list remembers lesson topics you choose. Casual chats stay separate, and saved topics aren't mastery scores.", 13, MUTED)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(note)

    add_child(root_control)

func _load_progress() -> void:
    var request := HTTPRequest.new()
    add_child(request)
    request.request_completed.connect(_on_progress_loaded.bind(request))
    var err := request.request(PROGRESS_URL + user_id.uri_encode())
    if err != OK:
        request.queue_free()
        topic_status_label.text = "Couldn't contact Mimi's learning server."

func _on_progress_loaded(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
    request.queue_free()
    if code != 200:
        topic_status_label.text = "Progress is unavailable right now (server %d)." % code
        return
    var data = JSON.parse_string(body.get_string_from_utf8())
    if typeof(data) != TYPE_DICTIONARY:
        topic_status_label.text = "The server returned an unreadable progress profile."
        return

    var topics: Array = data.get("topics", [])
    topics_label.text = "%d saved lesson topics" % topics.size()
    topic_viewport.visible = not topics.is_empty()
    topic_viewport.custom_minimum_size.y = minf(
        topics.size() * 24.0 + maxi(topics.size() - 1, 0) * 4.0,
        220.0
    )
    for child in topic_list.get_children():
        child.queue_free()
    if topics.is_empty():
        topic_status_label.text = "No topics saved yet. Start Lesson Mode and tell Mimi what you'd like to work on."
        focus_label.text = "Choose a topic in Lesson Mode to start a short, practical lesson."
        return

    topic_status_label.text = "Saved from recent lesson requests. Mention one again to revisit it."
    focus_label.text = "In Lesson Mode, ask to revisit a saved topic or explore something new."
    for item in topics:
        if typeof(item) == TYPE_DICTIONARY:
            _add_topic(str(item.get("topic", "French")), str(item.get("status", "practising")))

func _add_topic(topic: String, status: String) -> void:
    var line := HBoxContainer.new()
    topic_list.add_child(line)
    var name_label := _label(topic, 16, INK, true)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    line.add_child(name_label)
    var status_text := "Practising"
    match status:
        "review": status_text = "Revisit"
        "mastered": status_text = "Marked learned"
    line.add_child(_label(status_text, 13, GREEN))

func _card() -> PanelContainer:
    var panel := PanelContainer.new()
    var style := _flat(CARD, 16)
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 16
    style.content_margin_bottom = 16
    panel.add_theme_stylebox_override("panel", style)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 9)
    panel.add_child(box)
    return panel

func _label(value: String, size: int, color: Color, bold := false) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    if chat_font:
        label.add_theme_font_override("font", chat_font)
    label.add_theme_color_override("font_color", color)
    if bold:
        label.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _flat(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style
