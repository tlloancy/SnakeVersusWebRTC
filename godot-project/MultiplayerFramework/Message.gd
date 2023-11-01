class_name Message

const SERVER_LOGIN = 1
const MATCH_START = 2
const IS_ECHO = 4
const DISCONNECTED_CLOSED = 8
const DISCONNECTED_DISCONNECTED = 16
const MATCH_SIZE = 32

const _BYTE_MASK = 255

var server_login : bool
var match_start : bool
var is_echo : bool
var disconnected_closed : bool
var disconnected_disconnected : bool
var match_size : int

var content

func get_raw() -> PackedByteArray:
	var message = PackedByteArray()

	var byte = 0
	byte = set_bit(byte, SERVER_LOGIN, server_login)
	byte = set_bit(byte, IS_ECHO, is_echo)
	byte = set_bit(byte, MATCH_START, match_start)
	byte = set_bit(byte, DISCONNECTED_CLOSED, disconnected_closed)
	byte = set_bit(byte, DISCONNECTED_DISCONNECTED, disconnected_disconnected)
	byte = set_bit(byte, MATCH_SIZE, match_size)

	message.append(byte)
	message.append_array(var_to_bytes_with_objects(content))

	return message

func from_raw(arr : PackedByteArray):
	var flags = arr[0]

	server_login = get_bit(flags, SERVER_LOGIN)
	is_echo = get_bit(flags, IS_ECHO)
	match_start = get_bit(flags, MATCH_START)
	disconnected_closed = get_bit(flags, DISCONNECTED_CLOSED)
	disconnected_disconnected = get_bit(flags, DISCONNECTED_DISCONNECTED)
	match_size = get_bit(flags, MATCH_SIZE)

	content = null
	print("allo")
	if (arr.size() > 1):
		print("alloallo")
		content = bytes_to_var_with_objects(arr.slice(1, -1))
		print("alloalloallo")

func get_bit(byte : int, flag : int) -> bool:
	return byte & flag == flag

func set_bit(byte : int, flag : int, is_set : bool = true) -> int:
	if is_set:
		return byte | flag
	else:
		return byte & ~flag
