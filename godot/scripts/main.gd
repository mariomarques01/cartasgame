extends Control
## Cartas — Reinos do Destino | protótipo Godot vertical.
## Interface responsiva com catálogo de artes oficiais.

const SUITS := ["♥", "♦", "♠", "♣"]
const MAX_ENERGY := 6
const GOAL := 12

var rng := RandomNumberGenerator.new()
var deck: Array[Dictionary] = []
var discard: Array[Dictionary] = []
var hands: Array = [[], []]
var heroes: Array[Dictionary] = []
var energy := [3, 3]
var glory := [0, 0]
var round_number := 1
var current_side := 0
var used_card := false
var used_attack := false
var used_ace := false
var damage_scored := false
var finished := false
var selected_index := -1
var selected_actor := 0
var selected_target := 3
var ui: Dictionary = {}
var history: Array[String] = []
const GOLD := Color("#d5af69")
const CREAM := Color("#f4e3bf")
const INK := Color("#26312f")
const GREEN := Color("#15392f")
const RED := Color("#9e3e45")

var card_art: Dictionary = {}
const ArtCatalog = preload("res://scripts/card_art.gd")
const VERIFIED_ART = ArtCatalog.PATHS
var gallery_overlay: Control
var hero_views: Dictionary = {}
var hand_views: Array[Button] = []
var busy := false
var match_id := 0

func _suit_name(suit: String) -> String:
	match suit:
		"♥": return "COPAS"
		"♦": return "OUROS"
		"♠": return "ESPADAS"
		"♣": return "PAUS"
	return "CORINGA"

func _ornament(parent: Control) -> void:
	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 4)
	parent.add_child(rule)


func _ready() -> void:
	rng.randomize()
	for key in VERIFIED_ART:
		var asset_path: String = VERIFIED_ART[key]
		if ResourceLoader.exists(asset_path):
			card_art[key] = load(asset_path)
	_build_ui()
	new_game()

func _hero(name: String, suit: String, rank: String, side: int, hp: int, atk: int, defense: int) -> Dictionary:
	return {"name":name,"suit":suit,"rank":rank,"side":side,"hp":hp,"max_hp":hp,"atk":atk,"def":defense,"shield":0}

func new_game() -> void:
	match_id += 1
	busy = false
	selected_actor = 0
	selected_target = 3
	heroes = [
		_hero("Rei de Espadas","♠","K",0,14,4,3),
		_hero("Rainha de Copas","♥","Q",0,11,2,2),
		_hero("Valete de Paus","♣","J",0,9,3,1),
		_hero("Rei de Ouros","♦","K",1,14,4,3),
		_hero("Rainha de Paus","♣","Q",1,11,2,2),
		_hero("Valete de Copas","♥","J",1,9,3,1)
	]
	deck.clear()
	discard.clear()
	for suit in SUITS:
		for value in range(2,11):
			deck.append({"id":"%s%d" % [suit,value],"suit":suit,"value":value})
	deck.append({"id":"joker-red","joker":"red"})
	deck.append({"id":"joker-blue","joker":"blue"})
	deck.shuffle()
	hands = [[],[]]
	energy = [3,3]
	glory = [0,0]
	round_number = 1
	current_side = 0
	finished = false
	selected_index = -1
	history.clear()
	for i in 3:
		_draw_card(0)
		_draw_card(1)
	_log("Partida iniciada com um baralho único de 38 cartas.")
	_begin_turn()

func _draw_card(side: int) -> void:
	if deck.is_empty():
		return
	hands[side].append(deck.pop_back())

func _begin_turn() -> void:
	used_card = false
	used_attack = false
	used_ace = false
	damage_scored = false
	selected_index = -1
	for i in heroes.size():
		if heroes[i]["side"] == current_side:
			heroes[i]["shield"] = 0
	energy[current_side] = mini(MAX_ENERGY, energy[current_side] + 2)
	if not (round_number == 1 and current_side == 0):
		_draw_card(current_side)
	_log("Rodada %d — %s." % [round_number, "seu turno" if current_side == 0 else "turno rival"])
	_refresh()

