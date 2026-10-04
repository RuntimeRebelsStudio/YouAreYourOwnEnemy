extends VehicleBody3D



@export var explosion_scene: PackedScene
@export var crash_sound: AudioStream

@export var car_model_scene: PackedScene
var current_car_model: CarModel


# Car stats
@export var engine_power: float = 200.0
@export var max_steer_angle: float = 0.5
@export var steer_speed: float = 3.0

var max_torque: float
var min_max_rpm: float
var absolute_max_rpm: float
var rpm_acceleration: float

var current_max_rpm: float

var y_wheel_offset = 0.08
var speed_print_timer: float = 0.0

# Car Death 
signal car_died
var is_dead: bool = false

# Ghost Mechanic
var current_run_data: Array[Transform3D] = []
var is_recording: bool = true

# --- GHOST SABOTAGE ---
var sabotage_timer: float = 0.0
var total_sabotage_duration: float = 1.0 # Speichert die Ursprungsdauer für die Prozentrechnung
var is_sabotaged: bool = false
var sabotage_material: StandardMaterial3D # Das rote Kraftfeld


# --- SLOW ZONE / PATCH LOGIC (Einfach) ---
var current_slow_factor: float = 1.0
# Score
var max_distance_score: float = 0.0
var current_track_index: int = 0



@onready var physics_wheels := {
	"fl": $Front_Left,
	"fr": $Front_Right,
	"bl": $Back_Left,
	"br": $Back_Right,
}

var visual_wheels := {}

func _ready() -> void:
	
	add_to_group("player")
	
	var selected_model_scene := GameManager.get_selected_car_scene()
	
	if selected_model_scene:
		car_model_scene = selected_model_scene
	
	if not car_model_scene:
		push_error("No CarModel scene available for PlayerCar!")
		return
	
		
	current_car_model = car_model_scene.instantiate() as CarModel
	if current_car_model.get_parent() == null:
		add_child(current_car_model)
	
	# Schwerpunkt und Gewicht übernehmen
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = current_car_model.custom_center_of_mass
	mass = current_car_model.vehicle_mass
	
	# Performance-Werte übernehmen ---
	max_torque = current_car_model.max_torque
	min_max_rpm = current_car_model.min_max_rpm
	absolute_max_rpm = current_car_model.absolute_max_rpm
	rpm_acceleration = current_car_model.rpm_acceleration
	
	# WICHTIG: Die aktuelle Drehzahl auf den individuellen Startwert des Autos setzen
	current_max_rpm = min_max_rpm
	
	visual_wheels = {
		"fl": current_car_model.wheel_fl,
		"fr": current_car_model.wheel_fr,
		"bl": current_car_model.wheel_bl,
		"br": current_car_model.wheel_br,
	}

	# 2. ALLE Kollisionen (egal ob eine oder mehrere) übernehmen
	for col in current_car_model.collision_shapes:
		if col != null:
			col.reparent(self, true)
	
	

	# Physik-Räder an die Position der visuellen Räder setzen
	for key in physics_wheels:
		var p: VehicleWheel3D = physics_wheels[key]
		var v: MeshInstance3D = visual_wheels[key]

		var new_pos = to_local(v.global_position)
		new_pos.y += y_wheel_offset
		
		p.position = new_pos
		p.wheel_radius = current_car_model.wheel_radius
		
		
		
		
		remove_child(p)
		add_child(p)
		
		v.reparent(p, true)
		
		v.position = Vector3.ZERO
		v.rotation = Vector3.ZERO
	
	# --- VISUELLES SABOTAGE-MATERIAL ERSTELLEN ---
	sabotage_material = StandardMaterial3D.new()
	sabotage_material.albedo_color = Color(1.0, 0.1, 0.1, 0.8) # Kräftiges Rot, 80% Deckkraft
	sabotage_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sabotage_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Leuchtet ohne Schatten

# --- SLOW ZONE STEUERUNG (Direkt ohne Zähler) ---
func enter_slow_zone(factor: float) -> void:
	current_slow_factor = factor

func exit_slow_zone() -> void:
	current_slow_factor = 1.0

func hit_by_ghost_pulse(duration: float) -> void:
	is_sabotaged = true
	sabotage_timer = duration
	total_sabotage_duration = duration # Sichern für den Fade-Out
	
	# Legt das rote Material über die normale Textur des Autos
	if current_car_model and current_car_model.body_mesh:
		current_car_model.body_mesh.material_overlay = sabotage_material


