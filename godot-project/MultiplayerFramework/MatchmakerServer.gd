extends Node

@export var match_size: int

const PORT = 9080
var _server = TCPServer.new()
var wsp : WebSocketPeer
var spTCP : StreamPeerTCP
var _connected_players = {}
var _connected_players_objects = {}
var _match_queue = []
var thread

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
	thread = Thread.new()
	thread.start(self._on_data.bind(null))

	_logger_coroutine()


func _connected(obj, id, proto):
	print("Client %d connected with protocol: %s" % [id, proto])
	_connected_players_objects[obj] = id
	_connected_players[id] = [] # match queue
	_match_queue.append(id)

	var message = Message.new()
	message.server_login = true
	message.content = id
	obj.put_packet(message.get_raw())

func _match_size():
	pass

func create_new_match(wsp):
	var new_match = []
	for i in range(match_size):
		new_match.append(_match_queue[i])

	for i in range(match_size):
		var message = Message.new()
		message.match_start = true
		message.content = new_match
		wsp.put_packet(message.get_raw())
		_match_queue.remove_at(0)

	for i in range(new_match.size()):
		_connected_players[new_match[i]] = new_match

func remove_player_from_connections(obj, id):
	if _match_queue.has(id):
		_match_queue.erase(id)

	if _connected_players_objects.has(obj):
		_connected_players_objects.erase(obj)

	if _connected_players.has(id):
		if _connected_players[id] != null:
			_connected_players[id].erase(id)
		_connected_players.erase(id)

func _close_request(obj, code, reason):
	print("Client %d disconnecting with code: %d, reason: %s" % [_connected_players_objects[obj], code, reason])

	var message = Message.new()
	message.disconnected_closed = true
	message.content = _connected_players_objects[obj]

	for player_id in _connected_players[_connected_players_objects[obj]]:
		if (player_id != _connected_players_objects[obj]):
			obj.put_packet(message.get_raw())

	remove_player_from_connections(obj, _connected_players_objects[obj])

func _disconnected(obj, was_clean = false):
	print("Client %d disconnected, clean: %s" % [_connected_players_objects[obj], str(was_clean)])

	var message = Message.new()
	message.disconnected_disconnected = true
	message.content = _connected_players_objects[obj]

	for player_id in _connected_players[_connected_players_objects[obj]]:
		if (player_id != _connected_players_objects[obj]):
			obj.put_packet(message.get_raw())
		
	remove_player_from_connections(obj, _connected_players_objects[obj])

func _on_data(obj):
	if !obj:
		return
	var message = Message.new()
	print("j ai rentré quand meme!")
	print(obj)
	var res = obj.get_packet()

	print(res)
	message.from_raw(res)
	print("un")
	for player_id in _connected_players[_connected_players_objects[obj]]:
		print(player_id)
		if (player_id != _connected_players_objects[obj] || (player_id == _connected_players_objects[obj] && message.is_echo)):
			print(player_id)
			obj.put_packet(message.get_raw())
	print("quatro")

func _process(delta):
	if _server.is_connection_available():
		spTCP = _server.take_connection()
		wsp = WebSocketPeer.new()
		wsp.accept_stream(spTCP)
		while wsp.get_ready_state() != 1:
			wsp.poll()
		var id = randi_range(2, 1 << 30)
		_connected(wsp, id, "TCP")

	for _conn in _connected_players_objects.keys():
		_conn.poll()
		var buf = 0
		var state = _conn.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while _conn.get_available_packet_count():
				print("looooo")
				print(_conn)
				_on_data(_conn)
			#while true:
			#	buf = _conn.get_available_bytes()
			#	if buf <= 0:
			#		break
			#	_on_data(buf, _conn)
		elif state == WebSocketPeer.STATE_CONNECTING:
			pass
		elif state == WebSocketPeer.STATE_CLOSING:
			_disconnected(_conn)
		else: # STATUS_CLOSE
			_close_request(_conn, 00, "CLOSE")
			pass

		if (_match_queue.size() >= match_size):
			create_new_match(_conn)