func _power(value: int) -> int:
	if value <= 4: return 1
	if value <= 7: return 2
	return 3

func _cost(card: Dictionary) -> int:
	if card.has("joker"): return 3
	if card["value"] <= 4: return 1
	if card["value"] <= 7: return 2
	return 3

func _alive(side: int) -> Array[int]:
	var result: Array[int] = []
	for i in heroes.size():
		if heroes[i]["side"] == side and heroes[i]["hp"] > 0:
			result.append(i)
	return result

func _damage(attacker: int, target: int, bonus: int = 0, pierce: int = 0) -> void:
	var a := heroes[attacker]
	var t := heroes[target]
	var damage: int = maxi(1, int(a["atk"]) + bonus - maxi(0,int(t["def"]) - pierce))
	if a["rank"] == "K" and a["suit"] == "♣" and t["hp"] == t["max_hp"]:
		damage += 1
	var shield_used: int = mini(damage,int(t["shield"]))
	damage -= shield_used
	t["shield"] -= shield_used
	var dealt: int = mini(damage,int(t["hp"]))
	t["hp"] -= dealt
	var points := 0
	if dealt >= 3 and not damage_scored:
		points += 1
		damage_scored = true
	if t["hp"] <= 0:
		points += 3 if t["rank"] == "K" else 2
	glory[current_side] += points
	_log("%s → %s: %d PV, %d escudos, +%d PG." % [a["name"],t["name"],dealt,shield_used,points])
	_check_victory()

func _check_victory() -> void:
	if glory[0] >= GOAL or glory[1] >= GOAL or _alive(0).is_empty() or _alive(1).is_empty():
		finished = true
		var won: bool = glory[0] >= GOAL or _alive(1).is_empty()
		_log("VITÓRIA!" if won else "DERROTA!")
	_refresh()

func _play_card(side: int, index: int, actor: int, target: int) -> bool:
	if finished or used_card or index < 0 or index >= hands[side].size(): return false
	if actor not in _alive(side) or target < 0 or target >= heroes.size() or heroes[target]["hp"] <= 0: return false
	var card: Dictionary = hands[side][index]
	var c: int = _cost(card)
	if energy[side] < c: return false
	var attack_card: bool = not card.has("joker") and card["suit"] in ["♠","♣"]
	if attack_card and (used_attack or heroes[target]["side"] == side): return false
	if not attack_card and not card.has("joker") and heroes[target]["side"] != side: return false
	energy[side] -= c
	if card.has("joker"):
		heroes[actor]["shield"] = mini(4, int(heroes[actor]["shield"]) + 3)
		_log("Coringa: proteção provisória +3.")
	else:
		var power: int = _power(card["value"]) + (1 if card["suit"] == heroes[actor]["suit"] else 0)
		match card["suit"]:
			"♥":
				heroes[target]["hp"] = mini(int(heroes[target]["max_hp"]),int(heroes[target]["hp"]) + 1 + power)
				_log("Copas restaura Vida.")
			"♦":
				energy[side] = mini(MAX_ENERGY,energy[side] + power)
				heroes[target]["shield"] = mini(4,int(heroes[target]["shield"]) + 1 + power)
				_log("Ouros concede Energia e escudos.")
			"♠","♣":
				if card["suit"] == "♣":
					heroes[actor]["shield"] = mini(4,int(heroes[actor]["shield"]) + 1)
				_damage(actor,target,power,1 if card["suit"] == "♠" else 0)
				used_attack = true
	hands[side].remove_at(index)
	discard.append(card)
	used_card = true
	selected_index = -1
	_refresh()
	return true

func _basic_attack(actor: int, target: int) -> void:
	if finished or used_attack or actor not in _alive(current_side) or target not in _alive(1-current_side): return
	_damage(actor,target)
	used_attack = true
	_refresh()

