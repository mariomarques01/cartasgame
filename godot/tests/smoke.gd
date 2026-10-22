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
	check(game.selected_target == 0, "Healing selects allied target")
	check(not game._can_play_on(0, 3), "Healing rejects enemy")
	hp = game.heroes[0].hp
	check(game._play_card(0, 0, 0, 0), "Healing resolves")
	check(game.heroes[0].hp > hp, "Healing restores HP")
	game.new_game()
	game.energy[0] = 0
	game.hands[0] = [{"id":"♠3", "suit":"♠", "value":3}]
	check(not game._can_play_on(0, 3), "Insufficient energy blocks play")
	game.new_game()
	game._end_turn()
	check(game.current_side == 0 and game.round_number == 2, "AI returns control after its turn")
	game._show_gallery()
	await process_frame
	check(is_instance_valid(game.gallery_overlay), "Gallery opens")
	print("SMOKE TEST: ", failures, " failures")
	quit(1 if failures else 0)
