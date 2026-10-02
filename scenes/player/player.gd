extends CharacterBody3D

@export var base_speed: float = 26.0         # Maximale Geschwindigkeit auf der Straße
@export var offroad_speed: float = 10.0      # Geschwindigkeit im Gras
@export var steer_speed: float = 2.0         # Drehgeschwindigkeit der Lenkung

@export_group("Beschleunigung & Bremsen")
@export var acceleration: float = 14.0       # Wie schnell das Auto auf Asphalt wieder Fahrt aufnimmt
@export var offroad_decel: float = 30.0      # Wie schnell das Gras das Auto abbremst

var speed: float = base_speed

func _physics_process(delta: float) -> void:
	# 1. Spieler-Eingabe (A/D oder Pfeiltasten)
	var steer_input := Input.get_axis("ui_right", "ui_left")
	rotate_y(steer_input * steer_speed * delta)

	# 2. Aktuelle Position relativ zur Streckenmitte prüfen
	var current_s := TrackMath.get_closest_s(global_position)
	var idx := int(current_s / TrackMath.step_size)
	TrackMath.ensure_calculated_up_to(idx + 1)

	var center_pos := TrackMath.points[idx]
	var half_width := TrackMath.widths[idx] / 2.0

	# Distanz rein auf der 2D-Ebene (X und Z) messen
	var player_pos_2d := Vector2(global_position.x, global_position.z)
	var center_pos_2d := Vector2(center_pos.x, center_pos.z)
	var dist_from_center := player_pos_2d.distance_to(center_pos_2d)

	# 3. Dynamische Geschwindigkeitsanpassung
	if dist_from_center > half_width:
		# OFFROAD: Schnell abbremsen auf Gras-Tempo
		speed = move_toward(speed, offroad_speed, offroad_decel * delta)
	else:
		# ZURÜCK AUF DER STRASSE: Wieder hochbeschleunigen auf Base-Speed
		speed = move_toward(speed, base_speed, acceleration * delta)

	# 4. Vorwärts-Bewegung ausführen
	var forward_dir := -transform.basis.z
	velocity = forward_dir * speed
	move_and_slide()

	# Visuelle Neigung der Karosserie beim Lenken
	var raw_steer := Input.get_axis("ui_left", "ui_right")
	rotation.z = lerp_angle(rotation.z, -raw_steer * deg_to_rad(6.0), 10.0 * delta)
