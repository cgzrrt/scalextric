extends Node2D
class_name leveleditor

@export var level_name : String 
@onready var tile_map: TileMap = $TileMap

# var road_generator : BSPGenerator
var tile_size : float
var camera_tile_pos := Vector2i (0, 0)

func _ready() -> void:
	pass

func _input(event : InputEvent):
	if event.is_action_pressed("down"):
		move_camera(Vector2i(0, 1))
		print("down")
		pass
	if event.is_action_pressed("up"):
		move_camera(Vector2i(0, -1))
		print("up")
		pass
	if event.is_action_pressed("left"):
		move_camera(Vector2i(-1, 0))
		print("left")
		pass
	if event.is_action_pressed("right"):
		move_camera(Vector2i(1, 0))
		print("right")
		pass

func move_camera(v : Vector2i):
	camera_tile_pos += v
	$Camera2D.position = $Camera2D.position + Vector2(tile_map.tile_set.tile_size*v)
