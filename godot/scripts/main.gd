extends Control
## Cartas — Reinos do Destino | Godot 4.3, retrato.
## Estilo duelo de cartas: arraste cartas e heróis, alvos brilham, efeitos animados e turno rival visível.
## Atenção: a fonte padrão não tem símbolos de naipe; a interface usa apenas texto e formas desenhadas.

signal suit_chosen(suit: String)

const SUITS := ["♥", "♦", "♠", "♣"]
const MAX_ENERGY := 6
const MAX_SHIELD := 4
const GOAL := 12
const HAND_LIMIT := 5
const GOLD := Color("#d5af69")
const CREAM := Color("#f4e3bf")
const INK := Color("#26312f")
const RED := Color("#9e3e45")
const OK_GREEN := Color("#7ff0b0")
const FOE_RED := Color("#ff6b5e")
const ACE_TEXT := {
	"♥": "Ás de Copas (2 energia): cura 3 de vida e dá 1 escudo a um aliado.",
	"♦": "Ás de Ouros (2 energia): ganha 3 de energia.",
	"♠": "Ás de Espadas (2 energia): compra 2 cartas e descarta a mais fraca.",
	"♣": "Ás de Paus (2 energia): +2 de ataque no próximo golpe."
}
const PASSIVE_TEXT := {
	"K♥": "Guarda: reduz em 1 o primeiro dano que seu reino sofre por turno.",
	"K♣": "Golpe de Rei: +1 de dano contra alvos com vida cheia.",
	"J♠": "Oportunista: +1 de dano contra alvos feridos.",
	"J♣": "Fúria: +2 de dano quando está com 4 de vida ou menos.",
	"Q♦": "Tesoureira: +1 escudo extra ao usar cartas de Ouros."
}

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
var reshuffled := false
var deck_out := false
var selected_index := -1
var selected_actor := 0
var selected_target := 3
var last_tap := -1
var ui: Dictionary = {}
var history: Array[String] = []
var card_art: Dictionary = {}
const ArtCatalog = preload("res://scripts/card_art.gd")
const VERIFIED_ART = ArtCatalog.PATHS
var gallery_overlay: Control
var hero_views: Dictionary = {}
var hand_views: Array[Button] = []
var fx_queue: Array = []
var busy := false
var fast := false ## testes: sem pausas nem animações
var match_id := 0
var seen_cards := {}
var end_tween: Tween
const BUTTON_TEXT := {"Jogar":"Jogar carta","Atacar":"Atacar","Defender":"Defender","Ás":"Ás (2)","Encerrar":"Encerrar turno"}

func _suit_name(suit: String) -> String:
	match suit:
		"♥": return "COPAS"
		"♦": return "OUROS"
		"♠": return "ESPADAS"
		"♣": return "PAUS"
	return "CORINGA"

func _suit_label(suit: String) -> String:
	return _suit_name(suit).capitalize()

func _ready() -> void:
	randomize()
	for key in VERIFIED_ART:
		var asset_path: String = VERIFIED_ART[key]
		if ResourceLoader.exists(asset_path):
			card_art[key] = load(asset_path)
	_build_ui()
	resized.connect(_refresh)
	new_game()

func _wait(seconds: float) -> void:
	if fast or not is_inside_tree(): return
	await get_tree().create_timer(seconds).timeout

# ─────────────────────────── REGRAS ───────────────────────────

func _hero(hero_name: String, suit: String, rank: String, side: int, hp: int, atk: int, defense: int) -> Dictionary:
	return {"name":hero_name,"suit":suit,"rank":rank,"side":side,"hp":hp,"max_hp":hp,"atk":atk,"def":defense,"shield":0,"ace_bonus":0,"guard_used":false}

func new_game() -> void:
	match_id += 1
	busy = false
	selected_actor = 0
	selected_target = 3
	last_tap = -1
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
	reshuffled = false
	deck_out = false
	selected_index = -1
	fx_queue.clear()
	seen_cards.clear()
	history.clear()
	for i in 3:
		_draw_card(0)
		_draw_card(1)
	_log("Partida iniciada com um baralho único de 38 cartas.")
	_begin_turn()

func _draw_card(side: int) -> bool:
	if deck.is_empty():
		if not reshuffled and not discard.is_empty():
			for c in discard:
				deck.append(c)
			discard.clear()
			deck.shuffle()
			reshuffled = true
			_log("O descarte foi reembaralhado (só acontece uma vez).")
		else:
			deck_out = true
			return false
	hands[side].append(deck.pop_back())
	return true

func _begin_turn() -> void:
	used_card = false
	used_attack = false
	used_ace = false
	damage_scored = false
	selected_index = -1
	last_tap = -1
	for h in heroes:
		h["guard_used"] = false
		if h["side"] == current_side:
			h["shield"] = 0
	energy[current_side] = mini(MAX_ENERGY, energy[current_side] + 2)
	if not (round_number == 1 and current_side == 0):
		_draw_card(current_side)
	if current_side == 0:
		var alive_mine := _alive(0)
		if selected_actor not in alive_mine and not alive_mine.is_empty():
			selected_actor = alive_mine[0]
	_log("Rodada %d — %s." % [round_number, "seu turno" if current_side == 0 else "turno rival"])
	_banner("SEU TURNO" if current_side == 0 else "TURNO RIVAL")
	_refresh()

func _power(value: int) -> int:
	if value <= 4: return 1
	if value <= 7: return 2
	return 3

func _cost(card: Dictionary) -> int:
	if card.has("joker"): return 3
	return _power(int(card["value"]))

func _alive(side: int) -> Array[int]:
	var result: Array[int] = []
	for i in heroes.size():
		if heroes[i]["side"] == side and heroes[i]["hp"] > 0:
			result.append(i)
	return result

func _fx(hero: int, kind: String, text: String) -> void:
	fx_queue.append({"hero":hero,"kind":kind,"text":text})

func _add_shield(idx: int, amount: int) -> void:
	var h := heroes[idx]
	var before: int = h["shield"]
	h["shield"] = mini(MAX_SHIELD, before + amount)
	if int(h["shield"]) > before:
		_fx(idx, "shield", "+%d escudo" % (int(h["shield"]) - before))

func _heal(idx: int, amount: int) -> int:
	var h := heroes[idx]
	var before: int = h["hp"]
	h["hp"] = mini(int(h["max_hp"]), before + amount)
	var gained: int = int(h["hp"]) - before
	if gained > 0:
		_fx(idx, "heal", "+%d" % gained)
	return gained

func _add_energy(side: int, amount: int, hero: int) -> void:
	energy[side] = mini(MAX_ENERGY, energy[side] + amount)
	_fx(hero, "energy", "+%d energia" % amount)

func _passive_bonus(a: Dictionary, t: Dictionary) -> int:
	var key: String = str(a["rank"]) + str(a["suit"])
	var bonus := 0
	if key == "K♣" and t["hp"] == t["max_hp"]: bonus += 1
	if key == "J♠" and t["hp"] < t["max_hp"]: bonus += 1
	if key == "J♣" and a["hp"] <= 4: bonus += 2
	return bonus

