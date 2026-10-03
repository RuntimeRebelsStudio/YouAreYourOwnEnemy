extends Node3D

@export var ghost_car_scene: PackedScene
@onready var spawn_point: Node3D = $SpawnPoint
@onready var car_base_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameManager.current_state == GameManager.GameState.READY and	GameManager.last_car_scene == null:
		if GameManager.get_selected_car_scene() == null:
			get_tree().change_scene_to_file("res://GUI/CarSelect.tscn")
			return
	
	GameManager.start_new_run()

	if car_base_scene:
		var player = car_base_scene.instantiate() as Node3D
		add_child(player)
		if spawn_point:
			player.global_transform = spawn_point.global_transform

	
	if GameManager.current_state == GameManager.GameState.GAME_SUMMARY:
		print("TODO: Show Game Summary")
		# TODO Show Game Summary UI
		return
	
	if GameManager.has_ghost_data():
		var ghost = ghost_car_scene.instantiate()
		add_child(ghost)
		ghost.start_replay(GameManager.last_ghost_data, GameManager.last_car_scene)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
