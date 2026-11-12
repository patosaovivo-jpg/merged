class_name LabParts
extends RefCounted
## =============================================================================
## Peças procedurais lowpoly (cabelo, barba, rosto, óculos, chapéu, extras).
## Tudo é construído em coordenadas do ESQUELETO NA POSE DE REPOUSO (metros) a partir
## das medidas da cabeça do personagem, então serve em qualquer corpo Mixamo.
## =============================================================================

const HAIR := ["Nenhum", "Raspado", "Curto", "Topete", "Moicano", "Rabo de cavalo", "Coque", "Longo", "Chanel", "Afro", "Franja"]
# estilo de cabelo -> pintura no crânio (0 nada, 1 raspado, 2 curto, 3 baixo)
const HAIR_SCALP := [0, 1, 2, 2, 1, 2, 2, 3, 3, 0, 2]
const EYES := ["Redondo", "Oval", "Estreito", "Grande", "Bravo", "Sonolento"]
const BROWS := ["Nenhuma", "Reta", "Arqueada", "Grossa", "Brava", "Triste"]
const MOUTH := ["Nenhuma", "Reta", "Sorriso", "Pequena", "Aberta", "Triste"]
const NOSE := ["Nenhum", "Pequeno", "Grande", "Pontudo"]
const EARS := ["Nenhuma", "Pequena", "Grande", "Élfica"]
const BEARD := ["Nenhuma", "Cavanhaque", "Bigode", "Cheia", "Costeleta"]
const GLASSES := ["Nenhum", "Redondo", "Quadrado", "Escuros"]
const HAT := ["Nenhum", "Boné", "Gorro", "Chapéu", "Elmo", "Capuz", "Bandana"]
const SHOULDERS := ["Nenhuma", "Couro", "Placas", "Espinhos"]
const BACK := ["Nenhum", "Mochila", "Capa", "Aljava"]
const WAIST := ["Nenhuma", "Bolsas", "Bolsa grande"]
const NECK := ["Nenhum", "Cachecol", "Colar"]

const CATALOG := {
	"hair": HAIR, "eyes": EYES, "brows": BROWS, "mouth": MOUTH, "nose": NOSE, "ears": EARS,
	"beard": BEARD, "glasses": GLASSES, "hat": HAT, "shoulders": SHOULDERS, "back": BACK,
	"waist": WAIST, "neck": NECK,
}

# osso onde cada categoria é presa
const BONE := {
	"hair": "Head", "eyes": "Head", "brows": "Head", "mouth": "Head", "nose": "Head", "ears": "Head",
	"beard": "Head", "glasses": "Head", "hat": "Head", "back": "Spine2", "waist": "Hips", "neck": "Neck",
}


