extends Node3D

@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:
	particles.restart()
	particles.emitting = true
	
	await get_tree().create_timer(1.5).timeout
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
