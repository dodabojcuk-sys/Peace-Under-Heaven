class_name RegularCitySpatialFoundation
extends Node2D


const CityGateComponent = preload("res://scripts/city_gate_component_r1.gd")

const MAP_SIZE := Vector2(2200.0, 1400.0)
const GATE_LAYOUT := [
	{"name": "NorthGate", "position": Vector2(1100.0, 54.0), "orientation": 0},
	{"name": "EastGate", "position": Vector2(2146.0, 700.0), "orientation": 1},
	{"name": "SouthGate", "position": Vector2(1100.0, 1346.0), "orientation": 2},
	{"name": "WestGate", "position": Vector2(54.0, 700.0), "orientation": 3},
]

const BUILDING_LABELS := {
	"Manor": "城主府",
	"Barracks": "兵营",
	"Granary": "粮仓",
	"Academy": "书院",
	"CommandPlatform": "军令台",
	"Noticeboard": "告示板",
}

var _fixed_building_proxies: Array[Dictionary] = []


func _ready() -> void:
	z_index = -1
	_collect_fixed_building_proxies()
	_hide_legacy_visual_layer()
	_install_gate_instances()
	queue_redraw()


func _collect_fixed_building_proxies() -> void:
	for node_name in [
		"Manor",
		"Barracks",
		"Granary",
		"Academy",
		"CommandPlatform",
		"Noticeboard",
	]:
		var legacy_node := get_parent().get_node_or_null(node_name) as ColorRect
		if legacy_node == null:
			continue
		_fixed_building_proxies.append({
			"rect": Rect2(legacy_node.position, legacy_node.size),
			"name": node_name,
			"color": legacy_node.color,
		})
		# The original control remains the single fixed-building selection owner.
		# This foundation only replaces its flat-card visual, never its state.
		legacy_node.visible = false


func _hide_legacy_visual_layer() -> void:
	# The original MapWorld children remain state and selection anchors where
	# applicable, but their card/road artwork must not compete with the R1 city.
	for sibling in get_parent().get_children():
		if sibling == self or sibling.name == "ConstructionLayer":
			continue
		if sibling is CanvasItem:
			(sibling as CanvasItem).visible = false


func _install_gate_instances() -> void:
	var container := Node2D.new()
	container.name = "GateInstances"
	add_child(container)
	for gate_data in GATE_LAYOUT:
		var gate := CityGateComponent.new() as CityGateComponentR1
		gate.name = str(gate_data.name)
		gate.position = Vector2(gate_data.position)
		gate.configure(int(gate_data.orientation), "%s城门" % str(gate_data.name))
		container.add_child(gate)


func _draw() -> void:
	# Regular axial city: walls, a civic axis, and distinct wards. This is a
	# graybox spatial layer, intentionally without a permanent logic grid.
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("c6bea2"), true)
	draw_rect(Rect2(Vector2(28.0, 28.0), MAP_SIZE - Vector2(56.0, 56.0)), Color("6d7164"), false, 18.0)
	draw_rect(Rect2(Vector2(74.0, 74.0), MAP_SIZE - Vector2(148.0, 148.0)), Color("d7cfb2"), true)
	_draw_ward(Rect2(150.0, 130.0, 620.0, 410.0), Color("c8bea2"))
	_draw_ward(Rect2(835.0, 130.0, 530.0, 410.0), Color("cec5a9"))
	_draw_ward(Rect2(1430.0, 130.0, 580.0, 410.0), Color("c8bea2"))
	_draw_ward(Rect2(150.0, 770.0, 620.0, 430.0), Color("cec5a9"))
	_draw_ward(Rect2(835.0, 770.0, 530.0, 430.0), Color("c8bea2"))
	_draw_ward(Rect2(1430.0, 770.0, 580.0, 430.0), Color("cec5a9"))
	_draw_road(Rect2(1020.0, 74.0, 160.0, 1252.0))
	_draw_road(Rect2(74.0, 630.0, 2052.0, 140.0))
	# This is an open civic court rather than a foreground gate: it anchors the
	# axial roads without becoming a dominant facade in the default viewport.
	var civic_courtyard := Rect2(1010.0, 610.0, 180.0, 150.0)
	draw_rect(civic_courtyard, Color("b89352"), true)
	draw_rect(civic_courtyard, Color("755c35"), false, 4.0)
	draw_rect(civic_courtyard.grow(-24.0), Color("d8cda8"), true)
	draw_circle(civic_courtyard.get_center(), 18.0, Color("a57d3e"))
	for proxy in _fixed_building_proxies:
		_draw_graybox_building(
			Rect2(proxy.rect),
			Color(proxy.color),
			str(BUILDING_LABELS.get(str(proxy.name), str(proxy.name)))
		)


func _draw_ward(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect.grow(-20.0), Color("dcd4ba"), false, 3.0)
	# These are non-interactive ward volumes, not selectable production
	# buildings. They make the foundation read as a city before art production.
	for local_rect in [
		Rect2(54.0, 60.0, 100.0, 72.0),
		Rect2(rect.size.x - 174.0, 74.0, 112.0, 78.0),
		Rect2(rect.size.x * 0.5 - 54.0, rect.size.y - 126.0, 108.0, 74.0),
	]:
		_draw_ambient_volume(
			Rect2(rect.position + local_rect.position, local_rect.size)
		)


func _draw_ambient_volume(rect: Rect2) -> void:
	var shadow := Rect2(rect.position + Vector2(10.0, 13.0), rect.size)
	draw_rect(shadow, Color(0.17, 0.17, 0.14, 0.18), true)
	draw_rect(rect, Color("a29b7e"), true)
	var roof := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x * 0.5, -18.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(rect.size.x, 24.0),
		rect.position + Vector2(0.0, 24.0),
	])
	draw_colored_polygon(roof, Color("c2ad7b"))
	draw_rect(rect, Color("756c56"), false, 2.0)


func _draw_road(rect: Rect2) -> void:
	draw_rect(rect, Color("8f8060"), true)
	draw_line(rect.position + Vector2(0.0, rect.size.y * 0.5), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5), Color("c6b889"), 3.0)


func _draw_graybox_building(rect: Rect2, color: Color, label: String) -> void:
	var shadow := Rect2(rect.position + Vector2(14.0, 18.0), rect.size)
	draw_rect(shadow, Color(0.14, 0.16, 0.14, 0.28), true)
	var roof_height := minf(28.0, rect.size.y * 0.28)
	var roof := PackedVector2Array([
		rect.position + Vector2(0.0, roof_height),
		rect.position + Vector2(rect.size.x * 0.5, 0.0),
		rect.position + Vector2(rect.size.x, roof_height),
		rect.position + Vector2(rect.size.x, rect.size.y * 0.46),
		rect.position + Vector2(0.0, rect.size.y * 0.46),
	])
	draw_colored_polygon(roof, color.lightened(0.16))
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y * 0.46), Vector2(rect.size.x, rect.size.y * 0.54)), color.darkened(0.16), true)
	draw_rect(rect, color.darkened(0.38), false, 3.0)
	var door := Rect2(rect.get_center() + Vector2(-12.0, rect.size.y * 0.26), Vector2(24.0, 18.0))
	draw_rect(door, Color("222b29"), true)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10.0, 24.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20.0, 15, Color("f2efe1"))
