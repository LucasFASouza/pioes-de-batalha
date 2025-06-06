extends Node3D

@onready var debris = $Debris
@onready var explosion_souns: AudioStreamPlayer3D = $ExplosionSouns
@onready var omni_light = $OmniLight3D

func explode(impact_force: float = 1.0):
	var scale_multiplier = clamp(impact_force / 50.0, 0.5, 1.5)
	scale = Vector3.ONE * scale_multiplier
	
	var base_amount = 16
	debris.amount = int(base_amount * clamp(scale_multiplier, 0.8, 1.3))
	
	debris.emitting = true
	
	explosion_souns.pitch_scale = randf_range(0.8, 1.2)
	explosion_souns.play()
	
	var tween = create_tween()
	tween.tween_property(omni_light, "light_energy", 0.0, 0.35)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()
