extends CanvasLayer 


@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var round_label: Label = $MarginContainer/VBoxContainer/RoundLabel

var displayed_score: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	round_label.text = "Round: %d / %d" % [GameManager.current_round,
	GameManager.max_rounds]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		var player_car = get_tree().get_first_node_in_group("player")
		if player_car and "max_distance_score" in player_car:
			var target_score: float = player_car.max_distance_score
			
			displayed_score = lerp(displayed_score, target_score, 15.0 * delta)
			var current_m := roundi(displayed_score)
			

			if GameManager.last_score > 0:
				score_label.text = "Distance: %d m (To Beat: %d m)" % [current_m, roundi(GameManager.last_score)]
			else:
				score_label.text = "Distance: %d m" % current_m
