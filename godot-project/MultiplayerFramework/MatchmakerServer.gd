extends Node

@export var match_size: int

const PORT = 9080
var _server = TCPServer.new()

var _connected_players = {}
var _match_queue = []

func _logger_coroutine():
	while(true):
		await get_tree().create_timer(3).timeout

		var p = ""
		for player in _connected_players.keys():
			p += str(player) + " "

		var m = ""
		for id in _match_queue:
			m += str(id) + " "

		printt("Connected:   " + p)
		printt("Match queue: " + m + "\n")

func _ready():
	print("Starting server...")

	var err = _server.listen(PORT)
	if err != OK:
		print("Unable to start server")
		set_process(false)

	_logger_coroutine()


func _connected(id, proto):
	print("hiiiiiihhooouu")
	print("Client %d connected with protocol: %s" % [id.get_instance_id(), proto])
	_connected_players[id] = [] # match queue
	_match_queue.append(id)

	var message = Message.new()
	message.server_login = true
	message.content = id
	id.put_data(message.get_raw())

func _match_size():
	pass

func create_new_match(spTCP):
	var new_match = []
	for i in range(match_size):
		new_match.append(_match_queue[i])

	for i in range(match_size):
		var message = Message.new()
		message.match_start = true
		message.content = new_match
		spTCP.put_data(message.get_raw())
		_match_queue.remove_at(0)

	for i in range(new_match.size()):
		_connected_players[new_match[i]] = new_match

func remove_player_from_connections(id):
	if _match_queue.has(id):
		_match_queue.erase(id)

	if _connected_players.has(id):
		if _connected_players[id] != null:
			_connected_players[id].erase(id)
		_connected_players.erase(id)

func _close_request(id, code, reason):
	print("Client %d disconnecting with code: %d, reason: %s" % [id.get_instance_id(), code, reason])

	var message = Message.new()
	message.disconnected_closed = true
	message.content = id

	for player_id in _connected_players[id]:
		if (player_id != id):
			id.put_data(message.get_raw())

	remove_player_from_connections(id)

func _disconnected(id, was_clean = false):
	print("Client %d disconnected, clean: %s" % [id.get_instance_id(), str(was_clean)])

	var message = Message.new()
	message.disconnected_disconnected = true
	message.content = id

	for player_id in _connected_players[id]:
		if (player_id != id):
			id.put_data(message.get_raw())
		
	remove_player_from_connections(id)

func _on_data(buf, id):
	var message = Message.new()
	print("j ai rentré quand meme!")
	print(buf)
	var res = id.get_data(buf)
	print(res)
	message.from_raw(res)
	print("un")
	for player_id in _connected_players[id]:
		print(id)
		if (player_id != id || (player_id == id && message.is_echo)):
			print(player_id)
			id.put_data(message.get_raw())
	print("quatro")

func _process(delta):
	if _server.is_connection_available():
		var spTCP = _server.take_connection()
		_connected(spTCP, "TCP")

	for _conn in _connected_players.keys():
		_conn.poll()
		var buf = 0
		var state = _conn.get_status()
		if state == StreamPeerTCP.STATUS_CONNECTED:
			while true:
				buf = _conn.get_available_bytes()
				if buf <= 0:
					break
				_on_data(buf, _conn)
		elif state == StreamPeerTCP.STATUS_CONNECTING:
			pass
		elif state == StreamPeerTCP.STATUS_NONE:
			_disconnected(_conn)
		else: # STATUS_ERROR
			_close_request(_conn, 00, "ERROR")
			pass

		if (_match_queue.size() >= match_size):
			create_new_match(_conn)