func _estimate(attacker: int, target: int, bonus: int = 0, pierce: int = 0) -> int:
	var a := heroes[attacker]
	var t := heroes[target]
	var dmg: int = maxi(1, int(a["atk"]) + bonus + int(a["ace_bonus"]) - maxi(0, int(t["def"]) - pierce))
	return dmg + _passive_bonus(a, t)

func _damage(attacker: int, target: int, bonus: int = 0, pierce: int = 0) -> void:
	var a := heroes[attacker]
	var t := heroes[target]
	var dmg: int = _estimate(attacker, target, bonus, pierce)
	a["ace_bonus"] = 0
	var guarded := false
	for gi in _alive(int(t["side"])):
		var guard := heroes[gi]
		if guard["rank"] == "K" and guard["suit"] == "♥" and not guard["guard_used"]:
			guard["guard_used"] = true
			dmg = maxi(0, dmg - 1)
			guarded = true
			break
	var absorbed: int = mini(dmg, int(t["shield"]))
	t["shield"] -= absorbed
	dmg -= absorbed
	var dealt: int = mini(dmg, int(t["hp"]))
	t["hp"] -= dealt
	var points := 0
	if dealt >= 3 and not damage_scored:
		points += 1
		damage_scored = true
	var died: bool = int(t["hp"]) <= 0
	if died:
		points += 3 if t["rank"] == "K" else 2
	glory[int(a["side"])] += points
	if dealt > 0: _fx(target, "hit", "-%d" % dealt)
	if absorbed > 0: _fx(target, "shield", "-%d escudo" % absorbed)
	if dealt == 0 and absorbed == 0: _fx(target, "hit", "0")
	if dealt >= 4 or died: _fx(target, "quake", "")
	_log("%s ataca %s: %d de vida, %d de escudo, +%d PG.%s" % [a["name"],t["name"],dealt,absorbed,points," Guarda reduziu 1." if guarded else ""])
	_check_victory()

func _check_victory() -> void:
	if glory[0] >= GOAL or glory[1] >= GOAL or _alive(0).is_empty() or _alive(1).is_empty():
		if not finished:
			finished = true
			var won: bool = glory[0] >= GOAL or _alive(1).is_empty()
			_log("VITÓRIA!" if won else "DERROTA!")
			_banner("VITÓRIA!" if won else "DERROTA")
			if won: _confetti()
	_refresh()

func _effect_of(card: Dictionary, actor: int, target: int, joker_suit: String = "") -> Dictionary:
	var enemy: bool = heroes[target]["side"] != heroes[actor]["side"]
	var suit := ""
	var power := 0
	var ok := true
	if card.has("joker"):
		if card["joker"] == "red":
			suit = "♠" if enemy else "♥"
			power = 3
		else:
			suit = joker_suit
			power = 2 + (1 if suit == heroes[actor]["suit"] else 0)
			if suit == "": ok = false
	else:
		suit = card["suit"]
		power = _power(int(card["value"])) + (1 if suit == heroes[actor]["suit"] else 0)
	return {"ok":ok,"suit":suit,"power":power}

func _play_card(side: int, index: int, actor: int, target: int, joker_suit: String = "") -> bool:
	if finished or used_card or index < 0 or index >= hands[side].size(): return false
	if actor not in _alive(side) or target < 0 or target >= heroes.size() or heroes[target]["hp"] <= 0: return false
	var card: Dictionary = hands[side][index]
	var cost: int = _cost(card)
	if energy[side] < cost: return false
	var eff := _effect_of(card, actor, target, joker_suit)
	if not eff["ok"]: return false
	var suit: String = eff["suit"]
	var power: int = eff["power"]
	var attack_card: bool = suit in ["♠","♣"]
	if attack_card and (used_attack or heroes[target]["side"] == side): return false
	if not attack_card and heroes[target]["side"] != side: return false
	energy[side] -= cost
	var who: String = heroes[actor]["name"]
	var card_name := _card_name(card, joker_suit)
	match suit:
		"♥":
			var gained := _heal(target, 1 + power)
			_log("%s usa %s e cura %s em %d de vida." % [who,card_name,heroes[target]["name"],gained])
		"♦":
			_add_energy(side, power, actor)
			var extra := 1 if (heroes[actor]["rank"] == "Q" and heroes[actor]["suit"] == "♦") else 0
			_add_shield(target, 1 + power + extra)
			_log("%s usa %s: +%d energia e escudos para %s." % [who,card_name,power,heroes[target]["name"]])
		"♠","♣":
			if suit == "♣": _add_shield(actor, 1)
			_log("%s usa %s." % [who,card_name])
			used_attack = true
			_damage(actor, target, power, 1 if suit == "♠" else 0)
	hands[side].remove_at(index)
	discard.append(card)
	used_card = true
	selected_index = -1
	last_tap = -1
	_check_victory()
	return true

func _basic_attack(actor: int, target: int) -> bool:
	if finished or used_attack or actor not in _alive(current_side) or target not in _alive(1 - current_side): return false
	used_attack = true
	_damage(actor, target)
	return true

func _defend(actor: int) -> bool:
	if finished or used_attack or actor not in _alive(current_side): return false
	used_attack = true
	_add_shield(actor, 2)
	_log("%s se defende: +2 escudos (usa a ação de ataque do turno)." % heroes[actor]["name"])
	_refresh()
	return true

func _worst_card_index(side: int) -> int:
	var worst := 0
	var worst_score := 9999
	for i in hands[side].size():
		var c: Dictionary = hands[side][i]
		var score: int = 100 if c.has("joker") else _cost(c) * 10 + int(c["value"])
		if score < worst_score:
			worst_score = score
			worst = i
	return worst

func _activate_ace(actor: int, target: int) -> bool:
	if finished or used_ace or actor not in _alive(current_side) or energy[current_side] < 2: return false
	var side := current_side
	var suit: String = heroes[actor]["suit"]
	if suit == "♥" and target not in _alive(side): target = actor
	energy[side] -= 2
	used_ace = true
	match suit:
		"♥":
			_heal(target, 3)
			_add_shield(target, 1)
			_log("Ás de Copas: %s recupera vida e ganha escudo." % heroes[target]["name"])
		"♦":
			_add_energy(side, 3, actor)
			_log("Ás de Ouros: +3 energia.")
		"♠":
			_draw_card(side)
			_draw_card(side)
			var dropped: Dictionary = hands[side].pop_at(_worst_card_index(side))
			discard.append(dropped)
			_fx(actor, "energy", "+2 cartas")
			_log("Ás de Espadas: compra 2 cartas e descarta %s." % _card_name(dropped))
		"♣":
			heroes[actor]["ace_bonus"] = 2
			_fx(actor, "energy", "+2 ATQ")
			_log("Ás de Paus: %s ganha +2 de ataque no próximo golpe." % heroes[actor]["name"])
	_refresh()
	return true

func _resolve_deck_out() -> void:
	var total := [0, 0]
	for h in heroes:
		if h["hp"] > 0: total[int(h["side"])] += int(h["hp"])
	var scores := [[glory[0], total[0], energy[0]], [glory[1], total[1], energy[1]]]
	finished = true
	if scores[0] == scores[1]:
		_log("Baralho esgotado: empate.")
		_banner("EMPATE")
	elif scores[0] > scores[1]:
		_log("Baralho esgotado: você vence por Glória, Vida e Energia.")
		_banner("VITÓRIA!")
	else:
		_log("Baralho esgotado: o rival vence por Glória, Vida e Energia.")
		_banner("DERROTA")
	_refresh()

