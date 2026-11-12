class_name LabLook
extends RefCounted
## =============================================================================
## CRIADOR VISUAL: configuração do personagem (cores, roupas, rosto, cabelo, extras,
## proporções), aplicação no corpo/esqueleto atual, aleatório e salvar/carregar.
## Tudo fica preso ao esqueleto => TODO o sistema de animação continua funcionando.
## =============================================================================

signal changed

const SAVE_DIR_RES := "res://lab/personagens"
const SAVE_DIR_USER := "user://personagens"

const SKIN := ["dfd2c8", "ffe4d1", "ffc399", "ebc2a6", "e2c1aa", "ffcba7", "ffba8a", "e19d66", "bf7942", "935d34", "6d4425", "4a2f1b"]
const EYE_COL := ["0b0908", "21140a", "4e2e18", "5d5737", "1c4522", "144954", "2d393f", "5a7fc0"]
const LIP_COL := ["a44c2e", "994220", "e26060", "de4d4d", "ca3636", "881919", "6b3a30"]
const HAIR_COL := ["adadad", "e1dd78", "d45d2e", "92562b", "6a4830", "2a221f", "531103", "353535", "141414", "c33a7a", "3a6bd4"]
const CLOTH_COL := ["d2d2d2", "3c3c3c", "a82020", "5d8f1b", "1b4c07", "142835", "204760", "3b7d7f", "b6b01a", "68820b", "aa1a02", "8a103b", "6a4a8a", "e08a2c"]
const STYLES := {
	"ESCURO": ["2C3333", "395B64", "A5C9CA", "21353B"],
	"MAL": ["040303", "461111", "A13333", "B3541E"],
	"PAZ": ["F0EBE3", "E4DCCF", "7D9D9C", "576F72"],
	"TERRA": ["87805E", "B09B71", "D8CCA3", "EDDFB3"],
	"FOGO": ["630606", "890F0D", "E83A14", "D9CE3F"],
	"MAR": ["009DAE", "71DFE7", "C2FFF9", "FFE652"],
	"LUZ": ["F4F9F9", "CCF2F4", "A4EBF3", "AAAAAA"],
}

var rig: LabRig
var body: LabBody
var config: Dictionary = {}
var ctx: Dictionary = {}
var _part_nodes := {}      # categoria -> Node3D
var _attach := {}          # osso -> Node3D (espaço de repouso)
var _mats := {}            # categoria -> Material
var _pending_rebuild := false


static func defaults() -> Dictionary:
	return {
		"version": 1,
		"skin": {"color": "ffcba7", "rough": 0.7, "metal": 0.0},
		"shirt": {"on": true, "color": "a82020", "rough": 0.8, "metal": 0.0, "sleeve": 0.45, "hem": 1.10, "neck": 1.70, "volume": 0.010},
		"pants": {"on": true, "color": "204760", "rough": 0.8, "metal": 0.0, "len": 1.0, "volume": 0.008},
		"shoes": {"on": true, "color": "181818", "rough": 0.6, "metal": 0.1, "boot": 0.0, "volume": 0.012},
		"gloves": {"on": false, "color": "2f2f2f", "rough": 0.6, "metal": 0.0, "arm": 0.0, "volume": 0.006},
		"belt": {"on": false, "color": "3a2a1a", "rough": 0.5, "metal": 0.3, "y": 1.14, "volume": 0.004},
		"trim": {"on": true, "color": "e8e8e8", "rough": 0.8, "metal": 0.0},
		"hair": {"style": 2, "color": "6a4830", "rough": 0.5, "metal": 0.0},
		"eyes": {"style": 0, "color": "2d393f", "rough": 0.2, "metal": 0.0},
		"brows": {"style": 1, "color": "6a4830", "rough": 0.6, "metal": 0.0, "link": true},
		"mouth": {"style": 1, "color": "a44c2e", "rough": 0.3, "metal": 0.0},
		"nose": {"style": 1},
		"ears": {"style": 1},
		"beard": {"style": 0, "color": "6a4830", "rough": 0.6, "metal": 0.0, "link": true},
		"glasses": {"style": 0, "color": "222222", "rough": 0.3, "metal": 0.6},
		"hat": {"style": 0, "color": "3c3c3c", "rough": 0.7, "metal": 0.0},
		"shoulders": {"style": 0, "color": "5a4a3a", "rough": 0.5, "metal": 0.4},
		"back": {"style": 0, "color": "6a4a2a", "rough": 0.7, "metal": 0.0},
		"waist": {"style": 0, "color": "5a3a1a", "rough": 0.7, "metal": 0.0},
		"neck": {"style": 0, "color": "a82020", "rough": 0.8, "metal": 0.0},
		"body": {"height": 1.0, "chest": 1.0, "arms": 1.0, "legs": 1.0, "head": 1.0},
	}


