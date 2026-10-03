extends Node


@export var available_cars: Array[PackedScene] = []
var selected_car_index: int = 0

enum GameState { READY, PLAYING, ROUND_OVER, GAME_SUMMARY}

var current_state: GameState = GameState.READY
var current_round: int = 1
@export var max_rounds: int = 5

var last_score: float = 0
var current_score: float = 0

var last_car_scene: PackedScene = null
var last_ghost_data: Array[Transform3D] = []

func start_new_run() -> void:
	if current_round <= max_rounds and current_state != GameState.GAME_SUMMARY:
		current_state = GameState.PLAYING
	else: 
		current_state = GameState.GAME_SUMMARY

func get_selected_car_scene() -> PackedScene:
	if available_cars.size() > 0:
		return available_cars[selected_car_index]
	return last_car_scene

# called by car on death
func trigger_player_death(run_score: float, run_ghost_data:
Array[Transform3D], car_scene: PackedScene) -> void:
	if current_state == GameState.ROUND_OVER or current_state == GameState.GAME_SUMMARY:
		return
		
	
	if run_score > last_score:
		last_score = run_score
		save_ghost_data(run_ghost_data, car_scene)
		
		current_round += 1
		
		if current_round > max_rounds:
			current_state = GameState.GAME_SUMMARY
			respawn_level()
		else:
			current_state = GameState.ROUND_OVER
			respawn_level()
	else:
		# Didn't improve the round
		current_state = GameState.GAME_SUMMARY
		respawn_level()

func save_ghost_data(data: Array[Transform3D], car_scene: PackedScene) -> void:
	last_ghost_data = data.duplicate()
	last_car_scene = car_scene
	
func has_ghost_data() -> bool:
	var has_data = last_ghost_data.size() > 0 and last_car_scene != null
	return has_data
	

func respawn_level() -> void:
	get_tree().call_deferred("reload_current_scene")
	
	
func reset_game() -> void:
	current_round = 1
	last_score = 0.0
	last_ghost_data.clear()
	last_car_scene = null
	current_state = GameState.READY
	
