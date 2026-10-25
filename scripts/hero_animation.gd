class_name HeroAnimation
extends RefCounted
## Presentation only: normalize pose art and keep locomotion phase across speeds.
static func play(sprite: AnimatedSprite2D, name: String) -> void:
	if sprite.animation == name and (sprite.is_playing() or not sprite.sprite_frames.get_animation_loop(name)):
		return
	# Reach was drawn at a higher source resolution. Preserve the foot origin
	# and gravity-facing sign while matching the existing character's height.
	var previous_scale := float(sprite.get_meta("hero_pose_scale", 1.0))
	var next_scale := 0.72 if name == "reach" else 1.0
	if name == "reach":
		if not sprite.has_meta("hero_pose_offset"):
			sprite.set_meta("hero_pose_offset", sprite.offset)
		sprite.offset = Vector2(-200, -464)
	elif sprite.has_meta("hero_pose_offset"):
		sprite.offset = sprite.get_meta("hero_pose_offset")
		sprite.remove_meta("hero_pose_offset")
	sprite.scale *= next_scale / previous_scale
	sprite.set_meta("hero_pose_scale", next_scale)
	var stride := sprite.animation in [&"run", &"sprint"] and name in ["run", "sprint"]
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(name)
	if stride:
		sprite.set_frame_and_progress(frame, progress)

static func cadence(name: String, speed: float) -> float:
	if name == "run":
		return clampf(speed / 225.0, 0.35, 1.5)
	if name == "sprint":
		return clampf(speed / 340.0, 0.5, 1.5)
	return 1.0
