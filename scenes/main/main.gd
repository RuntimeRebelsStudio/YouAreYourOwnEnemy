extends Node3D

@export var ghost_car_scene: PackedScene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("--- DEBUG LEVEL READY ---")
	if GameManager.has_ghost_data():
		print("5. Spawne GhostCar Scene...")
		var ghost = ghost_car_scene.instantiate()
		add_child(ghost)
		ghost.start_replay(GameManager.last_ghost_data, GameManager.last_car_scene)
	else:
		print("5. KEINE Ghost-Daten im GameManager gefunden!")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