func _init() -> void:
	config = defaults()


# -----------------------------------------------------------------------------
# ligação com o rig atual
# -----------------------------------------------------------------------------
func bind(p_rig: LabRig) -> void:
	rig = p_rig
	_part_nodes.clear()
	_attach.clear()
	_mats.clear()
	body = LabBody.new()
	if rig == null or rig.skeleton == null or not body.bind(rig.skeleton):
		body = null
		return
	body.apply_data()
	_make_ctx()
	apply_all()


func _make_ctx() -> void:
	var hb := body.head_aabb
	ctx = {
		"hb": hb, "hc": hb.get_center(), "hx": hb.size.x * 0.5, "hy": hb.size.y * 0.5, "hz": hb.size.z * 0.5,
		"top": hb.end.y, "bottom": hb.position.y, "u": body.u,
		"face_z": Callable(body, "front_z"),
	}


func get_cfg(cat: String, key: String, default = null):
	return config.get(cat, {}).get(key, default)


## muda um valor e atualiza só o necessário
func set_value(cat: String, key: String, value) -> void:
	if not config.has(cat):
		config[cat] = {}
	config[cat][key] = value
	if body == null:
		return
	match cat:
		"skin", "shirt", "pants", "shoes", "gloves", "belt", "trim":
			_apply_body_material()
			if cat == "skin" and key == "color":
				_rebuild("nose")
				_rebuild("ears")
		"body":
			_apply_proportions()
		"hair":
			if key == "style":
				_apply_body_material()
				_rebuild("hair")
			else:
				_update_part_mat("hair")
				_update_linked()
		_:
			if key == "style":
				_rebuild(cat)
			else:
				_update_part_mat(cat)
	changed.emit()


func apply_all() -> void:
	if body == null:
		return
	_apply_body_material()
	for cat in LabParts.CATALOG:
		_rebuild(cat)
	_apply_proportions()
	changed.emit()


# -----------------------------------------------------------------------------
# corpo (shader)
# -----------------------------------------------------------------------------
func _col(cat: String) -> Color:
	return Color(String(config[cat].get("color", "ffffff")))


func _apply_body_material() -> void:
	var m := body.material
	var u := body.u
	var slots := ["skin", "shirt", "pants", "shoes", "gloves", "hair", "trim", "belt"]
	for i in slots.size():
		var c: Dictionary = config[slots[i]]
		m.set_shader_parameter("col%d" % i, Color(String(c.color)))
		m.set_shader_parameter("mr%d" % i, Vector2(c.get("rough", 0.6), c.get("metal", 0.0)))
	var sh: Dictionary = config.shirt
	var pa: Dictionary = config.pants
	var sw: Dictionary = config.shoes
	var gl: Dictionary = config.gloves
	var bl: Dictionary = config.belt
	m.set_shader_parameter("infl_a", Vector4(0.0, sh.volume * u, pa.volume * u, sw.volume * u))
	m.set_shader_parameter("infl_b", Vector4(gl.volume * u, 0.003 * u, 0.0, bl.volume * u))
	m.set_shader_parameter("shirt_on", sh.on)
	m.set_shader_parameter("pants_on", pa.on)
	m.set_shader_parameter("shoes_on", sw.on)
	m.set_shader_parameter("gloves_on", gl.on)
	m.set_shader_parameter("belt_on", bl.on)
	m.set_shader_parameter("trim_on", config.trim.on)
	m.set_shader_parameter("sleeve", sh.sleeve)
	m.set_shader_parameter("hem", sh.hem * u)
	m.set_shader_parameter("neck_cut", sh.neck * u)
	m.set_shader_parameter("pants_len", pa.len)
	m.set_shader_parameter("boot", sw.boot)
	m.set_shader_parameter("glove_arm", gl.arm)
	m.set_shader_parameter("belt_y", bl.y * u)
	m.set_shader_parameter("scalp_style", LabParts.HAIR_SCALP[clampi(int(config.hair.style), 0, LabParts.HAIR.size() - 1)])
	m.set_shader_parameter("trim_w", 0.014 * u)


