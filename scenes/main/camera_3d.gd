extends Camera3D

@export var car: Node3D 
@export var offset: Vector3 = Vector3(-5, 10, 10) 
@export var follow_speed: float = 15.0
@export var track_smooth_speed: float = 12.0 # Wie weich der Streckenverlauf nachgezogen wird

var smoothed_s: float = -1.0

func _process(delta: float) -> void:
	if not car:
		return
	
	# 1. Rohen Strecken-Index vom Auto holen
	var raw_player_s := TrackMath.get_closest_s(car.global_position)
	
	# Beim Start einmalig initialisieren, damit die Kamera nicht von 0 herankriecht
	if smoothed_s < 0.0:
		smoothed_s = raw_player_s
	
	# 2. Den Streckenwert selbst glätten (verhindert das nervige Springen/Zucken)
	smoothed_s = lerp(smoothed_s, raw_player_s, track_smooth_speed * delta)
	
	# 3. Mit dem geglätteten Wert arbeiten
	var float_idx := smoothed_s / TrackMath.step_size
	var i1 := int(floor(float_idx))
	var i2 := i1 + 1
	var frac := float_idx - i1
	
	TrackMath.ensure_calculated_up_to(i2 + 2)
	if i2 >= TrackMath.points.size():
		return
	
	var track_tangent = TrackMath.tangents[i1].lerp(TrackMath.tangents[i2], frac).normalized()
	var track_normal = TrackMath.normals[i1].lerp(TrackMath.normals[i2], frac).normalized()
	
	var forward = track_tangent
	var right = track_normal
	var up = Vector3.UP
	var track_basis = Basis(right, up, -forward).orthonormalized()
	
	var target_pos = car.global_position + track_basis * offset
	
	# 4. Kamera-Position weich nachziehen
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# 5. Blick permanent auf das Auto richten
	look_at(car.global_position + Vector3(0, 1, 0), Vector3.UP)
