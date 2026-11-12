class_name LabRig
extends Node3D
## =============================================================================
## RIG: personagem + AnimationPlayer + AnimationTree com CORPO DIVIDIDO
## -----------------------------------------------------------------------------
##  Loco (Transition: idle + 16 slots) -> LowerTS (velocidade dos pés)
##    -> Split  (Blend2, filtro = ossos de cima: "pose de mira/bloqueio")
##    -> OSU    (OneShot, filtro = ossos de cima: ataques/ações SÓ em cima)
##    -> OSF    (OneShot, sem filtro: ações de CORPO INTEIRO: rolamento, pulo...)
##    -> GlobalTS (velocidade global) -> saída
## Parte de baixo = locomoção. Parte de cima = locomoção até uma ação tocar.
## =============================================================================

const REF_HEIGHT := 1.62   # cabeça - pé (ossos) do macho.fbx, em metros

var db: LabAnimDB
var model: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var tree: AnimationTree
var bt: AnimationNodeBlendTree
var path_map := {}            # key do banco -> "biblioteca/animação"
var model_scale := 1.0
var pos_scale := 1.0
var split_bone := "mixamorig_Spine"
var current_slot := ""
var stance_amount := 0.0
var stance_target := 0.0
var split_enabled := true

var _skel_rel := "Skeleton3D"
var _filtered: Dictionary = {}   # node name -> Array[NodePath]
var _weapon_nodes: Array = []
var _stance_key := ""


func _process(delta: float) -> void:
	if tree == null:
		return
	stance_amount = move_toward(stance_amount, stance_target if split_enabled else 0.0, delta * 9.0)
	tree.set("parameters/Split/blend_amount", stance_amount)


# -----------------------------------------------------------------------------
# Construção
# -----------------------------------------------------------------------------
func load_character(p_db: LabAnimDB, path: String) -> bool:
	db = p_db
	_free_model()
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("LabRig: não consegui carregar " + path)
		return false
	model = ps.instantiate()
	add_child(model)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		push_error("LabRig: personagem sem Skeleton3D")
		return false
	skeleton = sks[0]
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	_fit_scale()
	_build_player()
	_build_tree()
	apply_split()
	return true


func _free_model() -> void:
	_weapon_nodes.clear()
	_filtered.clear()
	if tree != null and is_instance_valid(tree):
		tree.active = false
	if model != null and is_instance_valid(model):
		remove_child(model)
		model.free()
	model = null
	skeleton = null
	anim_player = null
	tree = null
	bt = null
	current_slot = ""
	_stance_key = ""


func _bone_y(name: String) -> float:
	var i := skeleton.find_bone(name)
	return skeleton.get_bone_global_rest(i).origin.y if i >= 0 else 0.0


func _fit_scale() -> void:
	var feet := minf(_bone_y("mixamorig_LeftFoot"), _bone_y("mixamorig_RightFoot"))
	var h := _bone_y("mixamorig_Head") - feet
	model_scale = 1.0
	if h > 0.0001:
		model_scale = REF_HEIGHT / h
	if absf(model_scale - 1.0) < 0.08:
		model_scale = 1.0
	model.scale = Vector3.ONE * model_scale
	pos_scale = 1.0 / model_scale


static func _safe(s: String) -> String:
	return s.replace("/", "-").replace(":", "-").replace(",", ";").replace("[", "(").replace("]", ")")


static func _strip_prefix(bone: String) -> String:
	var b := bone
	if b.begins_with("mixamorig"):
		b = b.substr(9)
		if b.begins_with(":") or b.begins_with("_"):
			b = b.substr(1)
	return b


