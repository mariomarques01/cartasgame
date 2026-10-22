extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.fast = true
	await process_frame
	await process_frame
	check(game.card_art.size() == 48, "All 48 original textures must load")
	for h in game.heroes:
		check(game.card_art.has(h.suit + h.rank), "Missing hero art: " + h.name)
	check(game.hero_views.size() == 6, "Six heroes must appear")
	for width in [320, 390, 540, 844, 1024]:
		game.size = Vector2(width, 960)
		await process_frame
		await process_frame
		for node in game.hero_views.values():
			check(node.size.x > 0 and node.global_position.x + node.size.x <= width + 1, "Hero exceeds viewport at width " + str(width))
	game.new_game()
	game.hands[0] = [{"id":"♠3", "suit":"♠", "value":3}]
	game._refresh()
	await process_frame
	await process_frame
	game._select_card(0)
	check(not game._can_play_on(0, 0), "Attack must reject allied target")
	check(game._can_play_on(0, 3), "Attack must accept enemy target")
	var hp: int = game.heroes[3].hp
	await game._on_play()
	check(game.heroes[3].hp < hp, "Animated attack must deal damage")
	check(game.hands[0].is_empty() and game.discard.size() == 1, "Move exactly one card to discard")
	check(game.used_attack and game.used_card, "Attack limits must be enforced")
	check(not game._can_play_on(0, 3), "Cannot replay a spent card")
	game.new_game()
	game.heroes[0].hp -= 5
	game.hands[0] = [{"id":"♥3", "suit":"♥", "value":3}]
	game._select_card(0)
	check(game.selected_target == 0, "Healing selects most wounded ally")
	check(not game._can_play_on(0, 3), "Healing rejects enemy")
	hp = game.heroes[0].hp
	check(game._play_card(0, 0, 0, 0), "Healing resolves")
	check(game.heroes[0].hp > hp, "Healing restores HP")
	game.new_game()
	game.energy[0] = 0
	game.hands[0] = [{"id":"♠3", "suit":"♠", "value":3}]
	check(not game._can_play_on(0, 3), "Insufficient energy blocks play")
	game.new_game()
	await game._end_turn()
	check(game.current_side == 0 and game.round_number == 2, "AI returns control after its turn")
	# --- habilidades ---
	game.new_game()
	var healthy: int = game._estimate(2, 3)
	game.heroes[2].hp = 4
	check(game._estimate(2, 3) == healthy + 2, "Valete de Paus: Furia +2 com 4 PV")
	game.new_game()
	game.energy[0] = 6
	game.selected_actor = 2
	check(game._activate_ace(2, 3), "As de Paus ativa")
	check(game.heroes[2].ace_bonus == 2, "As de Paus concede +2 ATQ")
	var base: int = game._estimate(2, 3)
	var hp2: int = game.heroes[3].hp
	check(game._basic_attack(2, 3), "Ataque basico apos As")
	check(hp2 - game.heroes[3].hp >= base - 2, "Bonus do As entra no dano")
	check(game.heroes[2].ace_bonus == 0, "Bonus do As e consumido")
	game.new_game()
	game.energy[0] = 6
	game.heroes[1].hp = 3
	check(game._activate_ace(1, 1), "As de Copas ativa")
	check(game.heroes[1].hp == 6 and game.heroes[1].shield == 1, "As de Copas cura 3 e da escudo 1")
	game.new_game()
	check(game._defend(0) and game.heroes[0].shield == 2 and game.used_attack, "Defender da 2 escudos e gasta o ataque")
	check(not game._basic_attack(0, 3), "Nao ataca apos defender")
	game.new_game()
	game.energy[0] = 6
	game.hands[0] = [{"id":"joker-red","joker":"red"}]
	game.selected_actor = 0
	hp = game.heroes[3].hp
	check(game._play_card(0, 0, 0, 3), "Coringa vermelho ataca inimigo")
	check(game.heroes[3].hp < hp, "Coringa vermelho causa dano")
	game.new_game()
	game.energy[0] = 6
	game.heroes[0].hp = 5
	game.hands[0] = [{"id":"joker-red","joker":"red"}]
	check(game._play_card(0, 0, 0, 0), "Coringa vermelho cura aliado")
	check(game.heroes[0].hp == 9, "Coringa vermelho cura 4")
	game.new_game()
	game.energy[0] = 6
	game.hands[0] = [{"id":"joker-blue","joker":"blue"}]
	check(not game._play_card(0, 0, 0, 3), "Coringa azul exige naipe")
	check(game._play_card(0, 0, 0, 3, "♣"), "Coringa azul vira Paus")
	game.new_game()
	game.heroes[3].shield = 4
	hp = game.heroes[3].hp
	game._damage(0, 3)
	check(game.heroes[3].hp == hp and game.heroes[3].shield < 4, "Escudo absorve dano antes da vida")
	# partida completa so com IA nos dois lados
	game.new_game()
	for i in 6:
		if game.finished: break
		await game._end_turn()
	check(game.round_number >= 2, "Partida avanca varias rodadas")
	game._show_gallery()
	await process_frame
	check(is_instance_valid(game.gallery_overlay), "Gallery opens")
	print("SMOKE TEST: ", failures, " failures")
	quit(1 if failures else 0)
