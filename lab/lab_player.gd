class_name LabPlayer
extends CharacterBody3D
## =============================================================================
## JOGADOR DO LABORATÓRIO
##  WASD mover | Shift correr | Espaço pular | Q rolamento/esquiva | F bloquear (segurar)
##  1-8 animações configuráveis | Botão direito = ataque/combo | Mouse = câmera
## =============================================================================

signal status_changed
signal loadout_changed

const MODES := ["auto", "upper", "full"]
const MODE_LABEL := ["Auto", "Só cima", "Corpo todo"]

var db: LabAnimDB
var rig: LabRig
var pivot: Node3D
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D

# --- ajustes (ligados ao menu) ---
var strafe_mode := false
var sync_speed := true
var walk_speed := 2.0
var run_speed := 5.0
var anim_speed := 1.0
var use_root_motion := true
var split_independent := true
var combo_window := 1.0     # a partir de que % do golpe o próximo pode entrar
var move_cancel := 1.0      # a partir de que % um golpe de corpo todo pode ser cancelado por movimento
var look: LabLook = LabLook.new()
var fill_light: OmniLight3D
var showcase := false          # modo vitrine (aba Visual): câmera foca no personagem
var auto_rotate := false
var cam_height := 1.5
var _cam_len_target := -1.0
var mouse_sens := 0.003
var gravity := 18.0
var jump_velocity := 5.2

# --- estado ---
var loadout: Dictionary = {}
var female := false
var slots: Dictionary = {}
var slot_overrides: Dictionary = {}       # por loadout id -> {slot: key}
var chain: Array = []
var chain_override: Dictionary = {}       # por loadout id -> Array de keys
var binds: Array = []                     # 8 x {"key","mode","user"}
var roles := {}                           # jump/dodge/block/hit/death/equip -> key
var role_override := {}                   # role -> key (global)
var cur_speed := 0.0
var cur_slot := "idle"
var cur_dir := "f"
var combo_idx := 0
var combo_count := 0
var _act := {}
var _queued_attack := false
var _last_attack_end := -10.0
var _face_yaw_override := NAN
var _face_until := 0.0
var _jump_timer := -1.0
var _yaw := 0.0
var _pitch := -0.25
var _blocking := false
var _hit_dummy_cb := Callable()
var last_text := ""

var aim_mode := false
var locked_target: Node3D = null
var lock_on_range := 18.0

var seek_cache: ComboSeekCache
var pose_offset: PoseOffset
var use_combo_seek := true
var combo_seek_decay := 0.10


func _ready() -> void:
	floor_snap_length = 0.3
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	pivot = Node3D.new()
	pivot.rotation.y = PI          # os modelos do Mixamo olham para +Z; o corpo olha para -Z
	add_child(pivot)
	rig = LabRig.new()
	pivot.add_child(rig)

	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 2.6
	spring.margin = 0.2
	spring.add_excluded_object(get_rid())
	cam_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 65
	cam.position = Vector3(0.45, 0.0, 0.0)
	spring.add_child(cam)
	cam.current = true
	fill_light = OmniLight3D.new()       # luz de preenchimento (só no modo vitrine)
	fill_light.omni_range = 12.0
	fill_light.light_energy = 0.7
	fill_light.shadow_enabled = false
	fill_light.visible = false
	cam.add_child(fill_light)
	cam_pivot.global_position = global_position + Vector3(0, 1.5, 0)

	for i in 8:
		binds.append({"key": "", "mode": "auto", "user": false})

	seek_cache = ComboSeekCache.new()
	pose_offset = PoseOffset.new()
	pose_offset.decay_time = combo_seek_decay


# -----------------------------------------------------------------------------
# Personagem / loadout
# -----------------------------------------------------------------------------
func load_character(path: String) -> void:
	female = path.get_file().begins_with("femea")
	rig.load_character(db, path)
	look.bind(rig)
	if not loadout.is_empty():
		equip_loadout(loadout.id, false)