func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	
	if is_dead:
		return


	# O(1) Abfrage des Fortschritts:
	var track_data := TrackMath.get_track_progress_s_optimized(global_position, current_track_index)
	current_track_index = track_data.index
	var current_s: float = track_data.s
	
	# Score-Highmark setzen
	if current_s > max_distance_score:
		max_distance_score = current_s

	# Record position for ghost mechanic	
	if is_recording:
		current_run_data.append(global_transform)
	
	# --- SABOTAGE TIMER ---
	if is_sabotaged:
		sabotage_timer -= delta
		
		# Visueller Countdown: Das Rot verblasst fließend
		var remaining_percent := sabotage_timer / total_sabotage_duration
		# Multipliziert mit 0.8, da wir bei max. 60% Deckkraft starten
		sabotage_material.albedo_color.a = remaining_percent * 0.6
		
		if sabotage_timer <= 0.0:
			is_sabotaged = false
			
			# Visuellen Effekt entfernen, Steuerung ist wieder frei
			if current_car_model and current_car_model.body_mesh:
				current_car_model.body_mesh.material_overlay = null


	# --- LENKUNG ---
	# Aktuelle Geschwindigkeit in Metern pro Sekunde
	var current_speed := linear_velocity.length()
	var speed_factor : float = clamp(current_speed / 30.0, 0.0, 1.0)
	var dynamic_max_steer : float = lerp(max_steer_angle, 0.1, speed_factor)

	var steer_target := Input.get_axis("right", "left") * dynamic_max_steer
	
	# WENN SABOTIERT: Lenkung invertieren und leicht schwächen
	if is_sabotaged:
		steer_target = -steer_target * 0.8
		
	steering = move_toward(steering, steer_target, steer_speed * delta)

	# Auto fährt dauerhaft nach vorne
	var accel := 1.0
	
	# Max-RPM kontinuierlich mit der Zeit erhöhen bis zum Limit
	current_max_rpm = move_toward(current_max_rpm, absolute_max_rpm, rpm_acceleration * delta)
	
	# --- DREHMOMENT ---
	var effective_torque := max_torque * current_slow_factor
	
	# WENN SABOTIERT: Motorleistung bricht extrem ein
	if is_sabotaged:
		effective_torque *= 0.3 
		
	var effective_max_rpm := current_max_rpm * current_slow_factor

	var rpmBL = abs($Back_Left.get_rpm())
	var rpmBR = abs($Back_Right.get_rpm())
	
	# max(0.0, ...) verhindert, dass der Motor rückwärts zieht, wenn die RPM plötzlich sinkt
	var force_multiplier_BL = max(0.0, 1.0 - rpmBL / effective_max_rpm)
	var force_multiplier_BR = max(0.0, 1.0 - rpmBR / effective_max_rpm)
	
	$Back_Left.engine_force = accel * effective_torque * force_multiplier_BL
	$Back_Right.engine_force = accel * effective_torque * force_multiplier_BR
	
	# --- NEU: Intelligenter Gras-Widerstand ---
	if current_slow_factor < 1.0:
		# Prüfen, ob wir noch schneller sind als die erlaubte Gras-Geschwindigkeit
		if rpmBL > effective_max_rpm or rpmBR > effective_max_rpm:
			linear_damp = 1.5 # Stark abbremsen (simuliert tiefen Matsch)
		else:
			linear_damp = 0.0 # Zielgeschwindigkeit erreicht -> Widerstand lösen, damit das Auto weiterrollen kann
	else:
		linear_damp = 0.0
	
		
	# Timer mit delta hochzählen und nur alle 1,0 Sekunden ausgeben
	speed_print_timer += delta
	if speed_print_timer >= 1.0:
		speed_print_timer = 0.0
		var speed_kmh := linear_velocity.length() * 3.6
		print("Geschwindigkeit: ", round(speed_kmh), " km/h")


func _process(_delta: float) -> void:
	pass
	
	
func die() -> void:
	if is_dead:
		return
		
	is_dead = true
	is_recording = false
	
	engine_force = 0.0
	brake = 100.0
	steering = 0.0
	
	# Send Signal
	car_died.emit()
	
	if explosion_scene:
		var explosion = explosion_scene.instantiate() as Node3D
		
		# Add to current level root so it isn't deleted if the car is freed
		get_tree().current_scene.add_child(explosion)
		
		# Place at car's global position
		explosion.global_position = global_position

	if crash_sound:
		var p := AudioStreamPlayer3D.new()
		get_tree().current_scene.add_child(p)
		p.global_position = global_position
		p.stream = crash_sound
		p.play()
		p.finished.connect(p.queue_free)

	await get_tree().create_timer(1.5).timeout
		
	GameManager.trigger_player_death(max_distance_score, current_run_data,
	 car_model_scene)
