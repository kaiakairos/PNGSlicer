extends CPUParticles2D

var colour = Color.WHITE

func _ready():
	one_shot = true
	modulate = colour
	emitting = true


func _on_finished():
	queue_free()
