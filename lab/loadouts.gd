class_name LabLoadouts
extends RefCounted
## =============================================================================
## LOADOUTS (armas + animações de cada estilo)
## -----------------------------------------------------------------------------
## Cada loadout diz: quais pacotes de animação ele usa (regex sobre "pack/clip"
## em minúsculas), a cadeia de combo do botão direito, os "especiais" que
## preenchem as teclas 1-8 por padrão, e quais armas aparecem nas mãos.
## A locomoção (idle, andar/correr em 8 direções) é resolvida SOZINHA pelos
## metadados do LabAnimDB; tudo pode ser trocado pelos dropdowns do menu.
## =============================================================================

const DIRS := ["f", "fl", "l", "bl", "b", "br", "r", "fr"]
const DIR_FALLBACK := {
	"f": [["f", false]],
	"fl": [["fl", false], ["f", false], ["l", false]],
	"fr": [["fr", false], ["f", false], ["r", false]],
	"l": [["l", false], ["fl", false], ["bl", false], ["f", false]],
	"r": [["r", false], ["fr", false], ["br", false], ["f", false]],
	"b": [["b", false], ["f", true]],
	"bl": [["bl", false], ["b", false], ["l", false], ["f", true]],
	"br": [["br", false], ["b", false], ["r", false], ["f", true]],
}
const CLASS_TARGET := {"walk": 1.8, "run": 4.0, "sprint": 7.0}

## Mão: "R" / "L". rot = Euler (graus) aplicado ao osso da mão; o eixo longo da
## arma (+Y do modelo) deve ficar ao longo da empunhadura. scale em metros reais.
static var WEAPONS := {
	"sword":      {"file": "res://weapons/sword.fbx",        "hand": "R", "scale": 0.30, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90)},
	"greatsword": {"file": "res://weapons/espada grande.fbx", "hand": "R", "scale": 0.30, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90)},
	"battleaxe":  {"file": "res://weapons/machado.fbx",       "hand": "R", "scale": 0.30, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90)},
	"axe":        {"file": "res://weapons/machado pequeno.fbx", "hand": "R", "scale": 0.30, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90)},
	"mace":       {"file": "res://weapons/mace.fbx",          "hand": "R", "scale": 0.30, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90)},
	"dagger":     {"file": "res://weapons/adaga.fbx",         "hand": "R", "scale": 0.30, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90)},
	"shield":     {"file": "res://weapons/escudo.fbx",        "hand": "L", "scale": 0.50, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, 0)},
	"bow":        {"file": "res://weapons/arco.fbx",          "hand": "L", "scale": 0.45, "pos": Vector3(0, 0.0, 0), "rot": Vector3(0, 0, 180)},
	"pistol":     {"file": "res://weapons/Pistola.fbx",       "hand": "R", "scale": 0.03, "pos": Vector3(0, 0.08, 0), "rot": Vector3(0, 0, -90), "recenter": false},
	"rifle":      {"file": "res://weapons/Rifle.fbx",         "hand": "R", "scale": 0.10, "pos": Vector3(0, 0.05, 0), "rot": Vector3(90, 90, 0), "recenter": false},
}

const GS := "Pro Sword and Shield Pack/"
const SS := "Pro Sword and Shield Pack/"
const AX := "Pro Melee Axe Pack/"
const LM := "Pro Magic Pack/"
const LB := "Pro Longbow Pack/"
const PI := "Pro guns pack/"
const R8 := "Pro guns pack/"
const SH := "Pro guns pack/"