func _activate_ace(actor: int, target: int) -> void:
	if finished or used_ace or actor not in _alive(current_side) or energy[current_side] < 2: return
	var suit: String = heroes[actor]["suit"]
	if suit == "♥" and target not in _alive(current_side): return
	energy[current_side] -= 2
	used_ace = true
	match suit:
		"♥":
			heroes[target]["hp"] = mini(int(heroes[target]["max_hp"]),int(heroes[target]["hp"]) + 3)
			heroes[target]["shield"] = mini(4,int(heroes[target]["shield"]) + 1)
		"♦": energy[current_side] = mini(6,energy[current_side] + 3)
		"♠":
			_draw_card(current_side)
			_draw_card(current_side)
			if not hands[current_side].is_empty():
				discard.append(hands[current_side].pop_back())
		"♣":
			heroes[actor]["shield"] = mini(4,int(heroes[actor]["shield"]) + 2)
	_log("Ás de %s ativado (protótipo)." % suit)
	_refresh()

func _end_turn() -> void:
	if finished or busy: return
	while hands[current_side].size() > 5:
		discard.append(hands[current_side].pop_back())
	if current_side == 1 and round_number == 5:
		for side in 2:
			if _alive(side).size() == 3:
				glory[side] += 2
		_check_victory()
	if finished: return
	if current_side == 1: round_number += 1
	current_side = 1 - current_side
	_begin_turn()
	if current_side == 1:
		_enemy_turn()

func _enemy_turn() -> void:
	if finished: return
	var allies := _alive(1)
	var opponents := _alive(0)
	if allies.is_empty() or opponents.is_empty(): return
	var actor: int = allies[0]
	var target: int = opponents[0]
	for i in opponents:
		if heroes[i]["hp"] < heroes[target]["hp"]: target = i
	for i in hands[1].size():
		var card: Dictionary = hands[1][i]
		if not card.has("joker") and card["suit"] in ["♠","♣"] and _cost(card) <= energy[1]:
			_play_card(1,i,actor,target)
			break
	if not used_attack and not finished:
		_basic_attack(actor,target)
	if not finished: _end_turn()

func _log(message: String) -> void:
	history.append(message)
	if history.size() > 80: history.pop_front()