# -----------------------------------------------------------------------------
# proporções (escala de ossos; as animações não têm tracks de escala)
# -----------------------------------------------------------------------------
func _bone_scale(name: String, s: Vector3) -> void:
	var i := rig.skeleton.find_bone("mixamorig_" + name)
	if i >= 0:
		rig.skeleton.set_bone_pose_scale(i, s)


func _apply_proportions() -> void:
	if rig == null or rig.skeleton == null:
		return
	var b: Dictionary = config.body
	rig.model.scale = Vector3.ONE * rig.model_scale * float(b.height)
	_bone_scale("Head", Vector3.ONE * float(b.head))
	var c := float(b.chest)
	_bone_scale("Spine1", Vector3(c, 1, c))
	_bone_scale("Neck", Vector3(1.0 / c, 1, 1.0 / c))     # o pescoço/cabeça não acompanham o peito
	var a := float(b.arms)
	for side in ["Left", "Right"]:
		_bone_scale(side + "Arm", Vector3(a, 1.0 / c, a))
	var l := float(b.legs)
	for side in ["Left", "Right"]:
		_bone_scale(side + "UpLeg", Vector3(l, 1, l))


# -----------------------------------------------------------------------------
# peças
# -----------------------------------------------------------------------------
func _space(bone: String) -> Node3D:
	if _attach.has(bone) and is_instance_valid(_attach[bone]):
		return _attach[bone]
	var sk := rig.skeleton
	var bi := sk.find_bone("mixamorig_" + bone)
	if bi < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "Look_" + bone
	sk.add_child(att)
	att.bone_name = "mixamorig_" + bone
	var space := Node3D.new()
	att.add_child(space)
	space.transform = sk.get_bone_global_rest(bi).affine_inverse()   # filhos em coordenadas de repouso
	_attach[bone] = space
	return space


func _part_color(cat: String) -> Color:
	var c: Dictionary = config[cat]
	if cat in ["brows", "beard"] and c.get("link", true):
		return Color(String(config.hair.color))
	if cat in ["nose", "ears"]:
		return Color(String(config.skin.color))
	return Color(String(c.get("color", "ffffff")))


func _make_mat(cat: String) -> StandardMaterial3D:
	var c: Dictionary = config[cat]
	var rough := float(c.get("rough", 0.6))
	var metal := float(c.get("metal", 0.0))
	if cat in ["nose", "ears"]:
		rough = float(config.skin.rough)
		metal = float(config.skin.metal)
	return LabParts.mat(_part_color(cat), rough, metal, cat in ["hat"])


