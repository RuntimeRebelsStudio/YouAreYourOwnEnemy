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


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
