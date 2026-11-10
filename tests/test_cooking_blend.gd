extends SceneTree
const FX = preload("res://scripts/cooking_effects.gd")
const Mold = preload("res://scripts/cooking_mold.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run():
	for mode in [Mold.Difficulty.NORMAL,Mold.Difficulty.EASY]:
		for first in [true,false]:
			var times := Mold.timing(first,mode)
			var state := Mold.State.SIDE_1 if first else Mold.State.SIDE_2
			for quality in [Mold.SideQuality.NORMAL,Mold.SideQuality.PERFECT]:
				for elapsed in [0, times[0]/2, times[0]-1,times[0],times[0]+1,times[1]-1,times[1],times[1]+1,(times[1]+times[2])/2,times[2]-1,times[2]]:
					var f := FX.browning_frame(state,int(elapsed),mode,quality)
					if first:
						check(f.color_only and f.from == "grill_covered" and f.to == "grill_covered", "first side preserves one silhouette throughout cooking")
						var expected := Color("fff0d2").lerp(Color("d5ac79"),f.weight) if elapsed < times[0] else Color("d5ac79").lerp(Color("cc7926"),f.weight)
						check(f.color_from.lerp(f.color_to,f.weight).is_equal_approx(expected), "first side uses original palette continuously")
					check(f.weight >= 0.0 and f.weight <= 1.0, "blend bounded")
					if elapsed < times[0]:
						check(is_equal_approx(f.weight,float(elapsed)/times[0]), "raw to normal follows actual minimum time")
					elif elapsed <= times[1]:
						check(f.from == f.to and f.weight == 0, "normal region remains normal")
					else:
						check(is_equal_approx(f.weight,float(elapsed-times[1])/(times[2]-times[1])), "goldening follows mode perfect interval")
					if not first and quality == Mold.SideQuality.NORMAL:
						check(not f.to.contains("perfect"), "normal first side cannot display delicious sparkle")
				var at := FX.browning_frame(state,times[0],mode,quality)
				var before := FX.browning_frame(state,times[0]-1,mode,quality)
				check(before.to == at.from and before.weight > 0.999, "minimum color boundary continuous")
				at = FX.browning_frame(state,times[1],mode,quality)
				var after := FX.browning_frame(state,times[1]+1,mode,quality)
				check(at.to == after.from and after.weight < 0.00001, "normal to perfect boundary continuous")
				var burned := FX.browning_frame(Mold.State.BURNT,times[2]+1,mode,quality)
				check(burned.from == "grill_burnt" and burned.to == "grill_burnt", "burned model is displayed immediately")
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = "res://.tools/test-data/blend-%d.json" % OS.get_process_id()
	root.add_child(main)
	main.set_process(false)
	main._start_round()
	var now := Time.get_ticks_usec()
	main.session.start(now)
	for i in 6:
		var mold = main.session.molds[i]
		mold.add_batter(now)
		mold.add_filling(now)
		mold.add_batter(now)
		mold.side_started_at = now-i*500_000
	main._render(now)
	for i in 6:
		var fx = main.final_design.cooking_effects[i]
		check(is_equal_approx(fx.blend_material.get_shader_parameter("blend_amount"),i*0.1), "actual UI uses explicit render clock independently")
		check(fx.backing.material == null, "fixed empty mold is not tinted or blended")
		if i > 0: check(fx.blend_material != main.final_design.cooking_effects[i-1].blend_material, "materials are not shared between molds")
		check(main.session.molds[i].state == Mold.State.SIDE_1 and main.session.molds[i].side_started_at == now-i*500_000, "rendering never mutates cooking model")
	main.session.advance(now+main.Session.DURATION_USEC)
	main._render(now+main.Session.DURATION_USEC)
	for fx in main.final_design.cooking_effects:
		check(fx.blend_frame.from == "grill_empty" and fx.blend_frame.weight == 0 and not fx.visible, "end clears blend and steam")
	main._start_round()
	check(main.final_design.cooking_effects[0].blend_frame.from == "grill_empty", "retry starts with empty texture")
	main.queue_free()
	await process_frame
	print("PNG BLEND TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
