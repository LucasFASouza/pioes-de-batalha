extends Node3D

@onready var debris = $Debris
@onready var explosion_souns: AudioStreamPlayer3D = $ExplosionSouns

func explode(impact_force: float = 1.0):
	var scale_multiplier = clamp(impact_force / 10.0, 0.3, 3.0)
	scale = Vector3.ONE * scale_multiplier
	
	var base_amount = 16
	debris.amount = int(base_amount * clamp(scale_multiplier, 0.5, 3))
	
	debris.emitting = true
	
	explosion_souns.pitch_scale = randf_range(0.8, 1.2)
	explosion_souns.play()
	
	await get_tree().create_timer(0.5).timeout
	queue_free()
