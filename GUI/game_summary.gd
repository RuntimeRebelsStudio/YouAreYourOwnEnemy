class_name GameSummary
extends Control

@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var round_label: Label = $Panel/VBoxContainer/RoundLabel
@onready var play_again_button: Button = $Panel/VBoxContainer/PlayAgainButton
@onready var car_select_button: Button = $Panel/VBoxContainer/CarSelectButton

func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	car_select_button.pressed.connect(_on_car_select_pressed)
	
	# Display final stats from GameManager
	if score_label:
		score_label.text = "Best Score: " + str(snappedf(GameManager.last_score, 0.01))
	if round_label:
		round_label.text = "Rounds Completed: " + str(GameManager.current_round - 1) + " / " + str(GameManager.max_rounds)

func _on_play_again_pressed() -> void:
	# Reset game state and seed, then restart current track scene
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_car_select_pressed() -> void:
	# Reset game state and seed, then jump to CarSelect
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://GUI/CarSelect.tscn")
