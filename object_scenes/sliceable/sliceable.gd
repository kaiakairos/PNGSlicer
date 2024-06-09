@tool
extends RigidBody2D

@onready var polygon2d = $Polygon2D
@onready var interior2d = $Interior
@onready var interior2d2 = $Interior2
@onready var interior2d3 = $Interior3
@onready var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

## Is object edible
@export var isFood : bool = true
## Texture that the object will have and will also generate the polygon from.
@export var texture : Texture = null:
	set(previewTexture):
		texture = previewTexture
		$Sprite2D.texture = previewTexture

## Texture of the "depth" effect. If null, it will only be the 'interior color'.
@export var interiorTexture : Texture
## Color of the depth effect. Will modulate interior texture if texture is given.
@export var interiorColor : Color = Color.WHITE
## Color of the slice particle effect.
@export var sliceColor : Color = Color.WHITE
## Water buoyancy of the object. 0 is completely unaffected by water.
@export var buoyancy :float = 0.4
## Is object frozen in place.
@export var isFrozen : bool = false:
	set(freezee):
		freeze = freezee
		isFrozen = freezee
## Frozen Point. If frozen point still inside object after slice, remain frozen.
var freezePoints = PackedVector2Array()
@export var freezePointGlobal : PackedVector2Array = PackedVector2Array():
	set(freezeP):
		freezePointGlobal = freezeP
		freezePoints = freezeP
@export var resetFreeze : bool = false:
	set(r):
		for p in range(freezePointGlobal.size()):
			freezePointGlobal[p] = position
@export var massMultiplier : float = 1.0


var collisionPolygon : CollisionPolygon2D


var area = 0
var freshObject = true

var mouseInArea = false

var radius = 32
var texOffset = Vector2.ZERO

var immediateForce = Vector2.ZERO
var immediateTorque = 0.0

var shouldMediate = true

var centroid = Vector2.ZERO

var reset_state = false
var moveVector: Vector2

var fileformat = "png"

var step = 0

var previousVelocity = Vector2.ZERO

func _ready():
	
	if Engine.is_editor_hint():
		return
	$Sprite2D.queue_free()
	if freshObject:
		## Sets polygon based on given texutre image
		## This is all setup for new objects created in editor
		var img: Image = texture.get_image()
		polygon2d.texture = texture
		if interiorTexture != null:
			interior2d.texture = interiorTexture
		interior2d.color = interiorColor
		
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(img)
		var polygons = bitmap.opaque_to_polygons(Rect2(Vector2(0, 0), bitmap.get_size()),1.0)
		var collider = CollisionPolygon2D.new()
		
		var newPoints = mediatePoints(polygons[step])
		
		# needs to create more of myself
		if polygons.size() != step + 1:
			var ins = load("res://object_scenes/sliceable/sliceable.tscn").instantiate()
			ins.step = step + 1
			ins.position = position
			ins.texture = texture
			ins.interiorTexture = interiorTexture
			get_parent().add_child(ins)
		
		centroid = Slice.origin_to_geometry(newPoints)
		position += (centroid - (Vector2(float(img.get_size().x),float(img.get_size().y))/2.0)).rotated(rotation)
		collider.polygon = newPoints
		mass = Slice.calculateArea(collider)*0.1*massMultiplier
		polygon2d.texture_offset = centroid
		interior2d.texture_offset = centroid
		texOffset = polygon2d.texture_offset
		
		add_child(collider)
		collisionPolygon = collider
		area = calculateArea(collisionPolygon)
		polygon2d.polygon = newPoints
		interior2d.polygon = newPoints
		
		for p in freezePoints:
			var spr = Sprite2D.new()
			spr.texture = load("res://object_scenes/sliceable/frozenPoint.png")
			spr.position = to_local(p)
			add_child(spr)
		
		
	else:
		## If object is created by slice, this code will run instead.
		
		polygon2d.texture = texture
		polygon2d.texture_offset = texOffset
		
		if interiorTexture != null:
			interior2d.texture = interiorTexture
		interior2d.color = interiorColor
		interior2d.texture_offset = texOffset
		
	setAdditionalInteriors()
	
func fixPolygon():
	collisionPolygon.polygon = mediatePoints(collisionPolygon.polygon)
	polygon2d.polygon = collisionPolygon.polygon
	interior2d.polygon = collisionPolygon.polygon
	
	if isFrozen:
		var hasAtLeastOnePoint = false
		for p in freezePoints:
			if Geometry2D.is_point_in_polygon(to_local(p),collisionPolygon.polygon):
				freeze = true
				hasAtLeastOnePoint = true
				var spr = Sprite2D.new()
				spr.texture = load("res://object_scenes/sliceable/frozenPoint.png")
				spr.position = to_local(p)
				add_child(spr)
		if !hasAtLeastOnePoint:
			freeze = false
			
			
			
	setAdditionalInteriors()

