class_name LabVisualTab
extends VBoxContainer
## Aba "Visual" do menu: criador de personagem (cores, roupas, rosto, cabelo, extras, proporções).

var player: LabPlayer
var look: LabLook
var _syncing := false
var _reg: Array = []              # entradas p/ sincronizar o menu com a configuração
var _name_edit: LineEdit
var _saved_opt: OptionButton
var _msg: Label

const PAL := {
	"skin": LabLook.SKIN, "hair": LabLook.HAIR_COL, "eyes": LabLook.EYE_COL, "mouth": LabLook.LIP_COL,
}


func build(p_player: LabPlayer) -> void:
	player = p_player
	look = player.look
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_top()
	_section_pele_cabelo()
	_section_rosto()
	_section_roupas()
	_section_extras()
	_section_corpo()
	refresh()
	look.changed.connect(func(): pass)


# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------
func _nofocus(c: Control) -> void:
	c.focus_mode = Control.FOCUS_NONE


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	return l


func _section(title: String, opened := false) -> VBoxContainer:
	var head := Button.new()
	head.toggle_mode = true
	head.button_pressed = opened
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nofocus(head)
	var body := VBoxContainer.new()
	body.visible = opened
	head.text = ("▼ " if opened else "▶ ") + title
	head.toggled.connect(func(v):
		body.visible = v
		head.text = ("▼ " if v else "▶ ") + title)
	add_child(head)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_child(body)
	add_child(margin)
	return body


func _lbl(parent: Control, text: String, w := 0) -> Label:
	var l := Label.new()
	l.text = text
	if w > 0:
		l.custom_minimum_size.x = w
	parent.add_child(l)
	return l


func _color_row(parent: Control, text: String, cat: String, palette: Array, key := "color") -> void:
	var row := HBoxContainer.new()
	_lbl(row, text, 78)
	var cp := ColorPickerButton.new()
	cp.custom_minimum_size = Vector2(44, 24)
	cp.edit_alpha = false
	_nofocus(cp)
	cp.color_changed.connect(func(c: Color):
		if not _syncing:
			look.set_value(cat, key, c.to_html(false)))
	row.add_child(cp)
	var sw := HFlowContainer.new()
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.add_theme_constant_override("h_separation", 2)
	sw.add_theme_constant_override("v_separation", 2)
	for hex in palette:
		var b := Button.new()
		b.custom_minimum_size = Vector2(16, 16)
		_nofocus(b)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(String(hex))
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var h: String = String(hex)
		b.pressed.connect(func():
			cp.color = Color(h)
			look.set_value(cat, key, h))
		sw.add_child(b)
	row.add_child(sw)
	parent.add_child(row)
	_reg.append({"kind": "color", "cat": cat, "key": key, "node": cp})


func _style_row(parent: Control, text: String, cat: String) -> void:
	var names: Array = LabParts.CATALOG[cat]
	var row := HBoxContainer.new()
	_lbl(row, text, 78)
	var prev := Button.new()
	prev.text = "◀"
	_nofocus(prev)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.fit_to_longest_item = false
	_nofocus(ob)
	for n in names:
		ob.add_item(String(n))
	var next := Button.new()
	next.text = "▶"
	_nofocus(next)
	var setter := func(i: int):
		var n := names.size()
		i = (i % n + n) % n
		ob.select(i)
		look.set_value(cat, "style", i)
	ob.item_selected.connect(func(i): if not _syncing: setter.call(i))
	prev.pressed.connect(func(): setter.call(ob.selected - 1))
	next.pressed.connect(func(): setter.call(ob.selected + 1))
	row.add_child(prev)
	row.add_child(ob)
	row.add_child(next)
	parent.add_child(row)
	_reg.append({"kind": "style", "cat": cat, "node": ob})


func _slider_row(parent: Control, text: String, cat: String, key: String, mn: float, mx: float, step: float) -> void:
	var row := HBoxContainer.new()
	_lbl(row, text, 120)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nofocus(s)
	var v := Label.new()
	v.custom_minimum_size.x = 42
	s.value_changed.connect(func(x: float):
		v.text = "%.2f" % x
		if not _syncing:
			look.set_value(cat, key, x))
	row.add_child(s)
	row.add_child(v)
	parent.add_child(row)
	_reg.append({"kind": "slider", "cat": cat, "key": key, "node": s, "label": v})


