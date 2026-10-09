class_name CampInteractable
extends Node3D


func _ready() -> void:
	add_to_group("interactable")


func can_use(_by: Node) -> bool:
	return true


func prompt_for(_by: Node) -> String:
	return "Interact"


func interact(_by: Node) -> bool:
	return false


func camp() -> CampSimulation:
	return get_tree().get_first_node_in_group("camp") as CampSimulation
