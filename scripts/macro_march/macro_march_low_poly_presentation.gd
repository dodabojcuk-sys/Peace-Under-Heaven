class_name MacroMarchLowPolyPresentation
extends Control


## A render-only orthographic miniature for Macro March.  It deliberately owns
## no game state: [MacroMarchR0] keeps the established 2D projection for all
## hit testing and asks this layer to display exactly the same world positions.

const OBLIQUE_X_SKEW := 0.20
const OBLIQUE_Y_SCALE := 0.72
const CAMERA_YAW := -atan(OBLIQUE_X_SKEW)
const CAMERA_PITCH := deg_to_rad(47.0)
const CAMERA_DISTANCE := 1200.0
const NATURE_ASSET_PATHS := {
	&"TREE_BROADLEAF": "res://assets/blackstone_art/kenney_nature/tree_default.glb",
	&"TREE_PINE": "res://assets/blackstone_art/kenney_nature/tree_pineRoundA.glb",
	&"TREE_DARK": "res://assets/blackstone_art/kenney_nature/tree_cone_dark.glb",
	&"ROCK_WIDE": "res://assets/blackstone_art/kenney_nature/rock_largeA.glb",
	&"ROCK_LOW": "res://assets/blackstone_art/kenney_nature/rock_largeC.glb",
	&"ROCK_TALL": "res://assets/blackstone_art/kenney_nature/rock_tallB.glb",
	&"GRASS": "res://assets/blackstone_art/kenney_nature/grass_leafsLarge.glb",
}

var _viewport := SubViewport.new()
var _texture := TextureRect.new()
var _world := Node3D.new()
var _camera := Camera3D.new()
var _static_root := Node3D.new()
var _road_root := Node3D.new()
var _point_root := Node3D.new()
var _army_root := Node3D.new()
var _specialist_root := Node3D.new()
var _patrol_root := Node3D.new()
var _project_root := Node3D.new()
var _theater: Object
var _static_definition_id: StringName = &""
var _road_signature := ""
var _point_signature := ""
var _army_nodes: Dictionary = {}
var _army_visual_signatures: Dictionary = {}
var _specialist_nodes: Dictionary = {}
var _specialist_visual_signatures: Dictionary = {}
var _patrol_nodes: Dictionary = {}
var _patrol_visual_signatures: Dictionary = {}
var _nature_scenes: Dictionary = {}
var _nature_material_variants: Dictionary = {}
var _selected_army_id: StringName = &""
var _selected_specialist_id: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture.texture = _viewport.get_texture()
	add_child(_texture)
	_viewport.add_child(_world)
	_world.add_child(_static_root)
	_world.add_child(_road_root)
	_world.add_child(_point_root)
	_world.add_child(_army_root)
	_world.add_child(_specialist_root)
	_world.add_child(_patrol_root)
	_world.add_child(_project_root)
	_build_world_lighting()


func is_available() -> bool:
	return DisplayServer.get_name() != "headless"


func sync(
	theater: Object,
	model: Dictionary,
	field: Dictionary,
	camera_center: Vector2,
	camera_zoom: float,
	selected_army_id: StringName = &"",
	selected_specialist_id: StringName = &""
) -> void:
	if not is_available() or theater == null or size.x < 2.0 or size.y < 2.0:
		visible = false
		return
	visible = true
	_theater = theater
	_selected_army_id = selected_army_id
	_selected_specialist_id = selected_specialist_id
	_resize_viewport()
	_update_camera(camera_center, camera_zoom)
	var definition_id := StringName(_theater.get_definition_id())
	if definition_id != _static_definition_id:
		_static_definition_id = definition_id
		_rebuild_static_theater()
	var roads: Dictionary = Dictionary(field.get("roads_by_id", {}))
	var roads_signature := _road_state_signature(roads)
	if roads_signature != _road_signature:
		_road_signature = roads_signature
		_rebuild_roads(roads)
	var points_signature := _point_state_signature(model, field)
	if points_signature != _point_signature:
		_point_signature = points_signature
		_rebuild_points(model, field)
	# Positions and progress change every world tick, while point ownership rarely
	# changes. Keep the visual actors synchronized independently of point rebuilds.
	_sync_armies(Array(model.get("armies", [])))
	_sync_specialists(Dictionary(field.get("specialists_by_id", {})))
	_sync_patrols(Dictionary(field.get("visible_patrols_by_id", {})))
	_sync_projects(Dictionary(field.get("projects_by_id", {})), Dictionary(field.get("specialists_by_id", {})))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_viewport()


func _resize_viewport() -> void:
	var target_size := Vector2i(maxi(roundi(size.x), 2), maxi(roundi(size.y), 2))
	if _viewport.size != target_size:
		_viewport.size = target_size
	_texture.position = Vector2.ZERO
	_texture.size = size


