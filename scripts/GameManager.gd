extends Node


var last_car_scene: PackedScene = null
var last_ghost_data: Array[Transform3D] = []


func save_ghost_data(data: Array[Transform3D], car_scene: PackedScene) -> void:
	last_ghost_data = data.duplicate()
	last_car_scene = car_scene
	print("3. GameManager hat Daten gespeichert. Anzahl: ", last_ghost_data.size())
	
func has_ghost_data() -> bool:
	var has_data = last_ghost_data.size() > 0 and last_car_scene != null
	print("4. GameManager.has_ghost_data() Abfrage ist: ", has_data)
	return has_data
	

func respawn_level() -> void:
	get_tree().call_deferred("reload_current_scene")
	
