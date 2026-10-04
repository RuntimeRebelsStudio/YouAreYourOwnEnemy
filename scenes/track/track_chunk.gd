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
@export var fence_offset_left: float = 0.3        # Fine-tune left fence offset
@export var fence_offset_right: float = 0.3       # Fine-tune right fence offset
@export var fence_rotation_deg: float = 90.0      # Adjustable base mesh rotation

@export_group("Procedural Trees")
@export var tree_scenes: Array[PackedScene] = []  # Tree prefabs/scenes
@export var tree_spacing: float = 4.0             # Distance along track between forest checks (Lower = denser)
@export var trees_per_step: int = 4               # How many trees to attempt spawning per side at each step!
@export var tree_density: float = 0.85            # Probability (0.0 - 1.0) for each individual tree attempt
@export var tree_min_offset: float = 2.0          # Distance OUTSIDE the fence (meters)
@export var tree_max_offset: float = 35.0         # Max depth into the forest shoulder
@export var tree_min_scale: float = 2.5           # Minimum tree scale multiplier
@export var tree_max_scale: float = 5.0           # Maximum tree scale multiplier
@export var tree_min_distance: float = 4.5        # Minimum distance in meters between any two trees

@export_group("Obstacles & Patches")
@export var obstacle_scenes: Array[PackedScene] = []
@export var patch_scenes: Array[PackedScene] = []

@onready var mesh_instance: MeshInstance3D = $MeshInstance
@onready var collision_shape: CollisionShape3D = $CollisionShape

var end_s: float = 0.0

func generate_chunk(start_s: float, length: float) -> void:
	end_s = start_s + length

	var array_mesh := ArrayMesh.new()

	# --- 1. PREPARE MATERIALS ---
	var road_mat := StandardMaterial3D.new()
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_mat.render_priority = 1
	
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

	terrain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain_mat.render_priority = 0

	# --- 2. BUILD MESH SURFACES ---
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_road.set_material(road_mat)

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

		# 1. Exact Road Edges
		var p_left1 := p1 - norm1 * w1
		var p_right1 := p1 + norm1 * w1
		var p_left2 := p2 - norm2 * w2
		var p_right2 := p2 + norm2 * w2

		# 2. Overlap under road + micro Y-slant per step to break self Z-fighting on turns
		var overlap := 0.5
		var step_y_bias := float(i % 10) * 0.001 # Micro height delta prevents overlapping ground quads from Z-fighting
		var y_drop := Vector3(0.0, -0.05 - step_y_bias, 0.0)

		var p_g_in_left1 := (p1 - norm1 * (w1 - overlap)) + y_drop
		var p_g_in_right1 := (p1 + norm1 * (w1 - overlap)) + y_drop
		var p_g_in_left2 := (p2 - norm2 * (w2 - overlap)) + y_drop
		var p_g_in_right2 := (p2 + norm2 * (w2 - overlap)) + y_drop

		# 3. Outer Ground Edges (Clamped on sharp curves so inner quads don't overlap as aggressively)
		var curve_dot := norm1.dot(norm2)
		var curve_factor := clampf(curve_dot * curve_dot, 0.2, 1.0) 
		var safe_shoulder := shoulder_width * curve_factor

		var p_out_left1 := (p1 - norm1 * (w1 + safe_shoulder)) + y_drop
		var p_out_right1 := (p1 + norm1 * (w1 + safe_shoulder)) + y_drop
		var p_out_left2 := (p2 - norm2 * (w2 + safe_shoulder)) + y_drop
		var p_out_right2 := (p2 + norm2 * (w2 + safe_shoulder)) + y_drop

		# UVs for Road
		var tex_w: float = 8.0
		var uv_l1 := Vector2(0.5 - (w1 / tex_w), v1)
		var uv_r1 := Vector2(0.5 + (w1 / tex_w), v1)
		var uv_l2 := Vector2(0.5 - (w2 / tex_w), v2)
		var uv_r2 := Vector2(0.5 + (w2 / tex_w), v2)

		# Add Road Quad
		add_quad_with_uv(st_road, p_left1, uv_l1, p_left2, uv_l2, p_right1, uv_r1, p_right2, uv_r2)

		# Add Ground Quads
		add_flat_ground_quad(st_ground, p_out_left1, p_out_left2, p_g_in_left1, p_g_in_left2)
		add_flat_ground_quad(st_ground, p_g_in_right1, p_g_in_right2, p_out_right1, p_out_right2)

	# --- 3. COMMIT SURFACES ---
	st_road.generate_normals()
	var road_only_mesh := st_road.commit()
	st_road.commit(array_mesh)

	st_ground.index()
	st_ground.commit(array_mesh)

	mesh_instance.mesh = array_mesh

	if road_only_mesh.get_faces().size() > 0:
		collision_shape.shape = road_only_mesh.create_trimesh_shape()

	# --- 4. SPAWN FENCES, TREES & PROPS ---
	if fence_scene_a or fence_scene_b:
		spawn_fences_along_chunk(start_s, end_s)

	spawn_trees_along_chunk(start_s, end_s)
	spawn_ground_patches(start_s, end_s)
	spawn_3d_obstacles(start_s, end_s)
	
	
	
