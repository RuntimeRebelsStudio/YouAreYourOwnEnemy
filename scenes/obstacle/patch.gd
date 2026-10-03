class_name GrassPatch
extends Area3D

@export_group("Geschwindigkeit")
@export var slow_factor: float = 0.4 # Spieler hat nur noch 40% Leistung im Gras

@export_group("Skalierung")
@export var min_scale: float = 3.0
@export var max_scale: float = 10.0

func _ready() -> void:
	# Signale für Betreten und Verlassen verbinden
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is VehicleBody3D or body.is_in_group("player"):
		print("Entered Zone")
		if body.has_method("enter_slow_zone"):
			body.enter_slow_zone(slow_factor)

func _on_body_exited(body: Node3D) -> void:
	if body is VehicleBody3D or body.is_in_group("player"):
		print("Left Zone")
		if body.has_method("exit_slow_zone"):
			body.exit_slow_zone()
