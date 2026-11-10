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
	if DisplayServer.get_name() == "headless":
		print("GPU visual test requires a graphical renderer")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(209,125)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := TextureRect.new()
	art.size = Vector2(209,125)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewport.add_child(art)
	var fx := FX.new()
	viewport.add_child(fx)
	fx.setup(art,0)
	for mode in [Mold.Difficulty.NORMAL,Mold.Difficulty.EASY]:
		var mold := Mold.new(mode)
		mold.state = Mold.State.SIDE_1
		mold.side_started_at = 0
		var times := Mold.timing(true,mode)
		var baseline: Image
		for elapsed in [0,times[0]/2,times[0],times[1],(times[1]+times[2])/2,times[2],times[2]+1]:
			mold.advance(int(elapsed))
			fx.update_browning(mold,int(elapsed))
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			if elapsed == 0: baseline = rendered
			var alpha_unchanged := true
			var outline_unchanged := true
			var changed := 0
			var visible_pixels := 0
			for y in rendered.get_height():
				for x in rendered.get_width():
					var a := baseline.get_pixel(x,y)
					var b := rendered.get_pixel(x,y)
					if a.a > 0.5: visible_pixels += 1
					if absf(a.a-b.a) > 0.004: alpha_unchanged = false
					if a.a > 0.9 and a.r < 0.5 and a.g < 0.5 and not a.is_equal_approx(b): outline_unchanged = false
					if a.a > 0.9 and absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.05: changed += 1
			check(visible_pixels > 1000,"renderer produced actual bread pixels")
			check(alpha_unchanged,"first-side alpha silhouette remains identical")
			check(outline_unchanged,"dark outlines remain fixed")
			check(changed > 50 if elapsed > 0 else changed == 0,"only color changes during cooking")
	viewport.queue_free()
	await process_frame
	print("GPU VISUAL TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