func equip_loadout(id: String, play_equip := true) -> void:
	loadout = LabLoadouts.by_id(id)
	_abort_all()
	slots = LabLoadouts.resolve_slots(db, loadout, female, slot_overrides.get(id, {}))
	rig.assign_slots(slots)
	rig.equip_weapons(loadout.weapons)
	chain = chain_override.get(id, LabLoadouts.resolve_chain(db, loadout))
	var sp := LabLoadouts.resolve_specials(db, loadout)
	for i in 8:
		if not binds[i].user:
			binds[i].key = sp[i]
			binds[i].mode = "auto"
	for r in ["jump", "dodge", "block", "hit", "death", "equip"]:
		roles[r] = role_override.get(r, LabLoadouts.resolve_role(db, loadout, r, female))
	strafe_mode = loadout.get("strafe", false)
	aim_mode = _is_ranged_weapon()
	if seek_cache != null:
		seek_cache.build(db, chain)
	combo_idx = 0
	combo_count = 0
	loadout_changed.emit()
	if play_equip and roles.get("equip", "") != "":
		trigger_clip(roles.equip, "upper", "equip")


func apply_slot_override(slot: String, key: String) -> void:
	var id: String = loadout.id
	var d: Dictionary = slot_overrides.get(id, {})
	if key == "":
		d.erase(slot)
	else:
		d[slot] = key
	slot_overrides[id] = d
	slots = LabLoadouts.resolve_slots(db, loadout, female, d)
	rig.assign_slots(slots)


func _abort_all() -> void:
	_act = {}
	_queued_attack = false
	_blocking = false
	rig.stop_actions()
	rig.set_stance("")


