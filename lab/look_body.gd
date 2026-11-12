class_name LabBody
extends RefCounted
## =============================================================================
## Prepara o corpo de malha única para o shader de roupas por região.
## Lê pesos de pele (CPU skinning na pose de repouso) e guarda por vértice:
## posição de repouso, classe (tronco/braço/perna...) e coordenada ao longo do membro.
## Também mede a cabeça (para posicionar cabelo, olhos, óculos...).
## =============================================================================

const SHADER_PATH := "res://lab/look_body.gdshader"
enum Cls { OTHER, TORSO, PELVIS, ARM, HAND, LEG, HEAD, FOOT }

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var material: ShaderMaterial
var u := 1.0                      # escala do esqueleto relativa a 2.0 m de altura
var head_aabb := AABB()
var rest := PackedVector3Array()
var cls := PackedInt32Array()
var ok := false
var body_top := 2.0


func bind(sk: Skeleton3D) -> bool:
	skeleton = sk
	ok = false
	mesh_instance = null
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).skin != null:
			mesh_instance = c
			break
	if mesh_instance == null:
		return false
	_bake()
	_smooth_mesh()
	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_error("LabBody: shader não encontrado: " + SHADER_PATH)
		return false
	material = ShaderMaterial.new()
	material.shader = shader
	mesh_instance.set_surface_override_material(0, material)
	ok = true
	return true


func _bone_origin(name: String) -> Vector3:
	var i := skeleton.find_bone("mixamorig_" + name)
	return skeleton.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO


static func _group(n: String) -> int:
	if n.begins_with("Head"):
		return Cls.HEAD
	if n == "Neck":
		return Cls.OTHER
	if n.begins_with("Spine") or n.ends_with("Shoulder"):
		return Cls.TORSO
	if n == "Hips":
		return Cls.PELVIS
	if n.contains("Hand"):
		return Cls.HAND
	if n.ends_with("ForeArm") or n.ends_with("Arm"):
		return Cls.ARM
	if n.contains("UpLeg") or n.ends_with("Leg"):
		return Cls.LEG
	if n.contains("Foot") or n.contains("Toe"):
		return Cls.FOOT
	return Cls.OTHER


## parâmetro 0..1 do ponto p ao longo da polilinha a->b->c
static func _along(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var total := maxf(l1 + l2, 0.0001)
	var best_d := 1e20
	var best_t := 0.0
	var pts := [a, b, c]
	var off := 0.0
	for i in 2:
		var s: Vector3 = pts[i]
		var e: Vector3 = pts[i + 1]
		var seg := e - s
		var sl := maxf(seg.length_squared(), 0.000001)
		var f := clampf((p - s).dot(seg) / sl, 0.0, 1.0)
		var d := p.distance_to(s + seg * f)
		if d < best_d:
			best_d = d
			best_t = (off + f * sqrt(sl)) / total
		off += sqrt(sl)
	return best_t


func _bake() -> void:
	var skin := mesh_instance.skin
	var arr := mesh_instance.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var n := verts.size()
	var per := bones.size() / maxi(n, 1)
	var bmap := []
	for i in skin.get_bind_count():
		var bi := skin.get_bind_bone(i)
		if bi < 0:
			bi = skeleton.find_bone(skin.get_bind_name(i))
		bmap.append(bi)
	body_top = _bone_origin("HeadTop_End").y
	u = maxf(body_top, 0.001) / 2.0

	var sides := {
		"Left": [_bone_origin("LeftArm"), _bone_origin("LeftForeArm"), _bone_origin("LeftHand"),
				_bone_origin("LeftUpLeg"), _bone_origin("LeftLeg"), _bone_origin("LeftFoot")],
		"Right": [_bone_origin("RightArm"), _bone_origin("RightForeArm"), _bone_origin("RightHand"),
				_bone_origin("RightUpLeg"), _bone_origin("RightLeg"), _bone_origin("RightFoot")],
	}
	rest.resize(n)
	cls.resize(n)
	var img := Image.create(n, 2, false, Image.FORMAT_RGBAF)
	var head_min := Vector3(1e9, 1e9, 1e9)
	var head_max := Vector3(-1e9, -1e9, -1e9)
	for v in n:
		var p := Vector3.ZERO
		var wsum := 0.0
		var gw := {}
		var side := "Left"
		var best_bw := -1.0
		for k in per:
			var w := wts[v * per + k]
			if w <= 0.0:
				continue
			var bind_i: int = bones[v * per + k]
			var bi: int = bmap[bind_i]
			if bi < 0:
				continue
			var xf := skeleton.get_bone_global_rest(bi) * skin.get_bind_pose(bind_i)
			p += (xf * verts[v]) * w
			wsum += w
			var nm := skeleton.get_bone_name(bi).replace("mixamorig_", "")
			var g := _group(nm)
			gw[g] = gw.get(g, 0.0) + w
			if w > best_bw:
				best_bw = w
				side = "Right" if nm.begins_with("Right") else "Left"
		p /= maxf(wsum, 0.0001)
		var c := Cls.OTHER
		var cw := -1.0
		for g in gw:
			if gw[g] > cw:
				cw = gw[g]
				c = g
		rest[v] = p
		cls[v] = c
		var t := 0.0
		var sd: Array = sides[side]
		if c == Cls.ARM:
			t = _along(p, sd[0], sd[1], sd[2])
		elif c == Cls.LEG:
			t = _along(p, sd[3], sd[4], sd[5])
		img.set_pixel(v, 0, Color(p.x, p.y, p.z, float(c)))
		img.set_pixel(v, 1, Color(t, 0, 0, 0))
		if c == Cls.HEAD:
			head_min = head_min.min(p)
			head_max = head_max.max(p)
	head_aabb = AABB(head_min, head_max - head_min)
	var tex := ImageTexture.create_from_image(img)
	_data_tex = tex


var _data_tex: ImageTexture


## Normais soldadas (média nos vértices coincidentes) => inflar a roupa sem abrir frestas.
## O aspecto facetado (lowpoly) é recuperado no shader por derivadas.
func _smooth_mesh() -> void:
	var arr := mesh_instance.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	if norms.size() != verts.size():
		return
	var sums := {}
	var keys := []
	keys.resize(verts.size())
	for v in verts.size():
		var key := Vector3i((verts[v] * 5000.0).round())
		keys[v] = key
		sums[key] = sums.get(key, Vector3.ZERO) + norms[v]
	var sm := PackedVector3Array()
	sm.resize(verts.size())
	for v in verts.size():
		var n: Vector3 = sums[keys[v]]
		sm[v] = n.normalized() if n.length() > 0.0001 else norms[v]
	arr[Mesh.ARRAY_NORMAL] = sm
	var per := (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(verts.size(), 1)
	var flags := 0
	if per == 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	mesh_instance.mesh = nm


func apply_data() -> void:
	if material == null:
		return
	material.set_shader_parameter("vdata", _data_tex)
	material.set_shader_parameter("head_min", head_aabb.position)
	material.set_shader_parameter("head_max", head_aabb.end)


## Maior z entre os vértices de cabeça perto de (x,y): superfície do rosto.
func front_z(x: float, y: float, rx := 0.03, ry := 0.04) -> float:
	var best := head_aabb.position.z
	for v in rest.size():
		if cls[v] != Cls.HEAD:
			continue
		var p := rest[v]
		if absf(p.x - x) <= rx * u and absf(p.y - y) <= ry * u and p.z > best:
			best = p.z
	return best