func _build_world_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6b835f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8e3c1")
	# A brighter ambient contribution keeps command targets readable without the
	# former long, high-contrast shadows dominating the miniature battlefield.
	environment.ambient_light_energy = 0.86
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-68.0, -28.0, 0.0)
	sun.light_color = Color("ffe7b2")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	_world.add_child(sun)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_camera.near = 0.1
	_camera.far = 4000.0
	_world.add_child(_camera)


func _update_camera(center: Vector2, zoom: float) -> void:
	if size.y <= 1.0:
		return
	var target := _ground_position(center)
	var forward := _camera_forward()
	_camera.position = target - forward * CAMERA_DISTANCE
	_camera.look_at(target, Vector3.UP)
	_camera.size = size.y / maxf(zoom, 0.01)


func project_world_to_viewport(world_position: Vector2, elevation := 0.0) -> Vector2:
	# Camera3D is the independent reference for renderer/overlay alignment.
	# The returned coordinates are local to this SubViewport, not the host Control.
	return _camera.unproject_position(_ground_position(world_position, elevation))


func _ground_position(world_position: Vector2, elevation := 0.0) -> Vector3:
	# Preserve the authoritative oblique screen transform on a horizontal XZ
	# ground plane.  The previous implementation used Camera3D's tilted screen-up
	# vector for world y, which made north/south map movement alter model height.
	# Here only the explicit elevation controls Y; the two horizontal basis vectors
	# are scaled so Camera3D still projects x + skew*y and y*scale identically to
	# MacroMarchR0's map transform.
	var forward := _camera_forward()
	var right := forward.cross(Vector3.UP).normalized()
	var camera_up := right.cross(forward).normalized()
	var horizontal := world_position.x + world_position.y * OBLIQUE_X_SKEW
	var vertical := world_position.y * OBLIQUE_Y_SCALE
	var screen_down_on_ground := Vector3(-camera_up.x, 0.0, -camera_up.z)
	var screen_down_length := screen_down_on_ground.length()
	if screen_down_length <= 0.0001:
		return right * horizontal + Vector3.UP * elevation
	return right * horizontal + screen_down_on_ground * (vertical / (screen_down_length * screen_down_length)) + Vector3.UP * elevation


func _camera_forward() -> Vector3:
	var horizontal := Vector3(sin(CAMERA_YAW) * cos(CAMERA_PITCH), 0.0, cos(CAMERA_YAW) * cos(CAMERA_PITCH))
	return Vector3(horizontal.x, -sin(CAMERA_PITCH), horizontal.z).normalized()


func _rebuild_static_theater() -> void:
	_clear_children(_static_root)
	if _theater == null:
		return
	var palette: Dictionary = _theater.get_presentation_profile()
	var bounds: Rect2 = _theater.get_world_bounds()
	# The authored theatre is an oblique projected parallelogram.  A horizontal
	# overscan ground keeps the clipped command viewport filled at overview zoom
	# without changing any authoritative terrain or passability bounds.
	_add_ground_quad(_static_root, bounds.grow(720.0), Color(palette.get("ground_color", Color("6f875f"))), 0.0, "Ground")
	for terrain_value in _theater.get_terrain_regions():
		var terrain: Dictionary = Dictionary(terrain_value)
		var terrain_rect := Rect2(terrain.get("rect", Rect2i()))
		match StringName(terrain.get("kind", &"")):
			&"WATER":
				_add_ground_quad(_static_root, terrain_rect, Color(palette.get("water_color", Color("438bb2"))), 0.18, "River")
				_add_water_reeds(terrain_rect)
				_add_riverbank_detail(terrain_rect)
			&"FOREST":
				_add_forest_patch(terrain_rect)
			&"ROCKS":
				_add_rock_patch(terrain_rect)


func _add_ground_quad(parent: Node3D, rect: Rect2, color: Color, elevation: float, node_name: String) -> void:
	var corners := [
		_ground_position(rect.position, elevation),
		_ground_position(Vector2(rect.end.x, rect.position.y), elevation),
		_ground_position(rect.end, elevation),
		_ground_position(Vector2(rect.position.x, rect.end.y), elevation),
	]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([corners[0], corners[1], corners[2], corners[3]])
	var surface_normal: Vector3 = (Vector3(corners[1]) - Vector3(corners[0])).cross(Vector3(corners[3]) - Vector3(corners[0])).normalized()
	if surface_normal.dot(Vector3.UP) < 0.0:
		surface_normal = -surface_normal
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([surface_normal, surface_normal, surface_normal, surface_normal])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _material(color, 0.96)
	instance.set_meta("ground_surface_normal", surface_normal)
	instance.set_meta("ground_corner_heights", [corners[0].y, corners[1].y, corners[2].y, corners[3].y])
	parent.add_child(instance)