func _end_turn() -> void:
	if finished or busy or current_side != 0: return
	await _finish_turn()

func _finish_turn() -> void:
	while hands[current_side].size() > HAND_LIMIT:
		var dropped: Dictionary = hands[current_side].pop_at(_worst_card_index(current_side))
		discard.append(dropped)
		_log("Limite de mão: %s descartada." % _card_name(dropped))
	for h in heroes:
		if h["side"] == current_side: h["ace_bonus"] = 0
	if current_side == 1:
		if round_number == 5:
			for side in 2:
				if _alive(side).size() == 3:
					glory[side] += 2
					_log("%s recebe +2 PG por manter os 3 heróis vivos." % ("Você" if side == 0 else "O rival"))
			_check_victory()
		if not finished and deck_out:
			_resolve_deck_out()
	if finished:
		_refresh()
		return
	if current_side == 1: round_number += 1
	current_side = 1 - current_side
	_begin_turn()
	if current_side == 1:
		await _enemy_turn()

# ─────────────────────────── IA RIVAL ───────────────────────────

func _ai_actor_for(suit: String) -> int:
	var best := -1
	for i in _alive(1):
		if heroes[i]["suit"] == suit: return i
		if best < 0 or int(heroes[i]["atk"]) > int(heroes[best]["atk"]): best = i
	return best

func _most_wounded(side: int) -> int:
	var best := -1
	var missing := 0
	for i in _alive(side):
		var m: int = int(heroes[i]["max_hp"]) - int(heroes[i]["hp"])
		if m > missing:
			missing = m
			best = i
	return best

func _ai_ace() -> Dictionary:
	if used_ace or energy[1] < 2: return {}
	for i in _alive(1):
		match heroes[i]["suit"]:
			"♦":
				if energy[1] <= 4: return {"actor":i,"target":i}
			"♥":
				var w := _most_wounded(1)
				if w >= 0 and int(heroes[w]["max_hp"]) - int(heroes[w]["hp"]) >= 4: return {"actor":i,"target":w}
			"♣":
				if not used_attack and energy[1] >= 3: return {"actor":i,"target":i}
			"♠":
				if hands[1].size() <= 2 and energy[1] >= 3: return {"actor":i,"target":i}
	return {}

func _ai_plan() -> Dictionary:
	var best := {}
	var best_score := 0.0
	for idx in hands[1].size():
		var card: Dictionary = hands[1][idx]
		if card.has("joker") and card["joker"] == "blue": continue
		var cost: int = _cost(card)
		if energy[1] < cost: continue
		var suit: String = "♠" if card.has("joker") else card["suit"]
		if suit in ["♠","♣"]:
			if used_attack: continue
			var actor := _ai_actor_for(suit)
			var bonus: int = 3 if card.has("joker") else _power(int(card["value"])) + (1 if heroes[actor]["suit"] == suit else 0)
			for t in _alive(0):
				var dmg := _estimate(actor, t, bonus, 1 if suit == "♠" else 0)
				var eff_hp: int = int(heroes[t]["hp"]) + int(heroes[t]["shield"])
				var score := float(mini(dmg, eff_hp)) * 2.0 + (8.0 if dmg >= eff_hp else 0.0) - float(cost) * 0.3
				if score > best_score:
					best_score = score
					best = {"index":idx,"actor":actor,"target":t}
		elif suit == "♥":
			var w := _most_wounded(1)
			if w < 0: continue
			var missing: int = int(heroes[w]["max_hp"]) - int(heroes[w]["hp"])
			if missing < 3: continue
			var heal_actor := _ai_actor_for("♥")
			var heal_score := float(mini(missing, 1 + _power(int(card["value"])))) * 1.6
			if heal_score > best_score:
				best_score = heal_score
				best = {"index":idx,"actor":heal_actor,"target":w}
		elif suit == "♦":
			var gold_actor := _ai_actor_for("♦")
			var gold_score := 2.2
			if gold_score > best_score and energy[1] >= cost + 1:
				best_score = gold_score
				best = {"index":idx,"actor":gold_actor,"target":gold_actor}
	return best

func _enemy_turn() -> void:
	var token := match_id
	busy = true
	_refresh()
	await _wait(1.0)
	if token != match_id: return
	var ace := _ai_ace()
	if not ace.is_empty() and not finished:
		_activate_ace(int(ace["actor"]), int(ace["target"]))
		await _wait(0.9)
		if token != match_id: return
	var plan := _ai_plan()
	if not plan.is_empty() and not finished:
		var card: Dictionary = hands[1][int(plan["index"])]
		await _fly_card_to(card, Vector2(size.x * 0.5 - 52.0, 40.0), int(plan["target"]))
		if token != match_id: return
		var attacking: bool = card.has("joker") or card["suit"] in ["♠","♣"]
		if attacking:
			await _lunge(int(plan["actor"]), int(plan["target"]))
			if token != match_id: return
		_play_card(1, int(plan["index"]), int(plan["actor"]), int(plan["target"]))
		await _wait(0.9)
		if token != match_id: return
	if not used_attack and not finished:
		var target := -1
		for t in _alive(0):
			if target < 0 or int(heroes[t]["hp"]) + int(heroes[t]["shield"]) < int(heroes[target]["hp"]) + int(heroes[target]["shield"]): target = t
		var attacker := -1
		for a in _alive(1):
			if attacker < 0 or _estimate(a, target) > _estimate(attacker, target): attacker = a
		if target >= 0 and attacker >= 0:
			if _estimate(attacker, target) <= 1:
				_defend(attacker)
			else:
				await _lunge(attacker, target)
				if token != match_id: return
				_basic_attack(attacker, target)
		await _wait(0.9)
		if token != match_id: return
	busy = false
	if not finished:
		await _finish_turn()
	else:
		_refresh()

# ─────────────────────────── TEXTOS ───────────────────────────

func _log(message: String) -> void:
	history.append(message)
	if history.size() > 80: history.pop_front()

func _card_name(card: Dictionary, joker_suit: String = "") -> String:
	if card.has("joker"):
		var n := "Coringa Vermelho" if card["joker"] == "red" else "Coringa Azul"
		return n + (" (%s)" % _suit_label(joker_suit) if joker_suit != "" else "")
	return "%d de %s" % [card["value"], _suit_label(card["suit"])]

func _ability(card: Dictionary) -> String:
	return str(_chip_info(card)[0])

func _chip_info(c: Dictionary) -> Array:
	if c.has("joker"):
		return ["ADAPTÁVEL" if c["joker"] == "red" else "TRANSFORMA", Color("#7a4fa3")]
	var p: int = _power(int(c["value"]))
	for i in _alive(0):
		if heroes[i]["suit"] == c["suit"]:
			p += 1
			break
	match c["suit"]:
		"♥": return ["CURA %d" % (1 + p), Color("#2f8f5b")]
		"♦": return ["+%d ENERGIA  ESC %d" % [p, 1 + p], Color("#2b6cb0")]
		"♠": return ["ATQ +%d  PERFURA" % p, Color("#a8323a")]
	return ["ATQ +%d  +1 ESC" % p, Color("#a8323a")]

