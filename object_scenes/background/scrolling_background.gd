extends Node2D

@export var texture : Texture

@export var scrollSpeed : float = 0.0

@onready var container = $SpriteContainer

var size = 800

func _ready():
	var img: Image = texture.get_image()
	size = img.get_size().x
	
	for i in range(3):
		var sprite = Sprite2D.new()
		sprite.texture = texture
		sprite.position.x = (i-1) * size
		sprite.centered = false
		#sprite.position.y = img.get_size().y * 0.5
		container.add_child(sprite)
	
	if scrollSpeed == 0.0:
		set_process(false)

func _process(delta):
	container.position.x += scrollSpeed * delta
	if container.position.x >= size:
		container.position.x -= size
	elif container.position.x <= -size:
		container.position.x += size