func _rebuild(cat: String) -> void:
	if body == null or not config.has(cat):
		return
	if _part_nodes.has(cat) and is_instance_valid(_part_nodes[cat]):
		var old: Node = _part_nodes[cat]
		if old.has_meta("pads"):
			for p in old.get_meta("pads"):
				if is_instance_valid(p):
					p.get_parent().remove_child(p)
					p.free()
			old.free()
		else:
			old.get_parent().remove_child(old)
			old.free()
	_part_nodes.erase(cat)
	var style := int(config[cat].get("style", 0))
	if style <= 0:
		return
	var m := _make_mat(cat)
	_mats[cat] = m
	var extra := {}
	if cat == "shoulders":
		var sk := rig.skeleton
		for side in ["Left", "Right"]:
			extra[side] = sk.get_bone_global_rest(sk.find_bone("mixamorig_%sArm" % side)).origin
	if cat == "shoulders":
		_build_shoulders(cat, style, m, extra)
		return
	var node := LabParts.build(cat, style, m, ctx, extra)
	if node == null:
		return
	var bone: String = LabParts.BONE.get(cat, "Spine2")
	var space := _space(bone)
	if space == null:
		node.free()
		return
	space.add_child(node)
	_part_nodes[cat] = node


func _build_shoulders(cat: String, style: int, m: Material, extra: Dictionary) -> void:
	# ombreiras: uma por braço, para acompanhar o movimento do braço
	var holder := Node3D.new()      # só para rastrear/remover; as peças ficam nos braços
	var pads: Array = []
	for side in ["Left", "Right"]:
		var space := _space(side + "Arm")
		if space == null:
			continue
		var pad := LabParts.build_shoulder_side(side, style, m, ctx, extra[side])
		if pad:
			space.add_child(pad)
			pads.append(pad)
	holder.set_meta("pads", pads)
	_part_nodes[cat] = holder


func _update_part_mat(cat: String) -> void:
	if _mats.has(cat) and is_instance_valid(_mats[cat]):
		var m := _mats[cat] as StandardMaterial3D
		m.albedo_color = _part_color(cat)
		m.roughness = float(config[cat].get("rough", 0.6))
		m.metallic = float(config[cat].get("metal", 0.0))


func _update_linked() -> void:
	for cat in ["brows", "beard"]:
		_update_part_mat(cat)


# -----------------------------------------------------------------------------
# aleatório (no espírito do criador de referência)
# -----------------------------------------------------------------------------
static func _pick(arr: Array, rng: RandomNumberGenerator):
	return arr[rng.randi() % arr.size()]


static func _hexcolor_variation(hex: String, rng: RandomNumberGenerator) -> String:
	var c := Color(hex)
	c.r = clampf(c.r + 0.05 - 0.1 * rng.randf(), 0, 1)
	c.g = clampf(c.g + 0.05 - 0.1 * rng.randf(), 0, 1)
	c.b = clampf(c.b + 0.05 - 0.1 * rng.randf(), 0, 1)
	return c.to_html(false)