func _short_ace(suit: String) -> String:
	match suit:
		"♥": return "Ás: cura 3"
		"♦": return "Ás: +3 energia"
		"♠": return "Ás: compra 2"
	return "Ás: +2 ATQ"

func _short_passive(h: Dictionary) -> String:
	match str(h["rank"]) + str(h["suit"]):
		"K♥": return "Guarda"
		"K♣": return "Golpe de Rei"
		"J♠": return "Oportunista"
		"J♣": return "Fúria"
		"Q♦": return "Tesoureira"
	return ""

func _art_key(c: Dictionary) -> String:
	if c.has("joker"): return "joker-red" if c["joker"] == "red" else "joker-blue"
	return str(c["suit"]) + str(c["value"])

func _card_description(card: Dictionary, actor: int) -> String:
	if card.has("joker"):
		if card["joker"] == "red":
			return "Coringa Vermelho (custo 3) — Adaptabilidade: em um inimigo age como 8 de Espadas (ataque +3, ignora 1 DEF); em um aliado, como 8 de Copas (cura 4)."
		return "Coringa Azul (custo 3) — Transformação: você escolhe o naipe e ele age como carta de potência 2 (+1 se for o naipe do herói)."
	var suit: String = card["suit"]
	var power: int = _power(int(card["value"]))
	var affinity: bool = actor >= 0 and heroes[actor]["suit"] == suit
	if affinity: power += 1
	var head := "%s (custo %d, potência %d%s) — " % [_card_name(card), _cost(card), power, ", afinidade +1" if affinity else ""]
	match suit:
		"♥": return head + "cura um aliado em %d de vida." % (1 + power)
		"♦": return head + "ganha %d energia e dá %d escudos a um aliado." % [power, 1 + power]
		"♠": return head + "ataque com +%d de dano que ignora 1 de DEF do inimigo." % power
	return head + "ataque com +%d de dano e dá 1 escudo ao atacante." % power

func _hero_description(i: int) -> String:
	var h := heroes[i]
	var text := "%s — Vida %d/%d, ATQ %d, DEF %d, Escudo %d." % [h["name"],h["hp"],h["max_hp"],h["atk"],h["def"],h["shield"]]
	var key: String = str(h["rank"]) + str(h["suit"])
	if PASSIVE_TEXT.has(key): text += " Passiva: " + PASSIVE_TEXT[key]
	return text + " " + ACE_TEXT[h["suit"]]

func _selected_card() -> Dictionary:
	if selected_index >= 0 and selected_index < hands[0].size():
		return hands[0][selected_index]
	return {}

func _info_text() -> String:
	if finished: return "Partida encerrada. Toque em Nova partida."
	if current_side != 0: return "TURNO DO RIVAL — acompanhe as jogadas."
	var card := _selected_card()
	var lines: Array[String] = []
	var enemy_ok: bool = selected_target in _alive(1)
	if not card.is_empty():
		lines.append(_card_description(card, selected_actor))
		if card.has("joker"):
			lines.append("Toque num inimigo (ataque) ou num aliado (cura). Toque na carta de novo para ampliar.")
		elif card["suit"] in ["♠", "♣"]:
			var tip := "Toque num inimigo com borda VERMELHA, ou arraste a carta até ele."
			if enemy_ok:
				var bonus: int = _power(int(card["value"])) + (1 if heroes[selected_actor]["suit"] == card["suit"] else 0)
				tip += " Dano em %s: %d." % [heroes[selected_target]["name"], _estimate(selected_actor, selected_target, bonus, 1 if card["suit"] == "♠" else 0)]
			lines.append(tip)
		else:
			lines.append("Toque num aliado com borda VERDE, ou arraste a carta até ele.")
		return "\n".join(lines)
	if used_attack and used_card: lines.append("Sem ações principais. Toque em Encerrar turno.")
	elif used_attack: lines.append("Você já atacou. Jogue uma carta de apoio ou encerre o turno.")
	else: lines.append("Escolha uma carta da mão, ou arraste um herói seu sobre um inimigo para atacar.")
	if selected_actor in _alive(0):
		var a := heroes[selected_actor]
		var pas := _short_passive(a)
		lines.append("%s: ATQ %d, DEF %d. %s%s" % [a["name"], a["atk"], a["def"], _short_ace(a["suit"]), (". Passiva " + pas + ": " + PASSIVE_TEXT[str(a["rank"]) + str(a["suit"])]) if pas != "" else ""])
	if enemy_ok and not used_attack and selected_actor in _alive(0):
		lines.append("Alvo %s: dano estimado %d." % [heroes[selected_target]["name"], _estimate(selected_actor, selected_target)])
	return "\n".join(lines)

# ─────────────────────────── INTERFACE ───────────────────────────