static func mat(color: Color, rough := 0.6, metal := 0.0, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _mi(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = sc
	return mi


static func box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


static func sph(r: float, hemi := false, segs := 8, rings := 4) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = segs
	s.rings = rings
	return s


static func cyl(rt: float, rb: float, h: float, segs := 8, caps := true) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return c


static func cap_(r: float, h: float, segs := 8) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 2
	return c


static func prism(sz: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = sz
	return p


static func torus(inner: float, outer: float, segs := 10) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = segs
	t.ring_segments = 6
	return t


# ----------------------------------------------------------------------------
# ctx: {hb: AABB, hc: Vector3, hx, hy, hz, top, bottom, face_z: Callable(x,y)->float, u}
# cada builder devolve um Node3D (coordenadas de repouso do esqueleto)
# ----------------------------------------------------------------------------
static func build(cat: String, style: int, m: Material, ctx: Dictionary, extra: Dictionary = {}) -> Node3D:
	if style <= 0:
		return null
	var root := Node3D.new()
	root.name = "Part_" + cat
	match cat:
		"hair": _hair(root, style, m, ctx)
		"eyes": _eyes(root, style, m, ctx, extra)
		"brows": _brows(root, style, m, ctx)
		"mouth": _mouth(root, style, m, ctx)
		"nose": _nose(root, style, m, ctx)
		"ears": _ears(root, style, m, ctx)
		"beard": _beard(root, style, m, ctx)
		"glasses": _glasses(root, style, m, ctx)
		"hat": _hat(root, style, m, ctx)
		"back": _back(root, style, m, ctx)
		"waist": _waist(root, style, m, ctx)
		"neck": _neck(root, style, m, ctx)
	return root


static func _lm(ctx: Dictionary) -> Dictionary:
	# landmarks do rosto em fração da altura da cabeça
	var hb: AABB = ctx.hb
	var bottom: float = hb.position.y
	var h: float = hb.size.y
	return {
		"eye_y": bottom + 0.575 * h, "brow_y": bottom + 0.665 * h, "nose_y": bottom + 0.44 * h,
		"mouth_y": bottom + 0.28 * h, "mid_y": bottom + 0.5 * h, "ear_y": bottom + 0.52 * h,
		"chin_y": bottom + 0.06 * h,
	}


static func _hair(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var hc: Vector3 = ctx.hc
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var top: float = ctx.top
	var bottom: float = ctx.bottom
	var h: float = top - bottom
	var y0 := bottom + 0.50 * h
	var zc := hc.z - 0.016
	var cap_ry := (top - y0) + 0.024
	var _cap := func(extra_r := 0.0, rot_x := -8.0, ry_mul := 1.0):
		var ms := _mi(sph(1.0, true, 10, 5), m, Vector3(hc.x, y0, zc), Vector3(rot_x, 0, 0),
				Vector3(hx + 0.016 + extra_r, cap_ry * ry_mul, hz + 0.034 + extra_r))
		root.add_child(ms)
	match style:
		1:    # raspado: só pintura no crânio
			pass
		2:
			_cap.call()
		3:
			_cap.call()
			root.add_child(_mi(box(Vector3(hx * 1.5, 0.04, 0.09)), m, Vector3(hc.x, top + 0.012, hc.z + hz * 0.38), Vector3(-24, 0, 0)))
		4:
			root.add_child(_mi(box(Vector3(0.035, 0.075, hz * 1.7)), m, Vector3(hc.x, top + 0.008, hc.z - 0.005)))
		5:
			_cap.call()
			root.add_child(_mi(cap_(0.032, 0.22), m, Vector3(hc.x, y0 - 0.03, hc.z - hz - 0.045), Vector3(-25, 0, 0)))
		6:
			_cap.call()
			root.add_child(_mi(sph(0.055, false, 8, 4), m, Vector3(hc.x, top + 0.03, hc.z - 0.06)))
		7:
			_cap.call()
			root.add_child(_mi(box(Vector3(hx * 2.0 + 0.035, 0.34, 0.05)), m, Vector3(hc.x, y0 - 0.17, hc.z - hz + 0.008)))
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.028, 0.22, hz * 1.2)), m, Vector3(hc.x + sx * (hx + 0.008), y0 - 0.1, hc.z - hz * 0.25)))
		8:
			_cap.call()
			root.add_child(_mi(box(Vector3(hx * 2.0 + 0.04, 0.16, 0.06)), m, Vector3(hc.x, y0 - 0.08, hc.z - hz + 0.005)))
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.03, 0.14, hz * 1.3)), m, Vector3(hc.x + sx * (hx + 0.01), y0 - 0.06, hc.z - hz * 0.22)))
		9:
			root.add_child(_mi(sph(0.165, false, 10, 6), m, Vector3(hc.x, y0 + 0.07, hc.z - 0.05)))
		10:
			_cap.call()
			root.add_child(_mi(box(Vector3(hx * 2.0 + 0.012, 0.045, 0.03)), m, Vector3(hc.x, y0 + 0.055, ctx.face_z.call(0.0, y0 + 0.06) - 0.004), Vector3(8, 0, 0)))


