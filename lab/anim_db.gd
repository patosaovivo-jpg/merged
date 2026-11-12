class_name LabAnimDB
extends RefCounted
## =============================================================================
## BANCO DE ANIMAÇÕES
## -----------------------------------------------------------------------------
## Varre res://ANIMATIONS (recursivo), carrega cada FBX/GLB/.scn/.tres do Mixamo e
## classifica cada clipe sozinho:
##   - categoria (idle, locomoção, ataque, bloqueio, pulo, rolamento, dano...)
##   - direção (f, fl, l, bl, b, br, r, fr) e velocidade real pelo deslocamento
##     do quadril (assim "great sword run" que na verdade corre de costas é
##     detectado corretamente e o corpo anda sem deslizar o pé)
##   - se o clipe deve tocar no corpo inteiro ou só na parte de cima
## O X/Z do quadril é travado nos clipes (o corpo é movido por código); a curva
## original fica guardada em meta ("root_t"/"root_xz") p/ aplicar root motion
## em ataques, rolamentos etc.
## Resultado é guardado em cache (user://) => a partir da 2ª vez abre rápido.
## =============================================================================

enum Cat { OTHER, IDLE, LOCO, ATTACK, BLOCK, JUMP, DODGE, HIT, DEATH, EQUIP, EMOTE, TURN }

const CAT_LABEL := {
	Cat.OTHER: "outro", Cat.IDLE: "idle", Cat.LOCO: "locomoção", Cat.ATTACK: "ataque",
	Cat.BLOCK: "bloqueio", Cat.JUMP: "pulo", Cat.DODGE: "rolamento/esquiva", Cat.HIT: "dano",
	Cat.DEATH: "morte", Cat.EQUIP: "equipar", Cat.EMOTE: "emote", Cat.TURN: "giro",
}

const DEFAULT_ROOTS := ["res://ANIMATIONS"]
const EXTS := ["fbx", "glb", "gltf", "dae", "scn", "tscn", "res", "tres"]
const CACHE_PATH := "user://lab_anim_cache_v2.res"
const DIR_BY_IDX := {0: "f", 1: "fl", 2: "l", 3: "bl", 4: "b", -1: "fr", -2: "r", -3: "br", -4: "b"}

var entries: Dictionary = {}   # key ("Pack/clip") -> info (Dictionary)
var anims: Dictionary = {}     # key -> Animation (já processada)
var packs: Dictionary = {}     # pack -> Array[String] de keys
var roots: Array = []
var from_cache := false
var skipped: PackedStringArray = []


func clear() -> void:
	entries.clear()
	anims.clear()
	packs.clear()
	skipped = PackedStringArray()
	from_cache = false


func has(key: String) -> bool:
	return entries.has(key)


func info(key: String) -> Dictionary:
	return entries.get(key, {})


func pack_names() -> Array:
	var names := packs.keys()
	names.sort()
	return names


## Procura uma key por texto exato (sem diferenciar maiúsculas) ou "pack/clip".
func find_key(spec: String) -> String:
	if spec == "":
		return ""
	if entries.has(spec):
		return spec
	var low := spec.to_lower()
	for k in entries:
		if String(k).to_lower() == low:
			return k
	return ""


# -----------------------------------------------------------------------------
# CARREGAMENTO
# -----------------------------------------------------------------------------
## Use com await. progress(feitos:int, total:int, arquivo:String)
func load_all(p_roots: Array = DEFAULT_ROOTS, force := false, progress := Callable()) -> void:
	clear()
	roots = p_roots.duplicate()
	var files: Array = []
	for r in roots:
		_list_files(String(r), files)
	files.sort()
	if files.is_empty():
		_load_fallback_libs()
		_rebuild_index()
		return
	var fp := _fingerprint(files)
	if not force and _try_load_cache(fp):
		from_cache = true
		return
	var tree := Engine.get_main_loop() as SceneTree
	var n := 0
	for path in files:
		var base := String(path).get_base_dir()
		var pack := base.get_file()
		var clip := String(path).get_file().get_basename()
		var found := _extract(String(path))
		if found.is_empty():
			skipped.append(String(path))
		for i in found.size():
			var an: Animation = found[i][1]
			var cname := clip if found.size() == 1 else "%s [%s]" % [clip, found[i][0]]
			_add_animation(pack, cname, an)
		n += 1
		if n % 5 == 0:
			if progress.is_valid():
				progress.call(n, files.size(), String(path))
			if tree:
				await tree.process_frame
	_rebuild_index()
	_save_cache(fp)


func _list_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not f.begins_with("."):
			var full := dir_path.path_join(f)
			if d.current_is_dir():
				_list_files(full, out)
			else:
				var nm := f
				if nm.ends_with(".import"):
					nm = nm.trim_suffix(".import")
				elif nm.ends_with(".remap"):
					nm = nm.trim_suffix(".remap")
				if nm.get_extension().to_lower() in EXTS:
					var p := dir_path.path_join(nm)
					if not out.has(p):
						out.append(p)
		f = d.get_next()
	d.list_dir_end()