func _make_label(text: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	return s

func _side_status() -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	var label := _make_label("", 13)
	label.add_theme_color_override("font_color", CREAM)
	box.add_child(label)
	var crystals := HBoxContainer.new()
	crystals.alignment = BoxContainer.ALIGNMENT_CENTER
	crystals.add_theme_constant_override("separation", 3)
	box.add_child(crystals)
	var bar := ProgressBar.new()
	bar.max_value = GOAL
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	bar.add_theme_stylebox_override("fill", _style(GOLD, GOLD, 0, 4))
	bar.add_theme_stylebox_override("background", _style(Color("#2a3b44"), Color("#2a3b44"), 0, 4))
	box.add_child(bar)
	return {"root":box,"label":label,"crystals":crystals,"bar":bar}

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#07121c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page)
	ui["page"] = page
	var safe := MarginContainer.new()
	safe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_theme_constant_override("margin_left", 8)
	safe.add_theme_constant_override("margin_right", 8)
	safe.add_theme_constant_override("margin_top", 5)
	safe.add_theme_constant_override("margin_bottom", 5)
	page.add_child(safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	safe.add_child(layout)
	var heading := _make_label("CARTAS\nREINOS DO DESTINO", 19)
	heading.add_theme_color_override("font_color", Color("#f4ce80"))
	heading.add_theme_color_override("font_outline_color", Color("#3d1d0b"))
	heading.add_theme_constant_override("outline_size", 4)
	layout.add_child(heading)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	layout.add_child(top)
	ui["me"] = _side_status()
	ui["foe"] = _side_status()
	ui["round"] = _make_label("", 13)
	ui["round"].custom_minimum_size = Vector2(70, 0)
	ui["round"].add_theme_color_override("font_color", GOLD)
	top.add_child(ui["me"]["root"])
	top.add_child(ui["round"])
	top.add_child(ui["foe"]["root"])
	var field := PanelContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 365)
	field.add_theme_stylebox_override("panel", _style(Color("#0a1721"), Color("#c9a062"), 5, 16))
	field.clip_contents = true
	layout.add_child(field)
	var felt := Gradient.new()
	felt.colors = PackedColorArray([Color("#294052"), Color("#07111c")])
	felt.offsets = PackedFloat32Array([0.0, 1.0])
	var felt_tex := GradientTexture2D.new()
	felt_tex.gradient = felt
	felt_tex.fill = GradientTexture2D.FILL_RADIAL
	felt_tex.fill_from = Vector2(0.5, 0.5)
	felt_tex.fill_to = Vector2(1.0, 0.5)
	var felt_rect := TextureRect.new()
	felt_rect.texture = felt_tex
	felt_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	felt_rect.stretch_mode = TextureRect.STRETCH_SCALE
	felt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(felt_rect)
	felt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	field.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)
	var enemy_label := _make_label("☠  REINO ADVERSÁRIO  ☠", 13)
	enemy_label.add_theme_color_override("font_color", GOLD)
	rows.add_child(enemy_label)
	ui["enemy"] = HBoxContainer.new()
	ui["enemy"].alignment = BoxContainer.ALIGNMENT_CENTER
	ui["enemy"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui["enemy"].add_theme_constant_override("separation", 6)
	rows.add_child(ui["enemy"])
	rows.add_child(HSeparator.new())
	ui["counts"] = _make_label("", 12)
	ui["counts"].add_theme_color_override("font_color", CREAM)
	rows.add_child(ui["counts"])
	rows.add_child(HSeparator.new())
	var player_label := _make_label("♛  SEUS HERÓIS  ♛", 13)
	player_label.add_theme_color_override("font_color", GOLD)
	rows.add_child(player_label)
	ui["player"] = HBoxContainer.new()
	ui["player"].alignment = BoxContainer.ALIGNMENT_CENTER
	ui["player"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui["player"].add_theme_constant_override("separation", 6)
	rows.add_child(ui["player"])
	var info_title := _make_label("⚔  HERÓI ATIVO  ⚔", 13)
	info_title.add_theme_color_override("font_color", GOLD)
	layout.add_child(info_title)
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _style(Color("#0a1724"), Color("#b98a49"), 3, 10))
	layout.add_child(info_panel)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(62, 78)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info_row.add_child(portrait)
	ui["portrait"] = portrait
	ui["info"] = _make_label("", 11)
	ui["info"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui["info"].custom_minimum_size = Vector2(0, 58)
	ui["info"].add_theme_color_override("font_color", CREAM)
	ui["info"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(ui["info"])
	var hand_title := _make_label("✦  SUA MÃO  ✦", 14)
	hand_title.add_theme_color_override("font_color", GOLD)
	layout.add_child(hand_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 137)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	ui["hand"] = HBoxContainer.new()
	ui["hand"].custom_minimum_size = Vector2(0, 135)
	ui["hand"].add_theme_constant_override("separation", 4)
	scroll.add_child(ui["hand"])
	ui["actions"] = HBoxContainer.new()
	ui["actions"].add_theme_constant_override("separation", 4)
	layout.add_child(ui["actions"])
	for label in ["Jogar", "Atacar", "Defender", "Ás", "Encerrar"]:
		var button := Button.new()
		button.text = BUTTON_TEXT[label]
		button.set_meta("id", label)
		if label == "Encerrar": ui["end_button"] = button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 50)
		button.add_theme_font_size_override("font_size", 13)
		var action_color := Color("#6d131a") if label == "Atacar" else Color("#123d74") if label == "Defender" else Color("#1a6149") if label == "Ás" else Color("#604019") if label == "Jogar" else Color("#872322")
		button.add_theme_stylebox_override("normal", _style(action_color, Color("#dcb46c"), 3, 9))
		button.add_theme_stylebox_override("hover", _style(action_color.lightened(0.2), Color("#ffe1a3"), 3, 9))
		button.add_theme_stylebox_override("pressed", _style(action_color.darkened(0.2), Color("#ffe1a3"), 3, 9))
		button.add_theme_color_override("font_color", CREAM)
		ui["actions"].add_child(button)
		match label:
			"Jogar": button.pressed.connect(_on_play)
			"Atacar": button.pressed.connect(_on_attack)
			"Defender": button.pressed.connect(_on_defend)
			"Ás": button.pressed.connect(_on_ace)
			"Encerrar": button.pressed.connect(_end_turn)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	layout.add_child(bottom)
	var new_button := Button.new()
	new_button.text = "Nova partida"
	new_button.custom_minimum_size = Vector2(0, 30)
	new_button.add_theme_font_size_override("font_size", 12)
	new_button.pressed.connect(new_game)
	bottom.add_child(new_button)
	var gallery_button := Button.new()
	gallery_button.text = "VER 48 CARTAS OFICIAIS"
	gallery_button.custom_minimum_size = Vector2(0, 30)
	gallery_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_button.add_theme_font_size_override("font_size", 12)
	gallery_button.pressed.connect(_show_gallery)
	bottom.add_child(gallery_button)
	ui["message"] = _make_label("", 12)
	ui["message"].add_theme_color_override("font_color", GOLD)
	layout.add_child(ui["message"])
	var fx_layer := Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fx_layer)
	ui["fx"] = fx_layer

func _make_card(text: String, is_red: bool, pressed: Callable, border: Color = GOLD, border_width: int = 3) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 150)
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	var style := _style(CREAM, border, border_width, 9)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 3
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", RED if is_red else INK)
	button.pressed.connect(pressed)
	return button

func _attach_art(card: Button, texture: Texture2D) -> void:
	card.text = ""
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 2
	art.offset_top = 2
	art.offset_right = -2
	art.offset_bottom = -2