static func all() -> Array:
	return [
		{"id": "unarmed", "name": "Desarmado", "include": "^male basic|pro melee axe pack/unarmed", "include_f": "^female basic|pro melee axe pack/unarmed",
			"weapons": [], "strafe": false,
			"chain": [AX + "standing melee attack kick ver. 1", AX + "standing melee attack kick ver. 2"],
			"specials": [AX + "standing taunt battlecry", AX + "standing taunt chest thump", AX + "unarmed jump running", AX + "standing react large gut", SH + "walking to dying", AX + "unarmed idle looking ver. 1", AX + "unarmed turn left 90", AX + "unarmed turn right 90"],
			"jump": "Male Basic Locomotion Pack/jump", "jump_f": "Female Basic Locomotion Pack/jump", "hit": AX + "standing react large gut", "death": SH + "walking to dying"},
		{"id": "sword", "name": "Espada", "include": "^pro sword and shield pack", "weapons": ["sword"], "strafe": false,
			"chain": [SS + "sword and shield attack", SS + "sword and shield attack (2)", SS + "sword and shield attack (3)", SS + "sword and shield attack (4)"],
			"specials": [SS + "sword and shield block", SS + "sword and shield block (2)", SS + "draw sword 1", SS + "sheath sword 1", SS + "sword and shield death", SS + "sword and shield turn", SS + "sword and shield turn (2)"],
			"block": SS + "sword and shield block idle", "equip": SS + "draw sword 1", "death": SS + "sword and shield death"},
		{"id": "swordshield", "name": "Espada + Escudo", "include": "^pro sword and shield pack", "weapons": ["sword", "shield"], "strafe": false,
			"chain": [SS + "sword and shield attack", SS + "sword and shield attack (2)", SS + "sword and shield attack (3)", SS + "sword and shield attack (4)"],
			"specials": [SS + "sword and shield block", SS + "sword and shield block (2)", SS + "draw sword 1", SS + "sheath sword 1", SS + "sword and shield death", SS + "sword and shield turn", SS + "sword and shield turn (2)"],
			"block": SS + "sword and shield block idle", "equip": SS + "draw sword 1", "death": SS + "sword and shield death"},
		{"id": "greatsword", "name": "Espada Grande", "include": "^pro sword and shield pack", "weapons": ["greatsword"], "strafe": false,
			"chain": [SS + "sword and shield slash", SS + "sword and shield slash (2)", SS + "sword and shield slash (3)", SS + "sword and shield attack"],
			"specials": [SS + "sword and shield kick", SS + "sword and shield jump", SS + "sword and shield impact", SS + "sword and shield power up", SS + "sword and shield slash (4)", SS + "sword and shield 180 turn", SS + "sword and shield 180 turn (2)"],
			"block": SS + "sword and shield block idle", "jump": SS + "sword and shield jump", "hit": SS + "sword and shield impact", "death": SS + "sword and shield death", "equip": SS + "draw sword 1"},
		{"id": "battleaxe", "name": "Machado Grande", "include": "^pro melee axe pack/(standing|crouch)", "weapons": ["battleaxe"], "strafe": false,
			"chain": [AX + "standing melee attack horizontal", AX + "standing melee attack backhand", AX + "standing melee attack downward", AX + "standing melee attack 360 high"],
			"specials": [AX + "standing melee combo attack ver. 1", AX + "standing melee combo attack ver. 2", AX + "standing melee combo attack ver. 3", AX + "standing melee attack 360 low", AX + "standing melee attack kick ver. 1", AX + "standing melee run jump attack", AX + "standing taunt battlecry", AX + "standing block react large"],
			"block": AX + "standing block idle", "jump": AX + "standing jump", "hit": AX + "standing react large gut", "equip": AX + "unarmed equip over shoulder"},
		{"id": "axe", "name": "Machado Pequeno", "include": "^pro melee axe pack/(standing|crouch)", "weapons": ["axe"], "strafe": false,
			"chain": [AX + "standing melee attack horizontal", AX + "standing melee attack backhand", AX + "standing melee attack downward", AX + "standing melee attack 360 high"],
			"specials": [AX + "standing melee combo attack ver. 1", AX + "standing melee combo attack ver. 2", AX + "standing melee combo attack ver. 3", AX + "standing melee attack 360 low", AX + "standing melee attack kick ver. 2", AX + "standing melee run jump attack", AX + "standing taunt chest thump", AX + "standing block react large"],
			"block": AX + "standing block idle", "jump": AX + "standing jump", "hit": AX + "standing react large gut", "equip": AX + "unarmed equip underarm"},
		{"id": "mace", "name": "Maça", "include": "^pro melee axe pack/(standing|crouch)", "weapons": ["mace"], "strafe": false,
			"chain": [AX + "standing melee attack downward", AX + "standing melee attack horizontal", AX + "standing melee attack backhand"],
			"specials": [AX + "standing melee combo attack ver. 1", AX + "standing melee combo attack ver. 2", AX + "standing melee combo attack ver. 3", AX + "standing melee attack 360 low", AX + "standing melee attack kick ver. 1", AX + "standing melee run jump attack"],
			"block": AX + "standing block idle", "jump": AX + "standing jump", "hit": AX + "standing react large gut", "equip": AX + "unarmed equip underarm"},
		{"id": "dagger", "name": "Adaga", "include": "^pro melee axe pack/(standing|crouch)", "weapons": ["dagger"], "strafe": false,
			"chain": [AX + "standing melee attack backhand", AX + "standing melee attack horizontal", AX + "standing melee attack kick ver. 2"],
			"specials": [AX + "standing melee combo attack ver. 3", AX + "standing melee combo attack ver. 2", AX + "standing melee attack 360 low", AX + "standing melee run jump attack"],
			"block": AX + "standing block idle", "jump": AX + "standing jump", "hit": AX + "standing react large gut", "equip": AX + "unarmed equip underarm"},
		{"id": "bow", "name": "Arco", "include": "^pro longbow pack", "weapons": ["bow"], "strafe": true,
			"chain": ["Pro Longbow Pack/standing draw arrow"],
			"specials": ["Pro Longbow Pack/standing equip bow", "Pro Longbow Pack/standing disarm bow", "Pro Longbow Pack/standing draw arrow"],
			"jump": LM + "Standing Jump", "hit": LM + "Standing React Small From Front", "death": LM + "Standing React Death Backward", "equip": LB + "standing equip bow"},
		{"id": "pistol", "name": "Pistola", "include": "^pro guns pack", "weapons": ["pistol"], "strafe": true,
			"chain": ["Pro guns pack/firing rifle"],
			"specials": [PI + "pistol stand to kneel", PI + "pistol kneel to stand", PI + "pistol kneeling idle", PI + "pistol jump (2)", R8 + "death from front headshot"],
			"jump": PI + "pistol jump", "hit": R8 + "death from front headshot"},
		{"id": "rifle", "name": "Rifle", "include": "^pro guns pack", "weapons": ["rifle"], "strafe": true,
			"chain": ["Pro guns pack/firing rifle"],
			"specials": [SH + "rifle aiming idle", R8 + "idle crouching aiming", R8 + "turn 90 left", R8 + "turn 90 right", R8 + "death from front headshot", R8 + "death from back headshot", SH + "jump forward", SH + "jump backward"],
			"jump": SH + "jump forward", "death": R8 + "death from front headshot"},
		{"id": "magic", "name": "Magia (sem arma)", "include": "^pro magic pack", "weapons": [], "strafe": false,
			"chain": ["Pro Magic Pack/Standing 1H Magic Attack 01", "Pro Magic Pack/Standing 2H Magic Area Attack 02"],
			"specials": [LM + "Standing 2H Magic Area Attack 02", LM + "Standing 1H Magic Attack 01", LM + "Standing React Large From Front", LM + "Standing React Small From Front", LM + "Standing React Death Backward"],
			"jump": LM + "Standing Jump", "hit": LM + "Standing React Large From Front", "death": LM + "Standing React Death Backward"},
	]


