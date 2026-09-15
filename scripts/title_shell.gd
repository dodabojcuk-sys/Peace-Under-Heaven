class_name TitleShell
extends Control


const CITY_SCENE := preload("res://scenes/blank_map.tscn")
const SAVE_STORE := preload("res://scripts/state/v5_campaign_save_store.gd")
const RUNTIME_IDENTITY := preload("res://scripts/runtime_identity.gd")

@onready var enter_city_button: Button = %EnterCityButton
@onready var new_game_button: Button = %NewGameButton
@onready var exit_button: Button = %ExitButton
@onready var status_label: Label = %Status
@onready var version_label: Label = %Version
@onready var development_details_button: Button = %DevelopmentDetailsButton
@onready var development_details_dialog: AcceptDialog = %DevelopmentDetailsDialog
@onready var new_game_confirmation: ConfirmationDialog = %NewGameConfirmation

var _city_transition_requested := false
var _regular_campaign_button: Button
var _regular_campaign_hint: Label
var _regular_campaign_confirmation: ConfirmationDialog


func _ready() -> void:
	enter_city_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	# R1B.2：入口表达——不让玩家猜两条新局路线的区别。
	new_game_button.tooltip_text = "开始经典黑石城战役新开局。"
	new_game_confirmation.confirmed.connect(_on_new_game_confirmed)
	_install_regular_campaign_entry()
	exit_button.pressed.connect(_on_exit_pressed)
	development_details_button.pressed.connect(_toggle_development_details)
	_refresh_candidate_identity()
	var can_continue := _has_continuable_campaign()
	enter_city_button.disabled = not can_continue
	status_label.text = (
		"检测到黑石战役存档，可继续原有军队、战斗与恢复任务。"
		if can_continue
		else "尚无可继续的黑石战役存档，请开始新局。"
	)
	call_deferred("_focus_primary_action")


func _unhandled_key_input(event: InputEvent) -> void:
	# The title has no modal stack to dismiss. Consume Esc deliberately instead
	# of leaking it into an uninitialized city interaction path.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	if enter_city_button.disabled:
		return
	_start_campaign(RUNTIME_IDENTITY.CAMPAIGN_START_CONTINUE)


func _on_new_game_pressed() -> void:
	if _city_transition_requested:
		return
	new_game_confirmation.popup_centered()


func _on_new_game_confirmed() -> void:
	_start_campaign(RUNTIME_IDENTITY.CAMPAIGN_START_NEW)


func _install_regular_campaign_entry() -> void:
	# The existing scene remains usable by legacy starts.  This separate control
	# makes the authored regular candidate an explicit new-game choice instead of
	# reinterpreting Continue or the Blackstone new-game path.
	_regular_campaign_button = Button.new()
	_regular_campaign_button.name = "RegularCampaignNewGameButton"
	_regular_campaign_button.text = "常规关卡候选 · 新局"
	_regular_campaign_button.tooltip_text = "从真实主城资产开始常规战役候选；不会加载或改写已有进度。"
	_regular_campaign_button.custom_minimum_size = Vector2(0, 46)
	_regular_campaign_button.focus_mode = Control.FOCUS_ALL
	_regular_campaign_button.add_theme_font_size_override("font_size", 17)
	_regular_campaign_button.add_theme_color_override(
		"font_color",
		new_game_button.get_theme_color("font_color")
	)
	for state in [&"normal", &"hover", &"pressed"]:
		_regular_campaign_button.add_theme_stylebox_override(
			state,
			new_game_button.get_theme_stylebox(state)
		)
	new_game_button.get_parent().add_child(_regular_campaign_button)
	new_game_button.get_parent().move_child(
		_regular_campaign_button,
		new_game_button.get_index() + 1
	)
	_regular_campaign_button.pressed.connect(_on_regular_campaign_pressed)

	# R1B.2：入口说明常显——「开始新局 / 常规关卡候选」的区别不再靠玩家猜。
	_regular_campaign_hint = Label.new()
	_regular_campaign_hint.name = "RegularCampaignEntryHint"
	_regular_campaign_hint.text = (
		"常规战役：创建独立候选进度，直接进入青原前线城体验战时建设；\n不影响已有存档。想从黑石城经营开始，请用「开始新局」。"
	)
	_regular_campaign_hint.add_theme_font_size_override("font_size", 12)
	_regular_campaign_hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.78))
	_regular_campaign_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_regular_campaign_hint.custom_minimum_size = Vector2(332, 0)
	new_game_button.get_parent().add_child(_regular_campaign_hint)
	new_game_button.get_parent().move_child(
		_regular_campaign_hint,
		_regular_campaign_button.get_index() + 1
	)

	_regular_campaign_confirmation = ConfirmationDialog.new()
	_regular_campaign_confirmation.name = "RegularCampaignNewGameConfirmation"
	_regular_campaign_confirmation.title = "开始常规关卡候选新局"
	_regular_campaign_confirmation.dialog_text = (
		"这会创建一个新的候选存档代次，并从真实主城资产进入常规战役备战。"
		+ "不会加载、覆盖或操作已有战役进度。"
	)
	_regular_campaign_confirmation.ok_button_text = "开始常规候选"
	_regular_campaign_confirmation.cancel_button_text = "返回"
	add_child(_regular_campaign_confirmation)
	_regular_campaign_confirmation.confirmed.connect(_on_regular_campaign_confirmed)