static func _eyes(root: Node3D, style: int, m: Material, ctx: Dictionary, extra: Dictionary) -> void:
	var lm := _lm(ctx)
	var white := mat(Color(0.96, 0.96, 0.96), 0.4)
	var ex: float = ctx.hx * 0.45
	for sx in [-1.0, 1.0]:
		var x: float = ctx.hc.x + sx * ex
		var z: float = ctx.face_z.call(x, lm.eye_y)
		var w := 0.03
		var hgt := 0.018
		var iris := 0.012
		var tilt := 0.0
		match style:
			2: hgt = 0.011; iris = 0.009
			3: w = 0.036; hgt = 0.024; iris = 0.017
			4: tilt = -12.0 * sx * -1.0
			5: hgt = 0.01; iris = 0.008
			1: hgt = 0.022
		root.add_child(_mi(box(Vector3(w, hgt, 0.006)), white, Vector3(x, lm.eye_y, z + 0.0005), Vector3(0, 0, tilt)))
		root.add_child(_mi(box(Vector3(iris, minf(iris + 0.004, hgt), 0.007)), m, Vector3(x, lm.eye_y, z + 0.0035), Vector3(0, 0, tilt)))


static func _brows(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var lm := _lm(ctx)
	var ex: float = ctx.hx * 0.45
	for sx in [-1.0, 1.0]:
		var x: float = ctx.hc.x + sx * ex
		var z: float = ctx.face_z.call(x, lm.brow_y)
		var w := 0.04
		var th := 0.006
		var ang := 0.0
		match style:
			2: ang = 8.0 * sx
			3: th = 0.011
			4: ang = -14.0 * sx; th = 0.009
			5: ang = 14.0 * sx
		root.add_child(_mi(box(Vector3(w, th, 0.008)), m, Vector3(x, lm.brow_y, z + 0.002), Vector3(0, 0, ang)))


static func _mouth(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var lm := _lm(ctx)
	var z: float = ctx.face_z.call(0.0, lm.mouth_y)
	var y: float = lm.mouth_y
	match style:
		1:
			root.add_child(_mi(box(Vector3(0.046, 0.006, 0.006)), m, Vector3(0, y, z + 0.001)))
		2:
			root.add_child(_mi(box(Vector3(0.03, 0.006, 0.006)), m, Vector3(0, y - 0.004, z + 0.001)))
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.018, 0.006, 0.006)), m, Vector3(sx * 0.024, y + 0.001, z - 0.001), Vector3(0, 0, -22.0 * sx)))
		3:
			root.add_child(_mi(box(Vector3(0.026, 0.007, 0.006)), m, Vector3(0, y, z + 0.001)))
		4:
			root.add_child(_mi(box(Vector3(0.036, 0.02, 0.006)), mat(Color(0.25, 0.04, 0.04), 0.5), Vector3(0, y, z + 0.0005)))
			root.add_child(_mi(box(Vector3(0.036, 0.006, 0.007)), m, Vector3(0, y + 0.012, z + 0.001)))
		5:
			root.add_child(_mi(box(Vector3(0.03, 0.006, 0.006)), m, Vector3(0, y + 0.004, z + 0.001)))
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.016, 0.006, 0.006)), m, Vector3(sx * 0.021, y - 0.001, z - 0.001), Vector3(0, 0, 24.0 * sx)))


