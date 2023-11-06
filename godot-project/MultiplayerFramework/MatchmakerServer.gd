extends Node

@export var match_size: int

const PORT = 9080
var _server = TCPServer.new()
var wsp : WebSocketPeer
var spTCP : StreamPeerTCP
var _connected_players = {}
var _connected_players_objects = {}
var _match_queue = []
signal on_data(obj)
var time_start = 0
var time_now = 0
var time_elapsed = 0
var WAIT_TIME = 3

func _logger_coroutine():
	while(true):
		await get_tree().create_timer(3).timeout

		var p = ""
		for player in _connected_players.keys():
			p += str(player) + " "

		var m = ""
		for id in _match_queue:
			m += str(id) + " "

		printt("[" + Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), true) + "]Connected:   " + p)
		printt("Match queue: " + m + "\n")

func _ready():
	print("Starting server...")

	var err = _server.listen(PORT)
	if err != OK:
		print("Unable to start server")
		set_process(false)
	self.connect("on_data", Callable(self, "_on_data"))
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

func create_new_match():
	var new_match = []
	for i in range(match_size):
		new_match.append(_match_queue[i])

	for i in range(match_size):
		var message = Message.new()
		message.match_start = true
		message.content = new_match
		_connected_players_objects.find_key(_match_queue[0]).put_packet(message.get_raw())
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

func _closed(obj, code, reason):
	print("Client %d closed with code: %d, reason: %s" % [_connected_players_objects[obj], code, reason])

	remove_player_from_connections(obj, _connected_players_objects[obj])

func _on_data(obj):
	var message = Message.new()
	var res = obj.get_packet()

	message.from_raw(res)
	for player_id in _connected_players[_connected_players_objects[obj]]:
		if (player_id != _connected_players_objects[obj] || (player_id == _connected_players_objects[obj] && message.is_echo)):
			_connected_players_objects.find_key(player_id).put_packet(message.get_raw())

func _process(delta):
	if _server.is_connection_available():
		spTCP = _server.take_connection()
		wsp = WebSocketPeer.new()
		var err = wsp.accept_stream(spTCP)
		if err != OK:
			print("connection attempts closed code %d" % [err])
			wsp.close(err)
		else:
			time_start = Time.get_unix_time_from_system()
			while wsp.get_ready_state() != 1:
				time_now = Time.get_unix_time_from_system()
				wsp.poll()
				time_elapsed = time_now - time_start
				if time_elapsed >= WAIT_TIME:
					break
			if wsp.get_ready_state() == 1:
				var id = randi_range(2, 1 << 30)
				_connected(wsp, id, "TCP")
			else:
				wsp.close(6300)
				print("Hand Shake Timeout")

	for _conn in _connected_players_objects.keys():
		_conn.poll()
		var buf = 0
		var state = _conn.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while _conn.get_available_packet_count() > 0 :
				emit_signal("on_data", _conn)
		elif state == WebSocketPeer.STATE_CONNECTING:
			pass
		elif state == WebSocketPeer.STATE_CLOSING:
			pass
		else: # STATUS_CLOSE
			_closed(_conn, _conn.get_close_code(), _conn.get_close_reason())
			pass

	if (_match_queue.size() >= match_size):
		create_new_match()
