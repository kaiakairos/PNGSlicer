extends Node2D

## Node Reference ##
@onready var wallCollider = $Collider/CollisionPolygon2D
@onready var sliceContainer = $sliceableContainer
@onready var cam = $Camera2D




## holders ##
@onready var sliceableScene = preload("res://object_scenes/sliceable/sliceable.tscn")
var texSliceable :Texture2D = null
var previousWindowSize = Vector2(600,600)
var file = "png"

var bgorobj = true # false = BG, true = obj 
var twColor :Tween = null
var twInfo :Tween = null
var twSound :Tween = null
var twInfoIcon :Tween = null
var twError :Tween = null

func _ready():
	Global.main = self

func _process(delta):
	$preview.visible = Input.is_action_pressed("right_click")
	if Input.is_action_pressed("right_click"):
		$preview.position = get_global_mouse_position()
	if Input.is_action_just_released("right_click"):
		createNewSliceable(file,get_global_mouse_position())
	if Input.is_action_just_pressed("reset"):
		for i in sliceContainer.get_children():
			i.queue_free()
	
	if Input.is_action_just_pressed("toggleUI"):
		$UILeft.visible = !$UILeft.visible
		$UIRight.visible = $UILeft.visible


## on image import ##
func _on_file_dialog_file_selected(path):
	
	var image :Image= Image.new()
	var err = image.load(path)
	if err != OK:
		# Failed, insert failure here
		runMessage("Error!: " + error_string(err))
		return
	var tex :ImageTexture = ImageTexture.new()
	var newTexture :Texture2D = tex.create_from_image(image)
	
	runMessage( path.right(3) + " loaded: " + path)
	
	if bgorobj:
		texSliceable = newTexture
		$preview.texture = texSliceable
		$UILeft/preview.texture = texSliceable
		var prevScale = max(newTexture.get_size().x,newTexture.get_size().y)
		$UILeft/preview.scale = Vector2(1,1) * (28.0/prevScale)
		
		file = path.right(3)
	else:
		$background.texture = newTexture
		$background.position.y = (newTexture.get_size().y * -0.5) -15

## Resize box collisions ##
func _notification(what):
	if what == 30:
		
		var poly = PackedVector2Array()
		var windowSize = get_window().get_size()
		var thick = -16
		
		cam.position = Vector2( 0 , -(windowSize.y / 2) )
		
		#create poly
		poly.append( Vector2i.ZERO )                    ######           ######
		poly.append( Vector2i(0,windowSize.y) )         ##   #           #   ##
		poly.append( windowSize )                       ##   #############   ##
		poly.append( Vector2i(windowSize.x,0) )         ##                   ##
														#######################
		poly.append( Vector2(windowSize.x + thick,0) )
		poly.append( windowSize + Vector2i(thick,thick) )
		poly.append( Vector2i(-thick,windowSize.y + thick) )  
		poly.append( Vector2i(-thick,0) )
		
		wallCollider.position = Vector2( -(windowSize.x/2),-windowSize.y)
		wallCollider.polygon = poly #assign poly
		
		$UILeft.position = cam.position - (Vector2(windowSize.x,windowSize.y)/2)
		$UIRight.position = cam.position + (Vector2(windowSize.x,-windowSize.y)/2)
		
		previousWindowSize = windowSize

func createNewSliceable(fileformat : String,pos : Vector2):
	if texSliceable == null:
		return
	var new = sliceableScene.instantiate()
	new.texture = texSliceable
	new.interiorTexture = texSliceable
	new.position = pos#Vector2( 0, previousWindowSize.y * -0.5 )
	new.fileformat = fileformat
	sliceContainer.add_child(new)

func reorganizeCollider():
	if $Collider.get_index() == 0:
		move_child($Collider, 1 )
	else:
		move_child($Collider, 0 )


func _on_obj_pressed():
	$FileDialog.visible = true
	$FileDialog.title = "Choose Object Sprite"
	$UILeft/Panel.visible = false
	bgorobj = true


func _on_bg_pressed():
	$FileDialog.visible = true
	$FileDialog.title = "Choose Background"
	$UILeft/Panel.visible = false
	bgorobj = false


func _on_color_picker_color_changed(color):
	$"BACKGROUND COLOR".color = color
	$UILeft/colorChange/balls/ColorIconChange.modulate = color
	

func _on_color_change_pressed():
	$UILeft/Panel.visible = !$UILeft/Panel.visible
	$UILeft/colorChange/balls.scale = Vector2(0.1,0.1)
	if is_instance_valid(twColor):
		twColor.stop()
	
	twColor = get_tree().create_tween()
	twColor.tween_property($UILeft/colorChange/balls,"scale",Vector2(1,1),1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)






func _on_info_button_pressed():
	$UIRight/Panel.visible = !$UIRight/Panel.visible
	if $UIRight/Panel.visible:
		$UIRight/Panel.scale = Vector2(0,0)
		if is_instance_valid(twInfo):
			twInfo.stop()
	
		twInfo = get_tree().create_tween()
		twInfo.tween_property($UIRight/Panel,"scale",Vector2(1,1),1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		$UIRight/Panel.scale = Vector2(0,0)
	
	$UIRight/Info.scale = Vector2(0.1,0.1)
	if is_instance_valid(twInfoIcon):
		twInfoIcon.stop()
	
	twInfoIcon = get_tree().create_tween()
	twInfoIcon.tween_property($UIRight/Info,"scale",Vector2(1,1),1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	

func _on_sound_toggle_pressed():
	$UILeft/soundToggle/Sound.scale = Vector2(0.1,0.1)
	if is_instance_valid(twSound):
		twSound.stop()
	
	twSound = get_tree().create_tween()
	twSound.tween_property($UILeft/soundToggle/Sound,"scale",Vector2(1,1),1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	Global.playSounds = !Global.playSounds
	$UILeft/soundToggle/Sound.frame = 1 - int(Global.playSounds)

func runMessage(string:String):
	$UIRight/error.text = string
	$UIRight/error.modulate.a = 1.0
	if is_instance_valid(twError):
		twError.stop()
	
	twError = get_tree().create_tween()
	twError.tween_property($UIRight/error,"modulate:a",0.0,5.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	


func _on_twit_pressed():
	OS.shell_open("https://x.com/kaiakairos")


func _on_kofi_pressed():
	OS.shell_open("https://ko-fi.com/kaiakairos")


func _on_ng_pressed():
	OS.shell_open("https://kaiakairos.newgrounds.com/")
