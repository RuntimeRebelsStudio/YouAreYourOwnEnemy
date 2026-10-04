extends Node3D

@export var ghost_material: StandardMaterial3D

@export_group("Ghost Sabotage")
@export var first_pulse_delay: float = 1.5
@export var min_pulse_interval: float = 6.0   
@export var max_pulse_interval: float = 12.0  
@export var pulse_radius: float = 15.0        
@export var min_sabotage_duration: float = 1.0
@export var max_sabotage_duration: float = 3.0

var ghost_data: Array[Transform3D] = []
var current_frame: int = 0
var is_playing: bool = false

# Puls-Variablen
var pulse_timer: float = 0.0
var current_pulse_target: float = 10.0 # Speichert den aktuell ausgewürfelten Ziel-Wert
var pulse_area: Area3D

func _ready() -> void:
	_setup_pulse_area()

func _setup_pulse_area() -> void:
	# Erstellt automatisch die Area3D für die Reichweiten-Abfrage
	pulse_area = Area3D.new()
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = pulse_radius
	collision.shape = sphere
	
	pulse_area.add_child(collision)
	add_child(pulse_area)

func start_replay(data: Array[Transform3D], car_scene: PackedScene) -> void:
	ghost_data = data
	current_frame = 0
	
	# Timer resetten und direkt den ERSTEN Zufallswert für den Puls auswürfeln
	pulse_timer = 0.0
	current_pulse_target = first_pulse_delay
	
	if car_scene == null:
		print("6. FEHLER: car_scene ist NULL!")
		return
	
	# Altes aufräumen (Area3D ignorieren)
	for child in get_children():
		if child != pulse_area:
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
		
	for child in node.get_children():
		_apply_ghost_overlay(child)

func _physics_process(delta: float) -> void:
	if not is_playing or ghost_data.is_empty():
		return
		
	if current_frame < ghost_data.size():
		global_transform = ghost_data[current_frame]
		current_frame += 1
		
		# Zufalls-Puls-Logik ausführen
		pulse_timer += delta
		if pulse_timer >= current_pulse_target:
			pulse_timer = 0.0
			# NÄCHSTEN Zufallswert für das Intervall auswürfeln
			current_pulse_target = randf_range(min_pulse_interval, max_pulse_interval)
			_fire_pulse()
	else:
		is_playing = false
		hide()

func _fire_pulse() -> void:
	# Würfelt die Bestrafungs-Dauer FÜR DIESEN EINEN PULS aus (z.B. 1.7 Sekunden)
	var random_duration := randf_range(min_sabotage_duration, max_sabotage_duration)
	
	print("Geist feuert Schockwelle ab! Nächster Puls in: ", round(current_pulse_target), "s. Dauer: ", snapped(random_duration, 0.1), "s")
	
	_spawn_visual_pulse()
	
	# Holt alle Physik-Objekte, die aktuell im 15-Meter-Radius sind
	var overlapping_bodies = pulse_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.is_in_group("player") and body.has_method("hit_by_ghost_pulse"):
			# Übergibt die zufällige Dauer an den Spieler
			body.hit_by_ghost_pulse(random_duration)
			
			
func _spawn_visual_pulse() -> void:
	# 1. Kugel-Mesh erstellen (Standard-Radius ist 0.5, wir skalieren es gleich)
	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	mesh_instance.mesh = sphere_mesh
	
	# 2. Material erstellen (Rot, halbtransparent, leuchtend)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.6) # Kräftiges Rot, 60% Sichtbarkeit
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Keine Schatten, wirkt wie Energie
	mesh_instance.material_override = mat
	
	# Dem Geist als Kind hinzufügen
	add_child(mesh_instance)
	mesh_instance.global_position = global_position
	
	# 3. Tween-Animation starten
	var tween := create_tween()
	
	# Skaliert die Kugel in 0.4 Sekunden auf den vollen Radius
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * pulse_radius, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Lässt die Kugel gleichzeitig (parallel) unsichtbar werden
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	
	# Löscht die Kugel aus dem Speicher, sobald die Animation fertig ist
	tween.tween_callback(mesh_instance.queue_free)
