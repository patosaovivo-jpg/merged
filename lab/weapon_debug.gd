class_name LabWeaponDebug
extends Node
## Calibração ao vivo da arma equipada.
## F9 liga/desliga o modo. Com ele ligado, o HUD mostra pos/rot da arma atual.
##
## Numpad 8/2 ......... pos.y +/-      Numpad 4/6 ......... pos.x +/-
## PageUp/PageDown .... pos.z +/-      Numpad 7/9 ......... rot.z +/-
## Numpad 1/3 ......... rot.x +/-      Numpad + / - ....... rot.y +/-
## Numpad 0 ........... imprime os valores no console (copiar p/ loadouts.gd)
## Shift = passo grande (0.02 m / 10 graus).

var player: LabPlayer
var enabled := false

var _id := ""
var _pos := Vector3.ZERO
var _rot := Vector3.ZERO


func setup(p: LabPlayer) -> void:
	player = p
	player.loadout_changed.connect(_reload)


func _reload() -> void:
	if player == null:
		return
	var ids: Array = player.loadout.get("weapons", [])
	_id = String(ids[0]) if ids.size() > 0 else ""
	var base: Dictionary = LabLoadouts.WEAPONS.get(_id, {})
	var ov: Dictionary = player.weapon_overrides.get(_id, {})
	_pos = ov.get("pos", base.get("pos", Vector3.ZERO))
	_rot = ov.get("rot", base.get("rot", Vector3.ZERO))


func _unhandled_input(event: InputEvent) -> void:
	var ev := event as InputEventKey
	if ev == null or not ev.pressed or ev.echo:
		return
	var k: int = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
	if k == KEY_F9:
		enabled = not enabled
		_reload()
		if enabled:
			print("[weapon] modo de calibração LIGADO: %s pos=%s rot=%s" % [_id, _pos, _rot])
			print("[weapon] Numpad 8/2/4/6 pos | PgUp/PgDn pos.z | 7/9 rot.z | 1/3 rot.x | + / - rot.y | 0 imprime")
		else:
			print("[weapon] calibração desligada.")
		get_viewport().set_input_as_handled()
		return
	if not enabled:
		return
	if _id == "":
		return
	var big: bool = ev.shift_pressed
	var step := 0.02 if big else 0.005
	var rstep := 10.0 if big else 2.0
	match k:
		KEY_KP_8:
			_pos.y += step
		KEY_KP_2:
			_pos.y -= step
		KEY_KP_4:
			_pos.x -= step
		KEY_KP_6:
			_pos.x += step
		KEY_PAGEUP:
			_pos.z -= step
		KEY_PAGEDOWN:
			_pos.z += step
		KEY_KP_7:
			_rot.z -= rstep
		KEY_KP_9:
			_rot.z += rstep
		KEY_KP_1:
			_rot.x -= rstep
		KEY_KP_3:
			_rot.x += rstep
		KEY_KP_ADD:
			_rot.y += rstep
		KEY_KP_SUBTRACT:
			_rot.y -= rstep
		KEY_KP_0:
			print("[weapon] \"%s\": {\"pos\": Vector3(%.3f, %.3f, %.3f), \"rot\": Vector3(%.1f, %.1f, %.1f)}" % [_id, _pos.x, _pos.y, _pos.z, _rot.x, _rot.y, _rot.z])
			print("[weapon] rot em radianos: %s" % _rot)
			return
		KEY_KP_ENTER:
			_pos = Vector3.ZERO
			_rot = Vector3.ZERO
		_:
			return
	player.set_weapon_override(_id, _pos, _rot)
	print("[weapon] %s pos=%s rot=%s" % [_id, _pos, _rot])


func status_text() -> String:
	if _id == "":
		return "Arma: — (equipe uma arma para calibrar)"
	return "Arma %s  pos=(%.3f, %.3f, %.3f)  rot=(%.1f, %.1f, %.1f)\nNumpad 8/2/4/6 pos | PgUp/PgDn pos.z | 7/9 rot.z | 1/3 rot.x | +/- rot.y | 0 imprime | F9 sai" % [
		_id, _pos.x, _pos.y, _pos.z, _rot.x, _rot.y, _rot.z]
