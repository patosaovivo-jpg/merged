class_name LabUI
extends CanvasLayer
## Menu lateral: equipar armas, teclas -> animações (dropdowns), combo, locomoção.

signal reload_requested
signal config_changed

const PANEL_W := 440

var db: LabAnimDB
var player: LabPlayer
var panel: PanelContainer
var tabs: TabContainer
var hud: Label
var help: Label
var hint: Label

var _all_dropdowns: Array = []     # [OptionButton, Callable getter(key)]
var _char_opt: OptionButton
var _lo_opt: OptionButton
var _lo_status: Label
var _bind_rows: Array = []         # [anim_opt, mode_opt]
var _role_opts := {}               # role -> OptionButton
var _chain_opts: Array = []
var _slot_opts := {}               # slot -> OptionButton
var _preview_opt: OptionButton
var _preview_mode: OptionButton
var _chk := {}
var _syncing := false
var characters: Array = []


func build(p_db: LabAnimDB, p_player: LabPlayer, chars: Array) -> void:
	db = p_db
	player = p_player
	characters = chars
	layer = 10

	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_W
	panel.offset_right = 0
	add_child(panel)
	tabs = TabContainer.new()
	panel.add_child(tabs)
	_build_tab_equip()
	_build_tab_visual()
	_build_tab_binds()
	_build_tab_combo()
	_build_tab_loco()

	help = Label.new()
	help.position = Vector2(14, 10)
	help.text = "WASD mover  |  Shift correr  |  Espaço pular  |  Q rolamento  |  F bloquear (segurar)\n1-8 animações configuráveis  |  Botão direito: ataque / combo  |  Alt: mirar p/ câmera\nClique esquerdo na cena: capturar mouse (câmera)  |  Esc: liberar mouse p/ usar o menu  |  R: parar ação"
	_style_label(help)
	add_child(help)

	hud = Label.new()
	hud.anchor_top = 1.0
	hud.anchor_bottom = 1.0
	hud.offset_left = 14
	hud.offset_top = -120
	hud.offset_right = 900
	hud.offset_bottom = -10
	_style_label(hud)
	add_child(hud)

	hint = Label.new()
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -330
	hint.offset_right = 70
	hint.offset_top = 90
	hint.text = ""
	_style_label(hint)
	add_child(hint)

	player.loadout_changed.connect(refresh_from_player)
	tabs.tab_changed.connect(func(i: int):
		var is_visual := tabs.get_child(i).name == "Visual"
		if is_visual != player.showcase:
			player.set_showcase(is_visual))
	refresh_from_player()


func _style_label(l: Label) -> void:
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if player == null:
		return
	hud.text = player.debug_text()
	hint.text = "" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Mouse livre (menu ativo). Clique na cena para controlar a câmera."


# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------
func _tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	tabs.add_child(sc)
	return vb


