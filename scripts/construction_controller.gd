extends Node


signal placing_started
signal construction_interaction_started
signal building_removed(placement_id: int)
signal city_state_changed

enum ConstructionState {
	IDLE,
	CHOOSING_TEMPLATE,
	PLACING,
}

const GRID_SIZE := 40.0
const GRID_ORIGIN := Vector2.ZERO
const PLACEMENT_KIND_FIXED := &"fixed"
const PLACEMENT_KIND_PLACED := &"placed"
const PLACEMENT_KIND_ROAD := &"road"
const ROAD_ROOT_CELLS: Array[Vector2i] = [Vector2i(7, 4)]
const BASE_RESOURCE_CAPACITY := 160
const UI_SAFETY_MARGIN := 8.0
const PREVIEW_VALID_COLOR := Color(0.31, 0.62, 0.43, 0.72)
const PREVIEW_INVALID_COLOR := Color(0.72, 0.31, 0.28, 0.72)
const PREVIEW_VALID_OUTLINE := Color(0.12, 0.34, 0.2, 1.0)
const PREVIEW_INVALID_OUTLINE := Color(0.42, 0.12, 0.1, 1.0)
const ROAD_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/road.tres"
)
const LOGGING_CAMP_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/logging_camp.tres"
)
const FARM_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/farm.tres"
)
const WAREHOUSE_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/warehouse.tres"
)
const WATCHTOWER_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/watchtower.tres"
)
const FIRST_MAP_THREAT_SCHEDULE: ThreatSchedule = preload(
	"res://resources/definitions/threats/first_map_v0.tres"
)
const INFANTRY_ROLE: UnitRole = preload(
	"res://resources/definitions/units/infantry_basic.tres"
)
const GENERAL_DEFINITIONS: Array[GeneralArchetype] = [
	preload("res://resources/definitions/generals/vanguard.tres"),
	preload("res://resources/definitions/generals/defender.tres"),
	preload("res://resources/definitions/generals/quartermaster.tres"),
]
const TECH_DEFINITIONS: Array[TechNode] = [
	preload("res://resources/definitions/tech/stone_tools.tres"),
	preload("res://resources/definitions/tech/formation_drill.tres"),
	preload("res://resources/definitions/tech/rotational_recruitment.tres"),
]
const BASE_RECRUITMENT_CAP := 50
const BASE_TRAINING_BATCH := 5
const EMERGENCY_MOBILIZATION_FOOD_COST := 30
const EMERGENCY_MOBILIZATION_INFANTRY := 5
const SECONDS_PER_DAY := 60.0
const BATTLE_PHASE_RESERVED := &"RESERVED"
const BATTLE_PHASE_ACTIVE := &"ACTIVE"
const BATTLE_PHASE_RESULT_PENDING := &"RESULT_PENDING"
const BATTLE_PHASE_APPLIED := &"APPLIED"
const BATTLE_PHASE_CANCELLED := &"CANCELLED"
const TEST_BUILDING_FOOTPRINT := Vector2i(2, 2)
const TEST_BUILDING_WORLD_SIZE := Vector2(80.0, 80.0)
const PRESET_BUILDING_DEFINITIONS := [
	{
		"node_path": "../MapWorld/Manor",
		"template_id": &"manor",
		"display_name": "城主府 L1",
		"description": "城市行政中枢；道路网络从其右侧根格开始",
	},
	{
		"node_path": "../MapWorld/Barracks",
		"template_id": &"barracks",
		"display_name": "兵营 L1",
		"description": "军事训练设施（P1-D 接入征募）",
	},
	{
		"node_path": "../MapWorld/Granary",
		"template_id": &"granary",
		"display_name": "粮仓 L2",
		"description": "城市粮食储备（P1-B 接入容量）",
	},
	{
		"node_path": "../MapWorld/Academy",
		"template_id": &"academy",
		"display_name": "学院 L1",
		"description": "研究与教育设施（P1-D 接入科技）",
	},
	{
		"node_path": "../MapWorld/CityGate",
		"template_id": &"city_gate",
		"display_name": "城门 L1",
		"description": "城市出入口（P1-C 接入城防）",
	},
	{
		"node_path": "../MapWorld/CommandPlatform",
		"template_id": &"command_platform",
		"display_name": "军令台 L1",
		"description": "军事命令设施（真实战役契约接入前不提供假入口）",
	},
]

@onready var map_world: Node2D = $"../MapWorld"
@onready var map_board: Control = $"../MapWorld/MapBoard"
@onready var placed_buildings: Node2D = $"../MapWorld/ConstructionLayer/PlacedBuildings"
@onready var construction_preview: Node2D = $"../MapWorld/ConstructionLayer/ConstructionPreview"
@onready var preview_body: Polygon2D = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Body"
)
@onready var preview_outline: Line2D = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Outline"
)
@onready var preview_label: Label = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Label"
)
@onready var construction_entry_panel: Control = (
	$"../UI/Shell/ConstructionEntryPanel"
)
@onready var build_entry_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/BuildEntryButton"
)
@onready var build_mode_status: Label = (
	$"../UI/Shell/ConstructionEntryPanel/BuildModeStatus"
)
@onready var construction_menu: Control = $"../UI/Shell/ConstructionMenu"
@onready var road_button: Button = $"../UI/Shell/ConstructionMenu/RoadButton"
@onready var logging_camp_button: Button = (
	$"../UI/Shell/ConstructionMenu/LoggingCampButton"
)
@onready var farm_button: Button = $"../UI/Shell/ConstructionMenu/FarmButton"
@onready var warehouse_button: Button = (
	$"../UI/Shell/ConstructionMenu/WarehouseButton"
)
@onready var watchtower_button: Button = (
	$"../UI/Shell/ConstructionMenu/WatchtowerButton"
)
@onready var close_construction_menu_button: Button = (
	$"../UI/Shell/ConstructionMenu/CloseButton"
)
@onready var top_status_bar: Control = $"../UI/Shell/TopStatusBar"
@onready var resource_summary: Label = $"../UI/Shell/TopStatusBar/ResourceSummary"
@onready var time_summary: Label = $"../UI/Shell/TopStatusBar/TimeSummary"
@onready var daily_report: Label = $"../UI/Shell/TopStatusBar/DailyReport"
@onready var pause_button: Button = $"../UI/Shell/TopStatusBar/PauseButton"
@onready var alert_summary: Label = $"../UI/Shell/TopStatusBar/AlertSummary"
@onready var city_bar: Control = $"../UI/Shell/CityBar"
@onready var city_bar_toggle: Button = $"../UI/Shell/CityBarToggle"
@onready var army_status: Label = $"../UI/Shell/CityBar/ArmyStatus"
@onready var recruit_button: Button = $"../UI/Shell/CityBar/RecruitButton"
@onready var general_option: OptionButton = $"../UI/Shell/CityBar/GeneralOption"
@onready var tech_option: OptionButton = $"../UI/Shell/CityBar/TechOption"
@onready var research_button: Button = $"../UI/Shell/CityBar/ResearchButton"
@onready var emergency_mobilization_button: Button = (
	$"../UI/Shell/CityBar/EmergencyMobilizationButton"
)
@onready var threat_detail: Label = $"../UI/Shell/CityBar/ThreatDetail"
@onready var restore_checkpoint_button: Button = (
	$"../UI/Shell/CityBar/RestoreCheckpointButton"
)
@onready var restart_map_button: Button = $"../UI/Shell/CityBar/RestartMapButton"
@onready var minimap_placeholder: Control = $"../UI/Shell/MinimapPlaceholder"
@onready var building_detail_panel: Control = $"../UI/Shell/BuildingDetailPanel"