func _add_forest_patch(rect: Rect2) -> void:
	# Forest floor is a restrained visual cue for the already-authoritative forest
	# region. It deliberately does not change fog, ambush eligibility, or movement.
	_add_ground_quad(_static_root, rect.grow(-5.0), Color("617850"), 0.055, "ForestFloor")
	var patch := Node3D.new()
	patch.name = "Forest"
	_static_root.add_child(patch)
	for offset in [
		Vector2(20, 24), Vector2(55, 48), Vector2(88, 23), Vector2(123, 63),
		Vector2(154, 32), Vector2(38, 98), Vector2(77, 118), Vector2(115, 91),
		Vector2(166, 130), Vector2(205, 68), Vector2(215, 150), Vector2(29, 154),
		Vector2(145, 158), Vector2(196, 116), Vector2(102, 151),
	]:
		if offset.x > rect.size.x - 8.0 or offset.y > rect.size.y - 8.0:
			continue
		var kinds := [&"TREE_BROADLEAF", &"TREE_PINE", &"TREE_DARK"]
		_add_tree(patch, rect.position + offset, 0.74 + fmod(offset.x, 3.0) * 0.1, kinds[int(offset.x) % kinds.size()])


func _add_rock_patch(rect: Rect2) -> void:
	_add_ground_quad(_static_root, rect.grow(-7.0), Color("70805c"), 0.05, "RockFloor")
	var rocks := Node3D.new()
	rocks.name = "Rocks"
	_static_root.add_child(rocks)
	var offsets := [Vector2(28, 34), Vector2(76, 58), Vector2(116, 28), Vector2(148, 74), Vector2(52, 95)]
	var kinds := [&"ROCK_WIDE", &"ROCK_LOW", &"ROCK_TALL"]
	for index in range(offsets.size()):
		var offset: Vector2 = offsets[index]
		if offset.x > rect.size.x - 8.0 or offset.y > rect.size.y - 8.0:
			continue
		_add_rock(rocks, rect.position + offset, 7.0 + fmod(offset.x, 6.0), kinds[index % kinds.size()])


func _add_water_reeds(rect: Rect2) -> void:
	var reeds := Node3D.new()
	reeds.name = "Reeds"
	_static_root.add_child(reeds)
	for ratio in [0.12, 0.44, 0.76]:
		for horizontal in [0.08, 0.23, 0.77, 0.91]:
			var point := Vector2(lerpf(rect.position.x, rect.end.x, horizontal), lerpf(rect.position.y, rect.end.y, ratio))
			_add_box(reeds, Vector3(1.2, 7.0, 1.2), _ground_position(point, 3.5), Color("8a984d"), "Reed")


func _add_riverbank_detail(rect: Rect2) -> void:
	# These visual-only instances sit just outside the authoritative water region.
	# They improve shore readability without altering traversal geometry or fog.
	var bank := Node3D.new()
	bank.name = "RiverbankArt"
	_static_root.add_child(bank)
	# The shallow strips deliberately remain outside the water rect. They make the
	# shore legible without suggesting that water is walkable.
	_add_ground_quad(bank, Rect2(rect.position - Vector2(15.0, 0.0), Vector2(12.0, rect.size.y)), Color("7d9569"), 0.075, "ShallowBank")
	_add_ground_quad(bank, Rect2(Vector2(rect.end.x + 3.0, rect.position.y), Vector2(12.0, rect.size.y)), Color("7d9569"), 0.075, "ShallowBank")
	for ratio in [0.14, 0.42, 0.70, 0.88]:
		var y := lerpf(rect.position.y, rect.end.y, ratio)
		_add_nature_asset(bank, &"GRASS", Vector2(rect.position.x - 11.0, y), 26.0, 0.0, "RiverbankGrass")
		_add_nature_asset(bank, &"GRASS", Vector2(rect.end.x + 11.0, y + 8.0), 22.0, 0.35, "RiverbankGrass")
	for point in [Vector2(rect.position.x - 18.0, rect.position.y + 22.0), Vector2(rect.end.x + 18.0, rect.end.y - 25.0)]:
		_add_nature_asset(bank, &"ROCK_LOW", point, 15.0, 0.0, "RiverbankRock")


func _add_tree(parent: Node3D, world_position: Vector2, scale: float, nature_kind: StringName) -> void:
	if _add_nature_asset(parent, nature_kind, world_position, 23.0 * scale, fmod(world_position.x, 3.0) * 0.38, "ArtTree"):
		return
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = _ground_position(world_position)
	parent.add_child(tree)
	_add_cylinder(tree, 1.4 * scale, 1.7 * scale, 11.0 * scale, Vector3(0, 5.5 * scale, 0), Color("634831"), 6, "Trunk")
	_add_cylinder(tree, 0.0, 8.0 * scale, 18.0 * scale, Vector3(0, 17.0 * scale, 0), Color("315842"), 7, "Crown")
	_add_cylinder(tree, 0.0, 5.6 * scale, 12.0 * scale, Vector3(0, 25.0 * scale, 0), Color("517443"), 7, "CrownTop")


