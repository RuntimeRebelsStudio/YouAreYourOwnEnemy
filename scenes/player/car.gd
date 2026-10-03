extends VehicleBody3D

@export var car_model_scene: PackedScene
@export var current_car_model: CarModel



@export var engine_power: float = 200.0
@export var max_steer_angle: float = 0.5
@export var steer_speed: float = 3.0

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
	if not current_car_model:
		push_error("No CarModel assigned to PlayerCar!")
		return

	# Modell muss im Baum hängen
	if current_car_model.get_parent() == null:
		add_child(current_car_model)

	visual_wheels = {
		"fl": current_car_model.wheel_fl,
		"fr": current_car_model.wheel_fr,
		"bl": current_car_model.wheel_bl,
		"br": current_car_model.wheel_br,
	}

	# Kollision übernehmen, globale Position behalten
	current_car_model.body_collision.reparent(self, true)
	
	
	# Physik-Räder an die Position der visuellen Räder setzen
	for key in physics_wheels:
		var p: VehicleWheel3D = physics_wheels[key]
		p.position = to_local(visual_wheels[key].global_position)
		
		p.wheel_radius = current_car_model.wheel_radius
		remove_child(p)
		add_child(p)
		
		# Nur zum Testen: Zeigt dir im Spiel genau an, wo das Physik-Rad sitzt
	for key in physics_wheels:
		var p: VehicleWheel3D = physics_wheels[key]
		
		var debug_mesh = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = p.wheel_radius
		cylinder.bottom_radius = p.wheel_radius
		cylinder.height = 0.1
		debug_mesh.mesh = cylinder
		
		# Zylinder so drehen, dass er wie ein Reifen liegt (90 Grad auf X)
		debug_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		p.add_child(debug_mesh)


func _physics_process(delta: float) -> void:
	var steer_target := Input.get_axis("right", "left") * max_steer_angle
	steering = move_toward(steering, steer_target, steer_speed * delta)

	var accel := Input.get_axis("backward", "forward")
	engine_force = accel * engine_power

	if Input.is_action_pressed("brake"):
		brake = 5.0
		engine_force = 0.0
	else:
		brake = 0.0


func _process(_delta: float) -> void:
	# Visuelle Räder folgen den Physik-Rädern (Position + Rotation durch Fahrt/Lenkung)
	for key in visual_wheels:
		var v: Node3D = visual_wheels[key]
		var p: VehicleWheel3D = physics_wheels[key]
		if v and p:
			v.global_position = p.global_position
			v.global_rotation = p.global_rotation
			v.rotate_object_local(Vector3.UP, PI)
