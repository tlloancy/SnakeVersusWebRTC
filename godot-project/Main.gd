extends Node

func _ready():
	randomize()
	get_tree().change_scene_to_file("res://Server/Server.tscn")
