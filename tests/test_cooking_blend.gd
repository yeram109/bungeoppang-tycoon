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
					check(is_equal_approx(f.scorch,progress*progress*progress),"darkening is gradual from start")
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
				check(burned.scorch == 1.0,"burn color finishes at original deadline")
				var previous := FX.browning_frame(state,0,mode,quality)
				for elapsed in range(100_000,times[2]+1,100_000):
					var current := FX.browning_frame(state,elapsed,mode,quality)
					check(current.weight > previous.weight and current.weight-previous.weight < 0.017,"no pauses or accelerated color bursts in 100ms steps")
					check(current.scorch >= previous.scorch and current.scorch-previous.scorch < 0.05,"darkening has bounded frame-to-frame change")
					previous = current
		# Batter already cooks while ingredients are being added. Keep the same
		# color progress when filling and covering so the third click cannot jump.
		for elapsed in [0,1_000_000,3_000_000,5_000_000]:
			var batter := FX.browning_frame(Mold.State.FIRST_BATTER,elapsed,mode,Mold.SideQuality.COOKING)
			for state in [Mold.State.FILLING_ADDED,Mold.State.SIDE_1]:
				var next := FX.browning_frame(state,elapsed,mode,Mold.SideQuality.COOKING)
				check(batter.weight == next.weight and batter.scorch == next.scorch and batter.color_from == next.color_from and batter.color_to == next.color_to,"ingredient clicks preserve ongoing color progress")
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