static func _nose(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var lm := _lm(ctx)
	var z: float = ctx.face_z.call(0.0, lm.nose_y)
	var w := 0.026
	var hgt := 0.05
	var d := 0.03
	match style:
		2: w = 0.036; hgt = 0.06; d = 0.04
		3: w = 0.02; hgt = 0.06; d = 0.05
	root.add_child(_mi(prism(Vector3(w, d, hgt)), m, Vector3(0, lm.nose_y + 0.01, z + d * 0.3), Vector3(90, 0, 0)))


static func _ears(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var lm := _lm(ctx)
	for sx in [-1.0, 1.0]:
		var x: float = ctx.hc.x + sx * (ctx.hx + 0.002)
		var z: float = ctx.hc.z - 0.005
		match style:
			1: root.add_child(_mi(box(Vector3(0.012, 0.05, 0.035)), m, Vector3(x + sx * 0.004, lm.ear_y, z)))
			2: root.add_child(_mi(box(Vector3(0.016, 0.075, 0.05)), m, Vector3(x + sx * 0.008, lm.ear_y + 0.005, z), Vector3(0, 0, -8.0 * sx)))
			3: root.add_child(_mi(prism(Vector3(0.05, 0.1, 0.014)), m, Vector3(x + sx * 0.03, lm.ear_y + 0.03, z), Vector3(0, 90, -70.0 * sx + 0.0)))


static func _beard(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var lm := _lm(ctx)
	var cz: float = ctx.face_z.call(0.0, lm.chin_y + 0.02)
	match style:
		1:    # cavanhaque
			root.add_child(_mi(box(Vector3(0.05, 0.055, 0.03)), m, Vector3(0, lm.chin_y + 0.015, cz - 0.004), Vector3(10, 0, 0)))
		2:    # bigode
			var z: float = ctx.face_z.call(0.0, lm.mouth_y + 0.02)
			root.add_child(_mi(box(Vector3(0.07, 0.016, 0.014)), m, Vector3(0, lm.mouth_y + 0.022, z + 0.003)))
		3:    # cheia
			root.add_child(_mi(box(Vector3(0.115, 0.07, 0.03)), m, Vector3(0, lm.chin_y + 0.03, cz - 0.008), Vector3(8, 0, 0)))
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.02, 0.1, 0.1)), m, Vector3(sx * (ctx.hx - 0.006), lm.mouth_y + 0.0, ctx.hc.z + 0.03)))
			root.add_child(_mi(box(Vector3(0.07, 0.014, 0.014)), m, Vector3(0, lm.mouth_y + 0.022, ctx.face_z.call(0.0, lm.mouth_y + 0.02) + 0.003)))
		4:    # costeletas
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.016, 0.11, 0.05)), m, Vector3(sx * (ctx.hx - 0.004), lm.mid_y - 0.0, ctx.hc.z + 0.04)))