func _badge(card: Control, lines: Array, bar_value: float = -1.0, height: float = 40.0) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -height
	panel.offset_left = 4
	panel.offset_right = -4
	panel.offset_bottom = -4
	panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.08, 0.1, 0.94), Color(0, 0, 0, 0), 0, 4))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	if bar_value >= 0.0:
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = bar_value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 7)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill_color := Color("#60ad87") if bar_value > 0.4 else Color("#d4a043") if bar_value > 0.2 else Color("#d9534f")
		bar.add_theme_stylebox_override("fill", _style(fill_color, fill_color, 0, 3))
		bar.add_theme_stylebox_override("background", _style(Color("#563b3b"), Color("#563b3b"), 0, 3))
		box.add_child(bar)
	for line in lines:
		var label := _make_label(str(line), 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", CREAM)
		box.add_child(label)

func _gem(card: Control, value: int) -> void:
	var gem := PanelContainer.new()
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.custom_minimum_size = Vector2(28, 28)
	gem.position = Vector2(3, 3)
	gem.add_theme_stylebox_override("panel", _style(Color("#2b6cb0"), GOLD, 2, 14))
	var label := _make_label(str(value), 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	gem.add_child(label)
	card.add_child(gem)

func _set_crystals(box: HBoxContainer, value: int) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for i in MAX_ENERGY:
		var crystal := Panel.new()
		crystal.custom_minimum_size = Vector2(14, 14)
		var on: bool = i < value
		crystal.add_theme_stylebox_override("panel", _style(Color("#5fb3ff") if on else Color("#20384a"), Color("#d8ecff") if on else Color("#3b5a70"), 1, 7))
		box.add_child(crystal)

func _target_valid(i: int) -> bool:
	if finished or current_side != 0 or busy or heroes[i]["hp"] <= 0: return false
	if selected_index >= 0: return _can_play_on(selected_index, i)
	return heroes[i]["side"] == 1 and not used_attack and selected_actor in _alive(0)

func _make_hero_card(i: int) -> Button:
	var h: Dictionary = heroes[i]
	var mine: bool = h["side"] == 0
	var border := GOLD
	var width := 3
	var valid := _target_valid(i)
	if valid:
		border = FOE_RED if not mine else OK_GREEN
		width = 4
	if mine and i == selected_actor and not finished:
		border = OK_GREEN
		width = 6
	if i == selected_target and (not mine or selected_index >= 0) and h["hp"] > 0:
		border = Color("#ffe27a")
		width = 6
	var fallback := "%s\n%s\nVIDA %d/%d\nATQ %d  DEF %d\nESCUDO %d" % [_suit_name(h["suit"]),h["name"],h["hp"],h["max_hp"],h["atk"],h["def"],h["shield"]]
	var card := _make_card(fallback, h["suit"] in ["♥","♦"], func(): _select_hero(i), border, width)
	card.custom_minimum_size = Vector2(0, 155)
	var key: String = str(h["suit"]) + str(h["rank"])
	if card_art.has(key):
		_attach_art(card, card_art[key])
		var power_line: String = _short_ace(h["suit"])
		var passive := _short_passive(h)
		if passive != "": power_line += "  /  " + passive
		_badge(card, ["VIDA %d/%d  ATQ %d" % [h["hp"],h["max_hp"],h["atk"]], "DEF %d  ESC %d" % [h["def"],h["shield"]]], float(h["hp"]) / float(h["max_hp"]), 42.0)
	card.set_drag_forwarding(_drag_hero.bind(i), _can_drop_on_hero.bind(i), _drop_on_hero.bind(i))
	if h["hp"] <= 0:
		card.modulate = Color(0.5, 0.38, 0.38)
		var dead := _make_label("DERROTADO", 20)
		dead.add_theme_color_override("font_color", Color("#ff6b5e"))
		dead.add_theme_color_override("font_outline_color", Color.BLACK)
		dead.add_theme_constant_override("outline_size", 8)
		dead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dead.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dead.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(dead)
	elif valid:
		var tween := card.create_tween().set_loops()
		tween.tween_property(card, "modulate", Color(1.3, 1.3, 1.3), 0.5)
		tween.tween_property(card, "modulate", Color.WHITE, 0.5)
	return card

func _rebuild_heroes() -> void:
	hero_views.clear()
	for side in 2:
		var container: HBoxContainer = ui["player"] if side == 0 else ui["enemy"]
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
		for i in heroes.size():
			if heroes[i]["side"] != side: continue
			var card := _make_hero_card(i)
			container.add_child(card)
			hero_views[i] = card

func _rebuild_hand() -> void:
	for child in ui["hand"].get_children():
		ui["hand"].remove_child(child)
		child.queue_free()
	hand_views.clear()
	var cw: float = clampf((size.x - 30.0) / 4.0 - 4.0, 92.0, 128.0)
	var ch: float = 133.0
	for i in hands[0].size():
		var c: Dictionary = hands[0][i]
		var selected: bool = i == selected_index
		var title: String = "CORINGA" if c.has("joker") else "%d\n%s" % [c["value"],_suit_name(c["suit"])]
		var chip: Array = _chip_info(c)
		var card := _make_card("%s\n%s" % [title,chip[0]], c.get("suit","") in ["♥","♦"], func(): _select_card(i), OK_GREEN if selected else GOLD, 5 if selected else 3)
		card.custom_minimum_size = Vector2(cw, ch)
		card.size_flags_vertical = Control.SIZE_SHRINK_END
		card.set_drag_forwarding(_drag_card.bind(i), Callable(), Callable())
		var art_key: String = _art_key(c)
		if card_art.has(art_key):
			_attach_art(card, card_art[art_key])
			_chip(card, str(chip[0]), chip[1])
		_gem(card, _cost(c))
		if selected:
			card.pivot_offset = Vector2(cw / 2.0, ch)
			card.scale = Vector2(1.1, 1.1)
		elif energy[0] < _cost(c):
			card.modulate = Color(0.55, 0.55, 0.65)
		ui["hand"].add_child(card)
		hand_views.append(card)
		if not seen_cards.has(c["id"]):
			seen_cards[c["id"]] = true
			if not fast and not selected:
				card.pivot_offset = Vector2(cw / 2.0, ch)
				card.modulate.a = 0.0
				card.scale = Vector2(0.5, 0.5)
				var deal := card.create_tween().set_parallel(true)
				deal.tween_property(card, "modulate:a", 1.0, 0.3)
				deal.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)

func _refresh() -> void:
	if ui.is_empty() or heroes.is_empty(): return
	ui["round"].text = "RODADA\n%d" % round_number
	for side in 2:
		var s: Dictionary = ui["me"] if side == 0 else ui["foe"]
		s["label"].text = "%s  PG %d/%d  ENERGIA %d" % ["VOCE" if side == 0 else "RIVAL",glory[side],GOAL,energy[side]]
		s["bar"].value = glory[side]
		_set_crystals(s["crystals"], energy[side])
	ui["counts"].text = "Baralho: %d   •   Descarte: %d   •   Mão rival: %d" % [deck.size(),discard.size(),hands[1].size()]
	_rebuild_heroes()
	_rebuild_hand()
	var can_act := not finished and current_side == 0 and not busy
	for button in ui["actions"].get_children():
		button.disabled = not can_act
		if button.get_meta("id") == "Jogar": button.disabled = button.disabled or used_card or selected_index < 0
		if button.get_meta("id") == "Atacar": button.disabled = button.disabled or used_attack
		if button.get_meta("id") == "Defender": button.disabled = button.disabled or used_attack
		if button.get_meta("id") == "Ás": button.disabled = button.disabled or used_ace or energy[0] < 2
	var done: bool = can_act and used_attack and (used_card or hands[0].is_empty() or energy[0] < 1)
	if end_tween: end_tween.kill()
	var end_button: Button = ui["end_button"]
	end_button.modulate = Color.WHITE
	if done and not fast:
		end_tween = end_button.create_tween().set_loops()
		end_tween.tween_property(end_button, "modulate", Color(1.4, 1.3, 0.9), 0.5)
		end_tween.tween_property(end_button, "modulate", Color.WHITE, 0.5)
	ui["info"].text = _info_text()
	if selected_actor >= 0 and selected_actor < heroes.size():
		var active: Dictionary = heroes[selected_actor]
		var active_key: String = str(active["suit"]) + str(active["rank"])
		ui["portrait"].texture = card_art.get(active_key, null)
	ui["message"].text = history.back() if not history.is_empty() else ""
	_flush_fx()

# ─────────────────────────── EFEITOS ───────────────────────────

func _fx_color(kind: String) -> Color:
	match kind:
		"hit": return Color("#ff5a4d")
		"heal": return Color("#6fe3a6")
		"shield": return Color("#7cc4ff")
	return Color("#ffd35c")

func _flush_fx() -> void:
	if fx_queue.is_empty(): return
	var batch: Array = fx_queue.duplicate()
	fx_queue.clear()
	await get_tree().process_frame
	var stack := {}
	for e in batch:
		var idx: int = e["hero"]
		if not hero_views.has(idx) or not is_instance_valid(hero_views[idx]): continue
		var view: Control = hero_views[idx]
		var kind: String = e["kind"]
		if kind == "quake":
			_screen_shake(9.0)
			continue
		var color := _fx_color(kind)
		var level: int = stack.get(idx, 0)
		stack[idx] = level + 1
		_spawn_float(view, str(e["text"]), color, level)
		_flash(view, color, kind == "hit")
		_burst(view, kind)
		if kind == "hit": _slash(view)
		else: _ring(view, color)

func _spawn_float(view: Control, text: String, color: Color, level: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui["fx"].add_child(label)
	label.position = view.global_position - global_position + Vector2(view.size.x * 0.2, view.size.y * 0.35 - level * 28.0)
	label.pivot_offset = Vector2(40, 16)
	label.scale = Vector2(0.4, 0.4)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "position:y", label.position.y - 70.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tween.finished.connect(label.queue_free)

func _flash(view: Control, color: Color, shake: bool) -> void:
	var base: Color = view.modulate
	view.modulate = color.lightened(0.3)
	var tween := view.create_tween()
	tween.tween_property(view, "modulate", base, 0.45)
	if shake:
		view.pivot_offset = view.size * 0.5
		var st := view.create_tween()
		for angle in [4.0, -4.0, 3.0, -2.0, 0.0]:
			st.tween_property(view, "rotation_degrees", angle, 0.05)

func _banner(text: String) -> void:
	if ui.is_empty() or fast or not is_inside_tree(): return
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.72)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(size.x, 88)
	band.position = Vector2(0, size.y * 0.4)
	band.pivot_offset = Vector2(size.x * 0.5, 44)
	band.scale = Vector2(1, 0)
	var label := _make_label(text, 46)
	label.add_theme_color_override("font_color", Color("#ffd98a"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band.add_child(label)
	ui["fx"].add_child(band)
	var tween := create_tween()
	tween.tween_property(band, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.8)
	tween.tween_property(band, "scale", Vector2(1, 0), 0.2)
	tween.finished.connect(band.queue_free)

func _lunge(attacker: int, target: int) -> void:
	if fast or not hero_views.has(attacker) or not hero_views.has(target): return
	var av: Control = hero_views[attacker]
	var tv: Control = hero_views[target]
	if not is_instance_valid(av) or not is_instance_valid(tv): return
	var delta: Vector2 = (tv.global_position + tv.size * 0.5) - (av.global_position + av.size * 0.5)
	var base: Vector2 = av.position
	av.z_index = 20
	var tween := create_tween()
	tween.tween_property(av, "position", base + delta * 0.6, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(av, "position", base, 0.2).set_ease(Tween.EASE_OUT)
	await tween.finished

func _ghost_for(card: Dictionary) -> Panel:
	var ghost := Panel.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = Vector2(104, 150)
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
		ghost.add_child(_make_label(_card_name(card), 16))
	return ghost

func _fly_card_to(card: Dictionary, from_position: Vector2, target: int) -> void:
	if fast or not hero_views.has(target) or not is_instance_valid(hero_views[target]): return
	var ghost := _ghost_for(card)
	add_child(ghost)
	ghost.position = from_position
	var tween := create_tween()
	tween.tween_property(ghost, "position", hero_views[target].global_position - global_position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	ghost.queue_free()

func _fly_card(index: int, target: int) -> void:
	if index < 0 or index >= hand_views.size(): return
	await _fly_card_to(hands[0][index], hand_views[index].global_position - global_position, target)

# ─────────────────────────── ENTRADA DO JOGADOR ───────────────────────────

func _select_card(index: int, allow_zoom: bool = true) -> void:
	if busy or finished or current_side != 0: return
	if allow_zoom and index == selected_index and index < hands[0].size():
		_zoom(_art_key(hands[0][index]), _card_description(hands[0][index], selected_actor))
		return
	selected_index = index
	last_tap = -1
	var card: Dictionary = hands[0][index]
	var suit: String = "" if card.has("joker") else card["suit"]
	var mine := _alive(0)
	if suit != "":
		for i in mine:
			if heroes[i]["suit"] == suit:
				selected_actor = i
				break
	if suit in ["♥", "♦"]:
		var wounded := -1
		var worst := 1.0
		for i in mine:
			var ratio: float = float(heroes[i]["hp"]) / float(heroes[i]["max_hp"])
			if ratio < worst:
				worst = ratio
				wounded = i
		selected_target = wounded if (suit == "♥" and wounded >= 0) else selected_actor
	elif card.has("joker"):
		selected_target = selected_actor
	elif selected_target not in _alive(1):
		selected_target = _alive(1)[0]
	_refresh()

func _select_hero(index: int) -> void:
	if busy or finished or current_side != 0 or heroes[index]["hp"] <= 0: return
	var mine: bool = heroes[index]["side"] == 0
	var card := _selected_card()
	var confirm: bool = last_tap == index
	last_tap = index
	if mine:
		var heals: bool = not card.is_empty() and (card.has("joker") or card["suit"] in ["♥", "♦"])
		if heals:
			selected_target = index
		else:
			selected_actor = index
			if not card.is_empty() and card["suit"] in ["♠", "♣"]:
				confirm = false
	else:
		selected_target = index
	_refresh()
	if not confirm: return
	last_tap = -1
	if not card.is_empty():
		_on_play()
	elif not mine:
		_on_attack()
	else:
		_zoom(str(heroes[index]["suit"]) + str(heroes[index]["rank"]), _hero_description(index))

func _on_play() -> void:
	if current_side != 0 or finished or busy: return
	var card := _selected_card()
	if card.is_empty() or not _can_play_on(selected_index, selected_target):
		_log("Jogada inválida: confira energia, alvo e ações disponíveis.")
		_refresh()
		return
	var index := selected_index
	var actor := selected_actor
	var target := selected_target
	var token := match_id
	var joker_suit := ""
	if card.has("joker") and card["joker"] == "blue":
		busy = true
		joker_suit = await _ask_suit(heroes[target]["side"] == 1)
		if token != match_id: return
		busy = false
		var eff := _effect_of(card, actor, target, joker_suit)
		var attack: bool = joker_suit in ["♠", "♣"]
		var enemy: bool = heroes[target]["side"] == 1
		if joker_suit == "" or not eff["ok"] or attack != enemy or (attack and used_attack):
			if joker_suit != "": _log("Esse naipe não combina com o alvo escolhido.")
			_refresh()
			return
	busy = true
	await _fly_card(index, target)
	if token != match_id: return
	var effect := _effect_of(card, actor, target, joker_suit)
	if effect["suit"] in ["♠", "♣"]:
		await _lunge(actor, target)
		if token != match_id: return
	busy = false
	if not _play_card(0, index, actor, target, joker_suit):
		_log("Jogada inválida: confira energia, alvo e ações disponíveis.")
	_refresh()

func _on_attack() -> void:
	if busy or current_side != 0 or finished or used_attack: return
	if selected_target not in _alive(1):
		selected_target = _alive(1)[0]
	var actor := selected_actor
	var target := selected_target
	var token := match_id
	busy = true
	await _lunge(actor, target)
	if token != match_id: return
	busy = false
	_basic_attack(actor, target)
	_refresh()

func _on_defend() -> void:
	if busy or current_side != 0 or finished or used_attack: return
	_defend(selected_actor)

func _on_ace() -> void:
	if busy or current_side != 0 or finished: return
	if not _activate_ace(selected_actor, selected_target):
		_log("Ás indisponível: confira energia e se ele já foi usado neste turno.")
		_refresh()

func _ask_suit(enemy_target: bool) -> String:
	if fast: return "♠" if enemy_target else "♥"
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.position = Vector2(size.x * 0.5 - 150.0, size.y * 0.3)
	box.add_theme_constant_override("separation", 8)
	overlay.add_child(box)
	var title := _make_label("Transformação: escolha o naipe", 18)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var options := [["♥", "Copas — cura aliado"], ["♦", "Ouros — energia e escudo"], ["♠", "Espadas — ataque perfurante"], ["♣", "Paus — ataque e escudo"], ["", "Cancelar"]]
	for option in options:
		var button := Button.new()
		button.text = option[1]
		button.custom_minimum_size = Vector2(0, 52)
		var chosen: String = option[0]
		button.pressed.connect(func(): suit_chosen.emit(chosen))
		box.add_child(button)
	var result: String = await suit_chosen
	overlay.queue_free()
	return result

func _can_play_on(index: int, target: int) -> bool:
	if busy or finished or current_side != 0 or used_card: return false
	if index < 0 or index >= hands[0].size() or selected_actor not in _alive(0): return false
	if target < 0 or target >= heroes.size() or heroes[target]["hp"] <= 0: return false
	var card: Dictionary = hands[0][index]
	if energy[0] < _cost(card): return false
	var enemy: bool = heroes[target]["side"] == 1
	if card.has("joker"): return not (enemy and used_attack)
	if card["suit"] in ["♠", "♣"]: return enemy and not used_attack
	return not enemy

func _drag_card(_position: Vector2, index: int) -> Variant:
	if busy or finished or current_side != 0 or used_card: return null
	_select_card(index, false)
	var preview := _ghost_for(hands[0][index])
	if hand_views.size() > 0:
		hand_views[mini(index, hand_views.size() - 1)].set_drag_preview(preview)
	return {"hand_index": index}

func _drag_hero(_position: Vector2, index: int) -> Variant:
	if busy or finished or current_side != 0 or used_attack or heroes[index]["side"] != 0 or heroes[index]["hp"] <= 0: return null
	selected_actor = index
	var preview := _make_label(str(heroes[index]["name"]) + "\nATACAR", 18)
	hero_views[index].set_drag_preview(preview)
	return {"attacker": index}

func _can_drop_on_hero(_position: Vector2, data: Variant, target: int) -> bool:
	if not data is Dictionary: return false
	if data.has("hand_index"): return _can_play_on(int(data["hand_index"]), target)
	if data.has("attacker"):
		return not busy and not finished and current_side == 0 and not used_attack and heroes[target]["side"] == 1 and heroes[target]["hp"] > 0
	return false

func _drop_on_hero(_position: Vector2, data: Variant, target: int) -> void:
	selected_target = target
	if data.has("hand_index"):
		selected_index = int(data["hand_index"])
		_on_play()
	else:
		selected_actor = int(data["attacker"])
		selected_index = -1
		_on_attack()

# ─────────────────────────── GALERIA ───────────────────────────

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
	layout.add_child(_make_label("Artes originais, sem cortes. Toque para ampliar.", 12))
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

# ─────────────────────────── EFEITOS EXTRAS ───────────────────────────

func _chip(card: Control, text: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -26
	panel.offset_left = 3
	panel.offset_right = -3
	panel.offset_bottom = -3
	panel.add_theme_stylebox_override("panel", _style(color, Color(1, 1, 1, 0.6), 1, 5))
	var label := _make_label(text, 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	card.add_child(panel)

func _view_center(view: Control) -> Vector2:
	return view.global_position - global_position + view.size * 0.5

func _burst(view: Control, kind: String) -> void:
	if fast: return
	var color := _fx_color(kind)
	var p := CPUParticles2D.new()
	ui["fx"].add_child(p)
	p.position = _view_center(view)
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 30
	p.lifetime = 0.85
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	match kind:
		"heal", "energy":
			p.direction = Vector2(0, -1)
			p.spread = 55.0
			p.gravity = Vector2(0, -120)
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 170.0
		"shield":
			p.spread = 180.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 110.0
			p.initial_velocity_max = 190.0
		_:
			p.spread = 180.0
			p.gravity = Vector2(0, 420)
			p.initial_velocity_min = 140.0
			p.initial_velocity_max = 320.0
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)

func _slash(view: Control) -> void:
	if fast: return
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.95)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(view.size.x * 1.4, 7)
	line.pivot_offset = line.size * 0.5
	line.rotation_degrees = -32.0
	line.position = _view_center(view) - line.size * 0.5
	line.scale = Vector2(0.1, 1)
	ui["fx"].add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "scale", Vector2.ONE, 0.1)
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.finished.connect(line.queue_free)

func _ring(view: Control, color: Color) -> void:
	if fast: return
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(60, 60)
	ring.pivot_offset = Vector2(30, 30)
	ring.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), color, 5, 30))
	ring.position = _view_center(view) - Vector2(30, 30)
	ui["fx"].add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.6, 3.6), 0.5)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.finished.connect(ring.queue_free)

