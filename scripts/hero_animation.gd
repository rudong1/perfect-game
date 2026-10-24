class_name HeroAnimation
extends RefCounted
## Shared presentation only: eight-step locomotion keeps phase across speeds.
static func play(sprite: AnimatedSprite2D, name: String) -> void:
	if sprite.animation == name and (sprite.is_playing() or not sprite.sprite_frames.get_animation_loop(name)):
		return
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