var state := ConstructionState.IDLE
var preview_origin_cell := Vector2i.ZERO
var preview_valid := false
var preview_invalid_reason := ""
var current_day := 1
var wood := 100
var food := 80
var tech_points := 0
var infantry_count := 20
var recruitment_cap := BASE_RECRUITMENT_CAP
var selected_general_id: StringName = &""
var training_queued_count := 0
var training_complete_day := 0
var last_training_order_day := 0
var researched_tech_ids: Array[StringName] = []
var supply_shortage := false
var emergency_mobilization_used := false
var enemy_count := 32
var enemy_fortification := 0
var last_daily_report := "尚未结算"
var city_time_paused := false
var day_elapsed_seconds := 0.0
var last_daily_breakdown := {
	"maintenance_food": 0,
	"maintenance_required": 0,
	"training_completed": 0,
	"wood_income": 0,
	"food_income": 0,
	"research_income": 0,
	"event_wood_loss": 0,
	"event_food_loss": 0,
	"stopped_placement_id": -1,
}
var _occupied_cells: Dictionary = {}
var _building_records_by_id: Dictionary = {}
var _placement_order: Array[int] = []
var _definitions_by_id: Dictionary = {}
var _generals_by_id: Dictionary = {}
var _tech_by_id: Dictionary = {}
var _next_placement_id := 1
var _detail_panel_active := false
var _selected_definition: BuildingDefinition
var _readiness_checkpoint: Dictionary = {}
var _active_battle_reservation: Dictionary = {}
var _closed_battle_transactions: Dictionary = {}
var _committed_battle_result_ids: Dictionary = {}
var _first_clear_keys: Dictionary = {}
var _last_battle_result_summary: Dictionary = {}
var _next_battle_transaction_sequence := 1


func _ready() -> void:
	_register_definition(ROAD_DEFINITION)
	_register_definition(LOGGING_CAMP_DEFINITION)
	_register_definition(FARM_DEFINITION)
	_register_definition(WAREHOUSE_DEFINITION)
	_register_definition(WATCHTOWER_DEFINITION)
	_register_strategy_definitions()
	_register_preset_buildings()
	build_entry_button.pressed.connect(_on_build_entry_pressed)
	road_button.pressed.connect(
		_on_definition_button_pressed.bind(ROAD_DEFINITION.definition_id)
	)
	logging_camp_button.pressed.connect(
		_on_definition_button_pressed.bind(LOGGING_CAMP_DEFINITION.definition_id)
	)
	farm_button.pressed.connect(
		_on_definition_button_pressed.bind(FARM_DEFINITION.definition_id)
	)
	warehouse_button.pressed.connect(
		_on_definition_button_pressed.bind(WAREHOUSE_DEFINITION.definition_id)
	)
	watchtower_button.pressed.connect(
		_on_definition_button_pressed.bind(WATCHTOWER_DEFINITION.definition_id)
	)
	close_construction_menu_button.pressed.connect(cancel_build_interaction)
	pause_button.pressed.connect(toggle_city_time_paused)
	recruit_button.pressed.connect(queue_training)
	general_option.item_selected.connect(_on_general_selected)
	tech_option.item_selected.connect(_on_tech_selected)
	research_button.pressed.connect(_on_research_pressed)
	emergency_mobilization_button.pressed.connect(emergency_mobilization)
	restore_checkpoint_button.pressed.connect(restore_readiness_checkpoint)
	restart_map_button.pressed.connect(restart_first_map)
	construction_preview.visible = false
	_update_threat_for_current_day(false)
	_sync_construction_ui()
	_refresh_city_ui()


func _process(delta: float) -> void:
	advance_city_time(delta)


func is_placing() -> bool:
	return state == ConstructionState.PLACING


func is_choosing_template() -> bool:
	return state == ConstructionState.CHOOSING_TEMPLATE


func open_construction_menu() -> void:
	if is_choosing_template() or is_city_action_locked_for_battle():
		return
	state = ConstructionState.CHOOSING_TEMPLATE
	_selected_definition = null
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()
	construction_interaction_started.emit()


func begin_placing(screen_position: Vector2) -> void:
	begin_placing_definition(
		LOGGING_CAMP_DEFINITION.definition_id,
		screen_position
	)


func begin_placing_definition(
	definition_id: StringName,
	screen_position: Vector2
) -> bool:
	if is_city_action_locked_for_battle():
		return false
	var definition := get_definition(definition_id)
	if definition == null:
		return false
	_selected_definition = definition
	state = ConstructionState.PLACING
	construction_preview.visible = true
	_apply_preview_geometry(definition)
	_sync_construction_ui()
	update_preview(screen_position)
	placing_started.emit()
	return true


func cancel_placing() -> void:
	if not is_placing():
		return
	state = ConstructionState.IDLE
	_selected_definition = null
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()


func cancel_build_interaction() -> void:
	if state == ConstructionState.IDLE:
		return
	state = ConstructionState.IDLE
	_selected_definition = null
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	_sync_construction_ui()


func handle_escape() -> bool:
	if not is_choosing_template():
		return false
	cancel_build_interaction()
	return true


func set_detail_panel_active(active: bool) -> void:
	_detail_panel_active = active
	_sync_construction_ui()


func is_construction_ui_point(screen_position: Vector2) -> bool:
	for ui_control in [
		construction_entry_panel,
		construction_menu,
		pause_button,
		city_bar_toggle,
	]:
		if (
			ui_control.is_visible_in_tree()
			and ui_control.get_global_rect().has_point(screen_position)
		):
			return true
	return false


func update_preview(screen_position: Vector2) -> void:
	if not is_placing() or _selected_definition == null:
		return
	var map_local_position := screen_to_map_local(screen_position)
	preview_origin_cell = map_position_to_origin_cell(
		map_local_position,
		_selected_definition.footprint
	)
	_refresh_preview_for_current_cell()


func confirm_current_preview() -> bool:
	if (
		not is_placing()
		or not preview_valid
		or _selected_definition == null
	):
		return false
	var placement_id := place_definition_at_cell(
		_selected_definition.definition_id,
		preview_origin_cell,
		true
	)
	if placement_id < 0:
		return false
	_refresh_preview_for_current_cell()
	return true


func place_definition_at_cell(
	definition_id: StringName,
	origin_cell: Vector2i,
	charge_cost := true
) -> int:
	if is_city_action_locked_for_battle():
		return -1
	var definition := get_definition(definition_id)
	if definition == null:
		return -1
	var validation := evaluate_origin_cell_for_definition(
		origin_cell,
		definition,
		false,
		charge_cost
	)
	if not bool(validation.valid):
		return -1
	if charge_cost and not _can_pay_definition(definition):
		return -1

	var placement_id := _allocate_placement_id()
	var footprint_cells := get_footprint_cells(
		origin_cell,
		definition.footprint
	)
	var building := _create_placed_building_node(
		placement_id,
		origin_cell,
		definition
	)
	var world_size := _definition_world_size(definition)
	var record := _base_record()
	record.merge({
		"placement_id": placement_id,
		"placement_kind": definition.placement_kind,
		"template_id": definition.definition_id,
		"definition_id": definition.definition_id,
		"display_name": definition.display_name,
		"building_type": definition.building_type,
		"description": definition.description,
		"origin_cell": origin_cell,
		"footprint": definition.footprint,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(Vector2.ZERO, world_size),
		"lifecycle_state": &"running",
		"prototype_status": "运行中",
		"selectable": true,
		"removable": true,
		"movable": false,
		"requires_road": definition.requires_road,
		"road_anchor_offsets": definition.road_anchor_offsets.duplicate(),
		"built_day": current_day,
		"node": building,
	}, true)
	_building_records_by_id[placement_id] = record
	_placement_order.append(placement_id)
	for cell in footprint_cells:
		_occupied_cells[cell] = placement_id
	building.tree_exited.connect(
		_on_runtime_building_tree_exited.bind(placement_id, building),
		CONNECT_ONE_SHOT
	)
	if charge_cost:
		wood -= definition.wood_cost
		food -= definition.food_cost
	_refresh_city_ui()
	city_state_changed.emit()
	return placement_id


