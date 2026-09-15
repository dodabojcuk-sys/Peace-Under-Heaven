class_name RegularCampaignCityHost
extends Node2D

## Presentation-only projection of campaign-local buildings into the established
## city MapWorld. Runtime commands and persistence remain owned by
## RegularCampaignRuntime; this node only supplies visuals and hit records to the
## existing map/selection controllers.

const BUILDING_VISUAL = preload("res://scripts/graybox_building_visual.gd")
const PALETTE = preload("res://resources/visuals/northern_campaign_palette.gd")
const BUILDING_ART := {
	&"FARM": preload("res://assets/regular_campaign/art_r1/runtime/farm.png"),
	&"LOGGING": preload("res://assets/regular_campaign/art_r1/runtime/logging.png"),
	&"WAREHOUSE": preload("res://assets/regular_campaign/art_r1/runtime/warehouse.png"),
	&"CLINIC": preload("res://assets/regular_campaign/art_r1/runtime/clinic.png"),
}

const GRID_SIZE := 40.0
const PLACEMENT_ID_BASE := 900000
const PLOT_CELLS := [
	Vector2i(9, 8), Vector2i(19, 8), Vector2i(36, 8),
	Vector2i(9, 18), Vector2i(19, 18), Vector2i(36, 18),
]
const PLOT_FOOTPRINTS := [
	Vector2i(4, 3), Vector2i(4, 3), Vector2i(4, 3),
	Vector2i(4, 3), Vector2i(4, 3), Vector2i(4, 3),
]

var _model: Dictionary = {}
var _records_by_placement_id: Dictionary = {}
var _visuals_by_placement_id: Dictionary = {}
var _selected_plot := -1
var _last_production_totals: Dictionary = {}
var _production_totals_ready := false
var _buildable_plots_visible := false


func sync(model: Dictionary) -> void:
	_model = model.duplicate(true)
	var local := Dictionary(_model.get("local", {}))
	var records: Array = Array(local.get("buildings", [])).duplicate(true)
	var project := Dictionary(local.get("project", {}))
	var seen: Dictionary = {}
	_records_by_placement_id.clear()
	for value in records:
		_sync_record(Dictionary(value), false, seen)
	if not project.is_empty():
		_sync_record(project, true, seen)
	for placement_id_value in _visuals_by_placement_id.keys():
		var placement_id := int(placement_id_value)
		if seen.has(placement_id):
			continue
		var stale := _visuals_by_placement_id[placement_id] as Node
		if is_instance_valid(stale):
			stale.queue_free()
		_visuals_by_placement_id.erase(placement_id)
	_sync_production_feedback()
	queue_redraw()


func set_selected_plot(plot: int) -> void:
	_selected_plot = plot if plot >= 0 and plot < PLOT_CELLS.size() else -1
	for placement_id_value in _visuals_by_placement_id:
		var placement_id := int(placement_id_value)
		var visual := _visuals_by_placement_id[placement_id] as GrayboxBuildingVisual
		if is_instance_valid(visual):
			var record := get_record(placement_id)
			var selected := int(record.get("plot", -1)) == _selected_plot
			visual.set_selected_state(selected, selected or not bool(record.get("connected", false)))
	queue_redraw()


func set_buildable_plots_visible(visible: bool) -> void:
	_buildable_plots_visible = visible
	queue_redraw()


func get_selected_plot() -> int:
	return _selected_plot


func get_plot_at_world_position(world_position: Vector2) -> int:
	for plot in range(PLOT_CELLS.size()):
		if _plot_rect(plot).has_point(world_position):
			return plot
	return -1


func get_placement_ids() -> Array[int]:
	var result: Array[int] = []
	for placement_id_value in _records_by_placement_id:
		result.append(int(placement_id_value))
	result.sort()
	return result


func get_record(placement_id: int) -> Dictionary:
	return Dictionary(_records_by_placement_id.get(placement_id, {})).duplicate(true)


func get_visual(placement_id: int) -> CanvasItem:
	var visual := _visuals_by_placement_id.get(placement_id) as CanvasItem
	return visual if is_instance_valid(visual) else null


func get_placement_id_for_node(node: CanvasItem) -> int:
	if not is_instance_valid(node) or not node.has_meta("regular_campaign_placement_id"):
		return -1
	return int(node.get_meta("regular_campaign_placement_id"))


func set_diagnostic_visible(placement_id: int, visible: bool) -> void:
	var visual := get_visual(placement_id) as GrayboxBuildingVisual
	if visual == null:
		return
	var record := get_record(placement_id)
	visual.set_selected_state(visible, visible or not bool(record.get("connected", false)))
	if visible:
		_selected_plot = int(record.get("plot", -1))
	queue_redraw()


