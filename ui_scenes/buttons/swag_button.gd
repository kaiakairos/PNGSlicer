extends Button

@export var img :Texture2D = null

var tw :Tween= null

var passiveSize = Vector2(1,1)

func _ready():
	$Sprite2D.texture = img

func _on_pressed():
	$Sprite2D.scale = Vector2(0.1,0.1)
	if is_instance_valid(tw):
		tw.stop()
	
	tw = get_tree().create_tween()
	tw.tween_property($Sprite2D,"scale",Vector2(1,1),1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _process(delta):
	$Sprite2D.scale = lerp($Sprite2D.scale, passiveSize,0.2)

func _on_mouse_entered():
	passiveSize = Vector2(1.1,1.1)


func _on_mouse_exited():
	passiveSize = Vector2(1,1)
