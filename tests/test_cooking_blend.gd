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
				for elapsed in [0,1,100_000,times[0]/2,times[0]-1,times[0],times[0]+1,times[1]-1,times[1],times[1]+1,times[2]-1,times[2]]:
					var f := FX.browning_frame(state,int(elapsed),mode,quality)
					var progress: float = float(elapsed)/times[2]
					check(is_equal_approx(f.weight,progress),"color progresses across entire cooking duration")
					check(f.scorch == 0.0,"edible bread never darkens, even throughout perfect interval")
					if first:
						check(f.color_only and f.from == "grill_covered" and f.to == "grill_covered","first-side silhouette fixed")
					else:
						check(f.from == "grill_cooking","second-side blend source never switches at quality boundary")
						if quality == Mold.SideQuality.NORMAL:
							check(not f.to.contains("perfect"),"normal first side cannot show delicious sparkle")
				for boundary in times:
					var before := FX.browning_frame(state,boundary-1,mode,quality)
					var after := FX.browning_frame(state,boundary+1,mode,quality)
					check(before.from == after.from and before.to == after.to and absf(before.weight-after.weight)<0.00001 and absf(before.scorch-after.scorch)<0.00001,"no color jump at quality boundary")
				var near_burn := FX.browning_frame(state,times[2]-1,mode,quality)
				var burned := FX.browning_frame(Mold.State.BURNT,times[2]+1,mode,Mold.SideQuality.BURNT if first else quality)
				check(burned.from == near_burn.from and burned.to == near_burn.to and absf(burned.weight-near_burn.weight)<0.001,"burning never swaps artwork")
				check(burned.scorch < 0.00001,"burn starts visually continuous after actual deadline")
				for offset in [0,1,125_000,249_999,250_000,500_000]:
					var burnt_quality: int = Mold.SideQuality.BURNT if first else quality
					var faded := FX.browning_frame(Mold.State.BURNT,times[2]+offset,mode,burnt_quality)
					var expected := 0.0 if offset == 0 else (0.5 if offset == 125_000 else (1.0 if offset >= 250_000 else -1.0))
					check(faded.scorch >= 0 and faded.scorch <= 1,"burn fade bounded")
					if expected >= 0: check(is_equal_approx(faded.scorch,expected),"burn fade completes in 250ms without delaying model")
				var previous := FX.browning_frame(state,0,mode,quality)
				for elapsed in range(100_000,times[2]+1,100_000):
					var current := FX.browning_frame(state,elapsed,mode,quality)
					check(current.weight > previous.weight and current.weight-previous.weight < 0.017,"no pauses or accelerated color bursts in 100ms steps")
					check(current.scorch == 0.0,"cooking remains golden until burnt")
					previous = current
		# Batter already cooks while ingredients are being added. Keep the same
		# color progress when filling and covering so the third click cannot jump.
		for elapsed in [0,1_000_000,3_000_000,5_000_000]:
			var batter := FX.browning_frame(Mold.State.FIRST_BATTER,elapsed,mode,Mold.SideQuality.COOKING)
			for state in [Mold.State.FILLING_ADDED,Mold.State.SIDE_1]:
				var next := FX.browning_frame(state,elapsed,mode,Mold.SideQuality.COOKING)
				check(batter.weight == next.weight and batter.scorch == next.scorch and batter.color_from == next.color_from and batter.color_to == next.color_to,"ingredient clicks preserve ongoing color progress")
	for mode in [Mold.Difficulty.NORMAL,Mold.Difficulty.EASY]:
		var mold := Mold.new(mode)
		for first in [true,false]:
			var limits := Mold.timing(first,mode)
			for quality in [Mold.SideQuality.NORMAL,Mold.SideQuality.PERFECT]:
				mold.first_quality = quality
				mold.side_started_at = 0
				for state in ([Mold.State.SIDE_1] if first else [Mold.State.SIDE_2,Mold.State.READY]):
					mold.state = state
					for elapsed in [0,limits[0],limits[1]-1,limits[1],limits[1]+1,limits[2]-1,limits[2],limits[2]+1]:
						var expected: bool = elapsed > limits[1] and elapsed <= limits[2] and (first or quality == Mold.SideQuality.PERFECT)
						check(FX.should_sparkle(mold,elapsed) == expected,"sparkles only at actual first-side perfect or delicious second-side quality")
		for state in [Mold.State.EMPTY,Mold.State.FIRST_BATTER,Mold.State.FILLING_ADDED,Mold.State.BURNT]:
			mold.state = state
			check(not FX.should_sparkle(mold,8_500_000),"inactive/incomplete/burnt bread never sparkles")
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
		check(is_equal_approx(fx.blend_material.get_shader_parameter("blend_amount"),float(i*500_000)/Mold.timing(true,Mold.Difficulty.NORMAL)[2]), "actual UI uses explicit render clock independently")
		check(fx.backing.material == null, "fixed empty mold is not tinted or blended")
		if i > 0: check(fx.blend_material != main.final_design.cooking_effects[i-1].blend_material, "materials are not shared between molds")
		check(main.session.molds[i].state == Mold.State.SIDE_1 and main.session.molds[i].side_started_at == now-i*500_000, "rendering never mutates cooking model")
	for i in 6:
		var mold = main.session.molds[i]
		mold.side_started_at = now-8_000_000 if i % 2 == 0 else now-6_000_000
	main._render(now)
	for i in 6:
		check(main.final_design.cooking_effects[i].sparkling == (i % 2 == 0),"actual UI independently shows perfect first-side sparkles")
	main.session.advance(now+1_000_001)
	main._render(now+1_000_001)
	check(main.session.molds[0].state == Mold.State.BURNT and main.final_design.cooking_effects[0].blend_frame.scorch < 0.001,"model burns immediately while visual fade starts")
	check(not main.final_design.cooking_effects[0].sparkling,"sparkles stop immediately upon burning")
	main.click_mold_at(0,now+1_000_002)
	check(main.session.bag.items.size() == 1 and main.session.bag.items[0] == Mold.Quality.BURNT,"burnt bread can be collected during fade without delaying input")
	main.session.advance(now+main.Session.DURATION_USEC)
	main._render(now+main.Session.DURATION_USEC)
	for fx in main.final_design.cooking_effects:
		check(fx.blend_frame.from == "grill_empty" and fx.blend_frame.weight == 0 and not fx.visible and not fx.sparkling, "end clears blend and steam")
	main._start_round()
	check(main.final_design.cooking_effects[0].blend_frame.from == "grill_empty", "retry starts with empty texture")
	main.queue_free()
	await process_frame
	print("PNG BLEND TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
