extends Control
## Presentation only: observes accepted model transitions; never writes to the model.
const Mold = preload("res://scripts/cooking_mold.gd")
const POUR := "pour"
const FILL := "fill"
const FLIP := "flip"
const BURN_FADE_USEC := 250_000
var artwork: TextureRect
var utensil: TextureRect
var backing: TextureRect
var motion: Tween
var action := ""
var action_serial := 0
var previous_state := Mold.State.EMPTY
var cooking := false
var sparkling := false
var phase := 0.0
var progress := 0.0
var seed := 0.0
var blend_material: ShaderMaterial
var blend_frame: Dictionary = {}
var textures: Dictionary = {}

# Presentation uses the full side duration, not quality boundaries. A single
# continuous ramp avoids fast starts, held colors and sudden late darkening.
static func browning_frame(state: int, elapsed: int, difficulty: int, first_quality: int) -> Dictionary:
	var names := ["grill_empty", "grill_batter", "grill_filling", "grill_covered", "grill_cooking", "grill_normal", "grill_burnt"]
	var burnt_first := state == Mold.State.BURNT and first_quality == Mold.SideQuality.BURNT
	var visual_state := (Mold.State.SIDE_1 if burnt_first else Mold.State.SIDE_2) if state == Mold.State.BURNT else state
	var frame := {"from":names[visual_state],"to":names[visual_state],"weight":0.0,"color_only":false,"scorch":0.0}
	if visual_state == Mold.State.EMPTY:
		return frame
	var side_one := visual_state in [Mold.State.FIRST_BATTER,Mold.State.FILLING_ADDED,Mold.State.SIDE_1]
	var duration: int = Mold.timing(side_one,difficulty)[2]
	var progress := clampf(float(elapsed)/duration,0.0,1.0)
	frame.weight = progress
	# Keep edible bread golden. Only the actual BURNT state starts a brief
	# visual fade; gameplay has already committed the burn and remains interactive.
	if state == Mold.State.BURNT:
		frame.scorch = smoothstep(0.0,float(BURN_FADE_USEC),float(maxi(0,elapsed-duration)))
	if side_one:
		frame.color_only = true
		frame.color_from = Color("fff0d2")
		frame.color_to = Color("cc7926")
	else:
		frame.from = "grill_cooking"
		frame.to = "grill_normal"
	return frame

static func should_sparkle(mold: RefCounted, now: int) -> bool:
	if mold.state == Mold.State.SIDE_1:
		return Mold.first_quality_at(mold.elapsed_at(now),mold.difficulty) == Mold.SideQuality.PERFECT
	if mold.state in [Mold.State.SIDE_2,Mold.State.READY]:
		return mold.first_quality == Mold.SideQuality.PERFECT and Mold.second_quality_at(mold.elapsed_at(now),mold.difficulty) == Mold.SideQuality.PERFECT
	return false

func update_browning(mold: RefCounted, now: int) -> void:
	sparkling = cooking and should_sparkle(mold,now)
	queue_redraw()
	blend_frame = browning_frame(mold.state,mold.elapsed_at(now),mold.difficulty,mold.first_quality)
	for name in [blend_frame.from,blend_frame.to]:
		if not textures.has(name): textures[name] = load("res://assets/design/"+name+".png")
	artwork.texture = textures[blend_frame.from]
	blend_material.set_shader_parameter("next_texture",textures[blend_frame.to])
	blend_material.set_shader_parameter("blend_amount",blend_frame.weight)
	blend_material.set_shader_parameter("color_only",blend_frame.color_only)
	blend_material.set_shader_parameter("scorch",blend_frame.scorch)
	if blend_frame.color_only:
		blend_material.set_shader_parameter("color_from",blend_frame.color_from)
		blend_material.set_shader_parameter("color_to",blend_frame.color_to)


func setup(image: TextureRect, index: int) -> void:
	artwork = image
	artwork.pivot_offset = artwork.size / 2.0
	backing = artwork.duplicate()
	backing.texture = preload("res://assets/design/grill_empty.png")
	artwork.get_parent().add_child(backing)
	artwork.get_parent().move_child(backing,artwork.get_index())
	backing.hide()
	blend_material = ShaderMaterial.new()
	blend_material.shader = preload("res://scripts/cooking_crossfade.gdshader")
	artwork.material = blend_material
	seed = index * 0.37
	phase = seed
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ZERO
	size = Vector2(209,125)
	utensil = TextureRect.new()
	utensil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	utensil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	utensil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	utensil.size = Vector2(72,72)
	utensil.pivot_offset = Vector2(36,36)
	add_child(utensil)
	utensil.hide()
	set_process(false)

