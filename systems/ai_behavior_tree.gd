class_name AIBehaviorTree
extends RefCounted
## Tiny selector used by companion leaders.
## The first leaf that handles the actor wins; otherwise they follow.

var root: BTNode


func tick(actor: Node, delta: float) -> void:
	if root:
		root.tick(actor, delta)


class BTNode:
	func tick(_actor: Node, _delta: float) -> bool:
		return false


class Selector:
	extends BTNode
	var children: Array = []

	func tick(actor: Node, delta: float) -> bool:
		for child in children:
			if child.tick(actor, delta):
				return true
		return false


class Leaf:
	extends BTNode
	var fn: Callable

	func _init(callback: Callable) -> void:
		fn = callback

	func tick(actor: Node, delta: float) -> bool:
		return bool(fn.call(actor, delta))