func _check_row(parent: Control, text: String, cat: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	_nofocus(c)
	c.toggled.connect(func(v: bool):
		if not _syncing:
			look.set_value(cat, key, v))
	parent.add_child(c)
	_reg.append({"kind": "check", "cat": cat, "key": key, "node": c})


func _mr(parent: Control, cat: String, metal := true) -> void:
	_slider_row(parent, "Rugosidade", cat, "rough", 0.0, 1.0, 0.05)
	if metal:
		_slider_row(parent, "Metal", cat, "metal", 0.0, 1.0, 0.05)


# -----------------------------------------------------------------------------
# seções
# -----------------------------------------------------------------------------
func _build_top() -> void:
	add_child(_title("Criador de personagem"))
	var l := Label.new()
	l.text = "As mudanças valem para o macho e a fêmea e funcionam com todas as animações e armas."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	var row := HBoxContainer.new()
	var rnd := Button.new()
	rnd.text = "🎲 Aleatório"
	_nofocus(rnd)
	rnd.pressed.connect(func():
		look.randomize_look()
		refresh())
	var rst := Button.new()
	rst.text = "Resetar"
	_nofocus(rst)
	rst.pressed.connect(func():
		look.config = LabLook.defaults()
		look.apply_all()
		refresh())
	row.add_child(rnd)
	row.add_child(rst)
	add_child(row)

	var cam := HBoxContainer.new()
	_lbl(cam, "Câmera: ")
	for f in [["Corpo", "body"], ["Rosto", "face"], ["Costas", "back"], ["Pés", "feet"]]:
		var b := Button.new()
		b.text = f[0]
		_nofocus(b)
		var key: String = f[1]
		b.pressed.connect(func(): player.set_focus(key))
		cam.add_child(b)
	add_child(cam)
	var spin := CheckBox.new()
	spin.text = "Girar sozinho (vitrine)  |  arraste com o botão esquerdo p/ girar"
	spin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nofocus(spin)
	spin.toggled.connect(func(v): player.auto_rotate = v)
	add_child(spin)

	var body := _section("Salvar / carregar", true)
	var r2 := HBoxContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "nome do personagem"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save := Button.new()
	save.text = "Salvar"
	_nofocus(save)
	save.pressed.connect(func():
		if look.save_to(_name_edit.text):
			_msg.text = "Salvo em: " + ProjectSettings.globalize_path(LabLook.save_dir())
			_refresh_saved()
		else:
			_msg.text = "Digite um nome para salvar.")
	r2.add_child(_name_edit)
	r2.add_child(save)
	body.add_child(r2)
	var r3 := HBoxContainer.new()
	_saved_opt = OptionButton.new()
	_saved_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saved_opt.fit_to_longest_item = false
	_nofocus(_saved_opt)
	var load_b := Button.new()
	load_b.text = "Carregar"
	_nofocus(load_b)
	load_b.pressed.connect(func():
		if _saved_opt.item_count > 0:
			var nm := _saved_opt.get_item_text(_saved_opt.selected)
			if look.load_from(nm):
				_name_edit.text = nm
				_msg.text = "Carregado: " + nm
				refresh()
			else:
				_msg.text = "Não consegui carregar.")
	var open_b := Button.new()
	open_b.text = "Pasta"
	_nofocus(open_b)
	open_b.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path(LabLook.save_dir())))
	r3.add_child(_saved_opt)
	r3.add_child(load_b)
	r3.add_child(open_b)
	body.add_child(r3)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_msg)
	_refresh_saved()


func _refresh_saved() -> void:
	_saved_opt.clear()
	for n in LabLook.list_saved():
		_saved_opt.add_item(n)


func _section_pele_cabelo() -> void:
	var b := _section("Pele e cabelo", true)
	_color_row(b, "Pele", "skin", LabLook.SKIN)
	_slider_row(b, "Rugosidade", "skin", "rough", 0.0, 1.0, 0.05)
	_style_row(b, "Cabelo", "hair")
	_color_row(b, "Cor", "hair", LabLook.HAIR_COL)
	_slider_row(b, "Rugosidade", "hair", "rough", 0.0, 1.0, 0.05)
	_style_row(b, "Chapéu", "hat")
	_color_row(b, "Cor", "hat", LabLook.CLOTH_COL)
	_mr(b, "hat")


func _section_rosto() -> void:
	var b := _section("Rosto")
	_style_row(b, "Olhos", "eyes")
	_color_row(b, "Cor", "eyes", LabLook.EYE_COL)
	_style_row(b, "Sobrancelha", "brows")
	_check_row(b, "Mesma cor do cabelo", "brows", "link")
	_color_row(b, "Cor", "brows", LabLook.HAIR_COL)
	_style_row(b, "Boca", "mouth")
	_color_row(b, "Cor", "mouth", LabLook.LIP_COL)
	_style_row(b, "Nariz", "nose")
	_style_row(b, "Orelhas", "ears")
	_style_row(b, "Barba", "beard")
	_check_row(b, "Mesma cor do cabelo", "beard", "link")
	_color_row(b, "Cor", "beard", LabLook.HAIR_COL)
	_style_row(b, "Óculos", "glasses")
	_color_row(b, "Cor", "glasses", LabLook.CLOTH_COL)
	_mr(b, "glasses")


