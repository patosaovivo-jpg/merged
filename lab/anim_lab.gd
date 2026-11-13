extends Node3D
## =============================================================================
## ANIM LAB — arena de testes de animações do Mixamo com corpo dividido
## Abra lab/anim_lab.tscn e aperte F6 (Executar cena atual).
## =============================================================================

const CFG_PATH := "user://anim_lab_config.cfg"
const ANIM_ROOTS := ["res://ANIMATIONS"]
const CHARACTER_DIRS := ["res://characters"]

var db := LabAnimDB.new()
var player: LabPlayer
var ui: LabUI
var loading: Label
var characters: Array = []
var _save_pending := false


func _ready() -> void:
	_build_world()
	loading = Label.new()
	loading.position = Vector2(30, 30)
	loading.add_theme_font_size_override("font_size", 22)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(loading)
	add_child(layer)
	loading.text = "Carregando animações..."
	await get_tree().process_frame
	await _load_db(false)
	_start()
	layer.queue_free()


func _load_db(force: bool) -> void:
	await db.load_all(ANIM_ROOTS, force, func(done, total, path):
		loading.text = "Carregando animações... %d / %d\n%s" % [done, total, path.get_file()])


func _scan_characters() -> Array:
	var out: Array = []
	for dir in CHARACTER_DIRS:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			var nm := f.trim_suffix(".import")
			if nm.get_extension().to_lower() in ["fbx", "glb", "gltf"] and not out.has(dir.path_join(nm)):
				out.append(dir.path_join(nm))
	out.sort()
	return out


func _start() -> void:
	if db.entries.is_empty():
		loading = Label.new()
		var l := Label.new()
		l.text = "Nenhuma animação encontrada em res://ANIMATIONS.\nCopie as pastas de FBX do Mixamo (Great Sword Pack, Rifle 8-Way..., etc.) para lá e rode de novo."
		l.position = Vector2(30, 30)
		l.add_theme_font_size_override("font_size", 22)
		var cl := CanvasLayer.new()
		cl.add_child(l)
		add_child(cl)
		return
	characters = _scan_characters()
	if characters.is_empty():
		push_error("Nenhum personagem em res://characters")
		return
	player = LabPlayer.new()
	player.name = "Player"
	player.db = db
	add_child(player)
	player.global_position = Vector3(0, 0.05, 0)
	ui = LabUI.new()
	add_child(ui)
	var cfg := _load_cfg()
	var char_path: String = cfg.get("char", "")
	if not characters.has(char_path):
		char_path = characters[0]
		for c in characters:
			if String(c).get_file().begins_with("macho"):
				char_path = c
	player.load_character(char_path)
	ui.build(db, player, characters)
	ui.select_character(char_path)
	ui.reload_requested.connect(_on_reload)
	ui.config_changed.connect(_queue_save)
	player.look.changed.connect(_queue_save)
	player.equip_loadout(cfg.get("loadout", "greatsword"), false)
	_apply_cfg(cfg)
	ui.refresh_from_player()


func _on_reload() -> void:
	var cur_char: String = characters[ui._char_opt.selected] if ui else ""
	var lo_id: String = player.loadout.id
	loading = Label.new()
	loading.position = Vector2(30, 30)
	loading.add_theme_font_size_override("font_size", 22)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(loading)
	add_child(layer)
	await _load_db(true)
	layer.queue_free()
	player.db = db
	ui.queue_free()
	ui = LabUI.new()
	add_child(ui)
	player.load_character(cur_char)
	ui.build(db, player, characters)
	ui.select_character(cur_char)
	ui.reload_requested.connect(_on_reload)
	ui.config_changed.connect(_queue_save)
	player.equip_loadout(lo_id, false)


# -----------------------------------------------------------------------------
# configuração salva
# -----------------------------------------------------------------------------
func _load_cfg() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return {}
	var d := {}
	for k in cf.get_section_keys("main"):
		d[k] = cf.get_value("main", k)
	return d


