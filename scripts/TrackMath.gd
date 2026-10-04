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

		# =========================================================
		# NEU: ANTI-LOOP-SYSTEM (Gummiband-Effekt / Forward Bias)
		# =========================================================
		# Wie weit darf die Strecke maximal abknicken? (z.B. 140 Grad)
		var max_angle := deg_to_rad(140.0) 
		
		# Berechne, wie nah wir am absoluten Limit sind (0.0 = geradeaus, 1.0 = am Limit)
		var deviation := accumulated_angle / max_angle
		
		# Exponentielle Rückstellkraft: Kleine Kurven bleiben unbeeinflusst, 
		# aber je schärfer die Kurve wird, desto brutaler drückt das System dagegen.
		# hoch 3 (pow 3) sorgt für eine sanfte Kurve, die am Ende zur Wand wird.
		var pull_back_force : float = pow(abs(deviation), 3.0) * sign(accumulated_angle)
		
		# Den Winkel aktiv zurückziehen
		accumulated_angle -= pull_back_force * 0.08 * step_size
		
		# Harte Begrenzung (Clamp) als absolutes Sicherheitsnetz, 
		# damit extreme Noise-Werte das System niemals überwinden können.
		accumulated_angle = clamp(accumulated_angle, -max_angle, max_angle)
		# =========================================================

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
	var result := get_track_progress_s_optimized(pos, last_known_s_idx)
	last_known_s_idx = result["index"]
	return result["s"]


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
	
	
# TrackMath.gd

# Optimierte Abfrage: Sucht nur in einem kleinen Fenster um den 'last_index' herum
static func get_track_progress_s_optimized(car_position: Vector3, last_index: int) -> Dictionary:
	if points.is_empty():
		return {"s": 0.0, "index": 0}
		
	var search_radius := 15
	var start_i: int = max(0, last_index - search_radius)
	var end_i: int = min(points.size() - 1, last_index + search_radius)
	
	var best_idx := last_index
	var min_dist_sq := INF
	
	for i in range(start_i, end_i + 1):
		var dist_sq := car_position.distance_squared_to(points[i])
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_idx = i
			
	if (best_idx == start_i and start_i > 0) or (best_idx == end_i and end_i < points.size() - 1):
		for i in range(points.size()):
			var dist_sq := car_position.distance_squared_to(points[i])
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				best_idx = i

	# DEFAULT FLOAT FALLBACK
	var progress_s : float = float(best_idx) * step_size

	if best_idx < points.size() - 1:
		var p1 := points[best_idx]
		var p2 := points[best_idx + 1]
		var segment := p2 - p1
		var seg_len_sq := segment.length_squared()
		
		if seg_len_sq > 0.0001:
			# CAST TO FLOAT EXPLICITLY TO PREVENT INT-DIVISION TRUNCATION
			var t : float = clampf((car_position - p1).dot(segment) / seg_len_sq, 0.0, 1.0)
			progress_s = (float(best_idx) + t) * float(step_size)

	return {
		"s": progress_s,
		"index": best_idx
	}
	
	
static func reset(game_seed: int) -> void:
		last_known_s_idx = 0
		init_seed(game_seed)
