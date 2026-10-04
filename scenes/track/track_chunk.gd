extends StaticBody3D

@export_group("Textures & Materials")
@export var road_texture: Texture2D
@export var texture_repeat_distance: float = 4.0

@export_subgroup("Outer Environment")
@export var shoulder_width: float = 40.0         # How far the terrain extends left/right
@export var ground_color: Color = Color("2e7d32") # Default Grass Green (Change to white for snow!)
@export var ground_material: StandardMaterial3D   # Optional custom material override

@export_group("Fences & Props")
@export var fence_scene_a: PackedScene            # Red barrier scene
@export var fence_scene_b: PackedScene            # White barrier scene
@export var fence_spacing: float = 6.0            # Distance in meters between barrier posts
@export var obstacle_scenes: Array[PackedScene] = []
@export var patch_scenes: Array[PackedScene] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance
@onready var collision_shape: CollisionShape3D = $CollisionShape

var end_s: float = 0.0

func generate_chunk(start_s: float, length: float) -> void:
	end_s = start_s + length

	# ArrayMesh allows having multiple material surfaces (Surface 0: Road, Surface 1: Ground)
	var array_mesh := ArrayMesh.new()

	# --- 1. PREPARE MATERIALS ---
	var road_mat := StandardMaterial3D.new()
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if road_texture:
		road_mat.albedo_texture = road_texture
		road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		road_mat.albedo_color = Color(0.25, 0.25, 0.3)

	var terrain_mat := ground_material
	if not terrain_mat:
		terrain_mat = StandardMaterial3D.new()
		terrain_mat.albedo_color = ground_color
		terrain_mat.roughness = 0.9

	# --- 2. BUILD ROAD MESH (Surface 0) ---
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_road.set_material(road_mat)

	# --- 3. BUILD TERRAIN SHOULDER MESH (Surface 1) ---
	var st_ground := SurfaceTool.new()
	st_ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_ground.set_material(terrain_mat)

	var step := TrackMath.step_size
	var start_idx := int(start_s / step)
	var count := int(length / step)
	var end_idx := start_idx + count

	TrackMath.ensure_calculated_up_to(end_idx + 1)

	for i in range(start_idx, end_idx):
		var s1 := float(i) * step
		var s2 := float(i + 1) * step

		var v1 := s1 / texture_repeat_distance
		var v2 := s2 / texture_repeat_distance

		var p1 := TrackMath.points[i]
		var p2 := TrackMath.points[i + 1]

		var norm1 := TrackMath.normals[i]
		var norm2 := TrackMath.normals[i + 1]

		var w1 := TrackMath.widths[i] / 2.0
		var w2 := TrackMath.widths[i + 1] / 2.0

		# Road edges
		var p_left1 := p1 - norm1 * w1
		var p_right1 := p1 + norm1 * w1
		var p_left2 := p2 - norm2 * w2
		var p_right2 := p2 + norm2 * w2

		# Outer environment edges
		var p_out_left1 := p1 - norm1 * (w1 + shoulder_width)
		var p_out_right1 := p1 + norm1 * (w1 + shoulder_width)
		var p_out_left2 := p2 - norm2 * (w2 + shoulder_width)
		var p_out_right2 := p2 + norm2 * (w2 + shoulder_width)

		# UVs for road
		var tex_w: float = 8.0
		var uv_l1 := Vector2(0.5 - (w1 / tex_w), v1)
		var uv_r1 := Vector2(0.5 + (w1 / tex_w), v1)
		var uv_l2 := Vector2(0.5 - (w2 / tex_w), v2)
		var uv_r2 := Vector2(0.5 + (w2 / tex_w), v2)

		# Add Road Quad
		add_quad_with_uv(st_road, p_left1, uv_l1, p_left2, uv_l2, p_right1, uv_r1, p_right2, uv_r2)

		# Dummy UVs for color ground mesh
		var g_uv := Vector2.ZERO
		# Add Left Ground Quad
		add_quad_with_uv(st_ground, p_out_left1, g_uv, p_out_left2, g_uv, p_left1, g_uv, p_left2, g_uv)
		# Add Right Ground Quad
		add_quad_with_uv(st_ground, p_right1, g_uv, p_right2, g_uv, p_out_right1, g_uv, p_out_right2, g_uv)

	# Commit both surfaces to the ArrayMesh
	st_road.generate_normals()
	st_road.commit(array_mesh)

	st_ground.generate_normals()
	st_ground.commit(array_mesh)

	mesh_instance.mesh = array_mesh

	if array_mesh.get_faces().size() > 0:
		collision_shape.shape = array_mesh.create_trimesh_shape()

	# --- 4. SPAWN ALTERNATING FENCES ALONG ROAD EDGES ---
	if fence_scene_a or fence_scene_b:
		spawn_fences_along_chunk(start_s, end_s)

	# --- 5. SPAWN OBSTACLES & PATCHES ---
	spawn_ground_patches(start_s, end_s)
	spawn_3d_obstacles(start_s, end_s)