func sync(state: int, active: bool) -> void:
	if not active or state in [Mold.State.EMPTY, Mold.State.BURNT]:
		clear()
		previous_state = state
		return
	cooking = state in [Mold.State.FIRST_BATTER, Mold.State.FILLING_ADDED, Mold.State.SIDE_1, Mold.State.SIDE_2, Mold.State.READY]
	var next_action := ""
	if (previous_state == Mold.State.EMPTY and state == Mold.State.FIRST_BATTER) or (previous_state == Mold.State.FILLING_ADDED and state == Mold.State.SIDE_1):
		next_action = POUR
	elif previous_state == Mold.State.FIRST_BATTER and state == Mold.State.FILLING_ADDED:
		next_action = FILL
	elif previous_state == Mold.State.SIDE_1 and state == Mold.State.SIDE_2:
		next_action = FLIP
	previous_state = state
	if not next_action.is_empty(): _play(next_action)
	visible = true
	set_process(cooking or not action.is_empty())

func _reset_motion() -> void:
	if motion != null and motion.is_valid(): motion.kill()
	motion = null
	action = ""
	progress = 0.0
	artwork.scale = Vector2.ONE
	artwork.rotation = 0.0
	utensil.hide()
	backing.hide()
	utensil.rotation = 0.0
	utensil.modulate = Color.WHITE

func clear() -> void:
	_reset_motion()
	cooking = false
	sparkling = false
	phase = seed
	visible = false
	set_process(false)
	queue_redraw()

func _play(kind: String) -> void:
	_reset_motion()
	action = kind
	action_serial += 1
	motion = create_tween()
	if kind == FLIP:
		backing.show()
		motion.set_parallel(true)
		motion.tween_property(artwork,"scale:x",0.05,0.12).set_trans(Tween.TRANS_SINE)
		motion.tween_property(artwork,"rotation",-0.16,0.12)
		motion.chain().tween_property(artwork,"scale:x",1.0,0.18).set_trans(Tween.TRANS_SINE)
		motion.parallel().tween_property(artwork,"rotation",0.0,0.18)
	else:
		utensil.texture = preload("res://assets/design/kettle.png") if kind == POUR else preload("res://assets/design/spatula_cursor.png")
		utensil.position = Vector2(110,-8)
		utensil.show()
		motion.set_parallel(true)
		motion.tween_property(self,"progress",1.0,0.48)
		motion.tween_property(utensil,"position",Vector2(83,-13) if kind == POUR else Vector2(69,24),0.20).set_trans(Tween.TRANS_SINE)
		motion.tween_property(utensil,"rotation",-0.65 if kind == POUR else -0.35,0.20)
		motion.chain().tween_property(utensil,"modulate:a",0.0,0.12)
		motion.parallel().tween_property(utensil,"position",Vector2(110,-8),0.12)
	motion.finished.connect(_finish_motion)

func _finish_motion() -> void:
	action = ""
	utensil.hide()
	backing.hide()
	artwork.scale = Vector2.ONE
	artwork.rotation = 0.0
	set_process(cooking)
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()

func _draw() -> void:
	# A separate layer stays bright instead of being darkened by bread shading.
	if sparkling:
		for i in 3:
			var center: Vector2 = [Vector2(35,29),Vector2(174,87),Vector2(126,28)][i]
			var radius := 13.0 + 3.0 * sin(phase * 4.5 + i * TAU / 3.0)
			var star := PackedVector2Array()
			for point in 8:
				var angle := -PI/2.0 + point * PI/4.0
				star.append(center + Vector2(cos(angle),sin(angle)) * (radius if point % 2 == 0 else radius * 0.28))
			var glow := PackedVector2Array()
			for point in star: glow.append(center + (point-center)*1.45)
			draw_colored_polygon(glow,Color(1.0,0.8,0.3,0.23))
			draw_colored_polygon(star,Color("fff8d9"))
			draw_circle(center,2.5,Color.WHITE)
			star.append(star[0])
			draw_polyline(star,Color("bf843d"),1.3,true)
	if cooking:
		for i in 3:
			var t := fposmod(phase * 0.7 + i / 3.0,1.0)
			var x := 71.0 + i * 28.0
			var alpha := sin(t * PI) * 0.55
			var points := PackedVector2Array()
			for j in 5:
				points.append(Vector2(x + sin(t * TAU + j * 0.8) * 3.0,53.0 - t * 34.0 - j * 4.0))
			draw_polyline(points,Color(1.0,0.95,0.84,alpha),2.2,true)
	if action == POUR and progress > 0.18 and progress < 0.85:
		var alpha := sin((progress-0.18)/0.67*PI)
		draw_line(Vector2(104,44),Vector2(97,76),Color(1.0,0.94,0.82,alpha),4.0,true)
		draw_circle(Vector2(97,76),4.0,Color(1.0,0.94,0.82,alpha*0.7))
	elif action == FILL and progress > 0.25 and progress < 0.8:
		var t := (progress-0.25)/0.55
		draw_circle(Vector2(108,48+t*25),3.5,Color(0.38,0.20,0.16,sin(t*PI)))
