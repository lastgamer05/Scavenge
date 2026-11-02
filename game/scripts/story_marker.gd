class_name StoryMarker
extends Node2D
## An objective position shown by the HUD's edge markers, like an extraction point.

var title := ""
var kind := "objective"


func _ready() -> void:
	add_to_group("objectives")


func is_open(_game: Node) -> bool:
	return true