func _on_regular_campaign_pressed() -> void:
	if _city_transition_requested:
		return
	_regular_campaign_confirmation.popup_centered()


func _on_regular_campaign_confirmed() -> void:
	_start_campaign(RUNTIME_IDENTITY.CAMPAIGN_START_REGULAR)


func _start_campaign(mode: StringName) -> void:
	if _city_transition_requested:
		return
	if not get_node("/root/RuntimeIdentity").request_campaign_start(mode):
		return
	_city_transition_requested = true
	enter_city_button.disabled = true
	new_game_button.disabled = true
	if _regular_campaign_button != null:
		_regular_campaign_button.disabled = true
	get_tree().change_scene_to_packed(CITY_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _focus_primary_action() -> void:
	if _city_transition_requested:
		return
	if not enter_city_button.disabled:
		enter_city_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _has_continuable_campaign() -> bool:
	var override: String = get_node("/root/RuntimeIdentity").get_campaign_save_directory_override()
	if DisplayServer.get_name() == "headless" and override.is_empty():
		return false
	var store := SAVE_STORE.new(
		override if not override.is_empty() else V5CampaignSaveStore.DEFAULT_DIRECTORY
	)
	return store.has_any_generation()


func _refresh_candidate_identity() -> void:
	var identity := RUNTIME_IDENTITY.parse_identity(OS.get_cmdline_user_args(), RUNTIME_IDENTITY.SCENE_TITLE)
	var candidate := str(identity.get("candidate", ""))
	var is_r1a := candidate == RUNTIME_IDENTITY.CANDIDATE_VERSION_REGULAR_R1A
	var candidate_name := "常规关卡候选 R1A" if is_r1a else ("常规关卡候选 R1" if candidate == RUNTIME_IDENTITY.CANDIDATE_VERSION_REGULAR_R1 else "正式试玩候选 R1")
	if is_r1a and _regular_campaign_button != null:
		_regular_campaign_button.text = "常规关卡 R1A · 新局"
		_regular_campaign_button.tooltip_text = "从真实主城资产进入可操作的战时内城空间小样；不会加载或改写已有进度。"
	if is_r1a and _regular_campaign_confirmation != null:
		_regular_campaign_confirmation.title = "开始常规关卡 R1A 新局"
		_regular_campaign_confirmation.ok_button_text = "开始 R1A 候选"
	version_label.text = (
		"%s · %s%s" % [
			candidate_name,
			str(identity.get("commit", "")).substr(0, 12),
			" · DIRTY" if bool(identity.get("dirty", false)) else "",
		]
		if bool(identity.get("identified", false))
		else "正式试玩候选 R1 · UNKNOWN"
	)
	development_details_dialog.dialog_text = (
		"Branch: %s\nCommit: %s\nProject: %s\nSave: %s\nLaunch: %s" % [
			str(identity.get("branch", "")),
			str(identity.get("commit", "")),
			str(identity.get("project_path", "")),
			str(identity.get("save_directory", "")),
			str(identity.get("launch_id", "")),
		]
		if bool(identity.get("identified", false))
		else "Branch: UNKNOWN\nCommit: UNKNOWN\nProject: UNKNOWN\nSave: UNKNOWN\nLaunch: UNKNOWN"
	)


func _toggle_development_details() -> void:
	development_details_dialog.popup_centered(Vector2i(760, 360))