func _section_roupas() -> void:
	var b := _section("Roupas", true)
	b.add_child(_title("Camisa / jaqueta"))
	_check_row(b, "Usar camisa", "shirt", "on")
	_color_row(b, "Cor", "shirt", LabLook.CLOTH_COL)
	_slider_row(b, "Manga (0 = sem)", "shirt", "sleeve", 0.0, 1.0, 0.05)
	_slider_row(b, "Barra (altura)", "shirt", "hem", 0.85, 1.40, 0.01)
	_slider_row(b, "Decote (altura)", "shirt", "neck", 1.55, 1.72, 0.01)
	_slider_row(b, "Volume", "shirt", "volume", 0.0, 0.035, 0.001)
	_mr(b, "shirt")
	_check_row(b, "Acabamento (barras/punhos)", "trim", "on")
	_color_row(b, "Cor", "trim", LabLook.CLOTH_COL)
	b.add_child(HSeparator.new())
	b.add_child(_title("Calça / bermuda"))
	_check_row(b, "Usar calça", "pants", "on")
	_color_row(b, "Cor", "pants", LabLook.CLOTH_COL)
	_slider_row(b, "Comprimento", "pants", "len", 0.15, 1.0, 0.05)
	_slider_row(b, "Volume", "pants", "volume", 0.0, 0.035, 0.001)
	_mr(b, "pants")
	b.add_child(HSeparator.new())
	b.add_child(_title("Calçado"))
	_check_row(b, "Usar calçado", "shoes", "on")
	_color_row(b, "Cor", "shoes", LabLook.CLOTH_COL)
	_slider_row(b, "Cano da bota", "shoes", "boot", 0.0, 0.7, 0.05)
	_slider_row(b, "Volume", "shoes", "volume", 0.0, 0.035, 0.001)
	_mr(b, "shoes")
	b.add_child(HSeparator.new())
	b.add_child(_title("Luvas"))
	_check_row(b, "Usar luvas", "gloves", "on")
	_color_row(b, "Cor", "gloves", LabLook.CLOTH_COL)
	_slider_row(b, "Cano (antebraço)", "gloves", "arm", 0.0, 0.8, 0.05)
	_mr(b, "gloves")
	b.add_child(HSeparator.new())
	b.add_child(_title("Cinto"))
	_check_row(b, "Usar cinto", "belt", "on")
	_color_row(b, "Cor", "belt", LabLook.CLOTH_COL)
	_slider_row(b, "Altura", "belt", "y", 0.95, 1.40, 0.01)
	_mr(b, "belt")


func _section_extras() -> void:
	var b := _section("Extras")
	for e in [["Ombreiras", "shoulders"], ["Costas", "back"], ["Cintura", "waist"], ["Pescoço", "neck"]]:
		_style_row(b, e[0], e[1])
		_color_row(b, "Cor", e[1], LabLook.CLOTH_COL)
		_mr(b, e[1])
		b.add_child(HSeparator.new())


func _section_corpo() -> void:
	var b := _section("Proporções do corpo")
	_slider_row(b, "Altura", "body", "height", 0.85, 1.20, 0.01)
	_slider_row(b, "Peito / ombros", "body", "chest", 0.85, 1.25, 0.01)
	_slider_row(b, "Braços (espessura)", "body", "arms", 0.80, 1.30, 0.01)
	_slider_row(b, "Pernas (espessura)", "body", "legs", 0.85, 1.20, 0.01)
	_slider_row(b, "Cabeça", "body", "head", 0.80, 1.30, 0.01)
	var l := Label.new()
	l.text = "Escala de ossos: as animações do Mixamo não têm tracks de escala, então funciona com todas."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(l)


# -----------------------------------------------------------------------------
## puxa a configuração para os controles (depois de carregar / aleatório / trocar personagem)
func refresh() -> void:
	_syncing = true
	for e in _reg:
		var cfg: Dictionary = look.config.get(e.cat, {})
		match e.kind:
			"color":
				(e.node as ColorPickerButton).color = Color(String(cfg.get(e.key, "ffffff")))
			"style":
				(e.node as OptionButton).select(clampi(int(cfg.get("style", 0)), 0, (e.node as OptionButton).item_count - 1))
			"slider":
				(e.node as HSlider).value = float(cfg.get(e.key, 0.0))
				(e.label as Label).text = "%.2f" % float(cfg.get(e.key, 0.0))
			"check":
				(e.node as CheckBox).button_pressed = bool(cfg.get(e.key, false))
	_syncing = false
