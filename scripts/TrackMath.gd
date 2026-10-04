class_name TrackMath
extends Node

static var noise_width := FastNoiseLite.new()
static var noise_macro := FastNoiseLite.new()   # Hauptkurven
static var noise_micro := FastNoiseLite.new()   # Schnelle S-Kurven / Schikanen
static var noise_sharp := FastNoiseLite.new()   # Seltene, scharfe Haken

# DAS NOCH BALANCEN:
static var step_size: float = 2.0
static var max_difficulty_distance: float = 250.0
static var min_spawn_prob: float = 0.40
static var max_spawn_prob: float = 0.95


# --- SANDUHR-BREITEN ---
static var min_track_width: float = 5.0   # Echtes Engpass-Nadelöhr
static var max_track_width: float = 28.0  # Breiter Boulevard

# Cache-Listen
static var points: Array[Vector3] = []
static var tangents: Array[Vector3] = []
static var normals: Array[Vector3] = []
static var widths: Array[float] = []

static var accumulated_angle: float = 0.0

static var noise_obs_spawn := FastNoiseLite.new()
static var noise_obs_pos := FastNoiseLite.new()
static var noise_obs_type := FastNoiseLite.new()

static func init_seed(game_seed: int) -> void:
	# 1. Breiten-Noise
	noise_width.seed = game_seed
	noise_width.frequency = 0.01
	noise_width.noise_type = FastNoiseLite.TYPE_PERLIN

	# 2. Hauptkurven (Erhöhte Frequenz für ständig wechselnde Richtungen)
	noise_macro.seed = game_seed + 999
	noise_macro.frequency = 0.005
	noise_macro.noise_type = FastNoiseLite.TYPE_PERLIN

	# 3. Micro-S-Kurven (Hohe Frequenz für Zick-Zack)
	noise_micro.seed = game_seed + 888
	noise_micro.frequency = 0.022
	noise_micro.noise_type = FastNoiseLite.TYPE_PERLIN

	# 4. Scharfe Kurven
	noise_sharp.seed = game_seed + 777
	noise_sharp.frequency = 0.003
	noise_sharp.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# 5. Hindernis-Zonen (Niedrigere Frequenz = ausgedehnte Abschnitte mit/ohne Hindernisse)
	noise_obs_spawn.seed = game_seed + 555
	noise_obs_spawn.frequency = 0.008
	noise_obs_spawn.noise_type = FastNoiseLite.TYPE_PERLIN

	# 6. Querposition auf der Fahrbahn
	noise_obs_pos.seed = game_seed + 444
	noise_obs_pos.frequency = 0.04
	noise_obs_pos.noise_type = FastNoiseLite.TYPE_PERLIN

	# 7. Welches Asset aus dem Array gewählt wird
	noise_obs_type.seed = game_seed + 333
	noise_obs_type.frequency = 0.1
	noise_obs_type.noise_type = FastNoiseLite.TYPE_PERLIN

	points.clear()
	tangents.clear()
	normals.clear()
	widths.clear()

	accumulated_angle = 0.0

	points.append(Vector3.ZERO)
	tangents.append(Vector3(0, 0, -1))
	normals.append(Vector3(1, 0, 0))
	widths.append(20.0)

static func ensure_calculated_up_to(target_index: int) -> void:
	while points.size() <= target_index:
		var i := points.size()
		var current_s := i * step_size

		# --- 1. KURVEN-ELEMENTE BERECHNEN ---
		
		# A) Hauptkurve
		var raw_macro := noise_macro.get_noise_1d(current_s)
		var macro := signf(raw_macro) * pow(absf(raw_macro), 0.5) * 0.038

		# B) Schnelle S-Kurven
		var raw_micro := noise_micro.get_noise_1d(current_s)
		var micro := raw_micro * 0.025

		# C) Scharfe Kurven-Haken
		var raw_sharp := noise_sharp.get_noise_1d(current_s)
		var sharp := 0.0
		if absf(raw_sharp) > 0.32:
			sharp = signf(raw_sharp) * 0.055

		# Gesamte Winkeländerung pro Schritt
		var total_curve_rate := macro + micro + sharp
		accumulated_angle += total_curve_rate * step_size

		# Richtungsvektor aus dem akkumulierten Winkel
		var dir := Vector3(sin(accumulated_angle), 0.0, -cos(accumulated_angle)).normalized()

		var prev_point := points[i - 1]
		var new_point := prev_point + dir * step_size
		var norm := Vector3(-dir.z, 0.0, dir.x)

		# --- 2. SANDUHR-EFFEKT ---
		var raw_w := noise_width.get_noise_1d(current_s)
		var w_factor := (raw_w + 1.0) / 2.0
		var hourglass := smoothstep(0.15, 0.85, w_factor)
		var w: float = lerp(min_track_width, max_track_width, hourglass)

		points.append(new_point)
		tangents.append(dir)
		normals.append(norm)
		widths.append(w)

static var last_known_s_idx: int = 0

static func get_closest_s(pos: Vector3) -> float:
	ensure_calculated_up_to(last_known_s_idx + 100)

	var min_dist_sq := 1e10
	var best_idx := last_known_s_idx

	# KORREKTUR: int statt float (für range)
	var search_start : int = max(0, last_known_s_idx - 10)
	var search_end : int = min(points.size(), last_known_s_idx + 100)

	for i in range(search_start, search_end):
		var dist_sq := pos.distance_squared_to(points[i])
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_idx = i

	last_known_s_idx = best_idx
	return best_idx * step_size
	