func _create_runtime_building(origin_cell: Vector2i) -> int:
	return place_definition_at_cell(
		LOGGING_CAMP_DEFINITION.definition_id,
		origin_cell,
		false
	)


func advance_city_time(simulation_delta: float) -> int:
	if (
		simulation_delta <= 0.0
		or city_time_paused
	):
		return 0

	var remaining_seconds := simulation_delta
	var advanced_days := 0
	while remaining_seconds > 0.0:
		var seconds_until_boundary := maxf(
			SECONDS_PER_DAY - day_elapsed_seconds,
			0.0
		)
		if remaining_seconds < seconds_until_boundary:
			day_elapsed_seconds += remaining_seconds
			remaining_seconds = 0.0
			break

		remaining_seconds -= seconds_until_boundary
		day_elapsed_seconds = 0.0
		if not _advance_day_boundary():
			day_elapsed_seconds = SECONDS_PER_DAY
			break
		advanced_days += 1

	_refresh_time_ui()
	return advanced_days


func advance_city_time_for_test(simulation_delta: float) -> int:
	return advance_city_time(simulation_delta)


func advance_one_day_for_test() -> bool:
	day_elapsed_seconds = 0.0
	return _advance_day_boundary()


func set_city_time_paused(paused: bool) -> void:
	if city_time_paused == paused:
		return
	city_time_paused = paused
	_refresh_time_ui()
	city_state_changed.emit()


func toggle_city_time_paused() -> void:
	set_city_time_paused(not city_time_paused)


func is_city_time_paused() -> bool:
	return city_time_paused


func get_day_progress_ratio() -> float:
	return clampf(day_elapsed_seconds / SECONDS_PER_DAY, 0.0, 1.0)


func _advance_day_boundary() -> bool:
	if is_city_action_locked_for_battle():
		return false
	current_day += 1
	var maintenance_required := get_maintenance_food_cost()
	var maintenance_paid := mini(food, maintenance_required)
	food -= maintenance_paid
	supply_shortage = maintenance_paid < maintenance_required
	var training_completed := _complete_training_for_current_day()
	var wood_income := 0
	var food_income := 0
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or int(record.built_day) >= current_day:
			continue
		var definition := get_definition(record.definition_id)
		if definition == null or not is_building_operational(placement_id):
			continue
		var production := definition.get_capability(&"production")
		if production == null:
			continue
		var production_amount := _get_production_amount(
			definition,
			production
		)
		if production.resource_id == &"wood":
			wood_income += production_amount
		elif production.resource_id == &"food":
			food_income += production_amount

	var wood_capacity := get_resource_capacity(&"wood")
	var food_capacity := get_resource_capacity(&"food")
	var accepted_wood := mini(wood_income, maxi(wood_capacity - wood, 0))
	var accepted_food := mini(food_income, maxi(food_capacity - food, 0))
	wood += accepted_wood
	food += accepted_food
	tech_points += 1
	last_daily_breakdown = {
		"maintenance_food": maintenance_paid,
		"maintenance_required": maintenance_required,
		"training_completed": training_completed,
		"wood_income": accepted_wood,
		"food_income": accepted_food,
		"research_income": 1,
		"event_wood_loss": 0,
		"event_food_loss": 0,
		"stopped_placement_id": -1,
	}
	_update_threat_for_current_day(true)
	_clear_expired_production_stops()
	if current_day == 9:
		_capture_readiness_checkpoint()
	_rebuild_daily_report()
	if accepted_wood < wood_income or accepted_food < food_income:
		last_daily_report += "（容量封顶）"
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _complete_training_for_current_day() -> int:
	if (
		training_queued_count <= 0
		or training_complete_day > current_day
	):
		return 0
	var completed := training_queued_count
	infantry_count += completed
	training_queued_count = 0
	training_complete_day = 0
	return completed


func _get_production_amount(
	definition: BuildingDefinition,
	production: BuildingCapability
) -> int:
	var amount := production.amount
	if (
		definition.definition_id == LOGGING_CAMP_DEFINITION.definition_id
		and has_tech(&"tech.stone_tools")
	):
		var stone_tools := get_tech_definition(&"tech.stone_tools")
		amount = roundi(
			float(amount) * (1.0 + stone_tools.effect_amount)
		)
	return amount


func get_city_state() -> Dictionary:
	return {
		"day": current_day,
		"wood": wood,
		"food": food,
		"tech_points": tech_points,
		"infantry_count": infantry_count,
		"recruitment_cap": recruitment_cap,
		"effective_command_limit": get_effective_command_limit(),
		"selected_general_id": selected_general_id,
		"training_queued_count": training_queued_count,
		"training_complete_day": training_complete_day,
		"researched_tech_ids": researched_tech_ids.duplicate(),
		"supply_shortage": supply_shortage,
		"emergency_mobilization_used": emergency_mobilization_used,
		"wood_capacity": get_resource_capacity(&"wood"),
		"food_capacity": get_resource_capacity(&"food"),
		"city_defense": get_city_defense(),
		"enemy_count": enemy_count,
		"enemy_fortification": enemy_fortification,
		"available_infantry_count": get_available_infantry_count(),
		"active_battle_reservation": _active_battle_reservation.duplicate(true),
		"committed_battle_result_ids": _committed_battle_result_ids.keys(),
		"first_clear_keys": _first_clear_keys.keys(),
		"last_battle_result_summary": _last_battle_result_summary.duplicate(true),
		"checkpoint_available": not _readiness_checkpoint.is_empty(),
		"city_time_paused": city_time_paused,
		"day_elapsed_seconds": day_elapsed_seconds,
		"day_progress_ratio": get_day_progress_ratio(),
		"seconds_per_day": SECONDS_PER_DAY,
		"last_daily_report": last_daily_report,
		"last_daily_breakdown": last_daily_breakdown.duplicate(true),
	}


func is_city_action_locked_for_battle() -> bool:
	return not _active_battle_reservation.is_empty()


func get_available_infantry_count() -> int:
	return maxi(
		infantry_count - int(
			_active_battle_reservation.get("committed_count", 0)
		),
		0
	)


func get_active_battle_reservation() -> Dictionary:
	return _active_battle_reservation.duplicate(true)


func get_closed_battle_transaction_phase(
	transaction_id: StringName
) -> StringName:
	return StringName(_closed_battle_transactions.get(transaction_id, &""))


func get_committed_battle_result_summary(
	result_id: StringName
) -> Dictionary:
	var summary: Dictionary = _committed_battle_result_ids.get(result_id, {})
	return summary.duplicate(true)


func has_first_clear(first_clear_key: StringName) -> bool:
	return _first_clear_keys.has(first_clear_key)


func reserve_battle_force(committed_count: int) -> StringName:
	if (
		not _active_battle_reservation.is_empty()
		or committed_count <= 0
		or committed_count > get_available_infantry_count()
		or committed_count > get_effective_command_limit()
	):
		return &""
	var transaction_id := StringName(
		"battle-%06d" % _next_battle_transaction_sequence
	)
	_next_battle_transaction_sequence += 1
	_active_battle_reservation = {
		"transaction_id": transaction_id,
		"committed_count": committed_count,
		"phase": BATTLE_PHASE_RESERVED,
	}
	_refresh_city_ui()
	city_state_changed.emit()
	return transaction_id


func activate_battle_reservation(transaction_id: StringName) -> bool:
	return _transition_battle_reservation(
		transaction_id,
		BATTLE_PHASE_RESERVED,
		BATTLE_PHASE_ACTIVE
	)


