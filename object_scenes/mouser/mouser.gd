extends Node2D

@onready var line = $Line2D

var clickedPosition = Vector2.ZERO
var size = 0
var globalCenter = Vector2.ZERO

var collidedPolygons = []
var dragin = null

func _ready():
	Slice.mouseSlicer = self

func addRigidBody(body):
	if collidedPolygons.has(body):
		return
	collidedPolygons.append(body)


func _physics_process(delta):
	if Input.is_action_just_pressed("left_click"):
		clickedPosition = get_global_mouse_position()
		line.global_position = clickedPosition
		$Line2D.visible = true
		collidedPolygons = []
		
	if Input.is_action_pressed("left_click"):
		var poop = line.to_local(get_global_mouse_position())
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(poop)
		
		size = poop.length()
		globalCenter = clickedPosition + (poop*0.5)
		
	if Input.is_action_just_released("left_click"):
		var mousePos = get_global_mouse_position()
		
		var sliced = false
		for rigidBody in collidedPolygons:
			if !is_instance_valid(rigidBody):
				continue
			var i = Slice.cut(clickedPosition,mousePos,rigidBody.collisionPolygon)
			if i : sliced = true
		
		if sliced:
			Sound.playSound("slice",0.0,randf_range(0.8,1.2),get_global_mouse_position())
			#get_parent().onSlice()
		
		$Line2D.visible = false
		collidedPolygons = []
	

	if Input.is_action_pressed("drag"):
		if dragin == null:
			var bodies = $Area2D.get_overlapping_bodies()
			if bodies.size() > 0:
				dragin = bodies[0]
		else:
			drag(delta)
	if Input.is_action_just_released("drag"):
		dragin = null

func _process(delta):
	$Area2D.position = get_global_mouse_position()
	if Input.is_action_pressed("delete"):
		delete(delta)

func delete(delta):
	var bodies = $Area2D.get_overlapping_bodies()
	for b in bodies:
		b.queue_free()

func drag(delta):
	if !is_instance_valid(dragin):
		return
	dragin.apply_central_impulse((dragin.mass * 40.0) * dragin.get_local_mouse_position().rotated(dragin.rotation) * delta)
