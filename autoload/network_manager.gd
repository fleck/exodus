extends Node
## ENet sessions for desktop and mobile. Web exports stay local:
## browsers in this build do not open the desktop socket.

const PORT := 7777
const MAX_PLAYERS := 4

var last_error: String = ""


func host_game() -> Error:
	close()
	if OS.has_feature("web"):
		last_error = "Online play uses a desktop or mobile build. This web build is local."
		return ERR_UNAVAILABLE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		last_error = error_string(err)
		return err
	multiplayer.multiplayer_peer = peer
	last_error = ""
	return OK


func join_game(address: String) -> Error:
	close()
	if OS.has_feature("web"):
		last_error = "Online play uses a desktop or mobile build. This web build is local."
		return ERR_UNAVAILABLE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		last_error = error_string(err)
		return err
	multiplayer.multiplayer_peer = peer
	last_error = ""
	return OK


func close() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func online() -> bool:
	return multiplayer.multiplayer_peer != null


func local_peer_id() -> int:
	if online():
		return multiplayer.get_unique_id()
	return 1


func has_authority(node: Node) -> bool:
	if not online():
		return true
	return node.is_multiplayer_authority()


func peer_total() -> int:
	if not online():
		return 1
	return 1 + multiplayer.get_peers().size()