func mark_battle_result_pending(transaction_id: StringName) -> bool:
	return _transition_battle_reservation(
		transaction_id,
		BATTLE_PHASE_ACTIVE,
		BATTLE_PHASE_RESULT_PENDING
	)


func cancel_battle_reservation(transaction_id: StringName) -> bool:
	if (
		_active_battle_reservation.is_empty()
		or StringName(_active_battle_reservation.transaction_id)
			!= transaction_id
		or StringName(_active_battle_reservation.phase)
			!= BATTLE_PHASE_RESERVED
	):
		return false
	_closed_battle_transactions[transaction_id] = BATTLE_PHASE_CANCELLED
	_active_battle_reservation = {}
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _transition_battle_reservation(
	transaction_id: StringName,
	expected_phase: StringName,
	next_phase: StringName
) -> bool:
	if (
		_active_battle_reservation.is_empty()
		or StringName(_active_battle_reservation.transaction_id)
			!= transaction_id
		or StringName(_active_battle_reservation.phase) != expected_phase
	):
		return false
	_active_battle_reservation.phase = next_phase
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func apply_battle_result_atomic(
	battle_result: BattleResult,
	request: BattleRequest
) -> Dictionary:
	if battle_result == null or request == null:
		return {}
	if _committed_battle_result_ids.has(battle_result.result_id):
		var committed_summary := get_committed_battle_result_summary(
			battle_result.result_id
		)
		if (
			StringName(committed_summary.get("transaction_id", &""))
				== battle_result.transaction_id
			and request.transaction_id == battle_result.transaction_id
		):
			return committed_summary
		return {}
	if (
		not battle_result.is_consistent()
		or _active_battle_reservation.is_empty()
		or StringName(_active_battle_reservation.transaction_id)
			!= battle_result.transaction_id
		or StringName(_active_battle_reservation.transaction_id)
			!= request.transaction_id
		or StringName(_active_battle_reservation.phase)
			!= BATTLE_PHASE_RESULT_PENDING
		or request.phase != BattleRequest.PHASE_RESULT_PENDING
		or battle_result.level_id != request.level_id
		or battle_result.started_day != request.created_day
		or battle_result.committed_count
			!= int(_active_battle_reservation.committed_count)
		or battle_result.committed_count
			!= request.committed_force.get_committed_total()
		or battle_result.player_snapshot_digest
			!= request.committed_force.get_digest()
		or battle_result.enemy_snapshot_digest
			!= request.enemy_force.get_digest()
		or battle_result.enemy_casualties > request.enemy_force.enemy_count
		or battle_result.casualty_count > infantry_count
	):
		return {}

	var grants_first_clear := (
		battle_result.outcome == BattleOutcome.Value.VICTORY
		and battle_result.first_clear_key != &""
		and not _first_clear_keys.has(battle_result.first_clear_key)
	)
	var planned_wood := 30 if grants_first_clear else 0
	var planned_food := 20 if grants_first_clear else 0
	var wood_capacity := get_resource_capacity(&"wood")
	var food_capacity := get_resource_capacity(&"food")
	var accepted_wood := mini(planned_wood, maxi(wood_capacity - wood, 0))
	var accepted_food := mini(planned_food, maxi(food_capacity - food, 0))
	var next_infantry := infantry_count - battle_result.casualty_count
	var next_wood := wood + accepted_wood
	var next_food := food + accepted_food
	if next_infantry < 0:
		return {}

	var summary := {
		"result_id": battle_result.result_id,
		"transaction_id": battle_result.transaction_id,
		"level_id": battle_result.level_id,
		"outcome": BattleOutcome.to_id(battle_result.outcome),
		"committed_count": battle_result.committed_count,
		"survivor_count": battle_result.survivor_count,
		"casualty_count": battle_result.casualty_count,
		"enemy_casualties": battle_result.enemy_casualties,
		"first_clear_granted": grants_first_clear,
		"planned_wood_reward": planned_wood,
		"planned_food_reward": planned_food,
		"accepted_wood_reward": accepted_wood,
		"accepted_food_reward": accepted_food,
		"overflow_wood_reward": planned_wood - accepted_wood,
		"overflow_food_reward": planned_food - accepted_food,
		"infantry_after": next_infantry,
		"wood_after": next_wood,
		"food_after": next_food,
	}

	infantry_count = next_infantry
	wood = next_wood
	food = next_food
	_committed_battle_result_ids[battle_result.result_id] = (
		summary.duplicate(true)
	)
	if grants_first_clear:
		_first_clear_keys[battle_result.first_clear_key] = true
	_closed_battle_transactions[battle_result.transaction_id] = (
		BATTLE_PHASE_APPLIED
	)
	_last_battle_result_summary = summary.duplicate(true)
	_active_battle_reservation = {}
	_refresh_city_ui()
	city_state_changed.emit()
	return summary.duplicate(true)


func get_last_daily_breakdown() -> Dictionary:
	return last_daily_breakdown.duplicate(true)


func get_unit_role() -> UnitRole:
	return INFANTRY_ROLE


func get_general_definition(
	general_id: StringName
) -> GeneralArchetype:
	return _generals_by_id.get(general_id) as GeneralArchetype


func get_selected_general() -> GeneralArchetype:
	return get_general_definition(selected_general_id)


func select_general(general_id: StringName) -> bool:
	if is_city_action_locked_for_battle():
		return false
	if general_id != &"" and not _generals_by_id.has(general_id):
		return false
	selected_general_id = general_id
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_effective_command_limit() -> int:
	var general := get_selected_general()
	return (
		general.command_limit
		if general != null
		else recruitment_cap
	)


func get_training_batch_size() -> int:
	var rotational := get_tech_definition(&"tech.rotational_recruitment")
	if rotational != null and has_tech(rotational.tech_id):
		return roundi(rotational.effect_amount)
	return BASE_TRAINING_BATCH


func can_queue_training() -> bool:
	var batch_size := get_training_batch_size()
	var command_limit := get_effective_command_limit()
	var food_cost := batch_size * INFANTRY_ROLE.recruit_food_per_unit
	return (
		not is_city_action_locked_for_battle()
		and
		current_day < FIRST_MAP_THREAT_SCHEDULE.max_day
		and training_queued_count == 0
		and last_training_order_day != current_day
		and get_available_infantry_count() + batch_size <= recruitment_cap
		and get_available_infantry_count() + batch_size <= command_limit
		and food >= food_cost
	)


func queue_training() -> bool:
	if not can_queue_training():
		return false
	var batch_size := get_training_batch_size()
	food -= batch_size * INFANTRY_ROLE.recruit_food_per_unit
	training_queued_count = batch_size
	training_complete_day = current_day + 1
	last_training_order_day = current_day
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_maintenance_food_cost() -> int:
	var cost := ceili(
		float(infantry_count)
		/ float(INFANTRY_ROLE.maintenance_units_per_food)
	)
	var general := get_selected_general()
	if (
		general != null
		and general.modifier_type == &"maintenance_reduction"
	):
		cost = ceili(float(cost) * (1.0 - general.modifier_amount))
	return cost


func get_tech_definition(tech_id: StringName) -> TechNode:
	return _tech_by_id.get(tech_id) as TechNode


func has_tech(tech_id: StringName) -> bool:
	return tech_id in researched_tech_ids


func can_research_tech(tech_id: StringName) -> bool:
	if is_city_action_locked_for_battle():
		return false
	var tech := get_tech_definition(tech_id)
	if tech == null or has_tech(tech_id) or tech_points < tech.cost:
		return false
	for prerequisite_id in tech.prerequisite_ids:
		if not has_tech(prerequisite_id):
			return false
	return true


