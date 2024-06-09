extends Node

var sfxScene = preload("res://sound/sfx.tscn")

var bumpDelay = 0

func playSound(file: String,volume: float,pitch: float,positionGlobal:Vector2):
	
	if !Global.playSounds:
		return
	
	if file == "bump" and bumpDelay > 0:
		return
	
	var sfx = sfxScene.instantiate()
	
	sfx.stream = load("res://sound/sfx/" + file + ".ogg")
	sfx.volume_db = volume
	sfx.pitch_scale = pitch
	
	add_child(sfx)
	if file == "bump":
		bumpDelay = 5

func _process(delta):
	bumpDelay -= 1
