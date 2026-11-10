extends SceneTree
const Mold = preload("res://scripts/cooking_mold.gd")
const Session = preload("res://scripts/cooking_session.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func ingredient(main, tool: int, index: int, now: int):
	main.session.select_tool(tool,now)
	main.click_mold_at(index,now)
func run():
	for mode in [Mold.Difficulty.NORMAL,Mold.Difficulty.EASY]:
		var main = load("res://scenes/main.tscn").instantiate()
		main.ranking_path = "res://.tools/test-data/v001-%d-%d.json" % [OS.get_process_id(),mode]
		root.add_child(main)
		main.set_process(false)
		main.difficulty_select.select(mode)
		main._start_round()
		for fx in main.final_design.cooking_effects:
			check(not fx.visible and not fx.is_processing(), "preparation has no effects")
		var now := Time.get_ticks_usec()
		main.session.start(now,mode)
		main._render(now)
		for i in 6:
			var fx = main.final_design.cooking_effects[i]
			ingredient(main,Session.Tool.BATTER,i,now)
			check(fx.action == fx.POUR and fx.action_serial == 1 and fx.cooking, "accepted first batter starts pour")
			var serial: int = fx.action_serial
			main.click_mold_at(i,now)
			check(fx.action_serial == serial, "wrong ingredient click does not replay")
			ingredient(main,Session.Tool.FILLING,i,now)
			check(fx.action == fx.FILL and fx.action_serial == 2 and main.session.molds[i].state == Mold.State.FILLING_ADDED, "rapid filling replaces pour without blocking input")
			ingredient(main,Session.Tool.BATTER,i,now)
			check(fx.action == fx.POUR and fx.action_serial == 3 and main.session.molds[i].state == Mold.State.SIDE_1, "rapid second batter replaces filling")
			main.click_mold_at(i,now+4_999_999)
			check(fx.action_serial == 3 and main.session.molds[i].state == Mold.State.SIDE_1, "early flip produces no animation")
			check(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE and fx.utensil.mouse_filter == Control.MOUSE_FILTER_IGNORE and fx.artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE and fx.backing.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visual layers cannot intercept clicks")
		# All six active effects remain independent, with staggered ambient loops.
		for i in 6:
			check(main.final_design.cooking_effects[i].action == "pour", "six pours can coexist")
			main.click_mold_at(i,now+8_000_000)
			var fx = main.final_design.cooking_effects[i]
			check(fx.action == fx.FLIP and fx.action_serial == 4 and fx.backing.visible, "accepted flip starts its own animation")
			check(main.session.molds[i].state == Mold.State.SIDE_2 and main.session.molds[i].side_started_at == now+8_000_000, "flip model commits immediately")
			main._render(now+8_000_000)
			check(fx.action_serial == 4, "frame refresh never restarts action")
		check(main.final_design.cooking_effects[0].seed != main.final_design.cooking_effects[1].seed, "ambient phases staggered")
		await create_timer(0.40).timeout
		for fx in main.final_design.cooking_effects:
			check(fx.action.is_empty() and not fx.backing.visible and fx.artwork.scale.is_equal_approx(Vector2.ONE) and is_zero_approx(fx.artwork.rotation), "flip tween completes with exact neutral transform")
			check(fx.cooking and fx.is_processing(), "cooking loop continues after transient effect")
		check(main.session.revenue == 0 and main.session.molds[0].side_started_at == now+8_000_000 and main.session.running, "animation completion cannot advance or modify game state")
		main.click_mold_at(0,now+11_000_000)
		check(main.session.bag.items.size() == 1 and not main.final_design.cooking_effects[0].visible, "collection clears effects immediately")
		check(main.final_design.cooking_effects[1].visible, "collection does not stop adjacent mold")
		ingredient(main,Session.Tool.BATTER,0,now+11_000_001)
		check(main.final_design.cooking_effects[0].action == "pour", "collected mold can animate new bread")
		await create_timer(0.65).timeout
		check(main.final_design.cooking_effects[0].action.is_empty() and not main.final_design.cooking_effects[0].utensil.visible and main.session.molds[0].state == Mold.State.FIRST_BATTER, "pour completes without changing ingredients")
		ingredient(main,Session.Tool.FILLING,0,now+11_000_002)
		await create_timer(0.65).timeout
		check(main.final_design.cooking_effects[0].action.is_empty() and not main.final_design.cooking_effects[0].utensil.visible and main.session.molds[0].state == Mold.State.FILLING_ADDED, "spoon completes without changing ingredients")
		# Burn interrupts the transient effect and stops ambient steam.
		main.session.advance(now+30_000_000)
		main._render(now+30_000_000)
		for fx in main.final_design.cooking_effects:
			check(not fx.visible and not fx.is_processing() and fx.action.is_empty(), "burn cancels transient and ambient effects")
		# End while a fresh action is running, then replay: no late callbacks.
		main.session.start(now,mode)
		main._render(now)
		ingredient(main,Session.Tool.BATTER,2,now+1)
		main.session.advance(now+Session.DURATION_USEC)
		main._finish_if_needed()
		main._render(now+Session.DURATION_USEC)
		for fx in main.final_design.cooking_effects:
			check(not fx.visible and fx.action.is_empty() and fx.artwork.scale == Vector2.ONE, "deadline cancels effects and restores artwork")
		main._start_round()
		await create_timer(0.65).timeout
		for fx in main.final_design.cooking_effects:
			check(not fx.visible and not fx.cooking and fx.action.is_empty(), "retry has no stale effect callback")
		main.queue_free()
		await process_frame
	print("V001 ANIMATION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
