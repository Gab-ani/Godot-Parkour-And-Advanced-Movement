extends Node3D
class_name AreaAwareness

var last_pushback_vector : Vector3

@export var shoulder_width : float = 0.5

@onready var space : PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

var on_floor_height : float = 1.2

@onready var model = $".." as PlayerModel
@onready var resources = $"../Resources" as HumanoidResources
@onready var states = $"../States" as HumanoidStates

var last_beam_fall : float = 0
var beam_cooldown : float = 0.2

var current_ledge : PackedVector3Array
var ledge_climbing_point : Vector3

var current_beam : PackedVector3Array

var last_wall_jump_normal : Vector3

var plane_1 : Vector3
var plane_2 : Vector3
var plane_3 : Vector3
var normal : Vector3

var start : Vector3
var end : Vector3 
var request : PhysicsRayQueryParameters3D
var results : Dictionary

func add_context(input : InputPackage):
	if search_for_thin_walkable_edge():
		input.input_actions.append("beam")
	if not is_on_floor():
		input.input_actions.append("midair")

# TODO probably refactor into some RaySlice usage?
func can_wall_jump() -> bool:
	var trigger : int = 0
	start = Vector3(0, 0.2, 0)
	end = Vector3(0, 0.2, 0.3)
	request = PhysicsRayQueryParameters3D.create(global_transform * start, global_transform * end, 2)
	results = space.intersect_ray(request)
	if not results.is_empty():
		trigger += 1
		last_wall_jump_normal = results["normal"]
	start = Vector3(0, 0.87, 0)
	end = Vector3(0, 0.87, 0.5)
	request = PhysicsRayQueryParameters3D.create(global_transform * start, global_transform * end, 2)
	results = space.intersect_ray(request)
	if not results.is_empty():
		trigger += 1
		last_wall_jump_normal = results["normal"]
	start = Vector3(0, 1.38, 0)
	end = Vector3(0, 1.38, 0.5)
	request = PhysicsRayQueryParameters3D.create(global_transform * start, global_transform * end, 2)
	results = space.intersect_ray(request)
	if not results.is_empty():
		trigger += 1
		last_wall_jump_normal = results["normal"]
	return trigger > 1


func is_on_floor() -> bool:
	#print(get_floor_distance())
	return get_floor_distance() <= on_floor_height

func get_floor_distance() -> float:
	start = global_position + Vector3(0, 1, 0)
	end = global_position + Vector3(0, -100, 0)
	request = PhysicsRayQueryParameters3D.create(start, end, 3, [model.player.get_rid()])
	results = space.intersect_ray(request)
	if not results.is_empty():
		#$test_marker.global_position = results["position"]
		return start.distance_to(results["position"])
	return 999999


# TODO the search probably must be started from character's legs, not from node's zero
func search_for_thin_walkable_edge() -> bool:
	start = global_position + Vector3(0, 1, 0)
	end = global_position + Vector3(0, -0.3, 0)
	request = PhysicsRayQueryParameters3D.create(start, end, 2)
	results = space.intersect_ray(request)
	if not results.is_empty():
		var collider = results["collider"]
		if collider is LocationElement:
			var edge = collider.has_thin_edge(results["normal"], global_transform * Vector3(0.1, 0, 0), global_transform * Vector3(-0.1, 0, 0), global_transform * Vector3(0, -0.2, 0))
			if not edge.is_empty():
				current_beam = edge
				return true
	return false


func search_for_climbable_edges(sensor : RaySlice) -> bool:
	var ray_slice_res = sensor.scan(global_transform, space)
	#$cringe/test_marker2.global_position = global_transform * (sensor.start)
	#$cringe/test_marker3.global_position = global_transform * (sensor.start + sensor.width)
	#$cringe/test_marker4.global_position = global_transform * (sensor.start + sensor.depth)
	if not ray_slice_res.is_empty():
		var collider = ray_slice_res["collider"]
		if collider is LocationElement:
			plane_1 = global_transform * sensor.start
			plane_2 = global_transform * (sensor.start + sensor.depth)
			plane_3 = global_transform * (sensor.start + sensor.width)
			normal = ray_slice_res["normal"]
			var edge : PackedVector3Array = collider.has_climbable_edge(normal, plane_1, plane_2, plane_3)
			if edge:
				var altitude : Vector3 = (global_position - edge[0]).project(edge[1] - edge[0]) + edge[0]
				$test_marker.global_position = altitude
				if altitude.distance_to(edge[0]) >= shoulder_width / 2 and altitude.distance_to(edge[1]) >= shoulder_width / 2 and (altitude - edge[0]).dot(altitude - edge[1]) < 0:
					current_ledge = edge
					ledge_climbing_point = altitude
					return true
	return false