func _add_rock(parent: Node3D, world_position: Vector2, radius: float, nature_kind: StringName) -> void:
	if _add_nature_asset(parent, nature_kind, world_position, radius * 3.6, fmod(world_position.y, 4.0) * 0.25, "ArtRock"):
		return
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.radius = radius
	mesh.height = radius * 1.25
	var instance := MeshInstance3D.new()
	instance.name = "Rock"
	instance.mesh = mesh
	instance.position = _ground_position(world_position, radius * 0.45)
	instance.scale = Vector3(1.18, 0.72, 0.9)
	instance.material_override = _material(Color("756f61"), 1.0)
	parent.add_child(instance)


func _add_nature_asset(parent: Node3D, asset_kind: StringName, world_position: Vector2, visual_scale: float, yaw: float, node_name: String) -> bool:
	var path := String(NATURE_ASSET_PATHS.get(asset_kind, ""))
	if path.is_empty():
		return false
	var scene: PackedScene = _nature_scenes.get(asset_kind, null)
	if scene == null:
		scene = load(path) as PackedScene
		if scene == null:
			return false
		_nature_scenes[asset_kind] = scene
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return false
	instance.name = node_name
	instance.position = _ground_position(world_position)
	instance.scale = Vector3.ONE * visual_scale
	instance.rotation.y = yaw
	instance.set_meta("asset_path", path)
	instance.set_meta("world_anchor", world_position)
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		# Imported GLBs expose separate trunk/crown and rock-light/rock-dark
		# surfaces. A single material_override erased that authored separation.
		# Surface variants keep every source material's texture and render flags,
		# while applying the Blackstone palette without mutating shared imports.
		mesh_instance.material_override = null
		mesh_instance.material_overlay = null
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.get_active_material(surface)
			var variant := _nature_material_variant(asset_kind, surface, source_material)
			if variant != null:
				mesh_instance.set_surface_override_material(surface, variant)
	parent.add_child(instance)
	# GLB roots preserve their authored child transforms. Some selected Kenney
	# meshes extend a small distance below their root, so settle the transformed
	# visible mesh—not an empty parent or metadata marker—onto the shared ground.
	var expected_ground_y := _ground_position(world_position).y
	var lowest_y := _lowest_visible_mesh_y(instance)
	if is_finite(lowest_y):
		instance.position.y += expected_ground_y - lowest_y
	instance.set_meta("ground_contact_y", expected_ground_y)
	return true


func _nature_material_variant(asset_kind: StringName, surface: int, source: Material) -> Material:
	var key := "%s:%d" % [String(asset_kind), surface]
	if _nature_material_variants.has(key):
		return _nature_material_variants[key]
	if not source is BaseMaterial3D:
		return source
	var variant := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
	if variant == null:
		return source
	variant.albedo_color = _nature_surface_color(asset_kind, surface)
	# Kenney's imported GLB surfaces declare metallicFactor=1. They are trees,
	# grass and rocks in this miniature, so retain their surface partition while
	# correcting only these runtime copies to a non-metallic material response.
	variant.metallic = 0.0
	variant.roughness = maxf(variant.roughness, 0.78)
	_nature_material_variants[key] = variant
	return variant


func _nature_surface_color(asset_kind: StringName, surface: int) -> Color:
	# Kenney trees use surface 0 for the trunk and surface 1 for the crown.
	# Rocks retain two or three shaded facets, rather than becoming flat grey.
	match asset_kind:
		&"TREE_BROADLEAF":
			return Color("75543a") if surface == 0 else Color("557947")
		&"TREE_PINE":
			return Color("6e4e38") if surface == 0 else Color("3e6a4d")
		&"TREE_DARK":
			return Color("5b4233") if surface == 0 else Color("2f5945")
		&"ROCK_WIDE":
			return Color("8a8171") if surface == 0 else Color("62685e")
		&"ROCK_LOW":
			return Color("9a8974") if surface == 0 else Color("6d7064")
		&"ROCK_TALL":
			if surface == 0:
				return Color("827b70")
			if surface == 1:
				return Color("5c655e")
			return Color("b6a587")
		&"GRASS":
			return Color("6f9148")
	return Color.WHITE


func _lowest_visible_mesh_y(root: Node3D) -> float:
	var lowest := INF
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var bounds := mesh_instance.get_aabb()
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var corner := bounds.position + bounds.size * Vector3(x, y, z)
					lowest = minf(lowest, (mesh_instance.global_transform * corner).y)
	return lowest


func _rebuild_roads(roads: Dictionary) -> void:
	_clear_children(_road_root)
	var road_ids: Array = roads.keys()
	road_ids.sort()
	for road_id_value in road_ids:
		var road: Dictionary = Dictionary(roads[road_id_value])
		var points: Array = Array(road.get("route_world_points", []))
		if points.size() < 2:
			continue
		var kind := StringName(road.get("road_kind", &""))
		var damaged := StringName(road.get("state", &"")) == &"DAMAGED"
		var color := Color("81623f")
		if kind == &"BRIDGE":
			color = Color("c79757")
		elif kind == &"NORMAL":
			color = Color("76593a")
		if damaged:
			color = Color("7a3935")
		for index in range(1, points.size()):
			var elevation := 0.7 if kind == &"BRIDGE" else 0.35
			_add_road_segment(_road_root, Vector2(points[index - 1]), Vector2(points[index]), color, kind == &"BRIDGE", damaged, elevation)