func _make_label(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#101c23")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page)
	var safe := MarginContainer.new()
	safe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 10)
	safe.add_theme_constant_override("margin_right", 10)
	safe.add_theme_constant_override("margin_top", 10)
	safe.add_theme_constant_override("margin_bottom", 16)
	page.add_child(safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	safe.add_child(layout)
	var heading := _make_label("CARTAS  -  REINOS DO DESTINO", 21)
	heading.add_theme_color_override("font_color", GOLD)
	layout.add_child(heading)
	ui["status"] = _make_label("", 14)
	ui["status"].add_theme_color_override("font_color", CREAM)
	layout.add_child(ui["status"])
	var gallery_button := Button.new()
	gallery_button.text = "VER 48 CARTAS OFICIAIS"
	gallery_button.custom_minimum_size = Vector2(0, 36)
	gallery_button.add_theme_font_size_override("font_size", 13)
	gallery_button.pressed.connect(_show_gallery)
	layout.add_child(gallery_button)
	var field := PanelContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#173528")
	style.border_color = GOLD
	style.set_border_width_all(5)
	style.set_corner_radius_all(16)
	field.add_theme_stylebox_override("panel", style)
	layout.add_child(field)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	field.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)
	var enemy_label := _make_label("REINO ADVERSARIO", 15)
	enemy_label.add_theme_color_override("font_color", GOLD)
	rows.add_child(enemy_label)
	ui["enemy"] = HBoxContainer.new()
	ui["enemy"].alignment = BoxContainer.ALIGNMENT_CENTER
	ui["enemy"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui["enemy"].add_theme_constant_override("separation", 5)
	rows.add_child(ui["enemy"])
	_ornament(rows)
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	rows.add_child(center)
	var deck_button := _make_pile("BARALHO")
	center.add_child(deck_button)
	var battlefield := VBoxContainer.new()
	battlefield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(battlefield)
	var field_title := _make_label("CAMPO DE BATALHA", 12)
	field_title.add_theme_color_override("font_color", GOLD)
	battlefield.add_child(field_title)
	ui["counts"] = _make_label("", 11)
	battlefield.add_child(ui["counts"])
	center.add_child(_make_pile("DESCARTE"))
	_ornament(rows)
	var player_label := _make_label("SEUS HEROIS", 15)
	player_label.add_theme_color_override("font_color", GOLD)
	rows.add_child(player_label)
	ui["player"] = HBoxContainer.new()
	ui["player"].alignment = BoxContainer.ALIGNMENT_CENTER
	ui["player"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui["player"].add_theme_constant_override("separation", 5)
	rows.add_child(ui["player"])
	var hand_label := _make_label("SUA MAO", 16)
	hand_label.add_theme_color_override("font_color", GOLD)
	layout.add_child(hand_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 158)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	ui["hand"] = HBoxContainer.new()
	ui["hand"].add_theme_constant_override("separation", 6)
	scroll.add_child(ui["hand"])
	ui["actions"] = HBoxContainer.new()
	ui["actions"].alignment = BoxContainer.ALIGNMENT_CENTER
	ui["actions"].add_theme_constant_override("separation", 5)
	layout.add_child(ui["actions"])
	for label in ["Jogar", "Atacar", "As", "Encerrar"]:
		var button := Button.new()
		button.text = label
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 13)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("#aa854a")
		bs.border_color = Color("#f1d5a0")
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(7)
		button.add_theme_stylebox_override("normal", bs)
		button.add_theme_color_override("font_color", Color("#1c2726"))
		ui["actions"].add_child(button)
		match label:
			"Jogar": button.pressed.connect(_on_play)
			"Atacar": button.pressed.connect(_on_attack)
			"As": button.pressed.connect(_on_ace)
			"Encerrar": button.pressed.connect(_end_turn)
	var new_button := Button.new()
	new_button.text = "Nova partida"
	new_button.custom_minimum_size = Vector2(0, 32)
	new_button.add_theme_font_size_override("font_size", 12)
	layout.add_child(new_button)
	new_button.pressed.connect(new_game)
	ui["message"] = _make_label("", 11)
	ui["message"].add_theme_color_override("font_color", GOLD)
	layout.add_child(ui["message"])

func _make_pile(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(62, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#284c4b")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var label := _make_label(title, 10)
	label.add_theme_color_override("font_color", CREAM)
	panel.add_child(label)
	return panel

func _make_card(text: String, is_red: bool, pressed: Callable, selected: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(95, 160)
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = Color("#8fe4b8") if selected else GOLD
	style.set_border_width_all(4 if selected else 3)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 3
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", RED if is_red else INK)
	button.pressed.connect(pressed)
	return button

func _refresh() -> void:
	if ui.is_empty(): return
	ui["status"].text = "Rodada %d  |  Voce: %d PG / %d Energia  |  Rival: %d PG / %d Energia" % [round_number,glory[0],energy[0],glory[1],energy[1]]
	ui["counts"].text = "Baralho: %d   •   Descarte: %d   •   Mão rival: %d" % [deck.size(),discard.size(),hands[1].size()]
	for side in 2:
		var container: HBoxContainer = ui["player"] if side == 0 else ui["enemy"]
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
		for i in heroes.size():
			var h: Dictionary = heroes[i]
			if h["side"] != side: continue
			var card := _make_card("%s\n%s\nVIDA %d/%d\nDEF %d  ESC %d" % [_suit_name(h["suit"]),h["name"],h["hp"],h["max_hp"],h["def"],h["shield"]],h["suit"] in ["♥","♦"],func(): _select_hero(i),i == selected_actor or i == selected_target)
			card.custom_minimum_size = Vector2(0, 160)
			container.add_child(card)
			hero_views[i] = card
			card.set_drag_forwarding(Callable(), _can_drop_on_hero.bind(i), _drop_on_hero.bind(i))
			var hero_key: String = h["suit"] + h["rank"]
			if card_art.has(hero_key):
				_attach_art(card, card_art[hero_key], true)
				_badge(card, "♥ %d/%d  ⚔ %d\nDEF %d  ESC %d" % [h["hp"],h["max_hp"],h["atk"],h["def"],h["shield"]])
			card.modulate.a = 0.35 if h["hp"] <= 0 else 1.0
	for child in ui["hand"].get_children():
		ui["hand"].remove_child(child)
		child.queue_free()
	hand_views.clear()
	for i in hands[0].size():
		var c: Dictionary = hands[0][i]
		var title: String = "CORINGA" if c.has("joker") else "%d\n%s" % [c["value"],_suit_name(c["suit"])]
		var card := _make_card("%s\nCUSTO %d" % [title,_cost(c)],c.get("suit","") in ["♥","♦"],func(): _select_card(i),i == selected_index)
		card.custom_minimum_size = Vector2(104, 150)
		ui["hand"].add_child(card)
		hand_views.append(card)
		card.set_drag_forwarding(_drag_card.bind(i), Callable(), Callable())
		card.tooltip_text = _ability(c)
		var art_key: String = ("joker-red" if c["joker"] == "red" else "joker-blue") if c.has("joker") else c["suit"] + str(c["value"])
		if card_art.has(art_key):
			_attach_art(card, card_art[art_key], false)
			_badge(card, "%s • %d E" % [_ability(c), _cost(c)])
	for button in ui["actions"].get_children():
		button.disabled = finished or current_side != 0 or busy
		if button.text == "Jogar": button.disabled = button.disabled or used_card or selected_index < 0
		if button.text == "Atacar": button.disabled = button.disabled or used_attack
		if button.text == "As": button.disabled = button.disabled or used_ace or energy[0] < 2
	ui["message"].text = history.back() if not history.is_empty() else ""

func _attach_art(card: Button, texture: Texture2D, _is_hero: bool) -> void:
	card.text = ""
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 2
	art.offset_top = 2
	art.offset_right = -2
	art.offset_bottom = -2
	card.add_child(art)
func _select_hero(index: int) -> void:
	if busy or finished or current_side != 0 or heroes[index]["hp"] <= 0: return
	if heroes[index]["side"] == 0:
		selected_actor = index
		if selected_index >= 0 and selected_index < hands[0].size():
			var card: Dictionary = hands[0][selected_index]
			if not card.has("joker") and card["suit"] in ["♥","♦"]:
				selected_target = index
	else:
		selected_target = index
	_refresh()

func _select_card(index: int) -> void:
	if busy or finished or current_side != 0: return
	selected_index = index
	var card: Dictionary = hands[0][index]
	if card.has("joker") or card.get("suit", "") in ["♥", "♦"]:
		selected_target = selected_actor
	elif selected_target not in _alive(1):
		selected_target = _alive(1)[0]
	_log(_ability(card) + " — escolha o alvo e toque Jogar, ou arraste a carta.")
	_refresh()

func _on_play() -> void:
	if current_side != 0 or finished or busy: return
	if not _can_play_on(selected_index, selected_target):
		_log("Jogada inválida: verifique energia, alvo e ações disponíveis.")
		_refresh()
		return
	var index := selected_index
	var actor := selected_actor
	var target := selected_target
	var token := match_id
	busy = true
	await _fly_card(index, target)
	if token != match_id: return
	busy = false
	_play_card(0, index, actor, target)
	_pulse(target, Color("77e5ad") if heroes[target]["side"] == 0 else Color("ff7777"))

func _on_attack() -> void:
	if busy or current_side != 0 or finished or used_attack: return
	var target := selected_target
	_basic_attack(selected_actor,target)
	_pulse(target, Color("ff7777"))

func _on_ace() -> void:
	if busy or current_side != 0: return
	_activate_ace(selected_actor,selected_target)
	_pulse(selected_actor, GOLD)

func _ability(card: Dictionary) -> String:
	if card.has("joker"): return "Escudo +3"
	match card["suit"]:
		"♥": return "Cura"
		"♦": return "Energia / escudo"
		"♠": return "Ataque perfurante"
		"♣": return "Ataque / escudo"
	return ""

func _badge(card: Control, text: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -36
	panel.offset_left = 4
	panel.offset_right = -4
	panel.offset_bottom = -4
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.1, 0.94)
	panel.add_theme_stylebox_override("panel", style)
	card.add_child(panel)
	var label := _make_label(text, 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", CREAM)
	panel.add_child(label)

func _can_play_on(index: int, target: int) -> bool:
	if busy or finished or current_side != 0 or used_card: return false
	if index < 0 or index >= hands[0].size() or selected_actor not in _alive(0): return false
	var card: Dictionary = hands[0][index]
	if energy[0] < _cost(card): return false
	if card.has("joker"): return target == selected_actor
	if card["suit"] in ["♠", "♣"]: return not used_attack and target in _alive(1)
	return target in _alive(0)

func _drag_card(_position: Vector2, index: int) -> Variant:
	if busy or finished or current_side != 0 or used_card: return null
	selected_index = index
	var preview := TextureRect.new()
	var card: Dictionary = hands[0][index]
	preview.texture = card_art.get(card["id"])
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(104, 150)
	if preview.texture == null:
		preview.add_child(_make_label(card["id"], 24))
	hand_views[index].set_drag_preview(preview)
	return {"hand_index": index}

func _can_drop_on_hero(_position: Vector2, data: Variant, target: int) -> bool:
	return data is Dictionary and data.has("hand_index") and _can_play_on(int(data["hand_index"]), target)

func _drop_on_hero(_position: Vector2, data: Variant, target: int) -> void:
	selected_index = int(data["hand_index"])
	selected_target = target
	_on_play()

func _fly_card(index: int, target: int) -> void:
	var ghost := Panel.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	ghost.position = hand_views[index].global_position - global_position
	ghost.size = hand_views[index].size
	var card: Dictionary = hands[0][index]
	var tex: Texture2D = card_art.get(card["id"])
	if tex:
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.add_child(art)
	else:
		ghost.add_child(_make_label(card["id"], 30))
	var tween := create_tween()
	tween.tween_property(ghost, "position", hero_views[target].global_position - global_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	ghost.queue_free()

func _pulse(target: int, color: Color) -> void:
	if not hero_views.has(target): return
	var card: Control = hero_views[target]
	card.modulate = color
	var tween := card.create_tween()
	tween.tween_property(card, "modulate", Color(1, 1, 1, 0.35 if heroes[target]["hp"] <= 0 else 1.0), 0.4)

func _show_gallery() -> void:
	if is_instance_valid(gallery_overlay):
		gallery_overlay.queue_free()
	gallery_overlay = ColorRect.new()
	gallery_overlay.color = Color("#101c23")
	gallery_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(gallery_overlay)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	gallery_overlay.add_child(layout)
	var close := Button.new()
	close.text = "VOLTAR AO JOGO"
	close.custom_minimum_size = Vector2(0, 56)
	close.pressed.connect(func(): gallery_overlay.queue_free())
	layout.add_child(close)
	var heading := _make_label("GALERIA - 48 CARTAS OFICIAIS", 18)
	heading.add_theme_color_override("font_color", GOLD)
	layout.add_child(heading)
	var hint := _make_label("Artes originais, sem cortes. Toque para ampliar.", 12)
	layout.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for key in VERIFIED_ART:
		var image_path: String = VERIFIED_ART[key]
		if not ResourceLoader.exists(image_path):
			continue
		var tex: Texture2D = load(image_path)
		var button := TextureButton.new()
		button.texture_normal = tex
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(0, 320)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_full_card.bind(tex))
		grid.add_child(button)

func _show_full_card(tex: Texture2D) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.06, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery_overlay.add_child(shade)
	var image := TextureRect.new()
	image.texture = tex
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_top = 60
	image.offset_bottom = -65
	shade.add_child(image)
	var close := Button.new()
	close.text = "FECHAR CARTA"
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	close.custom_minimum_size = Vector2(0, 52)
	close.pressed.connect(func(): shade.queue_free())
	shade.add_child(close)