func spawn_fences_along_chunk(start_s: float, chunk_end_s: float) -> void:
	var current_fence_s: float = ceil(start_s / fence_spacing) * fence_spacing

	while current_fence_s < chunk_end_s:
		var idx := int(current_fence_s / TrackMath.step_size)
		TrackMath.ensure_calculated_up_to(idx + 1)

		var pos := TrackMath.points[idx]
		var norm := TrackMath.normals[idx]
		var tan := TrackMath.tangents[idx]
		var half_w := TrackMath.widths[idx] / 2.0

		# Calculate step index to alternate back-to-back (0, 1, 0, 1...)
		var step_index := int(round(current_fence_s / fence_spacing))
		var scene_to_use: PackedScene
		if step_index % 2 == 0:
			scene_to_use = fence_scene_a if fence_scene_a else fence_scene_b
		else:
			scene_to_use = fence_scene_b if fence_scene_b else fence_scene_a

		if scene_to_use:
			# Left Fence (Offset slightly outside road edge)
			spawn_single_fence(scene_to_use, pos - norm * (half_w + 0.3), tan)
			# Right Fence
			spawn_single_fence(scene_to_use, pos + norm * (half_w + 0.3), tan)

		current_fence_s += fence_spacing

func spawn_single_fence(scene_to_spawn: PackedScene, spawn_pos: Vector3, tangent_dir: Vector3) -> void:
	var fence := scene_to_spawn.instantiate() as Node3D
	add_child(fence)
	fence.global_position = spawn_pos
	
	if tangent_dir.length() > 0:
		fence.look_at(fence.global_position + tangent_dir, Vector3.UP)
		# 90-degree local rotation to make the mesh run parallel along the track edge
		fence.rotate_object_local(Vector3.UP, deg_to_rad(90.0))


func add_quad_with_uv(st: SurfaceTool, p1: Vector3, uv1: Vector2, p2: Vector3, uv2: Vector2, p3: Vector3, uv3: Vector2, p4: Vector3, uv4: Vector2) -> void:
	st.set_uv(uv1); st.add_vertex(p1)
	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv3); st.add_vertex(p3)

	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv4); st.add_vertex(p4)
	st.set_uv(uv3); st.add_vertex(p3)

func spawn_ground_patches(start_s: float, chunk_end_s: float) -> void:
	if patch_scenes.is_empty(): return
	var patch_step := 10.0
	var current_s: float = ceil(start_s / patch_step) * patch_step
	while current_s < chunk_end_s:
		var p_info := TrackMath.get_patch_info(current_s, patch_scenes.size())
		if p_info.get("has_patch", false):
			spawn_obstacle_at(current_s, p_info.offset_ratio, patch_scenes[p_info.type_index], p_info.rotation_deg, p_info.scale_ratio_x, p_info.scale_ratio_z)
		current_s += patch_step

func spawn_3d_obstacles(start_s: float, chunk_end_s: float) -> void:
	if obstacle_scenes.is_empty(): return
	var check_step := 12.0
	var current_s: float = ceil(start_s / check_step) * check_step
	while current_s < chunk_end_s:
		var info := TrackMath.get_obstacle_info(current_s, obstacle_scenes.size())
		if info.get("has_obstacle", false):
			spawn_obstacle_at(current_s, info.offset_ratio, obstacle_scenes[info.type_index], info.rotation_deg, info.scale_ratio_x, info.scale_ratio_z)
		current_s += check_step

func spawn_obstacle_at(s: float, offset_ratio: float, scene_to_spawn: PackedScene, extra_rotation_deg: float = 0.0, scale_ratio_x: float = 0.5, scale_ratio_z: float = 0.5) -> void:
	if not scene_to_spawn: return
	var idx := int(s / TrackMath.step_size)
	TrackMath.ensure_calculated_up_to(idx + 1)
	var center_pos := TrackMath.points[idx]
	var norm := TrackMath.normals[idx]
	var half_w := TrackMath.widths[idx] / 2.0
	var spawn_pos := center_pos + norm * (half_w * offset_ratio)

	var obs := scene_to_spawn.instantiate() as Node3D
	add_child(obs)
	obs.global_position = spawn_pos

	var tan := TrackMath.tangents[idx]
	if tan.length() > 0:
		obs.look_at(obs.global_position + tan, Vector3.UP)
	obs.rotate_object_local(Vector3.UP, deg_to_rad(extra_rotation_deg))

	# Min/Max scaling logic
	var min_s: float = 1.0
	var max_s: float = 1.0

	if "min_scale" in obs:
		min_s = obs.min_scale
	if "max_scale" in obs:
		max_s = obs.max_scale

	if obs is GrassPatch:
		var final_scale_x : float = lerp(min_s, max_s, scale_ratio_x)
		var final_scale_z : float = lerp(min_s, max_s, scale_ratio_z)
		obs.scale = Vector3(final_scale_x, 1.0, final_scale_z)
	else:
		var uniform_ratio : float = (scale_ratio_x + scale_ratio_z) / 2.0
		var uniform_scale : float = lerp(min_s, max_s, uniform_ratio)
		obs.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)
