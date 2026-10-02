extends StaticBody3D

@export var road_texture: Texture2D          # Hier ziehen wir die Textur im Inspector rein
@export var texture_repeat_distance: float = 4.0 # Alle wieviel Meter sich die Textur wiederholt

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