# -----------------------------------------------------------------------------
# Entrada
# -----------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			or (showcase and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)):
		_yaw -= event.relative.x * mouse_sens
		_pitch = clampf(_pitch - event.relative.y * mouse_sens, -1.2, 0.8)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not showcase and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			MOUSE_BUTTON_RIGHT:
				attack_pressed()
			MOUSE_BUTTON_MIDDLE:
				_toggle_lock_on()
			MOUSE_BUTTON_WHEEL_UP:
				spring.spring_length = clampf(spring.spring_length - 0.4, 1.2, 10.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				spring.spring_length = clampf(spring.spring_length + 0.4, 1.2, 10.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				press_bind(event.keycode - KEY_1)
			KEY_Q:
				dodge_pressed()
			KEY_SPACE:
				jump_pressed()
			KEY_R:
				stop_current()


func press_bind(i: int) -> void:
	var b: Dictionary = binds[i]
	if b.key != "":
		trigger_clip(b.key, b.mode, "special")


func stop_current() -> void:
	_act = {}
	_queued_attack = false
	rig.stop_actions()


func _is_ranged_weapon() -> bool:
	var w := String(loadout.get("weapons", [""])[0] if loadout.has("weapons") else "")
	# active weapon from rig? use first weapon id
	var ids: Array = loadout.get("weapons", [])
	if ids.is_empty():
		return false
	var id := String(ids[0])
	return id in ["bow", "pistol", "rifle", "staff"]

func _toggle_aim() -> void:
	if not _is_ranged_weapon():
		return
	aim_mode = not aim_mode
	if not aim_mode:
		# reset camera distance handled in _update_camera
		pass

func _toggle_lock_on() -> void:
	if locked_target != null and is_instance_valid(locked_target):
		locked_target = null
		return
	# find nearest dummy in front within range
	var best: Node3D = null
	var best_dist := lock_on_range
	for n in get_tree().get_nodes_in_group("dummies"):
		if not (n is Node3D):
			continue
		var d := (n as Node3D).global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = n as Node3D
	locked_target = best

func attack_pressed() -> void:
	if chain.is_empty():
		return
	if _act.get("active", false) and _act.kind == "attack":
		_queued_attack = true
		return
	if _act.get("active", false) and _act.kind in ["death", "hit"]:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_attack_end > 0.9:
		combo_idx = 0
	elif combo_idx >= chain.size():
		combo_idx = 0
	trigger_clip(chain[combo_idx], "auto", "attack")


func dodge_pressed() -> void:
	if roles.get("dodge", "") == "":
		return
	if _act.get("active", false) and _act.kind in ["death", "hit"]:
		return
	trigger_clip(roles.dodge, "full", "dodge")


func jump_pressed() -> void:
	if not is_on_floor() or _jump_timer >= 0.0:
		return
	if _act.get("active", false) and _act.full and _act.kind != "jump":
		return
	if roles.get("jump", "") != "":
		trigger_clip(roles.jump, "full", "jump")
	_jump_timer = 0.12


# -----------------------------------------------------------------------------
# Ações (clipes tocados uma vez)
# -----------------------------------------------------------------------------
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func trigger_clip(key: String, mode_pref := "auto", kind := "special") -> bool:
	if not db.has(key):
		return false
	var inf := db.info(key)
	if _act.get("active", false) and _act.kind == "death" and kind != "death":
		return false
	var moving := cur_speed > 0.6
	var full := false
	match mode_pref:
		"full":
			full = true
		"upper":
			full = false
		_:
			full = inf.default_mode == "full" or not moving
	if mode_pref != "upper" and not split_independent:
		full = true
	var anim: Animation = db.anims[key]
	var length := anim.length / maxf(anim_speed, 0.05)
	var cancel := 1.0
	var locks := full
	match kind:
		"attack": cancel = move_cancel
		"special": cancel = 0.85
		"dodge": cancel = 0.85
		"jump", "equip", "emote": locks = false
		"hit", "death": cancel = 1.0
	if kind == "jump":
		locks = false
	var rm: bool = use_root_motion and full and inf.root_motion and kind != "jump"
	var move_during := false
	var move_speed := 0.0
	var move_dir := Vector3.ZERO
	if kind == "dodge" or "dodge" in key.to_lower() or "backflip" in key.to_lower() or "flip" in key.to_lower():
		move_during = true
		move_speed = run_speed
		move_dir = -global_transform.basis.z
		rm = false
	var seek_to := 0.0
	if use_combo_seek and seek_cache != null and _act.get("kind") == "attack" and kind == "attack":
		seek_to = seek_cache.get_seek(String(_act.get("key", "")), key)
	if seek_to > 0.0 and pose_offset != null and rig != null and rig.skeleton != null and db.anims.has(key):
		pose_offset.decay_time = combo_seek_decay
		pose_offset.capture(rig.skeleton, db.anims[key], seek_to, ComboSeekCache.BONES)
	_act = {"active": true, "key": key, "kind": kind, "full": full, "start": _now(), "len": length,
		"anim": anim, "cancel": cancel, "locks": locks, "rm": rm, "prev_t": 0.0, "hit_done": false,
		"moving_at_start": moving, "seek_offset": seek_to,
		"move_during": move_during, "move_speed": move_speed, "move_dir": move_dir}
	_queued_attack = false
	rig.play_action(key, full, 0.12, 0.2, seek_to)
	if kind == "attack" or kind == "special":
		_face_yaw_override = _yaw
		_face_until = _now() + 0.25
	if kind == "dodge":
		var dir := _input_world_dir()
		if dir != Vector3.ZERO:
			_face_yaw_override = atan2(-dir.x, -dir.z)
			_face_until = _now() + 0.12
	return true


func _act_frac() -> float:
	if not _act.get("active", false):
		return 1.0
	var elapsed: float = (_now() - _act.start) * anim_speed + float(_act.get("seek_offset", 0.0))
	return clampf(elapsed / maxf(_act.len, 0.01), 0.0, 1.5)


func _input_world_dir() -> Vector3:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
	if v.length() < 0.1:
		return Vector3.ZERO
	return (Basis(Vector3.UP, _yaw) * Vector3(v.x, 0, v.y)).normalized()


# -----------------------------------------------------------------------------
# Loop físico
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if locked_target != null and not is_instance_valid(locked_target):
		locked_target = null
	_update_camera(delta)
	if rig.tree == null:
		return

	# bloqueio (segurar F): pose de cima independente
	var want_block: bool = Input.is_physical_key_pressed(KEY_F) and roles.get("block", "") != "" and split_independent
	if want_block != _blocking:
		_blocking = want_block
		rig.set_stance(roles.block if _blocking else "")

	var gs := maxf(anim_speed, 0.05)
	rig.set_global_speed(gs)
	var world_dir := _input_world_dir()
	var has_input := world_dir != Vector3.ZERO
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	aim_mode = _is_ranged_weapon()

	# ---- ação em andamento ----
	var locked := false
	var locked_full := false
	var rm_vel := Vector3.ZERO
	if _act.get("active", false):
		var frac := _act_frac()
		var el: float = _now() - _act.start
		if _act.locks and frac < _act.cancel:
			locked = true
			locked_full = _act.full
		elif _act.locks and frac >= _act.cancel and has_input and _act.kind in ["attack", "special", "dodge"]:
			rig.stop_actions()    # cancelado por movimento
			_end_action()
		if _act.get("active", false) and locked and _act.rm:
			var t1 := minf(el * gs, (_act.anim as Animation).length)
			var d := LabAnimDB.root_delta(_act.anim, _act.prev_t, t1)
			_act.prev_t = t1
			var local := Vector3(-d.x, 0, -d.y)
			rm_vel = (global_transform.basis * local) / maxf(delta, 0.0001)
		elif _act.get("active", false) and locked and _act.kind == "dodge" and not _act.rm:
			var dodge_speed := maxf(cur_speed, run_speed)
			var dirv: Vector3
			if _act.get("moving_at_start", false):
				dirv = -global_transform.basis.z
			else:
				dirv = global_transform.basis.z
			rm_vel = dirv * dodge_speed * (1.0 - clampf(frac, 0.0, 1.0))
		# golpe acerta no meio da animação
		if _act.get("active", false) and _act.kind in ["attack", "special"] and not _act.hit_done and frac > 0.35:
			_act.hit_done = true
			if db.info(_act.key).cat == LabAnimDB.Cat.ATTACK:
				_do_hit()
		# combo: entra o próximo golpe
		if _act.get("active", false) and _act.kind == "attack" and _queued_attack and frac >= 1.0:
			_last_attack_end = _now()
			combo_idx = (combo_idx + 1) % maxi(chain.size(), 1)
			combo_count += 1
			trigger_clip(chain[combo_idx], "auto", "attack")
			return
		if _act.get("active", false) and frac >= 1.0:
			if _act.kind == "attack":
				_last_attack_end = _now()
				combo_idx = (combo_idx + 1) % maxi(chain.size(), 1)
			_end_action()

	# ---- orientação ----
	var face_cam := strafe_mode or aim_mode or Input.is_physical_key_pressed(KEY_ALT)
	if locked_target != null and is_instance_valid(locked_target):
		var to_t := locked_target.global_position - global_position
		to_t.y = 0.0
		if to_t.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-to_t.x, -to_t.z), 1.0 - exp(-14.0 * delta))
			face_cam = false
	var now := _now()
	if not is_nan(_face_yaw_override) and now < _face_until:
		rotation.y = lerp_angle(rotation.y, _face_yaw_override, 1.0 - exp(-24.0 * delta))
	elif locked:
		pass
	elif face_cam:
		rotation.y = lerp_angle(rotation.y, _yaw, 1.0 - exp(-14.0 * delta))
	elif has_input:
		rotation.y = lerp_angle(rotation.y, atan2(-world_dir.x, -world_dir.z), 1.0 - exp(-12.0 * delta))

	# ---- locomoção ----
	var moving_input := has_input and not locked_full
	var slot := "idle"
	var target_speed := 0.0
	var ts := 1.0
	if moving_input:
		var dirname := "f"
		if face_cam:
			var local := global_transform.basis.inverse() * world_dir
			var ang := rad_to_deg(atan2(-local.x, -local.z))
			dirname = LabAnimDB.DIR_BY_IDX[clampi(int(roundf(ang / 45.0)), -4, 4)]
			var prev_idx := _dir_to_angle(cur_dir)
			if absf(angle_difference(deg_to_rad(prev_idx), deg_to_rad(ang))) < deg_to_rad(31.0):
				dirname = cur_dir
		cur_dir = dirname
		slot = "%s_%s" % ["run" if running else "walk", dirname]
		var e: Dictionary = slots.get(slot, {})
		var native: float = maxf(e.get("speed", 2.0), 0.3)
		var scale: float = e.get("scale", 1.0)
		var clip_native := native / maxf(scale, 0.01)
		target_speed = native if sync_speed else (run_speed if running else walk_speed)
		ts = clampf(target_speed / clip_native, 0.35, 2.5)
	cur_slot = slot
	cur_speed = move_toward(cur_speed, target_speed, 28.0 * delta)
	if not moving_input and not locked_full:
		cur_speed = move_toward(cur_speed, 0.0, 40.0 * delta)
	rig.set_loco(slot if moving_input or cur_speed < 0.3 else slot, ts)

	var hvel := Vector3.ZERO
	if _act.get("active", false) and bool(_act.get("move_during", false)):
		hvel = (_act.get("move_dir", Vector3.ZERO) as Vector3) * float(_act.get("move_speed", 0.0))
	elif locked and rm_vel != Vector3.ZERO:
		hvel = rm_vel
	elif moving_input:
		hvel = world_dir * cur_speed
	elif is_on_floor():
		hvel = Vector3.ZERO
	else:
		hvel = Vector3(velocity.x, 0, velocity.z)
	velocity.x = hvel.x
	velocity.z = hvel.z

	# ---- vertical ----
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if _jump_timer >= 0.0:
		_jump_timer -= delta
		if _jump_timer < 0.0 and is_on_floor():
			velocity.y = jump_velocity
	move_and_slide()
	if pose_offset != null:
		pose_offset.apply(delta)
	status_changed.emit()