func _build_player() -> void:
	var parent := skeleton.get_parent()
	anim_player = AnimationPlayer.new()
	anim_player.name = "LabAnimPlayer"
	parent.add_child(anim_player)
	anim_player.root_node = NodePath("..")
	_skel_rel = str(parent.get_path_to(skeleton))
	var bone_by_stripped := {}
	for i in skeleton.get_bone_count():
		bone_by_stripped[_strip_prefix(skeleton.get_bone_name(i))] = skeleton.get_bone_name(i)

	path_map.clear()
	var libs := {}
	for key in db.anims:
		var inf: Dictionary = db.entries[key]
		var a: Animation = (db.anims[key] as Animation).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var ty := a.track_get_type(t)
			if ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_SCALE_3D:
				continue
			var p := String(a.track_get_path(t))
			var c := p.find(":")
			if c < 0:
				continue
			var bone := p.substr(c + 1)
			var mapped: String = bone_by_stripped.get(_strip_prefix(bone), "")
			if mapped == "":
				a.remove_track(t)
				continue
			a.track_set_path(t, NodePath(_skel_rel + ":" + mapped))
			if ty == Animation.TYPE_POSITION_3D and pos_scale != 1.0:
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * pos_scale)
		var ln := _safe(inf.pack)
		if not libs.has(ln):
			libs[ln] = AnimationLibrary.new()
		var an := _safe(inf.name)
		while (libs[ln] as AnimationLibrary).has_animation(an):
			an += "_"
		(libs[ln] as AnimationLibrary).add_animation(an, a)
		path_map[key] = "%s/%s" % [ln, an]
	for ln in libs:
		anim_player.add_animation_library(ln, libs[ln])


func _build_tree() -> void:
	var slots := LabLoadouts.slot_names()
	bt = AnimationNodeBlendTree.new()

	var trans := AnimationNodeTransition.new()
	trans.input_count = slots.size()
	trans.xfade_time = 0.18
	trans.allow_transition_to_self = false
	for i in slots.size():
		trans.set_input_name(i, slots[i])
	bt.add_node("Loco", trans)
	for i in slots.size():
		var an := AnimationNodeAnimation.new()
		bt.add_node("S_" + slots[i], an)
		bt.connect_node("Loco", i, "S_" + slots[i])

	bt.add_node("LowerTS", AnimationNodeTimeScale.new())
	bt.connect_node("LowerTS", 0, "Loco")

	bt.add_node("Stance", AnimationNodeAnimation.new())
	var split := AnimationNodeBlend2.new()
	split.filter_enabled = true
	bt.add_node("Split", split)
	bt.connect_node("Split", 0, "LowerTS")
	bt.connect_node("Split", 1, "Stance")

	bt.add_node("ActU", AnimationNodeAnimation.new())
	var osu := AnimationNodeOneShot.new()
	osu.filter_enabled = true
	osu.fadein_time = 0.12
	osu.fadeout_time = 0.2
	bt.add_node("OSU", osu)
	bt.connect_node("OSU", 0, "Split")
	bt.connect_node("OSU", 1, "ActU")

	bt.add_node("ActF", AnimationNodeAnimation.new())
	var osf := AnimationNodeOneShot.new()
	osf.filter_enabled = false
	osf.fadein_time = 0.12
	osf.fadeout_time = 0.2
	bt.add_node("OSF", osf)
	bt.connect_node("OSF", 0, "OSU")
	bt.connect_node("OSF", 1, "ActF")

	bt.add_node("GlobalTS", AnimationNodeTimeScale.new())
	bt.connect_node("GlobalTS", 0, "OSF")
	bt.connect_node("output", 0, "GlobalTS")

	tree = AnimationTree.new()
	tree.name = "LabTree"
	skeleton.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	tree.tree_root = bt
	tree.active = true
	tree.set("parameters/Loco/transition_request", "idle")
	current_slot = "idle"


# -----------------------------------------------------------------------------
# Corpo dividido
# -----------------------------------------------------------------------------
func upper_bone_names() -> Array:
	var out: Array = []
	var root := skeleton.find_bone(split_bone)
	if root < 0:
		return out
	for i in skeleton.get_bone_count():
		var p := i
		while p >= 0:
			if p == root:
				out.append(skeleton.get_bone_name(i))
				break
			p = skeleton.get_bone_parent(p)
	return out


func apply_split() -> void:
	if bt == null:
		return
	var upper := upper_bone_names()
	for node_name in ["Split", "OSU"]:
		var n := bt.get_node(node_name) as AnimationNode
		for old in _filtered.get(node_name, []):
			n.set_filter_path(old, false)
		var arr: Array = []
		for b in upper:
			var np := NodePath(_skel_rel + ":" + b)
			n.set_filter_path(np, true)
			arr.append(np)
		_filtered[node_name] = arr
		n.filter_enabled = true


func set_split_bone(bone: String) -> void:
	split_bone = bone
	apply_split()


