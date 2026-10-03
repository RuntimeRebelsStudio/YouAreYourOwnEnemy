extends VehicleBody3D

@export var car_model_scene: PackedScene
var current_car_model: CarModel


# Car stats
@export var engine_power: float = 200.0
@export var max_steer_angle: float = 0.5
@export var steer_speed: float = 3.0
@export var max_rpm = 500.0
@export var max_torque = 200.0

var y_wheel_offset = 0.08




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
		


func _physics_process(delta: float) -> void:
	var steer_target := Input.get_axis("right", "left") * max_steer_angle
	steering = move_toward(steering, steer_target, steer_speed * delta)

	var accel := Input.get_axis("backward", "forward")
	
	var rpm = abs($Back_Left.get_rpm())
	$Back_Left.engine_force = accel * max_torque * ( 1 - rpm / max_rpm)
	rpm = abs($Back_Right.get_rpm())
	$Back_Right.engine_force = accel * max_torque * ( 1 - rpm / max_rpm)


	if Input.is_action_pressed("brake"):
		brake = 5.0
		engine_force = 0.0
	else:
		brake = 0.0


func _process(_delta: float) -> void:
	pass