static func by_id(id: String) -> Dictionary:
	for lo in all():
		if lo.id == id:
			return lo
	return all()[0]


static func slot_names() -> Array:
	var out := ["idle"]
	for cls in ["walk", "run"]:
		for d in DIRS:
			out.append(cls + "_" + d)
	return out


static func _regex(pattern: String) -> RegEx:
	var re := RegEx.new()
	re.compile(pattern)
	return re


static func candidates(db: LabAnimDB, lo: Dictionary, female: bool) -> Array:
	var pat: String = lo.get("include_f", lo.include) if female else lo.include
	var re := _regex(pat)
	var out: Array = []
	for key in db.entries:
		if re.search(String(key).to_lower()) != null:
			out.append(db.entries[key])
	return out


## Resolve idle + 16 slots de locomoção.
## retorno: { slot: {"key","rev","scale","speed"} }  (speed = m/s que o corpo anda)
static func resolve_slots(db: LabAnimDB, lo: Dictionary, female: bool, overrides: Dictionary) -> Dictionary:
	var cands := candidates(db, lo, female)
	var slots := {}

	# idle: nome mais curto, sem "looking"/"aiming"/agachado
	var best_idle = null
	for inf in cands:
		if inf.cat != LabAnimDB.Cat.IDLE or inf.crouch or inf.aim or String(inf.name).contains("looking"):
			continue
		if lo.id != "unarmed" and String(inf.name).contains("unarmed"):
			continue
		if best_idle == null or String(inf.name).length() < String(best_idle.name).length():
			best_idle = inf
	if best_idle == null:
		for inf in cands:
			if inf.cat == LabAnimDB.Cat.IDLE and not inf.crouch:
				best_idle = inf
				break
	if best_idle == null:
		for k in db.entries:
			if db.entries[k].cat == LabAnimDB.Cat.IDLE and not db.entries[k].crouch:
				best_idle = db.entries[k]
				break
	if best_idle != null:
		slots["idle"] = {"key": best_idle.key, "rev": false, "scale": 1.0, "speed": 0.0}

	# melhor clipe por (classe|direção), mais perto da velocidade-alvo da classe
	var best := {}
	for inf in cands:
		if inf.cat != LabAnimDB.Cat.LOCO or inf.crouch:
			continue
		var k := "%s|%s" % [inf.sclass, inf.dir]
		var score := absf(inf.speed - CLASS_TARGET[inf.sclass])
		if not best.has(k):
			best[k] = {"inf": inf, "score": score, "fast": inf}
		else:
			if score < best[k].score:
				best[k].inf = inf
				best[k].score = score
			if inf.speed > best[k].fast.speed:
				best[k].fast = inf

	var class_order := {
		"walk": [["walk", 1.0], ["run", 0.55], ["sprint", 0.35]],
		"run": [["run", 1.0], ["sprint", 1.0], ["walk", 1.5]],
	}
	for cls in ["walk", "run"]:
		for d in DIRS:
			var picked := false
			for fb in DIR_FALLBACK[d]:
				for co in class_order[cls]:
					var k := "%s|%s" % [co[0], fb[0]]
					if best.has(k):
						var inf: Dictionary = best[k].inf
						var sc: float = co[1]
						if cls == "run" and co[0] == "walk":   # corrida sem clipe próprio: usa o andar mais rápido, acelerado
							inf = best[k].fast
							sc = clampf(3.5 / maxf(inf.speed, 0.1), 1.0, 1.5)
						slots["%s_%s" % [cls, d]] = {"key": inf.key, "rev": fb[1], "scale": sc, "speed": inf.speed * sc}
						picked = true
						break
				if picked:
					break

	for slot in overrides:
		var key := db.find_key(String(overrides[slot]))
		if key != "":
			var inf := db.info(key)
			slots[slot] = {"key": key, "rev": false, "scale": 1.0, "speed": inf.speed if inf.cat == LabAnimDB.Cat.LOCO else 0.0}
	return slots