# -----------------------------------------------------------------------------
# Locomoção / pose de cima / ações
# -----------------------------------------------------------------------------
func assign_slots(slots: Dictionary) -> void:
	for s in LabLoadouts.slot_names():
		var n := bt.get_node("S_" + s) as AnimationNodeAnimation
		if slots.has(s) and path_map.has(slots[s].key):
			n.animation = StringName(path_map[slots[s].key])
			n.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD if slots[s].rev else AnimationNodeAnimation.PLAY_MODE_FORWARD
		else:
			n.animation = &""


func set_loco(slot: String, timescale: float) -> void:
	if tree == null:
		return
	if slot != current_slot:
		current_slot = slot
		tree.set("parameters/Loco/transition_request", slot)
	tree.set("parameters/LowerTS/scale", timescale)


func set_global_speed(s: float) -> void:
	if tree:
		tree.set("parameters/GlobalTS/scale", s)


## Pose da parte de cima (bloqueio, mira...). key "" = solta.
func set_stance(key: String) -> void:
	if tree == null:
		return
	if key == "" or not path_map.has(key):
		stance_target = 0.0
		return
	if key != _stance_key:
		_stance_key = key
		(bt.get_node("Stance") as AnimationNodeAnimation).animation = StringName(path_map[key])
	stance_target = 1.0


func anim_length(key: String) -> float:
	return (db.anims[key] as Animation).length if db.anims.has(key) else 0.0


## Toca um clipe uma vez. full=true: corpo inteiro. false: só parte de cima.
func play_action(key: String, full: bool, fade_in := 0.12, fade_out := 0.2, seek_to := 0.0) -> bool:
	if tree == null or not path_map.has(key):
		return false
	var osu := bt.get_node("OSU") as AnimationNodeOneShot
	var osf := bt.get_node("OSF") as AnimationNodeOneShot
	var fire := AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	var fade := AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
	if full:
		(bt.get_node("ActF") as AnimationNodeAnimation).animation = StringName(path_map[key])
		osf.fadein_time = fade_in
		osf.fadeout_time = fade_out
		tree.set("parameters/OSF/request", fire)
		if osu_active():
			tree.set("parameters/OSU/request", fade)
	else:
		(bt.get_node("ActU") as AnimationNodeAnimation).animation = StringName(path_map[key])
		osu.fadein_time = fade_in
		osu.fadeout_time = fade_out
		tree.set("parameters/OSU/request", fire)
		if osf_active():
			tree.set("parameters/OSF/request", fade)
	if seek_to > 0.0 and anim_player != null:
		await Engine.get_main_loop().process_frame
		anim_player.seek(seek_to, true)
	return true


func stop_actions() -> void:
	if tree == null:
		return
	tree.set("parameters/OSU/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	tree.set("parameters/OSF/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func osu_active() -> bool:
	return tree != null and bool(tree.get("parameters/OSU/active"))


func osf_active() -> bool:
	return tree != null and bool(tree.get("parameters/OSF/active"))


# -----------------------------------------------------------------------------
# Armas
# -----------------------------------------------------------------------------
func equip_weapons(ids: Array) -> void:
	for n in _weapon_nodes:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	_weapon_nodes.clear()
	if skeleton == null:
		return
	for id in ids:
		var d: Dictionary = LabLoadouts.WEAPONS.get(id, {})
		if d.is_empty():
			continue
		var ps := load(d.file) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate()
		for bad in inst.find_children("*", "AnimationPlayer", true, false):
			bad.queue_free()
		var bone := "mixamorig_RightHand" if d.hand == "R" else "mixamorig_LeftHand"
		if skeleton.find_bone(bone) < 0:
			inst.free()
			continue
		var att := BoneAttachment3D.new()
		att.name = "Weapon_" + String(id)
		skeleton.add_child(att)
		att.bone_name = bone
		var wrap := Node3D.new()
		att.add_child(wrap)
		var f := pos_scale
		wrap.scale = Vector3.ONE * float(d.scale) * f
		var r: Vector3 = d.rot
		wrap.basis = Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))) * Basis.from_scale(wrap.scale)
		wrap.position = (d.pos as Vector3) * f
		wrap.add_child(inst)
		if d.get("recenter", true):
			for m in inst.find_children("*", "MeshInstance3D", true, false):
				var chain := m as Node3D
				var off := Vector3.ZERO
				while chain != null and chain != inst:
					off += chain.position
					chain = chain.get_parent() as Node3D
				inst.position = -off
				break
		_weapon_nodes.append(att)