static func _glasses(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var lm := _lm(ctx)
	var ex: float = ctx.hx * 0.45
	var lens := mat(Color(0.08, 0.1, 0.12, 0.55), 0.1, 0.0)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx in [-1.0, 1.0]:
		var x: float = ctx.hc.x + sx * ex
		var z: float = ctx.face_z.call(x, lm.eye_y) + 0.012
		match style:
			1:
				root.add_child(_mi(torus(0.015, 0.021, 10), m, Vector3(x, lm.eye_y, z), Vector3(90, 0, 0)))
				root.add_child(_mi(cyl(0.017, 0.017, 0.002, 10), lens, Vector3(x, lm.eye_y, z), Vector3(90, 0, 0)))
			2:
				for off in [Vector3(0, 0.017, 0), Vector3(0, -0.017, 0)]:
					root.add_child(_mi(box(Vector3(0.046, 0.004, 0.004)), m, Vector3(x, lm.eye_y, z) + off))
				for off2 in [Vector3(0.021, 0, 0), Vector3(-0.021, 0, 0)]:
					root.add_child(_mi(box(Vector3(0.004, 0.038, 0.004)), m, Vector3(x, lm.eye_y, z) + off2))
				root.add_child(_mi(box(Vector3(0.042, 0.032, 0.002)), lens, Vector3(x, lm.eye_y, z)))
			3:
				root.add_child(_mi(box(Vector3(0.05, 0.034, 0.006)), m, Vector3(x, lm.eye_y, z)))
		# haste até a orelha
		root.add_child(_mi(box(Vector3(0.004, 0.004, 0.12)), m, Vector3(ctx.hc.x + sx * (ctx.hx + 0.002), lm.eye_y + 0.002, ctx.hc.z + 0.065)))
	root.add_child(_mi(box(Vector3(ex * 0.9, 0.005, 0.005)), m, Vector3(ctx.hc.x, lm.eye_y + 0.008, ctx.face_z.call(0.0, lm.eye_y) + 0.012)))


static func _hat(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var hc: Vector3 = ctx.hc
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var top: float = ctx.top
	var bottom: float = ctx.bottom
	var h: float = top - bottom
	var y0 := bottom + 0.55 * h
	var zc := hc.z - 0.008
	match style:
		1:    # boné
			root.add_child(_mi(sph(1.0, true, 10, 5), m, Vector3(hc.x, y0 + 0.02, zc), Vector3(-6, 0, 0), Vector3(hx + 0.022, (top - y0) + 0.03, hz + 0.024)))
			root.add_child(_mi(box(Vector3(hx * 2.0, 0.008, 0.11)), m, Vector3(hc.x, y0 + 0.025, ctx.face_z.call(0.0, y0) + 0.05), Vector3(10, 0, 0)))
		2:    # gorro
			root.add_child(_mi(sph(1.0, true, 10, 6), m, Vector3(hc.x, y0 + 0.005, zc), Vector3(-4, 0, 0), Vector3(hx + 0.02, (top - y0) + 0.09, hz + 0.022)))
			root.add_child(_mi(cyl(1.0, 1.0, 0.045, 10, false), m, Vector3(hc.x, y0 + 0.0, zc), Vector3.ZERO, Vector3(hx + 0.026, 1.0, hz + 0.028)))
			root.add_child(_mi(sph(0.032, false, 8, 4), m, Vector3(hc.x, top + 0.085, zc - 0.01)))
		3:    # chapéu de aba
			root.add_child(_mi(cyl(0.12, 0.125, 0.105, 10), m, Vector3(hc.x, y0 + 0.075, zc)))
			root.add_child(_mi(cyl(0.25, 0.25, 0.01, 12), m, Vector3(hc.x, y0 + 0.03, zc)))
		4:    # elmo
			root.add_child(_mi(sph(1.0, true, 10, 5), m, Vector3(hc.x, bottom + 0.42 * h, zc), Vector3.ZERO, Vector3(hx + 0.03, (top - bottom) * 0.66 + 0.04, hz + 0.034)))
			root.add_child(_mi(cyl(1.0, 1.0, 0.1, 10, false), m, Vector3(hc.x, bottom + 0.42 * h - 0.05, zc), Vector3.ZERO, Vector3(hx + 0.03, 1.0, hz + 0.034)))
			root.add_child(_mi(box(Vector3(0.016, 0.1, 0.012)), m, Vector3(hc.x, bottom + 0.55 * h, ctx.face_z.call(0.0, y0) + 0.008)))
		5:    # capuz
			root.add_child(_mi(sph(1.0, true, 10, 6), m, Vector3(hc.x, bottom + 0.38 * h, zc - 0.01), Vector3(-6, 0, 0), Vector3(hx + 0.045, (top - bottom) * 0.7 + 0.06, hz + 0.05)))
			root.add_child(_mi(cyl(1.0, 1.0, 0.1, 10, false), m, Vector3(hc.x, bottom + 0.38 * h - 0.05, zc - 0.01), Vector3.ZERO, Vector3(hx + 0.045, 1.0, hz + 0.05)))
			root.add_child(_mi(box(Vector3(hx * 2.2, 0.16, 0.05)), m, Vector3(hc.x, bottom - 0.02, hc.z - hz - 0.012)))
		6:    # bandana
			root.add_child(_mi(cyl(1.0, 1.0, 0.035, 10, false), m, Vector3(hc.x, y0 + 0.07, zc), Vector3(-6, 0, 0), Vector3(hx + 0.012, 1.0, hz + 0.014)))
			root.add_child(_mi(box(Vector3(0.05, 0.05, 0.012)), m, Vector3(hc.x + 0.03, y0 + 0.05, hc.z - hz - 0.02), Vector3(0, 0, 20)))


static func build_shoulder_side(side: String, style: int, m: Material, ctx: Dictionary, o: Vector3) -> Node3D:
	if style <= 0:
		return null
	var root := Node3D.new()
	root.name = "Part_shoulder_" + side
	var sx := 1.0 if side == "Left" else -1.0
	match style:
		1:
			root.add_child(_mi(sph(1.0, true, 8, 4), m, o + Vector3(sx * 0.01, 0.02, 0.0), Vector3(0, 0, -sx * 12.0), Vector3(0.1, 0.07, 0.1)))
		2:
			for i in 3:
				root.add_child(_mi(box(Vector3(0.14 - i * 0.015, 0.016, 0.13 - i * 0.012)), m, o + Vector3(sx * (0.02 + i * 0.03), 0.045 - i * 0.025, 0.0), Vector3(0, 0, -sx * (12.0 + i * 8.0))))
		3:
			root.add_child(_mi(sph(1.0, true, 8, 4), m, o + Vector3(sx * 0.01, 0.02, 0.0), Vector3(0, 0, -sx * 12.0), Vector3(0.1, 0.06, 0.1)))
			for k in 3:
				root.add_child(_mi(cyl(0.0, 0.016, 0.07, 6), m, o + Vector3(sx * (0.0 + k * 0.025), 0.07 - k * 0.012, (k - 1) * 0.03), Vector3(0, 0, -sx * (20.0 + k * 8.0))))
	return root


static func _back(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var u: float = ctx.u
	match style:
		1:
			root.add_child(_mi(box(Vector3(0.3, 0.36, 0.15)), m, Vector3(0, 1.46 * u, -0.235 * u)))
			root.add_child(_mi(box(Vector3(0.22, 0.14, 0.05)), m, Vector3(0, 1.38 * u, -0.34 * u)))
			root.add_child(_mi(cyl(0.12, 0.12, 0.3, 8), m, Vector3(0, 1.28 * u, -0.235 * u), Vector3(0, 0, 90)))
		2:
			root.add_child(_mi(box(Vector3(0.42, 0.95, 0.02)), m, Vector3(0, 1.13 * u, -0.2 * u), Vector3(6, 0, 0)))
			root.add_child(_mi(box(Vector3(0.44, 0.06, 0.06)), m, Vector3(0, 1.62 * u, -0.16 * u)))
		3:
			root.add_child(_mi(cyl(0.05, 0.045, 0.55, 8), m, Vector3(0.06 * u, 1.5 * u, -0.2 * u), Vector3(0, 0, 25)))
			for k in 3:
				root.add_child(_mi(cyl(0.0, 0.014, 0.05, 6), mat(Color(0.8, 0.8, 0.75), 0.6), Vector3((0.16 + k * 0.012) * u, 1.8 * u, (-0.2 + k * 0.01) * u), Vector3(0, 0, 25)))
			root.add_child(_mi(box(Vector3(0.05, 0.6, 0.012)), m, Vector3(0, 1.45 * u, -0.145 * u), Vector3(0, 0, 40)))


static func _waist(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var u: float = ctx.u
	match style:
		1:
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.07, 0.1, 0.1)), m, Vector3(sx * 0.215 * u, 1.1 * u, 0.0), Vector3(0, 0, 0)))
		2:
			for sx in [-1.0, 1.0]:
				root.add_child(_mi(box(Vector3(0.09, 0.15, 0.14)), m, Vector3(sx * 0.22 * u, 1.06 * u, 0.0)))
				root.add_child(_mi(box(Vector3(0.094, 0.04, 0.144)), mat(m.albedo_color.darkened(0.25), 0.6), Vector3(sx * 0.22 * u, 1.115 * u, 0.0)))


static func _neck(root: Node3D, style: int, m: Material, ctx: Dictionary) -> void:
	var u: float = ctx.u
	match style:
		1:
			root.add_child(_mi(cyl(0.085, 0.095, 0.075, 8), m, Vector3(0, 1.69 * u, -0.012 * u)))
			root.add_child(_mi(box(Vector3(0.09, 0.3, 0.025)), m, Vector3(0.05 * u, 1.55 * u, 0.115 * u), Vector3(-6, 0, 0)))
		2:
			root.add_child(_mi(torus(0.07, 0.083, 10), m, Vector3(0, 1.68 * u, -0.01 * u)))
			root.add_child(_mi(sph(0.02, false, 6, 3), m, Vector3(0, 1.6 * u, 0.075 * u)))
