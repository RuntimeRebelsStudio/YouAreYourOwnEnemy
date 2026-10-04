extends Node3D

@export var available_cars: Array[PackedScene] = [] # Hier deine Car1.tscn, Car2.tscn etc. zuweisen
@export var background_music: AudioStream = preload("res://assets/audio/peaceful-running-loop-music-track-246473.mp3")

@onready var pivot: Node3D = $Pivot
@onready var car_name_label: Label = $UI/Control/TopPanel/CarNameLabel
@onready var left_button: Button = $UI/Control/BottomPanel/VBoxContainer/HBoxContainer/LeftButton
@onready var right_button: Button = $UI/Control/BottomPanel/VBoxContainer/HBoxContainer/RightButton
@onready var start_button: Button = $UI/Control/BottomPanel/VBoxContainer/PlayButton

var current_index: int = 0
var current_car_instance: Node3D = null
var rotate_speed: float = 0.5 # Kontinuierliche Drehung der Plattform

func _ready() -> void:
	GameManager.play_menu_music(background_music)
	# Falls Autos im GameManager hinterlegt sind, übernehmen
	if GameManager.available_cars.size() == 0 and available_cars.size() > 0:
		GameManager.available_cars = available_cars
		
	left_button.pressed.connect(_on_left_pressed)
	right_button.pressed.connect(_on_right_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	_load_car(current_index)

func _process(delta: float) -> void:
	# Lässt das Auto auf dem Drehteller langsam rotieren
	if pivot:
		pivot.rotate_y(rotate_speed * delta)

func _load_car(index: int) -> void:
	# Altes Modell entfernen
	if current_car_instance:
		current_car_instance.queue_free()
		
	var car_scene := GameManager.available_cars[index]
	current_car_instance = car_scene.instantiate() as Node3D
	
	# Kollisionen & Physik für die Vorschau deaktivieren
	current_car_instance.set_physics_process(false)
	current_car_instance.set_process(false)
	
	pivot.add_child(current_car_instance)
	
	_center_node_on_pivot(current_car_instance)
	
	# Name anzeigen
	car_name_label.text = current_car_instance.name

func _on_left_pressed() -> void:
	current_index = (current_index - 1 + GameManager.available_cars.size()) % GameManager.available_cars.size()
	_load_car(current_index)

func _on_right_pressed() -> void:
	current_index = (current_index + 1) % GameManager.available_cars.size()
	_load_car(current_index)

func _on_start_pressed() -> void:
	GameManager.selected_car_index = current_index
	GameManager.reset_game() # Setzt Runden & Zustand auf Start zurück
	GameManager.duck_menu_music()
	
	# Wechselt zur eigentlichen Rennstrecke
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	
	
# Berechnet die Gesamt-Bounding Box aller Meshes und zentriert das Objekt
func _center_node_on_pivot(node: Node3D) -> void:
	var combined_aabb := AABB()
	var has_mesh := false
	
	# Sucht alle MeshInstance3D Kinder rekursiv ab
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	
	for mesh in meshes:
		if mesh is MeshInstance3D and mesh.mesh:
			# Transformiert die AABB des Meshes in den lokalen Raum der Auto-Root Node
			var local_aabb: AABB = mesh.get_aabb()
			var mesh_transform: Transform3D = node.global_transform.affine_inverse() * mesh.global_transform
			var transformed_aabb := mesh_transform * local_aabb
			
			if not has_mesh:
				combined_aabb = transformed_aabb
				has_mesh = true
			else:
				combined_aabb = combined_aabb.merge(transformed_aabb)
				
	if has_mesh:
		# Berechnet das Zentrum der Bounding Box
		var center := combined_aabb.get_center()
		
		# Verschiebt das Auto so, dass sein geometrisches Zentrum bei Vector3.ZERO liegt
		# (Nur X und Z zentrieren, damit die Räder nicht im Boden versinken)
		node.position = -Vector3(center.x, 0.0, center.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		pivot.rotate_y(event.relative.x * 0.005)