func _add_road_segment(parent: Node3D, start: Vector2, end: Vector2, color: Color, bridge: bool, damaged: bool, elevation: float, construction := false) -> void:
	var start_3d := _ground_position(start, elevation)
	var end_3d := _ground_position(end, elevation)
	var distance := start_3d.distance_to(end_3d)
	if distance <= 0.01:
		return
	var segment := Node3D.new()
	segment.name = ("ProjectBridgeSegment" if bridge else "ProjectRoadSegment") if construction else ("BridgeSegment" if bridge else "RoadSegment")
	parent.add_child(segment)
	segment.global_position = start_3d.lerp(end_3d, 0.5)
	segment.look_at(end_3d, Vector3.UP)
	segment.set_meta("road_start", start_3d)
	segment.set_meta("road_end", end_3d)
	# Slightly broader presentation-only surfaces keep the legal route legible at
	# overview without altering the underlying route geometry or hit target.
	var deck_width := 20.0 if bridge else 15.0
	var deck_height := 1.7 if bridge else 0.7
	_add_box(segment, Vector3(deck_width, deck_height, distance + 2.0), Vector3.ZERO, color, "Deck")
	if bridge:
		var plank_count := maxi(2, floori(distance / 14.0))
		for index in range(plank_count):
			var z := -distance * 0.5 + float(index) * distance / float(maxi(plank_count - 1, 1))
			_add_box(segment, Vector3(23.0, 0.75, 1.0), Vector3(0, 1.15, z), Color("f0c67a"), "Plank")
		_add_box(segment, Vector3(0.9, 4.0, distance), Vector3(-10.4, 2.0, 0), Color("6d4e35"), "Rail")
		_add_box(segment, Vector3(0.9, 4.0, distance), Vector3(10.4, 2.0, 0), Color("6d4e35"), "Rail")
	if damaged:
		_add_box(segment, Vector3(deck_width + 3.0, 2.0, 7.0), Vector3(0, 2.0, 0), Color("332b2b"), "Break")


func _rebuild_points(model: Dictionary, field: Dictionary) -> void:
	_clear_children(_point_root)
	if _theater == null:
		return
	var points: Dictionary = _theater.get_points()
	for camp_value in Dictionary(field.get("camps_by_id", {})).values():
		var camp: Dictionary = Dictionary(camp_value)
		points[StringName(camp.get("point_id", &""))] = camp
	var cities: Dictionary = Dictionary(Dictionary(model.get("war_loop", {})).get("cities_by_id", {}))
	var point_ids: Array = points.keys()
	point_ids.sort()
	for point_id_value in point_ids:
		var point_id := StringName(point_id_value)
		var point: Dictionary = Dictionary(points[point_id])
		var position := Vector2(point.get("world_position", Vector2.ZERO))
		var kind := StringName(point.get("point_kind", &""))
		var controller := StringName(Dictionary(cities.get(point_id, {})).get("military_controller_faction_id", point.get("military_controller_faction_id", &"player")))
		if kind == &"ENEMY_CITY" or point_id in [&"blackstone_city", &"redcliff_city", &"silverford_city"]:
			_add_city(_point_root, position, controller != &"player")
		else:
			_add_garrison(_point_root, position, StringName(point.get("camp_id", &"")) != &"", point_id)


func _add_city(parent: Node3D, position: Vector2, enemy: bool) -> void:
	var city := Node3D.new()
	city.name = "EnemyCity" if enemy else "FriendlyCity"
	city.position = _ground_position(position, 0.8)
	parent.add_child(city)
	var wall_color := Color("78504a") if enemy else Color("777467")
	var roof_color := Color("71372f") if enemy else Color("274c55")
	var banner_color := Color("bf4e41") if enemy else Color("ddb550")
	# An authored gatehouse follows the local Chinese frontier reference silhouette,
	# while remaining a lightweight assembly at the authoritative city anchor.
	_add_box(city, Vector3(78.0, 8.0, 38.0), Vector3(0, 4.0, 0), Color("55534d"), "WallFoot")
	_add_box(city, Vector3(68.0, 19.0, 24.0), Vector3(0, 17.5, 0), wall_color, "Wall")
	for x in [-27.0, 27.0]:
		_add_box(city, Vector3(17.0, 35.0, 18.0), Vector3(x, 25.5, 0), wall_color, "Tower")
		_add_cylinder(city, 0.0, 15.0, 10.0, Vector3(x, 48.0, 0), roof_color, 4, "TowerRoof")
	_add_box(city, Vector3(25.0, 16.0, 5.0), Vector3(0, 11.0, -14.5), Color("292725"), "Gate")
	_add_box(city, Vector3(46.0, 17.0, 25.0), Vector3(0, 45.0, 0), Color("74492f"), "Gatehouse")
	_add_box(city, Vector3(58.0, 3.0, 33.0), Vector3(0, 55.0, 0), roof_color, "RoofEave")
	_add_cylinder(city, 0.0, 32.0, 13.0, Vector3(0, 62.5, 0), roof_color, 4, "GatehouseRoof")
	_add_box(city, Vector3(2.0, 53.0, 2.0), Vector3(15.0, 38.5, 0), Color("332d29"), "FlagPole")
	_add_box(city, Vector3(16.0, 9.0, 1.0), Vector3(23.0, 56.0, 0), banner_color, "Flag")


