extends Node

# TODO:
# add snapping to vertexes, handle the case where intersection point a or b is a vertex of the polygon
# handle lines and paths

signal cut_completed

var mouseSlicer = null

const THRESHOLD = 1

var current_state
var mouse_position = Vector2.ZERO

var newPolygonDeleter = []

var sliceable = preload("res://object_scenes/sliceable/sliceable.tscn")
var sliceParticle = preload("res://object_scenes/particle/slice_particle.tscn")

var whileMax : int = 120

func cut(point1,point2,polygonToCut):
	newPolygonDeleter = []
	if not is_instance_valid(polygonToCut):
		#Selected polygon instance is invalid
		return false
	
	if polygonToCut.get_parent().area <= 200:
		return false
	
	var scene_points = [point1,point2]
	
	# transform
	var polygon = get_polygon_data(polygonToCut)
	for i in polygon.size():
		polygon[i] = polygonToCut.get_global_transform() * polygon[i]
	
	# returns an array of clipped polylines
	var intersections : Array = Geometry2D.intersect_polyline_with_polygon(scene_points, polygon)
	
	if intersections.is_empty():
		#print("Cut didn't intersect the selected polygon")
		return false
	
	if (Geometry2D.is_point_in_polygon(scene_points.front(), polygon) or 
		Geometry2D.is_point_in_polygon(scene_points.back(), polygon)):
			#print("Invalid input: Both start and end point of the cut must lie outside the polygon")
			return false
	
	var polygons_to_check = []
	var polygons_to_check_for_next_iteration = [polygonToCut]
	
	
	for intersection_index in intersections.size():
		
		polygons_to_check = polygons_to_check_for_next_iteration
		polygons_to_check_for_next_iteration = []
		for current_polygon in polygons_to_check:
			var intersection = intersections[intersection_index]
			
			if intersection_index > 0:
				polygon = get_polygon_data(current_polygon)
				for i in polygon.size():
					polygon[i] = current_polygon.get_global_transform() * polygon[i]
				intersection = Geometry2D.intersect_polyline_with_polygon(intersection, polygon)
				assert(intersection.size() < 2)
				
				if intersection.is_empty():
					#print("Empty intersection, pushing polygon for next iteration")
					polygons_to_check_for_next_iteration.push_back(current_polygon)
					continue

				elif intersection.size() == 1:
					intersection = intersection.front()

			# check if the polyline is self-intersecating
			# I assume that adjacent segments of the polyline don't intersecate (possible only if they are superimposed)
			# TODO: disallow superimposed segments.
			var self_intersect = false
			for i in range(0, intersection.size() - 2, 1):
				for j in range(i + 2, intersection.size() - 1, 1):
					var res = Geometry2D.segment_intersects_segment(
						intersection[i], intersection[i+1],
						intersection[j], intersection[j+1])
					
					if res != null:
						self_intersect = true
		
			if self_intersect:
				#print("Cut does self-intersect inside the polygon!")
				return false
	
			var intersection_point_a = intersection[0]
			var intersection_point_b = intersection[intersection.size() - 1]

			var does_intersect = false
			var numba1 = true
			for extreme in [intersection_point_a, intersection_point_b]:
				if numba1:
					createParticle(extreme,polygonToCut.get_parent().sliceColor,extreme-point2)
					numba1 = false
				else:
					createParticle(extreme,polygonToCut.get_parent().sliceColor,extreme-point1)
				
				
				for i in polygon.size():
					var next_index = posmod(i + 1, polygon.size())

					var point_on_segment = Geometry2D.get_closest_point_to_segment(
						extreme,
						polygon[i], polygon[next_index])

					# check if the cut pass through the polygon vertices
					if (polygon[i].distance_to(extreme) < THRESHOLD or
						polygon[next_index].distance_to(extreme) < THRESHOLD):
						does_intersect = true

					elif point_on_segment.distance_to(extreme) < THRESHOLD:
						does_intersect = true
						polygon.insert(next_index, point_on_segment)
						break
					
					
			if not does_intersect:
				polygons_to_check_for_next_iteration.push_back(current_polygon)
				continue

			var intersection_point_a_index = 0
			var whileCount = 0
			
			while polygon[intersection_point_a_index].distance_to(intersection_point_a) > THRESHOLD:
				## I added this if it doesn't work delete it !
				intersection_point_a_index += 1
				if intersection_point_a_index >= polygon.size():
					print("broke loop!")
					break
				whileCount += 1
				if whileCount > polygon.size()+2:
					print("escaped loop!")
					polygonToCut.get_parent().queue_free()
					return false

			for step in [1, -1]:
				var polyslice = []

				var index = intersection_point_a_index
				var whileCount2 = 0
				while polygon[index].distance_to(intersection_point_b) > THRESHOLD:
					polyslice.append(polygon[index])
					index = posmod(index + step, polygon.size())
					whileCount2 += 1
					if whileCount2 > polygon.size()+2:
						print("escaped loop!")
						polygonToCut.get_parent().queue_free()
						return false
						
				polyslice.append(intersection_point_b)
				
				var internal_points_index = intersection.size() - 2
				var whileCount3 = 0
				while internal_points_index > 0:
					polyslice.append( intersection[internal_points_index])
					internal_points_index -= 1
					whileCount3 += 1
					if whileCount3 > polygon.size()+2:
						print("escaped loop!")
						polygonToCut.get_parent().queue_free()
						return false
				
				for i in polyslice.size():
					polyslice[i] = current_polygon.get_global_transform().inverse() * polyslice[i]
				
				polygons_to_check_for_next_iteration.push_back(create_new_polygon(current_polygon, polyslice))
			
			if current_polygon != polygonToCut:
				current_polygon.get_parent().free()

	var allNewPolygons = polygons_to_check_for_next_iteration
	var sizeTotal = 0
	var keptPolygons = []
	for shape in allNewPolygons:
		var size = shape.polygon.size()
		sizeTotal += size
		
		if size <= 2:
			shape.get_parent().queue_free()
		else:
			keptPolygons.append(shape)
	if sizeTotal > 2:
		polygonToCut.get_parent().queue_free()
	
	for shape in keptPolygons:
		if is_instance_valid(shape):
			if is_instance_valid(shape.get_parent()):
				shape.get_parent().fixPolygon()
	
	
	emit_signal("cut_completed")
	return true

