extends Camera3D

@export var car: VehicleBody3D
@export var offset: Vector3 = Vector3(0.0, 3.0, -6.0) # Abstand zum Auto
@export var follow_speed: float = 10.0

func _physics_process(delta: float) -> void:
	if not car:
		return
	
	# Zielposition basierend auf der Autoposition berechnen
	var target_position = car.global_position + car.global_transform.basis * offset
	
	# Weich zur Zielposition interpolieren (Camera Lag / Smooth Follow)
	global_position = global_position.lerp(target_position, follow_speed * delta)
	
	# Kamera schaut immer auf das Auto, rollt sich aber nicht mit
	look_at(car.global_position + Vector3.UP * 1.5, Vector3.UP)