func _add_garrison(parent: Node3D, position: Vector2, is_runtime_camp: bool, point_id: StringName) -> void:
	var camp := Node3D.new()
	camp.name = "RuntimeCamp" if is_runtime_camp else "Garrison"
	camp.position = _ground_position(position, 0.4)
	parent.add_child(camp)
	_add_cylinder(camp, 0.0, 12.0, 15.0, Vector3(-7, 7.5, 2), Color("ded3ae"), 4, "Tent")
	_add_cylinder(camp, 0.0, 9.0, 12.0, Vector3(10, 6.0, -4), Color("b8965f"), 4, "Tent")
	_add_cylinder(camp, 0.0, 7.5, 10.0, Vector3(3, 5.0, 12), Color("c9b07a"), 4, "Tent")
	_add_box(camp, Vector3(32.0, 2.5, 2.5), Vector3(0, 4.0, 14), Color("684b34"), "CampPalisade")
	_add_box(camp, Vector3(2.5, 2.0, 25.0), Vector3(-17.0, 3.5, 1.0), Color("684b34"), "CampPalisade")
	_add_cylinder(camp, 2.2, 2.2, 1.0, Vector3(-2.0, 0.8, -9.0), Color("d88a45"), 10, "CampFire")
	_add_box(camp, Vector3(2.0, 27.0, 2.0), Vector3(8, 14.0, 8), Color("49372b"), "FlagPole")
	_add_box(camp, Vector3(11.0, 6.0, 1.0), Vector3(14.0, 22.0, 8), Color("ddb550"), "Flag")
	if point_id == &"ridge_watch":
		_add_box(camp, Vector3(15.0, 25.0, 15.0), Vector3(-17.0, 12.5, -5.0), Color("6a5039"), "Watchtower")
		_add_box(camp, Vector3(25.0, 3.0, 25.0), Vector3(-17.0, 26.0, -5.0), Color("304e55"), "WatchtowerRoof")


func _sync_armies(armies: Array) -> void:
	var seen: Dictionary = {}
	for army_value in armies:
		var army: Dictionary = Dictionary(army_value)
		var army_id := StringName(army.get("army_id", &""))
		if army_id == &"":
			continue
		seen[army_id] = true
		var node: Node3D = _army_nodes.get(army_id, null)
		if node == null:
			node = Node3D.new()
			node.name = "Army_%s" % String(army_id)
			_army_root.add_child(node)
			_army_nodes[army_id] = node
		var state := _army_motion_state(army)
		node.position = _ground_position(Vector2(state.get("world_position", Vector2.ZERO)), 2.2)
		var count := _army_member_count(army)
		var selected := army_id == _selected_army_id
		var signature := "%s:%d:%s" % [String(army.get("phase", &"")), count, selected]
		if _army_visual_signatures.get(army_id, "") != signature:
			_army_visual_signatures[army_id] = signature
			_clear_children(node)
			_add_unit_group(node, Color("d44d3f"), Color("f4d476"), count, "Army")
			if selected:
				_add_selection_marker(node, count, false)
	_remove_absent_nodes(_army_nodes, _army_visual_signatures, seen)


func _sync_specialists(specialists: Dictionary) -> void:
	var seen: Dictionary = {}
	for specialist_id_value in specialists:
		var specialist_id := StringName(specialist_id_value)
		var specialist: Dictionary = Dictionary(specialists[specialist_id])
		if not bool(specialist.get("alive", false)):
			continue
		seen[specialist_id] = true
		var node: Node3D = _specialist_nodes.get(specialist_id, null)
		if node == null:
			node = Node3D.new()
			node.name = "Specialist_%s" % String(specialist_id)
			_specialist_root.add_child(node)
			_specialist_nodes[specialist_id] = node
		var role := StringName(specialist.get("role", &""))
		node.position = _ground_position(Vector2(specialist.get("world_position", Vector2.ZERO)), 2.4)
		var selected := specialist_id == _selected_specialist_id
		var signature := "%s:%s" % [String(role), selected]
		if _specialist_visual_signatures.get(specialist_id, &"") != signature:
			_specialist_visual_signatures[specialist_id] = signature
			_clear_children(node)
			_add_specialist(node, role)
			if selected:
				_add_selection_marker(node, 1, true)
	_remove_absent_nodes(_specialist_nodes, _specialist_visual_signatures, seen)