func research_tech(tech_id: StringName) -> bool:
	if not can_research_tech(tech_id):
		return false
	var tech := get_tech_definition(tech_id)
	tech_points -= tech.cost
	researched_tech_ids.append(tech_id)
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_infantry_attack_multiplier() -> float:
	var multiplier := 1.0
	var general := get_selected_general()
	if general != null and general.modifier_type == &"infantry_attack":
		multiplier *= 1.0 + general.modifier_amount
	var formation := get_tech_definition(&"tech.formation_drill")
	if formation != null and has_tech(formation.tech_id):
		multiplier *= 1.0 + formation.effect_amount
	return multiplier


func get_infantry_defense_multiplier() -> float:
	var general := get_selected_general()
	if general != null and general.modifier_type == &"infantry_defense":
		return 1.0 + general.modifier_amount
	return 1.0


func emergency_mobilization() -> bool:
	if (
		is_city_action_locked_for_battle()
		or
		current_day != FIRST_MAP_THREAT_SCHEDULE.max_day
		or emergency_mobilization_used
		or food < EMERGENCY_MOBILIZATION_FOOD_COST
	):
		return false
	food -= EMERGENCY_MOBILIZATION_FOOD_COST
	infantry_count += EMERGENCY_MOBILIZATION_INFANTRY
	emergency_mobilization_used = true
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_city_defense() -> int:
	var defense := 10
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty():
			continue
		var definition := get_definition(record.definition_id)
		if definition == null:
			continue
		var defense_capability := definition.get_capability(&"defense")
		if defense_capability != null:
			defense += defense_capability.amount
	return defense


func get_threat_state() -> Dictionary:
	var next_event := FIRST_MAP_THREAT_SCHEDULE.get_next_pressure_event(
		current_day
	)
	return {
		"day": current_day,
		"enemy_count": enemy_count,
		"fortification_level": enemy_fortification,
		"city_defense": get_city_defense(),
		"next_pressure_day": next_event.day if next_event != null else -1,
		"next_pressure_preview": (
			next_event.public_preview if next_event != null else "已进入最终战备"
		),
		"max_day": FIRST_MAP_THREAT_SCHEDULE.max_day,
	}


func get_resource_capacity(resource_id: StringName) -> int:
	var capacity := BASE_RESOURCE_CAPACITY
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty():
			continue
		var definition := get_definition(record.definition_id)
		if definition == null:
			continue
		var storage := definition.get_capability(&"storage")
		if (
			storage != null
			and (
				storage.resource_id == resource_id
				or storage.resource_id == &"wood_food"
			)
		):
			capacity += storage.amount
	return capacity


func has_readiness_checkpoint() -> bool:
	return not _readiness_checkpoint.is_empty()


func restore_readiness_checkpoint() -> bool:
	if (
		_readiness_checkpoint.is_empty()
		or is_city_action_locked_for_battle()
	):
		return false
	_clear_runtime_placements()
	current_day = int(_readiness_checkpoint.day)
	wood = int(_readiness_checkpoint.wood)
	food = int(_readiness_checkpoint.food)
	tech_points = int(_readiness_checkpoint.tech_points)
	infantry_count = int(_readiness_checkpoint.infantry_count)
	recruitment_cap = int(_readiness_checkpoint.recruitment_cap)
	selected_general_id = StringName(
		_readiness_checkpoint.selected_general_id
	)
	training_queued_count = int(
		_readiness_checkpoint.training_queued_count
	)
	training_complete_day = int(
		_readiness_checkpoint.training_complete_day
	)
	last_training_order_day = int(
		_readiness_checkpoint.last_training_order_day
	)
	researched_tech_ids.assign(
		_readiness_checkpoint.researched_tech_ids
	)
	supply_shortage = bool(_readiness_checkpoint.supply_shortage)
	emergency_mobilization_used = bool(
		_readiness_checkpoint.emergency_mobilization_used
	)
	day_elapsed_seconds = float(
		_readiness_checkpoint.get("day_elapsed_seconds", 0.0)
	)
	for placement in _readiness_checkpoint.placements:
		var placement_id := place_definition_at_cell(
			StringName(placement.definition_id),
			Vector2i(placement.origin_cell),
			false
		)
		if placement_id < 0:
			push_error("Readiness checkpoint placement restore failed")
			return false
		var record: Dictionary = _building_records_by_id[placement_id]
		record.built_day = int(placement.built_day)
		record.disabled_until_day = int(placement.disabled_until_day)
	_update_threat_for_current_day(false)
	last_daily_report = "已恢复第 9 日自动战备检查点"
	_enforce_resource_capacity()
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func restart_first_map() -> bool:
	if is_city_action_locked_for_battle():
		return false
	_clear_runtime_placements()
	current_day = 1
	wood = 100
	food = 80
	tech_points = 0
	infantry_count = 20
	recruitment_cap = BASE_RECRUITMENT_CAP
	selected_general_id = &""
	training_queued_count = 0
	training_complete_day = 0
	last_training_order_day = 0
	researched_tech_ids.clear()
	supply_shortage = false
	emergency_mobilization_used = false
	day_elapsed_seconds = 0.0
	_readiness_checkpoint = {}
	last_daily_breakdown = {
		"maintenance_food": 0,
		"maintenance_required": 0,
		"training_completed": 0,
		"wood_income": 0,
		"food_income": 0,
		"research_income": 0,
		"event_wood_loss": 0,
		"event_food_loss": 0,
		"stopped_placement_id": -1,
	}
	last_daily_report = "首图已重开"
	_update_threat_for_current_day(false)
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _update_threat_for_current_day(apply_event: bool) -> void:
	var threat_event := FIRST_MAP_THREAT_SCHEDULE.get_event_for_day(
		current_day
	)
	if threat_event == null:
		return
	enemy_count = threat_event.enemy_count
	enemy_fortification = threat_event.fortification_level
	if apply_event and threat_event.day == current_day:
		_apply_threat_event(threat_event)


func _apply_threat_event(threat_event: ThreatEventDefinition) -> void:
	if threat_event.event_type == &"food_harassment":
		var loss := (
			threat_event.adequate_food_loss
			if get_city_defense() >= threat_event.defense_threshold
			else threat_event.insufficient_food_loss
		)
		var actual_loss := mini(loss, food)
		food -= actual_loss
		last_daily_breakdown.event_food_loss = actual_loss
	elif (
		threat_event.event_type == &"production_disruption"
		and get_city_defense() < threat_event.defense_threshold
	):
		var target_id := _select_production_disruption_target()
		if target_id >= 0:
			var record: Dictionary = _building_records_by_id[target_id]
			record.disabled_until_day = (
				current_day + threat_event.production_stop_days
			)
			last_daily_breakdown.stopped_placement_id = target_id


func _select_production_disruption_target() -> int:
	var selected_id := -1
	var selected_yield := -1
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or not is_building_operational(placement_id):
			continue
		var definition := get_definition(record.definition_id)
		if definition == null:
			continue
		var production := definition.get_capability(&"production")
		if production == null:
			continue
		if (
			production.amount > selected_yield
			or (
				production.amount == selected_yield
				and (selected_id < 0 or placement_id < selected_id)
			)
		):
			selected_yield = production.amount
			selected_id = placement_id
	return selected_id


func _clear_expired_production_stops() -> void:
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and int(record.disabled_until_day) > 0
			and int(record.disabled_until_day) <= current_day
		):
			record.disabled_until_day = 0


func _capture_readiness_checkpoint() -> void:
	var placements: Array[Dictionary] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or record.placement_kind == PLACEMENT_KIND_FIXED:
			continue
		placements.append({
			"definition_id": record.definition_id,
			"origin_cell": record.origin_cell,
			"built_day": record.built_day,
			"disabled_until_day": record.disabled_until_day,
		})
	_readiness_checkpoint = {
		"day": current_day,
		"wood": wood,
		"food": food,
		"tech_points": tech_points,
		"infantry_count": infantry_count,
		"recruitment_cap": recruitment_cap,
		"selected_general_id": selected_general_id,
		"training_queued_count": training_queued_count,
		"training_complete_day": training_complete_day,
		"last_training_order_day": last_training_order_day,
		"researched_tech_ids": researched_tech_ids.duplicate(),
		"supply_shortage": supply_shortage,
		"emergency_mobilization_used": emergency_mobilization_used,
		"day_elapsed_seconds": day_elapsed_seconds,
		"placements": placements,
	}