## Retorna [[nome, Animation], ...] (cópias independentes).
func _extract(path: String) -> Array:
	var out: Array = []
	if not ResourceLoader.exists(path):
		return out
	var res = load(path)
	if res is PackedScene:
		var inst: Node = (res as PackedScene).instantiate()
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			var player := ap as AnimationPlayer
			for lib_name in player.get_animation_library_list():
				var lib := player.get_animation_library(lib_name)
				for an in lib.get_animation_list():
					if String(an) == "RESET":
						continue
					out.append([String(an), lib.get_animation(an).duplicate(true)])
		inst.free()
	elif res is AnimationLibrary:
		for an in (res as AnimationLibrary).get_animation_list():
			out.append([String(an), (res as AnimationLibrary).get_animation(an).duplicate(true)])
	elif res is Animation:
		out.append(["", (res as Animation).duplicate(true)])
	return out


func _load_fallback_libs() -> void:
	var d := DirAccess.open("res://characters")
	if d == null:
		return
	for f in d.get_files():
		var nm := f.trim_suffix(".import").trim_suffix(".remap")
		if nm.get_extension() in ["tres", "res"]:
			var res = load("res://characters/" + nm)
			if res is AnimationLibrary:
				var pack := "Biblioteca (" + nm.get_basename() + ")"
				for an in (res as AnimationLibrary).get_animation_list():
					var a: Animation = (res as AnimationLibrary).get_animation(an).duplicate(true)
					if a.get_track_count() > 0:
						_add_animation(pack, String(an), a)


func _add_animation(pack: String, clip: String, anim: Animation) -> void:
	var inf := _classify(pack, clip, anim)
	anim.set_meta("lab", inf)
	entries[inf.key] = inf
	anims[inf.key] = anim


func _rebuild_index() -> void:
	packs.clear()
	for key in entries:
		var p: String = entries[key].pack
		if not packs.has(p):
			packs[p] = []
		(packs[p] as Array).append(key)
	for p in packs:
		(packs[p] as Array).sort()


# -----------------------------------------------------------------------------
# CLASSIFICAÇÃO
# -----------------------------------------------------------------------------
static func _has_any(s: String, words: Array) -> bool:
	for w in words:
		if s.contains(w):
			return true
	return false


func _classify(pack: String, clip: String, anim: Animation) -> Dictionary:
	var n := clip.to_lower()
	var inf := {"pack": pack, "name": clip, "key": pack + "/" + clip, "len": anim.length}

	# --- curva do quadril (root motion) ---
	var hips_track := -1
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D \
				and String(anim.track_get_path(t)).to_lower().ends_with("hips"):
			hips_track = t
			break
	var disp := Vector3.ZERO
	var hips_y := 1.0
	var times := PackedFloat32Array()
	var xz := PackedVector2Array()
	var v0 := Vector3.ZERO
	var kc := 0
	if hips_track >= 0:
		kc = anim.track_get_key_count(hips_track)
		if kc > 0:
			v0 = anim.track_get_key_value(hips_track, 0)
			hips_y = v0.y
			for i in kc:
				var v: Vector3 = anim.track_get_key_value(hips_track, i)
				times.append(anim.track_get_key_time(hips_track, i))
				xz.append(Vector2(v.x - v0.x, v.z - v0.z))
			var vl: Vector3 = anim.track_get_key_value(hips_track, kc - 1)
			disp = vl - v0
	var hs := Vector2(disp.x, disp.z).length() / maxf(anim.length, 0.01)

	# --- categoria por nome ---
	var cat := Cat.OTHER
	if n.contains("death") or n.contains("dying"):
		cat = Cat.DEATH
	elif n.contains("impact") or n.contains("react"):
		cat = Cat.HIT
	elif n.contains("block"):
		cat = Cat.BLOCK
	elif _has_any(n, ["roll", "dodge", "dive", "flip", "evade", "sidestep", "somersault", "cartwheel"]):
		cat = Cat.DODGE
	elif n.contains("jump"):
		cat = Cat.ATTACK if n.contains("attack") else Cat.JUMP
	elif _has_any(n, ["draw sword", "draw a ", "sheath", "equip", "disarm", "holster"]):
		cat = Cat.EQUIP
	elif _has_any(n, ["taunt", "power up", "battlecry", "thump", "dance", "wave", "victory", "cheer"]):
		cat = Cat.EMOTE
	elif n.contains("turn"):
		cat = Cat.TURN
	elif _has_any(n, ["start walking", "stop walking", "backwards stop", "stand to", "to stand", "to standing", "to dying"]):
		cat = Cat.OTHER
	elif n.contains("idle"):
		cat = Cat.IDLE
	elif _has_any(n, ["attack", "slash", "combo", "melee", "cast", "spell", "magic", "kick", "spin", "firing",
			"shoot", "swing", "stab", "punch", "slide", "arrow"]):
		cat = Cat.ATTACK
	elif hs >= 0.9 and anim.length <= 2.5 and absf(disp.y) < 0.25:
		cat = Cat.LOCO

	# --- direção / classe de velocidade (só locomoção) ---
	var dir := "f"
	var sclass := ""
	var speed := 0.0
	if cat == Cat.LOCO:
		speed = hs
		var ang := rad_to_deg(atan2(disp.x, disp.z))   # +x = esquerda do personagem, +z = frente
		dir = DIR_BY_IDX[clampi(int(roundf(ang / 45.0)), -4, 4)]
		if n.contains("sprint"):
			sclass = "sprint"
		elif n.contains("run") or n.contains("jog"):
			sclass = "run"
		elif n.contains("walk"):
			sclass = "walk"
		else:
			sclass = "run" if speed >= 3.0 else "walk"

	var crouch := n.contains("crouch") or n.contains("kneel")
	var loop := cat == Cat.IDLE or cat == Cat.LOCO or n.contains("block idle") or n.contains("jump loop")
	var root_motion := cat != Cat.IDLE and cat != Cat.LOCO and cat != Cat.TURN and cat != Cat.JUMP \
			and Vector2(disp.x, disp.z).length() > 0.5
	var full := cat == Cat.JUMP or cat == Cat.DODGE or cat == Cat.HIT or cat == Cat.DEATH \
			or cat == Cat.TURN or hips_y < 0.85

	inf["cat"] = cat
	inf["dir"] = dir
	inf["sclass"] = sclass
	inf["speed"] = speed
	inf["disp"] = disp
	inf["hips_y"] = hips_y
	inf["loop"] = loop
	inf["crouch"] = crouch
	inf["aim"] = n.contains("aiming")
	inf["root_motion"] = root_motion
	inf["default_mode"] = "full" if full else "auto"

	# --- processa a animação ---
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if hips_track >= 0 and kc > 0:
		for i in kc:
			var v: Vector3 = anim.track_get_key_value(hips_track, i)
			anim.track_set_key_value(hips_track, i, Vector3(v0.x, v.y, v0.z))
		if root_motion:
			anim.set_meta("root_t", times)
			anim.set_meta("root_xz", xz)
	return inf


