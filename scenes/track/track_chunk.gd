extends StaticBody3D

@export var road_texture: Texture2D          # Hier ziehen wir die Textur im Inspector rein
@export var texture_repeat_distance: float = 4.0 # Alle wieviel Meter sich die Textur wiederholt
@export var obstacle_scenes: Array[PackedScene] = [] # Für 3D-Hindernisse (Steine, Bäume)
@export var patch_scenes: Array[PackedScene] = []    # Für Bodenflächen (Gras, Öl, Decals)

@onready var mesh_instance: MeshInstance3D = $MeshInstance
@onready var collision_shape: CollisionShape3D = $CollisionShape

var end_s: float = 0.0

func generate_chunk(start_s: float, length: float) -> void:
	end_s = start_s + length

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Material für die Straße vorbereiten
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	if road_texture:
		mat.albedo_texture = road_texture
		# Verhindert Verschwimmen bei Schrägansicht (Mipmaps)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		mat.albedo_color = Color(0.25, 0.25, 0.3) # Fallback-Farbe

	st.set_material(mat)

	var step := TrackMath.step_size
	var start_idx := int(start_s / step)
	var count := int(length / step)
	var end_idx := start_idx + count

	TrackMath.ensure_calculated_up_to(end_idx + 1)

	for i in range(start_idx, end_idx):
		var s1 := i * step
		var s2 := (i + 1) * step

		# V-Koordinaten basierend auf der echten Distanz in Metern
		var v1 := s1 / texture_repeat_distance
		var v2 := s2 / texture_repeat_distance

		var p1 := TrackMath.points[i]
		var p2 := TrackMath.points[i + 1]

		var norm1 := TrackMath.normals[i]
		var norm2 := TrackMath.normals[i + 1]

		var w1 := TrackMath.widths[i] / 2.0
		var w2 := TrackMath.widths[i + 1] / 2.0

		var p_left1 := p1 - norm1 * w1
		var p_right1 := p1 + norm1 * w1

		var p_left2 := p2 - norm2 * w2
		var p_right2 := p2 + norm2 * w2

		# UVs für die 4 Ecken festlegen:
		# (U=0 -> Links, U=1 -> Rechts, V = Meter-Fortschritt)
		var texture_width_meters: float = 8.0

		var uv_l1 := Vector2(0.5 - (w1 / texture_width_meters), v1)
		var uv_r1 := Vector2(0.5 + (w1 / texture_width_meters), v1)

		var uv_l2 := Vector2(0.5 - (w2 / texture_width_meters), v2)
		var uv_r2 := Vector2(0.5 + (w2 / texture_width_meters), v2)

		# Fahrbahn mit UV-Koordinaten generieren
		add_quad_with_uv(st, p_left1, uv_l1, p_left2, uv_l2, p_right1, uv_r1, p_right2, uv_r2)

	st.generate_normals()
	var array_mesh := st.commit()
	mesh_instance.mesh = array_mesh

	if array_mesh.get_faces().size() > 0:
		collision_shape.shape = array_mesh.create_trimesh_shape()
	
	
	
	# =========================================================
	# 1. BODENFLÄCHEN SPAWNEN (Gras, Öllachen, Decals)
	# =========================================================
	if patch_scenes.size() > 0:
		var patch_step := 10.0 # Alle 10 Meter auf Gras/Öl prüfen
		var current_patch_s : float = ceil(start_s / patch_step) * patch_step

		while current_patch_s < end_s:
			var p_info := TrackMath.get_patch_info(current_patch_s, patch_scenes.size())
			if p_info.get("has_patch", false):
				var chosen_patch: PackedScene = patch_scenes[p_info.type_index]
				
				spawn_obstacle_at(
					current_patch_s, 
					p_info.offset_ratio, 
					chosen_patch, 
					p_info.rotation_deg, 
					p_info.scale_ratio_x, 
					p_info.scale_ratio_z
				)
			current_patch_s += patch_step	
	
	# =========================================================
	# 2. 3D-HINDERNISSE SPAWNEN (Steine, Bäume, Kisten)
	# =========================================================
	if obstacle_scenes.size() > 0:
		var check_step := 12.0 # Alle 12 Meter auf 3D-Hindernisse prüfen
		var current_obs_s : float = ceil(start_s / check_step) * check_step

		while current_obs_s < end_s:
			var info := TrackMath.get_obstacle_info(current_obs_s, obstacle_scenes.size())
			if info.get("has_obstacle", false):
				var chosen_scene: PackedScene = obstacle_scenes[info.type_index]
				
				spawn_obstacle_at(
					current_obs_s, 
					info.offset_ratio, 
					chosen_scene, 
					info.rotation_deg, 
					info.scale_ratio_x, 
					info.scale_ratio_z
				)
			current_obs_s += check_step