func _dir_to_angle(d: String) -> float:
	for k in LabAnimDB.DIR_BY_IDX:
		if LabAnimDB.DIR_BY_IDX[k] == d:
			return k * 45.0
	return 0.0


func _end_action() -> void:
	_act = {"active": false}
	_queued_attack = false


func _do_hit() -> void:
	var fwd := -global_transform.basis.z
	for d in get_tree().get_nodes_in_group("dummies"):
		var to: Vector3 = d.global_position - global_position
		to.y = 0
		if to.length() < 2.6 and fwd.dot(to.normalized()) > 0.3:
			d.call("hit", combo_idx)
			combo_count += 0


## Vitrine: posiciona a câmera de frente/costas/rosto/pés do personagem
func set_focus(which: String) -> void:
	var front := rotation.y + PI          # câmera na frente do personagem
	match which:
		"face":
			cam_height = 1.88 * look.body.u if look.body else 1.88
			_cam_len_target = 1.4
			_yaw = front
			_pitch = 0.0
		"back":
			cam_height = 1.0
			_cam_len_target = 4.2
			_yaw = front + PI
			_pitch = -0.12
		"feet":
			cam_height = 0.35
			_cam_len_target = 2.0
			_yaw = front
			_pitch = -0.12
		_:
			cam_height = 0.95
			_cam_len_target = 3.4
			_yaw = front
			_pitch = -0.1


