class_name CarModel extends Area3D

# Visuals
@export var body_mesh: MeshInstance3D

# Physics & Wheels
@export var body_collision: CollisionShape3D
@export var wheel_fl: MeshInstance3D
@export var wheel_fr: MeshInstance3D
@export var wheel_bl: MeshInstance3D
@export var wheel_br: MeshInstance3D
@export var wheel_radius: float = 0.5# Passe das an die tatsächliche Größe an
@export var rest_length: float = 0.5# Passe das an die tatsächliche Größe an




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
