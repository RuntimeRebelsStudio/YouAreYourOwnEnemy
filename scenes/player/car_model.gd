class_name CarModel extends Area3D

# Visuals
@export var body_mesh: MeshInstance3D

# Physics & Wheels
@export var collision_shapes: Array[CollisionShape3D]

@export var wheel_fl: MeshInstance3D
@export var wheel_fr: MeshInstance3D
@export var wheel_bl: MeshInstance3D
@export var wheel_br: MeshInstance3D
@export var wheel_radius: float = 0.18
@export var rest_length: float = 0.5

# Eigener Schwerpunkt für dieses Auto ---
@export var custom_center_of_mass: Vector3 = Vector3(0, -0.1, 0.3)

#Individuelles Gewicht für jedes Auto (Standardwert z.B. 1200 kg)
@export var vehicle_mass: float = 1200.0

# Performance Stats für jedes Auto ---
@export_group("Performance")
@export var max_torque: float = 3500.0       # Beschleunigungskraft (Motorstärke)
@export var min_max_rpm: float = 300.0       # Start-Höchstgeschwindigkeit
@export var absolute_max_rpm: float = 1000.0 # Absolute Top-Geschwindigkeit
@export var rpm_acceleration: float = 50.0   # Wie schnell die Höchstgeschwindigkeit steigt
@export_group("Emergency Beacons")
@export var beacon_a: Light3D
@export var beacon_b: Light3D
@export var beacon_enabled := false
@export var blink_speed := 4.0 # flips per second

var _t := 0.0
func _process(delta):
	if not beacon_enabled or beacon_a == null or beacon_b == null:
		return
	_t += delta * blink_speed
	var phase := fmod(_t, 1.0) < 0.5
	beacon_a.visible = phase
	beacon_b.visible = not phase

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
