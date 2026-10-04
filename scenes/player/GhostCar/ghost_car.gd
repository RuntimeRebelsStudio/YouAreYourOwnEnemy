extends Node3D

@export var ghost_material: StandardMaterial3D

var ghost_data: Array[Transform3D] = []
var current_frame: int = 0
var is_playing: bool = false

func start_replay(data: Array[Transform3D], car_scene: PackedScene) -> void:
	ghost_data = data
	current_frame = 0
	
	if car_scene == null:
		print("6. FEHLER: car_scene ist NULL!")
		return
	
	# Altes aufräumen
	for child in get_children():
		child.queue_free()
	
	var model = car_scene.instantiate()
	add_child(model)
	
	await get_tree().process_frame
	
	_apply_ghost_overlay(model)
	
	is_playing = true
	show()
	
	
func _apply_ghost_overlay(node: Node) -> void:
	if node is MeshInstance3D:
		if ghost_material:
			node.material_overlay = ghost_material
		else:
			print("WARNUNG: ghost_material ist NULL!")
	elif node is SpotLight3D and ghost_material:
		node.light_color = ghost_material.emission
	for child in node.get_children():
		_apply_ghost_overlay(child)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_playing or ghost_data.is_empty():
		return
		
	if current_frame < ghost_data.size():
		global_transform = ghost_data[current_frame]
		current_frame += 1
	else:
		is_playing = false
		hide()