## Papéis (pulo, bloqueio, rolamento...). Usa o definido no loadout; se faltar,
## procura algo parecido no banco todo.
static func resolve_role(db: LabAnimDB, lo: Dictionary, role: String, female := false) -> String:
	var spec = lo.get(role + "_f", "") if female else ""
	var k := db.find_key(String(spec))
	if k != "":
		return k
	k = db.find_key(String(lo.get(role, "")))
	if k != "":
		return k
	var cands := candidates(db, lo, female)
	var want := -1
	match role:
		"jump": want = LabAnimDB.Cat.JUMP
		"dodge": want = LabAnimDB.Cat.DODGE
		"hit": want = LabAnimDB.Cat.HIT
		"death": want = LabAnimDB.Cat.DEATH
		"block": want = LabAnimDB.Cat.BLOCK
		"equip": want = LabAnimDB.Cat.EQUIP
	if want < 0:
		return ""
	for pool in [cands, db.entries.values()]:
		var best = null
		for inf in pool:
			if inf.cat != want:
				continue
			if role == "jump" and inf.root_motion:
				continue
			if role == "block" and not String(inf.name).contains("idle"):
				continue
			if best == null or absf(inf.len - 0.9) < absf(best.len - 0.9):
				best = inf
		if best != null:
			return best.key
	if role == "dodge":   # sem clipe de rolamento: usa um pulo pra frente como esquiva
		return db.find_key(SH + "jump forward")
	return ""


static func resolve_chain(db: LabAnimDB, lo: Dictionary) -> Array:
	var out: Array = []
	for spec in lo.get("chain", []):
		var k := db.find_key(String(spec))
		if k != "":
			out.append(k)
	return out


static func resolve_specials(db: LabAnimDB, lo: Dictionary) -> Array:
	var out: Array = []
	for spec in lo.get("specials", []):
		out.append(db.find_key(String(spec)))
	while out.size() < 8:
		out.append("")
	return out
