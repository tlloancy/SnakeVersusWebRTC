class_name Message

const SERVER_LOGIN = 1
const MATCH_START = 2
const IS_ECHO = 4
const DISCONNECTED_CLOSED = 8
const DISCONNECTED_DISCONNECTED = 16

const _BYTE_MASK = 255

var server_login : bool
var match_start : bool
var is_echo : bool
var disconnected_closed : bool
var disconnected_disconnected : bool

var content

func get_raw() -> PoolByteArray:
	var message = PoolByteArray()
	
	var byte = 0
	byte = set_bit(byte, SERVER_LOGIN, server_login)
	byte = set_bit(byte, IS_ECHO, is_echo)
	byte = set_bit(byte, MATCH_START, match_start)
	byte = set_bit(byte, DISCONNECTED_CLOSED, disconnected_closed)
	byte = set_bit(byte, DISCONNECTED_DISCONNECTED, disconnected_disconnected)
	
	message.append(byte)
	message.append_array(var2bytes(content))
	
	return message

func from_raw(var arr : PoolByteArray):
	var flags = arr[0]
	
	server_login = get_bit(flags, SERVER_LOGIN)
	is_echo = get_bit(flags, IS_ECHO)
	match_start = get_bit(flags, MATCH_START)
	disconnected_closed = get_bit(flags, DISCONNECTED_CLOSED)
	disconnected_disconnected = get_bit(flags, DISCONNECTED_DISCONNECTED)
	
	content = null
	if (arr.size() > 1):
		content = bytes2var(arr.subarray(1, -1))

static func get_bit(var byte : int, var flag : int) -> bool:
	return byte & flag == flag

static func set_bit(var byte : int, var flag : int, var is_set : bool = true) -> int:
	if is_set:
		return byte | flag
	else:
		return byte & ~flag
