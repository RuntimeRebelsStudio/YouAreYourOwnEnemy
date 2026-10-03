extends StaticBody3D

@export var road_texture: Texture2D          # Hier ziehen wir die Textur im Inspector rein
@export var texture_repeat_distance: float = 4.0 # Alle wieviel Meter sich die Textur wiederholt
@export var obstacle_scenes: Array[PackedScene] = []

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
		
	# --- FBX-OBJEKTE SEED-BASIERT PLATZIEREN ---
	if obstacle_scenes.size() > 0:
		var check_step := 12.0
		var current_obs_s : float = ceil(start_s / check_step) * check_step

		while current_obs_s < end_s:
			var info := TrackMath.get_obstacle_info(current_obs_s, obstacle_scenes.size())
			if info.get("has_obstacle", false):
				var chosen_scene: PackedScene = obstacle_scenes[info.type_index]
				
				var rot_deg: float = info.get("rotation_deg", 0.0)
				var sc_ratio: float = info.get("scale_ratio", 0.5)
				
				# Spawnen mit Rotation und Skalierung
				spawn_obstacle_at(current_obs_s, info.offset_ratio, chosen_scene, rot_deg, sc_ratio)
				
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
	
	
	
func spawn_obstacle_at(s: float, offset_ratio: float, scene_to_spawn: PackedScene, extra_rotation_deg: float = 0.0, scale_ratio: float = 0.5) -> void:
	if not scene_to_spawn:
		return

	var idx := int(s / TrackMath.step_size)
	TrackMath.ensure_calculated_up_to(idx + 1)
	var current_width := TrackMath.widths[idx]
	
	var center_pos := TrackMath.points[idx]
	var norm := TrackMath.normals[idx]
	var half_w := TrackMath.widths[idx] / 2.0
	
	var final_scale_factor : float
	# Bei sehr engen Abschnitten (z. B. < 8m) Skalierung begrenzen und Kanten freihalten
	if current_width < 8.0:
		final_scale_factor = minf(final_scale_factor, 1.5) # Nicht riesig werden lassen
		offset_ratio = clampf(offset_ratio, -0.4, 0.4) # Eher mittig/kontrolliert halten
	var spawn_pos := center_pos + norm * (half_w * offset_ratio)

	var obs := scene_to_spawn.instantiate() as Node3D
	add_child(obs)
	obs.global_position = spawn_pos

	# 1. Ausrichtung an der Straße
	var tan := TrackMath.tangents[idx]
	if tan.length() > 0:
		obs.look_at(obs.global_position + tan, Vector3.UP)

	# 2. Lokale Rotation anwenden
	obs.rotate_object_local(Vector3.UP, deg_to_rad(extra_rotation_deg))

	# 3. INDIVIDUELLE SKALIERUNG BERECHNEN UND ANWENDEN
	var min_s: float = 1.0
	var max_s: float = 1.0

	# Prüft, ob das Objekt min_scale / max_scale Variablen definiert hat
	if "min_scale" in obs:
		min_s = obs.min_scale
	if "max_scale" in obs:
		max_s = obs.max_scale

	# Interpoliert individuell für dieses Objekt
	if current_width >= 8.0: final_scale_factor = lerp(min_s, max_s, scale_ratio)
		
	obs.scale = Vector3.ONE * final_scale_factor