# Gibt Spawndaten deterministisch und quer über die ganze Fahrbahn verteilt zurück
# In TrackMath.gd:

static func get_obstacle_info(s: float, asset_count: int) -> Dictionary:
	if asset_count == 0:
		return {"has_obstacle": false}
		
	if s < 20.0:
		return {"has_obstacle": false} # Sicherer Startbereich

	# --- 1. SCHWIERIGKEITS-SKALIERUNG BERECHNEN ---
	# Nach wie vielen Metern soll die maximale Dichte erreicht sein? (z.B. 3000 Meter)
	var progress := clampf(s / max_difficulty_distance, 0.0, 1.0) # 0.0 am Start -> 1.0 nach 3000m

	# Wahrscheinlichkeit steigt von 20% (Start) auf max. 65% (Late Game)
	var current_spawn_prob : float = lerp(min_spawn_prob, max_spawn_prob, progress)

	# Auch die Zonen-Einschränkung öffnet sich sanft (Start: nur dichte Zonen, später: fast überall)
	var zone_threshold : float = lerp(0.05, -0.25, progress)


	# --- 2. ZONE UND SPAWN-CHANCE PRÜFEN ---
	var zone_density := noise_obs_spawn.get_noise_1d(s)

	if zone_density > zone_threshold:
		var step_id := int(s)

		# Deterministischer Hash für das Auftauchen
		var spawn_hash := posmod(hash(step_id * 73856093 ^ noise_obs_spawn.seed), 100000)
		var spawn_chance := (spawn_hash % 100) / 100.0

		# Dynamische Prüfung basierend auf dem aktuellen Fortschritt (s)
		if spawn_chance < current_spawn_prob:
			# 3. Asset-Index wählen
			var type_hash := posmod(hash(step_id * 19349663 ^ (noise_obs_spawn.seed + 99)), 100000)
			var selected_index := type_hash % asset_count

			# 4. Querposition auf der Straße (-0.85 bis +0.85)
			var pos_hash := posmod(hash(step_id * 3828371 ^ (noise_obs_spawn.seed + 55)), 100000)
			var normalized_pos := (pos_hash % 1001) / 1000.0
			var offset_ratio := (normalized_pos * 1.7) - 0.85

			# 5. Rotation (0 bis 360 Grad)
			var rot_hash := posmod(hash(step_id * 9182731 ^ (noise_obs_spawn.seed + 123)), 100000)
			var rotation_deg := (rot_hash % 3600) / 10.0

			# 6. UNABHÄNGIGE SKALIERUNG FÜR X UND Z (0.0 bis 1.0)
			var scale_x_hash := posmod(hash(step_id * 482711 ^ (noise_obs_spawn.seed + 222)), 100000)
			var scale_z_hash := posmod(hash(step_id * 619283 ^ (noise_obs_spawn.seed + 333)), 100000)

			var scale_ratio_x := (scale_x_hash % 1001) / 1000.0
			var scale_ratio_z := (scale_z_hash % 1001) / 1000.0

			return {
				"has_obstacle": true,
				"offset_ratio": offset_ratio,
				"type_index": selected_index,
				"rotation_deg": rotation_deg,
				"scale_ratio_x": scale_ratio_x,
				"scale_ratio_z": scale_ratio_z
			}

	return {"has_obstacle": false}
	
	
	
# Unabhängige Abfrage für Bodenflächen (Gras, Öl, Decals)
static func get_patch_info(s: float, patch_count: int) -> Dictionary:
	if patch_count == 0:
		return {"has_patch": false}

	if s < 20.0: # Kleiner Startpuffer
		return {"has_patch": false}

	var step_id := int(s)

	# 1. Deterministische Spawn-Chance für Bodenflächen (z. B. 35% Chance alle 10m)
	var spawn_hash := posmod(hash(step_id * 104729 ^ (noise_obs_spawn.seed + 777)), 100000)
	var spawn_chance := (spawn_hash % 100) / 100.0

	if spawn_chance < 0.35: # 35% Chance
		# 2. Welches Patch-Asset (Gras 1, Gras 2, Öl, etc.)
		var type_hash := posmod(hash(step_id * 224737 ^ (noise_obs_spawn.seed + 888)), 100000)
		var selected_index := type_hash % patch_count

		# 3. Querposition auf der Straße (-0.8 bis +0.8)
		var pos_hash := posmod(hash(step_id * 334829 ^ (noise_obs_spawn.seed + 999)), 100000)
		var normalized_pos := (pos_hash % 1001) / 1000.0
		var offset_ratio := (normalized_pos * 1.6) - 0.8

		# 4. Zufallswinkel (0 bis 360 Grad)
		var rot_hash := posmod(hash(step_id * 445801 ^ (noise_obs_spawn.seed + 111)), 100000)
		var rotation_deg := (rot_hash % 3600) / 10.0

		# 5. Getrennte Skalierung für X und Z
		var scale_x_hash := posmod(hash(step_id * 556817 ^ (noise_obs_spawn.seed + 222)), 100000)
		var scale_z_hash := posmod(hash(step_id * 667829 ^ (noise_obs_spawn.seed + 333)), 100000)

		return {
			"has_patch": true,
			"offset_ratio": offset_ratio,
			"type_index": selected_index,
			"rotation_deg": rotation_deg,
			"scale_ratio_x": (scale_x_hash % 1001) / 1000.0,
			"scale_ratio_z": (scale_z_hash % 1001) / 1000.0
		}

	return {"has_patch": false}
