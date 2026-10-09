extends Node
## Global signal router. Simulation, audio, and UI meet here
## and do not hold references to each other.

# Camp and morale
signal murmuring_changed(new_level: float)
signal riot_triggered(location: Vector3)
signal riot_ended
signal idolatry_started(location: Vector3)
signal idolatry_stopped
signal rebellion

# Missions
signal mission_started(mission: Resource)
signal mission_step_completed(mission_id: StringName, step_index: int)
signal mission_completed(mission_id: StringName)

# Resources
signal resource_updated(resource_type: StringName, amount: int)
signal manna_spoiled
signal manna_spawned(amount: int)
signal dawn_reached(day: int, manna_falls: bool)
signal day_advanced(day: int, is_sabbath_eve: bool)

# Characters
signal character_swapped(new_character_name: StringName)
signal control_changed

# World events
signal miracle_channeled(character_name: StringName, site_id: StringName)
signal water_purified(amount: int)
signal objective_event(step_id: StringName)
signal raid_started(enemy_count: int)
signal enemy_defeated(remaining: int)
signal world_flags_changed

signal game_over(reason: String)
signal victory(text: String)
signal notification(text: String)
signal peer_count_changed(peer_count: int)
