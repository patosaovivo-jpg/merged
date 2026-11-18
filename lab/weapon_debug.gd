class_name LabWeaponDebug
extends Node
## Calibração ao vivo da arma equipada.
##
## F9 (ou F8) liga/desliga. Quando ligado aparece um painel grande no topo da
## tela com os valores atuais — não depende do HUD pequeno do canto.
##
## Posição:  I/K = Y   J/L = X   U/O = Z   (também Numpad 8/2/4/6 e PgUp/PgDn)
## Rotação:  T/G = X   V/M = Y   B/N = Z   (também Numpad 1/3, +/- e 7/9)
## Shift = passo grande (0.02 m / 10 graus)
## 0 ou End = imprime e COPIA o código pronto para lab/loadouts.gd
## Home = restaura os valores originais do loadout
##
## Os ajustes são salvos automaticamente em `weapon_overrides` no config.

signal changed

const STEP := 0.005
const STEP_BIG := 0.02
const ROT_STEP := 2.0
const ROT_STEP_BIG := 10.0

var player: LabPlayer
var enabled := false

var _id := ""
var _pos := Vector3.ZERO
var _rot := Vector3.ZERO
var _cl: CanvasLayer
var _lbl: Label
var _msg := ""
var _msg_until := 0.0


func setup(p: LabPlayer) -> void:
	player = p
	if not player.loadout_changed.is_connected(_reload):
		player.loadout_changed.connect(_reload)
	_build_overlay()
	_reload()


func toggle() -> void:
	enabled = not enabled
	if _cl != null:
		_cl.visible = enabled
	if enabled:
		_reload()
		_msg = ""
		print("[weapon] calibração LIGADA: %s pos=%s rot=%s" % [_id, _pos, _rot])
	else:
		print("[weapon] calibração desligada.")
	_update_overlay()


func _reload() -> void:
	if player == null:
		return
	var ids: Array = player.loadout.get("weapons", [])
	_id = String(ids[0]) if ids.size() > 0 else ""
	var base: Dictionary = LabLoadouts.WEAPONS.get(_id, {})
	var ov: Dictionary = player.weapon_overrides.get(_id, {})
	_pos = ov.get("pos", base.get("pos", Vector3.ZERO))
	_rot = ov.get("rot", base.get("rot", Vector3.ZERO))
	_update_overlay()


func _build_overlay() -> void:
	if _cl != null and is_instance_valid(_cl):
		return
	_cl = CanvasLayer.new()
	_cl.layer = 40
	add_child(_cl)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -360.0
	panel.offset_right = 360.0
	panel.offset_top = 120.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.82)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	_cl.add_child(panel)
	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 18)
	_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl.add_theme_constant_override("outline_size", 4)
	panel.add_child(_lbl)
	_cl.visible = false


func _process(_delta: float) -> void:
	if enabled:
		_update_overlay()


func _input(event: InputEvent) -> void:
	var ev := event as InputEventKey
	if ev == null or not ev.pressed or ev.echo:
		return
	var k: int = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
	if k == KEY_F9 or k == KEY_F8:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not enabled or _id == "":
		return
	var step := STEP_BIG if ev.shift_pressed else STEP
	var rstep := ROT_STEP_BIG if ev.shift_pressed else ROT_STEP
	var moved := true
	match k:
		KEY_I, KEY_KP_8:
			_pos.y += step
		KEY_K, KEY_KP_2:
			_pos.y -= step
		KEY_J, KEY_KP_4:
			_pos.x -= step
		KEY_L, KEY_KP_6:
			_pos.x += step
		KEY_U, KEY_PAGEUP:
			_pos.z -= step
		KEY_O, KEY_PAGEDOWN:
			_pos.z += step
		KEY_T, KEY_KP_1:
			_rot.x -= rstep
		KEY_G, KEY_KP_3:
			_rot.x += rstep
		KEY_V, KEY_KP_ADD:
			_rot.y -= rstep
		KEY_M, KEY_KP_SUBTRACT:
			_rot.y += rstep
		KEY_B, KEY_KP_7:
			_rot.z -= rstep
		KEY_N, KEY_KP_9:
			_rot.z += rstep
		KEY_0, KEY_KP_0, KEY_END:
			_copy_code()
			get_viewport().set_input_as_handled()
			return
		KEY_HOME, KEY_KP_ENTER:
			var base: Dictionary = LabLoadouts.WEAPONS.get(_id, {})
			_pos = base.get("pos", Vector3.ZERO)
			_rot = base.get("rot", Vector3.ZERO)
			_msg = "Valores originais restaurados."
			_msg_until = Time.get_ticks_msec() + 2500.0
		_:
			moved = false
	if not moved:
		return
	player.set_weapon_override(_id, _pos, _rot)
	changed.emit()
	_msg = ""
	_update_overlay()
	get_viewport().set_input_as_handled()


func _copy_code() -> void:
	var base: Dictionary = LabLoadouts.WEAPONS.get(_id, {})
	var code := "\t\"%s\": {\"file\": \"%s\", \"hand\": \"%s\", \"scale\": %.3f, \"pos\": Vector3(%.3f, %.3f, %.3f), \"rot\": Vector3(%.1f, %.1f, %.1f)}," % [
		_id, String(base.get("file", "")), String(base.get("hand", "R")),
		float(base.get("scale", 1.0)), _pos.x, _pos.y, _pos.z, _rot.x, _rot.y, _rot.z]
	DisplayServer.clipboard_set(code)
	_msg = "Copiado para a área de transferência! Cole em lab/loadouts.gd."
	_msg_until = Time.get_ticks_msec() + 5000.0
	print("[weapon] ", code)
	_update_overlay()


func _update_overlay() -> void:
	if _lbl == null:
		return
	if not enabled:
		return
	var now := Time.get_ticks_msec()
	if now > _msg_until:
		_msg = ""
	var txt := "CALIBRAR ARMA: %s\npos = (%.3f, %.3f, %.3f)    rot = (%.1f, %.1f, %.1f)\nI/K Y · J/L X · U/O Z   |   T/G rx · V/M ry · B/N rz\nShift = passo grande · 0 copia · Home restaura · F9 fecha" % [
		_id if _id != "" else "—", _pos.x, _pos.y, _pos.z, _rot.x, _rot.y, _rot.z]
	if _msg != "":
		txt += "\n" + _msg
	_lbl.text = txt


func status_short() -> String:
	if _id == "":
		return "Arma: — (equipe uma arma para calibrar)"
	return "Arma %s pos=(%.3f, %.3f, %.3f) rot=(%.1f, %.1f, %.1f)" % [
		_id, _pos.x, _pos.y, _pos.z, _rot.x, _rot.y, _rot.z]