func create_new_polygon(current_polygon, new_polygon_data):
	var centroid = origin_to_geometry(new_polygon_data)
	var parent = current_polygon.get_parent()
	var new_polygon
	
	var is_scene_instance = not current_polygon.scene_file_path.is_empty()
	if is_scene_instance:
		new_polygon = load( current_polygon.scene_file_path ).instantiate()
		new_polygon.global_position = current_polygon.global_position
	else:
		new_polygon = current_polygon.duplicate(true)

	set_polygon_data(new_polygon, new_polygon_data)

	var area = calculateArea(new_polygon)
	if area < 50 and area > 0:
		return new_polygon
	
	newPolygonDeleter.append(new_polygon)
	var newRigidBody = sliceable.instantiate()
	newRigidBody.freshObject = false
	
	var newMass = area*0.1*parent.massMultiplier
	if newMass <= 0:
		newMass = 1
	newRigidBody.mass = newMass
	newRigidBody.area = area
	newRigidBody.buoyancy = parent.buoyancy
	newRigidBody.isFood = parent.isFood
	newRigidBody.isFrozen = parent.isFrozen
	newRigidBody.centroid = centroid
	newRigidBody.freezePoints = parent.freezePoints
	newRigidBody.position = parent.position + centroid.rotated(parent.rotation)
	newRigidBody.rotation = parent.rotation
	newRigidBody.texture = parent.texture
	newRigidBody.sliceColor = parent.sliceColor
	newRigidBody.interiorTexture = parent.interiorTexture
	newRigidBody.interiorColor = parent.interiorColor
	newRigidBody.texOffset = parent.texOffset + centroid
	newRigidBody.immediateForce = parent.linear_velocity
	newRigidBody.immediateTorque = parent.angular_velocity
	newRigidBody.massMultiplier = parent.massMultiplier
	newRigidBody.add_child(new_polygon)
	newRigidBody.collisionPolygon = new_polygon
	#newRigidBody.fixPolygon()
	parent.get_parent().add_child(newRigidBody)

	
	
	#new_polygon.global_position += centroid.rotated(parent.rotation)

	return new_polygon

func createParticle(globPosition,color,direction):
	var ins = sliceParticle.instantiate()
	ins.colour = color
	ins.rotation = direction.angle()
	ins.global_position = globPosition
	add_child(ins)

############################### UTILS #####################################

func calculateArea(shape):
	var ar = shape.get_polygon()
	var total = 0
	for id in ar.size():
		if id < ar.size()-1:
			total += (ar[id].x*ar[id+1].y)-(ar[id].y*ar[id+1].x)
		else:
			total += (ar[id].x*ar[0].y)-(ar[id].y*ar[0].x)
	
	return abs(total/2.0)

static func is_node_class_one_of(node, classes):
	for c in classes:
		if node.is_class(c):
			return true
	return false


static func set_polygon_data(node, polygon_data):
	if node is NavigationRegion2D:
		var navigation_polygon = NavigationPolygon.new()
		navigation_polygon.add_outline(polygon_data)
		navigation_polygon.make_polygons_from_outlines()
		node.navigation_polygon = navigation_polygon
	else:
		node.polygon = polygon_data


static func get_polygon_data(node):
	if node is NavigationRegion2D:
		assert(node.navigation_polygon.get_outline_count() == 1, "we can only handle connected navigation polygon instances")
		return node.navigation_polygon.get_outline(0)
	
	return node.polygon


static func get_polygon_orientation(polygon):
	return 1 if Geometry2D.is_polygon_clockwise(polygon) else -1


static func origin_to_geometry(polygon_data):
	# centering resulting polygons origin to their geometry
	var centroid = Vector2.ZERO
	for i in polygon_data.size():
		centroid += polygon_data[i]

	centroid /= polygon_data.size()

	for i in polygon_data.size():
		polygon_data[i] -= centroid
	
	return centroid
	
func mediatePoints(points):
	var groupDict = {}
	var invalidatedPoints = []
	
	var groupNo = 0
	
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
	
	var newPoints = PackedVector2Array()
	for group in range(groupNo):
		var average = Vector2.ZERO
		var id = 0.0
		for point in groupDict[group]:
			average += point
			id += 1.0

		newPoints.append((average/id))
	
	return newPoints
	
###########################################################################
