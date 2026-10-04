extends Node3D

@export var player: VehicleBody3D
@export var chunk_scene: PackedScene
@export var chunk_length: float = 40.0
@export var render_distance: float = 160.0

var next_spawn_z: float = 0.0
var active_chunks: Array[Node3D] = []

func _ready() -> void:
	
	var active_seed := GameManager.current_seed
	TrackMath.reset(active_seed)
	
	next_spawn_z = 0.0
	active_chunks.clear()
	
	while next_spawn_z < render_distance:
		spawn_next_chunk()

func _process(_delta: float) -> void:
	if not player:
		return

	# Liest den echten Standort des Autos relativ zur Strecke aus
	var player_s := TrackMath.get_closest_s(player.global_position)

	# 1. Neue Chunks voraus erzeugen
	while next_spawn_z < player_s + render_distance:
		spawn_next_chunk()

	# 2. Alte Chunks hinter dem Spieler aufräumen
	cleanup_chunks(player_s)

func spawn_next_chunk() -> void:
	if not chunk_scene:
		push_error("TrackManager: Keine 'chunk_scene' im Inspector zugewiesen!")
		return

	var chunk := chunk_scene.instantiate() as Node3D
	add_child(chunk)

	if chunk.has_method("generate_chunk"):
		chunk.generate_chunk(next_spawn_z, chunk_length)

	active_chunks.append(chunk)
	next_spawn_z += chunk_length

func cleanup_chunks(player_s: float) -> void:
	for i in range(active_chunks.size() - 1, -1, -1):
		var chunk := active_chunks[i]
		if is_instance_valid(chunk):
			if chunk.end_s < player_s - 50.0:
				chunk.queue_free()
				active_chunks.remove_at(i)
