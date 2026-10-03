extends VehicleBody3D

@export var explosion_scene: PackedScene

@export var car_model_scene: PackedScene
var current_car_model: CarModel


# Car stats
@export var engine_power: float = 200.0
@export var max_steer_angle: float = 0.5
@export var steer_speed: float = 3.0
@export var max_torque: float  = 3500.0 # vorher 350.0

@export_group("Speed Growth")
@export var min_max_rpm: float = 300.0       # Start-Höchstgeschwindigkeit (RPM)
@export var absolute_max_rpm: float = 1000.0 # Limit / maximale Endgeschwindigkeit
@export var rpm_acceleration: float = 50.0   # Wie viel RPM pro Sekunde dazukommen

@onready var current_max_rpm: float = min_max_rpm

var y_wheel_offset = 0.08
var speed_print_timer: float = 0.0

# Car Death 
signal car_died
var is_dead: bool = false


# --- SLOW ZONE / PATCH LOGIC (Einfach) ---
var current_slow_factor: float = 1.0


@onready var physics_wheels := {
	"fl": $Front_Left,
	"fr": $Front_Right,
	"bl": $Back_Left,
	"br": $Back_Right,
}

var visual_wheels := {}

func _ready() -> void:
	if not car_model_scene:
		push_error("No CarModel scene assigned to PlayerCar!")
		return
	
	current_car_model = car_model_scene.instantiate() as CarModel
	if current_car_model.get_parent() == null:
		add_child(current_car_model)
	
	# --- NEU: Schwerpunkt vom CarModel auf den VehicleBody3D übertragen ---
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = current_car_model.custom_center_of_mass
	
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
		

# --- SLOW ZONE STEUERUNG (Direkt ohne Zähler) ---
func enter_slow_zone(factor: float) -> void:
	current_slow_factor = factor

func exit_slow_zone() -> void:
	current_slow_factor = 1.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	
	# Aktuelle Geschwindigkeit in Metern pro Sekunde
	var current_speed := linear_velocity.length()

	# Lenkwinkel reduzieren, je schneller das Auto fährt (ab ca. 30 m/s ist der Einschlag minimal)
	var speed_factor : float = clamp(current_speed / 30.0, 0.0, 1.0)
	var dynamic_max_steer : float = lerp(max_steer_angle, 0.1, speed_factor)

	var steer_target := Input.get_axis("right", "left") * dynamic_max_steer
	steering = move_toward(steering, steer_target, steer_speed * delta)

	# Auto fährt dauerhaft nach vorne
	var accel := 1.0
	#var accel := Input.get_axis("backward", "forward")
	
	# Max-RPM kontinuierlich mit der Zeit erhöhen bis zum Limit
	current_max_rpm = move_toward(current_max_rpm, absolute_max_rpm, rpm_acceleration * delta)
	
	# Dynamische Skalierung von Drehmoment und Max-RPM
	var effective_torque := max_torque * current_slow_factor
	var effective_max_rpm := current_max_rpm * current_slow_factor

	var rpmBL = abs($Back_Left.get_rpm())
	var rpmBR = abs($Back_Right.get_rpm())
	$Back_Left.engine_force = accel * effective_torque * (1.0 - rpmBL / effective_max_rpm)
	$Back_Right.engine_force = accel * effective_torque * (1.0 - rpmBR / effective_max_rpm)

	if Input.is_action_pressed("brake"):
		brake = 10000.0   # Vorher 5.0 - Muss bei 1200kg massiv höher sein!
		engine_force = 0.0
	elif current_slow_factor < 1.0:
		# Leichter Widerstand/Reibung im Gras/Matsch
		brake = 2000.0    # Vorher 2.0
	else:
		brake = 0.0
		
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
	
	
	
	
	
	