func _sync_patrols(patrols: Dictionary) -> void:
	var seen: Dictionary = {}
	for patrol_id_value in patrols:
		var patrol_id := StringName(patrol_id_value)
		var patrol: Dictionary = Dictionary(patrols[patrol_id])
		seen[patrol_id] = true
		var node: Node3D = _patrol_nodes.get(patrol_id, null)
		if node == null:
			node = Node3D.new()
			node.name = "Patrol_%s" % String(patrol_id)
			_patrol_root.add_child(node)
			_patrol_nodes[patrol_id] = node
		node.position = _ground_position(Vector2(patrol.get("last_known_world_position", Vector2.ZERO)), 2.1)
		var strength := int(patrol.get("known_strength", 0))
		var signature := "%d:%s" % [strength, String(patrol.get("fog_state", &""))]
		if _patrol_visual_signatures.get(patrol_id, "") != signature:
			_patrol_visual_signatures[patrol_id] = signature
			_clear_children(node)
			_add_unit_group(node, Color("9f4139"), Color("d7c6a3"), strength, "Patrol")
	_remove_absent_nodes(_patrol_nodes, _patrol_visual_signatures, seen)


func _sync_projects(projects: Dictionary, specialists: Dictionary) -> void:
	_clear_children(_project_root)
	for project_value in projects.values():
		var project: Dictionary = Dictionary(project_value)
		if StringName(project.get("phase", &"")) in [&"COMPLETE", &"INTERRUPTED"]:
			continue
		var project_node := Node3D.new()
		project_node.name = "Project"
		_project_root.add_child(project_node)
		_add_active_project_segment(project_node, project)
		var points: Array = Array(project.get("route_world_points", []))
		var engineer := Dictionary(specialists.get(StringName(project.get("engineer_id", &"")), {}))
		if not engineer.is_empty() and bool(engineer.get("alive", false)):
			var scaffold := Node3D.new()
			scaffold.position = _ground_position(Vector2(engineer.get("world_position", points.front())), 2.5)
			project_node.add_child(scaffold)
			_add_box(scaffold, Vector3(12, 16, 1.5), Vector3.ZERO, Color("a87544"), "Scaffold")
			_add_box(scaffold, Vector3(1.5, 16, 12), Vector3.ZERO, Color("a87544"), "Scaffold")


func _add_active_project_segment(parent: Node3D, project: Dictionary) -> void:
	# Completed physical segments are rendered through roads_by_id.  This root only
	# renders the part currently under construction and retains each authoritative
	# segment's kind instead of converting all project geometry into a bridge.
	if StringName(project.get("phase", &"")) != &"BUILDING":
		return
	var elapsed := int(project.get("progress_milliseconds", 0))
	for plan_value in Array(project.get("segment_plans", [])):
		var plan: Dictionary = Dictionary(plan_value)
		var duration := maxi(int(plan.get("required_milliseconds", 0)), 1)
		if elapsed >= duration:
			elapsed -= duration
			continue
		if elapsed <= 0:
			return
		var partial_points := _partial_route_points(Array(plan.get("route_world_points", [])), float(elapsed) / float(duration))
		if partial_points.size() < 2:
			return
		var kind := StringName(plan.get("road_kind", &""))
		var bridge := kind == &"BRIDGE"
		_add_road_polyline(parent, partial_points, Color("e6bb6d") if bridge else Color("b98752"), bridge, 0.92 if bridge else 0.52, true)
		return


func _add_road_polyline(parent: Node3D, points: Array, color: Color, bridge: bool, elevation: float, construction: bool) -> void:
	for index in range(1, points.size()):
		_add_road_segment(parent, Vector2(points[index - 1]), Vector2(points[index]), color, bridge, false, elevation, construction)


func _partial_route_points(points: Array, fraction: float) -> Array:
	if points.size() < 2:
		return []
	var total_length := 0.0
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	var target_length := total_length * clampf(fraction, 0.0, 1.0)
	var result: Array = [Vector2(points.front())]
	var consumed := 0.0
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var length := start.distance_to(end)
		if consumed + length <= target_length:
			result.append(end)
			consumed += length
			continue
		if target_length > consumed:
			result.append(start.lerp(end, (target_length - consumed) / maxf(length, 0.0001)))
		break
	return result


func _add_unit_group(parent: Node3D, coat: Color, banner: Color, count: int, node_name: String) -> void:
	var member_count := clampi(count, 1, 5)
	for index in range(member_count):
		var offset := Vector3(float(index % 3 - 1) * 4.0, 0.0, float(index / 3) * 4.5)
		_add_cylinder(parent, 1.5, 1.8, 6.0, offset + Vector3(0, 3, 0), coat, 6, "%sSoldier" % node_name)
		_add_sphere(parent, 1.9, offset + Vector3(0, 7.2, 0), Color("f0c59f"), "%sHead" % node_name)
	_add_box(parent, Vector3(1.1, 19.0, 1.1), Vector3(8, 9.5, 0), Color("382c29"), "%sFlagPole" % node_name)
	_add_box(parent, Vector3(9.0, 5.0, 0.8), Vector3(12, 15.0, 0), banner, "%sFlag" % node_name)