func add_flat_ground_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> void:
	var dummy_uv := Vector2.ZERO
	var up_normal := Vector3.UP

	st.set_normal(up_normal); st.set_uv(dummy_uv); st.add_vertex(p1)
	st.set_normal(up_normal); st.set_uv(dummy_uv); st.add_vertex(p2)
	st.set_normal(up_normal); st.set_uv(dummy_uv); st.add_vertex(p3)

	st.set_normal(up_normal); st.set_uv(dummy_uv); st.add_vertex(p2)
	st.set_normal(up_normal); st.set_uv(dummy_uv); st.add_vertex(p4)
	st.set_normal(up_normal); st.set_uv(dummy_uv); st.add_vertex(p3)

func spawn_fences_along_chunk(start_s: float, chunk_end_s: float) -> void:
	var current_fence_s: float = ceil(start_s / fence_spacing) * fence_spacing

	while current_fence_s < chunk_end_s:
		var idx := int(current_fence_s / TrackMath.step_size)
		TrackMath.ensure_calculated_up_to(idx + 1)

		var pos := TrackMath.points[idx]
		var norm := TrackMath.normals[idx]
		var tan := TrackMath.tangents[idx]
		var half_w := TrackMath.widths[idx] / 2.0

		var step_index := int(round(current_fence_s / fence_spacing))
		var scene_to_use: PackedScene
		if step_index % 2 == 0:
			scene_to_use = fence_scene_a if fence_scene_a else fence_scene_b
		else:
			scene_to_use = fence_scene_b if fence_scene_b else fence_scene_a

		if scene_to_use:
			var left_pos := pos - norm * (half_w + fence_offset_left)
			spawn_single_fence(scene_to_use, left_pos, tan, false)

			var right_pos := pos + norm * (half_w + fence_offset_right)
			spawn_single_fence(scene_to_use, right_pos, tan, true)

		current_fence_s += fence_spacing


func spawn_single_fence(scene_to_spawn: PackedScene, spawn_pos: Vector3, tangent_dir: Vector3, is_right_side: bool) -> void:
	var fence := scene_to_spawn.instantiate() as Node3D
	add_child(fence)
	fence.global_position = spawn_pos
	
	if tangent_dir.length() > 0:
		fence.look_at(fence.global_position + tangent_dir, Vector3.UP)
		
		# Rotate 90 degrees to run parallel to track
		fence.rotate_object_local(Vector3.UP, deg_to_rad(fence_rotation_deg))
		
		# Mirror rotation if barrier mesh faces inward/outward asymmetrically
		if is_right_side:
			fence.rotate_object_local(Vector3.UP, deg_to_rad(180.0))