func set_showcase(on: bool) -> void:
	showcase = on
	if fill_light:
		fill_light.visible = on
	if on:
		set_focus("body")
	else:
		cam_height = 1.5
		_cam_len_target = 4.2
		auto_rotate = false


func _update_camera(delta: float) -> void:
	if showcase and auto_rotate and (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT) == 0:
		_yaw += delta * 0.7
	if _cam_len_target > 0.0:
		spring.spring_length = lerpf(spring.spring_length, _cam_len_target, 1.0 - exp(-8.0 * delta))
		if absf(spring.spring_length - _cam_len_target) < 0.02:
			_cam_len_target = -1.0
	# Distância da câmera por modo (RE over-shoulder / mira / lock-on)
	var target_len := 2.6
	if aim_mode:
		target_len = 1.8
	elif locked_target != null and is_instance_valid(locked_target):
		target_len = 3.0
	if _cam_len_target < 0.0:
		spring.spring_length = lerpf(spring.spring_length, target_len, 1.0 - exp(-8.0 * delta))
	# Lock-on: aponta a câmera para o alvo
	if locked_target != null and is_instance_valid(locked_target):
		var to_t := locked_target.global_position - (global_position + Vector3(0, cam_height, 0))
		_yaw = atan2(-to_t.x, -to_t.z)
		_pitch = clampf(-atan2(to_t.y, Vector2(to_t.x, to_t.z).length()), -0.6, 0.4)
	cam_pivot.global_position = cam_pivot.global_position.lerp(global_position + Vector3(0, cam_height, 0), 1.0 - exp(-16.0 * delta))
	cam_pivot.rotation = Vector3(_pitch, _yaw, 0)


# -----------------------------------------------------------------------------
func debug_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Loadout: %s%s" % [loadout.get("name", "-"), "  [strafe]" if strafe_mode else ""])
	var e: Dictionary = slots.get(cur_slot, {})
	lines.append("Baixo (pernas): %s → %s%s" % [cur_slot, String(e.get("key", "-")).get_slice("/", 1), " (reverso)" if e.get("rev", false) else ""])
	if _blocking:
		lines.append("Cima: bloqueio (segurando F)")
	if _act.get("active", false):
		lines.append("Ação: %s  [%s]  %d%%  tipo=%s%s" % [String(_act.key).get_slice("/", 1), "CORPO TODO" if _act.full else "SÓ CIMA", int(_act_frac() * 100), _act.kind, "  +root motion" if _act.rm else ""])
	else:
		lines.append("Ação: —")
	lines.append("Velocidade: %.1f m/s   Combo: golpe %d/%d" % [cur_speed, combo_idx + 1, chain.size()])
	if _act.get("seek_offset", 0.0) > 0.0:
		lines.append("Seek: +%.2fs no combo  |  offset ativo: %s" % [_act.seek_offset, "sim" if pose_offset and pose_offset.active else "não"])
	return "\n".join(lines)