func _clear_runtime_placements() -> void:
	var runtime_ids: Array[int] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if not record.is_empty() and record.placement_kind != PLACEMENT_KIND_FIXED:
			runtime_ids.append(placement_id)
	for placement_id in runtime_ids:
		remove_placed_building(placement_id)


func _rebuild_daily_report() -> void:
	last_daily_report = "入 木%d 粮%d｜维%d｜损%d｜研+%d" % [
		int(last_daily_breakdown.wood_income),
		int(last_daily_breakdown.food_income),
		int(last_daily_breakdown.maintenance_food),
		int(last_daily_breakdown.event_food_loss),
		int(last_daily_breakdown.research_income),
	]
	if int(last_daily_breakdown.stopped_placement_id) >= 0:
		last_daily_report += "｜生产受扰"


func get_definition(definition_id: StringName) -> BuildingDefinition:
	return _definitions_by_id.get(definition_id) as BuildingDefinition


func get_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition_id in _definitions_by_id:
		result.append(definition_id)
	result.sort()
	return result


func get_building_count() -> int:
	return _building_records_by_id.size()


func get_placement_ids() -> Array[int]:
	return _placement_order.duplicate()


func get_occupied_cell_count() -> int:
	return _occupied_cells.size()


func get_occupied_placement_id(cell: Vector2i) -> int:
	return int(_occupied_cells.get(cell, -1))


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func get_building_record(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {}
	var result := record.duplicate(true)
	var status := get_operational_status(placement_id)
	result.operational_state = status.state
	result.prototype_status = status.label
	return result


func get_building_node(placement_id: int) -> CanvasItem:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return null
	var building := record.get("node") as CanvasItem
	return building if is_instance_valid(building) else null


func get_placement_id_for_node(building: CanvasItem) -> int:
	if not is_instance_valid(building) or not building.has_meta("placement_id"):
		return -1
	var placement_id := int(building.get_meta("placement_id"))
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty() or record.get("node") != building:
		return -1
	return placement_id


func get_operational_status(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {"state": &"missing", "label": "不存在"}
	if record.placement_kind == PLACEMENT_KIND_ROAD:
		var connected_roads := get_connected_road_cells()
		var road_cell: Vector2i = record.origin_cell
		if connected_roads.has(road_cell):
			return {"state": &"connected", "label": "已接入城市路网"}
		return {"state": &"isolated", "label": "未接入城主府道路根格"}
	if int(record.disabled_until_day) >= current_day:
		return {
			"state": &"event_disabled",
			"label": "停产至第 %d 日结算后" % int(
				record.disabled_until_day
			),
		}
	if bool(record.requires_road) and not is_building_connected_to_road(
		placement_id
	):
		return {"state": &"disabled", "label": "停用：未接入道路"}
	if record.placement_kind == PLACEMENT_KIND_FIXED:
		return {"state": &"fixed", "label": "固定 / 可选择"}
	return {"state": &"operational", "label": "运行中"}


func is_building_operational(placement_id: int) -> bool:
	var state_id: StringName = get_operational_status(placement_id).state
	return state_id in [&"operational", &"fixed", &"connected"]


func is_building_connected_to_road(placement_id: int) -> bool:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty() or not bool(record.requires_road):
		return not record.is_empty()
	var connected_roads := get_connected_road_cells()
	var origin: Vector2i = record.origin_cell
	for offset in record.road_anchor_offsets:
		if connected_roads.has(origin + Vector2i(offset)):
			return true
	return false


func get_connected_road_cells() -> Dictionary:
	var road_cells: Dictionary = {}
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and record.placement_kind == PLACEMENT_KIND_ROAD
		):
			for cell in record.occupied_footprint_cells:
				road_cells[cell] = true

	var connected: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for root_cell in ROAD_ROOT_CELLS:
		if road_cells.has(root_cell):
			connected[root_cell] = true
			frontier.append(root_cell)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction in [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]:
			var neighbor: Vector2i = current + Vector2i(direction)
			if road_cells.has(neighbor) and not connected.has(neighbor):
				connected[neighbor] = true
				frontier.append(neighbor)
	return connected


func remove_placed_building(placement_id: int) -> bool:
	if is_city_action_locked_for_battle():
		return false
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if (
		record.is_empty()
		or record.placement_kind == PLACEMENT_KIND_FIXED
		or not bool(record.get("removable", false))
	):
		return false
	var building := record.get("node") as Node2D
	if (
		not is_instance_valid(building)
		or not building.is_inside_tree()
		or building.get_parent() != placed_buildings
	):
		return false
	for cell in record.occupied_footprint_cells:
		if _occupied_cells.get(cell, -1) != placement_id:
			push_error(
				"Cannot remove placement %d: occupancy ownership mismatch at %s"
				% [placement_id, cell]
			)
			return false
	_release_runtime_record(placement_id, true)
	building.queue_free()
	_enforce_resource_capacity()
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func screen_to_map_local(screen_position: Vector2) -> Vector2:
	return map_world.get_global_transform_with_canvas().affine_inverse() * screen_position


func map_local_to_screen(map_local_position: Vector2) -> Vector2:
	return map_world.get_global_transform_with_canvas() * map_local_position


func map_position_to_origin_cell(
	map_local_position: Vector2,
	footprint := Vector2i.ZERO
) -> Vector2i:
	var effective_footprint := footprint
	if effective_footprint == Vector2i.ZERO:
		effective_footprint = (
			_selected_definition.footprint
			if _selected_definition != null
			else LOGGING_CAMP_DEFINITION.footprint
		)
	var grid_position := (map_local_position - GRID_ORIGIN) / GRID_SIZE
	return Vector2i(
		roundi(grid_position.x - effective_footprint.x * 0.5),
		roundi(grid_position.y - effective_footprint.y * 0.5)
	)


func cell_to_map_local(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell) * GRID_SIZE


func get_footprint_cells(
	origin_cell: Vector2i,
	footprint := Vector2i.ZERO
) -> Array[Vector2i]:
	var effective_footprint := (
		footprint
		if footprint != Vector2i.ZERO
		else (
			_selected_definition.footprint
			if _selected_definition != null
			else LOGGING_CAMP_DEFINITION.footprint
		)
	)
	var cells: Array[Vector2i] = []
	for y in range(effective_footprint.y):
		for x in range(effective_footprint.x):
			cells.append(origin_cell + Vector2i(x, y))
	return cells


func evaluate_origin_cell(origin_cell: Vector2i) -> Dictionary:
	var definition := (
		_selected_definition
		if _selected_definition != null
		else LOGGING_CAMP_DEFINITION
	)
	return evaluate_origin_cell_for_definition(origin_cell, definition, true)


func evaluate_origin_cell_for_definition(
	origin_cell: Vector2i,
	definition: BuildingDefinition,
	check_ui := true,
	check_resources := true
) -> Dictionary:
	if definition == null:
		return _validation_result(false, "缺少建筑定义")
	var footprint_cells := get_footprint_cells(
		origin_cell,
		definition.footprint
	)
	if not _footprint_is_inside_map(origin_cell, definition.footprint):
		return _validation_result(false, "超出地图")
	for cell in footprint_cells:
		if _occupied_cells.has(cell):
			return _validation_result(false, "位置已占用")
	var screen_rect := get_footprint_screen_rect(
		origin_cell,
		definition.footprint
	)
	if check_ui:
		if not _screen_rect_is_inside_viewport(screen_rect):
			return _validation_result(false, "超出可操作区域", screen_rect)
		for ui_control in _get_ui_occlusion_controls():
			if (
				ui_control.is_visible_in_tree()
				and ui_control.get_global_rect().grow(
					UI_SAFETY_MARGIN
				).intersects(screen_rect)
			):
				return _validation_result(false, "被界面遮挡", screen_rect)
	if check_resources and not _can_pay_definition(definition):
		return _validation_result(
			false,
			"木材不足（需要 %d）" % definition.wood_cost,
			screen_rect
		)
	return _validation_result(true, "", screen_rect)


func get_footprint_screen_rect(
	origin_cell: Vector2i,
	footprint := Vector2i.ZERO
) -> Rect2:
	var effective_footprint := (
		footprint
		if footprint != Vector2i.ZERO
		else (
			_selected_definition.footprint
			if _selected_definition != null
			else LOGGING_CAMP_DEFINITION.footprint
		)
	)
	var map_origin := cell_to_map_local(origin_cell)
	var map_end := map_origin + Vector2(effective_footprint) * GRID_SIZE
	var corners := [
		map_local_to_screen(map_origin),
		map_local_to_screen(Vector2(map_end.x, map_origin.y)),
		map_local_to_screen(map_end),
		map_local_to_screen(Vector2(map_origin.x, map_end.y)),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _on_build_entry_pressed() -> void:
	open_construction_menu()


func _on_definition_button_pressed(definition_id: StringName) -> void:
	begin_placing_definition(definition_id, get_viewport().get_mouse_position())


func _refresh_preview_for_current_cell() -> void:
	if _selected_definition == null:
		return
	var validation := evaluate_origin_cell_for_definition(
		preview_origin_cell,
		_selected_definition,
		true
	)
	preview_valid = validation.valid
	preview_invalid_reason = validation.reason
	construction_preview.position = cell_to_map_local(preview_origin_cell)
	preview_body.color = (
		PREVIEW_VALID_COLOR if preview_valid else PREVIEW_INVALID_COLOR
	)
	preview_outline.default_color = (
		PREVIEW_VALID_OUTLINE if preview_valid else PREVIEW_INVALID_OUTLINE
	)
	preview_label.text = (
		"%s\n可放置" % _selected_definition.display_name
		if preview_valid
		else "%s\n%s" % [
			_selected_definition.display_name,
			preview_invalid_reason,
		]
	)


func _apply_preview_geometry(definition: BuildingDefinition) -> void:
	var world_size := _definition_world_size(definition)
	preview_body.polygon = _rectangle_polygon(world_size)
	preview_outline.points = _rectangle_outline_points(world_size)
	preview_label.size = world_size
	preview_label.position = Vector2.ZERO


func _footprint_is_inside_map(
	origin_cell: Vector2i,
	footprint: Vector2i
) -> bool:
	var map_grid_size := Vector2i(
		floori(map_board.size.x / GRID_SIZE),
		floori(map_board.size.y / GRID_SIZE)
	)
	return (
		origin_cell.x >= 0
		and origin_cell.y >= 0
		and origin_cell.x + footprint.x <= map_grid_size.x
		and origin_cell.y + footprint.y <= map_grid_size.y
	)


func _screen_rect_is_inside_viewport(screen_rect: Rect2) -> bool:
	var viewport_rect := get_viewport().get_visible_rect()
	return (
		screen_rect.position.x >= viewport_rect.position.x
		and screen_rect.position.y >= viewport_rect.position.y
		and screen_rect.end.x <= viewport_rect.end.x
		and screen_rect.end.y <= viewport_rect.end.y
	)


func _get_ui_occlusion_controls() -> Array[Control]:
	return [
		top_status_bar,
		city_bar,
		city_bar_toggle,
		minimap_placeholder,
		building_detail_panel,
		construction_entry_panel,
		construction_menu,
	]


func _validation_result(
	valid: bool,
	reason: String,
	screen_rect := Rect2()
) -> Dictionary:
	return {
		"valid": valid,
		"reason": reason,
		"screen_rect": screen_rect,
	}


func _create_placed_building_node(
	placement_id: int,
	origin_cell: Vector2i,
	definition: BuildingDefinition
) -> Node2D:
	var building := Node2D.new()
	building.name = "Placement%03d" % placement_id
	building.position = cell_to_map_local(origin_cell)
	building.set_meta("placement_id", placement_id)
	var world_size := _definition_world_size(definition)

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _rectangle_polygon(world_size)
	body.color = definition.body_color
	building.add_child(body)

	var outline := Line2D.new()
	outline.name = "Outline"
	outline.points = _rectangle_outline_points(world_size)
	outline.width = 3.0
	outline.default_color = definition.outline_color
	building.add_child(outline)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(3.0, 3.0)
	label.size = world_size - Vector2(6.0, 6.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = definition.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(
		"font_size",
		11 if definition.placement_kind == PLACEMENT_KIND_ROAD else 14
	)
	label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.96, 0.93, 1.0)
	)
	building.add_child(label)

	placed_buildings.add_child(building)
	return building


func _release_runtime_record(
	placement_id: int,
	require_complete_ownership: bool
) -> bool:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if (
		record.is_empty()
		or record.placement_kind == PLACEMENT_KIND_FIXED
	):
		return false
	var footprint_cells: Array = record.occupied_footprint_cells
	if require_complete_ownership:
		for cell in footprint_cells:
			if _occupied_cells.get(cell, -1) != placement_id:
				return false
	for cell in footprint_cells:
		if _occupied_cells.get(cell, -1) == placement_id:
			_occupied_cells.erase(cell)
		elif not require_complete_ownership:
			push_error(
				"Placement %d exited with occupancy mismatch at %s"
				% [placement_id, cell]
			)
	_building_records_by_id.erase(placement_id)
	_placement_order.erase(placement_id)
	building_removed.emit(placement_id)
	return true


func _on_runtime_building_tree_exited(
	placement_id: int,
	building: Node2D
) -> void:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return
	if record.get("node") != building:
		push_error(
			"Placement %d tree exit did not match its authoritative node"
			% placement_id
		)
		return
	_release_runtime_record(placement_id, false)
	city_state_changed.emit()


func _register_definition(definition: BuildingDefinition) -> void:
	if (
		definition == null
		or definition.definition_id == &""
		or _definitions_by_id.has(definition.definition_id)
	):
		push_error("Invalid or duplicate building definition")
		return
	_definitions_by_id[definition.definition_id] = definition


func _register_strategy_definitions() -> void:
	for general in GENERAL_DEFINITIONS:
		if (
			general == null
			or general.archetype_id == &""
			or _generals_by_id.has(general.archetype_id)
		):
			push_error("Invalid or duplicate general definition")
			continue
		_generals_by_id[general.archetype_id] = general
	general_option.clear()
	general_option.add_item("未任命")
	general_option.set_item_metadata(0, &"")
	for general in GENERAL_DEFINITIONS:
		general_option.add_item(general.display_name)
		general_option.set_item_metadata(
			general_option.item_count - 1,
			general.archetype_id
		)

	for tech in TECH_DEFINITIONS:
		if (
			tech == null
			or tech.tech_id == &""
			or _tech_by_id.has(tech.tech_id)
		):
			push_error("Invalid or duplicate tech definition")
			continue
		_tech_by_id[tech.tech_id] = tech
	tech_option.clear()
	for tech in TECH_DEFINITIONS:
		tech_option.add_item("%s · %d" % [tech.display_name, tech.cost])
		tech_option.set_item_metadata(
			tech_option.item_count - 1,
			tech.tech_id
		)


func _on_general_selected(index: int) -> void:
	select_general(StringName(general_option.get_item_metadata(index)))


func _on_research_pressed() -> void:
	if tech_option.item_count <= 0:
		return
	var selected_index := tech_option.selected
	research_tech(
		StringName(tech_option.get_item_metadata(selected_index))
	)


func _on_tech_selected(_index: int) -> void:
	_refresh_city_ui()


func _register_preset_buildings() -> void:
	for definition in PRESET_BUILDING_DEFINITIONS:
		var building := get_node(str(definition.node_path)) as Control
		if building == null:
			push_error("Missing preset building: %s" % definition.node_path)
			continue
		_register_fixed_building(building, definition)


func _register_fixed_building(
	building: Control,
	definition: Dictionary
) -> void:
	var map_rect := Rect2(building.position, building.size)
	var footprint_cells := _get_cells_intersecting_map_rect(map_rect)
	for cell in footprint_cells:
		if _occupied_cells.has(cell):
			push_error(
				"Preset building %s overlaps placement %s at %s"
				% [building.name, _occupied_cells[cell], cell]
			)
			return
	var origin_cell := Vector2i(
		floori(map_rect.position.x / GRID_SIZE),
		floori(map_rect.position.y / GRID_SIZE)
	)
	var footprint_end := Vector2i(
		ceili(map_rect.end.x / GRID_SIZE),
		ceili(map_rect.end.y / GRID_SIZE)
	)
	var placement_id := _allocate_placement_id()
	var record := _base_record()
	record.merge({
		"placement_id": placement_id,
		"placement_kind": PLACEMENT_KIND_FIXED,
		"template_id": definition.template_id,
		"definition_id": definition.template_id,
		"display_name": definition.display_name,
		"building_type": "固定预置建筑",
		"description": definition.description,
		"origin_cell": origin_cell,
		"footprint": footprint_end - origin_cell,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(Vector2.ZERO, building.size),
		"lifecycle_state": &"fixed",
		"prototype_status": "固定 / 可选择",
		"selectable": true,
		"removable": false,
		"movable": false,
		"built_day": 0,
		"node": building,
	}, true)
	building.set_meta("placement_id", placement_id)
	_building_records_by_id[placement_id] = record
	_placement_order.append(placement_id)
	for cell in footprint_cells:
		_occupied_cells[cell] = placement_id


func _base_record() -> Dictionary:
	return {
		"placement_id": -1,
		"placement_kind": &"",
		"template_id": &"",
		"definition_id": &"",
		"display_name": "",
		"building_type": "",
		"description": "",
		"origin_cell": Vector2i.ZERO,
		"footprint": Vector2i.ZERO,
		"occupied_footprint_cells": [],
		"selection_bounds": Rect2(),
		"lifecycle_state": &"",
		"prototype_status": "",
		"operational_state": &"",
		"selectable": false,
		"removable": false,
		"movable": false,
		"requires_road": false,
		"road_anchor_offsets": [],
		"built_day": 0,
		"disabled_until_day": 0,
		"node": null,
	}


func _get_cells_intersecting_map_rect(map_rect: Rect2) -> Array[Vector2i]:
	var start_cell := Vector2i(
		floori(map_rect.position.x / GRID_SIZE),
		floori(map_rect.position.y / GRID_SIZE)
	)
	var end_cell := Vector2i(
		ceili(map_rect.end.x / GRID_SIZE),
		ceili(map_rect.end.y / GRID_SIZE)
	)
	var cells: Array[Vector2i] = []
	for y in range(start_cell.y, end_cell.y):
		for x in range(start_cell.x, end_cell.x):
			cells.append(Vector2i(x, y))
	return cells


func _allocate_placement_id() -> int:
	var placement_id := _next_placement_id
	_next_placement_id += 1
	return placement_id


func _can_pay_definition(definition: BuildingDefinition) -> bool:
	return (
		wood >= definition.wood_cost
		and food >= definition.food_cost
	)


func _sync_construction_ui() -> void:
	construction_entry_panel.visible = not _detail_panel_active
	build_entry_button.visible = state != ConstructionState.PLACING
	build_mode_status.visible = state == ConstructionState.PLACING
	if state == ConstructionState.PLACING and _selected_definition != null:
		build_mode_status.text = "建造中：%s\n右键 / Esc 取消" % (
			_selected_definition.display_name
		)
	construction_menu.visible = (
		not _detail_panel_active
		and state == ConstructionState.CHOOSING_TEMPLATE
	)


func _refresh_city_ui() -> void:
	resource_summary.text = "木材 %d/%d · 粮食 %d/%d" % [
		wood,
		get_resource_capacity(&"wood"),
		food,
		get_resource_capacity(&"food"),
	]
	_refresh_time_ui()
	daily_report.text = last_daily_report
	var threat_state := get_threat_state()
	alert_summary.text = "敌军 %d · 工事 %d" % [
		enemy_count,
		enemy_fortification,
	]
	threat_detail.text = (
		"城防 %d\n当前敌军 %d · 工事 %d\n%s"
		% [
			get_city_defense(),
			enemy_count,
			enemy_fortification,
			str(threat_state.next_pressure_preview),
		]
	)
	var command_limit := get_effective_command_limit()
	var queued_text := (
		" · 训练 +%d（第 %d 日）" % [
			training_queued_count,
			training_complete_day,
		]
		if training_queued_count > 0
		else ""
	)
	army_status.text = "步兵 %d/%d · 科技 %d%s%s" % [
		infantry_count,
		command_limit,
		tech_points,
		queued_text,
		" · 供给不足" if supply_shortage else "",
	]
	recruit_button.text = "征募 %d 人 · %d 粮" % [
		get_training_batch_size(),
		get_training_batch_size() * INFANTRY_ROLE.recruit_food_per_unit,
	]
	recruit_button.disabled = not can_queue_training()
	for index in range(general_option.item_count):
		if (
			StringName(general_option.get_item_metadata(index))
			== selected_general_id
		):
			general_option.select(index)
			break
	if tech_option.item_count > 0:
		var selected_tech_id := StringName(
			tech_option.get_item_metadata(tech_option.selected)
		)
		research_button.disabled = not can_research_tech(
			selected_tech_id
		)
	emergency_mobilization_button.visible = (
		current_day >= FIRST_MAP_THREAT_SCHEDULE.max_day
	)
	emergency_mobilization_button.disabled = (
		emergency_mobilization_used
		or food < EMERGENCY_MOBILIZATION_FOOD_COST
	)
	restore_checkpoint_button.visible = (
		current_day >= FIRST_MAP_THREAT_SCHEDULE.max_day
		and has_readiness_checkpoint()
	)
	restart_map_button.visible = (
		current_day >= FIRST_MAP_THREAT_SCHEDULE.max_day
	)


func _refresh_time_ui() -> void:
	var elapsed_seconds := floori(day_elapsed_seconds)
	var time_text := "第 %d 日 · %02d:%02d" % [
		current_day,
		elapsed_seconds / 60,
		elapsed_seconds % 60,
	]
	if time_summary.text != time_text:
		time_summary.text = time_text
	var pause_text := "继续" if city_time_paused else "暂停"
	if pause_button.text != pause_text:
		pause_button.text = pause_text


func _enforce_resource_capacity() -> void:
	wood = mini(wood, get_resource_capacity(&"wood"))
	food = mini(food, get_resource_capacity(&"food"))


func _definition_world_size(definition: BuildingDefinition) -> Vector2:
	return Vector2(definition.footprint) * GRID_SIZE


func _rectangle_polygon(world_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(world_size.x, 0.0),
		world_size,
		Vector2(0.0, world_size.y),
	])


func _rectangle_outline_points(world_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(world_size.x, 0.0),
		world_size,
		Vector2(0.0, world_size.y),
		Vector2.ZERO,
	])
