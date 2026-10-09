class_name MissionResource
extends Resource

enum MissionType { MAIN_STORY, SURVIVAL, BATTLE, RITUAL }

@export var mission_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var type: MissionType = MissionType.MAIN_STORY
@export var objective_coordinates: Vector3 = Vector3.ZERO
@export var murmuring_impact: float = -10.0
@export var required_characters: Array[StringName] = [&"Moses"]
@export var step_ids: PackedStringArray = PackedStringArray()
@export var goal_amount: int = 1
@export var sort_order: int = 0
@export var synergy: bool = false