# =========================================================
# PROCEDURAL TREE SPAWNING
# =========================================================
func spawn_trees_along_chunk(start_s: float, chunk_end_s: float) -> void:
	if tree_scenes.is_empty():
		return

	# Fast local cache to track tree positions within this chunk
	var spawned_positions: Array[Vector3] = []
	var min_dist_sq:float = tree_min_distance * tree_min_distance

	var current_tree_s: float = ceil(start_s / tree_spacing) * tree_spacing

	while current_tree_s < chunk_end_s:
		var step_id := int(current_tree_s)
		
		# Left Side Trees (-1.0)
		for t in range(trees_per_step):
			var hash_left := posmod(hash((step_id * 1013904223) ^ (t * 1337) ^ TrackMath.noise_obs_spawn.seed), 100000)
			if (hash_left % 100) / 100.0 < tree_density:
				try_spawn_single_tree(current_tree_s, step_id, t, -1.0, spawned_positions, min_dist_sq)

		# Right Side Trees (+1.0)
		for t in range(trees_per_step):
			var hash_right := posmod(hash((step_id * 1664525) ^ (t * 7331) ^ TrackMath.noise_obs_spawn.seed), 100000)
			if (hash_right % 100) / 100.0 < tree_density:
				try_spawn_single_tree(current_tree_s, step_id, t, 1.0, spawned_positions, min_dist_sq)

		current_tree_s += tree_spacing
		
		
func try_spawn_single_tree(s: float, step_id: int, tree_index: int, side: float, spawned_positions: Array[Vector3], min_dist_sq: float) -> void:
	var idx := int(s / TrackMath.step_size)
	TrackMath.ensure_calculated_up_to(idx + 1)

	var center_pos := TrackMath.points[idx]
	var norm := TrackMath.normals[idx]
	var half_w := TrackMath.widths[idx] / 2.0

	var fence_offset := fence_offset_right if side > 0.0 else fence_offset_left

	# Compute distance past fence
	var dist_hash := posmod(hash((step_id * 314159) ^ (tree_index * 888) ^ int(side * 555)), 100000)
	var dist_ratio := (dist_hash % 1001) / 1000.0
	
	var min_safe_dist := half_w + fence_offset + tree_min_offset
	var max_safe_dist := half_w + fence_offset + tree_max_offset
	var final_offset:float = lerp(min_safe_dist, max_safe_dist, dist_ratio)

	var target_pos := center_pos + norm * (final_offset * side)

	# --- FAST DISTANCE CHECK AGAINST ALREADY SPAWNED TREES ---
	for existing_pos in spawned_positions:
		# Use squared distance check to avoid heavy square root calculations
		if target_pos.distance_squared_to(existing_pos) < min_dist_sq:
			return # Skip this tree because another tree is too close!

	# Position is valid, record it
	spawned_positions.append(target_pos)

	# Select Tree Scene
	var type_hash := posmod(hash((step_id * 271828) ^ (tree_index * 777) ^ int(side * 333)), 100000)
	var chosen_tree_scene: PackedScene = tree_scenes[type_hash % tree_scenes.size()]

	var tree := chosen_tree_scene.instantiate() as Node3D
	add_child(tree)
	tree.global_position = target_pos

	# Random Y-Rotation
	var rot_hash := posmod(hash((step_id * 141421) ^ (tree_index * 999) ^ int(side * 111)), 3600)
	tree.rotate_y(deg_to_rad(rot_hash / 10.0))

	# Random Scale
	var scale_hash := posmod(hash((step_id * 173205) ^ (tree_index * 444) ^ int(side * 222)), 1000)
	var scale_factor:float = lerp(tree_min_scale, tree_max_scale, scale_hash 
	 /1000.0)
	tree.scale = Vector3(scale_factor, scale_factor, scale_factor)


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
