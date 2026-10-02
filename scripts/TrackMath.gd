class_name TrackMath
extends Node

static var noise_width := FastNoiseLite.new()
static var noise_macro := FastNoiseLite.new()   # Hauptkurven
static var noise_micro := FastNoiseLite.new()   # Schnelle S-Kurven / Schikanen
static var noise_sharp := FastNoiseLite.new()   # Seltene, scharfe Haken

static var step_size: float = 2.0

# --- SANDUHR-BREITEN (Unverändert gut!) ---
static var min_track_width: float = 5.0   # Echtes Engpass-Nadelöhr
static var max_track_width: float = 28.0  # Breiter Boulevard

# Cache-Listen
static var points: Array[Vector3] = []
static var tangents: Array[Vector3] = []
static var normals: Array[Vector3] = []
static var widths: Array[float] = []

static var accumulated_angle: float = 0.0

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

		# --- 1. KURVEN-ELEMENTE STARK UND KONTINUIERLICH BERECHNEN ---
		
		# A) Hauptkurve: Verstärkt durch Potenzierung, damit keine spitzen Nullstellen entstehen
		var raw_macro := noise_macro.get_noise_1d(current_s)
		var macro := signf(raw_macro) * pow(absf(raw_macro), 0.5) * 0.038

		# B) Schnelle S-Kurven: Laufen fließend auf der Hauptkurve mit
		var raw_micro := noise_micro.get_noise_1d(current_s)
		var micro := raw_micro * 0.025

		# C) Scharfe Kurven-Haken (Injiziert bei Ausschlägen scharfe Abbiegungen)
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

	var search_start : float = max(0, last_known_s_idx - 10)
	var search_end : float = min(points.size(), last_known_s_idx + 100)

	for i in range(search_start, search_end):
		var dist_sq := pos.distance_squared_to(points[i])
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_idx = i

	last_known_s_idx = best_idx
	return best_idx * step_size
