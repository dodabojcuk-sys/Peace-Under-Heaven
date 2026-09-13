extends Node


signal placing_started
signal construction_interaction_started
signal construction_presentation_changed
signal building_removed(placement_id: int)
signal city_state_changed

enum ConstructionState {
	IDLE,
	CHOOSING_TEMPLATE,
	PLACING,
}

enum FirstWarState {
	PREPARATION,
	WARNING,
	PENDING,
	IN_BATTLE,
	RESOLVED_VICTORY,
	RESOLVED_RETREAT,
	RESOLVED_DEFEAT,
}

const GRID_SIZE := 40.0
const GRID_ORIGIN := Vector2.ZERO
const PLACEMENT_KIND_FIXED := &"fixed"
const PLACEMENT_KIND_PLACED := &"placed"
const PLACEMENT_KIND_ROAD := &"road"
const BASE_RESOURCE_CAPACITY := 160
const UI_SAFETY_MARGIN := 8.0
const PREVIEW_VALID_COLOR := Color(0.31, 0.62, 0.43, 0.72)
const PREVIEW_DISCONNECTED_COLOR := Color(0.78, 0.57, 0.2, 0.76)
const PREVIEW_INVALID_COLOR := Color(0.72, 0.31, 0.28, 0.72)
const PREVIEW_VALID_OUTLINE := Color(0.12, 0.34, 0.2, 1.0)
const PREVIEW_DISCONNECTED_OUTLINE := Color(0.48, 0.29, 0.08, 1.0)
const PREVIEW_INVALID_OUTLINE := Color(0.42, 0.12, 0.1, 1.0)
const ORIENTATION_NORTH := 0
const ORIENTATION_EAST := 1
const ORIENTATION_SOUTH := 2
const ORIENTATION_WEST := 3
const ORIENTATION_NAMES := ["北", "东", "南", "西"]
const CITY_GRID_RULES = preload(
	"res://scripts/city_sandbox/city_grid_rules.gd"
)
const CITY_ROAD_DRAFT = preload(
	"res://scripts/city_sandbox/city_road_draft.gd"
)
const GRAYBOX_BUILDING_VISUAL = preload(
	"res://scripts/graybox_building_visual.gd"
)
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
const HOUSING_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/housing.tres"
)
const CLINIC_DEFINITION: BuildingDefinition = preload(
	"res://resources/definitions/buildings/clinic.tres"
)
const EARLY_CITY_SNAPSHOT_V1 = preload(
	"res://scripts/state/early_city_snapshot_v1.gd"
)
const GARRISON_STATE = preload(
	"res://scripts/army/garrison_state.gd"
)
const TRAINING_QUEUE = preload(
	"res://scripts/army/training_queue.gd"
)
const ARMY_REGISTRY = preload(
	"res://scripts/army/army_registry.gd"
)
const V5_ARMY_DISPATCH_ADAPTER = preload(
	"res://scripts/army/v5_army_dispatch_adapter.gd"
)
const MACRO_MARCH_THEATER = preload(
	"res://scripts/macro_march/macro_march_theater.gd"
)
const WAR_LOOP_STATE = preload("res://scripts/war/war_loop_state.gd")
const WAR_LOOP_RULES: WarLoopRules = preload("res://resources/war/war_loop_r1_rules.tres")
const V5_CAMPAIGN_SNAPSHOT = preload(
	"res://scripts/state/v5_campaign_snapshot.gd"
)
const NATION_STATE = preload(
	"res://scripts/state/nation_state.gd"
)
const POPULATION_RECOVERY_STATE = preload(
	"res://scripts/state/population_recovery_state.gd"
)
const CITY_GOVERNANCE_STATE = preload("res://scripts/state/city_governance_state.gd")
const CITY_STRATEGY_STATE = preload("res://scripts/state/city_strategy_state.gd")
const CITY_GOVERNANCE_RULES: CityGovernanceRules = preload(
	"res://resources/war/blackstone_city_governance_r0.tres"
)
const CITY_STRATEGY_RULES: CityStrategyRules = preload("res://resources/war/blackstone_city_strategy_r0.tres")
const RECOVERY_RULES: CampaignRecoveryRules = preload(
	"res://resources/war/blackstone_recovery_r0.tres"
)
const CITY_LAYOUT_PROFILE_RESOLVER = preload(
	"res://scripts/city_layout_profile_resolver.gd"
)
const V5_NATIONAL_RESOURCE_ADAPTER = preload(
	"res://scripts/state/v5_national_resource_adapter.gd"
)
const MAINLINE_PRESSURE_PROFILE: MainlinePressureProfile = preload(
	"res://resources/definitions/mainline/m0_first_level_pressure.tres"
)
const CURRENT_MAINLINE_LEVEL = preload(
	"res://scripts/state/current_mainline_level.gd"
)
const NOTICEBOARD_MISSIONS: Array[MissionDefinition] = [
	preload("res://resources/definitions/missions/outskirts_sweep.tres"),
	preload("res://resources/definitions/missions/supply_relief.tres"),
	preload("res://resources/definitions/missions/missing_scout.tres"),
]
const WARTIME_DEFENSE_MISSION: MissionDefinition = preload(
	"res://resources/definitions/missions/blackstone_gate_defense.tres"
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
const BLACKSTONE_INITIAL_MILITARY_COUNT := 20
const EMERGENCY_MOBILIZATION_FOOD_COST := 30
const EMERGENCY_MOBILIZATION_INFANTRY := 5
const SECONDS_PER_DAY := 180.0
const MILLISECONDS_PER_DAY := 180000
const CONSTRUCTION_TICK_MILLISECONDS := 1000
const FIELD_SPECIALIST_DISPATCH_COSTS := {
	FieldTacticsState.SPECIALIST_SCOUT: 4,
	FieldTacticsState.SPECIALIST_ENGINEER: 8,
	FieldTacticsState.SPECIALIST_MEDIC: 6,
	FieldTacticsState.SPECIALIST_SABOTEUR: 7,
	FieldTacticsState.SPECIALIST_THIEF: 5,
	FieldTacticsState.SPECIALIST_SNIPER: 7,
}
const FIELD_SPECIALIST_ACTION_RULES := {
	FieldTacticsState.ACTION_MEDICAL: {"duration_milliseconds": 2500, "food_cost": 2, "effect_amount": 60},
	FieldTacticsState.ACTION_SABOTAGE: {"duration_milliseconds": 4000, "food_cost": 2, "effect_amount": 60},
	FieldTacticsState.ACTION_THEFT: {"duration_milliseconds": 3500, "food_cost": 2, "effect_amount": 5},
	FieldTacticsState.ACTION_SNIPER: {"duration_milliseconds": 3000, "food_cost": 2, "effect_amount": 1},
}
const CONSTRUCTION_PRIORITY_LOW := 0
const CONSTRUCTION_PRIORITY_NORMAL := 1
const CONSTRUCTION_PRIORITY_HIGH := 2
const BUILD_SLOT_IDLE := &"IDLE"
const BUILD_SLOT_PRODUCING := &"PRODUCING"
const BUILD_SLOT_WAITING_MATERIAL := &"WAITING_MATERIAL"
const BUILD_SLOT_READY_TO_PLACE := &"READY_TO_PLACE"
const BUILD_SLOT_PLACEMENT_ACTIVE := &"PLACEMENT_ACTIVE"
const CITY_TIME_SPEEDS := [1.0, 2.0, 4.0]
const FIRST_WAR_EVENT_ID := &"first_war.north_slope.v0"
const FIRST_WAR_WARNING_DAY := 6
const FIRST_WAR_PENDING_DAY := 7
const FIRST_WAR_LEVEL_ID := &"first_map.main_assault.v0"
const FIRST_WAR_RETREAT_DEFENSE_DAMAGE := 5
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
		"level": 1,
		"effect_summary": "提供城市道路网络根格",
	},
	{
		"node_path": "../MapWorld/Barracks",
		"template_id": &"barracks",
		"display_name": "兵营 L1",
		"description": "军事训练设施（P1-D 接入征募）",
		"level": 1,
		"effect_summary": "每批征募 5 人 · 消耗 15 粮 · 次日完成",
	},
	{
		"node_path": "../MapWorld/Granary",
		"template_id": &"granary",
		"display_name": "粮仓 L2",
		"description": "城市粮食储备（P1-B 接入容量）",
		"level": 2,
		"effect_summary": "当前城市木材／粮食基础容量各 160",
	},
	{
		"node_path": "../MapWorld/Academy",
		"template_id": &"academy",
		"display_name": "学院 L1",
		"description": "研究与教育设施（P1-D 接入科技）",
		"level": 1,
		"effect_summary": "每日结算科技点 +1",
	},
	{
		"node_path": "../MapWorld/CityGate",
		"template_id": &"city_gate",
		"display_name": "城门 L1",
		"description": "城市出入口（P1-C 接入城防）",
		"level": 1,
		"effect_summary": "提供基础城防 10",
	},
	{
		"node_path": "../MapWorld/CommandPlatform",
		"template_id": &"command_platform",
		"display_name": "军令台 L1",
		"description": "北坡首战的正式城市入口",
		"level": 1,
		"effect_summary": "显示敌情并处理北坡首战",
	},
	{
		"node_path": "../MapWorld/Noticeboard",
		"template_id": &"noticeboard",
		"display_name": "告示板",
		"description": "居民委托、小型战斗与搜索任务入口",
		"level": 1,
		"effect_summary": "提供三项当前进程内任务",
	},
]

@onready var map_world: Node2D = $"../MapWorld"
@onready var map_board: Control = $"../MapWorld/MapBoard"
@onready var city_spatial_foundation: RegularCitySpatialFoundation = (
	$"../MapWorld/RegularCitySpatialFoundation"
)
@onready var placed_buildings: Node2D = $"../MapWorld/ConstructionLayer/PlacedBuildings"
@onready var construction_preview: Node2D = $"../MapWorld/ConstructionLayer/ConstructionPreview"
@onready var road_preview_visual: RoadPreviewVisual = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/RoadPreview"
)
@onready var preview_body: Polygon2D = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Body"
)
@onready var preview_outline: Line2D = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Outline"
)
@onready var preview_label: Label = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/Label"
)
@onready var placement_grid: PlacementGridR1 = (
	$"../MapWorld/ConstructionLayer/ConstructionPreview/PlacementGrid"
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
@onready var placement_orientation_label: Label = (
	$"../UI/Shell/ConstructionEntryPanel/PlacementOrientation"
)
@onready var rotate_placement_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/RotateButton"
)
@onready var confirm_road_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/ConfirmRoadButton"
)
@onready var cancel_placement_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/CancelPlacementButton"
)
@onready var build_slot_progress: ProgressBar = (
	$"../UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotProgress"
)
@onready var build_slot_detail: Label = (
	$"../UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotDetail"
)
@onready var build_slot_primary_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotPrimaryButton"
)
@onready var build_slot_cancel_button: Button = (
	$"../UI/Shell/ConstructionEntryPanel/BuildSlotContent/BuildSlotCancelButton"
)
@onready var build_slot_content: VBoxContainer = (
	$"../UI/Shell/ConstructionEntryPanel/BuildSlotContent"
)
@onready var placement_feedback: Label = $"../UI/Shell/PlacementFeedback"
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
@onready var time_speed_option: OptionButton = (
	$"../UI/Shell/TopStatusBar/TimeSpeedOption"
)
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
@onready var first_war_actions: Control = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions"
)
@onready var first_war_intel: Label = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/WarIntel"
)
@onready var enter_first_war_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/EnterBattleButton"
)
@onready var current_mainline_entry_button: Button = (
	$"../UI/Shell/TopStatusBar/CurrentMainlineButton"
)
@onready var expedition_preparation_panel: ExpeditionPreparationPanel = (
	$"../UI/Shell/ExpeditionPreparationPanel"
)
@onready var order_retreat_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/OrderRetreatButton"
)
@onready var retreat_confirmation: Control = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/RetreatConfirmation"
)
@onready var confirm_retreat_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/RetreatConfirmation/ConfirmRetreatButton"
)
@onready var cancel_retreat_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/RetreatConfirmation/CancelRetreatButton"
)
@onready var first_war_result: Control = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/WarResult"
)
@onready var first_war_result_label: Label = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/WarResult/ResultLabel"
)
@onready var acknowledge_war_result_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/FirstWarActions/WarResult/AcknowledgeButton"
)
@onready var noticeboard_panel: Panel = $"../UI/Shell/NoticeboardPanel"
@onready var noticeboard_close_button: Button = (
	$"../UI/Shell/NoticeboardPanel/CloseButton"
)
@onready var noticeboard_last_result: Label = (
	$"../UI/Shell/NoticeboardPanel/LastResult"
)
@onready var enter_wartime_defense_button: Button = (
	$"../UI/Shell/BuildingDetailPanel/CityGateActions/EnterWartimeDefenseButton"
)

var state := ConstructionState.IDLE
var preview_origin_cell := Vector2i.ZERO
var preview_orientation := ORIENTATION_NORTH
var preview_valid := false
var preview_invalid_reason := ""
var preview_connection_state: StringName = &"not_required"
var preview_entrance_info: Dictionary = {}
var preview_entrance_marker: Polygon2D
var preview_conflict_mark: Line2D
var _last_preview_validation: Dictionary = {}
var _placement_feedback_generation := 0
var _legacy_overlap_reports: Array[Dictionary] = []
var _road_draft: Dictionary = {}
var _road_drag_active := false
var _road_preview_fixed := false
# This is presentation-only state for the current road-preview lifetime. It is
# deliberately cleared with the draft and is never exported to V5.
var _road_recommendation_preview: Dictionary = {}
var _road_drag_start_cell := Vector2i.ZERO
var _road_drag_current_cell := Vector2i.ZERO
var current_day := 1
var _nation_state: NationState = NATION_STATE.new()
var wood: int:
	get:
		return _nation_state.get_resource(&"wood")
	set(value):
		_set_legacy_resource_balance(&"wood", value)
var food: int:
	get:
		return _nation_state.get_resource(&"food")
	set(value):
		_set_legacy_resource_balance(&"food", value)
var tech_points: int:
	get:
		return _nation_state.get_resource(&"tech_points")
	set(value):
		_set_legacy_resource_balance(&"tech_points", value)
var _garrison_state: GarrisonState = GARRISON_STATE.new(
	&"blackstone_city",
	INFANTRY_ROLE.role_id,
	BLACKSTONE_INITIAL_MILITARY_COUNT
)
var infantry_count: int:
	get:
		return _garrison_state.get_unit_count(INFANTRY_ROLE.role_id)
	set(value):
		_garrison_state.set_unit_count(INFANTRY_ROLE.role_id, value)
var recruitment_cap := BASE_RECRUITMENT_CAP
var selected_general_id: StringName = &""
var _training_queue: TrainingQueue = TRAINING_QUEUE.new(&"blackstone_city")
var _last_training_failure_id: StringName = &""
var _last_campaign_checkpoint_result: Dictionary = {}
var _army_registry: ArmyRegistry = ARMY_REGISTRY.new()
var _population_recovery: PopulationRecoveryState = POPULATION_RECOVERY_STATE.new()
var _city_governance: CityGovernanceState = CITY_GOVERNANCE_STATE.new()
var _city_strategy: CityStrategyState = CITY_STRATEGY_STATE.new()
var _army_dispatch_adapter: V5ArmyDispatchAdapter
var _active_army_dispatch_reservation: Dictionary = {}
var _next_army_dispatch_transaction_sequence := 1
var _active_army_encounter: Dictionary = {}
var _v5_restore_failure_after_city_install_for_test := false
var training_queued_count: int:
	get:
		return int(_training_queue.get_active_order().get("quantity", 0))
var training_complete_day: int:
	get:
		return int(_training_queue.get_active_order().get("complete_day", 0))
var last_training_order_day: int:
	get:
		return _training_queue.get_last_order_day()
var researched_tech_ids: Array[StringName] = []
var supply_shortage := false
var emergency_mobilization_used := false
var enemy_count := 32
var enemy_fortification := 0
var last_daily_report := "尚未结算"
var city_time_paused := false
var city_time_speed := 1.0
var _macro_march_blocked_route_ids: Dictionary = {}
var day_elapsed_seconds := 0.0
var _city_frame_remainder_milliseconds := 0.0
var first_war_state := FirstWarState.PREPARATION
var first_war_warning_count := 0
var city_fallen := false
var city_defense_damage := 0
var city_security := MAINLINE_PRESSURE_PROFILE.default_security
var _current_mainline_level: CurrentMainlineLevel = (
	CURRENT_MAINLINE_LEVEL.new(MAINLINE_PRESSURE_PROFILE)
)
var _construction_completed_since_last_day := 0
var last_daily_breakdown := {
	"maintenance_food": 0,
	"maintenance_required": 0,
	"training_completed": 0,
	"construction_completed": 0,
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
var _active_city_id: StringName = CITY_LAYOUT_PROFILE_RESOLVER.BLACKSTONE_CITY_ID
var _city_layout_runtime_states: Dictionary = {}
var _definitions_by_id: Dictionary = {}
var _mission_definitions_by_id: Dictionary = {}
var _generals_by_id: Dictionary = {}
var _tech_by_id: Dictionary = {}
var _next_placement_id := 1
var _detail_panel_active := false
var _selected_definition: BuildingDefinition
var _build_slot: Dictionary = _empty_build_slot()
var _readiness_checkpoint: Dictionary = {}
var _active_battle_reservation: Dictionary = {}
var _closed_battle_transactions: Dictionary = {}
var _committed_battle_result_ids: Dictionary = {}
var _designated_combat_transaction_coordinator: CombatTransactionCoordinator
var _battle_result_commit_in_flight_ids: Dictionary = {}
var _first_clear_keys: Dictionary = {}
var _last_battle_result_summary: Dictionary = {}
var _first_war_pending_outcome: StringName = &""
var _first_war_result_acknowledged := false
var _formal_battle_scene: C0BattleGraybox
var _active_noticeboard_mission_id: StringName = &""
var _completed_noticeboard_mission_ids: Dictionary = {}
var _noticeboard_last_result_summary: Dictionary = {}
var _next_battle_transaction_sequence := 1
var _expedition_attempt: Dictionary = {}
var _expedition_commit_in_progress := false
var _expedition_commit_blocked := false
var _war_loop_state: WarLoopState = WAR_LOOP_STATE.new()
var _war_loop_frame_remainder_milliseconds := 0.0
var _macro_march_frame_remainders_by_order: Dictionary = {}
var _macro_march_traces_for_war_step: Dictionary = {}
# Test-only fault seams verify Field transaction rollback after an existing
# NationState commit. They are never serialized and production code has no caller.
var _field_supply_fault_for_test: StringName = &""
var _field_reinforcement_fault_for_test: StringName = &""
var _field_watchtower_fault_for_test: StringName = &""
var _wartime_session_checkpoint_fault_for_test: StringName = &""
var _city_strategy_fault_for_test: StringName = &""


func _ready() -> void:
	_ensure_war_loop_initialized()
	if _population_recovery.total_living <= 0:
		_population_recovery.initialize_fresh(RECOVERY_RULES, _garrison_state.get_total_count())
	if _city_governance.last_applied_day <= 0:
		_city_governance.initialize_fresh(CITY_GOVERNANCE_RULES)
	if _city_strategy.unlocked_official_ids.is_empty() and _city_strategy.campaign_energy <= 0:
		_city_strategy.initialize_fresh(CITY_STRATEGY_RULES)
	_register_definition(ROAD_DEFINITION)
	_register_definition(LOGGING_CAMP_DEFINITION)
	_register_definition(FARM_DEFINITION)
	_register_definition(WAREHOUSE_DEFINITION)
	_register_definition(WATCHTOWER_DEFINITION)
	_register_definition(HOUSING_DEFINITION)
	_register_definition(CLINIC_DEFINITION)
	_register_strategy_definitions()
	_register_noticeboard_missions()
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
	rotate_placement_button.pressed.connect(rotate_preview)
	confirm_road_button.pressed.connect(confirm_road_preview)
	cancel_placement_button.pressed.connect(cancel_placing)
	build_slot_primary_button.pressed.connect(_on_build_slot_primary_pressed)
	build_slot_cancel_button.pressed.connect(cancel_build_project)
	pause_button.pressed.connect(toggle_city_time_paused)
	time_speed_option.item_selected.connect(_on_time_speed_selected)
	recruit_button.pressed.connect(queue_training)
	general_option.item_selected.connect(_on_general_selected)
	tech_option.item_selected.connect(_on_tech_selected)
	research_button.pressed.connect(_on_research_pressed)
	emergency_mobilization_button.pressed.connect(emergency_mobilization)
	restore_checkpoint_button.pressed.connect(restore_readiness_checkpoint)
	restart_map_button.pressed.connect(restart_first_map)
	enter_first_war_button.pressed.connect(open_expedition_preparation)
	current_mainline_entry_button.pressed.connect(
		_on_current_mainline_entry_pressed
	)
	alert_summary.mouse_filter = Control.MOUSE_FILTER_STOP
	alert_summary.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alert_summary.gui_input.connect(_on_campaign_status_input)
	enter_wartime_defense_button.pressed.connect(enter_wartime_defense_battle)
	expedition_preparation_panel.selection_changed.connect(
		_on_expedition_selection_changed
	)
	expedition_preparation_panel.confirm_requested.connect(
		_on_expedition_confirm_requested
	)
	expedition_preparation_panel.cancel_requested.connect(
		close_expedition_preparation
	)
	order_retreat_button.pressed.connect(
		request_first_war_retreat_confirmation
	)
	confirm_retreat_button.pressed.connect(confirm_first_war_retreat)
	cancel_retreat_button.pressed.connect(
		cancel_first_war_retreat_confirmation
	)
	acknowledge_war_result_button.pressed.connect(
		acknowledge_first_war_result
	)
	noticeboard_close_button.pressed.connect(hide_noticeboard_panel)
	for mission in NOTICEBOARD_MISSIONS:
		var card := _get_noticeboard_card(mission.mission_id)
		var start_button := card.get_node("StartButton") as Button
		start_button.pressed.connect(
			start_noticeboard_mission.bind(mission.mission_id)
		)
	preview_entrance_marker = Polygon2D.new()
	preview_entrance_marker.name = "PreviewEntranceMarker"
	preview_entrance_marker.z_index = 2
	preview_entrance_marker.visible = false
	construction_preview.add_child(preview_entrance_marker)
	preview_conflict_mark = Line2D.new()
	preview_conflict_mark.name = "PreviewConflictMark"
	preview_conflict_mark.default_color = PREVIEW_INVALID_OUTLINE
	preview_conflict_mark.width = 4.0
	preview_conflict_mark.z_index = 3
	preview_conflict_mark.visible = false
	construction_preview.add_child(preview_conflict_mark)
	construction_preview.visible = false
	_configure_time_speed_options()
	_update_threat_for_current_day(false)
	_update_first_war_state_for_current_day()
	_refresh_road_visual_projection()
	_sync_construction_ui()
	_refresh_city_ui()


func get_nation_state() -> NationState:
	return _nation_state


func get_active_city_id() -> StringName:
	return _active_city_id


func get_active_city_name() -> String:
	return CITY_LAYOUT_PROFILE_RESOLVER.city_name(_active_city_id)


func get_layout_profile_id() -> StringName:
	if not is_instance_valid(city_spatial_foundation):
		return CITY_LAYOUT_PROFILE_RESOLVER.resolve_profile_id(_active_city_id)
	return city_spatial_foundation.get_layout_profile_id()


func get_layout_profile_name() -> String:
	return CITY_LAYOUT_PROFILE_RESOLVER.profile_name(get_layout_profile_id())


func get_layout_camera_focus() -> Vector2:
	return city_spatial_foundation.get_camera_focus()


func get_layout_profile_snapshot() -> Dictionary:
	return city_spatial_foundation.get_layout_profile_snapshot()


func switch_city(next_city_id: StringName) -> bool:
	if not CITY_LAYOUT_PROFILE_RESOLVER.is_known_city(next_city_id):
		return false
	if next_city_id == _active_city_id:
		return true
	if (
		is_placing()
		or has_build_project()
		or _road_drag_active
		or is_city_action_locked_for_battle()
		or not _active_battle_reservation.is_empty()
	):
		return false
	var previous_city_id := _active_city_id
	_capture_city_layout_runtime_state(_active_city_id)
	var previous_snapshot: Dictionary = _city_layout_runtime_states.get(
		previous_city_id,
		{}
	).duplicate(true)
	_clear_runtime_placements_for_city_switch()
	if not city_spatial_foundation.set_city_id(next_city_id):
		_restore_city_after_switch_failure(previous_city_id, previous_snapshot)
		return false
	if not _sync_fixed_records_to_current_profile():
		_restore_city_after_switch_failure(previous_city_id, previous_snapshot)
		return false
	_active_city_id = next_city_id
	if not _restore_city_layout_runtime_state(
		_city_layout_runtime_states.get(next_city_id, {})
	):
		_restore_city_after_switch_failure(previous_city_id, previous_snapshot)
		return false
	_refresh_road_visual_projection()
	_refresh_city_ui()
	_sync_construction_ui()
	construction_presentation_changed.emit()
	city_state_changed.emit()
	return true


func _restore_city_after_switch_failure(
	previous_city_id: StringName,
	previous_snapshot: Dictionary
) -> void:
	_clear_runtime_placements_for_city_switch()
	city_spatial_foundation.set_city_id(previous_city_id)
	_sync_fixed_records_to_current_profile()
	_active_city_id = previous_city_id
	_restore_city_layout_runtime_state(previous_snapshot)
	_refresh_road_visual_projection()


func get_city_layout_state_snapshot() -> Dictionary:
	return {
		"city_id": _active_city_id,
		"layout_profile_id": get_layout_profile_id(),
		"runtime_placement_ids": _get_runtime_placement_ids(),
		"player_road_cells": get_player_road_cells(),
	}


func _get_runtime_placement_ids() -> Array[int]:
	var ids: Array[int] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and record.placement_kind != PLACEMENT_KIND_FIXED
		):
			ids.append(placement_id)
	return ids


func _capture_city_layout_runtime_state(for_city_id: StringName) -> void:
	var placements: Array[Dictionary] = []
	for placement_id in _get_runtime_placement_ids():
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		placements.append({
			"placement_id": placement_id,
			"definition_id": StringName(record.definition_id),
			"origin_cell": Vector2i(record.origin_cell),
			"orientation": int(record.get("orientation", ORIENTATION_NORTH)),
			"lifecycle_state": StringName(record.lifecycle_state),
			"built_day": int(record.built_day),
			"disabled_until_day": int(record.disabled_until_day),
			"construction_started_day": int(record.construction_started_day),
			"construction_complete_day": int(record.construction_complete_day),
		})
	_city_layout_runtime_states[for_city_id] = {
		"placements": placements,
		"next_placement_id": _next_placement_id,
	}.duplicate(true)


func _clear_runtime_placements_for_city_switch() -> void:
	var runtime_ids := _get_runtime_placement_ids()
	for placement_id in runtime_ids:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		var building := record.get("node") as Node2D
		_release_runtime_record(placement_id, true, false)
		if is_instance_valid(building):
			if building.get_parent() == placed_buildings:
				placed_buildings.remove_child(building)
			building.queue_free()


func _restore_city_layout_runtime_state(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return true
	var max_id := _next_placement_id
	for placement_value in snapshot.get("placements", []):
		var placement: Dictionary = placement_value
		var definition := get_definition(StringName(placement.definition_id))
		if not _register_runtime_placement_record(
			int(placement.placement_id),
			Vector2i(placement.origin_cell),
			definition,
			int(placement.get("orientation", ORIENTATION_NORTH)),
			StringName(placement.lifecycle_state),
			int(placement.built_day),
			int(placement.disabled_until_day),
			int(placement.construction_started_day),
			int(placement.construction_complete_day)
		):
			return false
		max_id = maxi(max_id, int(placement.placement_id) + 1)
	_next_placement_id = maxi(
		max_id,
		int(snapshot.get("next_placement_id", max_id))
	)
	return true


func _sync_fixed_records_to_current_profile() -> bool:
	var next_occupied: Dictionary = {}
	var fixed_updates: Array[Dictionary] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or record.placement_kind != PLACEMENT_KIND_FIXED:
			continue
		var node := record.get("node") as Node
		var node_name: String = node.name if node != null else ""
		var rect := city_spatial_foundation.get_profile_fixed_building_rect(node_name)
		if rect.size == Vector2.ZERO:
			return false
		var origin := Vector2i(
			floori(rect.position.x / GRID_SIZE),
			floori(rect.position.y / GRID_SIZE)
		)
		var footprint := Vector2i(
			maxi(1, ceili(rect.size.x / GRID_SIZE)),
			maxi(1, ceili(rect.size.y / GRID_SIZE))
		)
		var cells := get_footprint_cells(origin, footprint)
		for cell in cells:
			if next_occupied.has(cell):
				return false
			next_occupied[cell] = placement_id
		fixed_updates.append({
			"record": record,
			"node": node,
			"origin": origin,
			"footprint": footprint,
			"cells": cells,
			"rect": rect,
		})
	for update in fixed_updates:
		var fixed_record: Dictionary = update.record
		fixed_record.origin_cell = update.origin
		fixed_record.footprint = update.footprint
		fixed_record.base_footprint = update.footprint
		fixed_record.occupied_footprint_cells = update.cells.duplicate()
		fixed_record.selection_bounds = Rect2(Vector2.ZERO, update.rect.size)
		var fixed_node: Node = update.node
		if is_instance_valid(fixed_node):
			if fixed_node is Control:
				(fixed_node as Control).position = update.rect.position
			elif fixed_node is Node2D:
				(fixed_node as Node2D).position = update.rect.position
	_occupied_cells = next_occupied
	return true


func _set_legacy_resource_balance(
	resource_id: StringName,
	value: int
) -> void:
	var result := _nation_state.replace_resource_balance_compatibility(
		NationState.BLACKSTONE_CITY_ID,
		resource_id,
		value,
		&"construction_controller_compatibility_setter"
	)
	if not bool(result.success):
		push_error(
			"Resource compatibility setter rejected %s: %s"
			% [resource_id, result.error_id]
		)


func _commit_national_resources(
	entries: Array[Dictionary],
	reason: StringName,
	local_commit: Callable = Callable()
) -> bool:
	return bool(_nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		entries,
		reason,
		local_commit
	).success)


func _replace_national_resources(
	resources: Dictionary,
	source: StringName
) -> bool:
	return bool(_nation_state.hydrate_shared_resources(
		resources.duplicate(true),
		source
	).success)


func _commit_national_resource_targets(
	targets: Dictionary,
	reason: StringName,
	local_commit: Callable = Callable()
) -> bool:
	var entries: Array[Dictionary] = []
	for resource_id_value in targets.keys():
		var resource_id := StringName(resource_id_value)
		var before := _nation_state.get_resource(resource_id)
		var after := int(targets[resource_id_value])
		if after == before:
			continue
		entries.append({
			"resource_id": resource_id,
			"operation": (
				NationState.RESOURCE_OPERATION_ADD
				if after > before
				else NationState.RESOURCE_OPERATION_SPEND
			),
			"amount": absi(after - before),
		})
	if entries.is_empty():
		if not local_commit.is_valid():
			return true
		var local_result = local_commit.call()
		if typeof(local_result) == TYPE_BOOL:
			return bool(local_result)
		if typeof(local_result) == TYPE_DICTIONARY:
			return (
				not Dictionary(local_result).is_empty()
				and bool(Dictionary(local_result).get("success", true))
			)
		return false
	return _commit_national_resources(entries, reason, local_commit)


func _process(delta: float) -> void:
	advance_city_time(delta * city_time_speed)
	var macro_before := get_macro_march_armies()
	_advance_all_macro_marches_seconds(delta)
	_macro_march_traces_for_war_step = _macro_army_movement_traces(
		macro_before, get_macro_march_armies(), delta * 1000.0 * city_time_speed
	)
	advance_war_loop_time_seconds(delta)
	_macro_march_traces_for_war_step.clear()
	_refresh_constructing_building_visuals()


func _refresh_constructing_building_visuals() -> void:
	# Only in-progress buildings receive per-frame presentation updates.  The
	# authoritative record, timers and resource transactions remain untouched.
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			record.is_empty()
			or StringName(record.get("lifecycle_state", &"")) != &"constructing"
		):
			continue
		_refresh_placed_building_visual(placement_id)


func is_placing() -> bool:
	return state == ConstructionState.PLACING


func is_road_placing() -> bool:
	return is_placing() and _selected_definition != null and (
		_selected_definition.placement_kind == PLACEMENT_KIND_ROAD
	)


func is_road_drag_active() -> bool:
	return is_road_placing() and _road_drag_active


func is_choosing_template() -> bool:
	return state == ConstructionState.CHOOSING_TEMPLATE


func _empty_build_slot() -> Dictionary:
	return {
		"state": BUILD_SLOT_IDLE,
		"definition_id": &"",
		"progress_milliseconds": 0,
		"required_milliseconds": 0,
		"total_costs": {},
		"paid_costs": {},
		"missing_resource_ids": [],
		"orientation": ORIENTATION_NORTH,
		"completion_notified": false,
	}


func has_build_project() -> bool:
	return StringName(_build_slot.get("state", BUILD_SLOT_IDLE)) != BUILD_SLOT_IDLE


func get_build_slot_state() -> StringName:
	return StringName(_build_slot.get("state", BUILD_SLOT_IDLE))


func get_build_slot_snapshot() -> Dictionary:
	var snapshot := _build_slot.duplicate(true)
	if StringName(snapshot.state) == BUILD_SLOT_PLACEMENT_ACTIVE:
		snapshot.state = BUILD_SLOT_READY_TO_PLACE
	return snapshot


func _has_legacy_construction() -> bool:
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and StringName(record.get("lifecycle_state", &"")) == &"constructing"
		):
			return true
	return false


func start_build_project(definition_id: StringName) -> Dictionary:
	var before := get_build_slot_state()
	if is_city_action_locked_for_battle():
		return _build_slot_result(false, &"CITY_ACTION_LOCKED", before, before)
	if _has_legacy_construction():
		_show_placement_feedback("旧存档施工完成后启用新建造队列")
		return _build_slot_result(false, &"LEGACY_CONSTRUCTION_LOCK", before, before)
	if has_build_project():
		var current_definition := get_definition(StringName(_build_slot.definition_id))
		_show_placement_feedback(
			"已有建造项目：%s" % (
				current_definition.display_name if current_definition != null else "建筑"
			)
		)
		return _build_slot_result(false, &"BUILD_SLOT_OCCUPIED", before, before)
	var definition := get_definition(definition_id)
	if (
		definition == null
		or definition.placement_kind != PLACEMENT_KIND_PLACED
		or definition.build_days <= 0
	):
		return _build_slot_result(false, &"INVALID_DEFINITION", before, before)
	var total_costs: Dictionary = {}
	if definition.wood_cost > 0:
		total_costs[&"wood"] = definition.wood_cost
	if definition.food_cost > 0:
		total_costs[&"food"] = definition.food_cost
	var paid_costs: Dictionary = {}
	for resource_id in total_costs:
		paid_costs[resource_id] = 0
	_build_slot = {
		"state": BUILD_SLOT_PRODUCING,
		"definition_id": definition.definition_id,
		"progress_milliseconds": 0,
		"required_milliseconds": maxi(
			definition.build_days * MILLISECONDS_PER_DAY,
			CONSTRUCTION_TICK_MILLISECONDS
		),
		"total_costs": total_costs,
		"paid_costs": paid_costs,
		"missing_resource_ids": [],
		"orientation": ORIENTATION_NORTH,
		"completion_notified": false,
	}
	_update_build_slot_wait_state()
	state = ConstructionState.IDLE
	_selected_definition = null
	_sync_construction_ui()
	_refresh_city_ui()
	city_state_changed.emit()
	construction_presentation_changed.emit()
	if get_build_slot_state() == BUILD_SLOT_WAITING_MATERIAL:
		_show_placement_feedback(
			"材料不足，已等待：%s" % _build_slot_missing_text(
				int(_build_slot.progress_milliseconds) > 0
			)
		)
	return _build_slot_result(true, &"", before, get_build_slot_state())


func _build_slot_result(
	success: bool,
	reason_code: StringName,
	state_before: StringName,
	state_after: StringName,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"success": success,
		"reason_code": reason_code,
		"reason_args": {},
		"state_before": state_before,
		"state_after": state_after,
	}
	result.merge(extra, false)
	return result


func open_construction_menu() -> void:
	if is_choosing_template() or is_city_action_locked_for_battle():
		return
	state = ConstructionState.CHOOSING_TEMPLATE
	_selected_definition = null
	preview_orientation = ORIENTATION_NORTH
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	preview_connection_state = &"not_required"
	preview_entrance_info = {}
	preview_entrance_marker.visible = false
	preview_conflict_mark.visible = false
	_reset_road_draft()
	_sync_construction_ui()
	construction_interaction_started.emit()
	construction_presentation_changed.emit()


func begin_placing(screen_position: Vector2) -> void:
	if get_build_slot_state() == BUILD_SLOT_READY_TO_PLACE:
		activate_ready_placement(screen_position)
		return
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
	if definition.placement_kind == PLACEMENT_KIND_ROAD:
		return begin_road_mode(screen_position)
	return bool(start_build_project(definition_id).success)


func activate_ready_placement(screen_position: Vector2) -> Dictionary:
	var before := get_build_slot_state()
	if before != BUILD_SLOT_READY_TO_PLACE:
		return _build_slot_result(false, &"NOT_READY", before, before)
	var definition := get_definition(StringName(_build_slot.definition_id))
	if definition == null:
		return _build_slot_result(false, &"INVALID_DEFINITION", before, before)
	_build_slot.state = BUILD_SLOT_PLACEMENT_ACTIVE
	_selected_definition = definition
	state = ConstructionState.PLACING
	preview_orientation = int(_build_slot.get("orientation", ORIENTATION_NORTH))
	_reset_road_draft()
	construction_preview.visible = true
	preview_body.visible = true
	preview_outline.visible = true
	preview_label.visible = true
	placement_grid.visible = true
	_apply_preview_geometry(definition, preview_orientation)
	_sync_construction_ui()
	update_preview(screen_position)
	placing_started.emit()
	construction_presentation_changed.emit()
	return _build_slot_result(
		true,
		&"",
		before,
		BUILD_SLOT_PLACEMENT_ACTIVE
	)


func begin_road_mode(screen_position: Vector2) -> bool:
	if is_city_action_locked_for_battle():
		return false
	var definition := get_definition(ROAD_DEFINITION.definition_id)
	if definition == null:
		return false
	_selected_definition = definition
	state = ConstructionState.PLACING
	preview_orientation = ORIENTATION_NORTH
	_road_draft = {}
	_road_drag_active = false
	_road_preview_fixed = false
	construction_preview.visible = true
	construction_preview.position = Vector2.ZERO
	preview_body.visible = false
	preview_outline.visible = false
	preview_label.visible = false
	placement_grid.visible = false
	preview_entrance_marker.visible = false
	preview_conflict_mark.visible = false
	road_preview_visual.clear_preview()
	_sync_construction_ui()
	_update_road_preview_from_screen(screen_position)
	placing_started.emit()
	construction_presentation_changed.emit()
	return true


func cancel_placing() -> void:
	if not is_placing():
		return
	var returning_ready := (
		StringName(_build_slot.get("state", BUILD_SLOT_IDLE))
		== BUILD_SLOT_PLACEMENT_ACTIVE
		and not is_road_placing()
	)
	if returning_ready:
		_build_slot.state = BUILD_SLOT_READY_TO_PLACE
		_build_slot.orientation = preview_orientation
	state = ConstructionState.IDLE
	_selected_definition = null
	preview_orientation = ORIENTATION_NORTH
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	preview_connection_state = &"not_required"
	preview_entrance_info = {}
	preview_entrance_marker.visible = false
	preview_conflict_mark.visible = false
	_reset_road_draft()
	_sync_construction_ui()
	city_state_changed.emit()
	construction_presentation_changed.emit()


func cancel_build_interaction() -> void:
	if (
		is_placing()
		and get_build_slot_state() == BUILD_SLOT_PLACEMENT_ACTIVE
		and not is_road_placing()
	):
		cancel_placing()
		return
	if state == ConstructionState.IDLE:
		return
	state = ConstructionState.IDLE
	_selected_definition = null
	preview_orientation = ORIENTATION_NORTH
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	preview_connection_state = &"not_required"
	preview_entrance_info = {}
	preview_entrance_marker.visible = false
	preview_conflict_mark.visible = false
	_reset_road_draft()
	_sync_construction_ui()
	construction_presentation_changed.emit()


func handle_escape() -> bool:
	if is_road_placing():
		if has_road_preview():
			cancel_road_preview()
			return true
		cancel_placing()
		return true
	if is_placing():
		cancel_placing()
		return true
	if not is_choosing_template():
		return false
	cancel_build_interaction()
	return true


func set_detail_panel_active(active: bool) -> void:
	_detail_panel_active = active
	_sync_construction_ui()


func is_construction_ui_point(screen_position: Vector2) -> bool:
	# During a stretched native window run, the OS pointer coordinates can be
	# expressed in physical pixels while the root input event is evaluated in
	# viewport coordinates. The GUI layer still resolves the hovered control
	# correctly, so use that authoritative hit result to keep a rail click from
	# leaking into map placement before the Button receives its pressed signal.
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		for ui_control in [
			construction_entry_panel,
			construction_menu,
			pause_button,
			city_bar_toggle,
			noticeboard_panel,
		]:
			if (
				ui_control.is_visible_in_tree()
				and (
					hovered_control == ui_control
					or ui_control.is_ancestor_of(hovered_control)
				)
			):
				return true
	for ui_control in [
		construction_entry_panel,
		construction_menu,
		pause_button,
		city_bar_toggle,
		noticeboard_panel,
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
	if is_road_placing():
		if _road_drag_active:
			_update_road_preview_from_screen(screen_position)
		return
	var map_local_position := screen_to_map_local(screen_position)
	preview_origin_cell = map_position_to_origin_cell(
		map_local_position,
		get_rotated_footprint(_selected_definition, preview_orientation)
	)
	_refresh_preview_for_current_cell()


func commit_building_from_map_click(screen_position: Vector2) -> Dictionary:
	if (
		not is_placing()
		or _selected_definition == null
		or is_road_placing()
		or get_build_slot_state() != BUILD_SLOT_PLACEMENT_ACTIVE
	):
		return _commit_result(false, &"INVALID_MAP_TARGET", "无法放置：请选择城内空地")
	# The click coordinate, preview, and final validation intentionally share one
	# update. This prevents a stale ghost after crossing the rail or resizing.
	update_preview(screen_position)
	if not preview_valid:
		var blocked_message := _ready_placement_failure_message(_last_preview_validation)
		_show_placement_feedback(blocked_message)
		return _commit_result(
			false,
			StringName(_last_preview_validation.get("reason_code", &"UNKNOWN_COMMIT_FAILURE")),
			blocked_message,
			_last_preview_validation
		)
	var definition_id := _selected_definition.definition_id
	var committed_origin := preview_origin_cell
	var committed_orientation := preview_orientation
	var commit_validation := evaluate_origin_cell_for_definition(
		committed_origin,
		_selected_definition,
		false,
		_selected_definition.build_days <= 0,
		committed_orientation
	)
	if not bool(commit_validation.valid):
		_refresh_preview_for_current_cell()
		var changed_message := _ready_placement_failure_message(commit_validation)
		_show_placement_feedback(changed_message)
		return _commit_result(
			false,
			StringName(commit_validation.get("reason_code", &"STATE_CHANGED")),
			changed_message,
			commit_validation
		)
	var placement_id := place_definition_at_cell(
		definition_id,
		committed_origin,
		false,
		true,
		committed_orientation
	)
	if placement_id < 0:
		var unknown_message := "放置失败，请重试（R0C-UNKNOWN）"
		push_error(
			"R0C_UNKNOWN_COMMIT_FAILURE definition=%s cell=%s orientation=%d"
			% [definition_id, committed_origin, committed_orientation]
		)
		_show_placement_feedback(unknown_message)
		return _commit_result(false, &"UNKNOWN_COMMIT_FAILURE", unknown_message)
	_build_slot = _empty_build_slot()
	cancel_placing()
	_refresh_city_ui()
	city_state_changed.emit()
	return {
		"success": true,
		"reason_code": CITY_GRID_RULES.REASON_NONE,
		"reason_text": "",
		"placement_id": placement_id,
		"origin_cell": committed_origin,
		"orientation": committed_orientation,
	}


func _commit_result(
	success: bool,
	reason_code: StringName,
	reason_text: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"success": success,
		"reason_code": reason_code,
		"reason_text": reason_text,
	}
	result.merge(extra, false)
	return result


func confirm_current_preview() -> bool:
	if (
		not is_placing()
		or not preview_valid
		or _selected_definition == null
	):
		return false
	if is_road_placing():
		return confirm_road_preview()
	# R0C has no independent building confirmation action. A paid ready token is
	# consumed only by the real map left click path above.
	return false


func get_last_preview_validation() -> Dictionary:
	return _last_preview_validation.duplicate(true)


func get_placement_feedback_text() -> String:
	return placement_feedback.text if placement_feedback.visible else ""


func begin_road_drag(screen_position: Vector2) -> bool:
	if not is_road_placing():
		return false
	var cell := _screen_to_cell(screen_position)
	_road_drag_active = true
	_road_preview_fixed = false
	_road_drag_start_cell = cell
	_road_drag_current_cell = cell
	_update_road_preview_cells([cell])
	return true


func update_road_drag(screen_position: Vector2) -> bool:
	if not is_road_placing() or not _road_drag_active:
		return false
	_road_drag_current_cell = _screen_to_cell(screen_position)
	_update_road_preview_cells([
		_road_drag_start_cell,
		_road_drag_current_cell,
	])
	return true


func finish_road_drag(screen_position: Vector2) -> bool:
	if not is_road_placing() or not _road_drag_active:
		return false
	_road_drag_active = false
	_road_preview_fixed = true
	if not is_construction_ui_point(screen_position):
		_road_drag_current_cell = _screen_to_cell(screen_position)
	_update_road_preview_cells([
		_road_drag_start_cell,
		_road_drag_current_cell,
	])
	return true


func has_road_preview() -> bool:
	return is_road_placing() and not _road_draft.is_empty()


func cancel_road_preview() -> void:
	if not is_road_placing():
		return
	_reset_road_draft()
	_road_drag_active = false
	_road_preview_fixed = false
	preview_valid = false
	preview_invalid_reason = ""
	preview_connection_state = &"not_required"
	road_preview_visual.clear_preview()
	_sync_construction_ui()
	construction_presentation_changed.emit()


func confirm_road_preview() -> bool:
	if (
		not is_road_placing()
		or not _road_preview_fixed
		or not preview_valid
		or _road_draft.is_empty()
	):
		return false
	var cells: Array[Vector2i] = _road_draft.unique_cells.duplicate()
	if not _road_recommendation_preview.is_empty():
		if not _is_current_road_recommendation_preview(cells):
			_show_placement_feedback("接通方案已过期，请重新查看方案")
			cancel_road_preview()
			return false
	var result := place_player_road_path(cells)
	if not bool(result.success):
		preview_valid = false
		preview_invalid_reason = str(result.reason)
		_update_road_preview_cells(_road_draft.sampled_cells)
		_sync_construction_ui()
		return false
	cancel_placing()
	return true


func _update_road_preview_from_screen(screen_position: Vector2) -> void:
	var cell := _screen_to_cell(screen_position)
	if _road_drag_active:
		_road_drag_current_cell = cell
		_update_road_preview_cells([
			_road_drag_start_cell,
			_road_drag_current_cell,
		])
	else:
		_update_road_preview_cells([cell])


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	return map_position_to_origin_cell(
		screen_to_map_local(screen_position),
		Vector2i.ONE
	)


func _update_road_preview_cells(sampled_cells: Array[Vector2i]) -> void:
	if not is_road_placing():
		return
	var draft: Dictionary = CITY_ROAD_DRAFT.build_draft(sampled_cells)
	var unique_cells: Array[Vector2i] = []
	for value in draft.get("unique_cells", []):
		unique_cells.append(Vector2i(value))
	_road_draft = {
		"sampled_cells": sampled_cells.duplicate(),
		"ordered_cells": draft.get("ordered_cells", []).duplicate(),
		"unique_cells": unique_cells.duplicate(),
		"valid_axis": bool(draft.get("valid", false)),
	}
	if not bool(_road_draft.valid_axis):
		preview_valid = false
		preview_invalid_reason = "道路必须水平或垂直拖拽"
		preview_connection_state = &"invalid"
		road_preview_visual.set_preview(
			unique_cells,
			&"invalid",
			GRID_SIZE
		)
		_sync_construction_ui()
		return
	var validation := evaluate_road_path(unique_cells)
	preview_valid = bool(validation.valid)
	preview_invalid_reason = str(validation.reason)
	preview_connection_state = StringName(
		validation.get("connection_state", &"invalid")
	)
	var visual_status := preview_connection_state
	if not preview_valid:
		visual_status = &"invalid"
	road_preview_visual.set_preview(unique_cells, visual_status, GRID_SIZE)
	_sync_construction_ui()
	construction_presentation_changed.emit()


func _reset_road_draft() -> void:
	_road_draft = {}
	_road_drag_active = false
	_road_preview_fixed = false
	_road_recommendation_preview = {}
	if is_instance_valid(road_preview_visual):
		road_preview_visual.clear_preview()


func query_road_connection_recommendation(placement_id: int) -> Dictionary:
	# A recommendation is a read-only query over the current canonical grid. It
	# intentionally owns neither a road graph nor a pending transaction.
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return _road_recommendation_result(
			&"unavailable", placement_id, "目标建筑已不存在"
		)
	if not bool(record.get("requires_road", false)):
		return _road_recommendation_result(
			&"unavailable", placement_id, "该建筑不需要道路"
		)
	var entrance := get_building_entrance_info(placement_id)
	if not bool(entrance.get("valid", false)):
		return _road_recommendation_result(
			&"unavailable", placement_id, "建筑入口无效，无法生成接通方案"
		)
	if bool(entrance.get("connected", false)):
		return _road_recommendation_result(
			&"unavailable", placement_id, "该建筑已接入城市路网"
		)

	var start := Vector2i(entrance.get("road_contact_cell", Vector2i.ZERO))
	var connected_roads := get_connected_road_cells()
	if connected_roads.is_empty():
		return _road_recommendation_result(
			&"unavailable", placement_id, "当前没有可接入的主路网"
		)
	if not _is_recommendation_transit_cell_legal(start):
		return _road_recommendation_result(
			&"unavailable", placement_id, "建筑入口旁没有可铺设的道路格"
		)

	var frontier: Array[Vector2i] = [start]
	var frontier_index := 0
	var distance_by_cell: Dictionary = {start: 0}
	var paths_by_cell: Dictionary = {start: 1}
	var parent_by_cell: Dictionary = {}
	var shortest_goal_distance := -1
	var shortest_goal_paths := 0
	var shortest_goal_end := Vector2i.ZERO

	while frontier_index < frontier.size():
		var current := frontier[frontier_index]
		frontier_index += 1
		var current_distance := int(distance_by_cell[current])
		if (
			shortest_goal_distance >= 0
			and current_distance + 1 > shortest_goal_distance
		):
			continue
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = current + direction
			var candidate_distance := current_distance + 1
			if connected_roads.has(neighbor):
				if shortest_goal_distance < 0:
					shortest_goal_distance = candidate_distance
				if candidate_distance == shortest_goal_distance:
					shortest_goal_paths = mini(
						2,
						shortest_goal_paths + int(paths_by_cell[current])
					)
					if shortest_goal_paths == 1:
						shortest_goal_end = neighbor
				continue
			if not _is_recommendation_transit_cell_legal(neighbor):
				continue
			if not distance_by_cell.has(neighbor):
				distance_by_cell[neighbor] = candidate_distance
				paths_by_cell[neighbor] = int(paths_by_cell[current])
				parent_by_cell[neighbor] = current
				frontier.append(neighbor)
			elif int(distance_by_cell[neighbor]) == candidate_distance:
				paths_by_cell[neighbor] = mini(
					2,
					int(paths_by_cell[neighbor]) + int(paths_by_cell[current])
				)

	if shortest_goal_paths <= 0:
		return _road_recommendation_result(
			&"unavailable", placement_id, "没有合法的接通路径，请手动规划"
		)
	if shortest_goal_paths > 1:
		return _road_recommendation_result(
			&"ambiguous", placement_id, "存在多种接通方式，请手动规划。"
		)

	var end_parent := Vector2i.ZERO
	# The terminal is an existing connected road. Locate its sole predecessor by
	# walking the frontier relation rather than adding that road to new cells.
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var candidate_parent: Vector2i = shortest_goal_end + direction
		if (
			distance_by_cell.has(candidate_parent)
			and int(distance_by_cell[candidate_parent]) + 1 == shortest_goal_distance
		):
			end_parent = candidate_parent
			break
	if not distance_by_cell.has(end_parent):
		return _road_recommendation_result(
			&"unavailable", placement_id, "接通路径状态无效，请手动规划"
		)
	var cells := _reconstruct_recommendation_path(
		start, end_parent, parent_by_cell
	)
	cells.append(shortest_goal_end)
	var validation := evaluate_road_path(cells)
	if not bool(validation.valid):
		return _road_recommendation_result(
			&"unavailable", placement_id,
			str(validation.get("reason", "没有合法的接通路径，请手动规划"))
		)
	return _road_recommendation_result(
		&"recommended", placement_id, "已找到唯一最短接通方案", cells,
		int(validation.get("cost", 0))
	)


func preview_road_connection_recommendation(placement_id: int) -> Dictionary:
	var recommendation := query_road_connection_recommendation(placement_id)
	if StringName(recommendation.status) != &"recommended":
		return recommendation
	var cells: Array[Vector2i] = []
	for cell_value in recommendation.cells:
		cells.append(Vector2i(cell_value))
	if cells.is_empty():
		return _road_recommendation_result(
			&"unavailable", placement_id, "接通方案为空，请手动规划"
		)
	var preview_screen := map_local_to_screen(
		cell_to_map_local(cells.front()) + Vector2(GRID_SIZE * 0.5, GRID_SIZE * 0.5)
	)
	if not begin_road_mode(preview_screen):
		return _road_recommendation_result(
			&"unavailable", placement_id, "当前无法进入道路预览"
		)
	_set_recommended_road_preview_cells(cells)
	if not preview_valid:
		var failure := preview_invalid_reason
		cancel_road_preview()
		return _road_recommendation_result(&"unavailable", placement_id, failure)
	_road_recommendation_preview = {
		"placement_id": placement_id,
		"cells": cells.duplicate(),
	}
	# Refresh after tagging the draft so the existing road panel can present the
	# target, cost, and manual alternative rather than generic drag copy.
	_sync_construction_ui()
	construction_presentation_changed.emit()
	return recommendation


func switch_recommended_road_to_manual() -> bool:
	if not is_road_placing():
		return false
	# Leave no hidden auto-route behind before the existing manual drag flow starts.
	cancel_road_preview()
	return begin_road_mode(get_viewport().get_mouse_position())


func has_road_connection_recommendation_preview() -> bool:
	return is_road_placing() and not _road_recommendation_preview.is_empty()


func _is_current_road_recommendation_preview(cells: Array[Vector2i]) -> bool:
	var placement_id := int(_road_recommendation_preview.get("placement_id", -1))
	var recommendation := query_road_connection_recommendation(placement_id)
	if StringName(recommendation.get("status", &"unavailable")) != &"recommended":
		return false
	var current_cells: Array = recommendation.get("cells", [])
	if current_cells.size() != cells.size():
		return false
	for index in current_cells.size():
		if Vector2i(current_cells[index]) != cells[index]:
			return false
	return true


func _set_recommended_road_preview_cells(cells: Array[Vector2i]) -> void:
	_road_draft = {
		"sampled_cells": cells.duplicate(),
		"ordered_cells": cells.duplicate(),
		"unique_cells": cells.duplicate(),
		"valid_axis": true,
	}
	_road_drag_active = false
	_road_preview_fixed = true
	var validation := evaluate_road_path(cells)
	preview_valid = bool(validation.valid)
	preview_invalid_reason = str(validation.reason)
	preview_connection_state = StringName(
		validation.get("connection_state", &"invalid")
	)
	road_preview_visual.set_preview(
		cells,
		preview_connection_state if preview_valid else &"invalid",
		GRID_SIZE
	)
	_sync_construction_ui()
	construction_presentation_changed.emit()


func _is_recommendation_transit_cell_legal(cell: Vector2i) -> bool:
	if get_all_road_cells().has(cell):
		return false
	var legality := evaluate_spatial_legality(PLACEMENT_KIND_ROAD, [cell])
	return bool(legality.get("is_legal", false))


func _reconstruct_recommendation_path(
	start: Vector2i,
	end: Vector2i,
	parent_by_cell: Dictionary
) -> Array[Vector2i]:
	var reversed: Array[Vector2i] = [end]
	var current := end
	while current != start:
		if not parent_by_cell.has(current):
			return []
		current = Vector2i(parent_by_cell[current])
		reversed.append(current)
	reversed.reverse()
	return reversed


func _road_recommendation_result(
	status: StringName,
	placement_id: int,
	message: String,
	cells: Array[Vector2i] = [],
	wood_cost := 0
) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	return {
		"status": status,
		"placement_id": placement_id,
		"target_name": str(record.get("display_name", "目标建筑")),
		"message": message,
		"cells": cells.duplicate(),
		"path_length": cells.size(),
		"wood_cost": wood_cost,
		"connection_result": "接入主路网" if status == &"recommended" else "",
		"completion_method": "立即铺设" if status == &"recommended" else "",
	}


func evaluate_road_path(cells: Array[Vector2i]) -> Dictionary:
	if cells.is_empty():
		return _road_validation(false, "请选择道路起点和终点")
	var ordered: Array[Vector2i] = []
	for cell in cells:
		if ordered.is_empty() or ordered.back() != cell:
			ordered.append(cell)
	for index in range(1, ordered.size()):
		var delta := ordered[index] - ordered[index - 1]
		if absi(delta.x) + absi(delta.y) != 1:
			return _road_validation(false, "道路路径必须保持正交连续")
	var all_roads := get_all_road_cells()
	var new_cells: Array[Vector2i] = []
	var seen_new: Dictionary = {}
	for cell in ordered:
		if all_roads.has(cell):
			continue
		if seen_new.has(cell):
			continue
		seen_new[cell] = true
		new_cells.append(cell)
	if new_cells.is_empty():
		return _road_validation(false, "所选格子已经是道路")
	var spatial := evaluate_spatial_legality(PLACEMENT_KIND_ROAD, new_cells)
	if not bool(spatial.is_legal):
		return _road_validation(
			false,
			str(spatial.reason_text),
			&"invalid",
			new_cells,
			0,
			spatial
		)
	for cell in new_cells:
		var screen_rect := get_footprint_screen_rect(cell, Vector2i.ONE)
		if not _screen_rect_is_inside_viewport(screen_rect):
			return _road_validation(false, "道路超出可操作区域")
		for ui_control in _get_ui_occlusion_controls():
			if (
				ui_control.is_visible_in_tree()
				and ui_control.get_global_rect().grow(UI_SAFETY_MARGIN).intersects(screen_rect)
			):
				return _road_validation(false, "道路位置被界面遮挡")
	var candidate_roads := all_roads.duplicate(true)
	for cell in new_cells:
		candidate_roads[cell] = true
	var connected := CITY_GRID_RULES.get_connected_road_cells(
		candidate_roads,
		city_spatial_foundation.get_road_root_cells()
	)
	var is_connected := false
	for cell in new_cells:
		if connected.has(cell):
			is_connected = true
			break
	var cost := new_cells.size() * ROAD_DEFINITION.wood_cost
	if wood < cost:
		return _road_validation(
			false,
			"木材不足（需要 %d）" % cost,
			&"connected" if is_connected else &"isolated",
			new_cells,
			cost
		)
	return _road_validation(
		true,
		"",
		&"connected" if is_connected else &"isolated",
		new_cells,
		cost
	)


func _road_validation(
	valid: bool,
	reason: String,
	connection_state: StringName = &"invalid",
	new_cells: Array[Vector2i] = [],
	cost := 0,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"valid": valid,
		"is_legal": valid,
		"reason": reason,
		"reason_text": reason,
		"reason_code": CITY_GRID_RULES.REASON_NONE,
		"conflicting_cells": [],
		"conflicting_placement_ids": [],
		"connection_state": connection_state,
		"new_cells": new_cells.duplicate(),
		"cost": cost,
	}
	result.merge(extra, true)
	return result


func _road_block_reason(record: Dictionary) -> String:
	if StringName(record.get("lifecycle_state", &"")) == &"constructing":
		return "道路穿过施工体"
	if record.get("placement_kind", &"") == PLACEMENT_KIND_ROAD:
		return "已经是道路"
	return "道路穿过建筑占地"


func _cell_is_inside_city(cell: Vector2i) -> bool:
	var map_grid_size: Vector2i = city_spatial_foundation.get_map_grid_size()
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < map_grid_size.x
		and cell.y < map_grid_size.y
	)


func place_player_road_path(cells: Array[Vector2i]) -> Dictionary:
	var validation := evaluate_road_path(cells)
	if not bool(validation.valid):
		return validation
	var new_cells: Array[Vector2i] = []
	for value in validation.new_cells:
		new_cells.append(Vector2i(value))
	var previous_next_id := _next_placement_id
	var allocated_ids: Array[int] = []
	for _cell in new_cells:
		allocated_ids.append(_allocate_placement_id())
	var registered_ids: Array[int] = []
	var register_path := func() -> Dictionary:
		for index in range(new_cells.size()):
			var registered := _register_runtime_placement_record(
				allocated_ids[index],
				new_cells[index],
				ROAD_DEFINITION,
				ORIENTATION_NORTH,
				&"running",
				current_day,
				0,
				current_day,
				current_day
			)
			if not registered:
				for registered_id in registered_ids:
					_release_runtime_record(registered_id, true, false)
				_next_placement_id = previous_next_id
				return {"success": false, "reason": "道路权威写入被拒绝"}
			registered_ids.append(allocated_ids[index])
		return {"success": true, "placement_ids": registered_ids.duplicate()}
	var paid := _commit_national_resources(
		[{
			"resource_id": &"wood",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": int(validation.cost),
		}],
		&"player_road_construction",
		register_path
	)
	if not paid:
		_next_placement_id = previous_next_id
		return {"success": false, "reason": "道路资源事务未提交"}
	_refresh_road_visual_projection()
	_refresh_city_ui()
	city_state_changed.emit()
	return {
		"success": true,
		"placement_ids": registered_ids.duplicate(),
		"new_cells": new_cells.duplicate(),
		"cost": int(validation.cost),
		"connection_state": validation.connection_state,
	}


func get_road_draft_snapshot() -> Dictionary:
	return _road_draft.duplicate(true)


func get_player_road_cells() -> Dictionary:
	var result: Dictionary = {}
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or record.placement_kind != PLACEMENT_KIND_ROAD:
			continue
		for cell in record.occupied_footprint_cells:
			result[Vector2i(cell)] = true
	return result


func get_all_road_cells() -> Dictionary:
	var result := city_spatial_foundation.get_formal_road_cells()
	for cell in get_player_road_cells():
		result[Vector2i(cell)] = true
	return result


func scan_current_placement_overlaps(mark_legacy := false) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var roads := get_all_road_cells()
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			record.is_empty()
			or StringName(record.placement_kind) == PLACEMENT_KIND_ROAD
		):
			continue
		var conflicts: Array[Vector2i] = []
		for value in record.occupied_footprint_cells:
			var cell := Vector2i(value)
			if roads.has(cell):
				conflicts.append(cell)
		if conflicts.is_empty():
			continue
		reports.append({
			"report_code": &"LEGACY_OVERLAP" if mark_legacy else &"OVERLAP",
			"placement_id": placement_id,
			"definition_id": StringName(record.definition_id),
			"reason_code": CITY_GRID_RULES.REASON_ROAD_OVERLAP,
			"conflicting_cells": conflicts,
		})
	if mark_legacy:
		_legacy_overlap_reports = reports.duplicate(true)
	return reports


func get_legacy_overlap_reports() -> Array[Dictionary]:
	return _legacy_overlap_reports.duplicate(true)


func get_road_mask(cell: Vector2i) -> int:
	return CITY_GRID_RULES.get_road_mask(cell, get_all_road_cells())


func rotate_preview() -> bool:
	if not is_placing() or _selected_definition == null:
		return false
	if has_road_connection_recommendation_preview():
		return switch_recommended_road_to_manual()
	preview_orientation = posmod(preview_orientation + 1, 4)
	if get_build_slot_state() == BUILD_SLOT_PLACEMENT_ACTIVE and not is_road_placing():
		_build_slot.orientation = preview_orientation
	_apply_preview_geometry(_selected_definition, preview_orientation)
	_refresh_preview_for_current_cell()
	_sync_construction_ui()
	construction_presentation_changed.emit()
	return true


func get_preview_orientation() -> int:
	return preview_orientation


func get_rotated_footprint(
	definition: BuildingDefinition,
	orientation: int
) -> Vector2i:
	if definition == null:
		return Vector2i.ZERO
	var result: Dictionary = CITY_GRID_RULES.get_rotated_footprint(
		definition.footprint,
		orientation
	)
	if not bool(result.get("valid", false)):
		return Vector2i.ZERO
	return Vector2i(result.footprint)


func place_definition_at_cell(
	definition_id: StringName,
	origin_cell: Vector2i,
	charge_cost := true,
	complete_immediately := false,
	orientation := ORIENTATION_NORTH
) -> int:
	if is_city_action_locked_for_battle():
		return -1
	var definition := get_definition(definition_id)
	if definition == null:
		return -1
	if orientation < ORIENTATION_NORTH or orientation > ORIENTATION_WEST:
		return -1
	if get_rotated_footprint(definition, orientation) == Vector2i.ZERO:
		return -1
	var validation := evaluate_origin_cell_for_definition(
		origin_cell,
		definition,
		false,
		charge_cost and (complete_immediately or definition.build_days <= 0),
		orientation
	)
	if not bool(validation.valid):
		return -1
	var placement_id := _allocate_placement_id()
	var starts_completed := (
		complete_immediately
		or definition.build_days <= 0
	)
	var register_commit := Callable(
		self,
		"_register_runtime_placement_record"
	).bind(
		placement_id,
		origin_cell,
		definition,
		orientation,
		&"running" if starts_completed else &"constructing",
		current_day,
		0,
		current_day,
		(
			current_day
			if starts_completed
			else current_day + definition.build_days
		),
		charge_cost
	)
	# Immediate construction preserves the existing atomic transaction. Timed
	# construction reserves the site first and pays cumulative cost per tick.
	if charge_cost and starts_completed:
		var construction_cost_entries: Array[Dictionary] = []
		if definition.wood_cost > 0:
			construction_cost_entries.append({
				"resource_id": &"wood",
				"operation": NationState.RESOURCE_OPERATION_SPEND,
				"amount": definition.wood_cost,
			})
		if definition.food_cost > 0:
			construction_cost_entries.append({
				"resource_id": &"food",
				"operation": NationState.RESOURCE_OPERATION_SPEND,
				"amount": definition.food_cost,
			})
		var paid := (
			bool(register_commit.call())
			if construction_cost_entries.is_empty()
			else _commit_national_resources(
				construction_cost_entries,
				&"construction_placement",
				register_commit
			)
		)
		if not paid:
			_next_placement_id = placement_id
			return -1
	elif not bool(register_commit.call()):
		_next_placement_id = placement_id
		return -1
	_refresh_placed_building_visual(placement_id)
	_refresh_city_ui()
	city_state_changed.emit()
	return placement_id


func _create_runtime_building(origin_cell: Vector2i) -> int:
	return place_definition_at_cell(
		LOGGING_CAMP_DEFINITION.definition_id,
		origin_cell,
		false,
		true
	)


func move_placed_building(
	placement_id: int,
	target_origin_cell: Vector2i
) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if (
		is_city_action_locked_for_battle()
		or record.is_empty()
		or not bool(record.get("movable", false))
	):
		return {"success": false, "reason_code": &"IMMOVABLE_PLACEMENT"}
	return _reposition_placed_building(
		placement_id,
		target_origin_cell,
		int(record.orientation)
	)


func rotate_placed_building(
	placement_id: int,
	target_orientation: int
) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if (
		is_city_action_locked_for_battle()
		or record.is_empty()
		or not bool(record.get("movable", false))
		or target_orientation < ORIENTATION_NORTH
		or target_orientation > ORIENTATION_WEST
	):
		return {"success": false, "reason_code": &"IMMOVABLE_PLACEMENT"}
	return _reposition_placed_building(
		placement_id,
		Vector2i(record.origin_cell),
		target_orientation
	)


func _reposition_placed_building(
	placement_id: int,
	target_origin_cell: Vector2i,
	target_orientation: int
) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	var definition := get_definition(StringName(record.get("definition_id", &"")))
	if definition == null:
		return {"success": false, "reason_code": &"MISSING_DEFINITION"}
	var validation := evaluate_origin_cell_for_definition(
		target_origin_cell,
		definition,
		false,
		false,
		target_orientation,
		placement_id
	)
	if not bool(validation.valid):
		var rejected := validation.duplicate(true)
		rejected["success"] = false
		return rejected
	var previous_cells: Array = record.occupied_footprint_cells.duplicate()
	for cell_value in previous_cells:
		if _occupied_cells.get(Vector2i(cell_value), -1) != placement_id:
			return {"success": false, "reason_code": &"OCCUPANCY_MISMATCH"}
	var footprint := get_rotated_footprint(definition, target_orientation)
	var next_cells := get_footprint_cells(target_origin_cell, footprint)
	for cell_value in previous_cells:
		_occupied_cells.erase(Vector2i(cell_value))
	for cell in next_cells:
		_occupied_cells[cell] = placement_id
	record.origin_cell = target_origin_cell
	record.orientation = target_orientation
	record.footprint = footprint
	record.occupied_footprint_cells = next_cells.duplicate()
	record.selection_bounds = Rect2(Vector2.ZERO, Vector2(footprint) * GRID_SIZE)
	var building := record.get("node") as GrayboxBuildingVisual
	if building != null:
		building.position = cell_to_map_local(target_origin_cell)
		var entrance_info := get_building_entrance_info(placement_id)
		var selected := bool(building.get_meta("show_entrance_marker", false))
		building.configure(
			definition.definition_id,
			definition.display_name,
			definition.building_type,
			footprint,
			target_orientation,
			definition.body_color,
			definition.outline_color,
			definition.requires_road,
			false,
			StringName(record.lifecycle_state),
			_get_building_presentation_progress(record),
			StringName(entrance_info.get("connection_state", &"disconnected")),
			selected
		)
	_refresh_road_visual_projection()
	_refresh_city_ui()
	city_state_changed.emit()
	return {
		"success": true,
		"reason_code": CITY_GRID_RULES.REASON_NONE,
		"origin_cell": target_origin_cell,
		"orientation": target_orientation,
	}


func advance_city_time(simulation_delta: float) -> int:
	if (
		simulation_delta <= 0.0
		or city_time_paused
		or is_first_war_time_blocked()
	):
		return 0

	var frame_milliseconds := simulation_delta * 1000.0 + _city_frame_remainder_milliseconds
	var remaining_milliseconds := floori(frame_milliseconds + 0.000000001)
	_city_frame_remainder_milliseconds = maxf(frame_milliseconds - remaining_milliseconds, 0.0)
	if remaining_milliseconds <= 0:
		return 0
	var elapsed_milliseconds := clampi(
		roundi(day_elapsed_seconds * 1000.0),
		0,
		MILLISECONDS_PER_DAY
	)
	var advanced_days := 0
	while remaining_milliseconds > 0:
		var milliseconds_until_boundary := maxi(
			MILLISECONDS_PER_DAY - elapsed_milliseconds,
			0
		)
		if remaining_milliseconds < milliseconds_until_boundary:
			_advance_population_recovery(remaining_milliseconds)
			_advance_construction_between(
				elapsed_milliseconds,
				remaining_milliseconds
			)
			elapsed_milliseconds += remaining_milliseconds
			remaining_milliseconds = 0
			break

		_advance_population_recovery(milliseconds_until_boundary)
		_advance_construction_between(
			elapsed_milliseconds,
			milliseconds_until_boundary
		)
		remaining_milliseconds -= milliseconds_until_boundary
		elapsed_milliseconds = 0
		if not _advance_day_boundary():
			# Keep the clock at the last representable instant before the
			# boundary so clearing a preflight blocker can retry deterministically.
			elapsed_milliseconds = MILLISECONDS_PER_DAY - 1
			break
		advanced_days += 1
		if is_first_war_time_blocked():
			break

	day_elapsed_seconds = float(elapsed_milliseconds) / 1000.0
	_refresh_time_ui()
	return advanced_days


func _advance_city_time_for_battle_settlement(
	duration_milliseconds: int
) -> int:
	if duration_milliseconds <= 0:
		return 0
	var elapsed_milliseconds := clampi(
		roundi(day_elapsed_seconds * 1000.0),
		0,
		MILLISECONDS_PER_DAY
	)
	var remaining_milliseconds := duration_milliseconds
	var advanced_days := 0
	while remaining_milliseconds > 0:
		var milliseconds_until_boundary := (
			MILLISECONDS_PER_DAY - elapsed_milliseconds
		)
		if remaining_milliseconds < milliseconds_until_boundary:
			_advance_population_recovery(remaining_milliseconds)
			_advance_construction_between(
				elapsed_milliseconds,
				remaining_milliseconds
			)
			elapsed_milliseconds += remaining_milliseconds
			remaining_milliseconds = 0
			break
		_advance_population_recovery(milliseconds_until_boundary)
		_advance_construction_between(
			elapsed_milliseconds,
			milliseconds_until_boundary
		)
		remaining_milliseconds -= milliseconds_until_boundary
		elapsed_milliseconds = 0
		if not _advance_day_boundary(true):
			return -1
		advanced_days += 1
	day_elapsed_seconds = float(elapsed_milliseconds) / 1000.0
	_refresh_time_ui()
	return advanced_days


func advance_city_time_for_test(simulation_delta: float) -> int:
	return advance_city_time(simulation_delta)


func advance_city_frame_for_test(real_delta: float) -> int:
	return advance_city_time(real_delta * city_time_speed)


func advance_one_day_for_test() -> bool:
	var remaining := float(
		MILLISECONDS_PER_DAY - get_day_elapsed_milliseconds()
	) / 1000.0
	var was_paused := city_time_paused
	city_time_paused = false
	var advanced := advance_city_time(remaining) == 1
	city_time_paused = was_paused
	return advanced


func get_day_elapsed_milliseconds() -> int:
	return clampi(
		roundi(day_elapsed_seconds * 1000.0),
		0,
		MILLISECONDS_PER_DAY
	)


func set_city_time_paused(paused: bool) -> void:
	if is_first_war_time_blocked():
		return
	if city_time_paused == paused:
		return
	city_time_paused = paused
	_refresh_time_ui()
	city_state_changed.emit()


func toggle_city_time_paused() -> void:
	set_city_time_paused(not city_time_paused)


func is_city_time_paused() -> bool:
	return city_time_paused


func set_city_time_speed(speed: float) -> bool:
	if is_first_war_time_blocked() or speed not in CITY_TIME_SPEEDS:
		return false
	city_time_speed = speed
	city_time_paused = false
	_refresh_time_ui()
	city_state_changed.emit()
	return true


func get_city_time_speed() -> float:
	return city_time_speed


func is_first_war_time_blocked() -> bool:
	return (
		first_war_state == FirstWarState.IN_BATTLE
		or _is_durable_expedition_reservation()
		or (
			_first_war_pending_outcome != &""
			and not _first_war_result_acknowledged
		)
	)


func get_first_war_state_id() -> StringName:
	match first_war_state:
		FirstWarState.PREPARATION:
			return &"PREPARATION"
		FirstWarState.WARNING:
			return &"WARNING"
		FirstWarState.PENDING:
			return &"PENDING"
		FirstWarState.IN_BATTLE:
			return &"IN_BATTLE"
		FirstWarState.RESOLVED_VICTORY:
			return &"RESOLVED_VICTORY"
		FirstWarState.RESOLVED_RETREAT:
			return &"RESOLVED_RETREAT"
		FirstWarState.RESOLVED_DEFEAT:
			return &"RESOLVED_DEFEAT"
	return &"PREPARATION"


func resolve_first_war_for_test(outcome: StringName) -> bool:
	if outcome == &"VICTORY":
		first_war_state = FirstWarState.RESOLVED_VICTORY
		_current_mainline_level.mark_cleared(current_day)
		enemy_count = 0
	elif outcome == &"RETREAT":
		first_war_state = FirstWarState.RESOLVED_RETREAT
	elif outcome == &"DEFEAT":
		first_war_state = FirstWarState.RESOLVED_DEFEAT
		city_fallen = true
	else:
		return false
	_first_war_pending_outcome = &""
	_first_war_result_acknowledged = true
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_first_war_food_cost(committed_count: int) -> int:
	if committed_count <= 0:
		return 0
	return ceili(
		float(committed_count)
		/ float(INFANTRY_ROLE.maintenance_units_per_food)
	)


func get_first_war_committed_count() -> int:
	return mini(
		get_available_infantry_count(),
		get_effective_command_limit()
	)


func can_enter_first_war() -> bool:
	return (
		first_war_state in [
			# The current mainline is an opt-in battle, not a day-seven-only
			# hard gate. A legal non-empty force may answer it during preparation.
			FirstWarState.PREPARATION,
			FirstWarState.WARNING,
			FirstWarState.PENDING,
			# Retreat is a settled loss, not a mainline clear. The current-mainline
			# entry may create a fresh attempt against the same remaining threat.
			FirstWarState.RESOLVED_RETREAT,
		]
		and _active_battle_reservation.is_empty()
		and get_first_war_committed_count() > 0
		and not is_instance_valid(_formal_battle_scene)
	)


func get_first_war_force_breakdown() -> Dictionary:
	# GarrisonState is the sole owner of resident infantry. Confirmed armies are
	# removed from it at dispatch; only in-flight reservations are subtracted here.
	var battle_reserved := int(
		_active_battle_reservation.get("committed_count", 0)
	)
	var dispatch_reserved := int(
		_active_army_dispatch_reservation.get("committed_count", 0)
	)
	return {
		"total_garrison_count": infantry_count,
		"city_defense_occupied_count": 0,
		"battle_reserved_count": battle_reserved,
		"dispatch_reserved_count": dispatch_reserved,
		"already_dispatched_count": 0,
		"injured_or_unavailable_count": 0,
		"available_count": get_available_infantry_count(),
		"dispatchable_count": get_dispatchable_infantry_count(),
		"effective_command_limit": get_effective_command_limit(),
	}


func get_first_war_entry_blocked_reason() -> String:
	if _current_mainline_level.cleared:
		return "当前主线已完成，压力已解除"
	if first_war_state == FirstWarState.IN_BATTLE:
		return "当前主线交战中"
	if _first_war_pending_outcome != &"":
		return "主线战果待确认"
	if not _active_battle_reservation.is_empty():
		return "无法出征：当前编队正在转入战场"
	var force := get_first_war_force_breakdown()
	if int(force.dispatchable_count) <= 0:
		return "无法出征：没有可派编队（可派兵力 %d；城防占用 %d；受伤 %d）" % [
			int(force.dispatchable_count),
			int(force.city_defense_occupied_count),
			int(force.injured_or_unavailable_count),
		]
	return "当前主线暂不可进入"


func get_formation_roster() -> Array[Dictionary]:
	return _garrison_state.get_formations()


func get_expedition_preparation_model(
	selected_formation_ids: Array = []
) -> Dictionary:
	var selected: Array[Dictionary] = []
	if not selected_formation_ids.is_empty():
		selected = _garrison_state.get_selected_formations(selected_formation_ids)
	var selected_total := 0
	for formation in selected:
		selected_total += int(formation.member_count)
	var food_cost := get_first_war_food_cost(selected_total)
	var blocked_reason := ""
	if _expedition_commit_blocked:
		blocked_reason = "存档结果暂无法确认；请冷启动恢复后继续"
	elif not can_enter_first_war():
		blocked_reason = get_first_war_entry_blocked_reason()
	elif selected_formation_ids.is_empty():
		blocked_reason = "请选择至少一支可用编队"
	elif selected.is_empty() or selected.size() != selected_formation_ids.size():
		blocked_reason = "所选编队已变化，请重新选择"
	elif selected.size() > CommittedForceSnapshot.MAX_SQUADS:
		blocked_reason = "一次最多选择三支编队"
	elif selected_total > get_effective_command_limit():
		blocked_reason = "所选兵力超过当前指挥上限"
	elif food < food_cost:
		blocked_reason = "粮食不足：需要 %d，当前 %d" % [food_cost, food]
	var pressure := get_mainline_pressure_state()
	return {
		"mainline_name": "北坡防御战",
		"mainline_id": _current_mainline_level.level_id,
		"objective": "突破任一路线的城防并击溃该路守军",
		"deadline_text": (
			"已逾期 %d 日" % int(pressure.overdue_days)
			if int(pressure.overdue_days) > 0
			else "%d 日" % int(pressure.days_remaining)
		),
		"food": food,
		"maintenance_units_per_food": INFANTRY_ROLE.maintenance_units_per_food,
		"formations": _garrison_state.get_formations(),
		"selected_formation_ids": selected_formation_ids.duplicate(),
		"selected_formation_count": selected.size(),
		"selected_total": selected_total,
		"food_cost": food_cost,
		"food_after": food - food_cost,
		"blocked_reason": blocked_reason,
		"can_confirm": blocked_reason.is_empty(),
	}


func open_expedition_preparation() -> bool:
	if not can_enter_first_war():
		_show_placement_feedback(get_first_war_entry_blocked_reason())
		return false
	cancel_build_interaction()
	expedition_preparation_panel.open_with_model(
		get_expedition_preparation_model()
	)
	return true


func close_expedition_preparation() -> void:
	if expedition_preparation_panel.visible:
		expedition_preparation_panel.close_panel()
		current_mainline_entry_button.grab_focus()


func _on_expedition_selection_changed(formation_ids: Array[StringName]) -> void:
	expedition_preparation_panel.update_model(
		get_expedition_preparation_model(formation_ids)
	)


func _on_expedition_confirm_requested(formation_ids: Array[StringName]) -> void:
	var result := commit_expedition_attempt(formation_ids)
	if not bool(result.get("success", false)):
		expedition_preparation_panel.update_model(
			get_expedition_preparation_model(formation_ids)
		)
		expedition_preparation_panel.show_error(
			str(result.get("error", "出征确认失败"))
		)
		return
	if not _launch_active_expedition_battle():
		expedition_preparation_panel.show_error("战场无法加载；出征状态已安全保存")
		return
	expedition_preparation_panel.close_panel()


func commit_expedition_attempt(formation_ids: Array) -> Dictionary:
	if _expedition_commit_in_progress or _expedition_commit_blocked:
		return _expedition_failure(&"EXPEDITION_COMMIT_BUSY", "出征事务正在处理")
	var model := get_expedition_preparation_model(formation_ids)
	if not bool(model.can_confirm):
		return _expedition_failure(&"EXPEDITION_VALIDATION", str(model.blocked_reason))
	var selected := _garrison_state.get_selected_formations(formation_ids)
	if selected.is_empty() or not _garrison_state.selection_matches(selected):
		return _expedition_failure(&"FORMATION_CHANGED", "编队人数已变化，请重新选择")
	var attempt_id := StringName(
		"battle-%06d" % _next_battle_transaction_sequence
	)
	var departures: Array[Dictionary] = []
	for index in range(selected.size()):
		var formation: Dictionary = selected[index].duplicate(true)
		formation.squad_id = index + 1
		# The existing normal twenty-person winning plan is a concentrated front
		# deployment. It becomes part of the immutable attempt; a future route
		# picker must run before confirmation rather than mutate it inside C0.
		formation.route_id = CommittedForceSnapshot.FRONT_ROUTE
		departures.append(formation)
	var committed := CommittedForceSnapshot.create_from_formations(
		attempt_id,
		departures,
		INFANTRY_ROLE,
		selected_general_id,
		researched_tech_ids.duplicate(),
		get_infantry_attack_multiplier(),
		get_infantry_defense_multiplier(),
		supply_shortage
	)
	var enemy := EnemyForceSnapshot.create(
		attempt_id,
		current_day,
		enemy_count,
		enemy_fortification
	)
	if committed == null or enemy == null:
		return _expedition_failure(&"SNAPSHOT_BUILD_FAILED", "无法建立战斗快照")
	var candidate := {
		"attempt_id": attempt_id,
		"mainline_id": FIRST_WAR_LEVEL_ID,
		"phase": BATTLE_PHASE_RESERVED,
		"created_day": current_day,
		"created_day_elapsed_milliseconds": get_day_elapsed_milliseconds(),
		"food_cost": int(model.food_cost),
		"food_before": food,
		"food_after": food - int(model.food_cost),
		"committed_total": int(model.selected_total),
		"selected_formations": departures.duplicate(true),
		"committed_force_snapshot": committed.to_dictionary(),
		"enemy_force_snapshot": enemy.to_dictionary(),
		"city_defense_snapshot": get_city_defense(),
		"first_clear_key": BattleSession.FIRST_CLEAR_KEY,
		"reward_wood": 30,
		"reward_food": 20,
		"settled": false,
		"result_id": &"",
		"wartime_facility_plan": WartimeFacilityPlan.empty_snapshot(),
		"battle_session_snapshot": {},
		"terminal_result_snapshot": {},
		"source_id": &"FIRST_WAR",
		"mission_id": &"",
		"source_patrol_id": &"",
		"source_force_name": "",
		"source_point_id": &"",
		"source_route_name": "",
	}
	var prior_attempt := _expedition_attempt.duplicate(true)
	var prior_reservation := _active_battle_reservation.duplicate(true)
	var prior_sequence := _next_battle_transaction_sequence
	_expedition_commit_in_progress = true
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{
			"resource_id": &"food",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": int(candidate.food_cost),
		}],
		&"expedition_departure",
		Callable(self, "_install_expedition_attempt").bind(candidate)
	)
	if not bool(transaction.get("success", false)):
		_expedition_commit_in_progress = false
		return _expedition_failure(
			StringName(transaction.get("error_id", &"RESOURCE_TRANSACTION")),
			str(transaction.get("error", "粮草事务失败"))
		)
	_refresh_city_ui()
	city_state_changed.emit()
	var persisted := _persist_expedition_departure(attempt_id)
	if not bool(persisted.get("success", false)):
		if bool(persisted.get("uncertain", false)):
			_expedition_commit_blocked = true
			_expedition_commit_in_progress = false
			return _expedition_failure(
				&"SAVE_OUTCOME_UNCERTAIN",
				"存档发布结果无法确认；为防止重复扣粮，请冷启动恢复"
			)
		_rollback_expedition_departure(
			int(candidate.food_cost),
			prior_attempt,
			prior_reservation,
			prior_sequence
		)
		_expedition_commit_in_progress = false
		return _expedition_failure(&"SAVE_FAILED", "出征存档失败，粮草与编队未改变")
	_expedition_commit_in_progress = false
	return {
		"success": true,
		"error_id": &"",
		"error": "",
		"attempt": _expedition_attempt.duplicate(true),
	}


## A city-defense attempt uses the same durable formation and V5 checkpoint
## owners as a normal departure, but it has no departure-food transaction and
## never mutates the mainline assault's pressure state.
func begin_wartime_defense_attempt(formation_ids: Array) -> Dictionary:
	if _expedition_commit_in_progress or _expedition_commit_blocked:
		return _expedition_failure(&"DEFENSE_COMMIT_BUSY", "战时守城事务正在处理")
	if (
		WARTIME_DEFENSE_MISSION == null
		or not WARTIME_DEFENSE_MISSION.is_valid()
		or WARTIME_DEFENSE_MISSION.source != MissionDefinition.SOURCE_WARTIME_DEFENSE
		or not _expedition_attempt.is_empty()
		or not _active_battle_reservation.is_empty()
		or is_instance_valid(_formal_battle_scene)
	):
		return _expedition_failure(&"DEFENSE_STATE", "当前不能建立黑石守城实例")
	var selected := _garrison_state.get_selected_formations(formation_ids)
	if (
		selected.is_empty()
		or selected.size() != formation_ids.size()
		or selected.size() > CommittedForceSnapshot.MAX_SQUADS
		or not _garrison_state.selection_matches(selected)
	):
		return _expedition_failure(&"DEFENSE_FORMATIONS", "守城编队已变化，请重新选择")
	var selected_total := 0
	for formation in selected:
		selected_total += int(formation.member_count)
	if selected_total <= 0 or selected_total > get_effective_command_limit():
		return _expedition_failure(&"DEFENSE_FORMATIONS", "守城兵力不符合当前指挥限制")
	var attempt_id := StringName("defense-%06d" % _next_battle_transaction_sequence)
	var formations: Array[Dictionary] = []
	for index in range(selected.size()):
		var formation: Dictionary = Dictionary(selected[index]).duplicate(true)
		formation.squad_id = index + 1
		formation.route_id = (
			WARTIME_DEFENSE_MISSION.player_route_pattern[index]
			if index < WARTIME_DEFENSE_MISSION.player_route_pattern.size()
			else CommittedForceSnapshot.FRONT_ROUTE
		)
		formations.append(formation)
	var committed := CommittedForceSnapshot.create_from_formations(
		attempt_id, formations, INFANTRY_ROLE, selected_general_id,
		researched_tech_ids.duplicate(), get_infantry_attack_multiplier(),
		get_infantry_defense_multiplier(), supply_shortage
	)
	_ensure_war_loop_initialized()
	var invasion := _war_loop_state.field_tactics.get_blackstone_invasion()
	var uses_field_invasion := StringName(invasion.get("phase", &"")) == FieldTacticsState.INVASION_ARRIVED
	var enemy := (
		EnemyForceSnapshot.create_for_mission_count(
			attempt_id, current_day, WARTIME_DEFENSE_MISSION,
			int(invasion.get("strength", 0))
		)
		if uses_field_invasion
		else EnemyForceSnapshot.create_for_mission(
			attempt_id, current_day, WARTIME_DEFENSE_MISSION
		)
	)
	if committed == null or enemy == null:
		return _expedition_failure(&"DEFENSE_SNAPSHOT", "无法建立守城战斗快照")
	var candidate := {
		"attempt_id": attempt_id,
		"mainline_id": WARTIME_DEFENSE_MISSION.mission_id,
		"phase": BATTLE_PHASE_RESERVED,
		"created_day": current_day,
		"created_day_elapsed_milliseconds": get_day_elapsed_milliseconds(),
		"food_cost": 0,
		"food_before": food,
		"food_after": food,
		"committed_total": selected_total,
		"selected_formations": formations.duplicate(true),
		"committed_force_snapshot": committed.to_dictionary(),
		"enemy_force_snapshot": enemy.to_dictionary(),
		"city_defense_snapshot": get_city_defense(),
		"first_clear_key": WARTIME_DEFENSE_MISSION.first_clear_key,
		"reward_wood": 0,
		"reward_food": 0,
		"settled": false,
		"result_id": &"",
		"wartime_facility_plan": WartimeFacilityPlan.empty_snapshot(),
		"battle_session_snapshot": {},
		"terminal_result_snapshot": {},
		"source_id": BattleRequest.SOURCE_WARTIME_DEFENSE,
		"mission_id": WARTIME_DEFENSE_MISSION.mission_id,
		"source_patrol_id": StringName(invasion.get("patrol_id", &"")) if uses_field_invasion else &"",
		"source_force_name": str(invasion.get("display_name", "")) if uses_field_invasion else "",
		"source_point_id": StringName(invasion.get("source_point_id", &"")) if uses_field_invasion else &"",
		"source_route_name": str(invasion.get("known_route_name", "")) if uses_field_invasion else "",
	}
	var prior_attempt := _expedition_attempt.duplicate(true)
	var prior_reservation := _active_battle_reservation.duplicate(true)
	var prior_sequence := _next_battle_transaction_sequence
	var prior_field_snapshot := _war_loop_state.field_tactics.get_snapshot()
	_expedition_attempt = candidate.duplicate(true)
	_active_battle_reservation = {
		"transaction_id": attempt_id,
		"committed_count": selected_total,
		"phase": BATTLE_PHASE_RESERVED,
	}
	_next_battle_transaction_sequence += 1
	if uses_field_invasion and not _war_loop_state.field_tactics.mark_invasion_handed_off(
		StringName(invasion.get("patrol_id", &"")), attempt_id
	):
		_expedition_attempt = prior_attempt
		_active_battle_reservation = prior_reservation
		_next_battle_transaction_sequence = prior_sequence
		return _expedition_failure(&"DEFENSE_HANDOFF", "来袭敌军已变化，请返回战区确认")
	_refresh_city_ui()
	city_state_changed.emit()
	var persisted := _persist_expedition_departure(attempt_id)
	if not bool(persisted.get("success", false)):
		_expedition_attempt = prior_attempt
		_active_battle_reservation = prior_reservation
		_next_battle_transaction_sequence = prior_sequence
		_war_loop_state.field_tactics.restore_snapshot(prior_field_snapshot)
		_refresh_city_ui()
		city_state_changed.emit()
		return _expedition_failure(&"SAVE_FAILED", "守城实例保存失败，编队与资源未改变")
	return {"success": true, "attempt": _expedition_attempt.duplicate(true)}


func enter_wartime_defense_battle(formation_ids: Array = []) -> bool:
	if _expedition_attempt.is_empty():
		_ensure_war_loop_initialized()
		var invasion := _war_loop_state.field_tactics.get_blackstone_invasion()
		if not invasion.is_empty() and StringName(invasion.get("phase", &"")) != FieldTacticsState.INVASION_ARRIVED:
			_show_placement_feedback("敌军尚未抵达黑石城；请在战区侦察、截击或继续准备")
			return false
		var selected_ids := formation_ids.duplicate()
		if selected_ids.is_empty():
			for formation in _garrison_state.get_formations():
				if int(formation.member_count) > 0:
					selected_ids.append(StringName(formation.formation_id))
		var committed := begin_wartime_defense_attempt(selected_ids)
		if not bool(committed.get("success", false)):
			return false
	if StringName(_expedition_attempt.get("source_id", &"")) != BattleRequest.SOURCE_WARTIME_DEFENSE:
		return false
	return _launch_active_expedition_battle()


## Defense deployment is part of the same frozen battle request, but it is
## intentionally editable only before this source is activated.  The update
## changes no roster or resource fact and is durably published before C0 can
## continue, so a resumed battle cannot silently use a different route.
func update_wartime_defense_deployment(
	attempt_id: StringName,
	squad_id: int,
	route_id: StringName
) -> Dictionary:
	if _expedition_commit_in_progress or _expedition_commit_blocked:
		return _expedition_failure(&"DEFENSE_DEPLOYMENT_BUSY", "战时守城部署正在处理")
	if (
		attempt_id == &""
		or squad_id <= 0
		or route_id not in [
			CommittedForceSnapshot.FRONT_ROUTE,
			CommittedForceSnapshot.SIDE_ROUTE,
		]
		or _expedition_attempt.is_empty()
		or StringName(_expedition_attempt.get("attempt_id", &"")) != attempt_id
		or StringName(_expedition_attempt.get("source_id", &""))
			!= BattleRequest.SOURCE_WARTIME_DEFENSE
		or StringName(_expedition_attempt.get("phase", &"")) != BATTLE_PHASE_RESERVED
	):
		return _expedition_failure(&"DEFENSE_DEPLOYMENT_STATE", "当前守城实例不能调整部署")
	var candidate := _expedition_attempt.duplicate(true)
	var selected_formations: Array = Array(candidate.get("selected_formations", []))
	var selected_index := -1
	for index in range(selected_formations.size()):
		var formation_value: Variant = selected_formations[index]
		if formation_value is Dictionary and int(Dictionary(formation_value).get("squad_id", 0)) == squad_id:
			selected_index = index
			break
	if selected_index < 0:
		return _expedition_failure(&"DEFENSE_DEPLOYMENT_SQUAD", "指定守城编队不存在")
	var committed := CommittedForceSnapshot.from_dictionary(
		Dictionary(candidate.get("committed_force_snapshot", {}))
	)
	if committed == null or committed.transaction_id != attempt_id:
		return _expedition_failure(&"DEFENSE_DEPLOYMENT_SNAPSHOT", "守城冻结编队快照非法")
	var committed_index := -1
	for index in range(committed.squads.size()):
		if int(Dictionary(committed.squads[index]).get("squad_id", 0)) == squad_id:
			committed_index = index
			break
	if committed_index < 0:
		return _expedition_failure(&"DEFENSE_DEPLOYMENT_SQUAD", "守城冻结编队不完整")
	var selected_formation: Dictionary = Dictionary(selected_formations[selected_index]).duplicate(true)
	selected_formation.route_id = route_id
	selected_formations[selected_index] = selected_formation
	var committed_squad: Dictionary = Dictionary(committed.squads[committed_index]).duplicate(true)
	committed_squad.route_id = route_id
	committed.squads[committed_index] = committed_squad
	candidate.selected_formations = selected_formations
	candidate.committed_force_snapshot = committed.to_dictionary()
	if get_durable_battle_request(candidate) == null:
		return _expedition_failure(&"DEFENSE_DEPLOYMENT_SNAPSHOT", "守城部署无法重建战斗请求")
	var prior_attempt := _expedition_attempt.duplicate(true)
	_expedition_attempt = candidate
	_refresh_city_ui()
	city_state_changed.emit()
	var persisted := _persist_expedition_departure(attempt_id)
	if bool(persisted.get("success", false)):
		return {
			"success": true,
			"committed_force_snapshot": committed.to_dictionary(),
		}
	_expedition_attempt = prior_attempt
	_refresh_city_ui()
	city_state_changed.emit()
	if bool(persisted.get("uncertain", false)):
		_expedition_commit_blocked = true
		return _expedition_failure(&"SAVE_OUTCOME_UNCERTAIN", "守城部署存档结果无法确认；请冷启动恢复")
	return _expedition_failure(&"SAVE_FAILED", "守城部署保存失败，已保留原部署")


func _install_expedition_attempt(candidate: Dictionary) -> Dictionary:
	if (
		candidate.is_empty()
		or not _active_battle_reservation.is_empty()
		or StringName(candidate.attempt_id)
			!= StringName("battle-%06d" % _next_battle_transaction_sequence)
	):
		return {"success": false}
	_expedition_attempt = candidate.duplicate(true)
	_active_battle_reservation = {
		"transaction_id": StringName(candidate.attempt_id),
		"committed_count": int(candidate.committed_total),
		"phase": BATTLE_PHASE_RESERVED,
	}
	_next_battle_transaction_sequence += 1
	return {"success": true, "attempt_id": StringName(candidate.attempt_id)}


## A battle-only facility plan is paid through the city resource authority but
## remains attached to the single immutable expedition attempt.  It never
## creates a regular-city placement or field-construction project.
func commit_wartime_facility_plan(
	attempt_id: StringName,
	plan_snapshot: Dictionary
) -> Dictionary:
	if _expedition_commit_in_progress or _expedition_commit_blocked:
		return _expedition_failure(&"BATTLE_PLAN_BUSY", "战时布防事务正在处理")
	if (
		attempt_id == &""
		or _expedition_attempt.is_empty()
		or StringName(_expedition_attempt.get("attempt_id", &"")) != attempt_id
		or StringName(_expedition_attempt.get("phase", &"")) != BATTLE_PHASE_RESERVED
	):
		return _expedition_failure(&"BATTLE_PLAN_STATE", "当前出征不能修改战时布防")
	var plan_validation := WartimeFacilityPlan.validate_for_new_submission(
		plan_snapshot,
		StringName(_expedition_attempt.get("source_id", &"FIRST_WAR"))
	)
	if not bool(plan_validation.get("valid", false)):
		return _expedition_failure(&"BATTLE_PLAN_INVALID", str(plan_validation.get("error", "战时布防非法")))
	plan_validation = WartimeFacilityPlan.validate_for_committed_squads(
		Dictionary(plan_validation.get("snapshot", {})),
		Array(
			Dictionary(_expedition_attempt.get("committed_force_snapshot", {})).get("squads", [])
		)
	)
	if not bool(plan_validation.get("valid", false)):
		return _expedition_failure(&"BATTLE_PLAN_CREW", str(plan_validation.get("error", "施工分队非法")))
	var normalized_plan: Dictionary = Dictionary(plan_validation.snapshot).duplicate(true)
	if Array(normalized_plan.facilities).is_empty():
		return _expedition_failure(&"BATTLE_PLAN_EMPTY", "请至少选择一项战时工事")
	if not Dictionary(_expedition_attempt.get("wartime_facility_plan", {})).is_empty() and not Array(Dictionary(_expedition_attempt.get("wartime_facility_plan", {})).get("facilities", [])).is_empty():
		return _expedition_failure(&"BATTLE_PLAN_LOCKED", "战时布防已经确认，不能重复扣费")
	var costs := WartimeFacilityPlan.get_costs(normalized_plan)
	if costs.is_empty():
		return _expedition_failure(&"BATTLE_PLAN_COST", "战时工事费用无法计算")
	var operations: Array[Dictionary] = []
	for resource_id_value in costs.keys():
		operations.append({
			"resource_id": StringName(resource_id_value),
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": int(costs[resource_id_value]),
		})
	var prior_attempt := _expedition_attempt.duplicate(true)
	_expedition_commit_in_progress = true
	var install_plan := func() -> Dictionary:
		if (
			StringName(_expedition_attempt.get("attempt_id", &"")) != attempt_id
			or StringName(_expedition_attempt.get("phase", &"")) != BATTLE_PHASE_RESERVED
		):
			return {"success": false}
		_expedition_attempt.wartime_facility_plan = normalized_plan.duplicate(true)
		return {"success": true}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		operations,
		&"wartime_facility_preparation",
		install_plan
	)
	if not bool(transaction.get("success", false)):
		_expedition_commit_in_progress = false
		return _expedition_failure(
			StringName(transaction.get("error_id", &"BATTLE_PLAN_RESOURCE")),
			str(transaction.get("error", "战时工事资源不足"))
		)
	_refresh_city_ui()
	city_state_changed.emit()
	var persisted := _persist_expedition_departure(attempt_id)
	if bool(persisted.get("success", false)):
		_expedition_commit_in_progress = false
		return {"success": true, "plan": normalized_plan.duplicate(true)}
	if bool(persisted.get("uncertain", false)):
		_expedition_commit_blocked = true
		_expedition_commit_in_progress = false
		return _expedition_failure(&"SAVE_OUTCOME_UNCERTAIN", "战时布防存档结果无法确认；请冷启动恢复")
	var refund_operations: Array[Dictionary] = []
	for resource_id_value in costs.keys():
		refund_operations.append({
			"resource_id": StringName(resource_id_value),
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": int(costs[resource_id_value]),
		})
	var rollback := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		refund_operations,
		&"wartime_facility_preparation_rollback",
		func() -> Dictionary:
			_expedition_attempt = prior_attempt.duplicate(true)
			return {"success": true}
	)
	if not bool(rollback.get("success", false)):
		_expedition_commit_blocked = true
		push_error("Wartime facility plan rollback failed")
	_refresh_city_ui()
	city_state_changed.emit()
	_expedition_commit_in_progress = false
	return _expedition_failure(&"SAVE_FAILED", "战时布防保存失败，资源与计划已回滚")


func checkpoint_active_battle_session(
	attempt_id: StringName,
	session_snapshot: Dictionary
) -> Dictionary:
	if (
		attempt_id == &""
		or _expedition_attempt.is_empty()
		or StringName(_expedition_attempt.get("attempt_id", &"")) != attempt_id
		or StringName(_expedition_attempt.get("phase", &"")) != BATTLE_PHASE_ACTIVE
	):
		return _expedition_failure(&"BATTLE_SESSION_STATE", "当前没有可保存的活动战时实例")
	var request := get_durable_battle_request()
	var session_probe := BattleSession.new(request)
	if request == null or not session_probe.restore_snapshot(session_snapshot):
		return _expedition_failure(&"BATTLE_SESSION_INVALID", "战时实例快照非法")
	var prior_snapshot: Dictionary = Dictionary(
		_expedition_attempt.get("battle_session_snapshot", {})
	).duplicate(true)
	var prior_terminal_result: Dictionary = Dictionary(
		_expedition_attempt.get("terminal_result_snapshot", {})
	).duplicate(true)
	_expedition_attempt.battle_session_snapshot = session_snapshot.duplicate(true)
	_expedition_attempt.terminal_result_snapshot = {}
	var checkpoint_faulted := _wartime_session_checkpoint_fault_for_test == &"CHECKPOINT_SAVE_FAILED"
	_wartime_session_checkpoint_fault_for_test = (
		&"" if checkpoint_faulted else _wartime_session_checkpoint_fault_for_test
	)
	var persisted := (
		{"success": false}
		if checkpoint_faulted
		else _persist_active_battle_checkpoint(attempt_id)
	)
	if bool(persisted.get("success", false)):
		return {"success": true}
	_expedition_attempt.battle_session_snapshot = prior_snapshot
	_expedition_attempt.terminal_result_snapshot = prior_terminal_result
	if bool(persisted.get("uncertain", false)):
		_expedition_commit_blocked = true
		return _expedition_failure(&"SAVE_OUTCOME_UNCERTAIN", "战时实例存档结果无法确认；请冷启动恢复")
	return _expedition_failure(&"SAVE_FAILED", "战时实例检查点保存失败，已保留上一次检查点")


func clear_active_battle_session_checkpoint(attempt_id: StringName) -> bool:
	if (
		attempt_id == &""
		or _expedition_attempt.is_empty()
		or StringName(_expedition_attempt.get("attempt_id", &"")) != attempt_id
		or StringName(_expedition_attempt.get("phase", &"")) != BATTLE_PHASE_ACTIVE
	):
		return false
	_expedition_attempt.battle_session_snapshot = {}
	_expedition_attempt.terminal_result_snapshot = {}
	return true


func _persist_expedition_departure(attempt_id: StringName) -> Dictionary:
	var root := get_parent()
	if root != null and root.has_method("persist_expedition_departure"):
		return root.persist_expedition_departure(attempt_id)
	if DisplayServer.get_name() == "headless":
		return {"success": true, "headless_test_store_disabled": true}
	return {"success": false, "uncertain": false}


func _persist_active_battle_checkpoint(attempt_id: StringName) -> Dictionary:
	var root := get_parent()
	if root != null and root.has_method("persist_expedition_battle_checkpoint"):
		return root.persist_expedition_battle_checkpoint(attempt_id)
	if DisplayServer.get_name() == "headless":
		return {"success": true, "headless_test_store_disabled": true}
	return {"success": false, "uncertain": false}


func _rollback_expedition_departure(
	food_cost: int,
	prior_attempt: Dictionary,
	prior_reservation: Dictionary,
	prior_sequence: int
) -> void:
	var rollback_local := func() -> Dictionary:
		_expedition_attempt = prior_attempt.duplicate(true)
		_active_battle_reservation = prior_reservation.duplicate(true)
		_next_battle_transaction_sequence = prior_sequence
		return {"success": true}
	var rollback := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{
			"resource_id": &"food",
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": food_cost,
		}],
		&"expedition_departure_rollback",
		rollback_local
	)
	if not bool(rollback.get("success", false)):
		_expedition_commit_blocked = true
		push_error("R1E expedition rollback failed")
	_refresh_city_ui()
	city_state_changed.emit()


func _expedition_failure(error_id: StringName, error: String) -> Dictionary:
	return {"success": false, "error_id": error_id, "error": error}


func enter_first_war_battle() -> bool:
	if (
		_expedition_attempt.is_empty()
		or StringName(_expedition_attempt.get("phase", &"")) not in [
			BATTLE_PHASE_RESERVED,
			BATTLE_PHASE_ACTIVE,
			BATTLE_PHASE_RESULT_PENDING,
		]
	):
		var available_ids: Array[StringName] = []
		for formation in _garrison_state.get_formations():
			if int(formation.member_count) > 0:
				available_ids.append(StringName(formation.formation_id))
		var committed := commit_expedition_attempt(available_ids)
		if not bool(committed.get("success", false)):
			return false
	return _launch_active_expedition_battle()


func _launch_active_expedition_battle() -> bool:
	if (
		_expedition_attempt.is_empty()
		or StringName(_expedition_attempt.phase) not in [
			BATTLE_PHASE_RESERVED,
			BATTLE_PHASE_ACTIVE,
			BATTLE_PHASE_RESULT_PENDING,
		]
		or is_instance_valid(_formal_battle_scene)
	):
		return false
	var request := get_durable_battle_request()
	if request == null:
		return false
	var battle_scene := load(
		"res://scenes/c0_battle_graybox.tscn"
	) as PackedScene
	if battle_scene == null:
		return false
	var battle := battle_scene.instantiate() as C0BattleGraybox
	if battle == null:
		return false
	battle.configure_formal_expedition(
		get_parent() as Node2D,
		self,
		request
	)
	if request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE:
		battle.formal_return_completed.connect(_on_wartime_defense_returned)
	else:
		battle.formal_return_completed.connect(_on_first_war_returned)
	battle.formal_entry_cancelled.connect(_on_first_war_entry_cancelled)
	var previous_first_war_state := first_war_state
	if request.source_id != BattleRequest.SOURCE_WARTIME_DEFENSE:
		first_war_state = FirstWarState.IN_BATTLE
	_formal_battle_scene = battle
	get_tree().root.add_child(battle)
	if battle.request == null:
		_formal_battle_scene = null
		first_war_state = previous_first_war_state
		battle.abort_formal_entry()
		_refresh_city_ui()
		return false
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _on_campaign_status_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_current_mainline_entry_pressed()
		alert_summary.accept_event()


func _on_current_mainline_entry_pressed() -> void:
	if has_resumable_expedition():
		resume_persisted_expedition()
		return
	if uses_blackstone_campaign():
		if get_parent().open_macro_march_r0():
			var invasion := get_blackstone_invasion_read_model()
			var point_id := StringName(invasion.get("source_point_id", &"blackstone_city"))
			get_parent().get_node("UI/MacroMarchR0").focus_campaign_location(point_id)
		return
	if not open_expedition_preparation():
		_show_placement_feedback(get_first_war_entry_blocked_reason())


func get_formal_battle_scene() -> C0BattleGraybox:
	return _formal_battle_scene if is_instance_valid(_formal_battle_scene) else null


func enter_macro_siege_wartime(army_id: StringName, city_id: StringName) -> bool:
	_ensure_war_loop_initialized()
	if is_instance_valid(_formal_battle_scene) or army_id == &"" or city_id == &"":
		return false
	var army := _army_registry.get_army(army_id)
	var siege := _war_loop_state.get_siege(city_id)
	if (
		army.is_empty()
		or siege.is_empty()
		or StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_SIEGING
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(siege.get("phase", &"")) != WarLoopState.PHASE_SIEGING
	):
		return false
	var battle_scene := load("res://scenes/c0_battle_graybox.tscn") as PackedScene
	if battle_scene == null:
		return false
	var battle := battle_scene.instantiate() as C0BattleGraybox
	if battle == null:
		return false
	battle.configure_macro_siege(get_parent() as Node2D, self, army_id, city_id)
	battle.formal_return_completed.connect(_on_macro_siege_wartime_returned)
	battle.formal_entry_cancelled.connect(_on_macro_siege_wartime_entry_cancelled)
	_formal_battle_scene = battle
	get_tree().root.add_child(battle)
	if battle.request == null:
		_formal_battle_scene = null
		battle.abort_formal_entry()
		return false
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_macro_siege_battle_session_snapshot(
	city_id: StringName,
	transaction_id: StringName
) -> Dictionary:
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if StringName(handoff.get("transaction_id", &"")) != transaction_id:
		return {}
	return Dictionary(handoff.get("battle_session_snapshot", {})).duplicate(true)


func get_macro_siege_battle_result_authority_snapshot(
	city_id: StringName,
	transaction_id: StringName
) -> Dictionary:
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if StringName(handoff.get("transaction_id", &"")) != transaction_id:
		return {}
	return Dictionary(handoff.get("result_authority_snapshot", {})).duplicate(true)


## Source-aware C0 copy reads the existing army, siege and theatre owners. It
## does not persist a second battle identity or turn field construction into a
## battle facility.
func get_macro_siege_player_context(
	army_id: StringName,
	city_id: StringName,
	transaction_id: StringName
) -> Dictionary:
	var army := _army_registry.get_army(army_id)
	var siege := _war_loop_state.get_siege(city_id)
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if (
		army.is_empty()
		or siege.is_empty()
		or transaction_id == &""
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
	):
		return {}
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var target := MACRO_MARCH_THEATER.get_point(city_id)
	var route_id := StringName(macro.get("route_id", &""))
	var route := MACRO_MARCH_THEATER.get_route(route_id)
	var source_id := StringName(macro.get("source_point_id", &""))
	var source := MACRO_MARCH_THEATER.get_point(source_id)
	return {
		"army_id": army_id,
		"order_id": StringName(macro.get("order_id", &"")),
		"target_city_id": city_id,
		"target_city_name": str(target.get("display_name", city_id)),
		"approach_route_id": route_id,
		"approach_route_name": str(route.get("display_name", route_id)),
		"source_point_id": source_id,
		"source_point_name": str(source.get("display_name", source_id)),
		"departure_food_cost": int(macro.get("food_cost", 0)),
	}


func _on_macro_siege_wartime_returned(_summary: Dictionary) -> void:
	_formal_battle_scene = null
	_refresh_city_ui()
	city_state_changed.emit()


func _on_macro_siege_wartime_entry_cancelled() -> void:
	_formal_battle_scene = null
	_refresh_city_ui()
	city_state_changed.emit()


func get_noticeboard_mission_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for mission in NOTICEBOARD_MISSIONS:
		result.append(mission.mission_id)
	return result


func get_noticeboard_mission_definition(
	mission_id: StringName
) -> MissionDefinition:
	return _mission_definitions_by_id.get(mission_id) as MissionDefinition


func get_noticeboard_mission_state(mission_id: StringName) -> StringName:
	if mission_id == _active_noticeboard_mission_id:
		return &"IN_PROGRESS"
	if _completed_noticeboard_mission_ids.has(mission_id):
		return &"COMPLETED"
	if _mission_definitions_by_id.has(mission_id):
		return &"AVAILABLE"
	return &"LOCKED"


func get_active_noticeboard_mission_id() -> StringName:
	return _active_noticeboard_mission_id


func show_noticeboard_panel() -> void:
	noticeboard_panel.visible = true
	_refresh_noticeboard_ui()
	set_detail_panel_active(true)


func hide_noticeboard_panel() -> void:
	noticeboard_panel.visible = false
	set_detail_panel_active(false)


func can_start_noticeboard_mission(mission_id: StringName) -> bool:
	var mission := get_noticeboard_mission_definition(mission_id)
	return (
		mission != null
		and not uses_blackstone_campaign()
		and mission.is_valid()
		and _active_noticeboard_mission_id == &""
		and not is_city_action_locked_for_battle()
		and not is_instance_valid(_formal_battle_scene)
		and mini(
			mission.committed_count,
			get_effective_command_limit()
		) <= get_available_infantry_count()
	)


func start_noticeboard_mission(mission_id: StringName) -> bool:
	if not can_start_noticeboard_mission(mission_id):
		return false
	var mission := get_noticeboard_mission_definition(mission_id)
	var battle_scene := load(
		"res://scenes/c0_battle_graybox.tscn"
	) as PackedScene
	if battle_scene == null:
		return false
	var battle := battle_scene.instantiate() as C0BattleGraybox
	if battle == null:
		return false
	battle.configure_noticeboard_mission(
		get_parent() as Node2D,
		self,
		mission
	)
	battle.noticeboard_return_completed.connect(
		_on_noticeboard_mission_returned
	)
	battle.noticeboard_entry_cancelled.connect(
		_on_noticeboard_mission_entry_cancelled
	)
	_active_noticeboard_mission_id = mission_id
	_formal_battle_scene = battle
	get_tree().root.add_child(battle)
	if battle.request == null:
		_formal_battle_scene = null
		_active_noticeboard_mission_id = &""
		battle.abort_formal_entry()
		_refresh_noticeboard_ui()
		return false
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _on_noticeboard_mission_returned(
	mission_id: StringName,
	summary: Dictionary
) -> void:
	_formal_battle_scene = null
	if mission_id != _active_noticeboard_mission_id or summary.is_empty():
		return
	_active_noticeboard_mission_id = &""
	_noticeboard_last_result_summary = summary.duplicate(true)
	noticeboard_panel.visible = true
	_refresh_noticeboard_ui()
	_refresh_city_ui()
	city_state_changed.emit()


func _on_noticeboard_mission_entry_cancelled(
	mission_id: StringName
) -> void:
	_formal_battle_scene = null
	if mission_id == _active_noticeboard_mission_id:
		_active_noticeboard_mission_id = &""
	noticeboard_panel.visible = true
	_refresh_noticeboard_ui()
	_refresh_city_ui()
	city_state_changed.emit()


func request_first_war_retreat_confirmation() -> bool:
	if first_war_state != FirstWarState.PENDING:
		return false
	retreat_confirmation.visible = true
	_refresh_first_war_ui()
	return true


func cancel_first_war_retreat_confirmation() -> void:
	retreat_confirmation.visible = false
	_refresh_first_war_ui()


func confirm_first_war_retreat() -> bool:
	if (
		first_war_state != FirstWarState.PENDING
		or not retreat_confirmation.visible
		or get_first_war_committed_count() <= 0
	):
		return false
	retreat_confirmation.visible = false
	var coordinator := CombatTransactionCoordinator.new()
	add_child(coordinator)
	coordinator.configure(self)
	first_war_state = FirstWarState.IN_BATTLE
	var retreat_request := coordinator.create_request(
		get_first_war_committed_count(),
		FIRST_WAR_LEVEL_ID,
		true
	)
	if retreat_request == null:
		first_war_state = FirstWarState.PENDING
		coordinator.queue_free()
		_refresh_city_ui()
		return false
	if not coordinator.activate_request():
		coordinator.cancel_request()
		first_war_state = FirstWarState.PENDING
		coordinator.queue_free()
		_refresh_city_ui()
		return false
	if coordinator.create_session() == null:
		push_error(
			"First-war retreat session failed after reservation activation"
		)
		_refresh_city_ui()
		return false
	for squad in retreat_request.committed_force.squads:
		coordinator.issue_order(
			int(squad.squad_id),
			BattleOrder.Command.RETREAT
		)
	var battle_result: BattleResult
	for _tick in range(BattleSession.MAX_BATTLE_TICKS + 2):
		battle_result = coordinator.advance_battle_tick()
		if battle_result != null:
			break
	if battle_result == null:
		push_error("First-war retreat did not produce a battle result")
		_refresh_city_ui()
		return false
	var summary := coordinator.confirm_result()
	if summary.is_empty():
		push_error("First-war retreat result could not be applied")
		_refresh_city_ui()
		return false
	coordinator.queue_free()
	_on_first_war_returned(summary)
	return true


func acknowledge_first_war_result() -> bool:
	if _first_war_result_acknowledged or _first_war_pending_outcome == &"":
		return false
	if _first_war_pending_outcome == &"VICTORY":
		first_war_state = FirstWarState.RESOLVED_VICTORY
		_current_mainline_level.mark_cleared(current_day)
	elif _first_war_pending_outcome == &"RETREAT":
		first_war_state = FirstWarState.RESOLVED_RETREAT
	elif _first_war_pending_outcome == &"DEFEAT":
		first_war_state = FirstWarState.RESOLVED_DEFEAT
		city_fallen = true
	else:
		return false
	_first_war_result_acknowledged = true
	_first_war_pending_outcome = &""
	first_war_result.visible = false
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _on_first_war_returned(summary: Dictionary) -> void:
	if summary.is_empty():
		return
	_formal_battle_scene = null
	_first_war_result_acknowledged = false
	if _first_war_pending_outcome == &"DEFEAT":
		first_war_state = FirstWarState.RESOLVED_DEFEAT
		city_fallen = true
	else:
		first_war_state = FirstWarState.IN_BATTLE
	first_war_result.visible = true
	_refresh_city_ui()
	city_state_changed.emit()


## Gate defense is a durable battle source, not a disguised mainline assault.
## Returning from it preserves the ordinary first-war projection while the
## already-applied defense result remains available from the city state.
func _on_wartime_defense_returned(summary: Dictionary) -> void:
	if (
		summary.is_empty()
		or StringName(summary.get("source_id", &""))
			!= BattleRequest.SOURCE_WARTIME_DEFENSE
	):
		return
	_formal_battle_scene = null
	_refresh_city_ui()
	city_state_changed.emit()


func _on_first_war_entry_cancelled() -> void:
	_formal_battle_scene = null
	if (
		first_war_state == FirstWarState.IN_BATTLE
		and _active_battle_reservation.is_empty()
	):
		first_war_state = FirstWarState.PENDING
	_refresh_city_ui()
	city_state_changed.emit()


func get_day_progress_ratio() -> float:
	return clampf(day_elapsed_seconds / SECONDS_PER_DAY, 0.0, 1.0)


func _advance_day_boundary(
	allow_battle_settlement := false
) -> bool:
	if not allow_battle_settlement and is_city_action_locked_for_battle():
		return false
	if not _can_complete_training_for_day(current_day + 1):
		return false
	current_day += 1
	_current_mainline_level.advance_to_day(current_day)
	var construction_completed := _complete_construction_for_current_day()
	var maintenance_required := get_maintenance_food_cost()
	var maintenance_paid := mini(food, maintenance_required)
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
	var food_after_maintenance := food - maintenance_paid
	var accepted_wood := mini(wood_income, maxi(wood_capacity - wood, 0))
	var accepted_food := mini(
		food_income,
		maxi(food_capacity - food_after_maintenance, 0)
	)
	var day_entries: Array[Dictionary] = []
	if maintenance_paid > 0:
		day_entries.append({
			"resource_id": &"food",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": maintenance_paid,
		})
	if accepted_wood > 0:
		day_entries.append({
			"resource_id": &"wood",
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": accepted_wood,
		})
	if accepted_food > 0:
		day_entries.append({
			"resource_id": &"food",
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": accepted_food,
		})
	day_entries.append({
		"resource_id": &"tech_points",
		"operation": NationState.RESOURCE_OPERATION_ADD,
		"amount": 1,
	})
	if not _commit_national_resources(day_entries, &"day_end_settlement"):
		return false
	var governance_before := _city_governance.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var vulnerable_people := maxi(
		_population_recovery.available
		+ _population_recovery.production_workers
		+ _population_recovery.construction_workers
		+ _population_recovery.medical_workers
		+ _population_recovery.governance_workers,
		0
	)
	var shared_medical_capacity := mini(get_city_medical_capacity(), _population_recovery.medical_workers)
	var active_wound_reservation := 0
	if StringName(_population_recovery.treatment.phase) == PopulationRecoveryState.TREATMENT_ACTIVE:
		active_wound_reservation = int(_population_recovery.treatment.count)
	var remaining_medical_capacity := maxi(shared_medical_capacity - active_wound_reservation, 0)
	var refugee_recoveries := _city_governance.apply_refugee_medical_care(remaining_medical_capacity)
	remaining_medical_capacity -= refugee_recoveries
	var governance_result := _city_governance.apply_day(
		current_day,
		maxi(maintenance_required - maintenance_paid, 0),
		maxi(_population_recovery.total_living - get_city_housing_capacity(), 0),
		vulnerable_people,
		_population_recovery.resident_sick,
		remaining_medical_capacity,
		city_security,
		CITY_GOVERNANCE_RULES
	)
	if governance_result.is_empty():
		_city_governance.restore_snapshot(governance_before)
		_population_recovery.restore_snapshot(population_before)
		return false
	if int(governance_result.recovered) > 0 and not _population_recovery.recover_sickness(int(governance_result.recovered)):
		_city_governance.restore_snapshot(governance_before)
		_population_recovery.restore_snapshot(population_before)
		return false
	if int(governance_result.new_cases) > 0 and not _population_recovery.record_sickness(int(governance_result.new_cases)):
		_city_governance.restore_snapshot(governance_before)
		_population_recovery.restore_snapshot(population_before)
		return false
	var population_changes := _advance_city_demography(
		maintenance_required == maintenance_paid,
		get_city_housing_capacity() - _population_recovery.total_living
	)
	if not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		_city_governance.restore_snapshot(governance_before)
		_population_recovery.restore_snapshot(population_before)
		return false
	city_security = clampi(city_security + int(governance_result.security_delta), 0, 100)
	var governance_consequence := _apply_city_governance_event_consequence()
	last_daily_breakdown = {
		"maintenance_food": maintenance_paid,
		"maintenance_required": maintenance_required,
		"training_completed": training_completed,
		"construction_completed": construction_completed,
		"wood_income": accepted_wood,
		"food_income": accepted_food,
		"research_income": 1,
		"event_wood_loss": 0,
		"event_food_loss": int(governance_consequence.get("food_loss", 0)),
		"stopped_placement_id": -1,
		"new_disease_cases": int(governance_result.new_cases),
		"disease_recoveries": int(governance_result.recovered),
		"refugee_recoveries": refugee_recoveries,
		"births": int(population_changes.get("births", 0)),
		"matured": int(population_changes.get("matured", 0)),
		"aged": int(population_changes.get("aged", 0)),
		"civilian_deaths": int(population_changes.get("deaths", 0)),
		"refugee_arrivals": _count_refugees_arriving_on_day(current_day),
		"health_permille": _city_governance.health_permille,
	}
	_apply_mainline_pressure_for_current_day()
	_update_threat_for_current_day(true)
	_clear_expired_production_stops()
	if current_day == 9:
		_capture_readiness_checkpoint()
	_rebuild_daily_report()
	if accepted_wood < wood_income or accepted_food < food_income:
		last_daily_report += "（容量封顶）"
	if not allow_battle_settlement:
		_update_first_war_state_for_current_day()
	var strategy_before := _city_strategy.get_snapshot()
	if _city_strategy.expire_support_for_day(current_day) and not _persist_city_strategy_checkpoint():
		# Keep the durable record retryable. Effect queries also check the city
		# day, so a failed expiry save cannot extend the expired bonus.
		_city_strategy.restore_snapshot(strategy_before)
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _apply_mainline_pressure_for_current_day() -> void:
	if is_campaign_pressure_cleared():
		return
	var event := _current_mainline_level.build_pressure_event(
		current_day,
		city_security
	)
	if event.is_empty():
		return
	var requested_losses: Dictionary = event.losses
	var actual_losses := {
		"wood": mini(wood, int(requested_losses.get("wood", 0))),
		"food": mini(food, int(requested_losses.get("food", 0))),
		"city_defense_damage": int(
			requested_losses.get("city_defense_damage", 0)
		),
	}
	event.losses = actual_losses
	var entries: Array[Dictionary] = []
	for resource_id in [&"wood", &"food"]:
		var amount := int(actual_losses[resource_id])
		if amount > 0:
			entries.append({
				"resource_id": resource_id,
				"operation": NationState.RESOURCE_OPERATION_SPEND,
				"amount": amount,
			})
	var local_commit := func() -> Dictionary:
		if not _current_mainline_level.commit_pressure_event(event):
			return {"success": false}
		city_defense_damage += int(actual_losses.city_defense_damage)
		last_daily_breakdown.event_wood_loss += int(actual_losses.wood)
		last_daily_breakdown.event_food_loss += int(actual_losses.food)
		return {"success": true}
	if entries.is_empty():
		local_commit.call()
	else:
		_commit_national_resources(entries, &"mainline_pressure", local_commit)


func get_mainline_pressure_state() -> Dictionary:
	var next_stage := MAINLINE_PRESSURE_PROFILE.get_next_stage_summary(current_day)
	return {
		"level_id": _current_mainline_level.level_id,
		"deadline_day": _current_mainline_level.deadline_day,
		"days_remaining": maxi(
			_current_mainline_level.deadline_day - current_day,
			0
		),
		"overdue_days": maxi(
			current_day - _current_mainline_level.deadline_day,
			0
		),
		"stage_id": &"PRESSURE_0" if is_campaign_pressure_cleared() else _current_mainline_level.pressure_stage_id,
		"stage_name": "压力解除" if is_campaign_pressure_cleared() else MAINLINE_PRESSURE_PROFILE.get_stage_display_name(current_day),
		"cleared": is_campaign_pressure_cleared(),
		"security": city_security,
		"construction_modifier_permille": get_pressure_modifier_permille(&"construction"),
		"production_modifier_permille": get_pressure_modifier_permille(&"production"),
		"next_stage_name": str(next_stage.name),
		"next_stage_days": int(next_stage.days_until),
		"permanent_losses": _current_mainline_level.permanent_losses.duplicate(true),
	}


func set_city_security_for_test(value: int) -> void:
	city_security = clampi(value, 0, 100)
	_refresh_city_ui()


func _can_complete_training_for_day(boundary_day: int) -> bool:
	var order := _training_queue.get_due_order(boundary_day)
	if order.is_empty():
		return true
	var future_total := (
		_garrison_state.get_total_count() + int(order.quantity)
	)
	if _population_recovery.training_reserved < int(order.quantity):
		_last_training_failure_id = &"TRAINING_COMPLETION_POPULATION"
		return false
	if future_total > recruitment_cap:
		_last_training_failure_id = &"TRAINING_COMPLETION_CAPACITY"
		return false
	if future_total > get_effective_command_limit():
		_last_training_failure_id = &"TRAINING_COMPLETION_COMMAND_LIMIT"
		return false
	return true


func _complete_training_for_current_day() -> int:
	var order := _training_queue.get_due_order(current_day)
	if order.is_empty():
		return 0
	var quantity := int(order.quantity)
	var capacity := mini(recruitment_cap, get_effective_command_limit())
	var garrison_before := _garrison_state.get_persistence_snapshot()
	var queue_before := _training_queue.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	if not _garrison_state.try_add_units(
		StringName(order.unit_definition_id),
		quantity,
		capacity
	):
		_last_training_failure_id = &"TRAINING_COMPLETION_CAPACITY"
		return 0
	if (
		not _population_recovery.complete_training(quantity)
		or not _training_queue.mark_completed(
		StringName(order.order_id),
		current_day
		)
	):
		_garrison_state.restore_persistence_snapshot(garrison_before)
		_training_queue.restore_snapshot(queue_before)
		_population_recovery.restore_snapshot(population_before)
		_last_training_failure_id = &"TRAINING_COMPLETION_COMMIT"
		return 0
	_last_training_failure_id = &""
	return quantity


func _complete_construction_for_current_day() -> int:
	var completed := _construction_completed_since_last_day
	_construction_completed_since_last_day = 0
	return completed


func _advance_construction_between(
	start_elapsed_milliseconds: int,
	duration_milliseconds: int
) -> void:
	if duration_milliseconds <= 0:
		return
	var end_elapsed := start_elapsed_milliseconds + duration_milliseconds
	var tick_count := (
		floori(float(end_elapsed) / CONSTRUCTION_TICK_MILLISECONDS)
		- floori(float(start_elapsed_milliseconds) / CONSTRUCTION_TICK_MILLISECONDS)
	)
	for _tick in range(tick_count):
		_advance_construction_tick()


func _advance_construction_tick() -> void:
	_advance_build_slot_tick()
	var ordered_ids := _get_ordered_construction_ids()
	for placement_id in ordered_ids:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or StringName(record.lifecycle_state) != &"constructing":
			continue
		var required := int(record.construction_required_milliseconds)
		var progress := int(record.construction_progress_milliseconds)
		var modifier := floori(float(get_pressure_modifier_permille(&"construction") * get_workforce_modifier_permille(&"construction")) / 1000.0)
		if modifier <= 0:
			continue
		var progress_delta := maxi(
			roundi(float(CONSTRUCTION_TICK_MILLISECONDS * modifier) / 1000.0),
			1
		)
		var next_progress := mini(progress + progress_delta, required)
		var total_costs: Dictionary = record.construction_total_costs
		var paid_costs: Dictionary = record.construction_paid_costs
		var entries: Array[Dictionary] = []
		var next_paid := paid_costs.duplicate(true)
		var missing_ids: Array[StringName] = []
		for resource_id in total_costs:
			var target_paid := (
				int(total_costs[resource_id])
				if next_progress >= required
				else floori(
					float(int(total_costs[resource_id]) * next_progress)
					/ float(required)
				)
			)
			var amount := target_paid - int(paid_costs.get(resource_id, 0))
			if amount <= 0:
				continue
			if _nation_state.get_resource(StringName(resource_id)) < amount:
				missing_ids.append(StringName(resource_id))
				continue
			entries.append({
				"resource_id": StringName(resource_id),
				"operation": NationState.RESOURCE_OPERATION_SPEND,
				"amount": amount,
			})
			next_paid[resource_id] = target_paid
		if not missing_ids.is_empty():
			record.construction_state = &"BLOCKED_RESOURCES"
			record.construction_missing_resource_ids = missing_ids
			record.prototype_status = "缺料暂停"
			continue
		var local_commit := func() -> Dictionary:
			record.construction_progress_milliseconds = next_progress
			record.construction_paid_costs = next_paid.duplicate(true)
			record.construction_missing_resource_ids = []
			record.construction_state = &"ACTIVE"
			if next_progress >= required:
				record.lifecycle_state = &"running"
				record.construction_state = &"COMPLETED"
				record.prototype_status = "运行中"
				_construction_completed_since_last_day += 1
			return {"success": true}
		var committed := (
			bool(local_commit.call().success)
			if entries.is_empty()
			else _commit_national_resources(
				entries,
				&"construction_progress",
				local_commit
			)
		)
		if committed:
			_refresh_placed_building_visual(placement_id)


func _get_build_slot_next_payment() -> Dictionary:
	var progress := int(_build_slot.get("progress_milliseconds", 0))
	var required := int(_build_slot.get("required_milliseconds", 0))
	if required <= 0 or progress >= required:
		return {
			"next_progress": required,
			"entries": [],
			"next_paid": Dictionary(_build_slot.get("paid_costs", {})).duplicate(true),
			"missing_ids": [],
			"shortages": [],
		}
	var modifier := floori(float(get_pressure_modifier_permille(&"construction") * get_workforce_modifier_permille(&"construction")) / 1000.0)
	if modifier <= 0:
		return {
			"next_progress": progress,
			"entries": [],
			"next_paid": Dictionary(_build_slot.get("paid_costs", {})).duplicate(true),
			"missing_ids": [],
			"shortages": [],
		}
	var progress_delta := maxi(
		roundi(float(CONSTRUCTION_TICK_MILLISECONDS * modifier) / 1000.0),
		1
	)
	var next_progress := mini(progress + progress_delta, required)
	var total_costs: Dictionary = _build_slot.get("total_costs", {})
	var paid_costs: Dictionary = _build_slot.get("paid_costs", {})
	var entries: Array[Dictionary] = []
	var next_paid := paid_costs.duplicate(true)
	var missing_ids: Array[StringName] = []
	var shortages: Array[Dictionary] = []
	var resource_ids: Array[StringName] = []
	for raw_resource_id in total_costs:
		resource_ids.append(StringName(raw_resource_id))
	resource_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return [&"wood", &"food"].find(left) < [&"wood", &"food"].find(right)
	)
	for resource_id in resource_ids:
		var total := int(total_costs[resource_id])
		var target_paid := (
			total
			if next_progress >= required
			else ceili(float(total * next_progress) / float(required))
		)
		var amount := target_paid - int(paid_costs.get(resource_id, 0))
		if amount <= 0:
			continue
		var available := _nation_state.get_resource(resource_id)
		if available < amount:
			missing_ids.append(resource_id)
			shortages.append({
				"resource_id": resource_id,
				"display_name": _resource_display_name(resource_id),
				"missing": amount - available,
			})
			continue
		entries.append({
			"resource_id": resource_id,
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": amount,
		})
		next_paid[resource_id] = target_paid
	return {
		"next_progress": next_progress,
		"entries": entries,
		"next_paid": next_paid,
		"missing_ids": missing_ids,
		"shortages": shortages,
	}


func _update_build_slot_wait_state() -> void:
	if get_build_slot_state() not in [
		BUILD_SLOT_PRODUCING,
		BUILD_SLOT_WAITING_MATERIAL,
	]:
		return
	var payment := _get_build_slot_next_payment()
	_build_slot.missing_resource_ids = Array(payment.missing_ids).duplicate()
	_build_slot.state = (
		BUILD_SLOT_WAITING_MATERIAL
		if not Array(payment.missing_ids).is_empty()
		else BUILD_SLOT_PRODUCING
	)


func _advance_build_slot_tick() -> void:
	if get_build_slot_state() not in [
		BUILD_SLOT_PRODUCING,
		BUILD_SLOT_WAITING_MATERIAL,
	]:
		return
	var payment := _get_build_slot_next_payment()
	var missing_ids: Array = payment.missing_ids
	if not missing_ids.is_empty():
		_build_slot.state = BUILD_SLOT_WAITING_MATERIAL
		_build_slot.missing_resource_ids = missing_ids.duplicate()
		_sync_construction_ui()
		city_state_changed.emit()
		construction_presentation_changed.emit()
		return
	var next_progress := int(payment.next_progress)
	var required := int(_build_slot.required_milliseconds)
	var local_commit := func() -> Dictionary:
		_build_slot.progress_milliseconds = next_progress
		_build_slot.paid_costs = Dictionary(payment.next_paid).duplicate(true)
		_build_slot.missing_resource_ids = []
		if next_progress >= required:
			_build_slot.state = BUILD_SLOT_READY_TO_PLACE
			_build_slot.completion_notified = true
			_construction_completed_since_last_day += 1
		else:
			_build_slot.state = BUILD_SLOT_PRODUCING
		return {"success": true}
	var entries: Array[Dictionary] = []
	for entry in payment.entries:
		entries.append(Dictionary(entry).duplicate(true))
	var committed := (
		bool(local_commit.call().success)
		if entries.is_empty()
		else _commit_national_resources(
			entries,
			&"build_slot_progress",
			local_commit
		)
	)
	if not committed:
		_update_build_slot_wait_state()
		return
	_sync_construction_ui()
	_refresh_city_ui()
	city_state_changed.emit()
	construction_presentation_changed.emit()


func cancel_build_project() -> Dictionary:
	var before := get_build_slot_state()
	if before == BUILD_SLOT_IDLE:
		return _build_slot_result(false, &"NO_BUILD_PROJECT", before, before)
	if before == BUILD_SLOT_PLACEMENT_ACTIVE:
		return _build_slot_result(false, &"EXIT_PLACEMENT_FIRST", before, before)
	var paid_costs: Dictionary = _build_slot.get("paid_costs", {})
	var entries: Array[Dictionary] = []
	for resource_id in [&"wood", &"food"]:
		var amount := int(paid_costs.get(resource_id, 0))
		if amount > 0:
			entries.append({
				"resource_id": resource_id,
				"operation": NationState.RESOURCE_OPERATION_ADD,
				"amount": amount,
			})
	var local_commit := func() -> Dictionary:
		_build_slot = _empty_build_slot()
		return {"success": true}
	var refunded := (
		bool(local_commit.call().success)
		if entries.is_empty()
		else _commit_national_resources(entries, &"build_slot_refund", local_commit)
	)
	if not refunded:
		return _build_slot_result(false, &"REFUND_FAILED", before, before)
	_sync_construction_ui()
	_refresh_city_ui()
	city_state_changed.emit()
	construction_presentation_changed.emit()
	return _build_slot_result(
		true,
		&"",
		before,
		BUILD_SLOT_IDLE,
		{"refunded": paid_costs.duplicate(true)}
	)


func _build_slot_missing_text(next_payment := false) -> String:
	if not has_build_project():
		return ""
	if next_payment:
		return _shortage_text(_get_build_slot_next_payment().shortages)
	var total_costs: Dictionary = _build_slot.total_costs
	var paid_costs: Dictionary = _build_slot.paid_costs
	var parts: Array[String] = []
	for resource_id in [&"wood", &"food"]:
		if not total_costs.has(resource_id):
			continue
		parts.append("%s %d" % [
			_resource_display_name(resource_id),
			int(total_costs[resource_id]) - int(paid_costs.get(resource_id, 0)),
		])
	return "、".join(parts)


func get_build_slot_presentation() -> Dictionary:
	var slot_state := get_build_slot_state()
	if slot_state == BUILD_SLOT_IDLE:
		return {"state": BUILD_SLOT_IDLE}
	var definition := get_definition(StringName(_build_slot.definition_id))
	var progress := int(_build_slot.progress_milliseconds)
	var required := maxi(int(_build_slot.required_milliseconds), 1)
	var paid_parts: Array[String] = []
	var refund_parts: Array[String] = []
	for resource_id in [&"wood", &"food"]:
		if Dictionary(_build_slot.total_costs).has(resource_id):
			var paid_amount := int(
				Dictionary(_build_slot.paid_costs).get(resource_id, 0)
			)
			paid_parts.append("%s %d/%d" % [
				_resource_display_name(resource_id),
				paid_amount,
				int(_build_slot.total_costs[resource_id]),
			])
			if paid_amount > 0:
				refund_parts.append("%s %d" % [
					_resource_display_name(resource_id),
					paid_amount,
				])
	var status_text := "建造中"
	if slot_state == BUILD_SLOT_WAITING_MATERIAL:
		status_text = "未开工" if progress == 0 else "缺料暂停"
	elif slot_state in [BUILD_SLOT_READY_TO_PLACE, BUILD_SLOT_PLACEMENT_ACTIVE]:
		status_text = "建造完成" if slot_state == BUILD_SLOT_READY_TO_PLACE else "放置中"
	var eta_text := _get_build_slot_eta_text()
	return {
		"state": slot_state,
		"definition_id": StringName(_build_slot.definition_id),
		"display_name": definition.display_name if definition != null else "建筑",
		"effect_text": _get_definition_effect_summary(definition) if definition != null else "",
		"status_text": status_text,
		"progress_percent": clampf(float(progress) * 100.0 / float(required), 0.0, 100.0),
		"paid_text": "、".join(paid_parts),
		"remaining_text": _build_slot_missing_text(false),
		"next_missing_text": _build_slot_missing_text(true),
		"eta_text": eta_text,
		"refund_text": "、".join(refund_parts),
	}


func _get_build_slot_eta_text() -> String:
	var slot_state := get_build_slot_state()
	if slot_state == BUILD_SLOT_WAITING_MATERIAL:
		return "等待材料"
	if city_time_paused:
		return "恢复时间后重新计算"
	if slot_state != BUILD_SLOT_PRODUCING:
		return ""
	var modifier := maxi(get_pressure_modifier_permille(&"construction"), 1)
	var remaining_effective := maxi(
		int(_build_slot.required_milliseconds)
		- int(_build_slot.progress_milliseconds),
		0
	)
	var remaining_world_ms := ceili(float(remaining_effective * 1000) / float(modifier))
	var absolute_ms := (
		(current_day - 1) * MILLISECONDS_PER_DAY
		+ get_day_elapsed_milliseconds()
		+ remaining_world_ms
	)
	var finish_day := floori(float(absolute_ms) / float(MILLISECONDS_PER_DAY)) + 1
	var day_ms := posmod(absolute_ms, MILLISECONDS_PER_DAY)
	var total_minutes := floori(float(day_ms) * 1440.0 / float(MILLISECONDS_PER_DAY))
	return "第 %d 日 %02d:%02d" % [finish_day, total_minutes / 60, total_minutes % 60]


func _on_build_slot_primary_pressed() -> void:
	if get_build_slot_state() == BUILD_SLOT_READY_TO_PLACE:
		activate_ready_placement(get_viewport().get_mouse_position())
	elif get_build_slot_state() in [BUILD_SLOT_PRODUCING, BUILD_SLOT_WAITING_MATERIAL]:
		begin_road_mode(get_viewport().get_mouse_position())


func _get_ordered_construction_ids() -> Array[int]:
	var result: Array[int] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if not record.is_empty() and StringName(record.lifecycle_state) == &"constructing":
			result.append(placement_id)
	result.sort_custom(func(left: int, right: int) -> bool:
		var left_priority := int(_building_records_by_id[left].construction_priority)
		var right_priority := int(_building_records_by_id[right].construction_priority)
		return left_priority > right_priority if left_priority != right_priority else left < right
	)
	return result


func set_construction_priority(placement_id: int, priority: int) -> bool:
	if priority not in [
		CONSTRUCTION_PRIORITY_LOW,
		CONSTRUCTION_PRIORITY_NORMAL,
		CONSTRUCTION_PRIORITY_HIGH,
	]:
		return false
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty() or StringName(record.lifecycle_state) != &"constructing":
		return false
	record.construction_priority = priority
	city_state_changed.emit()
	return true


func get_pressure_modifier_permille(channel_id: StringName) -> int:
	var value := 1000
	if not is_campaign_pressure_cleared():
		if channel_id == &"construction":
			value = MAINLINE_PRESSURE_PROFILE.get_construction_modifier_permille(current_day)
		elif channel_id in [
			&"production",
			&"food_minimum",
			&"basic_repair",
			&"medical_care",
			&"basic_training",
			&"war_supply",
		]:
			value = MAINLINE_PRESSURE_PROFILE.get_production_modifier_permille(current_day)
	if channel_id in [
		&"food_minimum",
		&"basic_repair",
		&"medical_care",
		&"basic_training",
		&"war_supply",
	]:
		value = maxi(value, MAINLINE_PRESSURE_PROFILE.essential_floor_permille)
	return value


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
	amount = maxi(
		floori(float(amount * get_pressure_modifier_permille(&"production")) / 1000.0),
		0
	)
	amount = maxi(
		floori(float(amount * get_workforce_modifier_permille(&"production")) / 1000.0),
		0
	)
	return amount


func get_workforce_modifier_permille(channel: StringName) -> int:
	var health_modifier := clampi(
		_city_governance.health_permille - int(
			float(_population_recovery.resident_sick * 300)
			/ float(maxi(_population_recovery.total_living, 1))
		),
		250,
		1000
	)
	if channel == &"production":
		if StringName(_city_governance.active_event.get("kind", &"")) == &"LOCAL_UNREST" and bool(_city_governance.active_event.get("consequence_applied", false)):
			return 0
		var result := floori(float(clampi(
			floori(float(_population_recovery.production_workers * 1000) / float(RECOVERY_RULES.production_workers_for_full_output)),
			0, 1000
		) * health_modifier) / 1000.0)
		if _is_city_support_active(&"PRODUCTION"):
			result += CITY_STRATEGY_RULES.production_support_permille
		if StringName(_city_governance.active_event.get("kind", &"")) == &"BANDIT_DISRUPTION" and bool(_city_governance.active_event.get("consequence_applied", false)):
			result = floori(float(result) * 0.5)
		return result
	if channel == &"construction":
		if StringName(_city_governance.active_event.get("kind", &"")) == &"LOCAL_UNREST" and bool(_city_governance.active_event.get("consequence_applied", false)):
			return 0
		return floori(float(clampi(
			floori(float(_population_recovery.construction_workers * 1000) / float(RECOVERY_RULES.construction_workers_for_full_speed)),
			0, 1000
		) * health_modifier) / 1000.0)
	return 1000


func get_city_state() -> Dictionary:
	return {
		"city_id": _active_city_id,
		"city_name": get_active_city_name(),
		"layout_profile_id": get_layout_profile_id(),
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
		"training_queue": get_training_queue_snapshot(),
		"population_recovery": get_population_recovery_read_model(),
		"city_governance": get_city_governance_read_model(),
		"day_elapsed_milliseconds": get_day_elapsed_milliseconds(),
		"city_time_speed_id": StringName(
			"%dx" % roundi(city_time_speed)
		),
		"manual_pause": city_time_paused,
		"war_block_reason": (
			&"FIRST_WAR"
			if is_first_war_time_blocked()
			else &""
		),
		"researched_tech_ids": researched_tech_ids.duplicate(),
		"supply_shortage": supply_shortage,
		"emergency_mobilization_used": emergency_mobilization_used,
		"wood_capacity": get_resource_capacity(&"wood"),
			"food_capacity": get_resource_capacity(&"food"),
			"city_defense": get_city_defense(),
		"construction_in_progress": get_construction_in_progress_count(),
		"build_slot": get_build_slot_snapshot(),
			"first_war_preparation": (
				get_first_war_preparation_assessment()
			),
		"enemy_count": enemy_count,
		"enemy_fortification": enemy_fortification,
		"available_infantry_count": get_available_infantry_count(),
		"dispatchable_infantry_count": (
			get_dispatchable_infantry_count()
		),
		"garrison": get_garrison_snapshot(),
		"active_battle_reservation": _active_battle_reservation.duplicate(true),
		"committed_battle_result_ids": _committed_battle_result_ids.keys(),
		"first_clear_keys": _first_clear_keys.keys(),
		"last_battle_result_summary": _last_battle_result_summary.duplicate(true),
		"noticeboard_mission_states": _get_noticeboard_mission_states(),
		"active_noticeboard_mission_id": _active_noticeboard_mission_id,
		"noticeboard_last_result_summary": (
			_noticeboard_last_result_summary.duplicate(true)
		),
		"checkpoint_available": not _readiness_checkpoint.is_empty(),
		"city_time_paused": city_time_paused,
		"city_time_speed": city_time_speed,
		"day_elapsed_seconds": day_elapsed_seconds,
		"day_progress_ratio": get_day_progress_ratio(),
		"seconds_per_day": SECONDS_PER_DAY,
		"first_war_event_id": FIRST_WAR_EVENT_ID,
		"first_war_state": get_first_war_state_id(),
		"first_war_warning_count": first_war_warning_count,
		"first_war_time_blocked": is_first_war_time_blocked(),
		"first_war_pending_outcome": _first_war_pending_outcome,
		"first_war_result_acknowledged": _first_war_result_acknowledged,
		"city_fallen": city_fallen,
		"city_defense_damage": city_defense_damage,
		"last_daily_report": last_daily_report,
		"last_daily_breakdown": last_daily_breakdown.duplicate(true),
	}


func _current_military_population() -> int:
	var total := _garrison_state.get_total_count()
	for army_value in _army_registry.get_armies():
		var army: Dictionary = Dictionary(army_value)
		if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED:
			continue
		for count in Dictionary(army.get("units_by_definition_id", {})).values():
			total += int(count)
	return total


func _current_alive_specialists() -> int:
	_ensure_war_loop_initialized()
	var total := 0
	for specialist_value in _war_loop_state.field_tactics.specialists_by_id.values():
		if bool(Dictionary(specialist_value).get("alive", false)):
			total += 1
	return total


func get_population_recovery_read_model() -> Dictionary:
	var snapshot := _population_recovery.get_snapshot()
	snapshot.military = _current_military_population()
	snapshot.specialists = _current_alive_specialists()
	snapshot.accounted = _population_recovery.invariant_matches(int(snapshot.military), int(snapshot.specialists))
	snapshot.production_permille = mini(1000, floori(float(_population_recovery.production_workers * 1000) / float(RECOVERY_RULES.production_workers_for_full_output)))
	snapshot.construction_permille = mini(1000, floori(float(_population_recovery.construction_workers * 1000) / float(RECOVERY_RULES.construction_workers_for_full_speed)))
	snapshot.medical_workers = _population_recovery.medical_workers
	snapshot.governance_workers = _population_recovery.governance_workers
	snapshot.adults = _population_recovery.total_living - _population_recovery.children - _population_recovery.elderly
	snapshot.work_eligible = _population_recovery.available
	return snapshot


func get_blackstone_personnel_accounting() -> Dictionary:
	var recovery := _population_recovery.get_snapshot()
	var garrison := infantry_count
	var field_army := get_committed_world_infantry_total() - garrison
	var wounded_count := int(recovery.get("wounded", 0))
	var fallen_count := int(recovery.get("fallen", 0))
	var accounted_total := garrison + field_army + wounded_count + fallen_count
	var additions := accounted_total - BLACKSTONE_INITIAL_MILITARY_COUNT
	return {
		"initial_military": BLACKSTONE_INITIAL_MILITARY_COUNT,
		"added_military": maxi(additions, 0),
		"garrison_survivors": garrison,
		"field_army_survivors": field_army,
		"wounded": wounded_count,
		"fallen": fallen_count,
		"accounted_total": accounted_total,
		"reconciled": additions >= 0,
	}


func get_city_season_id(day := -1) -> StringName:
	var effective_day := current_day if day < 0 else day
	var season_index := ((maxi(effective_day, 1) - 1) / CITY_GOVERNANCE_RULES.days_per_season) % 4
	return [&"SPRING", &"SUMMER", &"AUTUMN", &"WINTER"][season_index]


func get_city_housing_capacity() -> int:
	var capacity := CITY_GOVERNANCE_RULES.base_housing_capacity
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or not is_building_operational(placement_id):
			continue
		var definition := get_definition(StringName(record.definition_id))
		var capability := definition.get_capability(&"housing") if definition != null else null
		if capability != null:
			capacity += capability.amount
	if get_city_season_id() == &"WINTER":
		capacity = maxi(capacity - CITY_GOVERNANCE_RULES.winter_housing_penalty, 0)
	return capacity


func get_city_medical_capacity() -> int:
	var capacity := CITY_GOVERNANCE_RULES.base_medical_capacity
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or not is_building_operational(placement_id):
			continue
		var definition := get_definition(StringName(record.definition_id))
		var capability := definition.get_capability(&"medical_capacity") if definition != null else null
		if capability != null:
			capacity += capability.amount
	if _is_city_support_active(&"MEDICAL"):
		capacity += CITY_STRATEGY_RULES.medical_support_capacity
	return capacity


func get_city_governance_read_model() -> Dictionary:
	var snapshot := _city_governance.get_snapshot()
	snapshot.season_id = get_city_season_id()
	snapshot.season_name = {&"SPRING": "春", &"SUMMER": "夏", &"AUTUMN": "秋", &"WINTER": "冬"}.get(snapshot.season_id, "")
	snapshot.housing_capacity = get_city_housing_capacity()
	snapshot.housing_shortfall = maxi(_population_recovery.total_living - int(snapshot.housing_capacity), 0)
	snapshot.medical_capacity = get_city_medical_capacity()
	snapshot.security = city_security
	snapshot.food_required = get_maintenance_food_cost()
	snapshot.diseased_count = _population_recovery.resident_sick
	snapshot.pending_refugees = _population_recovery.unsettled_refugees
	snapshot.housing_surplus = maxi(int(snapshot.housing_capacity) - _population_recovery.total_living, 0)
	snapshot.growth_blocker = _get_population_growth_blocker()
	snapshot.refugee_medical_burden = _get_refugee_medical_burden()
	snapshot.active_issue = ""
	if int(snapshot.housing_shortfall) > 0:
		snapshot.active_issue = "居住容量不足 %d 人" % int(snapshot.housing_shortfall)
	elif _city_governance.consecutive_food_shortage_days > 0:
		snapshot.active_issue = "粮食短缺已持续 %d 日" % _city_governance.consecutive_food_shortage_days
	elif _population_recovery.resident_sick > 0:
		snapshot.active_issue = "患病 %d 人，医疗照护中" % _population_recovery.resident_sick
	elif StringName(_city_governance.active_event.phase) == CityGovernanceState.EVENT_ACTIVE:
		snapshot.active_issue = {&"PETTY_THEFT": "轻微盗窃事件待治理", &"BANDIT_DISRUPTION": "周边土匪正在干扰生产", &"LOCAL_UNREST": "局部秩序失控，城市工作停顿"}.get(StringName(_city_governance.active_event.kind), "治安事件待处理")
	elif _city_governance.pressure_points >= CITY_GOVERNANCE_RULES.pressure_warning_threshold:
		snapshot.active_issue = "治安压力正在累积：%d/100；可调整治理岗位并改善粮食、住房与健康" % _city_governance.pressure_points
	elif get_city_season_id() == &"AUTUMN":
		snapshot.active_issue = "入冬预警：检查粮储与住房"
	return snapshot


func _get_population_growth_blocker() -> String:
	if get_city_housing_capacity() <= _population_recovery.total_living:
		return "住房已满"
	if supply_shortage or _city_governance.consecutive_food_shortage_days > 0:
		return "粮食不足"
	if _city_governance.health_permille < CITY_GOVERNANCE_RULES.growth_health_threshold_permille or _population_recovery.resident_sick > 0:
		return "健康承压"
	return ""


func _get_refugee_medical_burden() -> int:
	var total := 0
	for value in _city_governance.refugee_cases_by_id.values():
		var refugee_case: Dictionary = Dictionary(value)
		if StringName(refugee_case.phase) in [CityGovernanceState.REFUGEE_WAITING_HOUSING, CityGovernanceState.REFUGEE_SETTLED]:
			total += int(refugee_case.medical_burden)
	return total


func _count_refugees_arriving_on_day(day: int) -> int:
	var total := 0
	for value in _city_governance.refugee_cases_by_id.values():
		var refugee_case: Dictionary = Dictionary(value)
		if int(refugee_case.arrival_day) == day:
			total += int(refugee_case.count)
	return total


func _advance_city_demography(food_ok: bool, housing_surplus: int) -> Dictionary:
	var result := {"births": 0, "matured": 0, "aged": 0, "deaths": 0}
	if food_ok and housing_surplus > 0 and _city_governance.health_permille >= CITY_GOVERNANCE_RULES.growth_health_threshold_permille and _population_recovery.resident_sick == 0:
		_population_recovery.growth_progress += CITY_GOVERNANCE_RULES.growth_progress_per_day
		if _population_recovery.growth_progress >= CITY_GOVERNANCE_RULES.birth_progress_required and _population_recovery.record_birth():
			_population_recovery.growth_progress -= CITY_GOVERNANCE_RULES.birth_progress_required
			result.births = 1
	_population_recovery.child_age_progress += _population_recovery.children
	if _population_recovery.child_age_progress >= CITY_GOVERNANCE_RULES.child_maturation_person_days and _population_recovery.mature_child():
		_population_recovery.child_age_progress -= CITY_GOVERNANCE_RULES.child_maturation_person_days
		result.matured = 1
	_population_recovery.adult_age_progress += _population_recovery.available
	if _population_recovery.adult_age_progress >= CITY_GOVERNANCE_RULES.adult_ageing_person_days and _population_recovery.age_available_adult():
		_population_recovery.adult_age_progress -= CITY_GOVERNANCE_RULES.adult_ageing_person_days
		result.aged = 1
	if get_city_season_id() == &"WINTER" and _city_governance.consecutive_housing_pressure_days >= CITY_GOVERNANCE_RULES.cold_consequence_trigger_days:
		_population_recovery.elderly_exposure_progress += _population_recovery.elderly
	else:
		_population_recovery.elderly_exposure_progress = maxi(_population_recovery.elderly_exposure_progress - _population_recovery.elderly, 0)
	if _population_recovery.elderly_exposure_progress >= CITY_GOVERNANCE_RULES.elderly_exposure_person_days and _population_recovery.record_elderly_death():
		_population_recovery.elderly_exposure_progress -= CITY_GOVERNANCE_RULES.elderly_exposure_person_days
		result.deaths = 1
	return result


func _apply_city_governance_event_consequence() -> Dictionary:
	if StringName(_city_governance.active_event.phase) != CityGovernanceState.EVENT_ACTIVE or bool(_city_governance.active_event.consequence_applied):
		return {}
	var kind := StringName(_city_governance.active_event.kind)
	if kind == &"PETTY_THEFT":
		var loss := mini(food, CITY_GOVERNANCE_RULES.petty_theft_food_loss)
		var before := _city_governance.get_snapshot()
		var local_commit := func() -> Dictionary:
			return {"success": _city_governance.mark_active_event_consequence_applied()}
		if loss > 0 and not _commit_national_resources([{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": loss}], &"city_petty_theft", local_commit):
			_city_governance.restore_snapshot(before)
			return {}
		if loss == 0:
			_city_governance.mark_active_event_consequence_applied()
		return {"food_loss": loss, "target_id": &"food"}
	_city_governance.mark_active_event_consequence_applied()
	return {"food_loss": 0, "target_id": StringName(_city_governance.active_event.target_id)}


func get_city_strategy_read_model() -> Dictionary:
	var snapshot := _city_strategy.get_snapshot()
	snapshot.active_support_effective = (
		StringName(_city_strategy.active_support.get("phase", &"")) == CityStrategyState.SUPPORT_ACTIVE
		and current_day < int(_city_strategy.active_support.get("expires_day", 0))
	)
	snapshot.official_names = {&"official.steward": "司仓主簿", &"official.physician": "医政官", &"official.strategist": "守御参军"}
	snapshot.equipment_names = {
		&"equipment.spear_kit": "长枪制式", &"equipment.padded_armor": "绵甲制式", &"equipment.marching_kit": "轻行装具",
		&"equipment.general.bronze_sword": "青铜佩剑", &"equipment.general.iron_sword": "精铁长剑",
		&"equipment.general.scout_helmet": "斥候盔", &"equipment.general.lamellar": "将领札甲",
		&"equipment.general.leather_gloves": "控缰护手", &"equipment.general.riding_boots": "骑行战靴",
		&"equipment.general.command_talisman": "军令符佩",
	}
	snapshot.equipment_costs = CITY_STRATEGY_RULES.equipment_costs.duplicate(true)
	snapshot.equipment_training_costs = CITY_STRATEGY_RULES.equipment_training_costs.duplicate(true)
	snapshot.equipment_rank_costs = CITY_STRATEGY_RULES.equipment_rank_costs.duplicate(true)
	var growth_models := {}
	for equipment_id_value in Dictionary(snapshot.equipment_growth_by_id):
		var equipment_id := StringName(equipment_id_value)
		var growth: Dictionary = Dictionary(snapshot.equipment_growth_by_id[equipment_id])
		var level := _city_strategy.equipment_level(equipment_id, CITY_STRATEGY_RULES.equipment_experience_per_level, CITY_STRATEGY_RULES.equipment_level_caps)
		var cap := int(CITY_STRATEGY_RULES.equipment_level_caps.get(StringName(growth.quality_id), 1))
		growth.level = level
		growth.level_cap = cap
		growth.effect_permille = level * CITY_STRATEGY_RULES.general_equipment_effect_permille
		growth.can_rank_up = level >= cap and StringName(growth.quality_id) != CITY_STRATEGY_RULES.equipment_quality_order.back()
		growth.assigned = _city_strategy.is_equipment_assigned(equipment_id)
		growth_models[equipment_id] = growth
	snapshot.equipment_growth_models = growth_models
	snapshot.quality_names = {&"COMMON": "常备", &"FINE": "精制", &"ELITE": "名品"}
	snapshot.general_slot_names = {&"weapon": "武器", &"helmet": "头盔", &"armor": "护甲", &"gloves": "护手", &"boots": "战靴", &"accessory": "饰物"}
	snapshot.support_descriptions = {&"official.steward": "生产 +25%，持续至下一城市日", &"official.physician": "医疗容量 +4，持续至下一城市日", &"official.strategist": "下一次冻结的防御参数 +15%"}
	snapshot.selected_general_id = selected_general_id
	var selected_general := get_selected_general()
	snapshot.selected_general_name = selected_general.display_name if selected_general != null else "未选择将领"
	var offers := CITY_STRATEGY_RULES.trade_offers.duplicate(true)
	for offer_id_value in offers.keys():
		var offer: Dictionary = offers[offer_id_value]
		var spend_available := _nation_state.get_resource(StringName(offer.spend_id))
		var gain_available := _nation_state.get_resource(StringName(offer.gain_id))
		var gain_capacity := get_resource_capacity(StringName(offer.gain_id))
		var already_used := _city_strategy.trade_day == current_day and StringName(offer_id_value) in _city_strategy.used_trade_offer_ids
		offer.spend_available = spend_available
		offer.gain_available = gain_available
		offer.gain_capacity = gain_capacity
		offer.can_execute = not already_used and spend_available >= int(offer.spend) and gain_available + int(offer.gain) <= gain_capacity and not is_city_action_locked_for_battle()
		offer.blocked_reason = "今日已交易" if already_used else ("付出资源不足" if spend_available < int(offer.spend) else ("目标仓储容量不足" if gain_available + int(offer.gain) > gain_capacity else ""))
		offers[offer_id_value] = offer
	snapshot.trade_offers = offers
	return snapshot


func _is_city_support_active(support_type: StringName) -> bool:
	return (
		StringName(_city_strategy.active_support.get("phase", &"")) == CityStrategyState.SUPPORT_ACTIVE
		and StringName(_city_strategy.active_support.get("support_type", &"")) == support_type
		and current_day < int(_city_strategy.active_support.get("expires_day", 0))
	)


func _persist_city_strategy_checkpoint() -> bool:
	if _city_strategy_fault_for_test == &"CHECKPOINT_SAVE_FAILED":
		_city_strategy_fault_for_test = &""
		return false
	return bool(_persist_macro_march_checkpoint().get("success", false))


func _rollback_city_strategy_change(strategy_before: Dictionary, resources_before: Dictionary = {}) -> void:
	_city_strategy.restore_snapshot(strategy_before)
	if not resources_before.is_empty() and not _replace_national_resources(resources_before, &"city_strategy_checkpoint_rollback"):
		push_error("City strategy resource rollback failed")
	_refresh_city_ui()


func appoint_city_official(official_id: StringName) -> Dictionary:
	var before := _city_strategy.get_snapshot()
	if is_city_action_locked_for_battle() or not _city_strategy.appoint(official_id):
		return {"success": false, "error": "该文官尚未获得，或战斗事务正在锁定城市"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before)
		return {"success": false, "error": "任命存档失败，选择已回滚"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func activate_city_official_support() -> Dictionary:
	if is_city_action_locked_for_battle():
		return {"success": false, "error": "战斗事务处理中不能启用新的城市支援"}
	var before := _city_strategy.get_snapshot()
	var support := _city_strategy.begin_support(_city_strategy.appointed_official_id, current_day, CITY_STRATEGY_RULES)
	if support.is_empty() or not _persist_city_strategy_checkpoint():
		_city_strategy.restore_snapshot(before)
		return {"success": false, "error": "关卡能量不足、已有支援生效，或存档失败"}
	_refresh_city_ui()
	return {"success": true, "support": support}


func get_battle_official_support_model() -> Dictionary:
	var official_id := _city_strategy.appointed_official_id
	var allowed_kinds: Array[StringName] = []
	if official_id == &"official.physician":
		allowed_kinds = [BattleSession.SUPPORT_HEAL]
	elif official_id == &"official.strategist":
		allowed_kinds = [
			BattleSession.SUPPORT_MOVE, BattleSession.SUPPORT_ATTACK,
			BattleSession.SUPPORT_PROTECT, BattleSession.SUPPORT_DOMAIN,
		]
	return {
		"appointed_official_id": official_id,
		"appointed_official_name": {
			&"official.steward": "治粟官", &"official.physician": "医官",
			&"official.strategist": "军谋官",
		}.get(official_id, "未任命"),
		"campaign_energy": _city_strategy.campaign_energy,
		"allowed_kinds": allowed_kinds,
	}


## One durable boundary owns both the account-wide energy debit and the
## BattleSession command. A failed checkpoint restores both snapshots, so a
## retry cannot spend energy without an effect or duplicate an accepted effect.
func commit_battle_official_support(
	coordinator: CombatTransactionCoordinator,
	kind: StringName,
	squad_id: int,
	route_id: StringName = &""
) -> Dictionary:
	if (
		not is_combat_transaction_coordinator_bound(coordinator)
		or coordinator.active_session == null
		or coordinator.active_request == null
		or coordinator.active_request.phase != BattleRequest.PHASE_ACTIVE
	):
		return {"success": false, "error": "当前没有可接受支援命令的战斗"}
	var model := get_battle_official_support_model()
	if kind not in Array(model.allowed_kinds):
		return {"success": false, "error": "当前任命文官不能使用这项战中能力"}
	if int(model.campaign_energy) <= 0:
		return {"success": false, "error": "关卡能量不足"}
	var context := coordinator.get_battle_source_context()
	if not bool(context.get("macro_siege", false)) and not bool(context.get("prepared_expedition", false)):
		return {"success": false, "error": "该临时战斗尚不支持持久文官命令"}
	var strategy_before := _city_strategy.get_snapshot()
	var session_before := coordinator.active_session.get_snapshot()
	var receipt := coordinator.active_session.issue_official_support(kind, squad_id, route_id)
	if receipt.is_empty() or not _city_strategy.spend_campaign_energy(1):
		coordinator.active_session.restore_snapshot(session_before)
		_city_strategy.restore_snapshot(strategy_before)
		return {"success": false, "error": "目标当前不适用该支援，未消耗能量"}
	var checkpoint: Dictionary
	if bool(context.get("macro_siege", false)):
		checkpoint = checkpoint_macro_siege_battle_session(
			StringName(context.get("army_id", &"")),
			StringName(context.get("city_id", &"")),
			StringName(context.get("transaction_id", &"")),
			coordinator.active_session.get_snapshot()
		)
	else:
		checkpoint = checkpoint_active_battle_session(
			StringName(context.get("transaction_id", &"")),
			coordinator.active_session.get_snapshot()
		)
	if not bool(checkpoint.get("success", false)):
		coordinator.active_session.restore_snapshot(session_before)
		_city_strategy.restore_snapshot(strategy_before)
		_refresh_city_ui()
		return {"success": false, "error": "战中支援保存失败，能量与效果已回滚"}
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "receipt": receipt, "campaign_energy": _city_strategy.campaign_energy}


func craft_city_equipment(equipment_id: StringName) -> Dictionary:
	if is_city_action_locked_for_battle() or _city_strategy.owned_equipment_ids.has(equipment_id):
		return {"success": false, "error": "战斗事务处理中不能制造，或装备已经拥有"}
	var costs: Dictionary = Dictionary(CITY_STRATEGY_RULES.equipment_costs.get(equipment_id, {}))
	if costs.is_empty():
		return {"success": false, "error": "未知装备"}
	var before := _city_strategy.get_snapshot()
	var resources_before := _nation_state.get_shared_resources()
	var entries: Array[Dictionary] = []
	for resource_id in costs:
		entries.append({"resource_id": StringName(resource_id), "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": int(costs[resource_id])})
	var local_commit := func() -> Dictionary: return {"success": _city_strategy.own_equipment(equipment_id)}
	if not _commit_national_resources(entries, &"equipment_crafting", local_commit):
		_city_strategy.restore_snapshot(before)
		return {"success": false, "error": "材料不足或装备事务未提交"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before, resources_before)
		return {"success": false, "error": "装备存档失败，材料与物品已回滚"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func equip_city_troops(equipment_id: StringName) -> Dictionary:
	var before := _city_strategy.get_snapshot()
	if is_city_action_locked_for_battle() or not _city_strategy.equip_troops(equipment_id):
		return {"success": false, "error": "只能在城市整备已拥有的制式装备"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before)
		return {"success": false, "error": "装配存档失败，原装配已恢复"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func unequip_city_troops(equipment_id: StringName) -> Dictionary:
	var before := _city_strategy.get_snapshot()
	if is_city_action_locked_for_battle() or not _city_strategy.unequip_troops(equipment_id):
		return {"success": false, "error": "只能在城市卸下当前已装配的制式装备"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before)
		return {"success": false, "error": "卸装存档失败，原装配已恢复"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func equip_city_general(equipment_id: StringName) -> Dictionary:
	var before := _city_strategy.get_snapshot()
	if is_city_action_locked_for_battle() or selected_general_id == &"" or not _city_strategy.equip_general(selected_general_id, equipment_id):
		return {"success": false, "error": "请先在城市选择将领，并使用已拥有且未被占用的将领装备"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before)
		return {"success": false, "error": "将领装配存档失败，原装配已恢复"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func unequip_city_general(equipment_id: StringName) -> Dictionary:
	var before := _city_strategy.get_snapshot()
	if is_city_action_locked_for_battle() or selected_general_id == &"" or not _city_strategy.unequip_general(selected_general_id, equipment_id):
		return {"success": false, "error": "只能在城市卸下当前将领已装配的装备"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before)
		return {"success": false, "error": "将领卸装存档失败，原装配已恢复"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func train_city_equipment(equipment_id: StringName) -> Dictionary:
	if is_city_action_locked_for_battle() or equipment_id not in _city_strategy.owned_equipment_ids or not _city_strategy.equipment_growth_by_id.has(equipment_id):
		return {"success": false, "error": "只能在城市培养已拥有的将领装备"}
	var before := _city_strategy.get_snapshot()
	var resources_before := _nation_state.get_shared_resources()
	var entries: Array[Dictionary] = []
	for resource_id in CITY_STRATEGY_RULES.equipment_training_costs:
		entries.append({"resource_id": StringName(resource_id), "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": int(CITY_STRATEGY_RULES.equipment_training_costs[resource_id])})
	var local_commit := func() -> Dictionary:
		return {"success": _city_strategy.train_equipment(equipment_id, CITY_STRATEGY_RULES.equipment_training_experience)}
	if not _commit_national_resources(entries, &"equipment_training", local_commit):
		_city_strategy.restore_snapshot(before)
		return {"success": false, "error": "培养资源不足或装备状态已经变化"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before, resources_before)
		return {"success": false, "error": "培养存档失败，资源与经验已回滚"}
	_refresh_city_ui()
	return {"success": true, "action": &"TRAINED", "equipment_id": equipment_id, "strategy": get_city_strategy_read_model()}


func rank_up_city_equipment(equipment_id: StringName) -> Dictionary:
	var growth: Dictionary = Dictionary(_city_strategy.equipment_growth_by_id.get(equipment_id, {}))
	if is_city_action_locked_for_battle() or growth.is_empty():
		return {"success": false, "error": "装备不存在或战斗事务正在锁定城市"}
	var costs: Dictionary = Dictionary(CITY_STRATEGY_RULES.equipment_rank_costs.get(StringName(growth.quality_id), {}))
	if costs.is_empty():
		return {"success": false, "error": "尚未达到升阶条件或已是最高品质"}
	var before := _city_strategy.get_snapshot()
	var resources_before := _nation_state.get_shared_resources()
	var entries: Array[Dictionary] = []
	for resource_id in costs:
		entries.append({"resource_id": StringName(resource_id), "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": int(costs[resource_id])})
	var local_commit := func() -> Dictionary:
		return {"success": _city_strategy.rank_up_equipment(equipment_id, CITY_STRATEGY_RULES.equipment_quality_order, CITY_STRATEGY_RULES.equipment_experience_per_level, CITY_STRATEGY_RULES.equipment_level_caps)}
	if not _commit_national_resources(entries, &"equipment_rank_up", local_commit):
		_city_strategy.restore_snapshot(before)
		return {"success": false, "error": "需达到当前等级上限，并备齐升阶资源"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before, resources_before)
		return {"success": false, "error": "升阶存档失败，品质与资源已回滚"}
	_refresh_city_ui()
	return {"success": true, "action": &"RANKED_UP", "equipment_id": equipment_id, "strategy": get_city_strategy_read_model()}


func inherit_city_equipment_experience(target_id: StringName, source_id: StringName) -> Dictionary:
	var before := _city_strategy.get_snapshot()
	if is_city_action_locked_for_battle() or _army_registry.is_equipment_referenced_by_active_macro_order(source_id) or not _city_strategy.inherit_equipment_experience(target_id, source_id, CITY_STRATEGY_RULES.equipment_experience_per_level):
		return {"success": false, "error": "仅可消耗同槽、未装配且未占用的将领装备进行经验继承"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before)
		return {"success": false, "error": "继承存档失败，来源装备与目标经验已回滚"}
	_refresh_city_ui()
	return {"success": true, "action": &"INHERITED", "target_id": target_id, "source_id": source_id, "strategy": get_city_strategy_read_model()}


func execute_city_trade(offer_id: StringName) -> Dictionary:
	if is_city_action_locked_for_battle():
		return {"success": false, "error": "战斗事务处理中不能交易"}
	var offer: Dictionary = Dictionary(CITY_STRATEGY_RULES.trade_offers.get(offer_id, {}))
	if offer.is_empty() or (_city_strategy.trade_day == current_day and offer_id in _city_strategy.used_trade_offer_ids):
		return {"success": false, "error": "交易不存在或今日已经执行"}
	var gain_id := StringName(offer.gain_id)
	if _nation_state.get_resource(gain_id) + int(offer.gain) > get_resource_capacity(gain_id):
		return {"success": false, "error": "目标仓储容量不足"}
	var before := _city_strategy.get_snapshot()
	var resources_before := _nation_state.get_shared_resources()
	var local_commit := func() -> Dictionary:
		var receipt := _city_strategy.record_trade(offer_id, current_day)
		return {"success": not receipt.is_empty(), "receipt": receipt}
	var entries: Array[Dictionary] = [
		{"resource_id": StringName(offer.spend_id), "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": int(offer.spend)},
		{"resource_id": gain_id, "operation": NationState.RESOURCE_OPERATION_ADD, "amount": int(offer.gain)},
	]
	if not _commit_national_resources(entries, &"city_trade", local_commit):
		_city_strategy.restore_snapshot(before)
		return {"success": false, "error": "资源、容量或交易条件不满足"}
	if not _persist_city_strategy_checkpoint():
		_rollback_city_strategy_change(before, resources_before)
		return {"success": false, "error": "交易存档失败，资源与回执已回滚"}
	_refresh_city_ui()
	return {"success": true, "strategy": get_city_strategy_read_model()}


func resolve_city_governance_event() -> Dictionary:
	if is_city_action_locked_for_battle():
		return {"success": false, "error": "战斗事务处理中不能安排治理"}
	if StringName(_city_governance.active_event.phase) != CityGovernanceState.EVENT_ACTIVE:
		return {"success": false, "error": "当前没有待处理的治安事件"}
	if _population_recovery.governance_workers < 2:
		return {"success": false, "error": "至少需要 2 名治理人员"}
	var governance_before := _city_governance.get_snapshot()
	var security_before := city_security
	var local_commit := func() -> Dictionary:
		if _city_governance.resolve_active_event(CITY_GOVERNANCE_RULES.governance_resolution_pressure_relief).is_empty():
			return {"success": false}
		city_security = mini(city_security + 5, 100)
		return {"success": true}
	var committed := _commit_national_resources([{
		"resource_id": &"food",
		"operation": NationState.RESOURCE_OPERATION_SPEND,
		"amount": CITY_GOVERNANCE_RULES.governance_action_food_cost,
	}], &"city_governance_action", local_commit)
	if not committed:
		_city_governance.restore_snapshot(governance_before)
		city_security = security_before
		return {"success": false, "error": "粮食不足，治理行动未提交"}
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "governance": get_city_governance_read_model()}


func decide_refugee_case(case_id: StringName, decision: StringName) -> Dictionary:
	if is_city_action_locked_for_battle():
		return {"success": false, "error": "战斗事务处理中不能处理安置"}
	var refugee_case: Dictionary = Dictionary(_city_governance.refugee_cases_by_id.get(case_id, {}))
	if refugee_case.is_empty():
		return {"success": false, "error": "难民来源不存在或尚未抵达"}
	var population_before := _population_recovery.get_snapshot()
	var governance_before := _city_governance.get_snapshot()
	var success := false
	match decision:
		&"ACCEPT":
			success = _population_recovery.accept_refugees(int(refugee_case.count)) and _city_governance.set_refugee_phase(case_id, CityGovernanceState.REFUGEE_WAITING_HOUSING, current_day)
		&"DEFER":
			success = _city_governance.set_refugee_phase(case_id, CityGovernanceState.REFUGEE_DEFERRED, current_day)
		&"REJECT":
			success = _city_governance.set_refugee_phase(case_id, CityGovernanceState.REFUGEE_REJECTED, current_day)
	if not success or not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		_population_recovery.restore_snapshot(population_before)
		_city_governance.restore_snapshot(governance_before)
		return {"success": false, "error": "该来源已经决定，或人口守恒校验失败"}
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "case": Dictionary(_city_governance.refugee_cases_by_id[case_id]).duplicate(true), "governance": get_city_governance_read_model()}


func settle_refugee_case(case_id: StringName) -> Dictionary:
	if is_city_action_locked_for_battle():
		return {"success": false, "error": "战斗事务处理中不能安排安置"}
	var refugee_case: Dictionary = Dictionary(_city_governance.refugee_cases_by_id.get(case_id, {}))
	if refugee_case.is_empty() or StringName(refugee_case.phase) != CityGovernanceState.REFUGEE_WAITING_HOUSING:
		return {"success": false, "error": "该来源当前不在待安置状态"}
	if get_city_housing_capacity() < _population_recovery.total_living:
		return {"success": false, "error": "住房不足 %d 人；可先建设民居并保持等待" % (_population_recovery.total_living - get_city_housing_capacity())}
	var population_before := _population_recovery.get_snapshot()
	var governance_before := _city_governance.get_snapshot()
	var count := int(refugee_case.count)
	var sick_count := int(refugee_case.medical_burden)
	if not _population_recovery.settle_refugees(count, sick_count) or not _city_governance.set_refugee_phase(case_id, CityGovernanceState.REFUGEE_SETTLED, current_day) or not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		_population_recovery.restore_snapshot(population_before)
		_city_governance.restore_snapshot(governance_before)
		return {"success": false, "error": "安置事务失败，状态未改变"}
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "case": Dictionary(_city_governance.refugee_cases_by_id[case_id]).duplicate(true), "population_recovery": get_population_recovery_read_model()}


func adjust_city_workforce(channel: StringName, delta: int) -> Dictionary:
	if is_city_action_locked_for_battle():
		return {"success": false, "error": "战斗事务处理中不能调整人员"}
	var before := _population_recovery.get_snapshot()
	if not _population_recovery.allocate_worker(channel, delta):
		return {"success": false, "error": "没有足够可用人口，或该岗位无人可调离"}
	if not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		_population_recovery.restore_snapshot(before)
		return {"success": false, "error": "人口守恒校验失败"}
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "population_recovery": get_population_recovery_read_model()}


func preview_wounded_treatment() -> Dictionary:
	var error := ""
	var count := mini(mini(_population_recovery.wounded, RECOVERY_RULES.treatment_batch_size), mini(get_city_medical_capacity(), _population_recovery.medical_workers))
	var cost := count * RECOVERY_RULES.treatment_food_per_person
	if is_city_action_locked_for_battle():
		error = "战斗事务处理中不能开始治疗"
	elif StringName(_population_recovery.treatment.phase) != PopulationRecoveryState.TREATMENT_IDLE:
		error = "已有治疗正在进行，需等待当前批次完成"
	elif _population_recovery.wounded <= 0:
		error = "当前没有待治疗伤员"
	elif _population_recovery.medical_workers <= 0:
		error = "医疗岗位无人；先调入至少 1 名可用人员"
	elif get_city_medical_capacity() <= 0:
		error = "没有可用医疗容量；检查医舍是否完工"
	elif food < cost:
		error = "治疗 %d 人还缺 %d 粮" % [count, cost - food]
	return {"valid": error.is_empty(), "error": error, "count": count, "food_cost": cost}


func begin_wounded_treatment() -> Dictionary:
	var preview := preview_wounded_treatment()
	if not bool(preview.valid):
		return {"success": false, "error": str(preview.error)}
	var count := int(preview.count)
	var food_cost := int(preview.food_cost)
	var required := count * RECOVERY_RULES.treatment_milliseconds_per_person
	var population_before := _population_recovery.get_snapshot()
	var local_commit := func() -> Dictionary:
		var treatment := _population_recovery.begin_treatment(count, food_cost, required)
		if treatment.is_empty():
			return {"success": false}
		return {"success": true, "treatment": treatment}
	var entries: Array[Dictionary] = []
	if food_cost > 0:
		entries.append({"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost})
	var committed := _commit_national_resources(entries, &"wounded_treatment", local_commit) if not entries.is_empty() else bool(local_commit.call().get("success", false))
	if not committed:
		_population_recovery.restore_snapshot(population_before)
		return {"success": false, "error": "粮食不足或治疗事务未提交"}
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "treatment": _population_recovery.treatment.duplicate(true)}


func _advance_population_recovery(delta_milliseconds: int) -> void:
	var due := _population_recovery.advance_treatment(delta_milliseconds)
	if due.is_empty():
		return
	var count := int(due.get("count", 0))
	var capacity := mini(recruitment_cap, get_effective_command_limit())
	if _garrison_state.get_total_count() + count > capacity:
		return
	var garrison_before := _garrison_state.get_persistence_snapshot()
	var population_before := _population_recovery.get_snapshot()
	if (
		not _garrison_state.try_add_units(INFANTRY_ROLE.role_id, count, capacity)
		or _population_recovery.complete_treatment(StringName(due.get("treatment_id", &""))) != count
	):
		_garrison_state.restore_persistence_snapshot(garrison_before)
		_population_recovery.restore_snapshot(population_before)
		return
	_refresh_city_ui()
	city_state_changed.emit()


func export_early_city_snapshot() -> Dictionary:
	if _active_city_id != CITY_LAYOUT_PROFILE_RESOLVER.BLACKSTONE_CITY_ID:
		return {}
	var scope_error := _get_early_city_snapshot_scope_error()
	if not scope_error.is_empty():
		return {}
	var placements: Array[Dictionary] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			record.is_empty()
			or record.placement_kind == PLACEMENT_KIND_FIXED
		):
			continue
		placements.append({
			"placement_id": placement_id,
			"definition_id": StringName(record.definition_id),
			"origin_cell": Vector2i(record.origin_cell),
			"lifecycle_state": StringName(record.lifecycle_state),
			"built_day": int(record.built_day),
			"disabled_until_day": int(record.disabled_until_day),
			"construction_started_day": int(
				record.construction_started_day
			),
			"construction_complete_day": int(
				record.construction_complete_day
			),
		})
	var snapshot := {
		"schema_version": EARLY_CITY_SNAPSHOT_V1.SCHEMA_VERSION,
		"snapshot_kind": EARLY_CITY_SNAPSHOT_V1.SNAPSHOT_KIND,
		"city_id": EARLY_CITY_SNAPSHOT_V1.CITY_ID,
		"city": {
			"current_day": current_day,
			"day_elapsed_seconds": day_elapsed_seconds,
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
			"emergency_mobilization_used": (
				emergency_mobilization_used
			),
			"city_time_paused": city_time_paused,
			"city_time_speed": city_time_speed,
		},
		"placements": placements,
		"next_placement_id": _next_placement_id,
	}
	var validation := validate_early_city_snapshot(snapshot)
	return (
		validation.snapshot.duplicate(true)
		if bool(validation.valid)
		else {}
	)


func export_v5_campaign_snapshot() -> Dictionary:
	# V5 remains a Blackstone-scoped schema.  Never serialize Riverbend under
	# the legacy blackstone city_id until a versioned multi-city schema exists.
	if _active_city_id != CITY_LAYOUT_PROFILE_RESOLVER.BLACKSTONE_CITY_ID:
		return {}
	if (
		(
			not _active_battle_reservation.is_empty()
			and not _is_durable_expedition_reservation()
		)
		or not _active_army_dispatch_reservation.is_empty()
		or not _active_army_encounter.is_empty()
	):
		return {}
	var legacy_city := V5_NATIONAL_RESOURCE_ADAPTER.project_into_legacy_city(
		{
			"current_day": current_day,
			"day_elapsed_milliseconds": (
				get_day_elapsed_milliseconds()
			),
			"recruitment_cap": recruitment_cap,
			"selected_general_id": selected_general_id,
			"researched_tech_ids": researched_tech_ids.duplicate(),
			"supply_shortage": supply_shortage,
			"emergency_mobilization_used": (
				emergency_mobilization_used
			),
			"city_time_paused": city_time_paused,
			"city_time_speed_id": StringName(
				"%dx" % roundi(city_time_speed)
			),
			"security": city_security,
		},
		_nation_state
	)
	if legacy_city.is_empty():
		return {}
	var snapshot := {
		"schema_version": V5CampaignSnapshot.SCHEMA_VERSION,
		"snapshot_kind": V5CampaignSnapshot.SNAPSHOT_KIND,
		"city_id": V5CampaignSnapshot.CITY_ID,
		"city": legacy_city,
		"placements": _export_v5_placements(),
		"next_placement_id": _next_placement_id,
		"garrison": _garrison_state.get_persistence_snapshot(),
		"training_queue": _training_queue.get_snapshot(),
		"army_registry": _army_registry.get_snapshot(),
		"settlement_ledger": {
			"committed_results_by_id": (
				_committed_battle_result_ids.duplicate(true)
			),
			"closed_transactions_by_id": (
				_closed_battle_transactions.duplicate(true)
			),
			"first_clear_keys": _first_clear_keys.duplicate(true),
			"completed_noticeboard_mission_ids": (
				_completed_noticeboard_mission_ids.duplicate(true)
			),
			"next_battle_transaction_sequence": (
				_next_battle_transaction_sequence
			),
			"next_army_dispatch_transaction_sequence": (
				_next_army_dispatch_transaction_sequence
			),
		},
		"mainline_level": _current_mainline_level.get_snapshot(),
		"build_slot": get_build_slot_snapshot(),
		"expedition_attempt": _expedition_attempt.duplicate(true),
		"war_loop": _war_loop_state.get_snapshot(),
		"population_recovery": _population_recovery.get_snapshot(),
		"city_governance": _city_governance.get_snapshot(),
		"city_strategy": _city_strategy.get_snapshot(),
	}
	var validation := validate_v5_campaign_snapshot(snapshot)
	if not bool(validation.valid):
		push_error(
			"V5 campaign snapshot validation failed: %s"
			% String(validation.get("error_id", &"UNKNOWN"))
		)
	return (
		Dictionary(validation.snapshot).duplicate(true)
		if bool(validation.valid)
		else {}
	)


func _export_v5_placements() -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			record.is_empty()
			or record.placement_kind == PLACEMENT_KIND_FIXED
		):
			continue
		placements.append({
			"placement_id": placement_id,
			"definition_id": StringName(record.definition_id),
			"origin_cell": Vector2i(record.origin_cell),
			"lifecycle_state": StringName(record.lifecycle_state),
			"built_day": int(record.built_day),
			"disabled_until_day": int(record.disabled_until_day),
			"construction_started_day": int(
				record.construction_started_day
			),
			"construction_complete_day": int(
				record.construction_complete_day
			),
			"orientation": int(record.get("orientation", ORIENTATION_NORTH)),
			"construction_state": StringName(record.construction_state),
			"construction_progress_milliseconds": int(
				record.construction_progress_milliseconds
			),
			"construction_required_milliseconds": int(
				record.construction_required_milliseconds
			),
			"construction_total_costs": Dictionary(
				record.construction_total_costs
			).duplicate(true),
			"construction_paid_costs": Dictionary(
				record.construction_paid_costs
			).duplicate(true),
			"construction_priority": int(record.construction_priority),
			"construction_missing_resource_ids": Array(
				record.construction_missing_resource_ids
			).duplicate(),
		})
	return placements


func validate_v5_campaign_snapshot(
	snapshot: Dictionary
) -> Dictionary:
	var structural := V5CampaignSnapshot.validate_structure(
		snapshot,
		get_unit_definition_ids()
	)
	if not bool(structural.valid):
		return structural
	var candidate: Dictionary = structural.snapshot
	var war_probe: WarLoopState = WAR_LOOP_STATE.new()
	if not war_probe.restore_snapshot(candidate.war_loop):
		return {
			"valid": false,
			"error_id": &"INVALID_WAR_LOOP",
			"error": "WarLoop 快照无法恢复",
		}
	if not war_probe.active_siege.is_empty():
		var siege: Dictionary = war_probe.active_siege
		var siege_army: Dictionary = Dictionary(candidate.army_registry.armies_by_id).get(StringName(siege.get("army_id", &"")), {})
		if siege_army.is_empty() or StringName(siege_army.get("phase", &"")) != ArmyRegistry.PHASE_SIEGING or StringName(Dictionary(siege_army.get("macro_march", {})).get("order_id", &"")) != StringName(siege.get("order_id", &"")):
			return {
				"valid": false,
				"error_id": &"WAR_LOOP_ARMY_MISMATCH",
				"error": "攻城事务与军队快照不一致",
			}
	var population_probe := PopulationRecoveryState.new()
	if not population_probe.restore_snapshot(candidate.population_recovery):
		return {"valid": false, "error_id": &"INVALID_POPULATION_RECOVERY", "error": "人口恢复状态无法恢复"}
	var governance_probe := CityGovernanceState.new()
	if not governance_probe.restore_snapshot(candidate.city_governance):
		return {"valid": false, "error_id": &"INVALID_CITY_GOVERNANCE", "error": "城市治理状态无法恢复"}
	var strategy_probe := CityStrategyState.new()
	if not strategy_probe.restore_snapshot(candidate.city_strategy):
		return {"valid": false, "error_id": &"INVALID_CITY_STRATEGY", "error": "城市战略支持状态无法恢复"}
	var candidate_military := 0
	for count_value in Dictionary(Dictionary(candidate.garrison).get("unit_counts_by_definition_id", {})).values():
		candidate_military += int(count_value)
	for army_value in Dictionary(Dictionary(candidate.army_registry).get("armies_by_id", {})).values():
		var candidate_army: Dictionary = Dictionary(army_value)
		if StringName(candidate_army.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED:
			continue
		for count_value in Dictionary(candidate_army.get("units_by_definition_id", {})).values():
			candidate_military += int(count_value)
	var candidate_specialists := 0
	for specialist_value in war_probe.field_tactics.specialists_by_id.values():
		if bool(Dictionary(specialist_value).get("alive", false)):
			candidate_specialists += 1
	if not population_probe.invariant_matches(candidate_military, candidate_specialists):
		return {"valid": false, "error_id": &"POPULATION_CONSERVATION_FAILED", "error": "人口、驻军、外派军队与专家不守恒"}
	if population_probe.resident_sick > population_probe.total_living - population_probe.wounded - candidate_military - candidate_specialists:
		return {"valid": false, "error_id": &"DISEASE_POPULATION_MISMATCH", "error": "患病人口超过可归属居民"}
	var sequence_validation := _validate_battle_sequence_high_water(candidate)
	if not bool(sequence_validation.get("valid", false)):
		return sequence_validation
	var mainline: Dictionary = candidate.mainline_level
	if (
		StringName(mainline.level_id) != MAINLINE_PRESSURE_PROFILE.level_id
		or int(mainline.deadline_day) != MAINLINE_PRESSURE_PROFILE.deadline_day
		or (
			not bool(mainline.cleared)
			and StringName(mainline.pressure_stage_id)
				!= MAINLINE_PRESSURE_PROFILE.get_stage_id(
					int(candidate.city.current_day)
				)
		)
	):
		return {
			"valid": false,
			"error_id": &"MAINLINE_PROFILE_MISMATCH",
			"error": "CampaignSnapshot 主线配置与当前 M0 profile 不一致",
		}
	var selected_general := StringName(
		candidate.city.selected_general_id
	)
	if (
		selected_general != &""
		and not _generals_by_id.has(selected_general)
	):
		return {
			"valid": false,
			"error_id": &"UNKNOWN_GENERAL",
			"error": "V2 引用未知将领",
		}
	for tech_id_value in candidate.city.researched_tech_ids:
		if not _tech_by_id.has(StringName(tech_id_value)):
			return {
				"valid": false,
				"error_id": &"UNKNOWN_TECH",
				"error": "V2 引用未知科技",
			}
	for placement_value in candidate.placements:
		var placement: Dictionary = placement_value
		if get_definition(StringName(placement.definition_id)) == null:
			return {
				"valid": false,
				"error_id": &"UNKNOWN_BUILDING",
				"error": "V2 引用未知建筑",
			}
	if (
		StringName(candidate.build_slot.definition_id) != &""
		and get_definition(StringName(candidate.build_slot.definition_id)) == null
	):
		return {
			"valid": false,
			"error_id": &"UNKNOWN_BUILD_SLOT_DEFINITION",
			"error": "建造位引用未知建筑",
		}
	var garrison_total := 0
	for count in Dictionary(
		candidate.garrison.unit_counts_by_definition_id
	).values():
		garrison_total += int(count)
	var queued_total := 0
	for order in Dictionary(
		candidate.training_queue.orders_by_id
	).values():
		if StringName(order.phase) == TrainingQueue.PHASE_QUEUED:
			queued_total += int(order.quantity)
	var command_limit := int(candidate.city.recruitment_cap)
	if selected_general != &"":
		command_limit = int(
			_generals_by_id[selected_general].command_limit
		)
	if garrison_total + queued_total > command_limit:
		return {
			"valid": false,
			"error_id": &"COMMAND_LIMIT_CONSERVATION",
			"error": "V2 驻军与训练队列超过指挥上限",
		}
	var attempt: Dictionary = candidate.expedition_attempt
	if not attempt.is_empty():
		var is_defense_attempt := StringName(attempt.get("source_id", &"FIRST_WAR")) == BattleRequest.SOURCE_WARTIME_DEFENSE
		if (
			(is_defense_attempt and int(attempt.food_cost) != 0)
			or (not is_defense_attempt and int(attempt.food_cost) != get_first_war_food_cost(int(attempt.committed_total)))
		):
			return {
				"valid": false,
				"error_id": &"EXPEDITION_FOOD_COST_MISMATCH",
				"error": "出征粮草不符合当前唯一公式",
			}
		var attempt_id_text := String(attempt.attempt_id)
		var sequence_prefix := "defense-" if is_defense_attempt else "battle-"
		var sequence_text := attempt_id_text.trim_prefix(sequence_prefix)
		if (
			not attempt_id_text.begins_with(sequence_prefix)
			or not sequence_text.is_valid_int()
			or int(sequence_text) <= 0
			or attempt_id_text != "%s%06d" % [sequence_prefix, int(sequence_text)]
			or int(candidate.settlement_ledger.next_battle_transaction_sequence)
				<= int(sequence_text)
		):
			return {
				"valid": false,
				"error_id": &"EXPEDITION_SEQUENCE_MISMATCH",
				"error": "出征尝试序列未保持单调",
			}
		var roster: Dictionary = candidate.garrison.formations_by_id
		for selected_value in attempt.selected_formations:
			var selected: Dictionary = selected_value
			var canonical: Dictionary = roster.get(StringName(selected.formation_id), {})
			if (
				canonical.is_empty()
				or str(selected.display_name) != str(canonical.display_name)
				or StringName(selected.definition_id) != StringName(canonical.definition_id)
				or int(selected.max_members) != int(canonical.max_members)
			):
				return {
					"valid": false,
					"error_id": &"EXPEDITION_ROSTER_IDENTITY_MISMATCH",
					"error": "出征编队身份偏离永久 roster",
				}
		var active_session_snapshot: Dictionary = Dictionary(
			attempt.get("battle_session_snapshot", {})
		)
		if not active_session_snapshot.is_empty():
			if StringName(attempt.get("phase", &"")) not in [
				BATTLE_PHASE_ACTIVE,
				BATTLE_PHASE_RESULT_PENDING,
			]:
				return {
					"valid": false,
					"error_id": &"BATTLE_SESSION_PHASE_MISMATCH",
					"error": "战斗会话快照只能附着于活动出征",
				}
			var request := get_durable_battle_request(attempt)
			# RESULT_PENDING preserves the last non-terminal simulation snapshot
			# separately from its terminal authority record. Validate that snapshot
			# under the ACTIVE request it was created with; the terminal record is
			# checked by V5CampaignSnapshot itself.
			if request != null and request.phase == BattleRequest.PHASE_RESULT_PENDING:
				request.phase = BattleRequest.PHASE_ACTIVE
			var session_probe := BattleSession.new(request)
			if request == null or not session_probe.restore_snapshot(active_session_snapshot):
				return {
					"valid": false,
					"error_id": &"INVALID_BATTLE_SESSION_SNAPSHOT",
					"error": "活动战时实例快照非法",
				}
		if bool(attempt.settled):
			var summary: Dictionary = Dictionary(
				candidate.settlement_ledger.committed_results_by_id
			).get(StringName(attempt.result_id), {})
			var settlement_validation := (
				_validate_applied_expedition_summary(candidate, attempt, summary)
			)
			if not bool(settlement_validation.get("valid", false)):
				return settlement_validation
	return structural


func _validate_battle_sequence_high_water(
	candidate: Dictionary
) -> Dictionary:
	var ledger: Dictionary = candidate.settlement_ledger
	var next_sequence := int(ledger.next_battle_transaction_sequence)
	var transaction_ids: Dictionary = {}
	for transaction_id_value in Dictionary(
		ledger.closed_transactions_by_id
	).keys():
		transaction_ids[StringName(transaction_id_value)] = true
	for summary_value in Dictionary(ledger.committed_results_by_id).values():
		if summary_value is Dictionary:
			var transaction_id := StringName(
				Dictionary(summary_value).get("transaction_id", &"")
			)
			if transaction_id != &"":
				transaction_ids[transaction_id] = true
	for transaction_id_value in transaction_ids:
		var transaction_text := String(transaction_id_value)
		if not transaction_text.begins_with("battle-"):
			continue
		var sequence_text := transaction_text.trim_prefix("battle-")
		if (
			not sequence_text.is_valid_int()
			or int(sequence_text) <= 0
			or transaction_text != "battle-%06d" % int(sequence_text)
			or next_sequence <= int(sequence_text)
		):
			return {
				"valid": false,
				"error_id": &"BATTLE_SEQUENCE_HIGH_WATER_MISMATCH",
				"error": "战斗事务序列低于已提交历史",
			}
	return {"valid": true, "error_id": &"", "error": ""}


func _validate_applied_expedition_summary(
	candidate: Dictionary,
	attempt: Dictionary,
	summary: Dictionary
) -> Dictionary:
	var result_id := StringName(attempt.get("result_id", &""))
	var attempt_id := StringName(attempt.get("attempt_id", &""))
	var fact: Dictionary = summary.get("battle_fact_snapshot", {})
	var battle_result := BattleResult.from_authority_snapshot(fact)
	var committed := CommittedForceSnapshot.from_dictionary(
		Dictionary(attempt.get("committed_force_snapshot", {}))
	)
	var enemy := EnemyForceSnapshot.from_dictionary(
		Dictionary(attempt.get("enemy_force_snapshot", {}))
	)
	if (
		summary.is_empty()
		or result_id == &""
		or result_id != StringName("%s-result-001" % String(attempt_id))
		or StringName(summary.get("result_id", &"")) != result_id
		or StringName(summary.get("transaction_id", &"")) != attempt_id
		or StringName(summary.get("level_id", &""))
			!= StringName(attempt.get("mainline_id", &""))
		or fact.is_empty()
		or battle_result == null
		or not battle_result.is_consistent()
		or battle_result.get_authority_snapshot() != fact
		or battle_result.result_id != result_id
		or battle_result.transaction_id != attempt_id
		or battle_result.level_id != StringName(attempt.get("mainline_id", &""))
		or battle_result.started_day != int(attempt.get("created_day", 0))
		or committed == null
		or enemy == null
		or battle_result.player_snapshot_digest != committed.get_digest()
		or battle_result.enemy_snapshot_digest != enemy.get_digest()
		or battle_result.committed_count
			!= int(attempt.get("committed_total", 0))
		or int(summary.get("committed_count", -1))
			!= battle_result.committed_count
		or int(summary.get("survivor_count", -1))
			!= battle_result.survivor_count
		or int(summary.get("casualty_count", -1))
			!= battle_result.casualty_count
		or StringName(summary.get("outcome", &""))
			!= BattleOutcome.to_id(battle_result.outcome)
		or int(summary.get("actual_food_cost", -1))
			!= int(attempt.get("food_cost", -1))
		or not bool(summary.get("food_already_committed", false))
		or Array(summary.get("formation_results", []))
			!= battle_result.formation_results
	):
		return {
			"valid": false,
			"error_id": &"EXPEDITION_SETTLEMENT_FACT_MISMATCH",
			"error": "已结算出征与终局事实不一致",
		}
	var departures_by_id: Dictionary = {}
	for departure_value in Array(attempt.get("selected_formations", [])):
		var departure: Dictionary = departure_value
		departures_by_id[StringName(departure.formation_id)] = departure
	var seen_results: Dictionary = {}
	for formation_result_value in battle_result.formation_results:
		var formation_result: Dictionary = formation_result_value
		var formation_id := StringName(
			formation_result.get("formation_id", &"")
		)
		var departure: Dictionary = departures_by_id.get(formation_id, {})
		if (
			departure.is_empty()
			or seen_results.has(formation_id)
			or int(formation_result.get("squad_id", 0))
				!= int(departure.get("squad_id", 0))
			or int(formation_result.get("departure_count", -1))
				!= int(departure.get("member_count", -1))
		):
			return {
				"valid": false,
				"error_id": &"EXPEDITION_SETTLEMENT_ROSTER_MISMATCH",
				"error": "已结算出征的逐编队事实不完整",
			}
		seen_results[formation_id] = true
	if seen_results.size() != departures_by_id.size():
		return {
			"valid": false,
			"error_id": &"EXPEDITION_SETTLEMENT_ROSTER_MISMATCH",
			"error": "已结算出征缺少参战编队结果",
		}
	# A gate-defense result belongs to its dedicated mission, not the ordinary
	# first-war pressure level. Only FIRST_WAR may make the mainline-cleared
	# fact agree with its own victory; applying a defense victory must preserve
	# whatever mainline fact was already saved.
	var is_first_war_attempt := StringName(
		attempt.get("source_id", &"FIRST_WAR")
	) == &"FIRST_WAR"
	var victory := battle_result.outcome == BattleOutcome.Value.VICTORY
	if is_first_war_attempt and bool(candidate.mainline_level.cleared) != victory:
		return {
			"valid": false,
			"error_id": &"EXPEDITION_MAINLINE_OUTCOME_MISMATCH",
			"error": "主线完成状态与出征结果不一致",
		}
	return {"valid": true, "error_id": &"", "error": ""}


func migrate_v1_snapshot_to_v5(
	v1_snapshot: Dictionary
) -> Dictionary:
	return V5CampaignSnapshot.migrate_v1(
		v1_snapshot,
		Callable(self, "validate_early_city_snapshot"),
		Callable(self, "validate_v5_campaign_snapshot"),
		INFANTRY_ROLE.role_id,
		INFANTRY_ROLE.recruit_food_per_unit
	)


func restore_v5_campaign_snapshot(
	snapshot: Dictionary
) -> Dictionary:
	if _active_city_id != CITY_LAYOUT_PROFILE_RESOLVER.BLACKSTONE_CITY_ID:
		return {
			"success": false,
			"error_id": &"CITY_SAVE_SCOPE",
			"error": "河湾城暂不支持 V5 单城存档写入",
		}
	if (
		not _active_battle_reservation.is_empty()
		or not _active_army_dispatch_reservation.is_empty()
		or not _active_army_encounter.is_empty()
	):
		return {
			"success": false,
			"error_id": &"LIVE_TRANSACTION",
			"error": "存在活动事务，拒绝恢复",
		}
	var validation := validate_v5_campaign_snapshot(snapshot)
	if not bool(validation.valid):
		return {
			"success": false,
			"error_id": validation.error_id,
			"error": validation.error,
		}
	var rollback := export_v5_campaign_snapshot()
	if rollback.is_empty():
		return {
			"success": false,
			"error_id": &"ROLLBACK_CAPTURE_FAILED",
			"error": "无法捕获 V5 恢复前状态",
		}
	var applied := _apply_validated_v5_campaign_snapshot(
		validation.snapshot,
		true
	)
	if not bool(applied.success):
		_force_reset_runtime_projection()
		var rollback_result := _apply_validated_v5_campaign_snapshot(
			rollback,
			false
		)
		if not bool(rollback_result.success):
			push_error("V5 restore and rollback both failed")
			return {
				"success": false,
				"error_id": &"ROLLBACK_FAILED",
				"error": "V5 恢复失败且回滚失败",
			}
		return applied
	var postcondition := export_v5_campaign_snapshot()
	if postcondition != validation.snapshot:
		_force_reset_runtime_projection()
		var postcondition_rollback := (
			_apply_validated_v5_campaign_snapshot(rollback, false)
		)
		if not bool(postcondition_rollback.success):
			push_error("V5 postcondition rollback failed")
			return {
				"success": false,
				"error_id": &"ROLLBACK_FAILED",
				"error": "V5 核对失败且回滚失败",
			}
		return {
			"success": false,
			"error_id": &"POSTCONDITION_FAILED",
			"error": "V5 恢复后核对失败，已回滚",
		}
	_refresh_city_ui()
	city_state_changed.emit()
	return {
		"success": true,
		"error_id": &"",
		"error": "",
	}


func _apply_validated_v5_campaign_snapshot(
	snapshot: Dictionary,
	allow_test_failure: bool
) -> Dictionary:
	var city: Dictionary = snapshot.city
	var queue: Dictionary = snapshot.training_queue
	var active_order_id := StringName(queue.active_order_id)
	var active_order: Dictionary = (
		Dictionary(queue.orders_by_id).get(active_order_id, {})
	)
	var garrison_counts: Dictionary = (
		snapshot.garrison.unit_counts_by_definition_id
	)
	var compatibility_placements: Array[Dictionary] = []
	var orientations_by_placement_id: Dictionary = {}
	var construction_by_placement_id: Dictionary = {}
	for placement_value in snapshot.placements:
		var persisted_placement: Dictionary = placement_value
		var placement_id := int(persisted_placement.placement_id)
		orientations_by_placement_id[placement_id] = int(
			persisted_placement.get("orientation", ORIENTATION_NORTH)
		)
		construction_by_placement_id[placement_id] = {
			"construction_state": StringName(persisted_placement.construction_state),
			"construction_progress_milliseconds": int(persisted_placement.construction_progress_milliseconds),
			"construction_required_milliseconds": int(persisted_placement.construction_required_milliseconds),
			"construction_total_costs": Dictionary(persisted_placement.construction_total_costs).duplicate(true),
			"construction_paid_costs": Dictionary(persisted_placement.construction_paid_costs).duplicate(true),
			"construction_priority": int(persisted_placement.construction_priority),
			"construction_missing_resource_ids": Array(persisted_placement.construction_missing_resource_ids).duplicate(),
		}
		var legacy_placement := persisted_placement.duplicate(true)
		for key in [
			"orientation",
			"construction_state",
			"construction_progress_milliseconds",
			"construction_required_milliseconds",
			"construction_total_costs",
			"construction_paid_costs",
			"construction_priority",
			"construction_missing_resource_ids",
		]:
			legacy_placement.erase(key)
		compatibility_placements.append(legacy_placement)
	var compatibility_snapshot := {
		"city": {
			"current_day": int(city.current_day),
			"day_elapsed_seconds": (
				float(city.day_elapsed_milliseconds) / 1000.0
			),
			"wood": int(city.wood),
			"food": int(city.food),
			"tech_points": int(city.tech_points),
			"infantry_count": int(
				garrison_counts.get(INFANTRY_ROLE.role_id, 0)
			),
			"recruitment_cap": int(city.recruitment_cap),
			"selected_general_id": StringName(
				city.selected_general_id
			),
			"training_queued_count": int(
				active_order.get("quantity", 0)
			),
			"training_complete_day": int(
				active_order.get("complete_day", 0)
			),
			"last_training_order_day": int(
				queue.last_order_day
			),
			"researched_tech_ids": (
				city.researched_tech_ids.duplicate()
			),
			"supply_shortage": bool(city.supply_shortage),
			"emergency_mobilization_used": bool(
				city.emergency_mobilization_used
			),
			"city_time_paused": bool(city.city_time_paused),
			"city_time_speed": float(
				String(city.city_time_speed_id).trim_suffix("x")
			),
		},
		"placements": compatibility_placements,
		"next_placement_id": int(snapshot.next_placement_id),
	}
	var clear_result := _clear_runtime_placements_for_snapshot_restore()
	if not bool(clear_result.success):
		return {
			"success": false,
			"error_id": &"CITY_CLEAR_FAILED",
			"error": clear_result.error,
		}
	var city_install := _install_early_city_snapshot(
		compatibility_snapshot,
		orientations_by_placement_id
	)
	if not bool(city_install.success):
		return {
			"success": false,
			"error_id": &"CITY_APPLY_FAILED",
			"error": city_install.error,
		}
	if not _garrison_state.restore_persistence_snapshot(snapshot.garrison):
		return {
			"success": false,
			"error_id": &"GARRISON_APPLY_FAILED",
			"error": "永久编队 roster 恢复失败",
		}
	for placement_id in construction_by_placement_id:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty():
			return {
				"success": false,
				"error_id": &"CONSTRUCTION_APPLY_FAILED",
				"error": "施工状态 placement 缺失",
			}
		record.merge(construction_by_placement_id[placement_id], true)
	city_security = int(city.security)
	var restored_mainline := CURRENT_MAINLINE_LEVEL.new(MAINLINE_PRESSURE_PROFILE)
	if not restored_mainline.restore_snapshot(snapshot.mainline_level):
		return {
			"success": false,
			"error_id": &"MAINLINE_APPLY_FAILED",
			"error": "主线压力状态恢复失败",
		}
	_current_mainline_level = restored_mainline
	_next_placement_id = int(snapshot.next_placement_id)
	if (
		allow_test_failure
		and _v5_restore_failure_after_city_install_for_test
	):
		return {
			"success": false,
			"error_id": &"APPLY_FAILED",
			"error": "注入 V5 apply failure",
		}
	if not _training_queue.restore_snapshot(snapshot.training_queue):
		return {
			"success": false,
			"error_id": &"TRAINING_APPLY_FAILED",
			"error": "TrainingQueue 恢复失败",
		}
	if not _army_registry.restore_snapshot(
		snapshot.army_registry,
		get_unit_definition_ids()
	):
		return {
			"success": false,
			"error_id": &"ARMY_APPLY_FAILED",
			"error": "ArmyRegistry 恢复失败",
		}
	if not _war_loop_state.restore_snapshot(snapshot.war_loop):
		return {
			"success": false,
			"error_id": &"WAR_LOOP_APPLY_FAILED",
			"error": "WarLoop 状态恢复失败",
		}
	# Specialist path migration needs the Resource-owned water and bridge facts.
	# Restore installs state first; this initializes that same authority before
	# any migrated route can be queried or advanced.
	_ensure_war_loop_initialized()
	if not _population_recovery.restore_snapshot(snapshot.population_recovery):
		return {
			"success": false,
			"error_id": &"POPULATION_RECOVERY_APPLY_FAILED",
			"error": "人口与恢复状态恢复失败",
		}
	if not _city_governance.restore_snapshot(snapshot.city_governance):
		return {
			"success": false,
			"error_id": &"CITY_GOVERNANCE_APPLY_FAILED",
			"error": "城市治理状态恢复失败",
		}
	if not _city_strategy.restore_snapshot(snapshot.city_strategy):
		return {"success": false, "error_id": &"CITY_STRATEGY_APPLY_FAILED", "error": "城市战略支持状态恢复失败"}
	if not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		return {
			"success": false,
			"error_id": &"POPULATION_CONSERVATION_FAILED",
			"error": "恢复后人口分配不守恒",
		}
	var ledger: Dictionary = snapshot.settlement_ledger
	_committed_battle_result_ids = Dictionary(
		ledger.committed_results_by_id
	).duplicate(true)
	_closed_battle_transactions = Dictionary(
		ledger.closed_transactions_by_id
	).duplicate(true)
	_first_clear_keys = Dictionary(ledger.first_clear_keys).duplicate(true)
	_completed_noticeboard_mission_ids = Dictionary(
		ledger.completed_noticeboard_mission_ids
	).duplicate(true)
	_next_battle_transaction_sequence = int(
		ledger.next_battle_transaction_sequence
	)
	_next_army_dispatch_transaction_sequence = int(
		ledger.next_army_dispatch_transaction_sequence
	)
	_expedition_attempt = Dictionary(snapshot.expedition_attempt).duplicate(true)
	_active_battle_reservation = {}
	if (
		not _expedition_attempt.is_empty()
		and StringName(_expedition_attempt.phase) in [
			BATTLE_PHASE_RESERVED,
			BATTLE_PHASE_ACTIVE,
			BATTLE_PHASE_RESULT_PENDING,
		]
	):
		_active_battle_reservation = {
			"transaction_id": StringName(_expedition_attempt.attempt_id),
			"committed_count": int(_expedition_attempt.committed_total),
			"phase": StringName(_expedition_attempt.phase),
		}
	_active_army_dispatch_reservation = {}
	_active_army_encounter = {}
	_last_battle_result_summary = {}
	if (
		not _expedition_attempt.is_empty()
		and bool(_expedition_attempt.get("settled", false))
	):
		_last_battle_result_summary = Dictionary(
			_committed_battle_result_ids.get(
				StringName(_expedition_attempt.get("result_id", &"")),
				{}
			)
		).duplicate(true)
	_restore_first_war_runtime_from_persistence()
	_build_slot = Dictionary(snapshot.build_slot).duplicate(true)
	state = ConstructionState.IDLE
	_selected_definition = null
	preview_orientation = int(_build_slot.get("orientation", ORIENTATION_NORTH))
	construction_preview.visible = false
	preview_valid = false
	preview_invalid_reason = ""
	preview_connection_state = &"not_required"
	preview_entrance_info = {}
	preview_entrance_marker.visible = false
	preview_conflict_mark.visible = false
	_reset_road_draft()
	scan_current_placement_overlaps(true)
	return {"success": true, "error_id": &"", "error": ""}


## First-war UI/runtime flags are projections, not a second persisted authority.
## Rebuild them from the V6 expedition attempt and the persisted mainline so a
## cold process cannot reopen a cleared pressure state or forget an active run.
func _restore_first_war_runtime_from_persistence() -> void:
	_first_war_pending_outcome = &""
	_first_war_result_acknowledged = false
	city_fallen = false
	# City-defense pressure damage lives with the persisted mainline. Battle
	# damage is recorded in the applied result summary. Rebuild the aggregate
	# runtime projection here instead of inheriting whatever value happened to
	# be present before hydration.
	city_defense_damage = int(
		_current_mainline_level.permanent_losses.get(
			"city_defense_damage",
			0
		)
	)
	if _expedition_attempt.is_empty():
		if _current_mainline_level.cleared:
			first_war_state = FirstWarState.RESOLVED_VICTORY
			_first_war_result_acknowledged = true
			enemy_count = 0
		else:
			first_war_state = FirstWarState.PREPARATION
			_update_first_war_state_for_current_day()
		return
	if StringName(_expedition_attempt.get("source_id", &"FIRST_WAR")) == BattleRequest.SOURCE_WARTIME_DEFENSE:
		if not _last_battle_result_summary.is_empty():
			city_defense_damage += int(
				_last_battle_result_summary.get("city_defense_damage", 0)
			)
			city_fallen = StringName(
				_last_battle_result_summary.get("outcome", &"")
			) == &"DEFEAT"
		if _current_mainline_level.cleared:
			first_war_state = FirstWarState.RESOLVED_VICTORY
			_first_war_result_acknowledged = true
		else:
			first_war_state = FirstWarState.PREPARATION
			_update_first_war_state_for_current_day()
		return
	var phase := StringName(_expedition_attempt.get("phase", &""))
	var persisted_enemy := EnemyForceSnapshot.from_dictionary(
		Dictionary(_expedition_attempt.get("enemy_force_snapshot", {}))
	)
	if persisted_enemy != null:
		enemy_count = persisted_enemy.enemy_count
		enemy_fortification = persisted_enemy.fortification_level
	if phase in [BATTLE_PHASE_RESERVED, BATTLE_PHASE_ACTIVE]:
		first_war_state = FirstWarState.IN_BATTLE
		return
	var outcome := StringName(
		_last_battle_result_summary.get("outcome", &"")
	)
	city_defense_damage += int(
		_last_battle_result_summary.get("city_defense_damage", 0)
	)
	enemy_count = int(
		_last_battle_result_summary.get("enemy_count_after", enemy_count)
	)
	_first_war_result_acknowledged = true
	match outcome:
		&"VICTORY":
			first_war_state = FirstWarState.RESOLVED_VICTORY
		&"RETREAT":
			first_war_state = FirstWarState.RESOLVED_RETREAT
		&"DEFEAT":
			first_war_state = FirstWarState.RESOLVED_DEFEAT
			city_fallen = true
		_:
			# Structural validation should make this unreachable. Keep a safe
			# non-playable projection rather than inventing a fresh battle state.
			first_war_state = FirstWarState.IN_BATTLE


func set_v5_restore_failure_after_city_install_for_test(
	enabled: bool
) -> void:
	_v5_restore_failure_after_city_install_for_test = enabled


func validate_early_city_snapshot(snapshot: Dictionary) -> Dictionary:
	var structural := EARLY_CITY_SNAPSHOT_V1.validate_structure(snapshot)
	if not bool(structural.valid):
		return structural
	var normalized: Dictionary = structural.snapshot
	var fixed_occupied_cells: Dictionary = {}
	var fixed_placement_ids: Dictionary = {}
	var max_fixed_placement_id := 0
	for placement_id in _placement_order:
		var fixed_record: Dictionary = _building_records_by_id.get(
			placement_id,
			{}
		)
		if (
			fixed_record.is_empty()
			or fixed_record.placement_kind != PLACEMENT_KIND_FIXED
		):
			continue
		fixed_placement_ids[placement_id] = true
		max_fixed_placement_id = maxi(max_fixed_placement_id, placement_id)
		for cell in fixed_record.occupied_footprint_cells:
			fixed_occupied_cells[Vector2i(cell)] = placement_id
	var map_grid_size := Vector2i(
		floori(map_board.size.x / GRID_SIZE),
		floori(map_board.size.y / GRID_SIZE)
	)
	return EARLY_CITY_SNAPSHOT_V1.validate_with_context(normalized, {
		"city_id": EARLY_CITY_SNAPSHOT_V1.CITY_ID,
		"definitions_by_id": _definitions_by_id,
		"generals_by_id": _generals_by_id,
		"tech_by_id": _tech_by_id,
		"fixed_occupied_cells": fixed_occupied_cells,
		"fixed_placement_ids": fixed_placement_ids,
		"max_fixed_placement_id": max_fixed_placement_id,
		"map_grid_size": map_grid_size,
		"base_resource_capacity": BASE_RESOURCE_CAPACITY,
		"threat_schedule": FIRST_MAP_THREAT_SCHEDULE,
		"road_root_cells": city_spatial_foundation.get_road_root_cells(),
		"formal_road_cells": city_spatial_foundation.get_formal_road_cells(),
		"seconds_per_day": SECONDS_PER_DAY,
		"allowed_time_speeds": CITY_TIME_SPEEDS,
		"allowed_training_batches": (
			_get_allowed_training_batches_for_snapshot(
				normalized.city.researched_tech_ids
			)
		),
	})


func restore_early_city_snapshot(snapshot: Dictionary) -> Dictionary:
	if _active_city_id != CITY_LAYOUT_PROFILE_RESOLVER.BLACKSTONE_CITY_ID:
		return {
			"success": false,
			"error": "河湾城暂不支持旧版单城存档恢复",
		}

	var scope_error := _get_early_city_snapshot_scope_error()
	if not scope_error.is_empty():
		return {
			"success": false,
			"error": "当前城市不可恢复：%s" % scope_error,
		}
	var validation := validate_early_city_snapshot(snapshot)
	if not bool(validation.valid):
		return {
			"success": false,
			"error": str(validation.error),
		}
	var rollback_snapshot := export_early_city_snapshot()
	if rollback_snapshot.is_empty():
		return {
			"success": false,
			"error": "无法捕获恢复前城市状态",
		}
	var apply_result := _apply_validated_early_city_snapshot(validation)
	if not bool(apply_result.success):
		var rollback_result := _rollback_early_city_snapshot(
			rollback_snapshot
		)
		if not bool(rollback_result.success):
			push_error(
				"S1A.1 restore failed and rollback failed: %s / %s"
				% [apply_result.error, rollback_result.error]
			)
			return {
				"success": false,
				"error": "恢复失败且旧状态回滚失败：%s" % (
					rollback_result.error
				),
			}
		_refresh_city_ui()
		city_state_changed.emit()
		return {
			"success": false,
			"error": str(apply_result.error),
		}
	for removed_placement_id in apply_result.removed_placement_ids:
		building_removed.emit(int(removed_placement_id))
	cancel_build_interaction()
	last_daily_breakdown = {
		"maintenance_food": 0,
		"maintenance_required": 0,
		"training_completed": 0,
		"construction_completed": 0,
		"wood_income": 0,
		"food_income": 0,
		"research_income": 0,
		"event_wood_loss": 0,
		"event_food_loss": 0,
		"stopped_placement_id": -1,
	}
	last_daily_report = "已恢复 S1A.1 内存快照"
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "error": ""}


func _get_early_city_snapshot_scope_error() -> String:
	if current_day < 1 or current_day >= FIRST_WAR_PENDING_DAY:
		return "只支持第 1 至第 6 日的早期城市状态"
	if first_war_state not in [
		FirstWarState.PREPARATION,
		FirstWarState.WARNING,
	]:
		return "首战状态已超出早期城市范围"
	if (
		not _active_battle_reservation.is_empty()
		or not _closed_battle_transactions.is_empty()
		or not _committed_battle_result_ids.is_empty()
		or not _first_clear_keys.is_empty()
		or not _last_battle_result_summary.is_empty()
		or _first_war_pending_outcome != &""
		or _first_war_result_acknowledged
		or is_instance_valid(_formal_battle_scene)
	):
		return "存在战斗事务或战果"
	if (
		_active_noticeboard_mission_id != &""
		or not _completed_noticeboard_mission_ids.is_empty()
		or not _noticeboard_last_result_summary.is_empty()
	):
		return "存在告示板任务状态"
	if not _readiness_checkpoint.is_empty():
		return "存在战备检查点"
	if city_fallen or city_defense_damage != 0:
		return "存在战败或城防损伤状态"
	if _next_battle_transaction_sequence != 1:
		return "战斗事务序号已变化"
	var placement_integrity_error := _get_placement_integrity_error()
	if not placement_integrity_error.is_empty():
		return placement_integrity_error
	if (
		current_day < FIRST_WAR_WARNING_DAY
		and (
			first_war_state != FirstWarState.PREPARATION
			or first_war_warning_count != 0
		)
	):
		return "首战准备状态与日期不一致"
	if (
		current_day == FIRST_WAR_WARNING_DAY
		and (
			first_war_state != FirstWarState.WARNING
			or first_war_warning_count != 1
		)
	):
		return "首战预警状态与日期不一致"
	return ""


func _get_placement_integrity_error() -> String:
	var expected_occupancy: Dictionary = {}
	var seen_ids: Dictionary = {}
	for placement_id in _placement_order:
		if seen_ids.has(placement_id):
			return "placement 顺序包含重复 ID"
		seen_ids[placement_id] = true
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty():
			return "placement 顺序引用缺失记录"
		var building := record.get("node") as CanvasItem
		if not is_instance_valid(building):
			return "placement 记录引用无效节点"
		for cell in record.occupied_footprint_cells:
			var typed_cell := Vector2i(cell)
			if expected_occupancy.has(typed_cell):
				return "当前 placement 记录互相重叠"
			expected_occupancy[typed_cell] = placement_id
	if seen_ids.size() != _building_records_by_id.size():
		return "权威记录包含未进入 placement 顺序的 ID"
	if expected_occupancy.size() != _occupied_cells.size():
		return "当前占用表与 placement 记录数量不一致"
	for cell in expected_occupancy:
		if _occupied_cells.get(cell, -1) != expected_occupancy[cell]:
			return "当前占用表所有权不一致"
	return ""


func _apply_validated_early_city_snapshot(
	validation: Dictionary
) -> Dictionary:
	var clear_result := _clear_runtime_placements_for_snapshot_restore()
	if not bool(clear_result.success):
		return clear_result
	var snapshot: Dictionary = validation.snapshot
	var install_result := _install_early_city_snapshot(snapshot)
	if not bool(install_result.success):
		return install_result
	var postcondition_error := _get_early_city_snapshot_postcondition_error(
		validation
	)
	if not postcondition_error.is_empty():
		return {
			"success": false,
			"error": "恢复后核对失败：%s" % postcondition_error,
		}
	return {
		"success": true,
		"error": "",
		"removed_placement_ids": (
			clear_result.removed_placement_ids.duplicate()
		),
	}


func _install_early_city_snapshot(
	snapshot: Dictionary,
	orientations_by_placement_id: Dictionary = {}
) -> Dictionary:
	var city: Dictionary = snapshot.city
	var legacy_resources := (
		V5_NATIONAL_RESOURCE_ADAPTER.extract_legacy_city_resources(city)
	)
	if (
		legacy_resources.is_empty()
		or not _replace_national_resources(
			legacy_resources,
			&"legacy_city_snapshot_hydration"
		)
	):
		return {
			"success": false,
			"error": "无法水合国家共享资源",
		}
	current_day = int(city.current_day)
	day_elapsed_seconds = float(city.day_elapsed_seconds)
	_city_frame_remainder_milliseconds = 0.0
	infantry_count = int(city.infantry_count)
	recruitment_cap = int(city.recruitment_cap)
	selected_general_id = StringName(city.selected_general_id)
	if not _restore_training_legacy_state(
		int(city.training_queued_count),
		int(city.training_complete_day),
		int(city.last_training_order_day)
	):
		return {
			"success": false,
			"error": "无法恢复训练队列",
		}
	researched_tech_ids.assign(city.researched_tech_ids)
	supply_shortage = bool(city.supply_shortage)
	emergency_mobilization_used = bool(city.emergency_mobilization_used)
	city_time_paused = bool(city.city_time_paused)
	city_time_speed = float(city.city_time_speed)
	var threat := EARLY_CITY_SNAPSHOT_V1.get_expected_threat(
		current_day,
		FIRST_MAP_THREAT_SCHEDULE
	)
	enemy_count = int(threat.enemy_count)
	enemy_fortification = int(threat.enemy_fortification)
	first_war_state = FirstWarState.PREPARATION
	first_war_warning_count = 0
	_update_first_war_state_for_current_day()
	for placement_value in snapshot.placements:
		var placement_id := int(placement_value.placement_id)
		if not _restore_runtime_placement_from_snapshot(
			placement_value,
			int(orientations_by_placement_id.get(placement_id, ORIENTATION_NORTH))
		):
			return {
				"success": false,
				"error": "无法安装 placement %d" % int(
					placement_value.placement_id
				),
			}
	_next_placement_id = int(snapshot.next_placement_id)
	return {"success": true, "error": ""}


func _clear_runtime_placements_for_snapshot_restore() -> Dictionary:
	var runtime_ids: Array[int] = []
	var removed_ids: Array[int] = []
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and record.placement_kind != PLACEMENT_KIND_FIXED
		):
			runtime_ids.append(placement_id)
	for placement_id in runtime_ids:
		var record: Dictionary = _building_records_by_id.get(
			placement_id,
			{}
		)
		var building := record.get("node") as Node2D
		if not _release_runtime_record(placement_id, true, false):
			return {
				"success": false,
				"error": "释放旧 placement %d 失败" % placement_id,
			}
		if is_instance_valid(building):
			if building.get_parent() == placed_buildings:
				placed_buildings.remove_child(building)
			building.queue_free()
		removed_ids.append(placement_id)
	return {
		"success": true,
		"error": "",
		"removed_placement_ids": removed_ids,
	}


func _restore_runtime_placement_from_snapshot(
	placement: Dictionary,
	orientation := ORIENTATION_NORTH
) -> bool:
	var placement_id := int(placement.placement_id)
	var definition := get_definition(StringName(placement.definition_id))
	var origin_cell := Vector2i(placement.origin_cell)
	return _register_runtime_placement_record(
		placement_id,
		origin_cell,
		definition,
		orientation,
		StringName(placement.lifecycle_state),
		int(placement.built_day),
		int(placement.disabled_until_day),
		int(placement.construction_started_day),
		int(placement.construction_complete_day),
	)


func _register_runtime_placement_record(
	placement_id: int,
	origin_cell: Vector2i,
	definition: BuildingDefinition,
	orientation: int,
	lifecycle_state: StringName,
	built_day: int,
	disabled_until_day: int,
	construction_started_day: int,
	construction_complete_day: int,
	construction_cost_enabled := false
) -> bool:
	if definition == null or _building_records_by_id.has(placement_id):
		return false
	var footprint := get_rotated_footprint(definition, orientation)
	if footprint == Vector2i.ZERO:
		return false
	var footprint_cells := get_footprint_cells(
		origin_cell,
		footprint
	)
	for cell in footprint_cells:
		if _occupied_cells.has(cell):
			return false
	var building := _create_placed_building_node(
		placement_id,
		origin_cell,
		definition,
		footprint,
		orientation
	)
	if (
		not is_instance_valid(building)
		or building.get_parent() != placed_buildings
	):
		if is_instance_valid(building):
			building.queue_free()
		return false
	var record := _base_record()
	var required_milliseconds := maxi(
		definition.build_days * MILLISECONDS_PER_DAY,
		0
	)
	var starts_completed := lifecycle_state != &"constructing"
	var total_costs: Dictionary = {}
	if construction_cost_enabled and definition.wood_cost > 0:
		total_costs[&"wood"] = definition.wood_cost
	if construction_cost_enabled and definition.food_cost > 0:
		total_costs[&"food"] = definition.food_cost
	var paid_costs: Dictionary = {}
	if starts_completed:
		paid_costs = total_costs.duplicate(true)
	record.merge({
		"placement_id": placement_id,
		"placement_kind": definition.placement_kind,
		"template_id": definition.definition_id,
		"definition_id": definition.definition_id,
		"display_name": definition.display_name,
		"building_type": definition.building_type,
		"description": definition.description,
		"origin_cell": origin_cell,
		"footprint": footprint,
		"base_footprint": definition.footprint,
		"orientation": orientation,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(
			Vector2.ZERO,
			Vector2(footprint) * GRID_SIZE
		),
		"lifecycle_state": lifecycle_state,
		"prototype_status": (
			"施工中"
			if lifecycle_state == &"constructing"
			else "运行中"
		),
		"selectable": true,
		"removable": true,
		"movable": definition.placement_kind == PLACEMENT_KIND_PLACED,
		"requires_road": definition.requires_road,
		"road_anchor_offsets": definition.road_anchor_offsets.duplicate(),
		"level": definition.level,
		"next_level_definition_id": definition.next_level_definition_id,
		"build_wood_cost": definition.wood_cost,
		"build_food_cost": definition.food_cost,
		"build_days": definition.build_days,
		"construction_started_day": construction_started_day,
		"construction_complete_day": construction_complete_day,
		"construction_state": &"COMPLETED" if starts_completed else &"ACTIVE",
		"construction_progress_milliseconds": (
			required_milliseconds if starts_completed else 0
		),
		"construction_required_milliseconds": required_milliseconds,
		"construction_total_costs": total_costs,
		"construction_paid_costs": paid_costs,
		"construction_priority": CONSTRUCTION_PRIORITY_NORMAL,
		"construction_missing_resource_ids": [],
		"built_day": built_day,
		"disabled_until_day": disabled_until_day,
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
	_refresh_placed_building_visual(placement_id)
	_refresh_road_visual_projection()
	return true


func _rollback_early_city_snapshot(snapshot: Dictionary) -> Dictionary:
	var validation := validate_early_city_snapshot(snapshot)
	if not bool(validation.valid):
		return {
			"success": false,
			"error": "回滚快照校验失败：%s" % validation.error,
		}
	_force_reset_runtime_projection()
	var install_result := _install_early_city_snapshot(validation.snapshot)
	if not bool(install_result.success):
		return {
			"success": false,
			"error": "回滚快照安装失败：%s" % install_result.error,
		}
	var postcondition_error := _get_early_city_snapshot_postcondition_error(
		validation
	)
	if not postcondition_error.is_empty():
		return {
			"success": false,
			"error": "回滚后核对失败：%s" % postcondition_error,
		}
	return {"success": true, "error": ""}


func _force_reset_runtime_projection() -> void:
	var runtime_nodes := placed_buildings.get_children()
	var fixed_records: Dictionary = {}
	var fixed_order: Array[int] = []
	var fixed_occupied: Dictionary = {}
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			record.is_empty()
			or record.placement_kind != PLACEMENT_KIND_FIXED
		):
			continue
		fixed_records[placement_id] = record
		fixed_order.append(placement_id)
		for cell in record.occupied_footprint_cells:
			fixed_occupied[Vector2i(cell)] = placement_id
	_building_records_by_id = fixed_records
	_placement_order.assign(fixed_order)
	_occupied_cells = fixed_occupied
	for child in runtime_nodes:
		if child.get_parent() == placed_buildings:
			placed_buildings.remove_child(child)
		child.queue_free()


func _get_early_city_snapshot_postcondition_error(
	validation: Dictionary
) -> String:
	var expected_snapshot: Dictionary = validation.snapshot
	if (
		str(expected_snapshot.city_id)
		!= EARLY_CITY_SNAPSHOT_V1.CITY_ID
	):
		return "城市身份不匹配"
	var integrity_error := _get_placement_integrity_error()
	if not integrity_error.is_empty():
		return integrity_error
	var actual_snapshot := export_early_city_snapshot()
	if actual_snapshot.is_empty():
		return "恢复后无法重新导出快照"
	if actual_snapshot != expected_snapshot:
		return "恢复后的权威源字段与候选状态不一致"

	var expected_ids: Dictionary = {}
	for placement_value in expected_snapshot.placements:
		expected_ids[int(placement_value.placement_id)] = true
	var node_id_counts: Dictionary = {}
	for child in placed_buildings.get_children():
		if not child.has_meta("placement_id"):
			return "运行时 placement 节点缺少 ID"
		var node_id := int(child.get_meta("placement_id"))
		node_id_counts[node_id] = int(node_id_counts.get(node_id, 0)) + 1
	if node_id_counts.size() != expected_ids.size():
		return "运行时 placement 节点数量不一致"
	for placement_id in expected_ids:
		if int(node_id_counts.get(placement_id, 0)) != 1:
			return "placement %d 的运行时节点不唯一" % placement_id
		var record: Dictionary = _building_records_by_id.get(
			placement_id,
			{}
		)
		var building := record.get("node") as Node2D
		if (
			not is_instance_valid(building)
			or building.get_parent() != placed_buildings
			or int(building.get_meta("placement_id", -1)) != placement_id
		):
			return "placement %d 的记录与节点不一致" % placement_id

	var derived: Dictionary = validation.derived
	if _occupied_cells != derived.occupied_cells:
		return "恢复后的 occupied cells 与候选派生结果不一致"
	if get_connected_road_cells() != derived.connected_road_cells:
		return "恢复后的道路连通与候选派生结果不一致"
	if (
		get_resource_capacity(&"wood") != int(derived.wood_capacity)
		or get_resource_capacity(&"food") != int(derived.food_capacity)
	):
		return "恢复后的资源容量与候选派生结果不一致"
	for placement_id in derived.operational_by_id:
		if (
			is_building_operational(placement_id)
			!= bool(derived.operational_by_id[placement_id])
		):
			return "placement %d 的启用状态不一致" % placement_id
	return ""


func is_city_action_locked_for_battle() -> bool:
	return (
		not _active_battle_reservation.is_empty()
		or not _active_army_encounter.is_empty()
		or is_first_war_time_blocked()
	)


func get_available_infantry_count() -> int:
	return maxi(
		infantry_count
		- int(_active_battle_reservation.get("committed_count", 0))
		- int(
			_active_army_dispatch_reservation.get(
				"committed_count",
				0
			)
		),
		0
	)


func get_dispatchable_infantry_count() -> int:
	return mini(
		get_available_infantry_count(),
		mini(recruitment_cap, get_effective_command_limit())
	)


func get_unit_definition_ids() -> Array[StringName]:
	return [INFANTRY_ROLE.role_id]


func get_unit_definition(
	definition_id: StringName
) -> UnitRole:
	if definition_id != INFANTRY_ROLE.role_id:
		return null
	return INFANTRY_ROLE


func get_garrison_snapshot() -> Dictionary:
	var force := get_first_war_force_breakdown()
	var snapshot := _garrison_state.get_snapshot()
	snapshot["definition_id"] = INFANTRY_ROLE.role_id
	snapshot["reserved_count"] = (
		int(force.battle_reserved_count)
		+ int(force.dispatch_reserved_count)
	)
	snapshot["battle_reserved_count"] = int(force.battle_reserved_count)
	snapshot["dispatch_reserved_count"] = int(force.dispatch_reserved_count)
	snapshot["city_defense_occupied_count"] = int(
		force.city_defense_occupied_count
	)
	snapshot["already_dispatched_count"] = int(force.already_dispatched_count)
	snapshot["injured_or_unavailable_count"] = int(
		force.injured_or_unavailable_count
	)
	snapshot["unreserved_count"] = int(force.available_count)
	snapshot["dispatchable_count"] = int(force.dispatchable_count)
	snapshot["recruitment_cap"] = recruitment_cap
	snapshot["effective_command_limit"] = int(force.effective_command_limit)
	return snapshot.duplicate(true)


func get_active_battle_reservation() -> Dictionary:
	return _active_battle_reservation.duplicate(true)


func get_expedition_attempt() -> Dictionary:
	return _expedition_attempt.duplicate(true)


func get_durable_battle_request(attempt_value: Dictionary = {}) -> BattleRequest:
	var attempt := (
		attempt_value
		if not attempt_value.is_empty()
		else _expedition_attempt
	)
	if attempt.is_empty():
		return null
	var mission: MissionDefinition = (
		WARTIME_DEFENSE_MISSION
		if StringName(attempt.get("source_id", &"FIRST_WAR"))
			== BattleRequest.SOURCE_WARTIME_DEFENSE
		else null
	)
	return BattleRequest.from_expedition_attempt(attempt, mission)


func has_resumable_expedition() -> bool:
	return (
		not _expedition_attempt.is_empty()
		and not bool(_expedition_attempt.get("settled", false))
		and StringName(_expedition_attempt.get("phase", &"")) in [
			BATTLE_PHASE_RESERVED,
			BATTLE_PHASE_ACTIVE,
			BATTLE_PHASE_RESULT_PENDING,
		]
		and not is_instance_valid(_formal_battle_scene)
	)


func resume_persisted_expedition() -> bool:
	if not has_resumable_expedition():
		return false
	return _launch_active_expedition_battle()


func _is_durable_expedition_reservation() -> bool:
	return (
		not _expedition_attempt.is_empty()
		and not _active_battle_reservation.is_empty()
		and StringName(_expedition_attempt.get("attempt_id", &""))
			== StringName(_active_battle_reservation.get("transaction_id", &""))
		and int(_expedition_attempt.get("committed_total", 0))
			== int(_active_battle_reservation.get("committed_count", 0))
		and StringName(_expedition_attempt.get("phase", &""))
			in [BATTLE_PHASE_RESERVED, BATTLE_PHASE_ACTIVE, BATTLE_PHASE_RESULT_PENDING]
	)


func get_v5_army_dispatch_adapter() -> V5ArmyDispatchAdapter:
	if _army_dispatch_adapter == null:
		_army_dispatch_adapter = V5_ARMY_DISPATCH_ADAPTER.new()
		_army_dispatch_adapter.configure(self)
	return _army_dispatch_adapter


func get_macro_march_read_model() -> Dictionary:
	_ensure_war_loop_initialized()
	var macro_army := get_macro_march_army()
	var macro_armies := get_macro_march_armies()
	return {
		"army": macro_army,
		"armies": macro_armies,
		"formations": _garrison_state.get_formations(),
		"food": food,
		"maintenance_units_per_food": INFANTRY_ROLE.maintenance_units_per_food,
		"paused": city_time_paused,
		"speed": city_time_speed,
		"blocked_route_ids": _macro_march_blocked_route_ids.duplicate(),
		"runtime_points": _war_loop_state.field_tactics.get_runtime_points(),
		"source_point_id": (
			StringName(macro_army.target_node_id)
			if not macro_army.is_empty()
			and StringName(macro_army.phase) == ArmyRegistry.PHASE_STATIONED
			else &"blackstone_city"
		),
		"can_issue_from_city": (
			_active_battle_reservation.is_empty()
			and not _army_registry.has_active_non_macro_army()
		),
		# Do not expose authoritative field state through the macro view: it
		# contains hidden patrol positions.  Combat records are already player
		# visible because the corresponding army is in an active siege.
		"war_loop": {
			"active_siege": _war_loop_state.active_siege.duplicate(true),
			"sieges": _war_loop_state.get_active_sieges(),
			"cities_by_id": _war_loop_state.cities_by_id.duplicate(true),
		},
		"level_cleared": _war_loop_state.is_level_cleared(),
	}


func get_macro_march_army() -> Dictionary:
	var armies := get_macro_march_armies()
	return armies.front().duplicate(true) if not armies.is_empty() else {}


func get_macro_march_armies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for army in _army_registry.get_armies():
		if (
			not Dictionary(army.get("macro_march", {})).is_empty()
			and StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_CLOSED
		):
			result.append(army.duplicate(true))
	return result


func get_macro_march_food_cost(total_count: int) -> int:
	return get_first_war_food_cost(total_count)


# Presentation may request this immutable projection, but only the command
# methods below may charge food or alter garrison and army records.
func get_macro_march_command_preview(formation_ids: Array, army_id: StringName = &"") -> Dictionary:
	var committed_total := 0
	if army_id != &"":
		var army := _army_registry.get_army(army_id)
		for count in Dictionary(army.get("units_by_definition_id", {})).values():
			committed_total += int(count)
	else:
		for formation in _garrison_state.get_selected_formations(formation_ids):
			committed_total += int(formation.member_count)
	var food_cost := get_macro_march_food_cost(committed_total)
	return {
		"committed_total": committed_total,
		"food_cost": food_cost,
		"food_available": food,
		"food_shortage": maxi(0, food_cost - food),
	}


func _ensure_war_loop_initialized() -> void:
	_war_loop_state.initialize_from_theater(
		MACRO_MARCH_THEATER.get_points(), MACRO_MARCH_THEATER.get_routes(),
		MACRO_MARCH_THEATER.get_water_regions(),
		Rect2i(MACRO_MARCH_THEATER.get_world_bounds()),
		MACRO_MARCH_THEATER.get_terrain_regions(),
		MACRO_MARCH_THEATER.get_patrol_configs(),
		MACRO_MARCH_THEATER.get_scout_visibility_range(),
		MACRO_MARCH_THEATER.get_watchtower_config()
	)


func plan_field_path(source_point_id: StringName, target_point_id: StringName, preferred_world_points: Array = [], required_road_id: StringName = &"") -> Dictionary:
	_ensure_war_loop_initialized()
	return _war_loop_state.field_tactics.plan_runtime_path(source_point_id, target_point_id, preferred_world_points, required_road_id)


func get_field_tactics_read_model() -> Dictionary:
	_ensure_war_loop_initialized()
	var field_snapshot := _war_loop_state.field_tactics.get_snapshot()
	# The public projection deliberately excludes hidden patrol records.  UI,
	# hit testing and risk labels must consume this projection rather than the
	# authoritative simulation dictionary.
	var visible_patrols: Dictionary = {}
	var visible_facilities: Dictionary = {}
	for facility_id_value in Dictionary(field_snapshot.get("watchtowers_by_id", {})).keys():
		var facility := Dictionary(field_snapshot.watchtowers_by_id[facility_id_value])
		if (
			StringName(facility.get("owner_faction_id", &"player")) == &"player"
			or &"player" in Array(facility.get("discovered_by_faction_ids", []))
		):
			visible_facilities[StringName(facility_id_value)] = facility.duplicate(true)
	for patrol_id_value in Dictionary(field_snapshot.patrols_by_id):
		var patrol_id := StringName(patrol_id_value)
		var intel := _war_loop_state.field_tactics.observe_subject(patrol_id)
		if StringName(intel.get("fog_state", &"")) != FieldTacticsState.FOG_UNOBSERVED:
			var patrol: Dictionary = Dictionary(field_snapshot.patrols_by_id[patrol_id])
			var projected := intel.duplicate(true)
			projected.exposed = bool(patrol.get("exposed", false))
			projected.last_engagement = Dictionary(patrol.get("last_engagement", {})).duplicate(true)
			visible_patrols[patrol_id] = projected
	return {
		"roads_by_id": Dictionary(field_snapshot.roads_by_id).duplicate(true),
		"camps_by_id": Dictionary(field_snapshot.camps_by_id).duplicate(true),
		"watchtowers_by_id": visible_facilities,
		"specialists_by_id": Dictionary(field_snapshot.specialists_by_id).duplicate(true),
		"projects_by_id": Dictionary(field_snapshot.projects_by_id).duplicate(true),
		"intel_by_subject_id": Dictionary(field_snapshot.intel_by_subject_id).duplicate(true),
		"visible_patrols_by_id": visible_patrols,
		"supply_inventory_by_point_id": Dictionary(field_snapshot.get("supply_inventory_by_point_id", {})).duplicate(true),
		"stationed_reinforcements_by_point_id": Dictionary(field_snapshot.get("stationed_reinforcements_by_point_id", {})).duplicate(true),
		"supply_transports_by_id": Dictionary(field_snapshot.get("supply_transports_by_id", {})).duplicate(true),
		"world_milliseconds": int(field_snapshot.world_milliseconds),
		"blackstone_invasion": get_blackstone_invasion_read_model(),
	}


## Read projections deliberately leave the historical first-war ledger intact.
func uses_blackstone_campaign() -> bool:
	return _war_loop_state != null and not _war_loop_state.field_tactics.get_blackstone_invasion().is_empty()


func is_campaign_pressure_cleared() -> bool:
	if uses_blackstone_campaign():
		return _war_loop_state.is_level_cleared()
	return _current_mainline_level.cleared


func get_blackstone_campaign_status_text() -> String:
	var invasion := get_blackstone_invasion_read_model()
	var phase := StringName(invasion.get("phase", &""))
	var threat := "准备期 · 第 %d 日预警 / 第 %d 日出发" % [int(invasion.get("warning_day", 4)), int(invasion.get("activation_day", 5))]
	if bool(invasion.get("known", false)):
		threat = {
			FieldTacticsState.INVASION_DORMANT: "预警：赤崖先遣军将沿北道来袭",
			FieldTacticsState.INVASION_MARCHING: "来袭途中 · 可截击或回城备防",
			FieldTacticsState.INVASION_ARRIVED: "敌军抵城 · 城门可接战",
			FieldTacticsState.INVASION_HANDED_OFF: "守城事务处理中 · 继续原战斗",
			FieldTacticsState.INVASION_CANCELLED: "赤崖已被控制，本次先遣军出兵取消。",
			FieldTacticsState.INVASION_RESOLVED: "来袭已结算 · 可治疗、整备与反攻",
		}.get(phase, "来袭军已消灭 · 可继续行动")
	var objective := "控制赤崖与银渡 · 第 7 日后经济压力递增"
	if _war_loop_state.is_level_cleared():
		objective = "双城目标达成 · 可继续经营、驻扎与续令"
	return objective + "\n" + threat


func get_city_food_forecast() -> Dictionary:
	var income := 0
	for placement_id in _placement_order:
		if not is_building_operational(placement_id): continue
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		var definition := get_definition(StringName(record.get("definition_id", &"")))
		if definition == null: continue
		var production := definition.get_capability(&"production")
		if production != null and production.resource_id == &"food":
			income += _get_production_amount(definition, production)
	var upkeep := get_maintenance_food_cost()
	return {"income": income, "upkeep": upkeep, "net": income - upkeep}


## Developer diagnostics are transient read models, never campaign save data.
func get_campaign_progress_diagnostics() -> Dictionary:
	var blocked_armies: Array[Dictionary] = []
	for army in get_macro_march_armies():
		if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED:
			blocked_armies.append(army.duplicate(true))
	return {
		"player_paused": city_time_paused,
		"city_reservation_blocked": is_first_war_time_blocked(),
		"controller_processing": is_processing(),
		"controller_can_process": can_process(),
		"city_scene_process_mode": get_parent().process_mode,
		"speed": city_time_speed,
		"day": current_day,
		"day_elapsed_ms": get_day_elapsed_milliseconds(),
		"world_ms": _war_loop_state.field_tactics.world_milliseconds,
		"training_wait_reason": _last_training_failure_id,
		"training": _training_queue.get_snapshot(),
		"treatment": _population_recovery.treatment.duplicate(true),
		"blocked_armies": blocked_armies,
		"field_projects": _war_loop_state.field_tactics.projects_by_id.duplicate(true),
		"last_checkpoint": _last_campaign_checkpoint_result.duplicate(true),
		"persistence": get_parent().get_runtime_persistence_status(),
		"city_build_slot": get_build_slot_presentation(),
	}


func get_blackstone_invasion_read_model() -> Dictionary:
	_ensure_war_loop_initialized()
	var invasion := _war_loop_state.field_tactics.get_blackstone_invasion()
	if invasion.is_empty():
		return {}
	var warning_day := int(invasion.get("warning_day", 0))
	var invasion_phase := StringName(invasion.get("phase", &""))
	if current_day < warning_day and invasion_phase != FieldTacticsState.INVASION_CANCELLED:
		return {
			"known": false,
			"phase": StringName(invasion.get("phase", &"")),
			"warning_day": warning_day,
			"activation_day": int(invasion.get("activation_day", 0)),
		}
	var patrol_id := StringName(invasion.get("patrol_id", &""))
	var intel := _war_loop_state.field_tactics.observe_subject(patrol_id)
	var exact_strength_known := StringName(intel.get("fog_state", FieldTacticsState.FOG_UNOBSERVED)) == FieldTacticsState.FOG_VISIBLE
	return {
		"known": true,
		"patrol_id": patrol_id,
		"display_name": str(invasion.get("display_name", "来袭敌军")),
		"phase": invasion_phase,
		"source_point_id": StringName(invasion.get("source_point_id", &"")),
		"source_name": str(MACRO_MARCH_THEATER.get_point(StringName(invasion.get("source_point_id", &""))).get("display_name", "未知来源")),
		"target_point_id": StringName(invasion.get("target_point_id", &"")),
		"target_name": str(MACRO_MARCH_THEATER.get_point(StringName(invasion.get("target_point_id", &""))).get("display_name", "黑石城")),
		"known_route_name": str(invasion.get("known_route_name", "既知道路")),
		"warning_day": warning_day,
		"activation_day": int(invasion.get("activation_day", 0)),
		"exact_strength_known": exact_strength_known,
		"known_strength": int(intel.get("known_strength", 0)) if exact_strength_known else -1,
		"fog_state": StringName(intel.get("fog_state", FieldTacticsState.FOG_UNOBSERVED)),
		"cancellation_reason": StringName(invasion.get("cancellation_reason", &"")),
		"cancelled_day": int(invasion.get("cancelled_day", 0)),
	}


func preview_field_supply_transport(source_point_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	if source_point_id != &"silverford_city":
		return {"valid": false, "error": "当前只有银渡城可安排粮草运回"}
	if StringName(_war_loop_state.get_city(source_point_id).get("military_controller_faction_id", &"")) != &"player":
		return {"valid": false, "error": "需要先占领银渡城才能安排运输"}
	var preview := _war_loop_state.field_tactics.preview_supply_transport(source_point_id, &"blackstone_city")
	if not bool(preview.get("valid", false)):
		return preview
	preview.destination_food_capacity = get_resource_capacity(&"food")
	preview.destination_food_available = food
	preview.destination_free_capacity = maxi(int(preview.destination_food_capacity) - food, 0)
	preview.unload_immediately_possible = int(preview.destination_free_capacity) >= int(preview.amount)
	return preview


func begin_field_supply_transport(source_point_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := preview_field_supply_transport(source_point_id)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"SUPPLY_INVALID", str(preview.get("error", "粮草运输无法安排")))
	var war_before := _war_loop_state.get_snapshot()
	var transport := _war_loop_state.field_tactics.begin_supply_transport(source_point_id, &"blackstone_city")
	if transport.is_empty():
		return _macro_failure(&"SUPPLY_CREATE_FAILED", "粮草运输未能创建")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SAVE_FAILED", "粮草运输存档失败，地点库存未扣除")
	return {"success": true, "transport": transport.duplicate(true), "preview": preview.duplicate(true)}


## R0 keeps the finite local pool in FieldTacticsState while ArmyRegistry owns
## every enlisted member. This Controller entry is the transaction boundary:
## it rechecks the point controller, station, capacity and pool immediately
## before mutating either owner, then publishes one normal V5 checkpoint.
func preview_field_stationed_replenishment(point_id: StringName, army_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	if point_id != &"silverford_city":
		return {"valid": false, "error": "当前只有银渡城可补充当地兵员"}
	if StringName(_war_loop_state.get_city(point_id).get("military_controller_faction_id", &"")) != &"player":
		return {"valid": false, "error": "需要先占领银渡城才能补员"}
	var army := _army_registry.get_army(army_id)
	if army.is_empty():
		return {"valid": false, "error": "未找到指定驻军"}
	if StringName(army.get("owner_faction_id", &"")) != &"player":
		return {"valid": false, "error": "只有我方驻军可接收当地补员"}
	var available := _war_loop_state.field_tactics.get_stationed_reinforcements(point_id)
	return _army_registry.preview_stationed_reinforcement(army_id, point_id, available)


func replenish_field_stationed_army(point_id: StringName, army_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := preview_field_stationed_replenishment(point_id, army_id)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"REINFORCEMENT_INVALID", str(preview.get("error", "驻军无法补员")))
	var amount := int(preview.get("amount", 0))
	var allocation: Array = Array(preview.get("allocation", [])).duplicate(true)
	if amount <= 0 or allocation.is_empty():
		return _macro_failure(&"REINFORCEMENT_EMPTY", "没有可提交的驻军补员")
	var war_before := _war_loop_state.get_snapshot()
	var registry_before := _army_registry.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var army := _army_registry.replenish_stationed_army(army_id, point_id, allocation)
	if (
		army.is_empty()
		or not _war_loop_state.field_tactics.consume_stationed_reinforcements(point_id, amount)
		or not _population_recovery.admit_external_population(amount)
		or not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists())
	):
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		return _macro_failure(&"REINFORCEMENT_COMMIT", "补员条件已变化，未写入任何兵员")
	var checkpoint_success := _field_reinforcement_fault_for_test != &"CHECKPOINT_SAVE_FAILED" and bool(_persist_macro_march_checkpoint().get("success", false))
	_field_reinforcement_fault_for_test = &"" if _field_reinforcement_fault_for_test == &"CHECKPOINT_SAVE_FAILED" else _field_reinforcement_fault_for_test
	if not checkpoint_success:
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		return _macro_failure(&"SAVE_FAILED", "驻军补员存档失败，地点兵源与编队已回滚")
	return {"success": true, "army": army.duplicate(true), "preview": preview.duplicate(true), "amount": amount}


func dispatch_field_specialist(role: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var food_cost := _field_specialist_dispatch_cost(role)
	if food_cost <= 0:
		return _macro_failure(&"SPECIALIST_ROLE", "未知专员类型")
	if food < food_cost:
		return _macro_failure(&"FOOD_SHORTAGE", "粮食不足，无法派遣特殊单位")
	var war_before := _war_loop_state.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var local_commit := func() -> Dictionary:
		if not _population_recovery.allocate_specialist():
			return {"success": false}
		var specialist := _war_loop_state.field_tactics.dispatch_specialist(role, &"blackstone_city")
		if specialist.is_empty():
			_population_recovery.restore_snapshot(population_before)
		return {"success": not specialist.is_empty(), "specialist": specialist}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"field_specialist_dispatch", local_commit
	)
	if not bool(transaction.get("success", false)):
		_population_recovery.restore_snapshot(population_before)
		return _macro_failure(&"SPECIALIST_TRANSACTION", "特殊单位派遣未提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_population_recovery.restore_snapshot(population_before)
		_nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
			&"field_specialist_dispatch_rollback")
		return _macro_failure(&"SAVE_FAILED", "特殊单位派遣存档失败，资源已回滚")
	return {"success": true, "specialist": Dictionary(transaction.local_commit_result.specialist).duplicate(true), "food_cost": food_cost}


func dispatch_field_specialist_to_target(role: StringName, target_point_id: StringName) -> Dictionary:
	# Direct-map dispatch is one transaction: first prove the requested movement
	# is legal, then create and order the specialist before publishing one save.
	# This avoids the old two-click flow where a failed target could still spend
	# food on an idle specialist.
	_ensure_war_loop_initialized()
	var food_cost := _field_specialist_dispatch_cost(role)
	if food_cost <= 0:
		return _macro_failure(&"SPECIALIST_ROLE", "未知专员类型")
	if target_point_id == &"blackstone_city":
		return _macro_failure(&"SPECIALIST_TARGET", "请选择另一处城池或驻点")
	var movement_preview := _war_loop_state.field_tactics.preview_specialist_move_from_point(&"blackstone_city", target_point_id)
	if not bool(movement_preview.get("valid", false)):
		return _macro_failure(&"SPECIALIST_MOVE", str(movement_preview.get("error", "特殊单位无法前往该位置")))
	if food < food_cost:
		return _macro_failure(&"FOOD_SHORTAGE", "粮食不足，无法派遣特殊单位")
	var war_before := _war_loop_state.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var local_commit := func() -> Dictionary:
		if not _population_recovery.allocate_specialist():
			return {"success": false}
		var specialist := _war_loop_state.field_tactics.dispatch_specialist(role, &"blackstone_city")
		if specialist.is_empty():
			_population_recovery.restore_snapshot(population_before)
			return {"success": false}
		var ordered := _war_loop_state.field_tactics.order_specialist_move(StringName(specialist.get("specialist_id", &"")), target_point_id)
		if ordered.is_empty():
			_war_loop_state.restore_snapshot(war_before)
			_population_recovery.restore_snapshot(population_before)
			return {"success": false}
		return {"success": true, "specialist": ordered}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"field_specialist_dispatch_and_move", local_commit
	)
	if not bool(transaction.get("success", false)):
		_population_recovery.restore_snapshot(population_before)
		return _macro_failure(&"SPECIALIST_TRANSACTION", "特殊单位派遣与目标下令未提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_population_recovery.restore_snapshot(population_before)
		_nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
			&"field_specialist_dispatch_and_move_rollback")
		return _macro_failure(&"SAVE_FAILED", "特殊单位派遣存档失败，资源已回滚")
	return {"success": true, "specialist": Dictionary(transaction.local_commit_result.specialist).duplicate(true), "food_cost": food_cost}


func preview_field_specialist_dispatch_to_target(role: StringName, target_point_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var food_cost := _field_specialist_dispatch_cost(role)
	if food_cost <= 0:
		return {"valid": false, "error": "未知专员类型"}
	var movement_preview := _war_loop_state.field_tactics.preview_specialist_move_from_point(&"blackstone_city", target_point_id)
	if not bool(movement_preview.get("valid", false)):
		return movement_preview
	movement_preview.food_cost = food_cost
	movement_preview.food_shortage = maxi(food_cost - food, 0)
	movement_preview.affordable = food >= food_cost
	if not bool(movement_preview.affordable):
		movement_preview.valid = false
		movement_preview.error = "粮食不足：需要 %d，当前 %d" % [food_cost, food]
	return movement_preview


func _field_specialist_dispatch_cost(role: StringName) -> int:
	return int(FIELD_SPECIALIST_DISPATCH_COSTS.get(role, 0))


func get_field_specialist_rules_model() -> Dictionary:
	return {
		"dispatch_food_costs": FIELD_SPECIALIST_DISPATCH_COSTS.duplicate(true),
		"action_rules": FIELD_SPECIALIST_ACTION_RULES.duplicate(true),
	}


func preview_field_specialist_move(specialist_id: StringName, target_point_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	return _war_loop_state.field_tactics.preview_specialist_move(specialist_id, target_point_id)


func order_field_specialist_move(specialist_id: StringName, target_point_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var war_before := _war_loop_state.get_snapshot()
	var specialist := _war_loop_state.field_tactics.order_specialist_move(specialist_id, target_point_id)
	if specialist.is_empty():
		return _macro_failure(&"SPECIALIST_MOVE", "特殊单位无法前往该位置")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SAVE_FAILED", "特殊单位军令存档失败")
	return {"success": true, "specialist": specialist}


func preview_field_specialist_action(specialist_id: StringName, action_kind: StringName, target_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var target := _resolve_field_specialist_action_target(action_kind, target_id, specialist_id)
	if not bool(target.get("valid", false)):
		return target
	var action_rule := Dictionary(FIELD_SPECIALIST_ACTION_RULES.get(action_kind, {}))
	var required_milliseconds := int(action_rule.get("duration_milliseconds", 0))
	var preview := _war_loop_state.field_tactics.preview_specialist_action(
		specialist_id, action_kind, target_id,
		Vector2i(target.get("world_position", FieldTacticsState.INVALID_WORLD_POSITION)),
		required_milliseconds
	)
	if not bool(preview.get("valid", false)):
		return preview
	var food_cost := int(action_rule.get("food_cost", 0))
	preview.food_cost = food_cost
	preview.affordable = food >= food_cost
	if not bool(preview.affordable):
		preview.valid = false
		preview.error = "粮食不足：任务需要 %d 粮" % food_cost
	return preview


func begin_field_specialist_action(specialist_id: StringName, action_kind: StringName, target_id: StringName) -> Dictionary:
	var preview := preview_field_specialist_action(specialist_id, action_kind, target_id)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"SPECIALIST_ACTION", str(preview.get("error", "专员任务不合法")))
	var war_before := _war_loop_state.get_snapshot()
	var specialist := _war_loop_state.field_tactics.begin_specialist_action(
		specialist_id, action_kind, target_id, Vector2i(preview.target_world_position),
		int(preview.required_milliseconds)
	)
	if specialist.is_empty():
		return _macro_failure(&"SPECIALIST_ACTION", "专员任务未能建立")
	var food_cost := int(Dictionary(FIELD_SPECIALIST_ACTION_RULES.get(action_kind, {})).get("food_cost", 0))
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"field_specialist_action"
	)
	if not bool(transaction.get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SPECIALIST_ACTION_RESOURCE", "专员任务费用未能提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_nation_state.commit_resource_transaction(
			NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
			&"field_specialist_action_rollback"
		)
		return _macro_failure(&"SAVE_FAILED", "专员任务存档失败，费用和任务已回滚")
	return {"success": true, "specialist": specialist, "preview": preview, "food_cost": food_cost}


func _resolve_field_specialist_action_target(action_kind: StringName, target_id: StringName, specialist_id: StringName = &"") -> Dictionary:
	var field: FieldTacticsState = _war_loop_state.field_tactics
	if action_kind == FieldTacticsState.ACTION_MEDICAL:
		for siege_value in _war_loop_state.get_active_sieges():
			var siege: Dictionary = Dictionary(siege_value)
			if StringName(siege.get("army_id", &"")) != target_id:
				continue
			var hp := int(siege.get("attacker_total_hp", 0))
			var hp_per_member := maxi(int(siege.get("attacker_hp_per_member", 1)), 1)
			var heal_cap := ceili(float(hp) / float(hp_per_member)) * hp_per_member
			if hp <= 0 or hp >= heal_cap or not Dictionary(siege.get("wartime_handoff", {})).is_empty():
				return {"valid": false, "error": "该军队没有可稳定的存活单位伤势，或已交接战时实例"}
			return {"valid": true, "world_position": Vector2i(field.point_positions_by_id.get(StringName(siege.get("city_id", &"")), FieldTacticsState.INVALID_WORLD_POSITION))}
	elif action_kind == FieldTacticsState.ACTION_SABOTAGE:
		var facility := Dictionary(field.watchtowers_by_id.get(target_id, {}))
		if (
			facility.is_empty()
			or StringName(facility.get("owner_faction_id", &"player")) == &"player"
			or StringName(facility.get("state", FieldTacticsState.FACILITY_ACTIVE)) == FieldTacticsState.FACILITY_DESTROYED
			or &"player" not in Array(facility.get("discovered_by_faction_ids", []))
		):
			return {"valid": false, "error": "请选择已发现且仍有效的敌方设施"}
		return {"valid": true, "world_position": Vector2i(facility.get("world_position", FieldTacticsState.INVALID_WORLD_POSITION))}
	elif action_kind == FieldTacticsState.ACTION_THEFT:
		var city := _war_loop_state.get_city(target_id)
		var target_siege := _war_loop_state.get_siege(target_id)
		var target_handoff := Dictionary(target_siege.get("wartime_handoff", {}))
		var city_intel := Dictionary(field.intel_by_subject_id.get(target_id, {}))
		var available_stock := int(field.supply_inventory_by_point_id.get(target_id, 0))
		var theft_amount := mini(available_stock, int(Dictionary(FIELD_SPECIALIST_ACTION_RULES[FieldTacticsState.ACTION_THEFT]).effect_amount))
		if (
			city.is_empty()
			or StringName(city.get("military_controller_faction_id", &"player")) == &"player"
			or available_stock <= 0
			or StringName(target_handoff.get("phase", &"")) in [WarLoopState.WARTIME_HANDOFF_RESERVED, WarLoopState.WARTIME_HANDOFF_ACTIVE, WarLoopState.WARTIME_HANDOFF_RESULT_PENDING]
			or StringName(city_intel.get("subject_kind", &"")) != &"POINT"
			or StringName(city_intel.get("fog_state", FieldTacticsState.FOG_UNOBSERVED)) not in [FieldTacticsState.FOG_VISIBLE, FieldTacticsState.FOG_OBSERVED]
		):
			return {"valid": false, "error": "目标没有可盗取的已知库存，或已由我方控制"}
		if maxi(get_resource_capacity(&"food") - food, 0) < theft_amount:
			return {"valid": false, "error": "黑石城粮仓没有空间接收本次战利品"}
		return {"valid": true, "world_position": Vector2i(field.point_positions_by_id.get(target_id, FieldTacticsState.INVALID_WORLD_POSITION))}
	elif action_kind == FieldTacticsState.ACTION_SNIPER:
		var patrol := Dictionary(field.patrols_by_id.get(target_id, {}))
		var intel := Dictionary(field.intel_by_subject_id.get(target_id, {}))
		if patrol.is_empty() or int(patrol.get("strength", 0)) <= 0 or StringName(patrol.get("phase", &"")) in [FieldTacticsState.INVASION_HANDED_OFF, FieldTacticsState.INVASION_DEFEATED, FieldTacticsState.INVASION_CANCELLED, FieldTacticsState.INVASION_RESOLVED] or StringName(intel.get("fog_state", FieldTacticsState.FOG_UNOBSERVED)) != FieldTacticsState.FOG_VISIBLE:
			return {"valid": false, "error": "狙击目标必须是当前已发现且未交接的存活敌军"}
		var patrol_position := Vector2(patrol.get("world_position", FieldTacticsState.INVALID_WORLD_POSITION))
		var action_position := patrol_position
		var specialist := Dictionary(field.specialists_by_id.get(specialist_id, {}))
		if not specialist.is_empty():
			# A sniper acts from a visible stand-off position. Walking onto the enemy
			# marker made the ordinary patrol-contact resolver kill the specialist
			# before the shot could be committed, so the formal action was impossible
			# without a guard. Exposure remains a result fact after the real shot.
			var from_target := Vector2(specialist.get("world_position", patrol_position)) - patrol_position
			if from_target.length_squared() > 0.01:
				action_position = patrol_position + from_target.normalized() * 110.0
		return {"valid": true, "world_position": Vector2i(action_position)}
	return {"valid": false, "error": "未知专员任务"}


func _resolve_ready_field_specialist_actions(action_ids: Array) -> Dictionary:
	var field: FieldTacticsState = _war_loop_state.field_tactics
	var pending_action_ids := action_ids.duplicate()
	# A thief who physically returned while the storehouse was full keeps the
	# same cargo and retries on later world steps. No new theft or debit occurs.
	for specialist_id_value in field.specialists_by_id.keys():
		var pending_id := StringName(specialist_id_value)
		var pending := Dictionary(field.specialists_by_id[pending_id])
		if StringName(pending.get("action_stage", &"")) == FieldTacticsState.ACTION_READY_DEPOSIT and pending_id not in pending_action_ids:
			pending_action_ids.append(pending_id)
	var changed := false
	var committed_amounts: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	for specialist_id_value in pending_action_ids:
		var specialist_id := StringName(specialist_id_value)
		var specialist := Dictionary(field.specialists_by_id.get(specialist_id, {}))
		var kind := StringName(specialist.get("action_kind", &""))
		var stage := StringName(specialist.get("action_stage", &""))
		var target_id := StringName(specialist.get("action_target_id", &""))
		var action_result: Dictionary = {}
		var waiting_for_capacity := false
		if stage == FieldTacticsState.ACTION_READY_DEPOSIT and kind == FieldTacticsState.ACTION_THEFT:
			var amount := int(specialist.get("action_cargo_food", 0))
			if amount > 0 and maxi(get_resource_capacity(&"food") - food, 0) >= amount:
				var transaction := _nation_state.commit_resource_transaction(
					NationState.BLACKSTONE_CITY_ID,
					[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": amount}],
					&"field_specialist_theft_deposit",
					func() -> Dictionary: return {"success": field.finish_specialist_action(specialist_id, {"deposited_food": amount})}
				)
				if bool(transaction.get("success", false)):
					committed_amounts.append({"transport_id": specialist_id, "amount": amount})
					action_result = {"deposited_food": amount}
			elif amount > 0:
				waiting_for_capacity = true
		elif stage == FieldTacticsState.ACTION_READY:
			var current_target := _resolve_field_specialist_action_target(kind, target_id)
			if not bool(current_target.get("valid", false)):
				field.interrupt_specialist_action(specialist_id, &"TARGET_INVALID")
			elif kind == FieldTacticsState.ACTION_MEDICAL:
				for siege_value in _war_loop_state.get_active_sieges():
					var siege: Dictionary = Dictionary(siege_value)
					if StringName(siege.get("army_id", &"")) == target_id:
						action_result = _war_loop_state.heal_siege_attacker(StringName(siege.get("city_id", &"")), int(Dictionary(FIELD_SPECIALIST_ACTION_RULES[FieldTacticsState.ACTION_MEDICAL]).effect_amount))
						break
				if not action_result.is_empty():
					field.finish_specialist_action(specialist_id, action_result)
			elif kind == FieldTacticsState.ACTION_SABOTAGE:
				action_result = field.apply_specialist_sabotage(specialist_id, target_id, int(Dictionary(FIELD_SPECIALIST_ACTION_RULES[FieldTacticsState.ACTION_SABOTAGE]).effect_amount))
			elif kind == FieldTacticsState.ACTION_THEFT:
				action_result = field.begin_specialist_theft_return(specialist_id, target_id, int(Dictionary(FIELD_SPECIALIST_ACTION_RULES[FieldTacticsState.ACTION_THEFT]).effect_amount), &"blackstone_city")
			elif kind == FieldTacticsState.ACTION_SNIPER:
				action_result = field.apply_specialist_sniper_shot(specialist_id, target_id, int(Dictionary(FIELD_SPECIALIST_ACTION_RULES[FieldTacticsState.ACTION_SNIPER]).effect_amount))
		if not waiting_for_capacity and action_result.is_empty() and StringName(Dictionary(field.specialists_by_id.get(specialist_id, {})).get("action_stage", &"")) in [FieldTacticsState.ACTION_READY, FieldTacticsState.ACTION_READY_DEPOSIT]:
			field.interrupt_specialist_action(specialist_id, &"ACTION_FAILED")
		var current := Dictionary(field.specialists_by_id.get(specialist_id, {}))
		var action_changed := current != specialist or not action_result.is_empty()
		changed = changed or action_changed
		if action_changed:
			events.append({"specialist_id": specialist_id, "action_kind": kind, "result": action_result})
	return {"success": true, "changed": changed, "events": events, "committed_amounts": committed_amounts}


func preview_field_road_project(
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	road_kind: StringName,
	build_camp := false
) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := _war_loop_state.field_tactics.preview_road_project(
		engineer_id, source_point_id, target_point_id, route_world_points, road_kind, build_camp
	)
	if not bool(preview.get("valid", false)):
		return preview
	var food_cost := 12 if bool(preview.get("contains_bridge", false)) else (10 if StringName(preview.get("road_kind", &"")) == FieldTacticsState.ROAD_REINFORCED else 5)
	preview.food_cost = food_cost
	preview.food_shortage = maxi(food_cost - food, 0)
	preview.affordable = food >= food_cost
	return preview


func begin_field_road_project(
	engineer_id: StringName,
	source_point_id: StringName,
	target_point_id: StringName,
	route_world_points: Array,
	road_kind: StringName,
	build_camp := false
) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := preview_field_road_project(engineer_id, source_point_id, target_point_id, route_world_points, road_kind, build_camp)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"PROJECT_INVALID", str(preview.get("error", "工程施工规划无效")))
	var resolved_road_kind := StringName(preview.get("road_kind", FieldTacticsState.ROAD_NORMAL))
	var food_cost := int(preview.get("food_cost", 0))
	if food < food_cost:
		return _macro_failure(&"FOOD_SHORTAGE", "粮食不足，无法安排工程施工")
	var war_before := _war_loop_state.get_snapshot()
	var local_commit := func() -> Dictionary:
		var project := _war_loop_state.field_tactics.begin_road_project(
			engineer_id, source_point_id, target_point_id, route_world_points, resolved_road_kind, build_camp
		)
		return {"success": not project.is_empty(), "project": project}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"field_road_project", local_commit
	)
	if not bool(transaction.get("success", false)):
		return _macro_failure(&"PROJECT_TRANSACTION", "工程施工未提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
			&"field_road_project_rollback")
		return _macro_failure(&"SAVE_FAILED", "工程施工存档失败，资源已回滚")
	return {"success": true, "project": Dictionary(transaction.local_commit_result.project).duplicate(true), "food_cost": food_cost}


func preview_field_watchtower_project(engineer_id: StringName, camp_id: StringName, world_position: Vector2i, facility_kind: StringName = FieldTacticsState.FACILITY_WATCHTOWER) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := _war_loop_state.field_tactics.preview_watchtower_project(engineer_id, camp_id, world_position, facility_kind)
	if not bool(preview.get("valid", false)):
		return preview
	var food_cost := int(preview.get("food_cost", 0))
	preview.food_shortage = maxi(food_cost - food, 0)
	preview.affordable = food >= food_cost
	if not bool(preview.affordable):
		preview.valid = false
		preview.error = "粮食不足：需要 %d，当前 %d" % [food_cost, food]
	return preview


func begin_field_watchtower_project(engineer_id: StringName, camp_id: StringName, world_position: Vector2i, facility_kind: StringName = FieldTacticsState.FACILITY_WATCHTOWER) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := preview_field_watchtower_project(engineer_id, camp_id, world_position, facility_kind)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"WATCHTOWER_INVALID", str(preview.get("error", "瞭望塔规划无效")))
	var food_cost := int(preview.get("food_cost", 0))
	var war_before := _war_loop_state.get_snapshot()
	var local_commit := func() -> Dictionary:
		var project := _war_loop_state.field_tactics.begin_watchtower_project(engineer_id, camp_id, world_position, facility_kind)
		return {"success": not project.is_empty(), "project": project}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"field_watchtower_project", local_commit
	)
	if not bool(transaction.get("success", false)):
		return _macro_failure(&"WATCHTOWER_TRANSACTION", "瞭望塔施工未提交")
	var checkpoint_success := _field_watchtower_fault_for_test != &"CHECKPOINT_SAVE_FAILED" and bool(_persist_macro_march_checkpoint().get("success", false))
	_field_watchtower_fault_for_test = &"" if _field_watchtower_fault_for_test == &"CHECKPOINT_SAVE_FAILED" else _field_watchtower_fault_for_test
	if not checkpoint_success:
		_war_loop_state.restore_snapshot(war_before)
		_nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
			&"field_watchtower_project_rollback")
		return _macro_failure(&"SAVE_FAILED", "瞭望塔施工存档失败，资源已回滚")
	return {"success": true, "project": Dictionary(transaction.local_commit_result.project).duplicate(true), "food_cost": food_cost}


func preview_field_facility_repair(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := _war_loop_state.field_tactics.preview_field_facility_repair(engineer_id, facility_id)
	if not bool(preview.get("valid", false)):
		return preview
	preview.affordable = food >= int(preview.get("food_cost", 0))
	if not bool(preview.affordable):
		preview.valid = false
		preview.error = "粮食不足，无法维修外部设施"
	return preview


func begin_field_facility_repair(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	var preview := preview_field_facility_repair(engineer_id, facility_id)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"FIELD_FACILITY_REPAIR_INVALID", str(preview.get("error", "设施维修无效")))
	var food_cost := int(preview.get("food_cost", 0))
	var war_before := _war_loop_state.get_snapshot()
	var local_commit := func() -> Dictionary:
		var project := _war_loop_state.field_tactics.begin_field_facility_repair(engineer_id, facility_id)
		return {"success": not project.is_empty(), "project": project}
	var transaction := _nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID, [{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}], &"field_facility_repair", local_commit)
	if not bool(transaction.get("success", false)):
		return _macro_failure(&"FIELD_FACILITY_REPAIR_TRANSACTION", "设施维修事务未提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID, [{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}], &"field_facility_repair_rollback")
		return _macro_failure(&"SAVE_FAILED", "设施维修存档失败，资源已回滚")
	return {"success": true, "project": Dictionary(transaction.local_commit_result.project).duplicate(true), "food_cost": food_cost}


func preview_field_facility_upgrade(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var preview := _war_loop_state.field_tactics.preview_field_facility_upgrade(engineer_id, facility_id)
	if not bool(preview.get("valid", false)):
		return preview
	preview.affordable = food >= int(preview.get("food_cost", 0))
	if not bool(preview.affordable):
		preview.valid = false
		preview.error = "粮食不足，无法升级外部设施"
	return preview


func begin_field_facility_upgrade(engineer_id: StringName, facility_id: StringName) -> Dictionary:
	var preview := preview_field_facility_upgrade(engineer_id, facility_id)
	if not bool(preview.get("valid", false)):
		return _macro_failure(&"FIELD_FACILITY_UPGRADE_INVALID", str(preview.get("error", "设施升级无效")))
	var food_cost := int(preview.get("food_cost", 0))
	var war_before := _war_loop_state.get_snapshot()
	var local_commit := func() -> Dictionary:
		var project := _war_loop_state.field_tactics.begin_field_facility_upgrade(engineer_id, facility_id)
		return {"success": not project.is_empty(), "project": project}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"field_facility_upgrade",
		local_commit
	)
	if not bool(transaction.get("success", false)):
		return _macro_failure(&"FIELD_FACILITY_UPGRADE_TRANSACTION", "设施升级事务未提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_nation_state.commit_resource_transaction(
			NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
			&"field_facility_upgrade_rollback"
		)
		return _macro_failure(&"SAVE_FAILED", "设施升级存档失败，资源已回滚")
	return {"success": true, "project": Dictionary(transaction.local_commit_result.project).duplicate(true), "food_cost": food_cost}


func assign_field_fortress_garrison(facility_id: StringName, army_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var army := _army_registry.get_army(army_id)
	var positions := _macro_army_world_positions()
	if (
		army.is_empty()
		or StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_STATIONED
		or not positions.has(army_id)
	):
		return _macro_failure(&"FORTRESS_ARMY_INVALID", "只有位于堡垒范围内的已驻扎军队可以进驻")
	var war_before := _war_loop_state.get_snapshot()
	if not _war_loop_state.field_tactics.assign_fortress_garrison(
		facility_id, army_id, Vector2(positions[army_id])
	):
		return _macro_failure(&"FORTRESS_ASSIGN_INVALID", "堡垒已被占用，或军队不在有效范围内")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SAVE_FAILED", "堡垒驻军存档失败，状态已回滚")
	return {"success": true, "facility_id": facility_id, "army_id": army_id}


func release_field_fortress_garrison(facility_id: StringName, army_id: StringName = &"") -> Dictionary:
	_ensure_war_loop_initialized()
	var war_before := _war_loop_state.get_snapshot()
	if not _war_loop_state.field_tactics.release_fortress_garrison(facility_id, army_id):
		return _macro_failure(&"FORTRESS_RELEASE_INVALID", "该堡垒没有对应驻军")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SAVE_FAILED", "堡垒撤军存档失败，状态已回滚")
	return {"success": true, "facility_id": facility_id, "army_id": army_id}


func clear_discovered_field_mine(facility_id: StringName, engineer_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var war_before := _war_loop_state.get_snapshot()
	if not _war_loop_state.field_tactics.clear_discovered_minefield(facility_id, &"player", engineer_id):
		return _macro_failure(&"MINE_CLEAR_INVALID", "需要由已到达现场的工程师排除已发现地雷")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SAVE_FAILED", "排雷存档失败，地雷状态已回滚")
	return {"success": true, "facility_id": facility_id}


func begin_field_road_repair(engineer_id: StringName, road_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	const REPAIR_FOOD_COST := 3
	if food < REPAIR_FOOD_COST:
		return _macro_failure(&"FOOD_SHORTAGE", "粮食不足，无法安排道路维修")
	var war_before := _war_loop_state.get_snapshot()
	var local_commit := func() -> Dictionary:
		var project := _war_loop_state.field_tactics.begin_road_repair(engineer_id, road_id)
		return {"success": not project.is_empty(), "project": project}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": REPAIR_FOOD_COST}],
		&"field_road_repair", local_commit
	)
	if not bool(transaction.get("success", false)):
		return _macro_failure(&"REPAIR_TRANSACTION", "道路维修未能提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_nation_state.commit_resource_transaction(NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": REPAIR_FOOD_COST}],
			&"field_road_repair_rollback")
		return _macro_failure(&"SAVE_FAILED", "道路维修存档失败，资源已回滚")
	return {"success": true, "project": Dictionary(transaction.local_commit_result.project).duplicate(true), "food_cost": REPAIR_FOOD_COST}


func preview_field_road_repair(engineer_id: StringName, road_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	const REPAIR_FOOD_COST := 3
	var preview := _war_loop_state.field_tactics.preview_road_repair(engineer_id, road_id)
	if not bool(preview.get("valid", false)):
		return preview
	preview.food_cost = REPAIR_FOOD_COST
	preview.food_shortage = maxi(REPAIR_FOOD_COST - food, 0)
	preview.affordable = food >= REPAIR_FOOD_COST
	if not bool(preview.affordable):
		preview.valid = false
		preview.error = "粮食不足：需要 %d，当前 %d" % [REPAIR_FOOD_COST, food]
	return preview


func resume_interrupted_field_project(engineer_id: StringName, project_id: StringName) -> Dictionary:
	_ensure_war_loop_initialized()
	var war_before := _war_loop_state.get_snapshot()
	var project := _war_loop_state.field_tactics.resume_interrupted_project(engineer_id, project_id)
	if project.is_empty():
		return _macro_failure(&"PROJECT_RESUME", "工程无法由该工程师接续")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SAVE_FAILED", "工程接续存档失败，状态已回滚")
	return {"success": true, "project": project}


func _macro_attacker_count(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _start_macro_siege(army: Dictionary) -> Dictionary:
	var war_before := _war_loop_state.get_snapshot()
	var macro: Dictionary = army.get("macro_march", {})
	var city_id := StringName(macro.get("target_point_id", &""))
	if not _war_loop_state.can_issue_attack(city_id):
		return _macro_failure(&"ATTACK_UNAVAILABLE", "目标不再是可进攻的敌城")
	var attack := roundi(float(INFANTRY_ROLE.attack) * get_infantry_attack_multiplier())
	var siege := _war_loop_state.begin_siege(
		StringName(army.army_id), StringName(macro.order_id), city_id,
		_macro_attacker_count(army), INFANTRY_ROLE.hp, attack, INFANTRY_ROLE.armor,
		roundi(get_infantry_attack_multiplier() * 10000.0), WAR_LOOP_RULES
	)
	if siege.is_empty():
		return _macro_failure(&"SIEGE_START_FAILED", "无法建立攻城事务")
	var started := _army_registry.begin_macro_siege(
		StringName(army.army_id), StringName(macro.order_id)
	)
	if started.is_empty():
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(&"SIEGE_ARMY_START_FAILED", "攻城军队状态未能提交")
	_war_loop_frame_remainder_milliseconds = 0.0
	if StringName(siege.phase) == WarLoopState.PHASE_OCCUPIED:
		return _finalize_macro_occupation(siege)
	return {"success": not started.is_empty(), "army": started.duplicate(true), "siege": siege.duplicate(true)}


func _finalize_macro_occupation(siege: Dictionary) -> Dictionary:
	var war_before := _war_loop_state.get_snapshot()
	var registry_before := _army_registry.get_snapshot()
	var resolution_id := StringName("%s.occupation" % String(siege.siege_id))
	var occupied := _war_loop_state.occupy_siege(StringName(siege.city_id), resolution_id)
	if occupied.is_empty():
		return _macro_failure(&"OCCUPATION_FAILED", "占领事务未能提交")
	var army := _army_registry.complete_macro_siege(StringName(occupied.army_id), StringName(occupied.order_id))
	if army.is_empty():
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return _macro_failure(&"OCCUPATION_ARMY_FAILED", "占领后驻扎状态未能提交")
	return {"success": true, "army": army.duplicate(true), "siege": occupied.duplicate(true), "level_cleared": _war_loop_state.is_level_cleared()}


# R0 exposes one demonstrable environmental condition. It is intentionally
# transient: the durable army's BLOCKED phase carries the recovery state.
func set_macro_march_route_blocked_for_scenario(route_id: StringName, blocked: bool) -> bool:
	var route := MACRO_MARCH_THEATER.get_route(route_id)
	if route.is_empty() or int(route.get("blockable_segment_index", -1)) < 1:
		return false
	if blocked:
		_macro_march_blocked_route_ids[route_id] = true
	else:
		_macro_march_blocked_route_ids.erase(route_id)
	return true


func is_macro_march_route_blocked(route_id: StringName) -> bool:
	return bool(_macro_march_blocked_route_ids.get(route_id, false))


func _validate_macro_march_route(source_point_id: StringName, target_point_id: StringName, route_id: StringName, route_world_points: Array) -> Dictionary:
	_ensure_war_loop_initialized()
	# Static roads were copied into FieldTacticsState at theater initialization,
	# so this one validation accepts both authored roads and player-completed
	# roads without letting unfinished/damaged segments through.
	return _war_loop_state.field_tactics.validate_runtime_route(
		source_point_id, target_point_id, route_id, route_world_points
	)


func get_macro_march_route_duration(route_id: StringName) -> int:
	var duration := _war_loop_state.field_tactics.runtime_route_duration_milliseconds(route_id)
	if StringName(_city_strategy.troop_equipment_by_slot.get(&"mobility", &"")) == &"equipment.marching_kit":
		duration = ceili(float(duration) / (1.0 + float(CITY_STRATEGY_RULES.equipment_effect_permille) / 1000.0))
	var mobility_permille := _general_equipment_effect_permille(&"MOBILITY")
	if mobility_permille > 0:
		duration = ceili(float(duration) / (1.0 + float(mobility_permille) / 1000.0))
	return duration


func _get_macro_order_strategy_snapshot() -> Dictionary:
	var equipment_ids: Array[StringName] = []
	for equipment_id_value in _city_strategy.troop_equipment_by_slot.values():
		var equipment_id := StringName(equipment_id_value)
		if equipment_id != &"" and equipment_id not in equipment_ids:
			equipment_ids.append(equipment_id)
	var general_slots: Dictionary = Dictionary(_city_strategy.general_equipment_by_general_id.get(selected_general_id, {}))
	for equipment_id_value in general_slots.values():
		var equipment_id := StringName(equipment_id_value)
		if equipment_id != &"" and equipment_id not in equipment_ids:
			equipment_ids.append(equipment_id)
	equipment_ids.sort()
	return {
		"equipment_ids": equipment_ids,
		"general_id": selected_general_id,
		"tech_ids": researched_tech_ids.duplicate(),
		"attack_basis_points": roundi(get_infantry_attack_multiplier() * 10000.0),
		"defense_basis_points": roundi(get_infantry_defense_multiplier() * 10000.0),
		"supply_shortage": supply_shortage,
	}


func commit_macro_march_from_city(
	formation_ids: Array,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array
) -> Dictionary:
	if (
		not _active_battle_reservation.is_empty()
		or _army_registry.has_active_non_macro_army()
	):
		return _macro_failure(&"MACRO_BUSY", "已有军令正在执行或等待驻扎")
	var selected := _garrison_state.get_selected_formations(formation_ids)
	if selected.is_empty() or not _garrison_state.selection_matches(selected):
		return _macro_failure(&"FORMATION_CHANGED", "请选择仍在黑石城内的完整编队")
	var total := 0
	var units: Dictionary = {}
	for formation in selected:
		total += int(formation.member_count)
		var definition_id := StringName(formation.definition_id)
		units[definition_id] = int(units.get(definition_id, 0)) + int(formation.member_count)
	var food_cost := get_macro_march_food_cost(total)
	var route_validation := _validate_macro_march_route(&"blackstone_city", target_point_id, route_id, route_world_points)
	if not bool(route_validation.valid):
		return _macro_failure(StringName(route_validation.error_id), str(route_validation.error))
	var validated_route: Dictionary = Dictionary(route_validation.get("route", {}))
	var route_segments: Array = Array(validated_route.get("segment_ids", [])).duplicate(true)
	if is_macro_march_route_blocked(route_id) or not _war_loop_state.field_tactics.is_route_open(route_id):
		return _macro_failure(&"ROAD_BLOCKED", "该道路当前受阻，请选择另一条道路或等待恢复")
	if food < food_cost:
		return _macro_failure(&"FOOD_SHORTAGE", "粮食不足：需要 %d，当前 %d" % [food_cost, food])
	var garrison_before := _garrison_state.get_persistence_snapshot()
	var registry_before := _army_registry.get_snapshot()
	var duration := get_macro_march_route_duration(route_id)
	var strategy_snapshot := _get_macro_order_strategy_snapshot()
	var local_commit := func() -> Dictionary:
		var army := _army_registry.create_macro_march(
			&"player", &"blackstone_city", &"blackstone_city", target_point_id,
			route_id, route_world_points, units, selected, food_cost, duration, route_segments,
			strategy_snapshot
		)
		if army.is_empty() or not _garrison_state.try_extract_selected_formations(selected):
			_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
			_garrison_state.restore_persistence_snapshot(garrison_before)
			return {"success": false}
		return {"success": true, "army": army.duplicate(true)}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"macro_march_issue", local_commit
	)
	if not bool(transaction.success):
		return _macro_failure(&"MACRO_TRANSACTION", "军令事务未提交")
	_refresh_city_ui()
	city_state_changed.emit()
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_rollback_macro_march_issue(food_cost, garrison_before, registry_before)
		return _macro_failure(&"SAVE_FAILED", "军令存档失败，粮食与编队已回滚")
	return {"success": true, "army": Dictionary(transaction.local_commit_result.army).duplicate(true)}


func commit_macro_march_from_station(
	army_id: StringName,
	target_point_id: StringName,
	route_id: StringName,
	route_world_points: Array
) -> Dictionary:
	_ensure_war_loop_initialized()
	var army := _army_registry.get_army(army_id)
	if army.is_empty() or StringName(army.phase) != ArmyRegistry.PHASE_STATIONED:
		return _macro_failure(&"STATION_REQUIRED", "只有已驻扎的军队可以继续发令")
	var occupied_fortress := _war_loop_state.field_tactics.fortress_for_army(army_id)
	if not occupied_fortress.is_empty():
		return _macro_failure(&"FORTRESS_GARRISONED", "该军队正在驻守堡垒；请先执行撤出堡垒")
	var route_validation := _validate_macro_march_route(StringName(army.target_node_id), target_point_id, route_id, route_world_points)
	if not bool(route_validation.valid):
		return _macro_failure(StringName(route_validation.error_id), str(route_validation.error))
	var validated_route: Dictionary = Dictionary(route_validation.get("route", {}))
	var route_segments: Array = Array(validated_route.get("segment_ids", [])).duplicate(true)
	if is_macro_march_route_blocked(route_id) or not _war_loop_state.field_tactics.is_route_open(route_id):
		return _macro_failure(&"ROAD_BLOCKED", "该道路当前受阻，请选择另一条道路或等待恢复")
	var total := 0
	for count in Dictionary(army.units_by_definition_id).values():
		total += int(count)
	var food_cost := get_macro_march_food_cost(total)
	if food < food_cost:
		return _macro_failure(&"FOOD_SHORTAGE", "粮食不足：需要 %d，当前 %d" % [food_cost, food])
	var registry_before := _army_registry.get_snapshot()
	var duration := get_macro_march_route_duration(route_id)
	var strategy_snapshot := _get_macro_order_strategy_snapshot()
	var local_commit := func() -> Dictionary:
		var issued := _army_registry.issue_stationed_macro_march(
			army_id, target_point_id, route_id, route_world_points, food_cost, duration, route_segments,
			strategy_snapshot
		)
		return {"success": not issued.is_empty(), "army": issued.duplicate(true)}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": food_cost}],
		&"macro_march_reissue", local_commit
	)
	if not bool(transaction.success):
		return _macro_failure(&"MACRO_TRANSACTION", "驻扎点军令事务未提交")
	_refresh_city_ui()
	city_state_changed.emit()
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_rollback_macro_march_issue(food_cost, {}, registry_before)
		return _macro_failure(&"SAVE_FAILED", "军令存档失败，粮食与军队状态已回滚")
	return {"success": true, "army": Dictionary(transaction.local_commit_result.army).duplicate(true)}


func advance_macro_march_time(
	army_id: StringName,
	order_id: StringName,
	expected_progress_milliseconds: int,
	delta_milliseconds: int
) -> Dictionary:
	return _advance_macro_march_elapsed_milliseconds(
		army_id, order_id, expected_progress_milliseconds,
		float(delta_milliseconds) * city_time_speed
	)


func advance_macro_march_time_seconds(
	army_id: StringName,
	order_id: StringName,
	expected_progress_milliseconds: int,
	delta_seconds: float
) -> Dictionary:
	return _advance_macro_march_elapsed_milliseconds(
		army_id, order_id, expected_progress_milliseconds,
		delta_seconds * 1000.0 * city_time_speed
	)


# The city owns world time.  Views may refresh every frame but must never
# advance individual armies, otherwise a second selected army changes the
# simulation rate.  Manual APIs above remain for deterministic test fixtures.
func _advance_all_macro_marches_seconds(delta_seconds: float) -> void:
	if city_time_paused or delta_seconds <= 0.0:
		return
	var snapshot := get_macro_march_armies()
	for army_value in snapshot:
		var army: Dictionary = army_value
		if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED:
			var blocked_macro: Dictionary = army.get("macro_march", {})
			var transfer: Dictionary = Dictionary(blocked_macro.get("blocked_transfer", {}))
			if StringName(transfer.get("phase", &"")) in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
				_advance_blocked_transfer_with_elapsed(army, delta_seconds * 1000.0 * city_time_speed)
			continue
		if StringName(army.get("phase", &"")) not in [ArmyRegistry.PHASE_MARCHING, ArmyRegistry.PHASE_RETREATING]:
			continue
		var macro: Dictionary = army.get("macro_march", {})
		var unavailable_segment := _war_loop_state.field_tactics.first_unavailable_route_segment(
			StringName(macro.get("route_id", &"")), Array(macro.get("route_segments", [])),
			Array(macro.get("route_world_points", [])), int(macro.get("progress_millis", 0)), int(macro.get("total_millis", 0))
		)
		if unavailable_segment >= 0:
			_block_macro_march_for_damaged_road(army, unavailable_segment)
			continue
		_advance_macro_march_elapsed_milliseconds(
			StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")),
			int(macro.get("progress_millis", 0)), delta_seconds * 1000.0 * city_time_speed
		)


func _advance_blocked_transfer_elapsed_milliseconds(army_id: StringName, order_id: StringName, expected_progress_milliseconds: int, elapsed_milliseconds: float) -> Dictionary:
	var remainder_key := StringName("transfer:%s:%s" % [String(army_id), String(order_id)])
	var pending := float(_macro_march_frame_remainders_by_order.get(remainder_key, 0.0)) + elapsed_milliseconds
	var whole_milliseconds := floori(pending + 0.000001)
	_macro_march_frame_remainders_by_order[remainder_key] = maxf(pending - float(whole_milliseconds), 0.0)
	if whole_milliseconds <= 0:
		return {}
	var result := _army_registry.advance_blocked_transfer(army_id, order_id, expected_progress_milliseconds, whole_milliseconds)
	if bool(result.get("arrived", false)):
		result.remaining_elapsed_milliseconds = float(result.get("remaining_milliseconds", 0)) + float(_macro_march_frame_remainders_by_order.get(remainder_key, 0.0))
		_macro_march_frame_remainders_by_order.erase(remainder_key)
	return result


func _advance_blocked_transfer_with_elapsed(army: Dictionary, elapsed_milliseconds: float) -> Dictionary:
	var registry_before := _army_registry.get_snapshot()
	var army_id := StringName(army.get("army_id", &""))
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var order_id := StringName(macro.get("order_id", &""))
	var remaining_milliseconds := elapsed_milliseconds
	var checkpoint_required := false
	var transitions := 0
	var final_result: Dictionary = {}
	while remaining_milliseconds > 0.000001 and transitions < 6:
		transitions += 1
		army = _army_registry.get_army(army_id)
		macro = Dictionary(army.get("macro_march", {}))
		var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
		var transfer_phase := StringName(transfer.get("phase", &""))
		if transfer_phase not in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
			break
		var unavailable_segment := _war_loop_state.field_tactics.first_unavailable_route_segment(
			StringName(transfer.get("route_id", &"")), Array(transfer.get("route_segments", [])),
			Array(transfer.get("route_world_points", [])), int(transfer.get("progress_millis", 0)), int(transfer.get("total_millis", 0))
		)
		if unavailable_segment >= 0:
			if transfer_phase == &"TO_CAMP":
				var rerouted := _plan_blocked_camp_transfer_from_temporary_route(army, transfer)
				if not rerouted.is_empty():
					var rerouted_army := _army_registry.replace_blocked_transfer(army_id, order_id, rerouted)
					if not rerouted_army.is_empty():
						checkpoint_required = true
						continue
			var blocked_phase := &"TO_CAMP_BLOCKED" if transfer_phase in [&"TO_CAMP", &"TO_CAMP_BLOCKED"] else &"TO_RESUME_BLOCKED"
			if transfer_phase != blocked_phase:
				transfer.phase = blocked_phase
				if not _army_registry.replace_blocked_transfer(army_id, order_id, transfer).is_empty():
					checkpoint_required = true
			break
		if transfer_phase in [&"TO_CAMP_BLOCKED", &"TO_RESUME_BLOCKED"]:
			transfer.phase = &"TO_CAMP" if transfer_phase == &"TO_CAMP_BLOCKED" else &"TO_RESUME"
			if _army_registry.replace_blocked_transfer(army_id, order_id, transfer).is_empty():
				break
			checkpoint_required = true
			transfer_phase = StringName(transfer.phase)
		var transfer_result := _advance_blocked_transfer_elapsed_milliseconds(
			army_id, order_id, int(transfer.get("progress_millis", 0)), remaining_milliseconds
		)
		if transfer_result.is_empty():
			break
		final_result = transfer_result
		if not bool(transfer_result.get("arrived", false)):
			break
		checkpoint_required = true
		remaining_milliseconds = float(transfer_result.get("remaining_elapsed_milliseconds", 0.0))
		if transfer_phase == &"TO_CAMP":
			army = Dictionary(transfer_result.get("army", {}))
			macro = Dictionary(army.get("macro_march", {}))
			if _war_loop_state.field_tactics.first_unavailable_route_segment(
				StringName(macro.get("route_id", &"")), Array(macro.get("route_segments", [])),
				Array(macro.get("route_world_points", [])), int(macro.get("progress_millis", 0)), int(macro.get("total_millis", 0))
			) >= 0:
				break
			if _begin_blocked_return(army).is_empty():
				break
			continue
		# Returning to the frozen position atomically restored the original order.
		# Any time beyond that boundary belongs to the original order, not to the
		# now-cleared temporary transfer.
		if remaining_milliseconds > 0.000001:
			army = Dictionary(transfer_result.get("army", {}))
			macro = Dictionary(army.get("macro_march", {}))
			final_result = _advance_macro_march_elapsed_milliseconds(
				army_id, order_id, int(macro.get("progress_millis", 0)), remaining_milliseconds
			)
		break
	if checkpoint_required and not bool(_persist_macro_march_checkpoint().get("success", false)):
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return {}
	return final_result


func _advance_macro_march_elapsed_milliseconds(
	army_id: StringName,
	order_id: StringName,
	expected_progress_milliseconds: int,
	elapsed_milliseconds: float
) -> Dictionary:
	if city_time_paused:
		return {}
	var remainder_key := StringName("%s:%s" % [String(army_id), String(order_id)])
	var pending_milliseconds := float(_macro_march_frame_remainders_by_order.get(remainder_key, 0.0)) + elapsed_milliseconds
	var whole_milliseconds := floori(pending_milliseconds + 0.000001)
	_macro_march_frame_remainders_by_order[remainder_key] = maxf(
		pending_milliseconds - float(whole_milliseconds), 0.0
	)
	if whole_milliseconds <= 0:
		return {}
	var registry_before := _army_registry.get_snapshot()
	var war_before := _war_loop_state.get_snapshot()
	var result := _army_registry.advance_macro_march(
		army_id, order_id, expected_progress_milliseconds, whole_milliseconds
	)
	var arrival_committed := not result.is_empty() and bool(result.get("arrived", false))
	if arrival_committed:
		var arrived_army: Dictionary = result.army
		var target_id := StringName(Dictionary(arrived_army.macro_march).target_point_id)
		if _war_loop_state.is_enemy_city(target_id):
			var siege_result := _start_macro_siege(arrived_army)
			if not bool(siege_result.get("success", false)):
				_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
				return siege_result
			result = siege_result
	if not result.is_empty():
		_refresh_city_ui()
		city_state_changed.emit()
		# Siege setup or immediate surrender returns a richer result than the
		# marching operation, so preserve the arrival commit fact separately.
		if arrival_committed and not bool(_persist_macro_march_checkpoint().get("success", false)):
			_rollback_macro_march_registry(registry_before)
			_war_loop_state.restore_snapshot(war_before)
			return _macro_failure(&"SAVE_FAILED", "抵达状态存档失败，军令已回滚")
		if arrival_committed:
			_macro_march_frame_remainders_by_order.erase(remainder_key)
	return result.duplicate(true)


func advance_war_loop_time(delta_milliseconds: int) -> Dictionary:
	return _advance_war_loop_elapsed_milliseconds(
		float(delta_milliseconds) * city_time_speed
	)


func advance_war_loop_time_seconds(delta_seconds: float) -> Dictionary:
	return _advance_war_loop_elapsed_milliseconds(
		delta_seconds * 1000.0 * city_time_speed
	)


func set_field_supply_fault_for_test(fault_id: StringName) -> void:
	_field_supply_fault_for_test = fault_id


func set_field_reinforcement_fault_for_test(fault_id: StringName) -> void:
	_field_reinforcement_fault_for_test = fault_id


func set_field_watchtower_fault_for_test(fault_id: StringName) -> void:
	_field_watchtower_fault_for_test = fault_id


func set_wartime_session_checkpoint_fault_for_test(fault_id: StringName) -> void:
	_wartime_session_checkpoint_fault_for_test = fault_id


func set_city_strategy_fault_for_test(fault_id: StringName) -> void:
	_city_strategy_fault_for_test = fault_id


func _advance_war_loop_elapsed_milliseconds(elapsed_milliseconds: float) -> Dictionary:
	if city_time_paused or elapsed_milliseconds <= 0.0:
		return {}
	_ensure_war_loop_initialized()
	var pending_milliseconds := _war_loop_frame_remainder_milliseconds + elapsed_milliseconds
	var whole_milliseconds := floori(pending_milliseconds + 0.000001)
	_war_loop_frame_remainder_milliseconds = maxf(
		pending_milliseconds - float(whole_milliseconds), 0.0
	)
	if whole_milliseconds <= 0:
		return {}
	var registry_before := _army_registry.get_snapshot()
	var war_before := _war_loop_state.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var military_before := _current_military_population()
	var specialists_before := _current_alive_specialists()
	var configured_invasion := _war_loop_state.field_tactics.get_blackstone_invasion()
	var invasion_source_id := StringName(configured_invasion.get("source_point_id", &""))
	var invasion_source_controllers: Dictionary = {}
	if invasion_source_id != &"":
		invasion_source_controllers[invasion_source_id] = StringName(
			_war_loop_state.get_city(invasion_source_id).get(
				"military_controller_faction_id", &""
			)
		)
	var invasion_departures := _war_loop_state.field_tactics.resolve_configured_invasion_departures(
		current_day, invasion_source_controllers
	)
	var activated_invasion_ids: Array[StringName] = Array(
		invasion_departures.get("activated_invasion_ids", []),
		TYPE_STRING_NAME, &"", null
	)
	var cancelled_invasion_ids: Array[StringName] = Array(
		invasion_departures.get("cancelled_invasion_ids", []),
		TYPE_STRING_NAME, &"", null
	)
	var field_advance := _war_loop_state.field_tactics.advance_world(
		whole_milliseconds, _macro_army_world_positions(), _macro_march_traces_for_war_step
	)
	var encounter_result := _resolve_field_patrol_encounters(field_advance)
	if not bool(encounter_result.get("success", true)):
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return encounter_result
	if not Array(encounter_result.get("encounters", [])).is_empty():
		field_advance.patrol_encounters = Array(encounter_result.encounters).duplicate(true)
	var specialist_action_settlement := _resolve_ready_field_specialist_actions(
		Array(field_advance.get("ready_specialist_action_ids", []))
	)
	if not bool(specialist_action_settlement.get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return _macro_failure(&"SPECIALIST_ACTION_SETTLEMENT", "专员行动结算失败")
	if not Array(specialist_action_settlement.get("events", [])).is_empty():
		field_advance.specialist_action_events = Array(specialist_action_settlement.events).duplicate(true)
	if not activated_invasion_ids.is_empty():
		field_advance.activated_invasion_ids = activated_invasion_ids.duplicate()
	if not cancelled_invasion_ids.is_empty():
		field_advance.cancelled_invasion_ids = cancelled_invasion_ids.duplicate()
	var supply_settlement := _settle_arrived_supply_transports(
		Array(field_advance.get("ready_supply_transport_ids", []))
	)
	var resource_credits: Array = Array(specialist_action_settlement.get("committed_amounts", [])).duplicate(true)
	resource_credits.append_array(Array(supply_settlement.get("committed_amounts", [])))
	if not bool(supply_settlement.get("success", false)):
		_rollback_supply_delivery_transactions(resource_credits)
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return _macro_failure(&"SUPPLY_SETTLEMENT_FAILED", str(supply_settlement.get("error", "粮草入库未能提交")))
	var supply_checkpoint_required := _war_loop_state.field_tactics.consume_supply_checkpoint_required()
	var resumed_armies := _resume_macro_marches_on_repaired_roads()
	var field_checkpoint_required := (
		not activated_invasion_ids.is_empty()
		or not cancelled_invasion_ids.is_empty()
		or
		Array(field_advance.get("arrived_invasion_ids", [])).size() > 0
		or
		Array(field_advance.get("facility_events", [])).size() > 0
		or
		Array(field_advance.get("completed_project_ids", [])).size() > 0
		or Array(field_advance.get("opened_road_ids", [])).size() > 0
		or Array(field_advance.get("engagements", [])).size() > 0
		or Array(field_advance.get("patrol_encounters", [])).size() > 0
		or not resumed_armies.is_empty()
		or bool(supply_settlement.get("changed", false))
		or bool(specialist_action_settlement.get("changed", false))
		or supply_checkpoint_required
	)
	var completed_watchtower_checkpoint := false
	for completed_project_id_value in Array(field_advance.get("completed_project_ids", [])):
		var completed_project := Dictionary(_war_loop_state.field_tactics.projects_by_id.get(StringName(completed_project_id_value), {}))
		if StringName(completed_project.get("project_kind", &"")) == &"WATCHTOWER":
			completed_watchtower_checkpoint = true
			break
	var result: Dictionary = {}
	for siege_value in _war_loop_state.get_active_sieges():
		var siege: Dictionary = siege_value
		var city_id := StringName(siege.get("city_id", &""))
		for tick_result in _war_loop_state.advance_siege_elapsed(city_id, whole_milliseconds, WAR_LOOP_RULES):
			result = Dictionary(tick_result)
			var surviving_count := ceili(float(maxi(int(result.attacker_total_hp), 0)) / float(maxi(int(result.attacker_hp_per_member), 1)))
			if surviving_count <= 0:
				if StringName(result.phase) != WarLoopState.PHASE_FAILED:
					_rollback_supply_delivery_transactions(resource_credits)
					_war_loop_state.restore_snapshot(war_before)
					_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
					return _macro_failure(&"SIEGE_ZERO_SURVIVOR_STATE", "全灭攻城未进入失败状态")
				result = _close_lost_macro_siege(result, StringName("%s.lost" % String(result.siege_id)))
				if not bool(result.get("success", false)):
					_rollback_supply_delivery_transactions(resource_credits)
					_war_loop_state.restore_snapshot(war_before)
					_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
					return result
				break
			# The fault seam makes the existing production composition-sync failure
			# branch observable after a supply credit.  It deliberately returns an
			# empty registry result instead of adding a parallel test-only rollback.
			var army: Dictionary = {}
			if _field_supply_fault_for_test == &"SIEGE_ARMY_REPLACE_FAIL":
				_field_supply_fault_for_test = &""
			else:
				army = _army_registry.replace_macro_composition(
					StringName(result.army_id), StringName(result.order_id), surviving_count
				)
			if army.is_empty():
				_rollback_supply_delivery_transactions(resource_credits)
				_war_loop_state.restore_snapshot(war_before)
				_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
				return _macro_failure(&"SIEGE_ARMY_SYNC_FAILED", "攻城伤亡无法同步到军队")
			if StringName(result.phase) == WarLoopState.PHASE_OCCUPIED:
				result = _finalize_macro_occupation(result)
				break
			if StringName(result.phase) == WarLoopState.PHASE_FAILED:
				result = _resolve_failed_macro_siege(result)
				break
	var military_losses := maxi(military_before - _current_military_population(), 0)
	var specialist_losses := maxi(specialists_before - _current_alive_specialists(), 0)
	if military_losses + specialist_losses > 0:
		if not _population_recovery.record_fallen(military_losses + specialist_losses):
			_rollback_supply_delivery_transactions(resource_credits)
			_war_loop_state.restore_snapshot(war_before)
			_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
			_population_recovery.restore_snapshot(population_before)
			return _macro_failure(&"POPULATION_CASUALTY_FAILED", "战区人员损失无法写回人口状态")
		field_checkpoint_required = true
	if not result.is_empty() or field_checkpoint_required:
		_refresh_city_ui()
		city_state_changed.emit()
		var checkpoint_faulted := _field_supply_fault_for_test == &"CHECKPOINT_SAVE_FAILED" or (
			completed_watchtower_checkpoint and _field_watchtower_fault_for_test == &"COMPLETION_CHECKPOINT_SAVE_FAILED"
		)
		var checkpoint_success := not checkpoint_faulted and bool(_persist_macro_march_checkpoint().get("success", false))
		_field_supply_fault_for_test = &"" if _field_supply_fault_for_test == &"CHECKPOINT_SAVE_FAILED" else _field_supply_fault_for_test
		_field_watchtower_fault_for_test = &"" if completed_watchtower_checkpoint and _field_watchtower_fault_for_test == &"COMPLETION_CHECKPOINT_SAVE_FAILED" else _field_watchtower_fault_for_test
		if not checkpoint_success:
			_rollback_supply_delivery_transactions(resource_credits)
			_war_loop_state.restore_snapshot(war_before)
			_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
			_population_recovery.restore_snapshot(population_before)
			return _macro_failure(&"SAVE_FAILED", "战区关键状态存档失败，事务已回滚")
	if result.is_empty() and not resumed_armies.is_empty():
		field_advance.resumed_army_ids = resumed_armies
	if not result.is_empty():
		if not Array(field_advance.get("patrol_encounters", [])).is_empty():
			result.patrol_encounters = Array(field_advance.patrol_encounters).duplicate(true)
		if not Array(field_advance.get("engagements", [])).is_empty():
			result.field_engagements = Array(field_advance.engagements).duplicate(true)
	return result.duplicate(true) if not result.is_empty() else field_advance


func _settle_arrived_supply_transports(transport_ids: Array) -> Dictionary:
	var field: FieldTacticsState = _war_loop_state.field_tactics
	var committed_amounts: Array[Dictionary] = []
	var changed := false
	for transport_id_value in transport_ids:
		var transport_id := StringName(transport_id_value)
		var transport := field.get_supply_transport(transport_id)
		if transport.is_empty() or bool(transport.get("deposited", false)):
			continue
		var amount := int(transport.get("amount", 0))
		if amount <= 0:
			return {"success": false, "error": "运输货物数量无效", "committed_amounts": committed_amounts}
		if maxi(get_resource_capacity(&"food") - food, 0) < amount:
			changed = field.mark_supply_transport_waiting_capacity(transport_id) or changed
			continue
		var transaction := _nation_state.commit_resource_transaction(
			NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": amount}],
			&"field_supply_transport_delivery",
			func() -> Dictionary:
				return {"success": field.complete_supply_transport(transport_id)}
		)
		if not bool(transaction.get("success", false)):
			return {"success": false, "error": str(transaction.get("error", "粮草入库事务失败")), "committed_amounts": committed_amounts}
		committed_amounts.append({"transport_id": transport_id, "amount": amount})
		changed = true
	return {"success": true, "changed": changed, "committed_amounts": committed_amounts}


func _rollback_supply_delivery_transactions(committed_amounts: Array) -> void:
	for committed_value in committed_amounts:
		var committed: Dictionary = Dictionary(committed_value)
		var amount := int(committed.get("amount", 0))
		if amount <= 0:
			continue
		_nation_state.commit_resource_transaction(
			NationState.BLACKSTONE_CITY_ID,
			[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_SPEND, "amount": amount}],
			&"field_supply_transport_delivery_rollback"
		)


func _resolve_field_patrol_encounters(field_advance: Dictionary) -> Dictionary:
	var encounters: Array[Dictionary] = []
	var patrol_traces_by_id: Dictionary = {}
	for movement_value in Array(field_advance.get("patrol_movements", [])):
		var movement: Dictionary = Dictionary(movement_value)
		var patrol_id := StringName(movement.get("patrol_id", &""))
		if patrol_id == &"":
			continue
		if not patrol_traces_by_id.has(patrol_id):
			patrol_traces_by_id[patrol_id] = []
		patrol_traces_by_id[patrol_id].append({
			"from": Vector2(movement.get("from", Vector2.ZERO)),
			"to": Vector2(movement.get("to", Vector2.ZERO)),
			"start_milliseconds": float(movement.get("start_offset_milliseconds", 0)),
			"end_milliseconds": float(movement.get("end_offset_milliseconds", field_advance.get("delta_milliseconds", 0))),
		})
	var guard_ids_by_patrol: Dictionary = {}
	for specialist_contact_value in Array(field_advance.get("engagements", [])):
		var specialist_contact: Dictionary = Dictionary(specialist_contact_value)
		var patrol_id := StringName(specialist_contact.get("patrol_id", &""))
		if not guard_ids_by_patrol.has(patrol_id):
			guard_ids_by_patrol[patrol_id] = []
		for army_id_value in Array(specialist_contact.get("guard_army_ids", [])):
			var army_id := StringName(army_id_value)
			if army_id != &"" and army_id not in guard_ids_by_patrol[patrol_id]:
				guard_ids_by_patrol[patrol_id].append(army_id)
	var field: FieldTacticsState = _war_loop_state.field_tactics
	for patrol_id_value in field.patrols_by_id.keys():
		var patrol_id := StringName(patrol_id_value)
		var patrol: Dictionary = Dictionary(field.patrols_by_id[patrol_id])
		if (
			int(patrol.get("strength", 0)) <= 0
			or StringName(patrol.get("phase", &"")) == FieldTacticsState.INVASION_CANCELLED
		):
			continue
		var resolved_ids: Array = Array(patrol.get("resolved_army_ids", []))
		var participant_ids: Array[StringName] = []
		var contact_milliseconds_by_army: Dictionary = {}
		var army_positions := _macro_army_world_positions()
		var patrol_trace: Array = Array(patrol_traces_by_id.get(patrol_id, []))
		for army_id_value in army_positions.keys():
			var army_id := StringName(army_id_value)
			if army_id in resolved_ids:
				continue
			var army := _army_registry.get_army(army_id)
			if army.is_empty() or StringName(army.get("phase", &"")) not in [ArmyRegistry.PHASE_MARCHING, ArmyRegistry.PHASE_BLOCKED, ArmyRegistry.PHASE_STATIONED, ArmyRegistry.PHASE_RETREATING]:
				continue
			var step_milliseconds := float(field_advance.get("delta_milliseconds", 0))
			var army_trace: Array = Array(_macro_march_traces_for_war_step.get(
				army_id, _stationary_timed_trace(Vector2(army_positions[army_id]), step_milliseconds)
			))
			var contact_milliseconds := INF
			if not patrol_trace.is_empty():
				contact_milliseconds = field.first_timed_contact_milliseconds(army_trace, patrol_trace, 32.0)
			if contact_milliseconds == INF and Vector2(army_positions[army_id]).distance_to(Vector2(patrol.get("world_position", Vector2.ZERO))) <= 32.0:
				# A stationary patrol has no movement segment this step. Its contact is
				# therefore the explicit end-of-step overlap, not a guessed path crossing.
				contact_milliseconds = step_milliseconds
			if contact_milliseconds < INF:
				participant_ids.append(army_id)
				contact_milliseconds_by_army[army_id] = contact_milliseconds
		for guard_id_value in Array(guard_ids_by_patrol.get(patrol_id, [])):
			var guard_id := StringName(guard_id_value)
			if guard_id not in resolved_ids and guard_id not in participant_ids:
				participant_ids.append(guard_id)
		participant_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
		if participant_ids.is_empty():
			continue
		var total_army_strength := 0
		var army_strength_before_by_army: Dictionary = {}
		for army_id in participant_ids:
			var army_strength_before := _macro_army_member_count(_army_registry.get_army(army_id))
			army_strength_before_by_army[army_id] = army_strength_before
			total_army_strength += army_strength_before
		if total_army_strength <= 0:
			continue
		var ambush_army_ids: Array[StringName] = []
		var consumed_ambush_ids: Array = Array(patrol.get("ambush_consumed_army_ids", []))
		var intel := field.observe_subject(patrol_id)
		for army_id in participant_ids:
			var army := _army_registry.get_army(army_id)
			var macro: Dictionary = Dictionary(army.get("macro_march", {}))
			var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
			var is_deployed := StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED or (StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED and StringName(transfer.get("phase", &"")) == &"WAITING")
			if is_deployed and army_id not in consumed_ambush_ids and StringName(intel.get("fog_state", FieldTacticsState.FOG_UNOBSERVED)) != FieldTacticsState.FOG_UNOBSERVED and field.position_has_terrain_kind(Vector2(army_positions[army_id]), &"FOREST"):
				ambush_army_ids.append(army_id)
		var patrol_strength_before := int(patrol.get("strength", 0))
		var patrol_losses := mini(patrol_strength_before, maxi(1, ceili(float(total_army_strength) / 3.0)) + ambush_army_ids.size() * 2)
		var army_losses_remaining := mini(total_army_strength, maxi(1, ceili(float(patrol_strength_before) / 2.0) - ambush_army_ids.size()))
		var losses_by_army: Dictionary = {}
		while army_losses_remaining > 0:
			var allocated := false
			for army_id in participant_ids:
				var capacity := _macro_army_member_count(_army_registry.get_army(army_id))
				var assigned := int(losses_by_army.get(army_id, 0))
				if assigned >= capacity:
					continue
				losses_by_army[army_id] = assigned + 1
				army_losses_remaining -= 1
				allocated = true
				if army_losses_remaining == 0:
					break
			if not allocated:
				break
		var formation_losses_by_army: Dictionary = {}
		var army_strength_after_by_army: Dictionary = {}
		var army_phase_after_by_army: Dictionary = {}
		for army_id in participant_ids:
			var army := _army_registry.get_army(army_id)
			var macro: Dictionary = Dictionary(army.get("macro_march", {}))
			var remaining_loss := int(losses_by_army.get(army_id, 0))
			var fortress := field.fortress_for_army(army_id)
			if not fortress.is_empty() and remaining_loss > 0:
				var reduction := clampi(int(fortress.get("garrison_casualty_reduction_permille", 0)), 0, 1000)
				var prevented := mini(remaining_loss, floori(float(remaining_loss * reduction) / 1000.0))
				if prevented > 0 and field.absorb_fortress_casualties(StringName(fortress.get("watchtower_id", &"")), prevented):
					remaining_loss -= prevented
			var formation_losses: Dictionary = {}
			var formations: Array = Array(macro.get("formation_snapshots", []))
			for formation_index in range(formations.size() - 1, -1, -1):
				var formation: Dictionary = Dictionary(formations[formation_index])
				var loss := mini(remaining_loss, int(formation.get("member_count", 0)))
				if loss > 0:
					formation_losses[StringName(formation.get("formation_id", &""))] = loss
					remaining_loss -= loss
			if not formation_losses.is_empty():
				var updated_army := _army_registry.apply_macro_formation_losses(army_id, StringName(macro.get("order_id", &"")), formation_losses)
				if updated_army.is_empty():
					return _macro_failure(&"FIELD_CASUALTY_SYNC_FAILED", "野外交战伤亡无法同步到军队")
				if _macro_army_member_count(updated_army) == 0:
					updated_army = _army_registry.close_macro_field_lost(army_id, StringName(macro.get("order_id", &"")), StringName("field.%s.%d.%s" % [String(patrol_id), int(field_advance.get("world_milliseconds", 0)), String(army_id)]))
					if updated_army.is_empty():
						return _macro_failure(&"FIELD_ARMY_CLOSE_FAILED", "野外交战全灭军队无法关闭")
					if not fortress.is_empty():
						field.release_fortress_garrison(StringName(fortress.get("watchtower_id", &"")), army_id)
			formation_losses_by_army[army_id] = formation_losses
			var army_after := _army_registry.get_army(army_id)
			army_strength_after_by_army[army_id] = _macro_army_member_count(army_after)
			army_phase_after_by_army[army_id] = StringName(army_after.get("phase", &""))
		var contact_milliseconds := float(field_advance.get("delta_milliseconds", 0))
		for contact_value in contact_milliseconds_by_army.values():
			contact_milliseconds = minf(contact_milliseconds, float(contact_value))
		var contact_world_position := Vector2(patrol.get("world_position", Vector2.ZERO))
		if not patrol_trace.is_empty():
			contact_world_position = field.timed_trace_position_at(patrol_trace, contact_milliseconds)
		var encounter := {
			"patrol_id": patrol_id,
			"army_ids": participant_ids.duplicate(),
			"ambush_army_ids": ambush_army_ids.duplicate(),
			"patrol_strength_before": patrol_strength_before,
			"patrol_losses": patrol_losses,
			"patrol_strength_after": patrol_strength_before - patrol_losses,
			"army_strength_before_by_army": army_strength_before_by_army,
			"army_strength_after_by_army": army_strength_after_by_army,
			"army_phase_after_by_army": army_phase_after_by_army,
			"formation_losses_by_army": formation_losses_by_army,
			# V5 snapshots deliberately admit only durable scalar types. The timed
			# solver returns a float for geometry precision, while the persisted event
			# records the nearest authoritative millisecond just like world time.
			"contact_milliseconds": roundi(contact_milliseconds),
			# The per-step contact offset is useful to reconstruct the trace, but it
			# naturally differs when the same world interval is split into frames.
			# Persist the matching world-clock instant for reports, diagnostics and
			# deterministic comparison without introducing another combat clock.
			"contact_world_milliseconds": int(field_advance.get("world_milliseconds", 0)) - int(field_advance.get("delta_milliseconds", 0)) + roundi(contact_milliseconds),
			"contact_world_position": Vector2i(contact_world_position),
			"world_position": Vector2i(contact_world_position),
			"world_milliseconds": int(field_advance.get("world_milliseconds", 0)),
		}
		# A patrol that has reached an army guarding a nearby field work can damage
		# that work without requiring its sampled position to land on the road's
		# centreline. This matches the same local protection/contact scale used for
		# engineers and remains far below map-wide influence.
		var damaged_road_id := field.damage_nearest_engineered_road(Vector2(encounter.world_position), 72.0, 999999)
		encounter.damaged_road_id = damaged_road_id
		if field.apply_patrol_encounter(patrol_id, participant_ids, patrol_losses, ambush_army_ids, encounter).is_empty():
			return _macro_failure(&"PATROL_SETTLEMENT_FAILED", "巡逻交战状态无法提交")
		encounters.append(encounter)
	return {"success": true, "encounters": encounters}


func _macro_army_world_positions() -> Dictionary:
	var result: Dictionary = {}
	for army_value in get_macro_march_armies():
		var army: Dictionary = Dictionary(army_value)
		if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_CLOSED:
			continue
		var macro: Dictionary = Dictionary(army.get("macro_march", {}))
		var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
		var points: Array = Array(macro.get("route_world_points", []))
		var progress := int(macro.get("progress_millis", 0))
		var total := int(macro.get("total_millis", 1))
		if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED and StringName(transfer.get("phase", &"")) in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"WAITING", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
			points = Array(transfer.get("route_world_points", []))
			progress = int(transfer.get("progress_millis", 0))
			total = int(transfer.get("total_millis", 1))
		result[StringName(army.get("army_id", &""))] = Vector2i(_world_position_along_points(points, float(progress) / maxf(float(total), 1.0)))
	return result


func _macro_army_movement_traces(before_armies: Array[Dictionary], after_armies: Array[Dictionary], step_milliseconds: float) -> Dictionary:
	var before_by_id: Dictionary = {}
	for army in before_armies:
		before_by_id[StringName(army.get("army_id", &""))] = army
	var traces: Dictionary = {}
	for after_army in after_armies:
		var army_id := StringName(after_army.get("army_id", &""))
		var before_army: Dictionary = Dictionary(before_by_id.get(army_id, {}))
		if before_army.is_empty():
			continue
		var before_motion := _macro_army_motion_state(before_army)
		var after_motion := _macro_army_motion_state(after_army)
		if before_motion.is_empty() or after_motion.is_empty():
			continue
		var before_points: Array = Array(before_motion.points)
		var after_points: Array = Array(after_motion.points)
		if before_points == after_points and int(after_motion.progress) >= int(before_motion.progress):
			traces[army_id] = _timed_segments_between_progress(
				before_points, int(before_motion.progress), int(after_motion.progress),
				maxi(int(before_motion.total), 1), step_milliseconds
			)
		else:
			traces[army_id] = [{
				"from": Vector2(before_motion.position), "to": Vector2(after_motion.position),
				"start_milliseconds": 0.0, "end_milliseconds": step_milliseconds,
			}]
	return traces


func _timed_segments_between_progress(points: Array, start_milliseconds: int, end_milliseconds: int, total_milliseconds: int, step_milliseconds: float) -> Array:
	var start_progress := float(start_milliseconds) / maxf(float(total_milliseconds), 1.0)
	var end_progress := float(end_milliseconds) / maxf(float(total_milliseconds), 1.0)
	var trace_points := _world_points_between_progress(points, start_progress, end_progress)
	var movement_milliseconds := minf(maxf(float(end_milliseconds - start_milliseconds), 0.0), step_milliseconds)
	var trace_length := 0.0
	for index in range(1, trace_points.size()):
		trace_length += Vector2(trace_points[index - 1]).distance_to(Vector2(trace_points[index]))
	var segments: Array = []
	var elapsed := 0.0
	for index in range(1, trace_points.size()):
		var from := Vector2(trace_points[index - 1])
		var to := Vector2(trace_points[index])
		var segment_milliseconds := movement_milliseconds * from.distance_to(to) / maxf(trace_length, 0.0001)
		segments.append({
			"from": from, "to": to,
			"start_milliseconds": elapsed, "end_milliseconds": elapsed + segment_milliseconds,
		})
		elapsed += segment_milliseconds
	var final_position := Vector2(trace_points.back()) if not trace_points.is_empty() else _world_position_along_points(points, end_progress)
	if segments.is_empty() or movement_milliseconds < step_milliseconds - 0.0001:
		segments.append({
			"from": final_position, "to": final_position,
			"start_milliseconds": movement_milliseconds, "end_milliseconds": step_milliseconds,
		})
	return segments


func _stationary_timed_trace(position: Vector2, step_milliseconds: float) -> Array:
	return [{
		"from": position, "to": position,
		"start_milliseconds": 0.0, "end_milliseconds": step_milliseconds,
	}]


func _macro_army_motion_state(army: Dictionary) -> Dictionary:
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	if macro.is_empty():
		return {}
	var points: Array = Array(macro.get("route_world_points", []))
	var progress := int(macro.get("progress_millis", 0))
	var total := maxi(int(macro.get("total_millis", 0)), 1)
	var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
	if StringName(army.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED and StringName(transfer.get("phase", &"")) in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"WAITING", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
		points = Array(transfer.get("route_world_points", []))
		progress = int(transfer.get("progress_millis", 0))
		total = maxi(int(transfer.get("total_millis", 0)), 1)
	if points.is_empty():
		return {}
	return {
		"points": points.duplicate(true), "progress": progress, "total": total,
		"position": _world_position_along_points(points, float(progress) / float(total)),
	}


func _world_points_between_progress(points: Array, start_progress: float, end_progress: float) -> Array:
	if points.size() < 2:
		return points.duplicate(true)
	var total_length := 0.0
	var cumulative: Array[float] = [0.0]
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
		cumulative.append(total_length)
	if total_length <= 0.0001:
		return [Vector2(points.front()), Vector2(points.back())]
	var start_distance := total_length * clampf(start_progress, 0.0, 1.0)
	var end_distance := total_length * clampf(end_progress, 0.0, 1.0)
	var result: Array = [_world_position_along_points(points, start_progress)]
	for index in range(1, points.size() - 1):
		if cumulative[index] > start_distance + 0.0001 and cumulative[index] < end_distance - 0.0001:
			result.append(Vector2(points[index]))
	result.append(_world_position_along_points(points, end_progress))
	return result


func _macro_army_member_count(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _world_position_along_points(points: Array, progress: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total_length := 0.0
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	var remaining_length := total_length * clampf(progress, 0.0, 1.0)
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var length := start.distance_to(end)
		if remaining_length <= length:
			return start.lerp(end, remaining_length / maxf(length, 1.0))
		remaining_length -= length
	return Vector2(points.back())


func _distance_to_world_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var squared := segment.length_squared()
	if squared <= 0.0001:
		return point.distance_to(start)
	return point.distance_to(start + segment * clampf((point - start).dot(segment) / squared, 0.0, 1.0))


func _world_traces_within_distance(first: Array, second: Array, distance: float) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	if first.size() == 1:
		first = [first.front(), first.front()]
	if second.size() == 1:
		second = [second.front(), second.front()]
	for first_index in range(1, first.size()):
		var first_start := Vector2(first[first_index - 1])
		var first_end := Vector2(first[first_index])
		for second_index in range(1, second.size()):
			var second_start := Vector2(second[second_index - 1])
			var second_end := Vector2(second[second_index])
			if Geometry2D.segment_intersects_segment(first_start, first_end, second_start, second_end) != null:
				return true
			if minf(
				minf(_distance_to_world_segment(first_start, second_start, second_end), _distance_to_world_segment(first_end, second_start, second_end)),
				minf(_distance_to_world_segment(second_start, first_start, first_end), _distance_to_world_segment(second_end, first_start, first_end))
			) <= distance:
				return true
	return false


func _timed_movement_segments_within_distance(first: Array, second: Array, distance: float) -> bool:
	for first_value in first:
		var first_segment: Dictionary = Dictionary(first_value)
		var first_start_time := float(first_segment.get("start_milliseconds", 0.0))
		var first_end_time := float(first_segment.get("end_milliseconds", first_start_time))
		for second_value in second:
			var second_segment: Dictionary = Dictionary(second_value)
			var overlap_start := maxf(first_start_time, float(second_segment.get("start_milliseconds", 0.0)))
			var overlap_end := minf(first_end_time, float(second_segment.get("end_milliseconds", overlap_start)))
			if overlap_end < overlap_start - 0.0001:
				continue
			var first_from := Vector2(first_segment.get("from", Vector2.ZERO))
			var first_to := Vector2(first_segment.get("to", first_from))
			var second_from := Vector2(second_segment.get("from", Vector2.ZERO))
			var second_to := Vector2(second_segment.get("to", second_from))
			var first_duration := maxf(first_end_time - first_start_time, 0.0001)
			var second_start_time := float(second_segment.get("start_milliseconds", 0.0))
			var second_end_time := float(second_segment.get("end_milliseconds", second_start_time))
			var second_duration := maxf(second_end_time - second_start_time, 0.0001)
			var first_at_start := first_from.lerp(first_to, clampf((overlap_start - first_start_time) / first_duration, 0.0, 1.0))
			var first_at_end := first_from.lerp(first_to, clampf((overlap_end - first_start_time) / first_duration, 0.0, 1.0))
			var second_at_start := second_from.lerp(second_to, clampf((overlap_start - second_start_time) / second_duration, 0.0, 1.0))
			var second_at_end := second_from.lerp(second_to, clampf((overlap_end - second_start_time) / second_duration, 0.0, 1.0))
			var relative_start := first_at_start - second_at_start
			var relative_delta := (first_at_end - second_at_end) - relative_start
			var closest_ratio := 0.0
			if relative_delta.length_squared() > 0.000001:
				closest_ratio = clampf(-relative_start.dot(relative_delta) / relative_delta.length_squared(), 0.0, 1.0)
			if relative_start.lerp(relative_start + relative_delta, closest_ratio).length() <= distance:
				return true
	return false


func _block_macro_march_for_damaged_road(army: Dictionary, blocked_road_segment_index: int) -> Dictionary:
	var macro: Dictionary = army.get("macro_march", {})
	var army_id := StringName(army.get("army_id", &""))
	var order_id := StringName(macro.get("order_id", &""))
	if army_id == &"" or order_id == &"":
		return {}
	var transfer := _plan_blocked_camp_transfer(army, blocked_road_segment_index)
	var registry_before := _army_registry.get_snapshot()
	var blocked := _army_registry.block_macro_march(
		army_id, order_id, blocked_road_segment_index, int(macro.get("progress_millis", 0)),
		StringName(transfer.get("target_point_id", &"受损道路前等待")), transfer
	)
	if blocked.is_empty():
		return {}
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return {}
	_refresh_city_ui()
	city_state_changed.emit()
	return blocked


func _plan_blocked_camp_transfer(army: Dictionary, blocked_segment_index: int) -> Dictionary:
	var macro: Dictionary = army.get("macro_march", {})
	var field: FieldTacticsState = _war_loop_state.field_tactics
	var best: Dictionary = {}
	for candidate_id in _friendly_station_candidate_ids(macro):
		var plan := field.plan_runtime_path_from_progress(Array(macro.get("route_segments", [])), int(macro.get("total_millis", 0)), int(macro.get("progress_millis", 0)), candidate_id)
		if not bool(plan.get("valid", false)):
			continue
		if best.is_empty() or int(plan.get("duration_milliseconds", 0)) < int(best.get("total_millis", 0)) or (int(plan.get("duration_milliseconds", 0)) == int(best.get("total_millis", 0)) and String(candidate_id) < String(best.get("target_point_id", &""))):
			best = {"phase": &"TO_CAMP", "target_point_id": candidate_id, "route_id": StringName(plan.get("route_id", &"")), "route_segments": Array(plan.get("segments", [])).duplicate(true), "route_world_points": Array(plan.get("points", [])).duplicate(true), "progress_millis": 0, "total_millis": int(plan.get("duration_milliseconds", 0)), "resume_progress_millis": int(macro.get("progress_millis", 0))}
	return best


func _plan_blocked_camp_transfer_from_temporary_route(army: Dictionary, transfer: Dictionary) -> Dictionary:
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var best: Dictionary = {}
	for candidate_id in _friendly_station_candidate_ids(macro):
		var plan := _war_loop_state.field_tactics.plan_runtime_path_from_progress(
			Array(transfer.get("route_segments", [])), int(transfer.get("total_millis", 0)),
			int(transfer.get("progress_millis", 0)), candidate_id
		)
		if not bool(plan.get("valid", false)):
			continue
		if best.is_empty() or int(plan.get("duration_milliseconds", 0)) < int(best.get("total_millis", 0)) or (int(plan.get("duration_milliseconds", 0)) == int(best.get("total_millis", 0)) and String(candidate_id) < String(best.get("target_point_id", &""))):
			best = {
				"phase": &"TO_CAMP",
				"target_point_id": candidate_id,
				"route_id": StringName(plan.get("route_id", &"")),
				"route_segments": Array(plan.get("segments", [])).duplicate(true),
				"route_world_points": Array(plan.get("points", [])).duplicate(true),
				"progress_millis": 0,
				"total_millis": int(plan.get("duration_milliseconds", 0)),
				"resume_progress_millis": int(transfer.get("resume_progress_millis", macro.get("progress_millis", 0))),
			}
	return best


func _friendly_station_candidate_ids(macro: Dictionary) -> Array[StringName]:
	var candidate_ids: Array[StringName] = []
	var field: FieldTacticsState = _war_loop_state.field_tactics
	for point_id_value in MACRO_MARCH_THEATER.get_points():
		var point_id := StringName(point_id_value)
		var point: Dictionary = Dictionary(MACRO_MARCH_THEATER.get_points()[point_id_value])
		# R0 authored garrisons predate the explicit FRIENDLY_GARRISON tag.
		# Treat every non-enemy authored point except this order's originating city
		# as a lawful existing station; runtime camps are added below.
		if point_id != StringName(macro.get("source_point_id", &"")) and StringName(point.get("point_kind", &"")) != &"ENEMY_CITY":
			candidate_ids.append(point_id)
	for point_id_value in field.get_runtime_points():
		if StringName(point_id_value) not in candidate_ids:
			candidate_ids.append(StringName(point_id_value))
	candidate_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return candidate_ids


func _begin_blocked_return(army: Dictionary) -> Dictionary:
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
	if StringName(transfer.get("phase", &"")) != &"WAITING":
		return {}
	var return_points: Array = Array(transfer.get("route_world_points", [])).duplicate(true)
	return_points.reverse()
	if return_points.size() < 2:
		return {}
	var return_segments: Array = []
	for segment_value in Array(transfer.get("route_segments", [])):
		var segment: Dictionary = Dictionary(segment_value).duplicate(true)
		segment.forward = not bool(segment.get("forward", false))
		if segment.has("route_world_points"):
			var segment_points: Array = Array(segment.get("route_world_points", [])).duplicate(true)
			segment_points.reverse()
			segment.route_world_points = segment_points
		if segment.has("source_point_id") or segment.has("target_point_id"):
			var previous_source := StringName(segment.get("source_point_id", &""))
			segment.source_point_id = StringName(segment.get("target_point_id", &""))
			segment.target_point_id = previous_source
		return_segments.push_front(segment)
	transfer.phase = &"TO_RESUME"
	transfer.route_world_points = return_points
	transfer.route_segments = return_segments
	transfer.progress_millis = 0
	return _army_registry.replace_blocked_transfer(
		StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), transfer
	)


func _resume_macro_marches_on_repaired_roads() -> Array[StringName]:
	var resumed: Array[StringName] = []
	for army_value in get_macro_march_armies():
		var army: Dictionary = army_value
		if StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_BLOCKED:
			continue
		var macro: Dictionary = army.get("macro_march", {})
		var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
		var transfer_phase := StringName(transfer.get("phase", &""))
		if transfer_phase in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
			var transfer_unavailable := _war_loop_state.field_tactics.first_unavailable_route_segment(
				StringName(transfer.get("route_id", &"")), Array(transfer.get("route_segments", [])),
				Array(transfer.get("route_world_points", [])), int(transfer.get("progress_millis", 0)), int(transfer.get("total_millis", 0))
			)
			if transfer_unavailable >= 0:
				continue
			if transfer_phase in [&"TO_CAMP_BLOCKED", &"TO_RESUME_BLOCKED"]:
				transfer.phase = &"TO_CAMP" if transfer_phase == &"TO_CAMP_BLOCKED" else &"TO_RESUME"
				var unblocked_army := _army_registry.replace_blocked_transfer(
					StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), transfer
				)
				if not unblocked_army.is_empty():
					resumed.append(StringName(unblocked_army.get("army_id", &"")))
				continue
		if _war_loop_state.field_tactics.first_unavailable_route_segment(
			StringName(macro.get("route_id", &"")), Array(macro.get("route_segments", [])),
			Array(macro.get("route_world_points", [])), int(macro.get("progress_millis", 0)), int(macro.get("total_millis", 0))
		) >= 0:
			continue
		if StringName(transfer.get("phase", &"")) == &"WAITING":
			# The temporary route is the authoritative record of how this army
			# reached the camp. Reverse its exact clipped geometry to return to the
			# frozen original-route position before resuming the original order.
			var returning_army := _begin_blocked_return(army)
			if not returning_army.is_empty():
				# Include a state transition in this checkpoint list: the caller
				# persists it through the same formal event path as a resume.
				resumed.append(StringName(returning_army.get("army_id", &"")))
				continue
		if StringName(transfer.get("phase", &"")) in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
			continue
		var resumed_army := _army_registry.resume_blocked_macro_march(
			StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &""))
		)
		if not resumed_army.is_empty():
			resumed.append(StringName(resumed_army.get("army_id", &"")))
	return resumed


func _macro_segment_at_progress(macro: Dictionary) -> int:
	var points: Array = macro.get("route_world_points", [])
	var total_millis := maxi(int(macro.get("total_millis", 0)), 1)
	var progress_millis := clampi(int(macro.get("progress_millis", 0)), 0, total_millis)
	var total_length := 0.0
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	var progressed_length := total_length * float(progress_millis) / float(total_millis)
	var consumed_length := 0.0
	for index in range(1, points.size()):
		consumed_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
		if progressed_length <= consumed_length:
			return index
	return maxi(points.size() - 1, 1)


func request_macro_siege_retreat(city_id: StringName = &"") -> Dictionary:
	var war_before := _war_loop_state.get_snapshot()
	var registry_before := _army_registry.get_snapshot()
	var target_city_id := city_id
	if target_city_id == &"":
		target_city_id = StringName(_war_loop_state.active_siege.get("city_id", &""))
	var failed := _war_loop_state.mark_retreat_at(target_city_id, WAR_LOOP_RULES)
	if failed.is_empty():
		return _macro_failure(&"RETREAT_UNAVAILABLE", "当前没有可撤逃的攻城军令")
	var surviving_count := ceili(float(maxi(int(failed.attacker_total_hp), 0)) / float(maxi(int(failed.attacker_hp_per_member), 1)))
	var army := _army_registry.replace_macro_composition(
		StringName(failed.army_id), StringName(failed.order_id),
		surviving_count
	)
	if surviving_count <= 0:
		var lost := _close_lost_macro_siege(failed, StringName("%s.retreat_lost" % String(failed.siege_id)))
		if not bool(lost.get("success", false)):
			_war_loop_state.restore_snapshot(war_before)
			_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
			return lost
		if not bool(_persist_macro_march_checkpoint().get("success", false)):
			_war_loop_state.restore_snapshot(war_before)
			_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
			return _macro_failure(&"SAVE_FAILED", "撤逃全灭状态存档失败，事务已回滚")
		_refresh_city_ui()
		city_state_changed.emit()
		return lost
	var retreating := _army_registry.begin_macro_retreat(StringName(failed.army_id), StringName(failed.order_id))
	var resolution_id := StringName("%s.retreat" % String(failed.siege_id))
	_war_loop_state.close_failed_siege_at(target_city_id, resolution_id)
	if army.is_empty() or retreating.is_empty():
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return _macro_failure(&"RETREAT_FAILED", "撤逃事务未能提交")
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return _macro_failure(&"SAVE_FAILED", "撤逃状态存档失败，事务已回滚")
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "army": retreating.duplicate(true), "siege": failed.duplicate(true)}


func _resolve_failed_macro_siege(failed: Dictionary) -> Dictionary:
	var surviving_count := ceili(float(maxi(int(failed.attacker_total_hp), 0)) / float(maxi(int(failed.attacker_hp_per_member), 1)))
	if surviving_count <= 0:
		return _close_lost_macro_siege(failed, StringName("%s.lost" % String(failed.siege_id)))
	var retreating := _army_registry.begin_macro_retreat(StringName(failed.army_id), StringName(failed.order_id))
	if retreating.is_empty():
		return _macro_failure(&"SIEGE_RETREAT_FAILED", "战败撤退路线未能建立")
	var resolution_id := StringName("%s.failed" % String(failed.siege_id))
	_war_loop_state.close_failed_siege_at(StringName(failed.city_id), resolution_id)
	return {"success": true, "army": retreating.duplicate(true), "siege": failed.duplicate(true)}


func _close_lost_macro_siege(failed: Dictionary, resolution_id: StringName) -> Dictionary:
	var closed := _army_registry.close_macro_lost(
		StringName(failed.army_id), StringName(failed.order_id), resolution_id
	)
	if closed.is_empty():
		return _macro_failure(&"SIEGE_LOSS_CLOSE_FAILED", "全灭军队状态未能关闭")
	var resolved := _war_loop_state.close_failed_siege_at(StringName(failed.city_id), resolution_id)
	if resolved.is_empty():
		return _macro_failure(&"SIEGE_LOSS_RESOLUTION_FAILED", "全灭攻城结算未能关闭")
	return {"success": true, "army": closed.duplicate(true), "siege": resolved.duplicate(true)}


func block_macro_march_at_segment(
	army_id: StringName,
	order_id: StringName,
	segment_index: int,
	progress_before_segment_millis: int,
	temporary_station_point: StringName
) -> Dictionary:
	var army_before := _army_registry.get_army(army_id)
	if army_before.is_empty() or not is_macro_march_route_blocked(
		StringName(Dictionary(army_before.macro_march).route_id)
	):
		return _macro_failure(&"ROAD_OPEN", "道路尚未进入受阻状态")
	var registry_before := _army_registry.get_snapshot()
	var result := _army_registry.block_macro_march(
		army_id, order_id, segment_index, progress_before_segment_millis,
		temporary_station_point
	)
	if result.is_empty():
		return {}
	_refresh_city_ui()
	city_state_changed.emit()
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_rollback_macro_march_registry(registry_before)
		return _macro_failure(&"SAVE_FAILED", "受阻驻扎存档失败，军令已回滚")
	return result


func resume_blocked_macro_march(army_id: StringName, order_id: StringName) -> Dictionary:
	var registry_before := _army_registry.get_snapshot()
	var result := _army_registry.resume_blocked_macro_march(army_id, order_id)
	if result.is_empty():
		return {}
	_refresh_city_ui()
	city_state_changed.emit()
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_rollback_macro_march_registry(registry_before)
		return _macro_failure(&"SAVE_FAILED", "恢复军令存档失败，军令已回滚")
	return result


func _persist_macro_march_checkpoint() -> Dictionary:
	var root := get_parent()
	if root != null and root.has_method("persist_macro_march_checkpoint"):
		_last_campaign_checkpoint_result = root.persist_macro_march_checkpoint().duplicate(true)
		return _last_campaign_checkpoint_result.duplicate(true)
	if DisplayServer.get_name() == "headless":
		return {"success": true, "headless_test_store_disabled": true}
	return {"success": false}


func _rollback_macro_march_issue(
	food_cost: int,
	garrison_before: Dictionary,
	registry_before: Dictionary
) -> void:
	var local_rollback := func() -> Dictionary:
		if not garrison_before.is_empty():
			_garrison_state.restore_persistence_snapshot(garrison_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		return {"success": true}
	_nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{"resource_id": &"food", "operation": NationState.RESOURCE_OPERATION_ADD, "amount": food_cost}],
		&"macro_march_rollback", local_rollback
	)


func _rollback_macro_march_registry(registry_before: Dictionary) -> void:
	_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
	_refresh_city_ui()
	city_state_changed.emit()
	_refresh_city_ui()
	city_state_changed.emit()


func _macro_failure(error_id: StringName, error: String) -> Dictionary:
	return {"success": false, "error_id": error_id, "error": error}


func reserve_army_dispatch(
	committed_count: int,
	target_node_id: StringName,
	route_id: StringName,
	duration_milliseconds: int
) -> Dictionary:
	if (
		not _active_army_dispatch_reservation.is_empty()
		or _army_registry.has_active_army()
		or not _army_registry.can_allocate_stable_id()
		or not _active_battle_reservation.is_empty()
		or committed_count <= 0
		or committed_count > get_dispatchable_infantry_count()
		or target_node_id == &""
		or target_node_id == &"blackstone_city"
		or route_id == &""
		or duration_milliseconds <= 0
	):
		return {}
	var transaction_id := StringName(
		"dispatch.blackstone.%06d"
		% _next_army_dispatch_transaction_sequence
	)
	_next_army_dispatch_transaction_sequence += 1
	_active_army_dispatch_reservation = {
		"transaction_id": transaction_id,
		"committed_count": committed_count,
		"source_node_id": &"blackstone_city",
		"target_node_id": target_node_id,
		"route_id": route_id,
		"duration_milliseconds": duration_milliseconds,
	}
	_refresh_city_ui()
	city_state_changed.emit()
	return _active_army_dispatch_reservation.duplicate(true)


func cancel_army_dispatch(transaction_id: StringName) -> bool:
	if (
		_active_army_dispatch_reservation.is_empty()
		or StringName(
			_active_army_dispatch_reservation.transaction_id
		) != transaction_id
	):
		return false
	_active_army_dispatch_reservation = {}
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func confirm_army_dispatch(transaction_id: StringName) -> Dictionary:
	if (
		_active_army_dispatch_reservation.is_empty()
		or StringName(
			_active_army_dispatch_reservation.transaction_id
		) != transaction_id
		or _army_registry.has_active_army()
	):
		return {}
	var reservation := _active_army_dispatch_reservation.duplicate(true)
	var registry_before := _army_registry.get_snapshot()
	var garrison_before := infantry_count
	var units := {
		INFANTRY_ROLE.role_id: int(reservation.committed_count),
	}
	var army := _army_registry.create_reserved(
		&"player",
		&"blackstone_city",
		StringName(reservation.source_node_id),
		StringName(reservation.target_node_id),
		StringName(reservation.route_id),
		units,
		int(reservation.duration_milliseconds),
		transaction_id
	)
	if army.is_empty():
		return {}
	if not _garrison_state.try_remove_units(
		INFANTRY_ROLE.role_id,
		int(reservation.committed_count)
	):
		_army_registry.restore_snapshot(
			registry_before,
			get_unit_definition_ids()
		)
		return {}
	if not _army_registry.transition(
		StringName(army.army_id),
		transaction_id,
		ArmyRegistry.PHASE_RESERVED,
		ArmyRegistry.PHASE_MARCHING
	):
		_garrison_state.set_unit_count(
			INFANTRY_ROLE.role_id,
			garrison_before
		)
		_army_registry.restore_snapshot(
			registry_before,
			get_unit_definition_ids()
		)
		return {}
	_active_army_dispatch_reservation = {}
	_refresh_city_ui()
	city_state_changed.emit()
	return _army_registry.get_army(StringName(army.army_id))


func get_active_army_dispatch_reservation() -> Dictionary:
	return _active_army_dispatch_reservation.duplicate(true)


func get_army_registry_snapshot() -> Dictionary:
	return _army_registry.get_snapshot().duplicate(true)


func get_army_state(army_id: StringName) -> Dictionary:
	return _army_registry.get_army(army_id)


## Creates or reconstructs the C0 request for an already-active macro siege.
## It never reserves city troops or food: the macro army and its original
## formation snapshots remain the only source of committed force facts.
func prepare_macro_siege_battle_request(
	army_id: StringName,
	city_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> BattleRequest:
	_ensure_war_loop_initialized()
	if not is_combat_transaction_coordinator_bound(coordinator):
		return null
	var army := _army_registry.get_army(army_id)
	var siege := _war_loop_state.get_siege(city_id)
	if (
		army.is_empty()
		or siege.is_empty()
		or StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_SIEGING
		or StringName(siege.get("phase", &"")) != WarLoopState.PHASE_SIEGING
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(Dictionary(army.get("macro_march", {})).get("order_id", &""))
			!= StringName(siege.get("order_id", &""))
	):
		return null
	var transaction_id := StringName("wartime.%s" % String(siege.get("siege_id", &"")))
	if transaction_id == &"wartime.":
		return null
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if not handoff.is_empty() and StringName(handoff.get("transaction_id", &"")) != transaction_id:
		return null
	var request: BattleRequest = null
	if handoff.is_empty():
		request = _build_macro_siege_battle_request(army, siege, transaction_id)
		if request == null:
			return null
		var request_snapshot := _get_macro_siege_request_snapshot(request)
		if request_snapshot.is_empty():
			return null
		var war_before := _war_loop_state.get_snapshot()
		if _war_loop_state.begin_wartime_handoff(city_id, transaction_id, request_snapshot).is_empty():
			return null
		if not bool(_persist_macro_march_checkpoint().get("success", false)):
			_war_loop_state.restore_snapshot(war_before)
			return null
		handoff = _war_loop_state.get_wartime_handoff(city_id)
	else:
		var request_snapshot: Dictionary = Dictionary(handoff.get("battle_request_snapshot", {}))
		if request_snapshot.is_empty():
			# A schema-five active handoff did not retain its initial request.  Its
			# one-time migration freezes the only recoverable current facts before
			# reopening the C0 scene; new handoffs never take this branch.
			var legacy_request := _build_macro_siege_battle_request(army, siege, transaction_id)
			if legacy_request == null:
				return null
			request_snapshot = _get_macro_siege_request_snapshot(legacy_request)
			if request_snapshot.is_empty():
				return null
			var war_before := _war_loop_state.get_snapshot()
			if _war_loop_state.materialize_legacy_wartime_request(
				city_id, transaction_id, request_snapshot
			).is_empty():
				return null
			if not bool(_persist_macro_march_checkpoint().get("success", false)):
				_war_loop_state.restore_snapshot(war_before)
				return null
			handoff = _war_loop_state.get_wartime_handoff(city_id)
		request = _build_macro_siege_battle_request_from_snapshot(transaction_id, request_snapshot)
		if request == null:
			return null
	if StringName(handoff.get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_ACTIVE:
		request.phase = BattleRequest.PHASE_ACTIVE
	elif StringName(handoff.get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_RESULT_PENDING:
		request.phase = BattleRequest.PHASE_RESULT_PENDING
	return request


## The macro army has already paid its departure cost.  This is deliberately
## separate from commit_wartime_facility_plan(), which owns an expedition
## attempt: a siege plan spends only its own construction resources and is
## persisted into the one frozen macro handoff request before activation.
func commit_macro_siege_wartime_facility_plan(
	army_id: StringName,
	city_id: StringName,
	transaction_id: StringName,
	plan_snapshot: Dictionary
) -> Dictionary:
	_ensure_war_loop_initialized()
	var army := _army_registry.get_army(army_id)
	var siege := _war_loop_state.get_siege(city_id)
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if (
		army.is_empty()
		or siege.is_empty()
		or transaction_id == &""
		or StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_SIEGING
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(siege.get("phase", &"")) != WarLoopState.PHASE_SIEGING
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WarLoopState.WARTIME_HANDOFF_RESERVED
	):
		return _macro_failure(&"WARTIME_PLAN_STATE", "当前围城不能修改战时工事")
	var plan_validation := WartimeFacilityPlan.validate_for_new_submission(
		plan_snapshot, BattleRequest.SOURCE_MACRO_SIEGE
	)
	if not bool(plan_validation.get("valid", false)):
		return _macro_failure(&"WARTIME_PLAN_INVALID", str(plan_validation.get("error", "战时工事非法")))
	var construction_request := _build_macro_siege_battle_request_from_snapshot(
		transaction_id, Dictionary(handoff.get("battle_request_snapshot", {}))
	)
	if construction_request == null:
		return _macro_failure(&"WARTIME_PLAN_REQUEST", "围城战时请求缺失，无法核对施工分队")
	plan_validation = WartimeFacilityPlan.validate_for_committed_squads(
		Dictionary(plan_validation.get("snapshot", {})), construction_request.committed_force.squads
	)
	if not bool(plan_validation.get("valid", false)):
		return _macro_failure(&"WARTIME_PLAN_CREW", str(plan_validation.get("error", "施工分队非法")))
	var normalized_plan: Dictionary = Dictionary(plan_validation.snapshot).duplicate(true)
	if Array(normalized_plan.get("facilities", [])).is_empty():
		return _macro_failure(&"WARTIME_PLAN_EMPTY", "请至少选择一项战时工事")
	var request_snapshot: Dictionary = Dictionary(handoff.get("battle_request_snapshot", {}))
	if request_snapshot.is_empty():
		return _macro_failure(&"WARTIME_PLAN_REQUEST", "围城战时请求缺失，无法确认工事")
	if not Array(Dictionary(request_snapshot.get("wartime_facility_plan", {})).get("facilities", [])).is_empty():
		return _macro_failure(&"WARTIME_PLAN_LOCKED", "战时工事已经确认，不能重复扣费")
	var costs := WartimeFacilityPlan.get_costs(normalized_plan)
	if costs.is_empty():
		return _macro_failure(&"WARTIME_PLAN_COST", "战时工事费用无法计算")
	var operations: Array[Dictionary] = []
	for resource_id_value in costs.keys():
		operations.append({
			"resource_id": StringName(resource_id_value),
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": int(costs[resource_id_value]),
		})
	var updated_request := request_snapshot.duplicate(true)
	updated_request.wartime_facility_plan = normalized_plan.duplicate(true)
	var war_before := _war_loop_state.get_snapshot()
	var install_plan := func() -> Dictionary:
		var current_siege := _war_loop_state.get_siege(city_id)
		var current_handoff := _war_loop_state.get_wartime_handoff(city_id)
		if (
			current_siege.is_empty()
			or StringName(current_siege.get("army_id", &"")) != army_id
			or StringName(current_handoff.get("transaction_id", &"")) != transaction_id
			or StringName(current_handoff.get("phase", &"")) != WarLoopState.WARTIME_HANDOFF_RESERVED
			or not Array(
				Dictionary(
					Dictionary(current_handoff.get("battle_request_snapshot", {})).get(
						"wartime_facility_plan", {}
					)
				).get("facilities", [])
			).is_empty()
		):
			return {"success": false}
		return {
			"success": not _war_loop_state.replace_reserved_wartime_request_snapshot(
				city_id, transaction_id, updated_request
			).is_empty()
		}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		operations,
		&"macro_wartime_facility_preparation",
		install_plan
	)
	if not bool(transaction.get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		return _macro_failure(
			StringName(transaction.get("error_id", &"WARTIME_PLAN_RESOURCE")),
			str(transaction.get("error", "战时工事资源不足"))
		)
	_refresh_city_ui()
	city_state_changed.emit()
	if bool(_persist_macro_march_checkpoint().get("success", false)):
		return {"success": true, "plan": normalized_plan.duplicate(true)}
	var refund_operations: Array[Dictionary] = []
	for resource_id_value in costs.keys():
		refund_operations.append({
			"resource_id": StringName(resource_id_value),
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": int(costs[resource_id_value]),
		})
	var rollback := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		refund_operations,
		&"macro_wartime_facility_preparation_rollback",
		func() -> Dictionary:
			_war_loop_state.restore_snapshot(war_before)
			return {"success": true}
	)
	if not bool(rollback.get("success", false)):
		push_error("Macro wartime facility plan rollback failed")
	_refresh_city_ui()
	city_state_changed.emit()
	return _macro_failure(&"SAVE_FAILED", "战时工事保存失败，资源与计划已回滚")


## Repair changes the active BattleSession only after this one resource
## transaction succeeds. C0 immediately checkpoints the changed session and
## calls the paired refund if that checkpoint cannot be published.
func commit_wartime_facility_repair_cost(
	transaction_id: StringName,
	facility_kind: StringName
) -> Dictionary:
	if transaction_id == &"":
		return _macro_failure(&"WARTIME_REPAIR_STATE", "战时工事维修来源无效")
	var active_attempt := (
		not _expedition_attempt.is_empty()
		and StringName(_expedition_attempt.get("attempt_id", &"")) == transaction_id
		and StringName(_expedition_attempt.get("phase", &"")) == BATTLE_PHASE_ACTIVE
	)
	# `active_siege` is only the legacy primary projection.  A battle launched
	# from a parallel macro siege is equally entitled to repair its own
	# facilities, so authenticate the immutable handoff transaction against all
	# current siege records rather than accidentally rejecting it by UI order.
	var active_handoff := false
	for siege_value in _war_loop_state.get_active_sieges():
		var siege: Dictionary = Dictionary(siege_value)
		var handoff: Dictionary = Dictionary(siege.get("wartime_handoff", {}))
		if (
			StringName(handoff.get("transaction_id", &"")) == transaction_id
			and StringName(handoff.get("phase", &"")) == WarLoopState.WARTIME_HANDOFF_ACTIVE
		):
			active_handoff = true
			break
	if not active_attempt and not active_handoff:
		return _macro_failure(&"WARTIME_REPAIR_STATE", "当前没有可维修的活动战时实例")
	var costs := WartimeFacilityPlan.get_repair_costs(facility_kind)
	if costs.is_empty():
		return _macro_failure(&"WARTIME_REPAIR_KIND", "该战时工事不能维修")
	var operations: Array[Dictionary] = []
	for resource_id_value in costs.keys():
		operations.append({
			"resource_id": StringName(resource_id_value),
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": int(costs[resource_id_value]),
		})
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID, operations, &"wartime_facility_repair"
	)
	if not bool(transaction.get("success", false)):
		return _macro_failure(StringName(transaction.get("error_id", &"WARTIME_REPAIR_RESOURCE")), str(transaction.get("error", "维修资源不足")))
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "costs": costs.duplicate(true)}


func rollback_wartime_facility_repair_cost(costs: Dictionary) -> bool:
	var operations: Array[Dictionary] = []
	for resource_id_value in costs.keys():
		operations.append({
			"resource_id": StringName(resource_id_value),
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": int(costs[resource_id_value]),
		})
	if operations.is_empty():
		return false
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID, operations, &"wartime_facility_repair_rollback"
	)
	_refresh_city_ui()
	city_state_changed.emit()
	return bool(transaction.get("success", false))


## The city gate is the protection mission's real target, so its temporary
## battle repair spends from the same city resource authority as facilities.
## C0 checkpoints the matching session state immediately after this commit and
## invokes the paired refund if that checkpoint cannot be published.
func commit_wartime_protect_target_repair_cost(
	transaction_id: StringName
) -> Dictionary:
	if transaction_id == &"":
		return _macro_failure(&"WARTIME_GATE_REPAIR_STATE", "城门维修来源无效")
	var active_attempt := (
		not _expedition_attempt.is_empty()
		and StringName(_expedition_attempt.get("attempt_id", &"")) == transaction_id
		and StringName(_expedition_attempt.get("phase", &"")) == BATTLE_PHASE_ACTIVE
		and StringName(_expedition_attempt.get("source_id", &""))
			== BattleRequest.SOURCE_WARTIME_DEFENSE
	)
	if not active_attempt:
		return _macro_failure(&"WARTIME_GATE_REPAIR_STATE", "当前没有可维修的战时城门")
	var costs := {&"wood": BattleSession.PROTECT_TARGET_REPAIR_WOOD_COST}
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{
			"resource_id": &"wood",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": BattleSession.PROTECT_TARGET_REPAIR_WOOD_COST,
		}],
		&"wartime_protect_target_repair"
	)
	if not bool(transaction.get("success", false)):
		return _macro_failure(
			StringName(transaction.get("error_id", &"WARTIME_GATE_REPAIR_RESOURCE")),
			str(transaction.get("error", "城门维修资源不足"))
		)
	_refresh_city_ui()
	city_state_changed.emit()
	return {"success": true, "costs": costs}


func rollback_wartime_protect_target_repair_cost(costs: Dictionary) -> bool:
	var wood: Variant = costs.get(&"wood", null)
	if typeof(wood) != TYPE_INT or int(wood) != BattleSession.PROTECT_TARGET_REPAIR_WOOD_COST:
		return false
	var transaction := _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{
			"resource_id": &"wood",
			"operation": NationState.RESOURCE_OPERATION_ADD,
			"amount": int(wood),
		}],
		&"wartime_protect_target_repair_rollback"
	)
	_refresh_city_ui()
	city_state_changed.emit()
	return bool(transaction.get("success", false))


func _build_macro_siege_battle_request(
	army: Dictionary,
	siege: Dictionary,
	transaction_id: StringName
) -> BattleRequest:
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var strategy: Dictionary = Dictionary(macro.get("strategy_snapshot", {}))
	var frozen_tech_ids: Array[StringName] = researched_tech_ids.duplicate()
	if strategy.has("tech_ids"):
		frozen_tech_ids.assign(Array(strategy.tech_ids))
	var source_formations: Array = Array(macro.get("formation_snapshots", []))
	# C0 currently renders a bounded number of independent squad controls. Never
	# merge or discard a macro formation merely to fit that presentation.
	if source_formations.is_empty() or source_formations.size() > CommittedForceSnapshot.MAX_SQUADS:
		return null
	var formations: Array[Dictionary] = []
	for source in source_formations:
		if not source is Dictionary:
			return null
		var formation: Dictionary = Dictionary(source)
		# A formal early counterattack can suffer a real field interception before
		# reaching Redcliff. Keep surviving original formations, but do not pass an
		# already-empty formation to the battle snapshot or invent replacements.
		if int(formation.get("member_count", 0)) <= 0:
			continue
		formations.append({
			"formation_id": StringName(formation.get("formation_id", &"")),
			"display_name": str(formation.get("display_name", "军队")),
			"definition_id": StringName(formation.get("definition_id", &"")),
			"member_count": int(formation.get("member_count", 0)),
			"max_members": int(formation.get("max_members", 0)),
			"squad_id": formations.size() + 1,
			"route_id": CommittedForceSnapshot.FRONT_ROUTE,
		})
	var committed := CommittedForceSnapshot.create_from_formations(
		transaction_id,
		formations,
		INFANTRY_ROLE,
		StringName(strategy.get("general_id", selected_general_id)),
		frozen_tech_ids,
		float(strategy.get("attack_basis_points", roundi(get_infantry_attack_multiplier() * 10000.0))) / 10000.0,
		float(strategy.get("defense_basis_points", roundi(get_infantry_defense_multiplier() * 10000.0))) / 10000.0,
		bool(strategy.get("supply_shortage", supply_shortage))
	)
	if committed == null:
		return null
	var defender_count := ceili(float(maxi(int(siege.get("defender_total_hp", 0)), 0)) / float(maxi(int(siege.get("defender_hp_per_member", 1)), 1)))
	if defender_count <= 0:
		return null
	var enemy := EnemyForceSnapshot.new()
	enemy.transaction_id = transaction_id
	enemy.snapshot_day = current_day
	enemy.enemy_count = defender_count
	enemy.fortification_level = 0
	enemy.route_states = {
		EnemyForceSnapshot.FRONT_ROUTE: {
			"enemy_members": defender_count,
			"gate_hp": int(siege.get("gate_hp", 0)),
		},
		EnemyForceSnapshot.SIDE_ROUTE: {
			"enemy_members": 0,
			"gate_hp": 0,
		},
	}
	var city_id := StringName(siege.get("city_id", &""))
	var request := BattleRequest.new(
		transaction_id,
		StringName("macro_siege.%s" % String(city_id)),
		current_day,
		committed,
		enemy,
		false,
		0,
		0,
		BattleRequest.SOURCE_MACRO_SIEGE,
		StringName("macro_siege.%s" % String(siege.get("siege_id", &""))),
		0,
		0
	)
	# This captures the exact macro damage state at handoff. The C0 session uses
	# it once on construction instead of silently rebuilding full-health squads.
	request.macro_siege_start_state = {
		"attacker_total_hp": int(siege.get("attacker_total_hp", 0)),
		"defender_total_hp": int(siege.get("defender_total_hp", 0)),
		"gate_hp": int(siege.get("gate_hp", 0)),
	}
	return request if request.is_valid() else null


## New handoffs persist this compact request fact before C0 receives control.
## It freezes the general, tech, supply and enemy snapshot rather than deriving
## a different battle when a calendar day or city selection changes on restore.
func _get_macro_siege_request_snapshot(request: BattleRequest) -> Dictionary:
	if request == null or not request.is_valid() or request.source_id != BattleRequest.SOURCE_MACRO_SIEGE:
		return {}
	return {
		"level_id": request.level_id,
		"created_day": request.created_day,
		"committed_force_snapshot": request.committed_force.to_dictionary(),
		"enemy_force_snapshot": request.enemy_force.to_dictionary(),
		"city_defense_snapshot": request.city_defense_snapshot,
		"first_clear_key": request.first_clear_key,
		"wartime_facility_plan": request.wartime_facility_plan.duplicate(true),
		"macro_siege_start_state": request.macro_siege_start_state.duplicate(true),
	}


func _build_macro_siege_battle_request_from_snapshot(
	transaction_id: StringName,
	snapshot: Dictionary
) -> BattleRequest:
	var expected_keys := [
		"level_id", "created_day", "committed_force_snapshot", "enemy_force_snapshot",
		"city_defense_snapshot", "first_clear_key", "wartime_facility_plan", "macro_siege_start_state",
	]
	if snapshot.size() != expected_keys.size():
		return null
	for key in expected_keys:
		if not snapshot.has(key):
			return null
	if (
		typeof(snapshot.level_id) != TYPE_STRING_NAME
		or typeof(snapshot.created_day) != TYPE_INT
		or typeof(snapshot.committed_force_snapshot) != TYPE_DICTIONARY
		or typeof(snapshot.enemy_force_snapshot) != TYPE_DICTIONARY
		or typeof(snapshot.city_defense_snapshot) != TYPE_INT
		or typeof(snapshot.first_clear_key) != TYPE_STRING_NAME
		or typeof(snapshot.wartime_facility_plan) != TYPE_DICTIONARY
		or typeof(snapshot.macro_siege_start_state) != TYPE_DICTIONARY
		or StringName(snapshot.level_id) == &""
		or int(snapshot.created_day) <= 0
		or int(snapshot.city_defense_snapshot) < 0
		or StringName(snapshot.first_clear_key) == &""
	):
		return null
	var committed := CommittedForceSnapshot.from_dictionary(Dictionary(snapshot.committed_force_snapshot))
	var enemy := EnemyForceSnapshot.from_dictionary(Dictionary(snapshot.enemy_force_snapshot))
	var start_state: Dictionary = Dictionary(snapshot.macro_siege_start_state)
	if (
		committed == null
		or enemy == null
		or committed.transaction_id != transaction_id
		or enemy.transaction_id != transaction_id
		or not _has_valid_macro_siege_combat_state(start_state)
	):
		return null
	var request := BattleRequest.new(
		transaction_id,
		StringName(snapshot.level_id),
		int(snapshot.created_day),
		committed,
		enemy,
		false,
		0,
		int(snapshot.city_defense_snapshot),
		BattleRequest.SOURCE_MACRO_SIEGE,
		StringName(snapshot.first_clear_key),
		0,
		0,
		null,
		Dictionary(snapshot.wartime_facility_plan)
	)
	request.macro_siege_start_state = start_state.duplicate(true)
	return request if request.is_valid() else null


func _has_valid_macro_siege_combat_state(state: Dictionary) -> bool:
	var expected_keys := ["attacker_total_hp", "defender_total_hp", "gate_hp"]
	if state.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not state.has(key) or typeof(state.get(key, null)) != TYPE_INT or int(state.get(key, -1)) < 0:
			return false
	return true


func authorize_macro_siege_battle_activation(
	army_id: StringName,
	city_id: StringName,
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return false
	var siege := _war_loop_state.get_siege(city_id)
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if (
		siege.is_empty()
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WarLoopState.WARTIME_HANDOFF_RESERVED
	):
		return false
	var war_before := _war_loop_state.get_snapshot()
	if _war_loop_state.set_wartime_handoff_phase(
		city_id, transaction_id, WarLoopState.WARTIME_HANDOFF_ACTIVE
	).is_empty():
		return false
	if bool(_persist_macro_march_checkpoint().get("success", false)):
		return true
	_war_loop_state.restore_snapshot(war_before)
	return false


func cancel_reserved_macro_siege_battle(
	army_id: StringName,
	city_id: StringName,
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return false
	var siege := _war_loop_state.get_siege(city_id)
	if siege.is_empty() or StringName(siege.get("army_id", &"")) != army_id:
		return false
	var war_before := _war_loop_state.get_snapshot()
	if _war_loop_state.cancel_reserved_wartime_handoff(city_id, transaction_id).is_empty():
		return false
	if bool(_persist_macro_march_checkpoint().get("success", false)):
		return true
	_war_loop_state.restore_snapshot(war_before)
	return false


func authorize_macro_siege_battle_result_pending(
	army_id: StringName,
	city_id: StringName,
	transaction_id: StringName,
	result_authority_snapshot: Dictionary,
	terminal_combat_state: Dictionary,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return false
	var siege := _war_loop_state.get_siege(city_id)
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	if (
		siege.is_empty()
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(handoff.get("transaction_id", &"")) != transaction_id
		or StringName(handoff.get("phase", &"")) != WarLoopState.WARTIME_HANDOFF_ACTIVE
		or result_authority_snapshot.is_empty()
		or not _has_valid_macro_siege_combat_state(terminal_combat_state)
	):
		return false
	var result := BattleResult.from_authority_snapshot(result_authority_snapshot)
	if (
		not result.is_consistent()
		or result.transaction_id != transaction_id
		or result.session_id != StringName("%s-session" % transaction_id)
	):
		return false
	var war_before := _war_loop_state.get_snapshot()
	if _war_loop_state.mark_wartime_handoff_result_pending(
		city_id, transaction_id, result_authority_snapshot, terminal_combat_state
	).is_empty():
		return false
	if bool(_persist_macro_march_checkpoint().get("success", false)):
		return true
	_war_loop_state.restore_snapshot(war_before)
	return false


func checkpoint_macro_siege_battle_session(
	army_id: StringName,
	city_id: StringName,
	transaction_id: StringName,
	session_snapshot: Dictionary
) -> Dictionary:
	var siege := _war_loop_state.get_siege(city_id)
	if siege.is_empty() or StringName(siege.get("army_id", &"")) != army_id:
		return _macro_failure(&"WARTIME_HANDOFF", "围城战时实例来源已失效")
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	var request := _build_macro_siege_battle_request_from_snapshot(
		transaction_id, Dictionary(handoff.get("battle_request_snapshot", {}))
	)
	if request != null:
		request.phase = BattleRequest.PHASE_ACTIVE
	var session_probe := BattleSession.new(request)
	if request == null or not session_probe.restore_snapshot(session_snapshot):
		return _macro_failure(&"WARTIME_SESSION_INVALID", "围城战时实例快照非法")
	var war_before := _war_loop_state.get_snapshot()
	if _war_loop_state.checkpoint_wartime_handoff_session(
		city_id, transaction_id, session_snapshot
	).is_empty():
		return _macro_failure(&"WARTIME_SESSION_STATE", "围城战时实例状态不允许保存")
	var checkpoint_faulted := _wartime_session_checkpoint_fault_for_test == &"CHECKPOINT_SAVE_FAILED"
	_wartime_session_checkpoint_fault_for_test = (
		&"" if checkpoint_faulted else _wartime_session_checkpoint_fault_for_test
	)
	if not checkpoint_faulted and bool(_persist_macro_march_checkpoint().get("success", false)):
		return {"success": true}
	_war_loop_state.restore_snapshot(war_before)
	return _macro_failure(&"SAVE_FAILED", "围城战时实例存档失败，已保留上次检查点")


func get_active_armies() -> Array[Dictionary]:
	return _army_registry.get_active_armies()


func advance_army_strategic_time(
	army_id: StringName,
	transaction_id: StringName,
	expected_progress_milliseconds: int,
	delta_milliseconds: int
) -> Dictionary:
	var result := _army_registry.advance_progress(
		army_id,
		transaction_id,
		expected_progress_milliseconds,
		delta_milliseconds
	)
	if result.is_empty():
		return {}
	_refresh_city_ui()
	city_state_changed.emit()
	return result.duplicate(true)


func mark_army_settlement_pending(
	army_id: StringName,
	transaction_id: StringName
) -> bool:
	var changed := _army_registry.transition(
		army_id,
		transaction_id,
		ArmyRegistry.PHASE_ARRIVED,
		ArmyRegistry.PHASE_SETTLEMENT_PENDING
	)
	if changed:
		_refresh_city_ui()
		city_state_changed.emit()
	return changed


func get_committed_world_infantry_total() -> int:
	return (
		infantry_count
		+ _army_registry.get_total_active_units(
			INFANTRY_ROLE.role_id
		)
		+ _army_registry.get_total_stationed_units(
			INFANTRY_ROLE.role_id
		)
	)


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


func _accept_combat_transaction_coordinator_binding(
	coordinator: CombatTransactionCoordinator
) -> bool:
	if coordinator == null or not coordinator.is_bound_to_city(self):
		return false
	if _designated_combat_transaction_coordinator == coordinator:
		return true
	if _designated_combat_transaction_coordinator != null:
		return false
	_designated_combat_transaction_coordinator = coordinator
	return true


func is_combat_transaction_coordinator_bound(
	coordinator: CombatTransactionCoordinator
) -> bool:
	return (
		coordinator != null
		and _designated_combat_transaction_coordinator == coordinator
		and coordinator.is_bound_to_city(self)
	)


func authorize_prepared_battle_request(
	request: BattleRequest,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if (
		not is_combat_transaction_coordinator_bound(coordinator)
		or request == null
		or not request.is_valid()
		or not request.formal_city_entry
		or request.is_noticeboard_mission()
		or request.source_id not in [&"FIRST_WAR", BattleRequest.SOURCE_WARTIME_DEFENSE]
		or not _is_durable_expedition_reservation()
		or StringName(_expedition_attempt.get("attempt_id", &""))
			!= request.transaction_id
		or StringName(_expedition_attempt.get("mainline_id", &""))
			!= request.level_id
		or StringName(_expedition_attempt.get("source_id", &"FIRST_WAR"))
			!= request.source_id
		or StringName(_expedition_attempt.get("mission_id", &""))
			!= (
				request.mission_definition.mission_id
				if request.mission_definition != null
				else &""
			)
		or StringName(_expedition_attempt.get("phase", &""))
			!= request.phase
		or int(_expedition_attempt.get("created_day", 0))
			!= request.created_day
		or int(_expedition_attempt.get("food_cost", -1))
			!= request.committed_food_cost
		or int(_expedition_attempt.get("city_defense_snapshot", -1))
			!= request.city_defense_snapshot
		or StringName(_expedition_attempt.get("first_clear_key", &""))
			!= request.first_clear_key
		or int(_expedition_attempt.get("reward_wood", -1))
			!= request.reward_wood
		or int(_expedition_attempt.get("reward_food", -1))
			!= request.reward_food
		or Dictionary(
			_expedition_attempt.get("committed_force_snapshot", {})
		) != request.committed_force.to_dictionary()
		or Dictionary(
			_expedition_attempt.get("enemy_force_snapshot", {})
		) != request.enemy_force.to_dictionary()
		or Dictionary(
			_expedition_attempt.get("wartime_facility_plan", {})
		) != request.wartime_facility_plan
	):
		return false
	return true


func authorize_army_encounter_activation(
	army_id: StringName,
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if (
		not is_combat_transaction_coordinator_bound(coordinator)
		or not _active_army_encounter.is_empty()
	):
		return false
	var army := _army_registry.get_army(army_id)
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase)
			!= ArmyRegistry.PHASE_SETTLEMENT_PENDING
	):
		return false
	_active_army_encounter = {
		"army_id": army_id,
		"transaction_id": transaction_id,
		"phase": BATTLE_PHASE_ACTIVE,
	}
	return true


func authorize_army_encounter_result_pending(
	army_id: StringName,
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if (
		not is_combat_transaction_coordinator_bound(coordinator)
		or _active_army_encounter.is_empty()
		or StringName(_active_army_encounter.army_id) != army_id
		or StringName(_active_army_encounter.transaction_id)
			!= transaction_id
		or StringName(_active_army_encounter.phase)
			!= BATTLE_PHASE_ACTIVE
	):
		return false
	_active_army_encounter.phase = BATTLE_PHASE_RESULT_PENDING
	return true


func reserve_battle_force(
	committed_count: int,
	coordinator: CombatTransactionCoordinator
) -> StringName:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return &""
	if (
		not _active_battle_reservation.is_empty()
		or committed_count <= 0
		or committed_count > get_dispatchable_infantry_count()
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


func activate_battle_reservation(
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return false
	return _transition_battle_reservation(
		transaction_id,
		BATTLE_PHASE_RESERVED,
		BATTLE_PHASE_ACTIVE
	)


func mark_battle_result_pending(
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return false
	# A durable city battle must publish its terminal authority together with the
	# RESULT_PENDING phase. Otherwise a cold restore would pair a pending result
	# with only the last ACTIVE checkpoint and either replay a battle tick or
	# reject the state as internally inconsistent.
	if _is_durable_expedition_reservation():
		if (
			coordinator.active_session == null
			or not coordinator.active_session.completed
			or _expedition_attempt.is_empty()
			or StringName(_expedition_attempt.get("attempt_id", &""))
				!= transaction_id
		):
			return false
		var terminal_result_snapshot := (
			coordinator.active_session.get_terminal_result_snapshot()
		)
		var terminal_result := BattleResult.from_authority_snapshot(
			terminal_result_snapshot
		)
		if (
			terminal_result == null
			or not terminal_result.is_consistent()
			or terminal_result.transaction_id != transaction_id
		):
			return false
		var prior_terminal_result: Dictionary = Dictionary(
			_expedition_attempt.get("terminal_result_snapshot", {})
		).duplicate(true)
		if not _transition_battle_reservation(
			transaction_id,
			BATTLE_PHASE_ACTIVE,
			BATTLE_PHASE_RESULT_PENDING
		):
			return false
		_expedition_attempt.terminal_result_snapshot = terminal_result_snapshot.duplicate(true)
		var persisted := _persist_active_battle_checkpoint(transaction_id)
		if bool(persisted.get("success", false)):
			return true
		_expedition_attempt.terminal_result_snapshot = prior_terminal_result
		_transition_battle_reservation(
			transaction_id,
			BATTLE_PHASE_RESULT_PENDING,
			BATTLE_PHASE_ACTIVE
		)
		if bool(persisted.get("uncertain", false)):
			_expedition_commit_blocked = true
		return false
	return _transition_battle_reservation(
		transaction_id,
		BATTLE_PHASE_ACTIVE,
		BATTLE_PHASE_RESULT_PENDING
	)


func cancel_battle_reservation(
	transaction_id: StringName,
	coordinator: CombatTransactionCoordinator
) -> bool:
	if not is_combat_transaction_coordinator_bound(coordinator):
		return false
	if (
		_active_battle_reservation.is_empty()
		or StringName(_active_battle_reservation.transaction_id)
			!= transaction_id
		or StringName(_active_battle_reservation.phase)
			!= BATTLE_PHASE_RESERVED
	):
		return false
	# A durable R1E expedition has already paid food and published its immutable
	# attempt. It can only finish through battle settlement; the old transient
	# reservation cancellation path must never erase or refund it.
	if _is_durable_expedition_reservation():
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
	if _is_durable_expedition_reservation():
		_expedition_attempt.phase = next_phase
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func apply_battle_result_atomic(
	transaction_id: StringName,
	result_id: StringName
) -> Dictionary:
	if not is_combat_transaction_coordinator_bound(
		_designated_combat_transaction_coordinator
	):
		return {}
	var settlement := _designated_combat_transaction_coordinator.get_authorized_settlement_for_bound_city(
		transaction_id,
		result_id
	)
	if settlement.is_empty():
		return {}
	var battle_result: BattleResult = settlement.get("battle_result")
	var request: BattleRequest = settlement.get("request")
	var army_id := StringName(settlement.get("army_id", &""))
	var macro_siege_city_id := StringName(settlement.get("macro_siege_city_id", &""))
	if (
		battle_result == null
		or request == null
	):
		return {}
	if macro_siege_city_id != &"":
		return _apply_macro_siege_battle_result_atomic(
			battle_result, request, army_id, macro_siege_city_id
		)
	if army_id != &"":
		return _apply_army_battle_result_atomic(
			battle_result,
			request,
			army_id
		)
	if _committed_battle_result_ids.has(battle_result.result_id):
		var committed_summary := get_committed_battle_result_summary(
			battle_result.result_id
		)
		if (
			StringName(committed_summary.get("transaction_id", &""))
				== battle_result.transaction_id
			and request.transaction_id == battle_result.transaction_id
			and StringName(committed_summary.get("session_id", &""))
				== battle_result.session_id
			and int(committed_summary.get("finished_tick", -1))
				== battle_result.finished_tick
			and StringName(committed_summary.get("outcome", &""))
				== BattleOutcome.to_id(battle_result.outcome)
		):
			if (
				not _expedition_attempt.is_empty()
				and bool(_expedition_attempt.get("settled", false))
				and StringName(_expedition_attempt.get("attempt_id", &""))
					== battle_result.transaction_id
				and StringName(_expedition_attempt.get("result_id", &""))
					== battle_result.result_id
				and not bool(_persist_expedition_settlement(
					battle_result.transaction_id,
					battle_result.result_id
				).get("success", false))
			):
				return {}
			return committed_summary
		return {}
	if _battle_result_commit_in_flight_ids.has(battle_result.result_id):
		return {}
	if (
		not _expedition_attempt.is_empty()
		and StringName(_expedition_attempt.get("attempt_id", &""))
			== battle_result.transaction_id
	):
		return _apply_durable_expedition_result_atomic(
			battle_result,
			request
		)
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
		or (
			request.formal_city_entry
			and (
				request.level_id != FIRST_WAR_LEVEL_ID
				or first_war_state != FirstWarState.IN_BATTLE
				or request.city_defense_snapshot != get_city_defense()
			)
		)
		or (
			request.is_noticeboard_mission()
			and (
				_active_noticeboard_mission_id != request.level_id
				or get_noticeboard_mission_definition(request.level_id)
					!= request.mission_definition
			)
		)
	):
		return {}

	var battle_duration_milliseconds := (
		battle_result.get_duration_milliseconds()
	)
	if battle_duration_milliseconds < 0:
		return {}
	var grants_first_clear := (
		battle_result.outcome == BattleOutcome.Value.VICTORY
		and battle_result.first_clear_key != &""
		and not _first_clear_keys.has(battle_result.first_clear_key)
	)
	var planned_wood := request.reward_wood if grants_first_clear else 0
	var planned_food := request.reward_food if grants_first_clear else 0
	_battle_result_commit_in_flight_ids[battle_result.result_id] = true
	var city_time_before_day := current_day
	var city_time_before_milliseconds := roundi(
		day_elapsed_seconds * 1000.0
	)
	var advanced_days := _advance_city_time_for_battle_settlement(
		battle_duration_milliseconds
	)
	if advanced_days < 0:
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}

	var wood_capacity := get_resource_capacity(&"wood")
	var food_capacity := get_resource_capacity(&"food")
	var actual_food_cost := (
		mini(food, request.committed_food_cost)
		if request.formal_city_entry
		else 0
	)
	var food_after_cost := food - actual_food_cost
	var accepted_wood := mini(planned_wood, maxi(wood_capacity - wood, 0))
	var accepted_food := mini(
		planned_food,
		maxi(food_capacity - food_after_cost, 0)
	)
	var next_infantry := infantry_count - battle_result.casualty_count
	var next_wood := wood + accepted_wood
	var next_food := food_after_cost + accepted_food
	var defense_before := get_city_defense()
	var defense_damage := 0
	var next_enemy_count := enemy_count
	if request.formal_city_entry:
		if battle_result.outcome == BattleOutcome.Value.RETREAT:
			defense_damage = mini(
				FIRST_WAR_RETREAT_DEFENSE_DAMAGE,
				defense_before
			)
		elif battle_result.outcome == BattleOutcome.Value.DEFEAT:
			defense_damage = defense_before
		next_enemy_count = (
			0
			if battle_result.outcome == BattleOutcome.Value.VICTORY
			else maxi(enemy_count - battle_result.enemy_casualties, 0)
		)

	var summary := {
		"result_id": battle_result.result_id,
		"transaction_id": battle_result.transaction_id,
		"session_id": battle_result.session_id,
		"level_id": battle_result.level_id,
		"outcome": BattleOutcome.to_id(battle_result.outcome),
		"finished_tick": battle_result.finished_tick,
		"breached_route": battle_result.breached_route,
		"orders_digest": battle_result.orders_digest,
		"player_snapshot_digest": battle_result.player_snapshot_digest,
		"enemy_snapshot_digest": battle_result.enemy_snapshot_digest,
		"first_clear_key": battle_result.first_clear_key,
		"battle_duration_milliseconds": battle_duration_milliseconds,
		"city_time_advanced_milliseconds": battle_duration_milliseconds,
		"city_time_before_day": city_time_before_day,
		"city_time_before_milliseconds": city_time_before_milliseconds,
		"city_time_after_day": current_day,
		"city_time_after_milliseconds": roundi(
			day_elapsed_seconds * 1000.0
		),
		"city_time_advanced_days": advanced_days,
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
		"formal_city_entry": request.formal_city_entry,
		"source_id": request.source_id,
		"mission_id": (
			request.mission_definition.mission_id
			if request.mission_definition != null
			else &""
		),
		"planned_food_cost": request.committed_food_cost,
		"actual_food_cost": actual_food_cost,
		"food_shortage": actual_food_cost < request.committed_food_cost,
		"city_defense_before": defense_before,
		"city_defense_damage": defense_damage,
		"city_defense_after": defense_before - defense_damage,
		"enemy_count_before": enemy_count,
		"enemy_count_after": next_enemy_count,
		"infantry_after": next_infantry,
		"wood_after": next_wood,
		"food_after": next_food,
		"mainline_cleared": (
			request.formal_city_entry
			and battle_result.outcome == BattleOutcome.Value.VICTORY
			and request.level_id == FIRST_WAR_LEVEL_ID
		),
	}

	# Legacy non-durable missions still settle real people. Keep their original
	# identity/reward ledger while using the same casualty accounting as V5.
	var population_before := _population_recovery.get_snapshot()
	var garrison_before := _garrison_state.get_persistence_snapshot()
	var casualty_commit := func() -> Dictionary:
		infantry_count = next_infantry
		var casualties := _population_recovery.record_casualties(
			battle_result.casualty_count, RECOVERY_RULES.wounded_permille
		) if battle_result.casualty_count > 0 else {"wounded": 0, "fallen": 0}
		if casualties.is_empty() or not _population_recovery.invariant_matches(
			_current_military_population(), _current_alive_specialists()
		):
			_garrison_state.restore_persistence_snapshot(garrison_before)
			_population_recovery.restore_snapshot(population_before)
			return {"success": false}
		summary["wounded_added"] = int(casualties.wounded)
		summary["fallen_added"] = int(casualties.fallen)
		return {"success": true}
	if not _commit_national_resource_targets(
		{&"wood": next_wood, &"food": next_food},
		&"battle_result_settlement", casualty_commit
	):
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	if request.formal_city_entry:
		city_defense_damage += defense_damage
		enemy_count = next_enemy_count
		_first_war_pending_outcome = BattleOutcome.to_id(
			battle_result.outcome
		)
		city_fallen = (
			battle_result.outcome == BattleOutcome.Value.DEFEAT
		)
	if bool(summary.mainline_cleared):
		# The result ledger and national-resource transaction are now committed.
		# Clearing here makes victory effective on the one authorized confirm,
		# while retreat and defeat keep the existing pressure progression.
		_current_mainline_level.mark_cleared(current_day)
	_committed_battle_result_ids[battle_result.result_id] = (
		summary.duplicate(true)
	)
	if grants_first_clear:
		_first_clear_keys[battle_result.first_clear_key] = true
	if (
		request.is_noticeboard_mission()
		and battle_result.outcome == BattleOutcome.Value.VICTORY
	):
		_completed_noticeboard_mission_ids[request.level_id] = true
	_closed_battle_transactions[battle_result.transaction_id] = (
		BATTLE_PHASE_APPLIED
	)
	_last_battle_result_summary = summary.duplicate(true)
	_active_battle_reservation = {}
	_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
	_refresh_city_ui()
	city_state_changed.emit()
	return summary.duplicate(true)


func _apply_durable_expedition_result_atomic(
	battle_result: BattleResult,
	request: BattleRequest
) -> Dictionary:
	if (
		battle_result == null
		or request == null
		or not battle_result.is_consistent()
		or not request.formal_city_entry
		or request.is_noticeboard_mission()
		or request.phase != BattleRequest.PHASE_RESULT_PENDING
		or StringName(_expedition_attempt.get("phase", &""))
			!= BATTLE_PHASE_RESULT_PENDING
		or bool(_expedition_attempt.get("settled", false))
		or StringName(_expedition_attempt.get("result_id", &"")) != &""
		or _active_battle_reservation.is_empty()
		or StringName(_active_battle_reservation.get("transaction_id", &""))
			!= battle_result.transaction_id
		or StringName(_active_battle_reservation.get("phase", &""))
			!= BATTLE_PHASE_RESULT_PENDING
		or battle_result.transaction_id != request.transaction_id
		or battle_result.level_id != request.level_id
		or battle_result.started_day != request.created_day
		or battle_result.committed_count
			!= int(_expedition_attempt.get("committed_total", 0))
		or battle_result.committed_count
			!= request.committed_force.get_committed_total()
		or battle_result.player_snapshot_digest
			!= request.committed_force.get_digest()
		or battle_result.enemy_snapshot_digest
			!= request.enemy_force.get_digest()
		or battle_result.enemy_casualties > request.enemy_force.enemy_count
		or (
			request.source_id == &"FIRST_WAR"
			and (
				request.level_id != FIRST_WAR_LEVEL_ID
				or first_war_state != FirstWarState.IN_BATTLE
			)
		)
		or (
			request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE
			and (
				request.level_id != WARTIME_DEFENSE_MISSION.mission_id
				or request.mission_definition != WARTIME_DEFENSE_MISSION
			)
		)
		or request.city_defense_snapshot != int(
			_expedition_attempt.get("city_defense_snapshot", -1)
		)
		or request.committed_food_cost
			!= int(_expedition_attempt.get("food_cost", -1))
		or request.committed_force.to_dictionary()
			!= Dictionary(
				_expedition_attempt.get("committed_force_snapshot", {})
			)
		or request.enemy_force.to_dictionary()
			!= Dictionary(
				_expedition_attempt.get("enemy_force_snapshot", {})
			)
	):
		return {}

	var departures: Array = Array(
		_expedition_attempt.get("selected_formations", [])
	).duplicate(true)
	if (
		departures.is_empty()
		or battle_result.formation_results.size() != departures.size()
		or not _garrison_state.selection_matches(departures)
	):
		return {}
	var departures_by_id: Dictionary = {}
	for departure_value in departures:
		if not departure_value is Dictionary:
			return {}
		var departure: Dictionary = departure_value
		var formation_id := StringName(departure.get("formation_id", &""))
		if formation_id == &"" or departures_by_id.has(formation_id):
			return {}
		departures_by_id[formation_id] = departure
	var survivors_by_formation_id: Dictionary = {}
	var normalized_formation_results: Array[Dictionary] = []
	for formation_result_value in battle_result.formation_results:
		var formation_result: Dictionary = formation_result_value
		var formation_id := StringName(
			formation_result.get("formation_id", &"")
		)
		var departure: Dictionary = departures_by_id.get(formation_id, {})
		if (
			departure.is_empty()
			or survivors_by_formation_id.has(formation_id)
			or int(formation_result.get("squad_id", 0))
				!= int(departure.get("squad_id", 0))
			or int(formation_result.get("departure_count", -1))
				!= int(departure.get("member_count", -1))
		):
			return {}
		survivors_by_formation_id[formation_id] = int(
			formation_result.get("survivor_count", -1)
		)
		normalized_formation_results.append(formation_result.duplicate(true))
	var roster_probe := GarrisonState.new(
		NationState.BLACKSTONE_CITY_ID,
		INFANTRY_ROLE.role_id,
		0
	)
	if (
		not roster_probe.restore_persistence_snapshot(
			_garrison_state.get_persistence_snapshot()
		)
		or not roster_probe.apply_formation_survivors(
			departures,
			survivors_by_formation_id
		)
	):
		return {}
	# Snapshot the complete pre-settlement authority while the durable attempt is
	# still ACTIVE. Casualties are installed before the elapsed battle time is
	# advanced so training that completes during that time is added after the
	# returning survivors rather than invalidating or erasing the battle result.
	var rollback_snapshot := export_v5_campaign_snapshot()
	if rollback_snapshot.is_empty():
		return {}
	if not _garrison_state.apply_formation_survivors(
		departures,
		survivors_by_formation_id
	):
		return {}
	var recovery_casualties := _population_recovery.record_casualties(
		battle_result.casualty_count,
		RECOVERY_RULES.wounded_permille
	) if battle_result.casualty_count > 0 else {"casualties": 0, "wounded": 0, "fallen": 0}
	if recovery_casualties.is_empty() or not _population_recovery.invariant_matches(
		_current_military_population(), _current_alive_specialists()
	):
		_rollback_durable_expedition_settlement(rollback_snapshot)
		return {}

	var battle_duration_milliseconds := battle_result.get_duration_milliseconds()
	if battle_duration_milliseconds < 0:
		_rollback_durable_expedition_settlement(rollback_snapshot)
		return {}
	_battle_result_commit_in_flight_ids[battle_result.result_id] = true
	var city_time_before_day := current_day
	var city_time_before_milliseconds := get_day_elapsed_milliseconds()
	var advanced_days := _advance_city_time_for_battle_settlement(
		battle_duration_milliseconds
	)
	if advanced_days < 0:
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		_rollback_durable_expedition_settlement(rollback_snapshot)
		return {}

	var grants_first_clear := (
		battle_result.outcome == BattleOutcome.Value.VICTORY
		and battle_result.first_clear_key != &""
		and not _first_clear_keys.has(battle_result.first_clear_key)
	)
	var planned_wood := request.reward_wood if grants_first_clear else 0
	var planned_food := request.reward_food if grants_first_clear else 0
	var wood_capacity := get_resource_capacity(&"wood")
	var food_capacity := get_resource_capacity(&"food")
	var accepted_wood := mini(planned_wood, maxi(wood_capacity - wood, 0))
	var accepted_food := mini(planned_food, maxi(food_capacity - food, 0))
	var next_wood := wood + accepted_wood
	var next_food := food + accepted_food
	var defense_before := get_city_defense()
	var planned_defense_damage := 0
	var enemy_count_before := request.enemy_force.enemy_count
	var next_enemy_count := enemy_count_before
	if request.source_id == &"FIRST_WAR":
		if battle_result.outcome == BattleOutcome.Value.RETREAT:
			planned_defense_damage = mini(
				FIRST_WAR_RETREAT_DEFENSE_DAMAGE,
				defense_before
			)
		elif battle_result.outcome == BattleOutcome.Value.DEFEAT:
			planned_defense_damage = defense_before
		next_enemy_count = (
			0
			if battle_result.outcome == BattleOutcome.Value.VICTORY
			else maxi(enemy_count_before - battle_result.enemy_casualties, 0)
		)
	elif request.source_id == BattleRequest.SOURCE_WARTIME_DEFENSE:
		# The defense objective itself is authoritative for this R0 loss.  The
		# long-lived mainline pressure is intentionally not overwritten by it.
		if battle_result.outcome == BattleOutcome.Value.DEFEAT:
			planned_defense_damage = defense_before
		next_enemy_count = (
			0
			if battle_result.outcome == BattleOutcome.Value.VICTORY
			else maxi(enemy_count_before - battle_result.enemy_casualties, 0)
		)
	var roster_after := _garrison_state.get_persistence_snapshot()
	var infantry_after := 0
	for count in Dictionary(
		roster_after.get("unit_counts_by_definition_id", {})
	).values():
		infantry_after += int(count)
	var summary := {
		"result_id": battle_result.result_id,
		"transaction_id": battle_result.transaction_id,
		"session_id": battle_result.session_id,
		"level_id": battle_result.level_id,
		"outcome": BattleOutcome.to_id(battle_result.outcome),
		"finished_tick": battle_result.finished_tick,
		"breached_route": battle_result.breached_route,
		"orders_digest": battle_result.orders_digest,
		"player_snapshot_digest": battle_result.player_snapshot_digest,
		"enemy_snapshot_digest": battle_result.enemy_snapshot_digest,
		"first_clear_key": battle_result.first_clear_key,
		"battle_duration_milliseconds": battle_duration_milliseconds,
		"city_time_advanced_milliseconds": battle_duration_milliseconds,
		"city_time_before_day": city_time_before_day,
		"city_time_before_milliseconds": city_time_before_milliseconds,
		"city_time_after_day": current_day,
		"city_time_after_milliseconds": get_day_elapsed_milliseconds(),
		"city_time_advanced_days": advanced_days,
		"committed_count": battle_result.committed_count,
		"survivor_count": battle_result.survivor_count,
		"casualty_count": battle_result.casualty_count,
		"wounded_added": int(recovery_casualties.get("wounded", 0)),
		"fallen_added": int(recovery_casualties.get("fallen", 0)),
		"enemy_casualties": battle_result.enemy_casualties,
		"formation_results": normalized_formation_results.duplicate(true),
		"first_clear_granted": grants_first_clear,
		"planned_wood_reward": planned_wood,
		"planned_food_reward": planned_food,
		"accepted_wood_reward": accepted_wood,
		"accepted_food_reward": accepted_food,
		"overflow_wood_reward": planned_wood - accepted_wood,
		"overflow_food_reward": planned_food - accepted_food,
		"formal_city_entry": true,
		"source_id": request.source_id,
		"mission_id": (
			request.mission_definition.mission_id
			if request.mission_definition != null
			else &""
		),
		"planned_food_cost": request.committed_food_cost,
		"actual_food_cost": request.committed_food_cost,
		"food_already_committed": true,
		"food_shortage": false,
		"food_before_departure": int(
			_expedition_attempt.get("food_before", 0)
		),
		"food_after_departure": int(
			_expedition_attempt.get("food_after", 0)
		),
		"city_defense_before": defense_before,
		"city_defense_damage": planned_defense_damage,
		"city_defense_after": defense_before - planned_defense_damage,
		"enemy_count_before": enemy_count_before,
		"enemy_count_after": next_enemy_count,
		"infantry_after": infantry_after,
		"wood_after": next_wood,
		"food_after": next_food,
		"mainline_cleared": (
			battle_result.outcome == BattleOutcome.Value.VICTORY
			and request.level_id == FIRST_WAR_LEVEL_ID
		),
		"battle_fact_snapshot": (
			battle_result.get_authority_snapshot().duplicate(true)
		),
	}
	var installed := _commit_national_resource_targets(
		{&"wood": next_wood, &"food": next_food},
		&"r1e_expedition_settlement",
		Callable(self, "_install_durable_expedition_settlement").bind(
			battle_result,
			summary,
			planned_defense_damage,
			next_enemy_count,
			grants_first_clear
		)
	)
	_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
	if not installed:
		_rollback_durable_expedition_settlement(rollback_snapshot)
		return {}
	_refresh_city_ui()
	city_state_changed.emit()
	if not bool(_persist_expedition_settlement(
		battle_result.transaction_id,
		battle_result.result_id
	).get("success", false)):
		return {}
	return summary.duplicate(true)


func _install_durable_expedition_settlement(
	battle_result: BattleResult,
	summary: Dictionary,
	planned_defense_damage: int,
	next_enemy_count: int,
	grants_first_clear: bool
) -> Dictionary:
	city_defense_damage += planned_defense_damage
	enemy_count = next_enemy_count
	var settlement_source := StringName(_expedition_attempt.get("source_id", &"FIRST_WAR"))
	if settlement_source == &"FIRST_WAR":
		_first_war_pending_outcome = BattleOutcome.to_id(battle_result.outcome)
		city_fallen = battle_result.outcome == BattleOutcome.Value.DEFEAT
	elif settlement_source == BattleRequest.SOURCE_WARTIME_DEFENSE:
		city_fallen = battle_result.outcome == BattleOutcome.Value.DEFEAT
		var source_patrol_id := StringName(_expedition_attempt.get("source_patrol_id", &""))
		if source_patrol_id != &"" and not _war_loop_state.field_tactics.resolve_invasion_handoff(
			source_patrol_id,
			StringName(_expedition_attempt.get("attempt_id", &"")),
			int(summary.get("enemy_count_after", 0)),
			StringName(summary.get("outcome", &""))
		):
			return {}
	if bool(summary.get("mainline_cleared", false)):
		_current_mainline_level.mark_cleared(current_day)
	_committed_battle_result_ids[battle_result.result_id] = summary.duplicate(true)
	if grants_first_clear:
		_first_clear_keys[battle_result.first_clear_key] = true
	_closed_battle_transactions[battle_result.transaction_id] = (
		BATTLE_PHASE_APPLIED
	)
	_last_battle_result_summary = summary.duplicate(true)
	_expedition_attempt.phase = BATTLE_PHASE_APPLIED
	_expedition_attempt.settled = true
	_expedition_attempt.result_id = battle_result.result_id
	_expedition_attempt.battle_session_snapshot = {}
	_expedition_attempt.terminal_result_snapshot = {}
	_active_battle_reservation = {}
	return {"success": true}


func _rollback_durable_expedition_settlement(
	rollback_snapshot: Dictionary
) -> bool:
	var restored := _apply_validated_v5_campaign_snapshot(
		rollback_snapshot,
		false
	)
	if not bool(restored.get("success", false)):
		_expedition_commit_blocked = true
		push_error("R1E settlement rollback failed")
		return false
	if not _active_battle_reservation.is_empty():
		_active_battle_reservation.phase = BATTLE_PHASE_RESULT_PENDING
	if StringName(_expedition_attempt.get("source_id", &"FIRST_WAR")) == BattleRequest.SOURCE_WARTIME_DEFENSE:
		# Defense owns no first-war projection. A failed defense settlement must
		# restore the durable attempt without impersonating a mainline assault.
		first_war_state = FirstWarState.PREPARATION
		_update_first_war_state_for_current_day()
	else:
		first_war_state = FirstWarState.IN_BATTLE
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _persist_expedition_settlement(
	attempt_id: StringName,
	result_id: StringName
) -> Dictionary:
	var root := get_parent()
	if root != null and root.has_method("persist_expedition_settlement"):
		return root.persist_expedition_settlement(attempt_id, result_id)
	if DisplayServer.get_name() == "headless":
		return {"success": true, "headless_test_store_disabled": true}
	return {"success": false, "uncertain": false}


func _apply_macro_siege_battle_result_atomic(
	battle_result: BattleResult,
	request: BattleRequest,
	army_id: StringName,
	city_id: StringName
) -> Dictionary:
	if _committed_battle_result_ids.has(battle_result.result_id):
		var existing := get_committed_battle_result_summary(battle_result.result_id)
		if (
			StringName(existing.get("army_id", &"")) == army_id
			and StringName(existing.get("city_id", &"")) == city_id
			and Dictionary(existing.get("battle_fact_snapshot", {})) == battle_result.get_authority_snapshot()
		):
			return existing
		return {}
	var siege := _war_loop_state.get_siege(city_id)
	var handoff := _war_loop_state.get_wartime_handoff(city_id)
	var army := _army_registry.get_army(army_id)
	if (
		_battle_result_commit_in_flight_ids.has(battle_result.result_id)
		or not battle_result.is_consistent()
		or request == null
		or request.source_id != BattleRequest.SOURCE_MACRO_SIEGE
		or request.phase != BattleRequest.PHASE_RESULT_PENDING
		or siege.is_empty()
		or army.is_empty()
		or StringName(siege.get("army_id", &"")) != army_id
		or StringName(siege.get("order_id", &"")) != StringName(Dictionary(army.get("macro_march", {})).get("order_id", &""))
		or StringName(handoff.get("transaction_id", &"")) != battle_result.transaction_id
		or StringName(handoff.get("phase", &"")) != WarLoopState.WARTIME_HANDOFF_RESULT_PENDING
		or request.transaction_id != battle_result.transaction_id
		or request.level_id != battle_result.level_id
		or request.committed_force.get_digest() != battle_result.player_snapshot_digest
		or request.enemy_force.get_digest() != battle_result.enemy_snapshot_digest
		or battle_result.enemy_casualties > request.enemy_force.enemy_count
	):
		return {}
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	if StringName(army.get("phase", &"")) != ArmyRegistry.PHASE_SIEGING:
		return {}
	var terminal_combat_state: Dictionary = Dictionary(handoff.get("terminal_combat_state", {}))
	if not _has_valid_macro_siege_combat_state(terminal_combat_state):
		return {}
	var formations_by_id: Dictionary = {}
	for formation_value in Array(macro.get("formation_snapshots", [])):
		if not formation_value is Dictionary:
			return {}
		var formation: Dictionary = formation_value
		var formation_id := StringName(formation.get("formation_id", &""))
		if formation_id == &"" or formations_by_id.has(formation_id):
			return {}
		# A field encounter can exhaust one formation before the surviving army
		# reaches a siege. The zero-count formation remains in ArmyRegistry for
		# provenance, but it was not committed to this battle and therefore has
		# no formation result to settle.
		if int(formation.get("member_count", 0)) <= 0:
			continue
		formations_by_id[formation_id] = formation
	if battle_result.formation_results.size() != formations_by_id.size():
		return {}
	var losses_by_formation_id: Dictionary = {}
	for result_value in battle_result.formation_results:
		if not result_value is Dictionary:
			return {}
		var formation_result: Dictionary = result_value
		var formation_id := StringName(formation_result.get("formation_id", &""))
		var original: Dictionary = Dictionary(formations_by_id.get(formation_id, {}))
		if (
			original.is_empty()
			or losses_by_formation_id.has(formation_id)
			or int(formation_result.get("departure_count", -1)) != int(original.get("member_count", -1))
			or int(formation_result.get("survivor_count", -1)) < 0
		):
			return {}
		losses_by_formation_id[formation_id] = int(original.get("member_count", 0)) - int(formation_result.get("survivor_count", 0))
	var registry_before := _army_registry.get_snapshot()
	var war_before := _war_loop_state.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	_battle_result_commit_in_flight_ids[battle_result.result_id] = true
	var updated_army := _army_registry.apply_macro_formation_losses(
		army_id, StringName(macro.get("order_id", &"")), losses_by_formation_id
	)
	if updated_army.is_empty():
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	var recovery_casualties := _population_recovery.record_casualties(
		battle_result.casualty_count, RECOVERY_RULES.wounded_permille
	) if battle_result.casualty_count > 0 else {"casualties": 0, "wounded": 0, "fallen": 0}
	if recovery_casualties.is_empty() or not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	var resolved := _war_loop_state.resolve_wartime_handoff(
		city_id,
		battle_result.transaction_id,
		battle_result.result_id,
		battle_result.outcome == BattleOutcome.Value.VICTORY,
		battle_result.outcome == BattleOutcome.Value.RETREAT,
		int(terminal_combat_state.attacker_total_hp),
		int(terminal_combat_state.defender_total_hp),
		int(terminal_combat_state.gate_hp)
	)
	if resolved.is_empty():
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	var settled: Dictionary = {}
	if battle_result.outcome == BattleOutcome.Value.VICTORY:
		settled = _finalize_macro_occupation(resolved)
	else:
		settled = _resolve_failed_macro_siege(resolved)
	if not bool(settled.get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	var summary := {
		"result_id": battle_result.result_id,
		"transaction_id": battle_result.transaction_id,
		"session_id": battle_result.session_id,
		"level_id": battle_result.level_id,
		"army_id": army_id,
		"city_id": city_id,
		"order_id": StringName(macro.get("order_id", &"")),
		"outcome": BattleOutcome.to_id(battle_result.outcome),
		"committed_count": battle_result.committed_count,
		"survivor_count": battle_result.survivor_count,
		"casualty_count": battle_result.casualty_count,
		"wounded_added": int(recovery_casualties.get("wounded", 0)),
		"fallen_added": int(recovery_casualties.get("fallen", 0)),
		"enemy_casualties": battle_result.enemy_casualties,
		"formation_results": battle_result.formation_results.duplicate(true),
		"actual_food_cost": 0,
		"accepted_wood_reward": 0,
		"accepted_food_reward": 0,
		"first_clear_granted": false,
		"personnel_accounting": get_blackstone_personnel_accounting(),
		"battle_fact_snapshot": battle_result.get_authority_snapshot().duplicate(true),
	}
	_committed_battle_result_ids[battle_result.result_id] = summary.duplicate(true)
	_closed_battle_transactions[battle_result.transaction_id] = BATTLE_PHASE_APPLIED
	_last_battle_result_summary = summary.duplicate(true)
	_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
	if not bool(_persist_macro_march_checkpoint().get("success", false)):
		_war_loop_state.restore_snapshot(war_before)
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		_committed_battle_result_ids.erase(battle_result.result_id)
		_closed_battle_transactions.erase(battle_result.transaction_id)
		return {}
	_refresh_city_ui()
	city_state_changed.emit()
	return summary.duplicate(true)


func _apply_army_battle_result_atomic(
	battle_result: BattleResult,
	request: BattleRequest,
	army_id: StringName
) -> Dictionary:
	if _committed_battle_result_ids.has(battle_result.result_id):
		var existing := get_committed_battle_result_summary(
			battle_result.result_id
		)
		if (
			Dictionary(
				existing.get("battle_fact_snapshot", {})
			) == battle_result.get_authority_snapshot()
			and StringName(existing.get("army_id", &"")) == army_id
		):
			return existing
		return {}
	if (
		_battle_result_commit_in_flight_ids.has(battle_result.result_id)
		or not battle_result.is_consistent()
		or _active_army_encounter.is_empty()
		or StringName(_active_army_encounter.army_id) != army_id
		or StringName(_active_army_encounter.transaction_id)
			!= battle_result.transaction_id
		or StringName(_active_army_encounter.phase)
			!= BATTLE_PHASE_RESULT_PENDING
		or request.phase != BattleRequest.PHASE_RESULT_PENDING
		or request.transaction_id != battle_result.transaction_id
		or request.level_id != battle_result.level_id
		or request.created_day != battle_result.started_day
		or request.committed_force.get_digest()
			!= battle_result.player_snapshot_digest
		or request.enemy_force.get_digest()
			!= battle_result.enemy_snapshot_digest
		or battle_result.enemy_casualties
			> request.enemy_force.enemy_count
	):
		return {}
	var army := _army_registry.get_army(army_id)
	if (
		army.is_empty()
		or StringName(army.transaction_id)
			!= battle_result.transaction_id
		or StringName(army.phase)
			!= ArmyRegistry.PHASE_SETTLEMENT_PENDING
	):
		return {}
	var committed_total := 0
	for count in Dictionary(army.units_by_definition_id).values():
		committed_total += int(count)
	if (
		committed_total != battle_result.committed_count
		or committed_total
			!= request.committed_force.get_committed_total()
	):
		return {}
	var survivor_units: Dictionary = {}
	if battle_result.survivor_count > 0:
		survivor_units[INFANTRY_ROLE.role_id] = (
			battle_result.survivor_count
		)
	# An external First War result never establishes a destination garrison.
	# ArmyRegistry remains the sole owner of the composition while every
	# surviving unit returns through the existing home-return transition.
	var disposition := ArmyRegistry.DISPOSITION_CLOSED_LOST
	if battle_result.survivor_count > 0:
		disposition = ArmyRegistry.DISPOSITION_RETURNING_HOME
	var registry_probe := ArmyRegistry.new()
	if (
		not registry_probe.restore_snapshot(
			_army_registry.get_snapshot(),
			get_unit_definition_ids()
		)
		or not registry_probe.apply_settlement(
			army_id,
			battle_result.transaction_id,
			battle_result.result_id,
			survivor_units,
			disposition
		)
	):
		return {}
	var duration_milliseconds := battle_result.get_duration_milliseconds()
	if duration_milliseconds < 0:
		return {}
	_battle_result_commit_in_flight_ids[battle_result.result_id] = true
	var registry_before := _army_registry.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var time_before_day := current_day
	var time_before_milliseconds := get_day_elapsed_milliseconds()
	var advanced_days := _advance_city_time_for_battle_settlement(
		duration_milliseconds
	)
	if advanced_days < 0:
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	if not _army_registry.apply_settlement(
		army_id,
		battle_result.transaction_id,
		battle_result.result_id,
		survivor_units,
		disposition
	):
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	var recovery_casualties := _population_recovery.record_casualties(
		battle_result.casualty_count, RECOVERY_RULES.wounded_permille
	) if battle_result.casualty_count > 0 else {"casualties": 0, "wounded": 0, "fallen": 0}
	if recovery_casualties.is_empty() or not _population_recovery.invariant_matches(_current_military_population(), _current_alive_specialists()):
		_army_registry.restore_snapshot(registry_before, get_unit_definition_ids())
		_population_recovery.restore_snapshot(population_before)
		_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
		return {}
	var summary := {
		"result_id": battle_result.result_id,
		"transaction_id": battle_result.transaction_id,
		"session_id": battle_result.session_id,
		"level_id": battle_result.level_id,
		"army_id": army_id,
		"outcome": BattleOutcome.to_id(battle_result.outcome),
		"finished_tick": battle_result.finished_tick,
		"committed_count": battle_result.committed_count,
		"survivor_count": battle_result.survivor_count,
		"casualty_count": battle_result.casualty_count,
		"wounded_added": int(recovery_casualties.get("wounded", 0)),
		"fallen_added": int(recovery_casualties.get("fallen", 0)),
		"enemy_casualties": battle_result.enemy_casualties,
		"disposition": disposition,
		"battle_duration_milliseconds": duration_milliseconds,
		"city_time_before_day": time_before_day,
		"city_time_before_milliseconds": time_before_milliseconds,
		"city_time_after_day": current_day,
		"city_time_after_milliseconds": (
			get_day_elapsed_milliseconds()
		),
		"city_time_advanced_days": advanced_days,
		"battle_fact_snapshot": (
			battle_result.get_authority_snapshot().duplicate(true)
		),
	}
	_committed_battle_result_ids[battle_result.result_id] = (
		summary.duplicate(true)
	)
	_closed_battle_transactions[battle_result.transaction_id] = (
		BATTLE_PHASE_APPLIED
	)
	_last_battle_result_summary = summary.duplicate(true)
	_active_army_encounter = {}
	_battle_result_commit_in_flight_ids.erase(battle_result.result_id)
	_refresh_city_ui()
	city_state_changed.emit()
	return summary.duplicate(true)


func complete_returned_army_to_garrison(
	army_id: StringName,
	transaction_id: StringName
) -> Dictionary:
	var army := _army_registry.get_army(army_id)
	if (
		army.is_empty()
		or StringName(army.transaction_id) != transaction_id
		or StringName(army.phase) != ArmyRegistry.PHASE_ARRIVED
		or StringName(army.last_applied_result_id) == &""
	):
		return {}
	var survivor_count := int(
		Dictionary(army.units_by_definition_id).get(
			INFANTRY_ROLE.role_id,
			0
		)
	)
	if survivor_count <= 0:
		return {}
	var registry_before := _army_registry.get_snapshot()
	var garrison_before := infantry_count
	if not _garrison_state.try_add_units(
		INFANTRY_ROLE.role_id,
		survivor_count
	):
		return {}
	if not _army_registry.close_return_to_garrison(
		army_id,
		transaction_id
	):
		_garrison_state.set_unit_count(
			INFANTRY_ROLE.role_id,
			garrison_before
		)
		_army_registry.restore_snapshot(
			registry_before,
			get_unit_definition_ids()
		)
		return {}
	var summary := {
		"army_id": army_id,
		"transaction_id": transaction_id,
		"returned_count": survivor_count,
		"garrison_after": infantry_count,
		"phase": ArmyRegistry.PHASE_CLOSED,
	}
	_refresh_city_ui()
	city_state_changed.emit()
	return summary


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
	return _get_training_batch_size_for_tech_ids(researched_tech_ids)


func _get_training_batch_size_for_tech_ids(tech_ids: Array) -> int:
	var rotational := get_tech_definition(&"tech.rotational_recruitment")
	if rotational != null and rotational.tech_id in tech_ids:
		return roundi(rotational.effect_amount)
	return BASE_TRAINING_BATCH


func _get_allowed_training_batches_for_snapshot(
	tech_ids: Array
) -> Array[int]:
	var allowed: Array[int] = [BASE_TRAINING_BATCH]
	var current_batch := _get_training_batch_size_for_tech_ids(tech_ids)
	if current_batch not in allowed:
		allowed.append(current_batch)
	return allowed


func can_queue_training() -> bool:
	return _get_training_failure_id(
		INFANTRY_ROLE.role_id,
		get_training_batch_size()
	) == &""


func _get_training_failure_id(
	unit_definition_id: StringName,
	quantity: int
) -> StringName:
	if is_city_action_locked_for_battle():
		return &"CITY_BATTLE_LOCKED"
	if not uses_blackstone_campaign() and current_day >= FIRST_MAP_THREAT_SCHEDULE.max_day:
		return &"TRAINING_DAY_LIMIT"
	if _training_queue.has_active_order():
		return &"TRAINING_QUEUE_BUSY"
	if last_training_order_day == current_day:
		return &"TRAINING_DAILY_LIMIT"
	if get_unit_definition(unit_definition_id) == null:
		return &"UNKNOWN_UNIT_DEFINITION"
	if quantity <= 0 or quantity != get_training_batch_size():
		return &"INVALID_TRAINING_QUANTITY"
	if _population_recovery.available < quantity:
		return &"INSUFFICIENT_AVAILABLE_POPULATION"
	if supply_shortage:
		return &"SUPPLY_SHORTAGE"
	var future_total := _garrison_state.get_total_count() + quantity
	if future_total > recruitment_cap:
		return &"RECRUITMENT_CAPACITY"
	if future_total > get_effective_command_limit():
		return &"COMMAND_LIMIT"
	var food_cost := quantity * INFANTRY_ROLE.recruit_food_per_unit
	if food < food_cost:
		return &"INSUFFICIENT_FOOD"
	return &""


func request_training(
	unit_definition_id := INFANTRY_ROLE.role_id,
	quantity := -1
) -> Dictionary:
	var requested_quantity := (
		get_training_batch_size()
		if quantity < 0
		else quantity
	)
	var failure_id := _get_training_failure_id(
		StringName(unit_definition_id),
		requested_quantity
	)
	if failure_id != &"":
		_last_training_failure_id = failure_id
		return {
			"success": false,
			"error_id": failure_id,
			"order": {},
		}
	var food_cost := (
		requested_quantity * INFANTRY_ROLE.recruit_food_per_unit
	)
	var queue_before := _training_queue.get_snapshot()
	var population_before := _population_recovery.get_snapshot()
	var local_commit := func() -> Dictionary:
		if not _population_recovery.reserve_training(requested_quantity):
			return {"success": false}
		var order := _training_queue.enqueue(
			StringName(unit_definition_id), requested_quantity, current_day,
			current_day + 1, food_cost
		)
		if order.is_empty():
			_population_recovery.restore_snapshot(population_before)
			_training_queue.restore_snapshot(queue_before)
			return {"success": false}
		return {"success": true, "order": order}
	var transaction: Dictionary = _nation_state.commit_resource_transaction(
		NationState.BLACKSTONE_CITY_ID,
		[{
			"resource_id": &"food",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": food_cost,
		}],
		&"training_order", local_commit
	)
	if not bool(transaction.success):
		_last_training_failure_id = (
			&"TRAINING_QUEUE_COMMIT"
			if transaction.error_id == &"LOCAL_COMMIT_REJECTED"
			else &"RESOURCE_TRANSACTION_COMMIT"
		)
		return {
			"success": false,
			"error_id": _last_training_failure_id,
			"order": {},
		}
	var order: Dictionary = Dictionary(transaction.local_commit_result.get("order", {})).duplicate(true)
	_last_training_failure_id = &""
	_refresh_city_ui()
	city_state_changed.emit()
	return {
		"success": true,
		"error_id": &"",
		"order": order.duplicate(true),
	}


func queue_training() -> bool:
	return bool(request_training().success)


func get_training_queue_snapshot() -> Dictionary:
	return _training_queue.get_snapshot().duplicate(true)


func get_last_training_failure_id() -> StringName:
	return _last_training_failure_id


func get_training_blocked_reason() -> Dictionary:
	var error_id := _get_training_failure_id(
		INFANTRY_ROLE.role_id,
		get_training_batch_size()
	)
	var messages := {
		&"CITY_BATTLE_LOCKED": "战斗期间不可征募",
		&"TRAINING_DAY_LIMIT": "首战阶段已结束征募",
		&"TRAINING_QUEUE_BUSY": "已有训练正在进行",
		&"TRAINING_DAILY_LIMIT": "今日已下达训练",
		&"UNKNOWN_UNIT_DEFINITION": "未知兵种",
		&"INVALID_TRAINING_QUANTITY": "训练批量不符合当前规则",
		&"SUPPLY_SHORTAGE": "供给不足，训练暂停",
		&"RECRUITMENT_CAPACITY": "驻军已达征募容量",
		&"COMMAND_LIMIT": "驻军将超过指挥上限",
		&"INSUFFICIENT_FOOD": "粮食还缺 %d" % maxi(get_training_batch_size() * INFANTRY_ROLE.recruit_food_per_unit - food, 0),
		&"INSUFFICIENT_AVAILABLE_POPULATION": "可用人口还缺 %d；可调整生产、施工、医疗或治理岗位" % maxi(get_training_batch_size() - _population_recovery.available, 0),
	}
	return {
		"blocked": error_id != &"",
		"error_id": error_id,
		"message": String(messages.get(error_id, "")),
	}


func _restore_training_legacy_state(
	quantity: int,
	complete_day: int,
	last_order_day: int
) -> bool:
	var food_cost := maxi(
		quantity * INFANTRY_ROLE.recruit_food_per_unit,
		0
	)
	var restored := _training_queue.restore_legacy_state(
		quantity,
		complete_day,
		last_order_day,
		INFANTRY_ROLE.role_id,
		food_cost
	)
	if restored:
		_last_training_failure_id = &""
	return restored


func get_maintenance_food_cost() -> int:
	var military_cost := ceili(
		float(infantry_count)
		/ float(INFANTRY_ROLE.maintenance_units_per_food)
	)
	var general := get_selected_general()
	if (
		general != null
		and general.modifier_type == &"maintenance_reduction"
	):
		military_cost = ceili(float(military_cost) * (1.0 - general.modifier_amount))
	# External armies paid at dispatch and are intentionally excluded here.  The
	# city ration covers residents who remain in Blackstone, including workers,
	# trainees and wounded people, without charging the garrison twice.
	var city_civilians := maxi(
		_population_recovery.total_living
		- _current_military_population()
		- _current_alive_specialists(),
		0
	)
	var civilian_cost := ceili(
		float(city_civilians) / float(CITY_GOVERNANCE_RULES.civilians_per_food)
	)
	return military_cost + civilian_cost


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
	if not _commit_national_resources(
		[{
			"resource_id": &"tech_points",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": tech.cost,
		}],
		&"technology_research"
	):
		return false
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
	if StringName(_city_strategy.troop_equipment_by_slot.get(&"attack", &"")) == &"equipment.spear_kit":
		multiplier *= 1.0 + float(CITY_STRATEGY_RULES.equipment_effect_permille) / 1000.0
	var general_attack := _general_equipment_effect_permille(&"ATTACK")
	if general_attack > 0:
		multiplier *= 1.0 + float(general_attack) / 1000.0
	return multiplier


func get_infantry_defense_multiplier() -> float:
	var multiplier := 1.0
	var general := get_selected_general()
	if general != null and general.modifier_type == &"infantry_defense":
		multiplier *= 1.0 + general.modifier_amount
	if StringName(_city_strategy.troop_equipment_by_slot.get(&"defense", &"")) == &"equipment.padded_armor":
		multiplier *= 1.0 + float(CITY_STRATEGY_RULES.equipment_effect_permille) / 1000.0
	var general_defense := _general_equipment_effect_permille(&"DEFENSE")
	if general_defense > 0:
		multiplier *= 1.0 + float(general_defense) / 1000.0
	if _is_city_support_active(&"DEFENSE"):
		multiplier *= 1.0 + float(CITY_STRATEGY_RULES.defense_support_permille) / 1000.0
	return multiplier


func _general_equipment_effect_permille(requested_kind: StringName) -> int:
	var loadout: Dictionary = Dictionary(_city_strategy.general_equipment_by_general_id.get(selected_general_id, {}))
	var total := 0
	for equipment_id_value in loadout.values():
		var equipment_id := StringName(equipment_id_value)
		if equipment_id == &"":
			continue
		var kind := StringName(CITY_STRATEGY_RULES.general_equipment_effect_kinds.get(equipment_id, &""))
		if kind != requested_kind and kind != &"ATTACK_DEFENSE":
			continue
		total += _city_strategy.equipment_level(equipment_id, CITY_STRATEGY_RULES.equipment_experience_per_level, CITY_STRATEGY_RULES.equipment_level_caps) * CITY_STRATEGY_RULES.general_equipment_effect_permille
	return total


func emergency_mobilization() -> bool:
	if (
		is_city_action_locked_for_battle()
		or
		current_day != FIRST_MAP_THREAT_SCHEDULE.max_day
		or emergency_mobilization_used
		or food < EMERGENCY_MOBILIZATION_FOOD_COST
		or _population_recovery.available < EMERGENCY_MOBILIZATION_INFANTRY
	):
		return false
	var population_before := _population_recovery.get_snapshot()
	var local_commit := func() -> Dictionary:
		if not _population_recovery.allocate_to_military(EMERGENCY_MOBILIZATION_INFANTRY):
			return {"success": false}
		return {"success": true}
	if not _commit_national_resources(
		[{
			"resource_id": &"food",
			"operation": NationState.RESOURCE_OPERATION_SPEND,
			"amount": EMERGENCY_MOBILIZATION_FOOD_COST,
		}],
		&"emergency_mobilization",
		local_commit
	):
		_population_recovery.restore_snapshot(population_before)
		return false
	infantry_count += EMERGENCY_MOBILIZATION_INFANTRY
	if not _population_recovery.invariant_matches(
		_current_military_population(), _current_alive_specialists()
	):
		infantry_count -= EMERGENCY_MOBILIZATION_INFANTRY
		_population_recovery.restore_snapshot(population_before)
		_nation_state.commit_resource_transaction(
			NationState.BLACKSTONE_CITY_ID,
			[{
				"resource_id": &"food",
				"operation": NationState.RESOURCE_OPERATION_ADD,
				"amount": EMERGENCY_MOBILIZATION_FOOD_COST,
			}],
			&"emergency_mobilization_rollback"
		)
		return false
	emergency_mobilization_used = true
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func get_city_defense() -> int:
	var defense := 10
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if record.is_empty() or not is_building_operational(placement_id):
			continue
		var definition := get_definition(record.definition_id)
		if definition == null:
			continue
		var defense_capability := definition.get_capability(&"defense")
		if defense_capability != null:
			defense += defense_capability.amount
	return maxi(defense - city_defense_damage, 0)


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
		if record.is_empty() or not is_building_operational(placement_id):
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


func grant_blackstone_mvp_victory_reward(
	requested_wood: int
) -> int:
	if requested_wood <= 0:
		return 0
	var accepted_wood := mini(
		requested_wood,
		maxi(get_resource_capacity(&"wood") - wood, 0)
	)
	if (
		accepted_wood > 0
		and not _commit_national_resources(
			[{
				"resource_id": &"wood",
				"operation": NationState.RESOURCE_OPERATION_ADD,
				"amount": accepted_wood,
			}],
			&"blackstone_mvp_victory_reward"
		)
	):
		return 0
	_refresh_city_ui()
	city_state_changed.emit()
	return accepted_wood


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
	if not _commit_national_resource_targets(
		{
			&"wood": int(_readiness_checkpoint.wood),
			&"food": int(_readiness_checkpoint.food),
			&"tech_points": int(_readiness_checkpoint.tech_points),
		},
		&"readiness_checkpoint_restore"
	):
		return false
	infantry_count = int(_readiness_checkpoint.infantry_count)
	recruitment_cap = int(_readiness_checkpoint.recruitment_cap)
	selected_general_id = StringName(
		_readiness_checkpoint.selected_general_id
	)
	if not _restore_training_legacy_state(
		int(_readiness_checkpoint.training_queued_count),
		int(_readiness_checkpoint.training_complete_day),
		int(_readiness_checkpoint.last_training_order_day)
	):
		push_error("Readiness checkpoint training queue restore failed")
		return false
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
			false,
			true
		)
		if placement_id < 0:
			push_error("Readiness checkpoint placement restore failed")
			return false
		var record: Dictionary = _building_records_by_id[placement_id]
		record.built_day = int(placement.built_day)
		record.disabled_until_day = int(placement.disabled_until_day)
		record.lifecycle_state = StringName(
			placement.get("lifecycle_state", &"running")
		)
		record.construction_started_day = int(
			placement.get("construction_started_day", record.built_day)
		)
		record.construction_complete_day = int(
			placement.get(
				"construction_complete_day",
				record.built_day
			)
		)
		_refresh_placed_building_visual(placement_id)
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
	if not _replace_national_resources(
		NationState.DEFAULT_SHARED_RESOURCES,
		&"new_game_restart"
	):
		return false
	infantry_count = 20
	recruitment_cap = BASE_RECRUITMENT_CAP
	selected_general_id = &""
	_training_queue.clear()
	_last_training_failure_id = &""
	_army_registry = ARMY_REGISTRY.new()
	_population_recovery = POPULATION_RECOVERY_STATE.new()
	_population_recovery.initialize_fresh(RECOVERY_RULES, _garrison_state.get_total_count())
	_city_governance = CITY_GOVERNANCE_STATE.new()
	_city_governance.initialize_fresh(CITY_GOVERNANCE_RULES)
	_city_strategy = CITY_STRATEGY_STATE.new()
	_city_strategy.initialize_fresh(CITY_STRATEGY_RULES)
	_active_army_dispatch_reservation = {}
	_next_army_dispatch_transaction_sequence = 1
	_active_army_encounter = {}
	researched_tech_ids.clear()
	supply_shortage = false
	emergency_mobilization_used = false
	city_time_paused = false
	city_time_speed = 1.0
	day_elapsed_seconds = 0.0
	_city_frame_remainder_milliseconds = 0.0
	first_war_state = FirstWarState.PREPARATION
	first_war_warning_count = 0
	city_fallen = false
	city_defense_damage = 0
	enemy_count = 0
	enemy_fortification = 0
	city_security = MAINLINE_PRESSURE_PROFILE.default_security
	_current_mainline_level = CURRENT_MAINLINE_LEVEL.new(
		MAINLINE_PRESSURE_PROFILE
	)
	_construction_completed_since_last_day = 0
	_first_war_pending_outcome = &""
	_first_war_result_acknowledged = false
	_readiness_checkpoint = {}
	last_daily_breakdown = {
		"maintenance_food": 0,
		"maintenance_required": 0,
		"training_completed": 0,
		"construction_completed": 0,
		"wood_income": 0,
		"food_income": 0,
		"research_income": 0,
		"event_wood_loss": 0,
		"event_food_loss": 0,
		"stopped_placement_id": -1,
	}
	last_daily_report = "首图已重开"
	_update_threat_for_current_day(false)
	_update_first_war_state_for_current_day()
	_refresh_city_ui()
	city_state_changed.emit()
	return true


func _update_threat_for_current_day(apply_event: bool) -> void:
	if (
		_first_war_pending_outcome != &""
		or (
			not _expedition_attempt.is_empty()
			and StringName(_expedition_attempt.get("phase", &""))
				== BATTLE_PHASE_APPLIED
		)
	):
		return
	var threat_event := FIRST_MAP_THREAT_SCHEDULE.get_event_for_day(
		current_day
	)
	if threat_event == null:
		return
	enemy_count = threat_event.enemy_count
	enemy_fortification = threat_event.fortification_level
	if apply_event and not uses_blackstone_campaign() and threat_event.day == current_day:
		_apply_threat_event(threat_event)


func _update_first_war_state_for_current_day() -> void:
	if first_war_state in [
		FirstWarState.RESOLVED_VICTORY,
		FirstWarState.RESOLVED_RETREAT,
		FirstWarState.RESOLVED_DEFEAT,
	]:
		return
	if current_day >= FIRST_WAR_PENDING_DAY:
		first_war_state = FirstWarState.PENDING
		return
	if (
		current_day >= FIRST_WAR_WARNING_DAY
		and first_war_state == FirstWarState.PREPARATION
	):
		first_war_state = FirstWarState.WARNING
		first_war_warning_count += 1


func _apply_threat_event(threat_event: ThreatEventDefinition) -> void:
	if threat_event.event_type == &"food_harassment":
		var loss := (
			threat_event.adequate_food_loss
			if get_city_defense() >= threat_event.defense_threshold
			else threat_event.insufficient_food_loss
		)
		var actual_loss := mini(loss, food)
		if (
			actual_loss > 0
			and not _commit_national_resources(
				[{
					"resource_id": &"food",
					"operation": NationState.RESOURCE_OPERATION_SPEND,
					"amount": actual_loss,
				}],
				&"threat_food_harassment"
			)
		):
			return
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
				"lifecycle_state": record.lifecycle_state,
				"construction_started_day": record.construction_started_day,
				"construction_complete_day": record.construction_complete_day,
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
	var wood_loss := int(last_daily_breakdown.event_wood_loss)
	var food_loss := int(last_daily_breakdown.event_food_loss)
	if wood_loss > 0 or food_loss > 0:
		var loss_parts: Array[String] = []
		if wood_loss > 0:
			loss_parts.append("木材 %d" % wood_loss)
		if food_loss > 0:
			loss_parts.append("粮食 %d" % food_loss)
		last_daily_report = "今日结算：损失 %s" % [
			"、".join(loss_parts),
		]
	else:
		last_daily_report = "今日结算：木材+%d" % [
			int(last_daily_breakdown.wood_income),
		]
	if int(last_daily_breakdown.stopped_placement_id) >= 0:
		last_daily_report += "｜生产受扰"
	if int(last_daily_breakdown.get("construction_completed", 0)) > 0:
		last_daily_report += "｜完工%d" % int(
			last_daily_breakdown.construction_completed
		)
	if int(last_daily_breakdown.get("new_disease_cases", 0)) > 0:
		last_daily_report += "｜新增患病%d" % int(last_daily_breakdown.new_disease_cases)
	if int(last_daily_breakdown.get("disease_recoveries", 0)) > 0:
		last_daily_report += "｜康复%d" % int(last_daily_breakdown.disease_recoveries)
	if int(last_daily_breakdown.get("refugee_recoveries", 0)) > 0:
		last_daily_report += "｜难民医疗%d" % int(last_daily_breakdown.refugee_recoveries)
	if int(last_daily_breakdown.get("births", 0)) > 0:
		last_daily_report += "｜出生%d" % int(last_daily_breakdown.births)
	if int(last_daily_breakdown.get("matured", 0)) > 0:
		last_daily_report += "｜成长%d" % int(last_daily_breakdown.matured)
	if int(last_daily_breakdown.get("aged", 0)) > 0:
		last_daily_report += "｜老化%d" % int(last_daily_breakdown.aged)
	if int(last_daily_breakdown.get("civilian_deaths", 0)) > 0:
		last_daily_report += "｜严寒死亡%d" % int(last_daily_breakdown.civilian_deaths)
	if int(last_daily_breakdown.get("refugee_arrivals", 0)) > 0:
		last_daily_report += "｜难民抵达%d（待决定）" % int(last_daily_breakdown.refugee_arrivals)
	if supply_shortage:
		last_daily_report += "｜粮食短缺，健康承压"


func get_definition(definition_id: StringName) -> BuildingDefinition:
	return _definitions_by_id.get(definition_id) as BuildingDefinition


func get_definition_build_data(definition_id: StringName) -> Dictionary:
	var definition := get_definition(definition_id)
	if definition == null:
		return {}
	var unavailable_reason := _get_definition_unavailable_reason(definition)
	return {
		"definition_id": definition.definition_id,
		"display_name": definition.display_name,
		"level": definition.level,
		"next_level_label": (
			"下一等级：当前切片未开放"
			if definition.next_level_definition_id == &""
			else "下一等级：%s" % definition.next_level_definition_id
		),
		"cost_text": _get_definition_cost_text(definition),
		"compact_cost_text": _get_definition_compact_cost_text(definition),
		"duration_text": (
			"即时完成"
			if definition.build_days <= 0
			else "%d 日" % definition.build_days
		),
		"effect_text": _get_definition_effect_summary(definition),
		"prerequisite_text": _get_definition_prerequisite_summary(
			definition
		),
		"unavailable_reason": unavailable_reason,
		"can_build": unavailable_reason.is_empty(),
	}


func get_building_data(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {}
	var status := get_operational_status(placement_id)
	var level := int(record.get("level", 1))
	var investment_text := "初始固定设施"
	var duration_text := "已建成"
	var effect_text := str(record.get("effect_summary", ""))
	var prerequisite_text := str(
		record.get("prerequisite_summary", "初始固定设施")
	)
	var progress_text := "已建成"
	var definition := get_definition(
		StringName(record.get("definition_id", &""))
	)
	if definition != null:
		var definition_data := get_definition_build_data(
			definition.definition_id
		)
		investment_text = str(definition_data.cost_text)
		duration_text = str(definition_data.duration_text)
		effect_text = str(definition_data.effect_text)
		prerequisite_text = str(definition_data.prerequisite_text)
		if StringName(record.lifecycle_state) == &"constructing":
			var required := maxi(int(record.construction_required_milliseconds), 1)
			var progress_percent := floori(
				float(int(record.construction_progress_milliseconds))
				/ float(required) * 100.0
			)
			var paid_parts: Array[String] = []
			for resource_id in record.construction_total_costs:
				paid_parts.append("%s %d/%d" % [
					"木" if StringName(resource_id) == &"wood" else "粮",
					int(record.construction_paid_costs.get(resource_id, 0)),
					int(record.construction_total_costs[resource_id]),
				])
			var state_text := (
				"缺料暂停"
				if StringName(record.construction_state) == &"BLOCKED_RESOURCES"
				else "施工中"
			)
			progress_text = "%s · %d%% · 已扣 %s · 预计第 %d 日完成" % [
				state_text,
				progress_percent,
				"无" if paid_parts.is_empty() else "、".join(paid_parts),
				int(record.construction_complete_day),
			]
		else:
			progress_text = "已完工 · 第 %d 日投入运行" % int(
				record.construction_complete_day
			)
	else:
		effect_text = _get_fixed_building_effect_summary(
			StringName(record.template_id),
			effect_text
		)
	return {
		"level_text": "当前等级：L%d" % level,
		"next_level_text": "下一等级：当前切片未开放",
		"investment_text": investment_text,
		"duration_text": duration_text,
		"effect_text": effect_text,
		"prerequisite_text": prerequisite_text,
		"progress_text": progress_text,
		"status_text": str(status.label),
		"upgrade_available": false,
		"construction_priority": int(
			record.get("construction_priority", CONSTRUCTION_PRIORITY_NORMAL)
		),
		"construction_state": StringName(
			record.get("construction_state", &"COMPLETED")
		),
	}


func get_building_detail_state(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {}
	var definition := get_definition(StringName(record.definition_id))
	if definition == null:
		return {
			"primary_status_id": &"FIXED",
			"primary_status_text": str(record.prototype_status),
			"effect_text": _get_fixed_building_effect_summary(
				StringName(record.template_id),
				str(record.effect_summary)
			),
			"road_text": "道路：不需要",
			"orientation_text": "朝向：北",
			"progress_visible": false,
			"priority_visible": false,
			"status_reason_text": "",
		}
	var constructing := StringName(record.lifecycle_state) == &"constructing"
	var required := maxi(int(record.construction_required_milliseconds), 1)
	var progress := clampi(
		int(record.construction_progress_milliseconds),
		0,
		required
	)
	var progress_percent := floori(float(progress) / float(required) * 100.0)
	var entrance := get_building_entrance_info(placement_id)
	var connected := bool(entrance.get("connected", false))
	var primary_status_id: StringName
	var primary_status_text := ""
	var status_reason_text := ""
	if constructing:
		if city_time_paused:
			primary_status_id = &"GLOBAL_PAUSED"
			primary_status_text = "全局暂停"
			status_reason_text = "恢复时间后继续施工"
			if StringName(record.construction_state) == &"BLOCKED_RESOURCES":
				status_reason_text += "；当前另有材料不足"
		elif StringName(record.construction_state) == &"BLOCKED_RESOURCES":
			primary_status_id = &"MISSING_RESOURCES"
			primary_status_text = "缺料暂停"
			status_reason_text = "补足材料后从当前进度继续"
		elif progress <= 0:
			primary_status_id = &"WAITING_CONSTRUCTION"
			primary_status_text = "等待施工"
			status_reason_text = "时间推进后开始投入材料"
		else:
			primary_status_id = &"CONSTRUCTING"
			primary_status_text = "施工中"
	else:
		if definition.requires_road and not connected:
			primary_status_id = &"COMPLETED_DISCONNECTED"
			primary_status_text = "未连接道路"
			status_reason_text = "连接入口旁道路后开始生产"
		elif int(record.disabled_until_day) >= current_day:
			primary_status_id = &"EVENT_DISABLED"
			primary_status_text = "事件停产"
			status_reason_text = "停产至第 %d 日结算后" % int(record.disabled_until_day)
		elif get_pressure_modifier_permille(&"production") < 1000:
			primary_status_id = &"PRESSURE_AFFECTED"
			primary_status_text = "受压力影响"
			status_reason_text = "主线压力降低当前产出"
		else:
			primary_status_id = &"PRODUCING"
			primary_status_text = "生产中"
	var total_costs: Dictionary = record.construction_total_costs
	var paid_costs: Dictionary = record.construction_paid_costs
	var paid_parts: Array[String] = []
	var remaining_parts: Array[String] = []
	for resource_id in total_costs:
		var total := int(total_costs[resource_id])
		var paid := int(paid_costs.get(resource_id, 0))
		var label := _resource_display_name(StringName(resource_id))
		paid_parts.append("%s %d/%d" % [label, paid, total])
		remaining_parts.append("%s %d" % [label, maxi(total - paid, 0)])
	var missing_parts: Array[String] = []
	if constructing and StringName(record.construction_state) == &"BLOCKED_RESOURCES":
		var next_payment := _get_next_construction_payment(record)
		for resource_id in next_payment:
			var shortfall := maxi(
				int(next_payment[resource_id])
				- _nation_state.get_resource(StringName(resource_id)),
				0
			)
			if shortfall > 0:
				missing_parts.append("%s %d" % [
					_resource_display_name(StringName(resource_id)),
					shortfall,
				])
	var eta_text := "已完成"
	if constructing:
		if StringName(record.construction_state) == &"BLOCKED_RESOURCES":
			eta_text = "等待材料"
		elif city_time_paused:
			eta_text = "恢复时间后计算"
		else:
			var modifier := maxi(get_pressure_modifier_permille(&"construction"), 1)
			var effective_remaining := ceili(
				float(required - progress) * 1000.0 / float(modifier)
			)
			var days_needed := maxi(ceili(float(effective_remaining) / float(MILLISECONDS_PER_DAY)), 1)
			eta_text = "第 %d 日" % (current_day + days_needed)
	var production := definition.get_capability(&"production")
	var base_amount := 0
	var actual_amount := 0
	var production_resource := ""
	if production != null:
		base_amount = int(production.amount)
		production_resource = _resource_display_name(production.resource_id)
		if not constructing and connected and int(record.disabled_until_day) < current_day:
			actual_amount = _get_production_amount(definition, production)
	var orientation := clampi(int(record.orientation), 0, 3)
	return {
		"primary_status_id": primary_status_id,
		"primary_status_text": primary_status_text,
		"status_reason_text": status_reason_text,
		"effect_text": (
			"%s +%d/日" % [production_resource, base_amount]
			if production != null
			else _get_definition_effect_summary(definition)
		),
		"road_text": (
			"道路：%s · 入口朝%s" % ["已连接" if connected else "未连接", ORIENTATION_NAMES[orientation]]
			if definition.requires_road
			else "道路：不需要"
		),
		"orientation_text": "朝向：%s · 占地 %d × %d" % [
			ORIENTATION_NAMES[orientation],
			int(record.footprint.x),
			int(record.footprint.y),
		],
		"progress_visible": constructing,
		"progress_percent": progress_percent,
		"progress_text": "进度：%d%%" % progress_percent,
		"paid_text": "已投入：%s" % ("无" if paid_parts.is_empty() else "、".join(paid_parts)),
		"remaining_text": "仍需：%s" % ("无" if remaining_parts.is_empty() else "、".join(remaining_parts)),
		"missing_text": "缺少：%s" % ("无" if missing_parts.is_empty() else "、".join(missing_parts)),
		"eta_text": "预计完成：%s" % eta_text,
		"priority_visible": constructing,
		"priority": int(record.construction_priority),
		"priority_help_text": "材料或施工能力不足时，高优先级先推进。",
		"base_output_text": "基础产出：%s +%d/日" % [production_resource, base_amount],
		"actual_output_text": "当前实际：%s +%d/日" % [production_resource, actual_amount],
		"pressure_effect_text": "影响：主线压力 -%d%%" % (
			100 - roundi(float(get_pressure_modifier_permille(&"production")) / 10.0)
		),
	}


func _get_next_construction_payment(record: Dictionary) -> Dictionary:
	var required := maxi(int(record.construction_required_milliseconds), 1)
	var progress := int(record.construction_progress_milliseconds)
	var modifier := get_pressure_modifier_permille(&"construction")
	var next_progress := mini(
		progress + maxi(roundi(float(CONSTRUCTION_TICK_MILLISECONDS * modifier) / 1000.0), 1),
		required
	)
	var result: Dictionary = {}
	for resource_id in record.construction_total_costs:
		var total := int(record.construction_total_costs[resource_id])
		var target_paid := total if next_progress >= required else floori(
			float(total * next_progress) / float(required)
		)
		var amount := target_paid - int(record.construction_paid_costs.get(resource_id, 0))
		if amount > 0:
			result[StringName(resource_id)] = amount
	return result


func _resource_display_name(resource_id: StringName) -> String:
	return {&"wood": "木材", &"food": "粮食"}.get(resource_id, str(resource_id))


func get_construction_in_progress_count() -> int:
	var count := (
		1
		if get_build_slot_state() in [
			BUILD_SLOT_PRODUCING,
			BUILD_SLOT_WAITING_MATERIAL,
		]
		else 0
	)
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if (
			not record.is_empty()
			and StringName(record.lifecycle_state) == &"constructing"
		):
			count += 1
	return count


func get_first_war_preparation_assessment() -> Dictionary:
	var committed_count := get_first_war_committed_count()
	var food_cost := get_first_war_food_cost(committed_count)
	var pressure_event := FIRST_MAP_THREAT_SCHEDULE.get_event_for_day(5)
	var defense_target := (
		pressure_event.defense_threshold
		if pressure_event != null
		else 20
	)
	var suggestions: Array[String] = []
	if committed_count < enemy_count:
		suggestions.append("补充兵力")
	if food < food_cost:
		suggestions.append("补充粮食")
	if get_city_defense() < defense_target:
		suggestions.append("建造瞭望塔")
	return {
		"committed_count": committed_count,
		"enemy_count": enemy_count,
		"troop_status": (
			"不低于当前敌军"
			if committed_count >= enemy_count
			else "少于当前敌军 %d" % (enemy_count - committed_count)
		),
		"food": food,
		"food_cost": food_cost,
		"supply_status": (
			"粮草充足"
			if food >= food_cost
			else "缺少粮食 %d" % (food_cost - food)
		),
		"city_defense": get_city_defense(),
		"defense_target": defense_target,
		"defense_status": (
			"达到首轮骚扰减损线"
			if get_city_defense() >= defense_target
			else "低于减损线 %d" % (defense_target - get_city_defense())
		),
		"suggestion": (
			"当前没有明确短板"
			if suggestions.is_empty()
			else "建议：" + "、".join(suggestions)
		),
	}


func _get_definition_cost_text(definition: BuildingDefinition) -> String:
	var parts: Array[String] = []
	if definition.wood_cost > 0:
		parts.append("木材 %d" % definition.wood_cost)
	if definition.food_cost > 0:
		parts.append("粮食 %d" % definition.food_cost)
	return "无资源消耗" if parts.is_empty() else "、".join(parts)


func _get_definition_compact_cost_text(
	definition: BuildingDefinition
) -> String:
	var parts: Array[String] = []
	if definition.wood_cost > 0:
		parts.append("木%d" % definition.wood_cost)
	if definition.food_cost > 0:
		parts.append("粮%d" % definition.food_cost)
	return "无消耗" if parts.is_empty() else " ".join(parts)


func _get_placement_cost_with_available_text(
	definition: BuildingDefinition
) -> String:
	var parts: Array[String] = []
	if definition.wood_cost > 0:
		parts.append("木材 %d（现有 %d）" % [definition.wood_cost, wood])
	if definition.food_cost > 0:
		parts.append("粮食 %d（现有 %d）" % [definition.food_cost, food])
	return "无资源消耗" if parts.is_empty() else "、".join(parts)


func _get_definition_effect_summary(
	definition: BuildingDefinition
) -> String:
	if definition.placement_kind == PLACEMENT_KIND_ROAD:
		return "接通城市路网"
	var production := definition.get_capability(&"production")
	if production != null:
		return "%s +%d/日" % [
			"木材" if production.resource_id == &"wood" else "粮食",
			production.amount,
		]
	var storage := definition.get_capability(&"storage")
	if storage != null:
		return "木材／粮食容量各 +%d" % storage.amount
	var defense := definition.get_capability(&"defense")
	if defense != null:
		return "城防 +%d" % defense.amount
	return definition.description


func _get_definition_prerequisite_summary(
	definition: BuildingDefinition
) -> String:
	if definition.requires_road:
		return "建成后需接入道路才生效"
	return "无额外前置"


func _get_definition_unavailable_reason(
	definition: BuildingDefinition
) -> String:
	if is_city_action_locked_for_battle():
		return "敌袭待处理"
	if definition.build_days > 0:
		return ""
	var reasons: Array[String] = []
	if wood < definition.wood_cost:
		reasons.append("缺木%d" % (definition.wood_cost - wood))
	if food < definition.food_cost:
		reasons.append("缺粮%d" % (definition.food_cost - food))
	return "、".join(reasons)


func _get_fixed_building_effect_summary(
	template_id: StringName,
	fallback: String
) -> String:
	match template_id:
		&"barracks":
			var batch_size := get_training_batch_size()
			return "每批征募 %d 人 · 消耗 %d 粮 · 次日完成" % [
				batch_size,
				batch_size * INFANTRY_ROLE.recruit_food_per_unit,
			]
		&"granary":
			return "当前城市木材／粮食基础容量各 %d" % (
				BASE_RESOURCE_CAPACITY
			)
		&"academy":
			return "每日结算科技点 +1"
		&"city_gate":
			return "提供基础城防 10"
		&"manor":
			return "提供城市道路网络根格"
	return fallback


func get_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition_id in _definitions_by_id:
		result.append(definition_id)
	result.sort()
	return result


func get_build_catalog_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition_id in _definitions_by_id:
		var definition := get_definition(definition_id)
		if definition != null and definition.build_catalog_visible:
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
	var entrance_info := get_building_entrance_info(placement_id)
	if not entrance_info.is_empty():
		result.entrance_cell = entrance_info.get("entrance_cell", Vector2i.ZERO)
		result.entrance_facing = entrance_info.get(
			"entrance_facing",
			Vector2i.ZERO
		)
		result.road_contact_cell = entrance_info.get(
			"road_contact_cell",
			Vector2i.ZERO
		)
		result.entrance_connection_state = entrance_info.get(
			"connection_state",
			&"not_required"
		)
	return result


func set_building_diagnostic_visible(placement_id: int, visible: bool) -> void:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return
	var building := record.get("node") as Node2D
	if not is_instance_valid(building):
		return
	building.set_meta("show_entrance_marker", visible)
	_refresh_placed_building_visual(placement_id)


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
	if StringName(record.lifecycle_state) == &"constructing":
		if city_time_paused:
			return {"state": &"global_paused", "label": "全局暂停"}
		if StringName(record.construction_state) == &"BLOCKED_RESOURCES":
			return {"state": &"blocked_resources", "label": "缺料暂停"}
		return {
			"state": &"constructing",
			"label": "施工中 · 预计第 %d 日完成" % int(
				record.construction_complete_day
			),
		}
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
		return {
			"state": &"disabled",
			"label": "停用：未接入道路 · 入口未接路",
		}
	if record.placement_kind == PLACEMENT_KIND_FIXED:
		return {"state": &"fixed", "label": "固定 / 可选择"}
	if bool(record.requires_road):
		return {"state": &"operational", "label": "运行中：入口已接路"}
	return {"state": &"operational", "label": "运行中"}


func is_building_operational(placement_id: int) -> bool:
	var state_id: StringName = get_operational_status(placement_id).state
	return state_id in [&"operational", &"fixed", &"connected"]


func is_building_connected_to_road(placement_id: int) -> bool:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty() or not bool(record.requires_road):
		return not record.is_empty()
	var entrance_info := get_building_entrance_info(placement_id)
	return bool(entrance_info.get("connected", false))


func get_connected_road_cells() -> Dictionary:
	return CITY_GRID_RULES.get_connected_road_cells(
		get_all_road_cells(),
		city_spatial_foundation.get_road_root_cells()
	)


func _refresh_road_visual_projection() -> void:
	if is_instance_valid(city_spatial_foundation):
		city_spatial_foundation.set_player_road_cells(get_player_road_cells())


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
	_refresh_road_visual_projection()
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


func get_formal_road_cells() -> Dictionary:
	return city_spatial_foundation.get_formal_road_cells()


func get_formal_reserved_cells() -> Dictionary:
	return city_spatial_foundation.get_formal_reserved_cells()


func get_formal_wall_cells() -> Dictionary:
	return city_spatial_foundation.get_formal_wall_cells()


func get_formal_gate_cells() -> Dictionary:
	return city_spatial_foundation.get_formal_gate_cells()


func get_entrance_info_for_definition(
	origin_cell: Vector2i,
	definition: BuildingDefinition,
	orientation := ORIENTATION_NORTH
) -> Dictionary:
	if definition == null:
		return {"valid": false, "error": &"missing_definition"}
	# Definitions describe their allowed perimeter contacts through
	# road_anchor_offsets.  Select one stable adapter from that definition, then
	# let CityGridRules rotate the adapter with the real footprint so the contact
	# cell, facing, and occupied shape remain one deterministic query.
	var adapter := CITY_GRID_RULES.get_definition_entrance_adapter(
		definition.footprint,
		definition.road_anchor_offsets
	)
	var resolved: Dictionary = CITY_GRID_RULES.resolve_entrance(
		origin_cell,
		definition.footprint,
		Vector2i(adapter.entrance_cell),
		Vector2i(adapter.entrance_facing),
		orientation
	)
	if not bool(resolved.get("valid", false)):
		return resolved
	var connected_roads := get_connected_road_cells()
	resolved["connected"] = connected_roads.has(
		Vector2i(resolved.road_contact_cell)
	)
	resolved["connection_state"] = (
		&"connected"
		if bool(resolved.connected)
		else &"disconnected"
	)
	return resolved


func get_building_entrance_info(placement_id: int) -> Dictionary:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return {}
	var definition := get_definition(StringName(record.definition_id))
	if definition == null or not bool(record.requires_road):
		return {
			"valid": true,
			"required": false,
			"connection_state": &"not_required",
		}
	var result := get_entrance_info_for_definition(
		Vector2i(record.origin_cell),
		definition,
		int(record.orientation)
	)
	result["required"] = true
	return result


func _get_spatial_block_reason(cell: Vector2i) -> String:
	if city_spatial_foundation.is_formal_reserved_cell(cell):
		return "占用保留区域"
	if city_spatial_foundation.is_formal_gate_cell(cell):
		return "占用城门槽位"
	if city_spatial_foundation.is_formal_wall_cell(cell):
		return "占用城墙"
	if city_spatial_foundation.is_formal_road_cell(cell):
		return "占用道路"
	return ""


func evaluate_spatial_legality(
	placement_kind: StringName,
	cells: Array[Vector2i],
	ignore_placement_id := -1
) -> Dictionary:
	var placement_kinds: Dictionary = {}
	for placement_id in _placement_order:
		var record: Dictionary = _building_records_by_id.get(placement_id, {})
		if not record.is_empty():
			placement_kinds[placement_id] = StringName(record.placement_kind)
	var result := CITY_GRID_RULES.evaluate_placement_legality(
		placement_kind,
		cells,
		Rect2i(Vector2i.ZERO, city_spatial_foundation.get_map_grid_size()),
		_occupied_cells,
		placement_kinds,
		get_all_road_cells(),
		get_formal_reserved_cells(),
		get_formal_wall_cells(),
		get_formal_gate_cells(),
		ignore_placement_id
	)
	result["reason_text"] = _placement_reason_text(
		StringName(result.reason_code),
		placement_kind,
		Array(result.conflicting_cells)
	)
	return result


func _placement_reason_text(
	reason_code: StringName,
	placement_kind: StringName,
	conflicting_cells: Array
) -> String:
	match reason_code:
		CITY_GRID_RULES.REASON_OUT_OF_BOUNDS:
			return "道路超出地图边界" if placement_kind == PLACEMENT_KIND_ROAD else "超出可建区域"
		CITY_GRID_RULES.REASON_ROAD_OVERLAP:
			return "所选格子已经是道路" if placement_kind == PLACEMENT_KIND_ROAD else "与道路重叠"
		CITY_GRID_RULES.REASON_BUILDING_OVERLAP:
			return "道路穿过建筑占地" if placement_kind == PLACEMENT_KIND_ROAD else "与其他建筑重叠"
		CITY_GRID_RULES.REASON_IMMOVABLE_OBJECT_OVERLAP:
			for value in conflicting_cells:
				var cell := Vector2i(value)
				if city_spatial_foundation.is_formal_reserved_cell(cell):
					return "道路占用保留区域" if placement_kind == PLACEMENT_KIND_ROAD else "占用保留区域"
				if city_spatial_foundation.is_formal_gate_cell(cell):
					return "道路占用城门槽位" if placement_kind == PLACEMENT_KIND_ROAD else "占用城门槽位"
				if city_spatial_foundation.is_formal_wall_cell(cell):
					return "道路占用城墙" if placement_kind == PLACEMENT_KIND_ROAD else "占用城墙"
			return "道路穿过不可移动建筑" if placement_kind == PLACEMENT_KIND_ROAD else "与不可移动建筑重叠"
	return ""


func _resource_shortages(definition: BuildingDefinition) -> Array[Dictionary]:
	var shortages: Array[Dictionary] = []
	for resource in [
		[&"wood", "木材", definition.wood_cost],
		[&"food", "粮食", definition.food_cost],
	]:
		var missing := maxi(int(resource[2]) - _nation_state.get_resource(resource[0]), 0)
		if missing > 0:
			shortages.append({
				"resource_id": resource[0],
				"display_name": resource[1],
				"missing": missing,
			})
	return shortages


func _shortage_text(shortages: Array) -> String:
	var parts: Array[String] = []
	for shortage in shortages:
		parts.append("%s %d" % [shortage.display_name, int(shortage.missing)])
	return "、".join(parts)


func _player_failure_message(validation: Dictionary) -> String:
	var reason_code := StringName(validation.get("reason_code", &"UNKNOWN_COMMIT_FAILURE"))
	match reason_code:
		CITY_GRID_RULES.REASON_ROAD_OVERLAP:
			return "无法建造：与道路重叠"
		CITY_GRID_RULES.REASON_BUILDING_OVERLAP:
			return "无法建造：与其他建筑重叠"
		CITY_GRID_RULES.REASON_IMMOVABLE_OBJECT_OVERLAP:
			return "无法建造：此处有不可移动建筑"
		CITY_GRID_RULES.REASON_OUT_OF_BOUNDS:
			return "无法建造：超出可建区域"
		&"INVALID_MAP_TARGET", &"UI_OCCLUDED":
			return "无法建造：请选择城内空地"
		&"INSUFFICIENT_RESOURCE", &"INSUFFICIENT_RESOURCES", &"INSUFFICIENT_FUNDS":
			var shortages: Array = validation.get("shortages", [])
			if not shortages.is_empty():
				return "无法建造：缺少%s" % _shortage_text(shortages)
		&"STATE_CHANGED":
			return "建造失败：状态已变化，请重新选择位置"
		&"UNKNOWN_COMMIT_FAILURE":
			return "建造失败，请重试（R0B-UNKNOWN）"
	var reason_text := str(
		validation.get("reason_text", validation.get("reason", ""))
	)
	return (
		"无法建造：%s" % reason_text
		if not reason_text.is_empty()
		else "建造失败，请重试（R0B-UNKNOWN）"
	)


func _ready_placement_failure_message(validation: Dictionary) -> String:
	var reason_code := StringName(
		validation.get("reason_code", &"UNKNOWN_COMMIT_FAILURE")
	)
	match reason_code:
		CITY_GRID_RULES.REASON_ROAD_OVERLAP:
			return "无法放置：与道路重叠"
		CITY_GRID_RULES.REASON_BUILDING_OVERLAP:
			return "无法放置：与其他建筑重叠"
		CITY_GRID_RULES.REASON_IMMOVABLE_OBJECT_OVERLAP:
			return "无法放置：此处有不可移动建筑"
		CITY_GRID_RULES.REASON_OUT_OF_BOUNDS:
			return "无法放置：超出可建区域"
		&"UI_OCCLUDED", &"INVALID_MAP_TARGET":
			return "无法放置：请选择城内空地"
		&"STATE_CHANGED":
			return "位置状态已变化，请重试"
		_:
			return "放置失败，请重试（R0C-UNKNOWN）"


func _show_placement_feedback(message: String) -> void:
	_placement_feedback_generation += 1
	var generation := _placement_feedback_generation
	placement_feedback.text = message
	placement_feedback.visible = true
	await get_tree().create_timer(2.5).timeout
	if generation == _placement_feedback_generation:
		placement_feedback.visible = false


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
	check_resources := true,
	orientation := ORIENTATION_NORTH,
	ignore_placement_id := -1
) -> Dictionary:
	if definition == null:
		return _validation_result(false, "缺少建筑定义")
	var footprint := get_rotated_footprint(definition, orientation)
	if footprint == Vector2i.ZERO:
		return _validation_result(false, "建筑朝向非法")
	var footprint_cells := get_footprint_cells(
		origin_cell,
		footprint
	)
	var screen_rect := get_footprint_screen_rect(
		origin_cell,
		footprint
	)
	var spatial := evaluate_spatial_legality(
		definition.placement_kind,
		footprint_cells,
		ignore_placement_id
	)
	var spatial_blocks_before_ui := (
		not bool(spatial.is_legal)
		and (
			StringName(spatial.reason_code) == CITY_GRID_RULES.REASON_OUT_OF_BOUNDS
			or not Array(spatial.conflicting_placement_ids).is_empty()
		)
	)
	if spatial_blocks_before_ui:
		return _validation_result(
			false,
			str(spatial.reason_text),
			screen_rect,
			spatial
		)
	if check_ui:
		if not _screen_rect_is_inside_viewport(screen_rect):
			return _validation_result(
				false,
				"超出可操作区域",
				screen_rect,
				{"reason_code": &"UI_OCCLUDED"}
			)
		for ui_control in _get_ui_occlusion_controls():
			if (
				ui_control.is_visible_in_tree()
				and ui_control.get_global_rect().grow(
					UI_SAFETY_MARGIN
				).intersects(screen_rect)
				):
				return _validation_result(
					false,
					"被界面遮挡",
					screen_rect,
					{"reason_code": &"UI_OCCLUDED"}
				)
	if not bool(spatial.is_legal):
		return _validation_result(
			false,
			str(spatial.reason_text),
			screen_rect,
			spatial
		)
	if check_resources and not _can_pay_definition(definition):
		return _validation_result(
			false,
			"木材不足（需要 %d）" % definition.wood_cost,
			screen_rect,
			{"reason_code": &"INSUFFICIENT_RESOURCES"}
		)
	var entrance_info := get_entrance_info_for_definition(
		origin_cell,
		definition,
		orientation
	)
	var connection_state: StringName = &"not_required"
	if definition.requires_road:
		if not bool(entrance_info.get("valid", false)):
			return _validation_result(
				false,
				"入口位置无效",
				screen_rect,
				{"reason_code": CITY_GRID_RULES.REASON_INVALID_ENTRANCE}
			)
		connection_state = StringName(
			entrance_info.get("connection_state", &"disconnected")
		)
	return _validation_result(
		true,
		"",
		screen_rect,
		{
			"is_legal": true,
			"reason_code": CITY_GRID_RULES.REASON_NONE,
			"conflicting_cells": [],
			"conflicting_placement_ids": [],
			"connection_state": connection_state,
			"entrance_info": entrance_info,
		}
	)


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
		true,
		_selected_definition.build_days <= 0,
		preview_orientation
	)
	var shortages := (
		[]
		if get_build_slot_state() == BUILD_SLOT_PLACEMENT_ACTIVE
		else _resource_shortages(_selected_definition)
	)
	validation["shortages"] = shortages
	preview_valid = validation.valid
	_last_preview_validation = validation.duplicate(true)
	preview_invalid_reason = validation.reason
	preview_connection_state = StringName(
		validation.get("connection_state", &"not_required")
	)
	preview_entrance_info = Dictionary(
		validation.get("entrance_info", {})
	)
	construction_preview.position = cell_to_map_local(preview_origin_cell)
	var preview_is_connected := (
		preview_connection_state == &"connected"
		or preview_connection_state == &"not_required"
	)
	var preview_has_warning := not shortages.is_empty() or not preview_is_connected
	preview_body.color = (
		PREVIEW_INVALID_COLOR
		if not preview_valid
		else (
			PREVIEW_DISCONNECTED_COLOR
			if preview_has_warning
			else PREVIEW_VALID_COLOR
		)
	)
	preview_outline.default_color = (
		PREVIEW_INVALID_OUTLINE
		if not preview_valid
		else (
			PREVIEW_DISCONNECTED_OUTLINE
			if preview_has_warning
			else PREVIEW_VALID_OUTLINE
		)
	)
	var preview_size := Vector2(
		get_rotated_footprint(_selected_definition, preview_orientation)
	) * GRID_SIZE
	preview_conflict_mark.points = PackedVector2Array([
		Vector2(8.0, 8.0),
		preview_size - Vector2(8.0, 8.0),
		Vector2(preview_size.x - 8.0, 8.0),
		Vector2(8.0, preview_size.y - 8.0),
	])
	preview_conflict_mark.visible = not preview_valid
	_update_preview_entrance_marker()
	if get_build_slot_state() == BUILD_SLOT_PLACEMENT_ACTIVE:
		preview_label.text = (
			(
				"可放置"
				if preview_connection_state != &"disconnected"
				else "入口未接路"
			)
			if preview_valid
			else _ready_placement_failure_message(validation).trim_prefix(
				"无法放置："
			)
		)
	else:
		preview_label.text = (
			"%s L%d · 朝%s\n%s · %s\n%s" % [
				_selected_definition.display_name,
				_selected_definition.level,
				ORIENTATION_NAMES[preview_orientation],
				_get_definition_compact_cost_text(_selected_definition),
				(
					"即时"
					if _selected_definition.build_days <= 0
					else "第 %d 日完成" % (
						current_day + _selected_definition.build_days
					)
				),
				_preview_connection_label(),
			]
			if preview_valid
			else "%s L%d · 朝%s\n%s" % [
				_selected_definition.display_name,
				_selected_definition.level,
				ORIENTATION_NAMES[preview_orientation],
				preview_invalid_reason,
			]
		)
	_sync_construction_ui()


func get_preview_connection_state() -> StringName:
	return preview_connection_state


func _preview_connection_label() -> String:
	if not preview_valid:
		return preview_invalid_reason
	if preview_connection_state == &"connected":
		return "入口已接路 · 可放置"
	if preview_connection_state == &"disconnected":
		return "可建，但入口未接路"
	return "可放置"


func _update_preview_entrance_marker() -> void:
	if preview_entrance_marker == null:
		return
	if not is_placing() or _selected_definition == null:
		preview_entrance_marker.visible = false
		return
	var footprint := get_rotated_footprint(
		_selected_definition,
		preview_orientation
	)
	if footprint == Vector2i.ZERO or preview_entrance_info.is_empty():
		preview_entrance_marker.visible = false
		return
	var entrance_cell := Vector2i(
		preview_entrance_info.get("entrance_cell", Vector2i.ZERO)
	)
	var facing := Vector2i(
		preview_entrance_info.get("entrance_facing", Vector2i.UP)
	)
	var center := (Vector2(entrance_cell) + Vector2(0.5, 0.5)) * GRID_SIZE
	var tip := center + Vector2(facing) * 12.0
	var side := Vector2(-facing.y, facing.x) * 7.0
	preview_entrance_marker.polygon = PackedVector2Array([
		tip,
		center - Vector2(facing) * 4.0 + side,
		center - Vector2(facing) * 4.0 - side,
	])
	preview_entrance_marker.color = (
		PREVIEW_INVALID_OUTLINE
		if not preview_valid
		else (
			PREVIEW_DISCONNECTED_OUTLINE
			if (
				preview_connection_state == &"disconnected"
				or not _resource_shortages(_selected_definition).is_empty()
			)
			else PREVIEW_VALID_OUTLINE
		)
	)
	preview_entrance_marker.visible = true


func _apply_preview_geometry(
	definition: BuildingDefinition,
	orientation: int
) -> void:
	var footprint := get_rotated_footprint(definition, orientation)
	var world_size := Vector2(footprint) * GRID_SIZE
	preview_body.polygon = _rectangle_polygon(world_size)
	preview_outline.points = _rectangle_outline_points(world_size)
	preview_label.size = world_size
	preview_label.position = Vector2.ZERO
	placement_grid.configure_grid(footprint, GRID_SIZE)


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
	screen_rect := Rect2(),
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"valid": valid,
		"is_legal": valid,
		"reason": reason,
		"reason_text": reason,
		"reason_code": CITY_GRID_RULES.REASON_NONE,
		"conflicting_cells": [],
		"conflicting_placement_ids": [],
		"screen_rect": screen_rect,
	}
	result.merge(extra, true)
	return result


func _create_placed_building_node(
	placement_id: int,
	origin_cell: Vector2i,
	definition: BuildingDefinition,
	footprint: Vector2i,
	orientation: int
) -> Node2D:
	var building := GRAYBOX_BUILDING_VISUAL.new() as GrayboxBuildingVisual
	building.name = "Placement%03d" % placement_id
	building.position = cell_to_map_local(origin_cell)
	building.set_meta("placement_id", placement_id)
	var is_road := definition.placement_kind == PLACEMENT_KIND_ROAD
	building.configure(
		definition.definition_id,
		definition.display_name,
		definition.building_type,
		footprint,
		orientation,
		definition.body_color,
		definition.outline_color,
		definition.requires_road,
		is_road,
		&"running",
		1.0,
		&"not_required",
		false
	)

	placed_buildings.add_child(building)
	return building


func _entrance_polygon(world_size: Vector2, orientation: int) -> PackedVector2Array:
	var width := minf(20.0, world_size.x * 0.3)
	match orientation:
		ORIENTATION_NORTH:
			return PackedVector2Array([
				Vector2(world_size.x * 0.5 - width * 0.5, 0.0),
				Vector2(world_size.x * 0.5 + width * 0.5, 0.0),
				Vector2(world_size.x * 0.5 + width * 0.5, 10.0),
				Vector2(world_size.x * 0.5 - width * 0.5, 10.0),
			])
		ORIENTATION_EAST:
			return PackedVector2Array([
				Vector2(world_size.x - 10.0, world_size.y * 0.5 - width * 0.5),
				Vector2(world_size.x, world_size.y * 0.5 - width * 0.5),
				Vector2(world_size.x, world_size.y * 0.5 + width * 0.5),
				Vector2(world_size.x - 10.0, world_size.y * 0.5 + width * 0.5),
			])
		ORIENTATION_SOUTH:
			return PackedVector2Array([
				Vector2(world_size.x * 0.5 - width * 0.5, world_size.y - 10.0),
				Vector2(world_size.x * 0.5 + width * 0.5, world_size.y - 10.0),
				Vector2(world_size.x * 0.5 + width * 0.5, world_size.y),
				Vector2(world_size.x * 0.5 - width * 0.5, world_size.y),
			])
		_:
			return PackedVector2Array([
				Vector2(0.0, world_size.y * 0.5 - width * 0.5),
				Vector2(10.0, world_size.y * 0.5 - width * 0.5),
				Vector2(10.0, world_size.y * 0.5 + width * 0.5),
				Vector2(0.0, world_size.y * 0.5 + width * 0.5),
			])


func _entrance_marker_polygon(
	world_size: Vector2,
	_footprint: Vector2i,
	orientation: int
) -> PackedVector2Array:
	var width := minf(18.0, minf(world_size.x, world_size.y) * 0.28)
	var depth := 12.0
	var center := Vector2.ZERO
	var facing := Vector2.UP
	match orientation:
		ORIENTATION_NORTH:
			center = Vector2(world_size.x * 0.5, 0.0)
			facing = Vector2.UP
		ORIENTATION_EAST:
			center = Vector2(world_size.x, world_size.y * 0.5)
			facing = Vector2.RIGHT
		ORIENTATION_SOUTH:
			center = Vector2(world_size.x * 0.5, world_size.y)
			facing = Vector2.DOWN
		_:
			center = Vector2(0.0, world_size.y * 0.5)
			facing = Vector2.LEFT
	var side := Vector2(-facing.y, facing.x) * (width * 0.5)
	return PackedVector2Array([
		center + facing * depth,
		center - facing * 2.0 + side,
		center - facing * 2.0 - side,
	])


func _refresh_placed_building_visual(placement_id: int) -> void:
	var record: Dictionary = _building_records_by_id.get(placement_id, {})
	if record.is_empty():
		return
	var building := record.get("node") as Node2D
	if building == null or not is_instance_valid(building):
		return
	var visual := building as GrayboxBuildingVisual
	if visual == null:
		return
	var entrance_info := get_building_entrance_info(placement_id)
	var connection_state := StringName(
		entrance_info.get("connection_state", &"not_required")
	)
	var is_selected := bool(building.get_meta("show_entrance_marker", false))
	visual.visible = StringName(record.placement_kind) != PLACEMENT_KIND_ROAD
	visual.update_presentation(
		StringName(record.lifecycle_state),
		_get_building_presentation_progress(record),
		connection_state,
		is_selected,
		is_selected
	)


func _get_building_presentation_progress(record: Dictionary) -> float:
	if StringName(record.get("lifecycle_state", &"")) != &"constructing":
		return 1.0
	var started_day := int(record.get("construction_started_day", current_day))
	var complete_day := int(record.get("construction_complete_day", started_day + 1))
	var total_days := maxf(float(complete_day - started_day), 1.0)
	var elapsed_days := float(current_day - started_day) + get_day_progress_ratio()
	return clampf(elapsed_days / total_days, 0.0, 0.99)


func _release_runtime_record(
	placement_id: int,
	require_complete_ownership: bool,
	emit_removal_signal := true
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
	if record.placement_kind == PLACEMENT_KIND_ROAD:
		_refresh_road_visual_projection()
	if emit_removal_signal:
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


func _configure_time_speed_options() -> void:
	time_speed_option.clear()
	for speed in CITY_TIME_SPEEDS:
		time_speed_option.add_item("%d×" % int(speed))
		time_speed_option.set_item_metadata(
			time_speed_option.item_count - 1,
			speed
		)
	time_speed_option.select(0)


func _on_time_speed_selected(index: int) -> void:
	set_city_time_speed(float(time_speed_option.get_item_metadata(index)))


func _register_noticeboard_missions() -> void:
	for mission in NOTICEBOARD_MISSIONS:
		if mission == null or not mission.is_valid():
			push_error("Invalid noticeboard mission definition")
			continue
		if _mission_definitions_by_id.has(mission.mission_id):
			push_error(
				"Duplicate noticeboard mission id: %s"
				% mission.mission_id
			)
			continue
		_mission_definitions_by_id[mission.mission_id] = mission


func _get_noticeboard_card(mission_id: StringName) -> Panel:
	var card_name: String = str({
		&"noticeboard.outskirts_sweep.v0": "OutskirtsSweepCard",
		&"noticeboard.supply_relief.v0": "SupplyReliefCard",
		&"noticeboard.missing_scout.v0": "MissingScoutCard",
	}.get(mission_id, ""))
	if card_name.is_empty():
		return null
	return noticeboard_panel.get_node(card_name) as Panel


func _get_noticeboard_mission_states() -> Dictionary:
	var states := {}
	for mission in NOTICEBOARD_MISSIONS:
		states[mission.mission_id] = get_noticeboard_mission_state(
			mission.mission_id
		)
	return states


func _refresh_noticeboard_ui() -> void:
	for mission in NOTICEBOARD_MISSIONS:
		var card := _get_noticeboard_card(mission.mission_id)
		if card == null:
			continue
		(card.get_node("Title") as Label).text = mission.title
		(card.get_node("Description") as Label).text = mission.description
		(card.get_node("Objective") as Label).text = (
			"目标：%s" % mission.objective_text
		)
		(card.get_node("RiskReward") as Label).text = (
			"风险：%s\n首胜奖励：%s"
			% [mission.risk_label, mission.get_reward_text()]
		)
		var state_id := get_noticeboard_mission_state(mission.mission_id)
		(card.get_node("StateLabel") as Label).text = (
			_get_noticeboard_state_text(state_id)
		)
		var start_button := card.get_node("StartButton") as Button
		start_button.text = (
			"再次挑战" if state_id == &"COMPLETED" else "开始任务"
		)
		start_button.tooltip_text = "旧独立任务：不改变赤崖、银渡控制权；正式黑石战役不再新开，旧活动事务仍按原身份恢复。"
		if uses_blackstone_campaign():
			start_button.text = "历史任务 · 已退出首关入口"
		start_button.disabled = not can_start_noticeboard_mission(
			mission.mission_id
		)
	if _noticeboard_last_result_summary.is_empty():
		noticeboard_last_result.text = "尚无任务结果"
	else:
		var last_mission := get_noticeboard_mission_definition(
			StringName(
				_noticeboard_last_result_summary.get("mission_id", &"")
			)
		)
		noticeboard_last_result.text = "最近结果：%s · %s" % [
			last_mission.title if last_mission != null else "未知任务",
			_get_noticeboard_outcome_text(
				StringName(
					_noticeboard_last_result_summary.get("outcome", &"")
				)
			),
		]


func _get_noticeboard_state_text(state_id: StringName) -> String:
	if state_id == &"IN_PROGRESS":
		return "进行中"
	if state_id == &"COMPLETED":
		return "已完成"
	return "可接受"


func _get_noticeboard_outcome_text(outcome: StringName) -> String:
	if outcome == &"VICTORY":
		return "胜利"
	if outcome == &"RETREAT":
		return "主动撤退"
	return "失败"


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
	var graybox_visual: GrayboxBuildingVisual = null
	if building.has_meta("graybox_visual"):
		graybox_visual = building.get_meta("graybox_visual") as GrayboxBuildingVisual
	var selection_node: CanvasItem = (
		graybox_visual if graybox_visual != null else building
	)
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
		"base_footprint": footprint_end - origin_cell,
		"occupied_footprint_cells": footprint_cells.duplicate(),
		"selection_bounds": Rect2(Vector2.ZERO, building.size),
		"lifecycle_state": &"fixed",
		"prototype_status": "固定 / 可选择",
		"selectable": true,
		"removable": false,
		"movable": false,
		"level": int(definition.level),
		"next_level_definition_id": &"",
		"build_wood_cost": 0,
		"build_food_cost": 0,
		"build_days": 0,
		"construction_started_day": 0,
		"construction_complete_day": 0,
		"effect_summary": str(definition.effect_summary),
		"prerequisite_summary": "初始固定设施",
		"built_day": 0,
		"node": selection_node,
	}, true)
	selection_node.set_meta("placement_id", placement_id)
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
		"orientation": ORIENTATION_NORTH,
		"occupied_footprint_cells": [],
		"selection_bounds": Rect2(),
		"lifecycle_state": &"",
		"prototype_status": "",
		"operational_state": &"",
		"selectable": false,
		"removable": false,
		"movable": false,
		"level": 1,
		"next_level_definition_id": &"",
		"build_wood_cost": 0,
		"build_food_cost": 0,
		"build_days": 0,
		"construction_started_day": 0,
		"construction_complete_day": 0,
		"construction_state": &"COMPLETED",
		"construction_progress_milliseconds": 0,
		"construction_required_milliseconds": 0,
		"construction_total_costs": {},
		"construction_paid_costs": {},
		"construction_priority": CONSTRUCTION_PRIORITY_NORMAL,
		"construction_missing_resource_ids": [],
		"effect_summary": "",
		"prerequisite_summary": "",
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
	var slot_state := get_build_slot_state()
	var show_slot := slot_state != BUILD_SLOT_IDLE and state != ConstructionState.PLACING
	build_slot_content.visible = show_slot
	build_entry_button.visible = state != ConstructionState.PLACING and not show_slot
	build_entry_button.text = (
		"旧存档施工完成后启用新建造队列"
		if _has_legacy_construction()
		else "城市经营"
	)
	build_entry_button.disabled = is_city_action_locked_for_battle()
	build_mode_status.visible = state == ConstructionState.PLACING
	placement_orientation_label.visible = state == ConstructionState.PLACING
	rotate_placement_button.visible = (
		state == ConstructionState.PLACING
		and (
			not is_road_placing()
			or has_road_connection_recommendation_preview()
		)
	)
	confirm_road_button.visible = state == ConstructionState.PLACING and is_road_placing()
	cancel_placement_button.visible = state == ConstructionState.PLACING
	build_slot_progress.visible = show_slot
	build_slot_detail.visible = show_slot
	build_slot_primary_button.visible = show_slot
	build_slot_cancel_button.visible = show_slot
	if show_slot:
		var presentation := get_build_slot_presentation()
		build_mode_status.visible = true
		build_mode_status.text = "%s｜%s\n%s" % [
			presentation.display_name,
			presentation.status_text,
			presentation.effect_text,
		]
		build_slot_progress.value = float(presentation.progress_percent)
		build_slot_progress.visible = slot_state not in [
			BUILD_SLOT_READY_TO_PLACE,
			BUILD_SLOT_PLACEMENT_ACTIVE,
		]
		var detail_lines: Array[String] = []
		if slot_state == BUILD_SLOT_WAITING_MATERIAL:
			detail_lines.append(
				("缺少：" if int(_build_slot.progress_milliseconds) == 0 else "恢复推进还缺：")
				+ (
					str(presentation.remaining_text)
					if int(_build_slot.progress_milliseconds) == 0
					else str(presentation.next_missing_text)
				)
			)
		if slot_state in [BUILD_SLOT_PRODUCING, BUILD_SLOT_WAITING_MATERIAL]:
			detail_lines.append("已投入：%s" % presentation.paid_text)
			detail_lines.append("剩余成本：%s" % presentation.remaining_text)
			detail_lines.append("预计完成：%s" % presentation.eta_text)
		else:
			detail_lines.append("材料已全部投入")
		build_slot_detail.text = "\n".join(detail_lines)
		build_slot_primary_button.text = (
			"放置%s" % presentation.display_name
			if slot_state == BUILD_SLOT_READY_TO_PLACE
			else "铺设道路"
		)
		build_slot_cancel_button.text = (
			"取消项目并返还：%s" % presentation.refund_text
			if not str(presentation.refund_text).is_empty()
			else "取消项目"
		)
	if state == ConstructionState.PLACING and _selected_definition != null:
		if is_road_placing():
			var road_cells: Array = _road_draft.get("unique_cells", [])
			var connection_text := (
				"已接入城市道路网络"
				if preview_connection_state == &"connected"
				else "琥珀：暂未接入主网"
			)
			if not preview_valid:
				connection_text = preview_invalid_reason
			if has_road_connection_recommendation_preview():
				var recommendation_id := int(
					_road_recommendation_preview.get("placement_id", -1)
				)
				var recommendation_target: Dictionary = _building_records_by_id.get(
					recommendation_id, {}
				)
				var recommendation_cost := int(
					evaluate_road_path(road_cells).get("cost", 0)
				)
				build_mode_status.text = "接通方案 · %s\n路径 %d 格 · 木材 %d · %s" % [
					str(recommendation_target.get("display_name", "目标建筑")),
					road_cells.size(),
					recommendation_cost,
					connection_text,
				]
				placement_orientation_label.text = "完成方式：立即铺设 · 状态变化后需重新查看"
				rotate_placement_button.text = "手动规划"
				cancel_placement_button.text = "取消方案 · Esc"
			else:
				build_mode_status.text = "道路工具 · 拖拽直线\n长度 %d · %s" % [
					road_cells.size(),
					connection_text,
				]
				placement_orientation_label.text = (
					"道路只接受水平 / 垂直路径 · 每格木%d"
					% ROAD_DEFINITION.wood_cost
				)
				cancel_placement_button.text = "取消道路 · Esc"
			confirm_road_button.text = "确认铺设"
			confirm_road_button.disabled = (
				not preview_valid or not _road_preview_fixed
			)
			cancel_placement_button.text = "取消道路 · Esc"
		else:
			var status_text := "可放置"
			if not preview_valid:
				status_text = _ready_placement_failure_message(_last_preview_validation)
			elif preview_connection_state == &"disconnected":
				status_text = "入口未接道路，放置后不生产"
			build_mode_status.text = "放置%s\n已建造完成｜放置不再扣料\n状态：%s" % [
				_selected_definition.display_name,
				status_text,
			]
			placement_orientation_label.text = "朝向：%s · 占地 %d × %d" % [
				ORIENTATION_NAMES[preview_orientation],
				get_rotated_footprint(_selected_definition, preview_orientation).x,
				get_rotated_footprint(_selected_definition, preview_orientation).y,
			]
			cancel_placement_button.text = "右键 / Esc 取消"
		cancel_placement_button.disabled = false
		rotate_placement_button.disabled = (
			is_road_placing()
			and not has_road_connection_recommendation_preview()
		)
	construction_menu.visible = (
		not _detail_panel_active
		and state == ConstructionState.CHOOSING_TEMPLATE
	)


func _refresh_construction_catalog_ui() -> void:
	var catalog_entries := [
		[road_button, ROAD_DEFINITION],
		[logging_camp_button, LOGGING_CAMP_DEFINITION],
		[farm_button, FARM_DEFINITION],
		[warehouse_button, WAREHOUSE_DEFINITION],
		[watchtower_button, WATCHTOWER_DEFINITION],
	]
	for entry in catalog_entries:
		var button := entry[0] as Button
		var definition := entry[1] as BuildingDefinition
		button.visible = definition.build_catalog_visible
		if not definition.build_catalog_visible:
			button.disabled = true
			continue
		var data := get_definition_build_data(definition.definition_id)
		var duration_compact := (
			"即时"
			if definition.build_days <= 0
			else "%d日" % definition.build_days
		)
		var second_line := str(data.effect_text)
		if not bool(data.can_build):
			second_line = "不可建：%s" % str(data.unavailable_reason)
		elif definition.requires_road:
			second_line += " · 需道路"
		button.text = (
			"道路工具 · 每格木%d\n拖拽直线 · %s"
			% [definition.wood_cost, second_line]
			if definition.placement_kind == PLACEMENT_KIND_ROAD
			else "%s L%d · %s · %s\n%s" % [
				definition.display_name,
				definition.level,
				str(data.compact_cost_text),
				duration_compact,
				second_line,
			]
		)
		var slot_blocks_building := (
			definition.placement_kind != PLACEMENT_KIND_ROAD
			and (has_build_project() or _has_legacy_construction())
		)
		button.disabled = not bool(data.can_build) or slot_blocks_building
		if slot_blocks_building:
			button.tooltip_text = (
				"已有建造项目：请先完成放置或等待旧存档施工完成"
			)
			continue
		button.tooltip_text = (
			"投入：%s｜工期：%s\n效果：%s\n前置：%s%s"
			% [
				str(data.cost_text),
				str(data.duration_text),
				str(data.effect_text),
				str(data.prerequisite_text),
				(
					"\n当前不可建：%s" % str(data.unavailable_reason)
					if not bool(data.can_build)
					else ""
				),
			]
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
	var mainline := get_mainline_pressure_state()
	alert_summary.text = (
		"主线已完成 · 压力解除"
		if bool(mainline.cleared)
		else (
			"主线逾期 %d 日\n压力：%s　治安：%d" % [
				int(mainline.overdue_days),
				str(mainline.stage_name),
				int(mainline.security),
			]
			if int(mainline.overdue_days) > 0
			else "主线期限：第 %d 日 · 剩余 %d 日\n压力：%s　治安：%d" % [
				int(mainline.deadline_day),
				int(mainline.days_remaining),
				str(mainline.stage_name),
				int(mainline.security),
			]
		)
	)
	if uses_blackstone_campaign():
		alert_summary.text = get_blackstone_campaign_status_text()
	_refresh_first_war_ui()
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
	var training_block := get_training_blocked_reason()
	var blocked_text := (
		"\n征募阻断：%s" % String(training_block.message)
		if bool(training_block.blocked)
			and training_queued_count == 0
		else ""
	)
	army_status.text = "驻军 %d · 可派 %d · 指挥上限 %d\n科技 %d%s%s%s" % [
		infantry_count,
		get_dispatchable_infantry_count(),
		command_limit,
		tech_points,
		queued_text,
		" · 供给不足" if supply_shortage else "",
		blocked_text,
	]
	recruit_button.text = "征募 %d 人 · %d 粮" % [
		get_training_batch_size(),
		get_training_batch_size() * INFANTRY_ROLE.recruit_food_per_unit,
	]
	recruit_button.disabled = not can_queue_training()
	general_option.disabled = is_city_action_locked_for_battle()
	for index in range(general_option.item_count):
		if (
			StringName(general_option.get_item_metadata(index))
			== selected_general_id
		):
			general_option.select(index)
			break
	if tech_option.item_count > 0:
		tech_option.disabled = is_city_action_locked_for_battle()
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
		is_city_action_locked_for_battle()
		or
		emergency_mobilization_used
		or current_day != FIRST_MAP_THREAT_SCHEDULE.max_day
		or food < EMERGENCY_MOBILIZATION_FOOD_COST
		or _population_recovery.available < EMERGENCY_MOBILIZATION_INFANTRY
	)
	emergency_mobilization_button.tooltip_text = "仅第 %d 日可用一次；需要 %d 粮、%d 名可用人员。其他日期可用正常征募。" % [FIRST_MAP_THREAT_SCHEDULE.max_day, EMERGENCY_MOBILIZATION_FOOD_COST, EMERGENCY_MOBILIZATION_INFANTRY]
	restore_checkpoint_button.visible = (
		current_day >= FIRST_MAP_THREAT_SCHEDULE.max_day
		and not uses_blackstone_campaign()
		and has_readiness_checkpoint()
	)
	restart_map_button.visible = (
		current_day >= FIRST_MAP_THREAT_SCHEDULE.max_day
	)
	_refresh_noticeboard_ui()
	_refresh_construction_catalog_ui()
	_sync_construction_ui()


func _refresh_first_war_ui() -> void:
	var committed_count := get_first_war_committed_count()
	var food_cost := get_first_war_food_cost(committed_count)
	var assessment := get_first_war_preparation_assessment()
	var state_text := str(get_first_war_state_id())
	var countdown_text := ""
	if first_war_state == FirstWarState.WARNING:
		var remaining := ceili(
			maxf(SECONDS_PER_DAY - day_elapsed_seconds, 0.0)
		)
		countdown_text = "\n距离敌袭：%02d:%02d" % [
			remaining / 60,
			remaining % 60,
		]
	var invasion := get_blackstone_invasion_read_model()
	var invasion_text := ""
	if bool(invasion.get("known", false)):
		var invasion_phase := StringName(invasion.get("phase", &""))
		var phase_text: String = str({
			FieldTacticsState.INVASION_DORMANT: "集结中",
			FieldTacticsState.INVASION_MARCHING: "行军中",
			FieldTacticsState.INVASION_ARRIVED: "已抵达城门",
			FieldTacticsState.INVASION_HANDED_OFF: "守城实例交战中",
			FieldTacticsState.INVASION_DEFEATED: "已在战区被消灭",
			FieldTacticsState.INVASION_CANCELLED: "赤崖已被控制，本次先遣军出兵取消",
			FieldTacticsState.INVASION_RESOLVED: "守城战果已结算",
		}.get(invasion_phase, "状态待确认"))
		var strength_text := (
			"精确兵力 %d" % int(invasion.get("known_strength", 0))
			if bool(invasion.get("exact_strength_known", false))
			else "兵力未侦明"
		)
		invasion_text = "来袭预警 · %s（%s）\n%s → %s｜%s｜%s\n" % [
			str(invasion.get("display_name", "来袭敌军")), phase_text,
			str(invasion.get("source_name", "未知来源")), str(invasion.get("target_name", "黑石城")),
			str(invasion.get("known_route_name", "既知道路")), strength_text,
		]
	var legacy_first_war_text := (
		"北坡敌情 · %s%s\n敌军 %d｜工事 %d\n"
		+ "守军 %d｜%s\n粮食 %d／出战需 %d｜%s\n"
		+ "城防 %d／减损线 %d｜%s\n%s"
	) % [
		state_text,
		countdown_text,
		enemy_count,
		enemy_fortification,
		committed_count,
		str(assessment.troop_status),
		food,
		food_cost,
		str(assessment.supply_status),
		get_city_defense(),
		int(assessment.defense_target),
		str(assessment.defense_status),
		str(assessment.suggestion),
	]
	first_war_intel.text = (
		invasion_text + "黑石守军 %d｜城防 %d\n城门接战前可从战区侦察、截击或建设防线。" % [committed_count, get_city_defense()]
		if not invasion.is_empty()
		else legacy_first_war_text
	)
	var awaiting_summary := (
		_first_war_pending_outcome != &""
		and not _first_war_result_acknowledged
		and first_war_state in [
			FirstWarState.IN_BATTLE,
			FirstWarState.RESOLVED_DEFEAT,
		]
	)
	first_war_intel.visible = not awaiting_summary
	enter_first_war_button.visible = (
		first_war_state == FirstWarState.PENDING
		and invasion.is_empty()
		and not retreat_confirmation.visible
		and not awaiting_summary
	)
	# The legacy city-side instant retreat created a transient default force and
	# bypassed selection, prepaid food, stable formation IDs, and V6 durability.
	# Retreat remains available inside the formal battle after an expedition is
	# confirmed; this obsolete shortcut must not remain player-reachable.
	order_retreat_button.visible = false
	enter_first_war_button.disabled = not can_enter_first_war()
	var invasion_phase := StringName(invasion.get("phase", &""))
	enter_wartime_defense_button.text = (
		"进入黑石城门防守 · 沿用来袭敌军"
		if invasion_phase == FieldTacticsState.INVASION_ARRIVED
		else (
			"黑石守城交战中"
			if invasion_phase == FieldTacticsState.INVASION_HANDED_OFF
			else (
				"本次来袭已结算 · 可继续反攻"
				if invasion_phase in [FieldTacticsState.INVASION_DEFEATED, FieldTacticsState.INVASION_CANCELLED, FieldTacticsState.INVASION_RESOLVED]
				else "敌军尚未抵达 · 返回战区处置"
			)
		)
	)
	enter_wartime_defense_button.disabled = (
		not _expedition_attempt.is_empty()
		or (not invasion.is_empty() and invasion_phase != FieldTacticsState.INVASION_ARRIVED)
	)
	enter_wartime_defense_button.tooltip_text = (
		"同一支敌军抵达后才能接战；外部截击造成的实际损失会带入守城"
		if invasion_phase != FieldTacticsState.INVASION_ARRIVED
		else "以当前实际守军迎击；敌军兵力来自战区中的同一来袭记录"
	)
	order_retreat_button.disabled = true
	if first_war_state != FirstWarState.PENDING:
		retreat_confirmation.visible = false
	first_war_result.visible = awaiting_summary
	if awaiting_summary:
		var summary := _last_battle_result_summary
		first_war_result_label.text = (
			"%s\n出战 %d｜幸存 %d｜损失 %d\n"
			+ "粮草 -%d｜城防 -%d｜剩余敌军 %d"
		) % [
			_first_war_outcome_display_name(_first_war_pending_outcome),
			int(summary.get("committed_count", 0)),
			int(summary.get("survivor_count", 0)),
			int(summary.get("casualty_count", 0)),
			int(summary.get("actual_food_cost", 0)),
			int(summary.get("city_defense_damage", 0)),
			int(summary.get("enemy_count_after", enemy_count)),
		]
		acknowledge_war_result_button.text = (
			"确认城市失守"
			if _first_war_pending_outcome == &"DEFEAT"
			else "确认战后摘要"
		)
	_refresh_current_mainline_entry_ui()


func _refresh_current_mainline_entry_ui() -> void:
	if uses_blackstone_campaign():
		current_mainline_entry_button.text = "继续原战斗" if has_resumable_expedition() else "查看战区 · 赤崖 / 银渡"
		current_mainline_entry_button.tooltip_text = get_blackstone_campaign_status_text() + "\n点击定位已知来袭来源；侦察、工程和直接出兵均可选。"
		current_mainline_entry_button.disabled = is_instance_valid(_formal_battle_scene)
		return
	if _current_mainline_level.cleared:
		current_mainline_entry_button.text = "主线已完成 · 压力解除"
		current_mainline_entry_button.tooltip_text = "当前主线已结算，后续压力已停止"
		current_mainline_entry_button.disabled = true
		return
	if can_enter_first_war():
		current_mainline_entry_button.text = (
			"再次进入当前主线"
			if first_war_state == FirstWarState.RESOLVED_RETREAT
			else "进入当前主线"
		)
		current_mainline_entry_button.tooltip_text = "进入北坡战场；确认战果后才写回城市"
		current_mainline_entry_button.disabled = false
		return
	if _first_war_pending_outcome != &"":
		current_mainline_entry_button.text = "主线战果待确认"
		current_mainline_entry_button.tooltip_text = "战果已写回，返回城市后确认摘要"
		current_mainline_entry_button.disabled = true
		return
	if first_war_state == FirstWarState.IN_BATTLE:
		current_mainline_entry_button.text = "当前主线交战中"
		current_mainline_entry_button.tooltip_text = "当前战斗尚未完成"
		current_mainline_entry_button.disabled = true
		return
	var blocked_reason := get_first_war_entry_blocked_reason()
	current_mainline_entry_button.text = "无法出征：没有可派编队"
	current_mainline_entry_button.tooltip_text = blocked_reason
	# Keep the failed action reachable so an actual click produces the same
	# explicit reason as the visible state rather than failing silently.
	current_mainline_entry_button.disabled = false


func _first_war_outcome_display_name(outcome: StringName) -> String:
	if outcome == &"VICTORY":
		return "北坡防御战 · 胜利"
	if outcome == &"RETREAT":
		return "北坡防御战 · 主动撤退"
	return "北坡防御战 · 失败 / 城市失守"


func _refresh_time_ui() -> void:
	var elapsed_seconds := floori(day_elapsed_seconds)
	var time_text := "第 %d 日 · %02d:%02d" % [
		current_day,
		elapsed_seconds / 60,
		elapsed_seconds % 60,
	]
	if time_summary.text != time_text:
		time_summary.text = time_text
	var pause_text := (
		"敌袭冻结"
		if is_first_war_time_blocked()
		else ("继续" if city_time_paused else "暂停")
	)
	if pause_button.text != pause_text:
		pause_button.text = pause_text
	time_summary.tooltip_text = "常态内城与外部战区共享暂停和倍速；切换战区不暂停生产、施工、治疗。战时内城与战区冻结；守城确认补计城市战斗时长，反攻围城不补计城市日历。"
	pause_button.disabled = is_first_war_time_blocked()
	time_speed_option.disabled = is_first_war_time_blocked()
	for index in range(time_speed_option.item_count):
		if is_equal_approx(
			float(time_speed_option.get_item_metadata(index)),
			city_time_speed
		):
			time_speed_option.select(index)
			break


func _get_first_war_objective_text() -> String:
	if uses_blackstone_campaign():
		return get_blackstone_campaign_status_text()
	if (
		_first_war_pending_outcome != &""
		and not _first_war_result_acknowledged
	):
		return "战后摘要待确认 · %s" % (
			(
				"胜利"
				if _first_war_pending_outcome == &"VICTORY"
				else (
					"主动撤退"
					if _first_war_pending_outcome == &"RETREAT"
					else "城市失守"
				)
			)
		)
	match first_war_state:
		FirstWarState.PREPARATION:
			return "目标 北坡备战 · 距敌袭 %d 日" % maxi(
				FIRST_WAR_PENDING_DAY - current_day,
				0
			)
		FirstWarState.WARNING:
			return "预警 北坡敌袭 · 第 7 日到达"
		FirstWarState.PENDING:
			return "敌袭待处理 · 前往军令台"
		FirstWarState.IN_BATTLE:
			return "北坡防御战进行中"
		FirstWarState.RESOLVED_VICTORY:
			return "北坡首战 · 胜利"
		FirstWarState.RESOLVED_RETREAT:
			return "北坡首战 · 已撤退"
		FirstWarState.RESOLVED_DEFEAT:
			return "城市失守"
	return "北坡备战"


func _enforce_resource_capacity() -> void:
	_commit_national_resource_targets(
		{
			&"wood": mini(wood, get_resource_capacity(&"wood")),
			&"food": mini(food, get_resource_capacity(&"food")),
		},
		&"resource_capacity_enforcement"
	)


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