# -----------------------------------------------------------------------------
# ROOT MOTION (amostra a curva guardada)  x = esquerda(+), y = frente(+)
# -----------------------------------------------------------------------------
static func root_delta(anim: Animation, t0: float, t1: float) -> Vector2:
	if anim == null or not anim.has_meta("root_t"):
		return Vector2.ZERO
	var ts: PackedFloat32Array = anim.get_meta("root_t")
	var ps: PackedVector2Array = anim.get_meta("root_xz")
	return _sample(ts, ps, t1) - _sample(ts, ps, t0)


static func _sample(ts: PackedFloat32Array, ps: PackedVector2Array, t: float) -> Vector2:
	var n := ts.size()
	if n == 0:
		return Vector2.ZERO
	if t <= ts[0]:
		return ps[0]
	if t >= ts[n - 1]:
		return ps[n - 1]
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if ts[mid] <= t:
			lo = mid
		else:
			hi = mid
	var span := ts[hi] - ts[lo]
	var f := 0.0 if span <= 0.0 else (t - ts[lo]) / span
	return ps[lo].lerp(ps[hi], f)


# -----------------------------------------------------------------------------
# CACHE
# -----------------------------------------------------------------------------
func _fingerprint(files: Array) -> String:
	var s := ""
	for f in files:
		s += String(f) + "|" + str(FileAccess.get_modified_time(String(f))) + ";"
	return "%d:%d:v2" % [files.size(), s.hash()]


func _try_load_cache(fp: String) -> bool:
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	var lib = ResourceLoader.load(CACHE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (lib is AnimationLibrary):
		return false
	if String((lib as AnimationLibrary).get_meta("fingerprint", "")) != fp:
		return false
	for n in (lib as AnimationLibrary).get_animation_list():
		var a: Animation = (lib as AnimationLibrary).get_animation(n)
		if not a.has_meta("lab"):
			clear()
			return false
		var inf: Dictionary = a.get_meta("lab")
		entries[inf.key] = inf
		anims[inf.key] = a
	if entries.is_empty():
		return false
	_rebuild_index()
	return true


func _save_cache(fp: String) -> void:
	if entries.is_empty():
		return
	var lib := AnimationLibrary.new()
	for key in anims:
		var nm := String(key).replace("/", "|").replace(":", "-").replace(",", ";").replace("[", "(").replace("]", ")")
		lib.add_animation(StringName(nm), anims[key])
	lib.set_meta("fingerprint", fp)
	var err := ResourceSaver.save(lib, CACHE_PATH)
	if err != OK:
		push_warning("LabAnimDB: não consegui salvar o cache (%d)" % err)