func _apply_cfg(d: Dictionary) -> void:
	player.sync_speed = d.get("sync", true)
	player.use_root_motion = d.get("rm", true)
	player.split_independent = d.get("split", true)
	player.combo_window = d.get("combo_window", 0.5)
	player.move_cancel = d.get("move_cancel", 0.7)
	player.mouse_sens = d.get("sens", 0.003)
	player.use_combo_seek = d.get("use_combo_seek", true)
	player.combo_seek_decay = d.get("combo_seek_decay", 0.10)
	if player.pose_offset != null:
		player.pose_offset.decay_time = player.combo_seek_decay
	var bl: Array = d.get("binds", [])
	for i in mini(bl.size(), 8):
		if bl[i].get("user", false) and db.has(bl[i].get("key", "")):
			player.binds[i] = bl[i]
		elif bl[i].get("user", false) and bl[i].get("key", "") == "":
			player.binds[i] = bl[i]
	var ro: Dictionary = d.get("roles", {})
	for r in ro:
		if db.has(ro[r]):
			player.role_override[r] = ro[r]
			player.roles[r] = ro[r]
	player.chain_override = d.get("chains", {})
	player.slot_overrides = d.get("slots", {})
	player.weapon_overrides = d.get("weapon_overrides", {})
	if d.has("look") and d["look"] is Dictionary:
		player.look.from_dict(d["look"])
		player.look.apply_all()
		if ui.visual_tab:
			ui.visual_tab.refresh()
	player.aim_fov = d.get("aim_fov", 40.0)
	player.aim_sens_mult = d.get("aim_sens_mult", 0.4)
	if player.aim_sys:
		player.aim_sys.max_range = d.get("aim_range", 60.0)
	if player.lock_on:
		player.lock_on.max_range = d.get("lock_max_range", 20.0)
		player.lock_on.cam_speed = d.get("lock_cam_speed", 6.0)
		var col_str: String = d.get("lock_indicator_color", "#ffe533")
		player.lock_on.indicator_color = Color.html(col_str)
		player.lock_on.set_indicator_color(player.lock_on.indicator_color)
	player.equip_loadout(player.loadout.id, false)
	player.strafe_mode = player.loadout.get("strafe", false)
	ui.refresh_from_player()


func _queue_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	await get_tree().create_timer(0.5).timeout
	_save_pending = false
	var cf := ConfigFile.new()
	var s := "main"
	cf.set_value(s, "char", characters[ui._char_opt.selected])
	cf.set_value(s, "loadout", player.loadout.id)
	cf.set_value(s, "sync", player.sync_speed)
	cf.set_value(s, "rm", player.use_root_motion)
	cf.set_value(s, "split", player.split_independent)
	cf.set_value(s, "combo_window", player.combo_window)
	cf.set_value(s, "move_cancel", player.move_cancel)
	cf.set_value(s, "sens", player.mouse_sens)
	cf.set_value(s, "use_combo_seek", player.use_combo_seek)
	cf.set_value(s, "combo_seek_decay", player.combo_seek_decay)
	cf.set_value(s, "aim_fov", player.aim_fov)
	cf.set_value(s, "aim_sens_mult", player.aim_sens_mult)
	if player.aim_sys:
		cf.set_value(s, "aim_range", player.aim_sys.max_range)
	if player.lock_on:
		cf.set_value(s, "lock_max_range", player.lock_on.max_range)
		cf.set_value(s, "lock_cam_speed", player.lock_on.cam_speed)
		cf.set_value(s, "lock_indicator_color", player.lock_on.indicator_color.to_html())
	cf.set_value(s, "binds", player.binds)
	cf.set_value(s, "roles", player.role_override)
	cf.set_value(s, "chains", player.chain_override)
	cf.set_value(s, "slots", player.slot_overrides)
	cf.set_value(s, "weapon_overrides", player.weapon_overrides)
	cf.set_value(s, "look", player.look.config)
	cf.save(CFG_PATH)


# -----------------------------------------------------------------------------
# mundo
# -----------------------------------------------------------------------------
func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.4, 0.65)
	sm.sky_horizon_color = Color(0.65, 0.72, 0.8)
	sm.ground_horizon_color = Color(0.5, 0.52, 0.55)
	sm.ground_bottom_color = Color(0.25, 0.26, 0.28)
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.78, 0.8)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	mi.mesh = plane
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var c := Color(0.30, 0.32, 0.34) if ((x / 32 + y / 32) % 2 == 0) else Color(0.24, 0.26, 0.28)
			if x % 32 == 0 or y % 32 == 0:
				c = Color(0.14, 0.15, 0.16)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(40, 40, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.9
	mi.material_override = mat
	floor_body.add_child(mi)
	add_child(floor_body)

	# referências de escala: bonecos de treino e alguns blocos
	for p in [Vector3(0, 0, -4), Vector3(3.5, 0, -6), Vector3(-3.5, 0, -6)]:
		var d := LabDummy.new()
		add_child(d)
		d.position = p
	for b in [[Vector3(7, 0.5, 2), Vector3(2, 1, 2)], [Vector3(-8, 1, 0), Vector3(2, 2, 4)], [Vector3(6, 0.25, -3), Vector3(3, 0.5, 3)]]:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		sb.add_child(cs)
		var bm := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = b[1]
		bm.mesh = bmesh
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.5, 0.45, 0.4)
		bm.material_override = m2
		sb.add_child(bm)
		add_child(sb)
		sb.position = b[0]