## 'Mediates' polygon points. Points that are close are averaged together.
func mediatePoints(points):
	
	var groupDict = {}
	var invalidatedPoints = []
	
	var groupNo = 0
	
	## Segregates points into groups based on distance
	for point in points:
		if invalidatedPoints.has(point):
			continue
		groupDict[groupNo] = [point]
		for otherPoint in points:
			if otherPoint != point:
				var dis = abs((point - otherPoint).length())
				if dis < 5:
					groupDict[groupNo].append(otherPoint)
					invalidatedPoints.append(otherPoint)
		groupNo += 1
	
	## Observes point groups and adds them back into a new point set
	var newPoints = PackedVector2Array()
	for group in range(groupNo):
		var average = Vector2.ZERO
		var id = 0.0
		for point in groupDict[group]:
			average += point
			id += 1.0
		
		newPoints.append((average/id))
	
	## Finds longest point for object radius.
	var longest = 32
	for point in newPoints:
		if point.length() > longest:
			longest = point.length()
	radius = longest
	
	## Deletes rigidbody if points are less than 3.
	if newPoints.size() <= 2:
		queue_free()
	
	return newPoints
	

func _process(delta):
	
	if Engine.is_editor_hint():
		return
	

	if is_instance_valid(Slice.mouseSlicer):
		## If rigid body within slicer circumference, add to slice pool
		var mouseDistance = (global_position - Slice.mouseSlicer.globalCenter).length()
		if Input.is_action_pressed("left_click") and mouseDistance < Slice.mouseSlicer.size + radius:
			Slice.mouseSlicer.addRigidBody(self)
	
	## Rotates rigidbody's shadow/depth effect
	var yeah :Vector2 = Vector2(0,0)
	interior2d.position = yeah.normalized().rotated(-rotation)
	interior2d2.position = yeah.normalized().rotated(-rotation) * 2
	interior2d3.position = yeah.normalized().rotated(-rotation) * 3
	
	## Deletes rigidbody if it falls off screen
	
	if reset_state:
		return
	if position.y > get_window().get_size().y + radius:
		queue_free()
		
	if abs(position.x) > get_window().get_size().x / 2:
		queue_free()
	
func _physics_process(delta):
	
	if Engine.is_editor_hint():
		return
	
	## Matches velocities with original rigidbody
	if immediateForce != Vector2.ZERO:
		apply_central_impulse(immediateForce* mass)
		immediateForce = Vector2.ZERO
	
	if immediateTorque != 0.0:
		apply_torque_impulse(immediateTorque * inertia)
		immediateTorque = 0.0
	
	previousVelocity = linear_velocity

func calculateArea(shape):
	var ar = shape.get_polygon()
	var total = 0
	for id in ar.size():
		if id < ar.size()-1:
			total += (ar[id].x*ar[id+1].y)-(ar[id].y*ar[id+1].x)
		else:
			total += (ar[id].x*ar[0].y)-(ar[id].y*ar[0].x)
	
	return abs(total/2.0)

func setAdditionalInteriors():
	$Interior2.polygon = $Interior.polygon
	$Interior3.polygon = $Interior.polygon
	
	$Interior2.texture = $Interior.texture
	$Interior3.texture = $Interior.texture
	
	$Interior2.texture_offset = $Interior.texture_offset
	$Interior3.texture_offset = $Interior.texture_offset
	
	$Interior2.color = $Interior.color
	$Interior3.color = $Interior.color

func _integrate_forces(state):
	if reset_state:
		state.transform = Transform2D( state.transform.get_rotation() , moveVector)
		reset_state = false

func move_body(targetPos: Vector2):
	moveVector = targetPos;
	reset_state = true;


func _on_body_entered(body):
	
	if mass < 400.0:
		return
	
	var vel = previousVelocity.length()
	if body is RigidBody2D:
		vel = (previousVelocity.length() + body.previousVelocity.length())/2.0
	
	var vol = min(1.0,vel / 1400.0)
	var pitch = clamp(vel / 2000.0,0.8,1.2)
	
	if vol < 0.1:
		return
	
	Sound.playSound("bump",linear_to_db(vol),-pitch+2,global_position)
