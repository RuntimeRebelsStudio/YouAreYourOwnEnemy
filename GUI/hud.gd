extends CanvasLayer 


@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var round_label: Label = $MarginContainer/VBoxContainer/RoundLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	round_label.text = "Round: %d / %d" % [GameManager.current_round,
	GameManager.max_rounds]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		var player_car = get_tree().get_first_node_in_group("player")
		if player_car and "max_distance_score" in player_car:
			var current_m := int(player_car.max_distance_score)
			if GameManager.last_score > 0:
				score_label.text = "Distance: %d m (To Beat: %d m)" % [current_m,
				int(GameManager.last_score)]
			else:
				score_label.text = "Distance: %d m" % current_m
