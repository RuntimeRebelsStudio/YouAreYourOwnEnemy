class_name Obstacle
extends StaticBody3D # Falls RocksLow ein StaticBody3D ist (ansonsten Node3D)

signal car_died

@export_group("Skalierung (Custom)")
@export var min_scale: float = 1.0
@export var max_scale: float = 3.0

# Greift auf den untergeordneten Node "HitBox" zu
@onready var hit_box: Area3D = $HitBox

func _ready() -> void:
	if hit_box:
		# Verbindet das body_entered Signal der HitBox
		hit_box.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is VehicleBody3D or body.is_in_group("player"):
		print("Auto berührt!")
		if body.has_method("die"):
			body.die()
