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


func _ready() -> void:
	enter_city_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	new_game_confirmation.confirmed.connect(_on_new_game_confirmed)
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


func _start_campaign(mode: StringName) -> void:
	if _city_transition_requested:
		return
	if not get_node("/root/RuntimeIdentity").request_campaign_start(mode):
		return
	_city_transition_requested = true
	enter_city_button.disabled = true
	new_game_button.disabled = true
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
	version_label.text = (
		"正式试玩候选 R1 · %s%s" % [
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