func _screen_shake(strength: float) -> void:
	if fast or not ui.has("page"): return
	var page: Control = ui["page"]
	var tween := create_tween()
	for i in 6:
		tween.tween_property(page, "position", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength, 0.03)
	tween.tween_property(page, "position", Vector2.ZERO, 0.05)

func _confetti() -> void:
	if fast: return
	for k in 3:
		var p := CPUParticles2D.new()
		ui["fx"].add_child(p)
		p.position = Vector2(size.x * (0.2 + 0.3 * k), -10)
		p.amount = 80
		p.lifetime = 2.6
		p.one_shot = true
		p.explosiveness = 0.3
		p.direction = Vector2(0, 1)
		p.spread = 50.0
		p.gravity = Vector2(0, 260)
		p.initial_velocity_min = 140.0
		p.initial_velocity_max = 320.0
		p.scale_amount_min = 4.0
		p.scale_amount_max = 8.0
		p.color = GOLD
		p.hue_variation_min = -1.0
		p.hue_variation_max = 1.0
		p.emitting = true
		get_tree().create_timer(3.2).timeout.connect(p.queue_free)

func _zoom(key: String, text: String) -> void:
	if fast: return
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_zoom_input.bind(overlay))
	add_child(overlay)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 40
	box.offset_bottom = -30
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)
	if card_art.has(key):
		var art := TextureRect.new()
		art.texture = card_art[key]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(art)
	var label := _make_label(text, 15)
	label.add_theme_color_override("font_color", CREAM)
	box.add_child(label)
	var hint := _make_label("Toque para fechar", 12)
	hint.add_theme_color_override("font_color", GOLD)
	box.add_child(hint)
	overlay.modulate.a = 0.0
	box.pivot_offset = size * 0.5
	box.scale = Vector2(0.85, 0.85)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.18)
	tween.tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)

func _zoom_input(event: InputEvent, overlay: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		overlay.queue_free()