func randomize_look(seed_value := -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var cfg := defaults()
	var style_name: String = _pick(STYLES.keys(), rng)
	var pal: Array = STYLES[style_name]
	var cc := func(): return _hexcolor_variation(_pick(pal, rng), rng)
	cfg.skin.color = _pick(SKIN, rng)
	var hair_c: String = _pick(HAIR_COL, rng)
	cfg.hair.color = hair_c
	cfg.hair.style = 0 if rng.randf() < 0.08 else rng.randi_range(1, LabParts.HAIR.size() - 1)
	cfg.brows.style = rng.randi_range(1, LabParts.BROWS.size() - 1)
	cfg.eyes.style = rng.randi_range(0, LabParts.EYES.size() - 1)
	cfg.eyes.color = _pick(EYE_COL, rng)
	cfg.mouth.style = rng.randi_range(1, LabParts.MOUTH.size() - 1)
	cfg.mouth.color = _pick(LIP_COL, rng)
	cfg.nose.style = rng.randi_range(1, LabParts.NOSE.size() - 1)
	cfg.ears.style = rng.randi_range(1, 2)
	cfg.beard.style = rng.randi_range(1, LabParts.BEARD.size() - 1) if rng.randf() < 0.3 else 0
	cfg.glasses.style = rng.randi_range(1, LabParts.GLASSES.size() - 1) if rng.randf() < 0.25 else 0
	cfg.hat.style = rng.randi_range(1, LabParts.HAT.size() - 1) if rng.randf() < 0.18 else 0
	if cfg.hat.style in [4, 5]:
		cfg.hair.style = 0
	cfg.shirt.color = cc.call()
	cfg.shirt.sleeve = _pick([0.0, 0.25, 0.45, 0.75, 1.0], rng)
	cfg.shirt.hem = _pick([1.0, 1.1, 1.2, 0.9], rng)
	cfg.pants.color = cc.call()
	cfg.pants.len = _pick([0.5, 0.7, 1.0, 1.0], rng)
	cfg.shoes.color = cc.call()
	cfg.shoes.boot = _pick([0.0, 0.0, 0.25, 0.45], rng)
	cfg.trim.color = cc.call()
	cfg.belt.on = rng.randf() < 0.5
	cfg.belt.color = cc.call()
	cfg.gloves.on = rng.randf() < 0.2
	cfg.gloves.color = cc.call()
	cfg.gloves.arm = _pick([0.0, 0.0, 0.3], rng)
	cfg.shoulders.style = rng.randi_range(1, 3) if rng.randf() < 0.25 else 0
	cfg.back.style = rng.randi_range(1, 3) if rng.randf() < 0.25 else 0
	cfg.waist.style = rng.randi_range(1, 2) if rng.randf() < 0.25 else 0
	cfg.neck.style = rng.randi_range(1, 2) if rng.randf() < 0.2 else 0
	for k in ["hat", "shoulders", "back", "waist", "neck"]:
		cfg[k].color = cc.call()
	cfg.body = {"height": snappedf(rng.randf_range(0.92, 1.08), 0.01), "chest": snappedf(rng.randf_range(0.92, 1.1), 0.01),
		"arms": snappedf(rng.randf_range(0.9, 1.15), 0.01), "legs": snappedf(rng.randf_range(0.92, 1.12), 0.01),
		"head": snappedf(rng.randf_range(0.92, 1.1), 0.01)}
	config = cfg
	apply_all()


# -----------------------------------------------------------------------------
# salvar / carregar (JSON legível, como o .npc da referência)
# -----------------------------------------------------------------------------
static func save_dir() -> String:
	var d := SAVE_DIR_RES if OS.has_feature("editor") else SAVE_DIR_USER
	if not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_recursive_absolute(d)
	if not DirAccess.dir_exists_absolute(d):
		d = SAVE_DIR_USER
		DirAccess.make_dir_recursive_absolute(d)
	return d


static func list_saved() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(save_dir())
	if d:
		for f in d.get_files():
			if f.ends_with(".char.json"):
				out.append(f.trim_suffix(".char.json"))
	out.sort()
	return out


func save_to(file_name: String) -> bool:
	var clean := file_name.strip_edges().replace("/", "_").replace("\\", "_")
	if clean == "":
		return false
	var f := FileAccess.open(save_dir().path_join(clean + ".char.json"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(config, "\t"))
	f.close()
	return true


func load_from(file_name: String) -> bool:
	var f := FileAccess.open(save_dir().path_join(file_name + ".char.json"), FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	from_dict(parsed)
	apply_all()
	return true


## mescla com os padrões (campos que faltam no arquivo não quebram) e valida tipos
func from_dict(d: Dictionary) -> void:
	var base := defaults()
	for cat in base:
		if d.has(cat) and d[cat] is Dictionary:
			for k in base[cat]:
				if not d[cat].has(k):
					continue
				var v = d[cat][k]
				var b = base[cat][k]
				if b is bool:
					if v is bool:
						base[cat][k] = v
				elif b is int:
					if v is int or v is float:
						base[cat][k] = int(v)
				elif b is float:
					if v is int or v is float:
						base[cat][k] = float(v)
				elif b is String:
					if v is String:
						base[cat][k] = v
	for cat in LabParts.CATALOG:
		base[cat].style = clampi(int(base[cat].style), 0, LabParts.CATALOG[cat].size() - 1)
	config = base