func _add_specialist(parent: Node3D, role: StringName) -> void:
	var coat := Color("63b9d8") if role == &"SCOUT" else Color("e1a65d")
	_add_cylinder(parent, 1.4, 1.7, 7.0, Vector3(0, 3.5, 0), coat, 6, "Specialist")
	_add_sphere(parent, 1.9, Vector3(0, 8.2, 0), Color("f0c59f"), "SpecialistHead")
	if role == &"ENGINEER":
		_add_box(parent, Vector3(6.0, 0.8, 1.2), Vector3(5.0, 5.0, 0), Color("74503a"), "Tool")


func _add_selection_marker(parent: Node3D, member_count: int, specialist: bool) -> void:
	# A compact elevated, depth-independent command pennant complements the
	# existing hollow 2D selection ring when a truthful ground actor is occluded
	# by a city, camp, tree cluster, or bridge. It carries no simulation position,
	# input, or duplicate count label.
	var marker := Node3D.new()
	marker.name = "SpecialistSelectionMarker" if specialist else "ArmySelectionMarker"
	parent.add_child(marker)
	var height := 30.0 if specialist else 36.0
	_add_marker_box(marker, Vector3(1.4, height, 1.4), Vector3(0, height * 0.5, 0), Color("f7df7b"), "SelectionPole")
	_add_marker_box(marker, Vector3(14.0, 7.0, 0.8), Vector3(7.5, height - 4.0, 0), Color("f7df7b") if specialist else Color("f4b94c"), "SelectionPennant")
	marker.set_meta("member_count", member_count)


func _add_marker_box(parent: Node3D, mesh_size: Vector3, position: Vector3, color: Color, node_name: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _overlay_material(color)
	parent.add_child(instance)


func _add_box(parent: Node3D, mesh_size: Vector3, position: Vector3, color: Color, node_name: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color, 0.9)
	parent.add_child(instance)


func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, position: Vector3, color: Color, segments: int, node_name: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color, 0.88)
	parent.add_child(instance)


func _add_sphere(parent: Node3D, radius: float, position: Vector3, color: Color, node_name: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _material(color, 0.8)
	parent.add_child(instance)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _overlay_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.7)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.no_depth_test = true
	return material


func _army_motion_state(army: Dictionary) -> Dictionary:
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	var transfer: Dictionary = Dictionary(macro.get("blocked_transfer", {}))
	var points: Array = Array(macro.get("route_world_points", []))
	var progress := int(macro.get("progress_millis", 0))
	var total := maxi(int(macro.get("total_millis", 1)), 1)
	if StringName(army.get("phase", &"")) == &"BLOCKED" and StringName(transfer.get("phase", &"")) in [&"TO_CAMP", &"TO_CAMP_BLOCKED", &"WAITING", &"TO_RESUME", &"TO_RESUME_BLOCKED"]:
		points = Array(transfer.get("route_world_points", []))
		progress = int(transfer.get("progress_millis", 0))
		total = maxi(int(transfer.get("total_millis", 1)), 1)
	return {"world_position": _point_along_route(points, float(progress) / float(total))}


func _point_along_route(points: Array, progress: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var total_length := 0.0
	for index in range(1, points.size()):
		total_length += Vector2(points[index - 1]).distance_to(Vector2(points[index]))
	var remaining := total_length * clampf(progress, 0.0, 1.0)
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1])
		var end := Vector2(points[index])
		var length := start.distance_to(end)
		if remaining <= length:
			return start.lerp(end, remaining / maxf(length, 0.0001))
		remaining -= length
	return Vector2(points.back())


func _army_member_count(army: Dictionary) -> int:
	var total := 0
	for formation_value in Array(Dictionary(army.get("macro_march", {})).get("formation_snapshots", [])):
		total += int(Dictionary(formation_value).get("member_count", 0))
	return total


func _road_state_signature(roads: Dictionary) -> String:
	var parts: Array[String] = []
	var ids: Array = roads.keys()
	ids.sort()
	for road_id_value in ids:
		var road: Dictionary = Dictionary(roads[road_id_value])
		parts.append("%s:%s:%s:%s" % [String(road_id_value), String(road.get("state", &"")), String(road.get("road_kind", &"")), str(road.get("route_world_points", []))])
	return "|".join(parts)


func _point_state_signature(model: Dictionary, field: Dictionary) -> String:
	return "%s|%s" % [str(Dictionary(Dictionary(model.get("war_loop", {})).get("cities_by_id", {}))), str(Dictionary(field.get("camps_by_id", {})))]


func _remove_absent_nodes(nodes: Dictionary, signatures: Dictionary, seen: Dictionary) -> void:
	for node_id_value in nodes.keys():
		var node_id := StringName(node_id_value)
		if seen.has(node_id):
			continue
		var node: Node = nodes[node_id]
		if is_instance_valid(node):
			node.queue_free()
		nodes.erase(node_id)
		signatures.erase(node_id)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()