func add_quad_with_uv(st: SurfaceTool, 
		p1: Vector3, uv1: Vector2, 
		p2: Vector3, uv2: Vector2, 
		p3: Vector3, uv3: Vector2, 
		p4: Vector3, uv4: Vector2) -> void:
	
	# Dreieck 1 (p1 -> p2 -> p3)
	st.set_uv(uv1); st.add_vertex(p1)
	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv3); st.add_vertex(p3)

	# Dreieck 2 (p2 -> p4 -> p3)
	st.set_uv(uv2); st.add_vertex(p2)
	st.set_uv(uv4); st.add_vertex(p4)
	st.set_uv(uv3); st.add_vertex(p3)
	
	
	
func spawn_obstacle_at(s: float, offset_ratio: float, scene_to_spawn: PackedScene, extra_rotation_deg: float = 0.0, scale_ratio_x: float = 0.5, scale_ratio_z: float = 0.5) -> void:
	if not scene_to_spawn:
		return

	var idx := int(s / TrackMath.step_size)
	TrackMath.ensure_calculated_up_to(idx + 1)

	var center_pos := TrackMath.points[idx]
	var norm := TrackMath.normals[idx]
	var half_w := TrackMath.widths[idx] / 2.0

	var spawn_pos := center_pos + norm * (half_w * offset_ratio)

	var obs := scene_to_spawn.instantiate() as Node3D
	add_child(obs)
	obs.global_position = spawn_pos

	# 1. Ausrichtung an der Fahrtrichtung der Straße
	var tan := TrackMath.tangents[idx]
	if tan.length() > 0:
		obs.look_at(obs.global_position + tan, Vector3.UP)

	# 2. Lokale Rotation
	obs.rotate_object_local(Vector3.UP, deg_to_rad(extra_rotation_deg))

	# 3. MIN/MAX SKALIERUNG BERECHNEN
	var min_s: float = 1.0
	var max_s: float = 1.0

	if "min_scale" in obs:
		min_s = obs.min_scale
	if "max_scale" in obs:
		max_s = obs.max_scale

	# 4. SKALIERUNG ZUWEISEN (Unterscheidung Patch vs Obstacle)
	if obs is GrassPatch:
		# Patches (Gras, Öl) dürfen in Länge und Breite unabhängig verzerrt werden
		var final_scale_x : float = lerp(min_s, max_s, scale_ratio_x)
		var final_scale_z : float = lerp(min_s, max_s, scale_ratio_z)
		
		# Y bleibt 1.0, damit sie flach auf dem Boden liegen
		obs.scale = Vector3(final_scale_x, 1.0, final_scale_z)
	else:
		# Obstacles (Bäume, Steine) werden in alle 3 Richtungen exakt gleichmäßig skaliert.
		# Wir bilden den Mittelwert aus X- und Z-Ratio für eine einzige, organische Größe.
		var uniform_ratio : float = (scale_ratio_x + scale_ratio_z) / 2.0
		var uniform_scale : float = lerp(min_s, max_s, uniform_ratio)
		
		obs.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)
