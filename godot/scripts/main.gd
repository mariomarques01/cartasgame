extends Control
## Cartas — Reinos do Destino | protótipo Godot vertical.
## Cena e interface criadas por código, sem dependência de artes externas.

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
	_build_ui()
	new_game()

func _hero(name: String, suit: String, rank: String, side: int, hp: int, atk: int, defense: int) -> Dictionary:
	return {"name":name,"suit":suit,"rank":rank,"side":side,"hp":hp,"max_hp":hp,"atk":atk,"def":defense,"shield":0}

func new_game() -> void:
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
		_draw(0)
		_draw(1)
	_log("Partida iniciada com um baralho único de 38 cartas.")
	_begin_turn()

func _draw(side: int) -> void:
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
		_draw(current_side)
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
			_draw(current_side)
			_draw(current_side)
			if not hands[current_side].is_empty():
				discard.append(hands[current_side].pop_back())
		"♣":
			heroes[actor]["shield"] = mini(4,int(heroes[actor]["shield"]) + 2)
	_log("Ás de %s ativado (protótipo)." % suit)
	_refresh()

func _end_turn() -> void:
	if finished: return
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
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 10)
	safe.add_theme_constant_override("margin_right", 10)
	safe.add_theme_constant_override("margin_top", 22)
	safe.add_theme_constant_override("margin_bottom", 16)
	add_child(safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	safe.add_child(layout)
	var heading := _make_label("CARTAS  -  REINOS DO DESTINO", 21)
	heading.add_theme_color_override("font_color", GOLD)
	layout.add_child(heading)
	ui["status"] = _make_label("", 14)
	ui["status"].add_theme_color_override("font_color", CREAM)
	layout.add_child(ui["status"])
	var field := PanelContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = GREEN
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
	scroll.custom_minimum_size = Vector2(0, 112)
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
	panel.custom_minimum_size = Vector2(72, 74)
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
	button.custom_minimum_size = Vector2(95, 118)
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
		for child in container.get_children(): child.queue_free()
		for i in heroes.size():
			var h: Dictionary = heroes[i]
			if h["side"] != side: continue
			var card := _make_card("%s\n%s\nVIDA %d/%d\nDEF %d  ESC %d" % [_suit_name(h["suit"]),h["name"],h["hp"],h["max_hp"],h["def"],h["shield"]],h["suit"] in ["♥","♦"],func(): _select_hero(i),i == selected_actor or i == selected_target)
			card.custom_minimum_size = Vector2(0, 118)
			container.add_child(card)
	for child in ui["hand"].get_children(): child.queue_free()
	for i in hands[0].size():
		var c: Dictionary = hands[0][i]
		var title: String = "CORINGA" if c.has("joker") else "%d\n%s" % [c["value"],_suit_name(c["suit"])]
		var card := _make_card("%s\nCUSTO %d" % [title,_cost(c)],c.get("suit","") in ["♥","♦"],func(): _select_card(i),i == selected_index)
		card.custom_minimum_size = Vector2(90, 110)
		ui["hand"].add_child(card)
	for button in ui["actions"].get_children():
		button.disabled = finished or current_side != 0
	ui["message"].text = history.back() if not history.is_empty() else ""

func _select_hero(index: int) -> void:
	if finished or current_side != 0 or heroes[index]["hp"] <= 0: return
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
	selected_index = index
	_refresh()

func _on_play() -> void:
	if current_side != 0 or finished: return
	if not _play_card(0,selected_index,selected_actor,selected_target):
		_log("Jogada inválida: selecione uma carta e um alvo compatível.")
		_refresh()

func _on_attack() -> void:
	_basic_attack(selected_actor,selected_target)

func _on_ace() -> void:
	_activate_ace(selected_actor,selected_target)
