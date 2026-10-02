extends Camera3D

@export var target: Node3D                      # Das Auto (wird automatisch erkannt)
@export var distance: float = 6.5               # Abstand hinter dem Auto
@export var height: float = 3.5                 # Höhe über dem Auto
@export var look_at_height: float = 1.2         # Blickpunkt-Höhe am Auto

@export_group("Dämpfung / Glättung")
@export var follow_speed: float = 10.0          # Wie schnell die Kamera der Position folgt
@export var rotation_speed: float = 4.5         # Wie sanft die Kamera Drehungen ausgleicht (NIEDRIGER = WENIGER RUCKELN)

var smoothed_forward := Vector3.FORWARD

func _ready() -> void:
	# Wichtig: Trennt die Kamera von der starren Rotation des Auto-Nodes!
	top_level = true
	
	if not target and get_parent() is Node3D:
		target = get_parent() as Node3D
		
	if target:
		smoothed_forward = -target.global_transform.basis.z

func _physics_process(delta: float) -> void:
	if not target:
		return

	# 1. Blickrichtung des Autos sanft dämpfen (Verhindert Ruckeln bei kurzen Taps)
	var target_forward := -target.global_transform.basis.z
	smoothed_forward = smoothed_forward.lerp(target_forward, rotation_speed * delta).normalized()

	# 2. Wunschposition der Kamera hinter dem Auto berechnen
	var target_pos := target.global_position - smoothed_forward * distance + Vector3(0, height, 0)

	# 3. Kamera-Position weich anziehen
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# 4. Kamera geschmeidig auf das Auto ausrichten
	var look_target := target.global_position + Vector3(0, look_at_height, 0)
	look_at(look_target, Vector3.UP)
