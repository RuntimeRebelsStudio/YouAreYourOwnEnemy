extends Camera3D

@export var car: VehicleBody3D 
@export var offset: Vector3 = Vector3(-5, 10, 10) 
@export var follow_speed: float = 12.0
@export var rotation_speed: float = 10.0
@export var track_smooth_speed: float = 10.0

var smoothed_s: float = -1.0

func _physics_process(delta: float) -> void:
	if not car:
		return
	
	# 1. Get smooth continuous track progress
	var raw_player_s := TrackMath.get_closest_s(car.global_position)
	
	if smoothed_s < 0.0:
		smoothed_s = raw_player_s
	
	# 2. Frame-rate independent exponential smoothing on track progress
	smoothed_s = lerp(smoothed_s, raw_player_s, 1.0 - exp(-track_smooth_speed * delta))
	
	# 3. Compute continuous track orientation & basis
	var float_idx := smoothed_s / float(TrackMath.step_size)
	var i1 := int(floor(float_idx))
	var i2 := i1 + 1
	var frac := float_idx - float(i1)
	
	TrackMath.ensure_calculated_up_to(i2 + 2)
	if i2 >= TrackMath.points.size():
		return
	
	var track_tangent = TrackMath.tangents[i1].lerp(TrackMath.tangents[i2], frac).normalized()
	var track_normal = TrackMath.normals[i1].lerp(TrackMath.normals[i2], frac).normalized()
	
	var forward = track_tangent
	var right = track_normal
	var up = Vector3.UP
	var track_basis = Basis(right, up, -forward).orthonormalized()
	
	# 4. Smooth camera position tracking
	var target_pos = car.global_position + track_basis * offset
	global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))
	
	# 5. Smooth camera orientation look-at (Eliminates distant blur/twitching)
	var target_look_at = car.global_position + Vector3(0, 1.2, 0)
	var target_transform = transform.looking_at(target_look_at, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, 1.0 - exp(-rotation_speed * delta))