func _sync_record(source: Dictionary, constructing: bool, seen: Dictionary) -> void:
	var plot := int(source.get("plot", -1))
	if plot < 0 or plot >= PLOT_CELLS.size():
		return
	var placement_id := PLACEMENT_ID_BASE + plot
	seen[placement_id] = true
	var kind := StringName(source.get("kind", &""))
	var style := _building_style(kind)
	var progress := 1.0
	if constructing:
		progress = clampf(
			float(source.get("progress_ms", 0)) / maxf(float(source.get("required_ms", 1)), 1.0),
			0.0,
			1.0
		)
	var visual := _visuals_by_placement_id.get(placement_id) as GrayboxBuildingVisual
	if visual == null:
		visual = BUILDING_VISUAL.new()
		visual.name = "CampaignPlot%d" % (plot + 1)
		visual.position = Vector2(PLOT_CELLS[plot]) * GRID_SIZE
		visual.set_meta("placement_id", placement_id)
		visual.set_meta("regular_campaign_placement_id", placement_id)
		add_child(visual)
		_visuals_by_placement_id[placement_id] = visual
	visual.configure(
		StringName(style.definition_id), String(style.display_name), String(style.building_type),
		PLOT_FOOTPRINTS[plot], 0, Color(style.body_color), Color(style.outline_color),
		true, false, &"constructing" if constructing else &"running", progress,
		&"connected" if bool(source.get("connected", false)) else &"disconnected"
	)
	if BUILDING_ART.has(kind):
		visual.set_art_texture(BUILDING_ART[kind])
	var selected := plot == _selected_plot
	visual.update_presentation(
		&"constructing" if constructing else &"running",
		progress,
		&"connected" if bool(source.get("connected", false)) else &"disconnected",
		selected,
		selected or not bool(source.get("connected", false))
	)
	var paused := bool(_model.get("paused", false))
	var operational := (
		not constructing
		and bool(source.get("connected", false))
		and int(source.get("workers", 0)) > 0
	)
	visual.set_activity_state(
		constructing and bool(source.get("advancing", true)) and not paused,
		operational and not paused,
		paused
	)
	var record := source.duplicate(true)
	record.merge({
		"placement_id": placement_id,
		"template_id": StringName("regular_%s" % String(kind).to_lower()),
		"definition_id": StringName(style.definition_id),
		"display_name": String(style.display_name),
		"placement_kind": &"placed",
		"lifecycle_state": &"constructing" if constructing else &"running",
		"selectable": true,
		"removable": false,
		"requires_road": true,
		"orientation": 0,
		"footprint": PLOT_FOOTPRINTS[plot],
		"selection_bounds": Rect2(Vector2.ZERO, Vector2(PLOT_FOOTPRINTS[plot]) * GRID_SIZE),
		"node": visual,
		"connected": bool(source.get("connected", false)),
	}, true)
	_records_by_placement_id[placement_id] = record


func _sync_production_feedback() -> void:
	var totals := Dictionary(_model.get("totals", {}))
	if not _production_totals_ready:
		_last_production_totals = totals.duplicate(true)
		_production_totals_ready = true
		return
	var changes := {
		&"FARM": int(totals.get("food_produced", 0)) - int(_last_production_totals.get("food_produced", 0)),
		&"LOGGING": int(totals.get("wood_produced", 0)) - int(_last_production_totals.get("wood_produced", 0)),
	}
	for kind in changes:
		var amount := int(changes[kind])
		if amount <= 0:
			continue
		for placement_id in _records_by_placement_id:
			var record := Dictionary(_records_by_placement_id[placement_id])
			if StringName(record.get("kind", &"")) != kind:
				continue
			var visual := get_visual(int(placement_id)) as GrayboxBuildingVisual
			if visual != null:
				visual.show_deposit(amount, "粮" if kind == &"FARM" else "木")
			break
	_last_production_totals = totals.duplicate(true)


func _draw() -> void:
	if not _buildable_plots_visible and _selected_plot < 0:
		return
	for plot in range(PLOT_CELLS.size()):
		if _records_by_placement_id.has(PLACEMENT_ID_BASE + plot):
			continue
		if not _buildable_plots_visible and plot != _selected_plot:
			continue
		var rect := _plot_rect(plot).grow(-4.0)
		var color := PALETTE.COPPER_GOLD if plot == _selected_plot else Color(PALETTE.INK_TEAL, 0.62)
		draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, 2.0, 10.0)
		draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, 2.0, 10.0)
		draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, 2.0, 10.0)
		draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, 2.0, 10.0)
		# R1B：给空地画上编号，与「点击城内有编号的空地」的指引文案对应。
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(6.0, 20.0),
			str(plot + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			color
		)


func _plot_rect(plot: int) -> Rect2:
	if plot < 0 or plot >= PLOT_CELLS.size():
		return Rect2()
	return Rect2(
		Vector2(PLOT_CELLS[plot]) * GRID_SIZE,
		Vector2(PLOT_FOOTPRINTS[plot]) * GRID_SIZE
	)


func _building_style(kind: StringName) -> Dictionary:
	match kind:
		&"FARM":
			return {"definition_id": &"farm", "display_name": "农田", "building_type": "农业", "body_color": PALETTE.JADE, "outline_color": PALETTE.INK_TEAL}
		&"LOGGING":
			return {"definition_id": &"logging_camp", "display_name": "伐木场", "building_type": "采集", "body_color": PALETTE.COPPER_GOLD, "outline_color": PALETTE.INK_BLUE}
		&"WAREHOUSE":
			return {"definition_id": &"warehouse", "display_name": "仓储", "building_type": "仓储", "body_color": PALETTE.GROUND_COOL, "outline_color": PALETTE.INK_TEAL}
		&"CLINIC":
			return {"definition_id": &"clinic", "display_name": "医舍", "building_type": "医疗", "body_color": PALETTE.GROUND_PALE, "outline_color": PALETTE.INK_BLUE}
	return {"definition_id": &"building", "display_name": "设施", "building_type": "设施", "body_color": PALETTE.GROUND_COOL, "outline_color": PALETTE.INK_TEAL}