func _label(parent: Control, text: String, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	parent.add_child(l)
	return l


func _noclip_focus(c: Control) -> void:
	c.focus_mode = Control.FOCUS_NONE


func _check(parent: Control, text: String, value: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_noclip_focus(c)
	c.toggled.connect(func(v): if not _syncing: cb.call(v))
	parent.add_child(c)
	return c


func _slider(parent: Control, text: String, mn: float, mx: float, step: float, value: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 150
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_noclip_focus(s)
	var v := Label.new()
	v.text = "%.2f" % value
	v.custom_minimum_size.x = 44
	s.value_changed.connect(func(x): v.text = "%.2f" % x; if not _syncing: cb.call(x))
	row.add_child(s)
	row.add_child(v)
	parent.add_child(row)
	return s


func _anim_option(selected: String, cb: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.clip_text = true
	ob.fit_to_longest_item = false
	ob.custom_minimum_size.x = 160
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_noclip_focus(ob)
	_fill(ob)
	_select_key(ob, selected)
	ob.item_selected.connect(func(i): if not _syncing: cb.call(String(ob.get_item_metadata(i))))
	return ob


func _fill(ob: OptionButton) -> void:
	ob.clear()
	ob.add_item("— nenhuma —")
	ob.set_item_metadata(0, "")
	for pack in db.pack_names():
		ob.add_separator(String(pack))
		for key in db.packs[pack]:
			var inf := db.info(key)
			ob.add_item("%s  (%.1fs)" % [inf.name, inf.len])
			ob.set_item_metadata(ob.item_count - 1, key)


func _select_key(ob: OptionButton, key: String) -> void:
	for i in ob.item_count:
		if not ob.is_item_separator(i) and String(ob.get_item_metadata(i)) == key:
			ob.select(i)
			return
	ob.select(0)


func _mode_option(selected: String, cb: Callable) -> OptionButton:
	var ob := OptionButton.new()
	for t in LabPlayer.MODE_LABEL:
		ob.add_item(t)
	ob.select(maxi(LabPlayer.MODES.find(selected), 0))
	ob.fit_to_longest_item = false
	ob.custom_minimum_size.x = 92
	_noclip_focus(ob)
	ob.item_selected.connect(func(i): if not _syncing: cb.call(LabPlayer.MODES[i]))
	return ob


# -----------------------------------------------------------------------------
# Aba EQUIPAR
# -----------------------------------------------------------------------------
func _build_tab_equip() -> void:
	var vb := _tab("Equipar")
	_label(vb, "Personagem", true)
	_char_opt = OptionButton.new()
	_noclip_focus(_char_opt)
	for c in characters:
		_char_opt.add_item(String(c).get_file().get_basename())
	_char_opt.item_selected.connect(func(i):
		if not _syncing:
			player.load_character(characters[i])
			config_changed.emit())
	vb.add_child(_char_opt)

	_label(vb, "Arma / Estilo", true)
	_lo_opt = OptionButton.new()
	_noclip_focus(_lo_opt)
	var los := LabLoadouts.all()
	for lo in los:
		_lo_opt.add_item(lo.name)
		_lo_opt.set_item_metadata(_lo_opt.item_count - 1, lo.id)
	_lo_opt.item_selected.connect(func(i):
		if not _syncing:
			player.equip_loadout(String(_lo_opt.get_item_metadata(i)))
			config_changed.emit())
	vb.add_child(_lo_opt)
	var eq := Button.new()
	eq.text = "Equipar de novo (toca o saque)"
	eq.clip_text = true
	_noclip_focus(eq)
	eq.pressed.connect(func(): player.equip_loadout(player.loadout.id))
	vb.add_child(eq)
	_lo_status = _label(vb, "")

	vb.add_child(HSeparator.new())
	_label(vb, "Corpo dividido", true)
	_chk["split"] = _check(vb, "Parte de cima independente da de baixo", player.split_independent, func(v): player.split_independent = v; config_changed.emit())
	var row := HBoxContainer.new()
	var dl := Label.new()
	dl.text = "Dividir em: "
	row.add_child(dl)
	var sb := OptionButton.new()
	_noclip_focus(sb)
	for t in ["Cintura (Spine)", "Peito (Spine1)", "Ombros (Spine2)"]:
		sb.add_item(t)
	sb.item_selected.connect(func(i): player.rig.set_split_bone(["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"][i]); config_changed.emit())
	row.add_child(sb)
	vb.add_child(row)
	_label(vb, "Ações em modo Auto: se você está se movendo, tocam só em cima (as pernas continuam); parado, tocam no corpo todo. Pulo, rolamento, dano e morte sempre usam o corpo todo.")

	vb.add_child(HSeparator.new())
	_label(vb, "Movimento", true)
	_chk["strafe"] = _check(vb, "Strafe (corpo mira p/ câmera, 8 direções)", player.strafe_mode, func(v): player.strafe_mode = v)
	_chk["sync"] = _check(vb, "Sincronizar velocidade com a animação (sem pé deslizando)", player.sync_speed, func(v): player.sync_speed = v; config_changed.emit())
	_chk["rm"] = _check(vb, "Root motion nos golpes de corpo todo", player.use_root_motion, func(v): player.use_root_motion = v; config_changed.emit())
	_slider(vb, "Vel. andar (sync off)", 0.5, 5.0, 0.1, player.walk_speed, func(v): player.walk_speed = v)
	_slider(vb, "Vel. correr (sync off)", 2.0, 9.0, 0.1, player.run_speed, func(v): player.run_speed = v)
	_slider(vb, "Velocidade das animações", 0.3, 2.0, 0.05, player.anim_speed, func(v): player.anim_speed = v)
	_slider(vb, "Sensib. mouse", 0.5, 8.0, 0.1, player.mouse_sens * 1000.0, func(v): player.mouse_sens = v / 1000.0; config_changed.emit())

	vb.add_child(HSeparator.new())
	var rl := Button.new()
	rl.text = "Recarregar animações (re-escanear)"
	rl.clip_text = true
	_noclip_focus(rl)
	rl.pressed.connect(func(): reload_requested.emit())
	vb.add_child(rl)
	_label(vb, "%d clipes carregados em %d pacotes%s." % [db.entries.size(), db.packs.size(), " (cache)" if db.from_cache else ""])


# -----------------------------------------------------------------------------
# Aba VISUAL (criador de personagem)
# -----------------------------------------------------------------------------
var visual_tab: LabVisualTab


func _build_tab_visual() -> void:
	var vb := _tab("Visual")
	visual_tab = LabVisualTab.new()
	vb.add_child(visual_tab)
	visual_tab.build(player)


# -----------------------------------------------------------------------------
# Aba TECLAS
# -----------------------------------------------------------------------------
func _build_tab_binds() -> void:
	var vb := _tab("Teclas")
	_label(vb, "Tecla → animação  (escolha qualquer clipe de qualquer pacote)", true)
	for i in 8:
		var row := HBoxContainer.new()
		var kl := Label.new()
		kl.text = "[%d]" % (i + 1)
		kl.custom_minimum_size.x = 30
		row.add_child(kl)
		var idx := i
		var ao := _anim_option("", func(k): player.binds[idx].key = k; player.binds[idx].user = true; config_changed.emit())
		var mo := _mode_option("auto", func(m): player.binds[idx].mode = m; player.binds[idx].user = true; config_changed.emit())
		row.add_child(ao)
		row.add_child(mo)
		vb.add_child(row)
		_bind_rows.append([ao, mo])
	var reset := Button.new()
	reset.text = "Usar teclas padrão da arma"
	reset.clip_text = true
	_noclip_focus(reset)
	reset.pressed.connect(func():
		for b in player.binds:
			b.user = false
		player.equip_loadout(player.loadout.id, false)
		config_changed.emit())
	vb.add_child(reset)

	vb.add_child(HSeparator.new())
	_label(vb, "Ações fixas", true)
	for r in [["dodge", "[Q] rolamento"], ["jump", "[Espaço] pulo"], ["block", "[F] bloquear"], ["hit", "dano (teste)"], ["death", "morte (teste)"]]:
		var row := HBoxContainer.new()
		var kl := Label.new()
		kl.text = r[1]
		kl.custom_minimum_size.x = 100
		row.add_child(kl)
		var role: String = r[0]
		var ao := _anim_option("", func(k):
			player.role_override[role] = k
			player.roles[role] = k
			if role == "block":
				player._abort_all()
			config_changed.emit())
		row.add_child(ao)
		vb.add_child(row)
		_role_opts[role] = ao
	_label(vb, "Sem clipe de rolamento no pacote? Q usa um salto como esquiva. Adicione um FBX com 'roll'/'dodge' no nome em ANIMATIONS e ele é detectado sozinho.")

	vb.add_child(HSeparator.new())
	_label(vb, "Pré-visualizar qualquer animação", true)
	var prow := HBoxContainer.new()
	_preview_opt = _anim_option("", func(_k): pass)
	_preview_mode = _mode_option("auto", func(_m): pass)
	prow.add_child(_preview_opt)
	prow.add_child(_preview_mode)
	vb.add_child(prow)
	var play := Button.new()
	play.text = "▶ Tocar"
	_noclip_focus(play)
	play.pressed.connect(func():
		var k := String(_preview_opt.get_item_metadata(maxi(_preview_opt.selected, 0)))
		if k != "":
			player.trigger_clip(k, LabPlayer.MODES[_preview_mode.selected], "special"))
	vb.add_child(play)


# -----------------------------------------------------------------------------
# Aba COMBO
# -----------------------------------------------------------------------------
func _build_tab_combo() -> void:
	var vb := _tab("Combo")
	_label(vb, "Botão direito: sequência do combo (clique de novo durante o golpe para encadear)", true)
	for i in 5:
		var row := HBoxContainer.new()
		var kl := Label.new()
		kl.text = "%d." % (i + 1)
		kl.custom_minimum_size.x = 24
		row.add_child(kl)
		var idx := i
		var ao := _anim_option("", func(k):
			var arr: Array = player.chain.duplicate()
			while arr.size() <= idx:
				arr.append("")
			arr[idx] = k
			arr = arr.filter(func(x): return x != "")
			player.chain = arr
			player.chain_override[player.loadout.id] = arr
			player.combo_idx = 0
			config_changed.emit())
		row.add_child(ao)
		vb.add_child(row)
		_chain_opts.append(ao)
	_slider(vb, "Janela p/ próximo golpe (%)", 0.1, 0.95, 0.05, player.combo_window, func(v): player.combo_window = v; config_changed.emit())
	_slider(vb, "Cancelar c/ movimento (%)", 0.2, 1.0, 0.05, player.move_cancel, func(v): player.move_cancel = v; config_changed.emit())
	vb.add_child(HSeparator.new())
	_label(vb, "Encadeamento suave", true)
	_check(vb, "Seek autom?tico (come?a do ponto mais parecido)", player.use_combo_seek,
		func(v): player.use_combo_seek = v; player.seek_cache.build(player.db, player.chain))
	_slider(vb, "Decay do offset (s)", 0.03, 0.30, 0.01, player.combo_seek_decay,
		func(v): player.combo_seek_decay = v; if player.pose_offset: player.pose_offset.decay_time = v)
	_label(vb, "Há bonecos de treino na arena: golpes que acertam fazem o boneco piscar/balançar.")


# -----------------------------------------------------------------------------
# Aba LOCOMOÇÃO
# -----------------------------------------------------------------------------
func _build_tab_loco() -> void:
	var vb := _tab("Locomoção")
	_label(vb, "Slots de locomoção (resolvidos sozinhos; troque se quiser)", true)
	var nice := {"f": "frente", "fl": "frente-esq", "l": "esquerda", "bl": "trás-esq", "b": "trás", "br": "trás-dir", "r": "direita", "fr": "frente-dir"}
	for s in LabLoadouts.slot_names():
		var row := HBoxContainer.new()
		var kl := Label.new()
		var parts := String(s).split("_")
		kl.text = "idle" if s == "idle" else "%s %s" % ["andar" if parts[0] == "walk" else "correr", nice[parts[1]]]
		kl.custom_minimum_size.x = 120
		row.add_child(kl)
		var slot: String = s
		var ao := _anim_option("", func(k): player.apply_slot_override(slot, k); config_changed.emit())
		row.add_child(ao)
		vb.add_child(row)
		_slot_opts[s] = ao


# -----------------------------------------------------------------------------
# sincroniza o menu com o estado do jogador
# -----------------------------------------------------------------------------
func refresh_from_player() -> void:
	if player == null or player.loadout.is_empty():
		return
	_syncing = true
	for i in _lo_opt.item_count:
		if String(_lo_opt.get_item_metadata(i)) == player.loadout.id:
			_lo_opt.select(i)
	for i in 8:
		_select_key(_bind_rows[i][0], player.binds[i].key)
		_bind_rows[i][1].select(maxi(LabPlayer.MODES.find(player.binds[i].mode), 0))
	for r in _role_opts:
		_select_key(_role_opts[r], player.roles.get(r, ""))
	for i in _chain_opts.size():
		_select_key(_chain_opts[i], player.chain[i] if i < player.chain.size() else "")
	for s in _slot_opts:
		_select_key(_slot_opts[s], player.slots[s].key if player.slots.has(s) else "")
	_chk["strafe"].button_pressed = player.strafe_mode
	var missing := PackedStringArray()
	if player.chain.is_empty():
		missing.append("sem ataques")
	if player.slots.get("walk_f", {}).get("scale", 1.0) != 1.0:
		missing.append("sem 'andar' próprio (usa correr mais lento)")
	if player.slots.get("run_l", {}).get("scale", 1.0) != 1.0:
		missing.append("sem strafe de corrida próprio")
	_lo_status.text = "Combo: %d golpe(s)." % player.chain.size() + ("  Aviso: " + ", ".join(missing) if missing.size() > 0 else "")
	_syncing = false


func select_character(path: String) -> void:
	_syncing = true
	for i in characters.size():
		if characters[i] == path:
			_char_opt.select(i)
	_syncing = false
