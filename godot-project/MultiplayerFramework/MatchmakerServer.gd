extends Node

@export var match_size: int

const PORT = 9080
var _server = TCPServer.new()
var socket = WebSocketPeer.new()

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

	_server.connect("client_connected", Callable(self, "_connected"))
	_server.connect("client_disconnected", Callable(self, "_disconnected"))
	_server.connect("client_close_request", Callable(self, "_close_request"))
	_server.connect("data_received", Callable(self, "_on_data"))

	var err = _server.listen(PORT)
	if err != OK:
		print("Unable to start server")
		set_process(false)

	var spTCP = _server.take_connection()
	err = socket.accept_stream(spTCP)
	if err != OK:
		print("Server Fail !")
		set_process(false)

	_logger_coroutine()


func _connected(id, proto):
	print("Client %d connected with protocol: %s" % [id, proto])
	_connected_players[id] = [] # match queue
	_match_queue.append(id)

	var message = Message.new()
	message.server_login = true
	message.content = id
	socket.put_packet(message.get_raw())

func _match_size():
	pass

func create_new_match():
	var new_match = []
	for i in range(match_size):
		new_match.append(_match_queue[i])

	for i in range(match_size):
		var message = Message.new()
		message.match_start = true
		message.content = new_match
		socket.put_packet(message.get_raw())
		_match_queue.remove(0)

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
	print("Client %d disconnecting with code: %d, reason: %s" % [id, code, reason])

	var message = Message.new()
	message.disconnected_closed = true
	message.content = id

	for player_id in _connected_players[id]:
		if (player_id != id):
			socket.put_packet(message.get_raw())

	remove_player_from_connections(id)

func _disconnected(id, was_clean = false):
	print("Client %d disconnected, clean: %s" % [id, str(was_clean)])

	var message = Message.new()
	message.disconnected_disconnected = true
	message.content = id

	for player_id in _connected_players[id]:
		if (player_id != id):
			socket.put_packet(message.get_raw())
		
	remove_player_from_connections(id)

func _on_data(id):
	var message = Message.new()
	message.from_raw(socket.get_packet())

	for player_id in _connected_players[id]:
		if (player_id != id || (player_id == id && message.is_echo)):
			socket.put_packet(message.get_raw())

func _process(delta):
	socket.poll()
	var message = Message.new()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			print("Packet: ", socket.get_packet())
			message.from_raw(socket.get_packet())
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.
		message.content = 0
		message.disconnected_disconnected = true
		socket.put_packet(message.get_raw())
	else:
		pass

	if (_match_queue.size() >= match_size):
		create_new_match()
