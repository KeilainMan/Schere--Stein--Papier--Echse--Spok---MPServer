extends Node


var network: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
const PORT: int = 3434
const MAX_PLAYERS: int = 2



var all_player_info: Array = []

#var all_player_ids = []
#var player_1 
#var player_2 
#var player_names ={}
#var game_start_player_ready=[]
#var player_choices = {}

var current_game_state: int = game_state.WAITING_FOR_2_PLAYERS_TO_CONNECT
enum game_state {
	WAITING_FOR_2_PLAYERS_TO_CONNECT,
	WAITING_FOR_2_PLAYER_TO_START_THE_GAME,
	IN_ROUND,
	GAME_FINISHED
}

var current_in_round_game_state: int = in_round_game_state.WAITING_FOR_2_PLAYERS_TO_CHOOSE
enum in_round_game_state {
	WAITING_FOR_2_PLAYERS_TO_CHOOSE,
	WAITING_FOR_2_PLAYER_TO_START_NEXT_ROUND,
}

func _ready():
	start_server()


func start_server() -> void:
	network.create_server(PORT, MAX_PLAYERS)
	get_tree().set_network_peer(network)
	network.connect("peer_connected", self, "_peer_connected")
	network.connect("peer_disconnected", self, "_peer_disconnected")
	print("Server started")


################################################################################
## SERVER ##

func _peer_connected(player_id: int):
	print("User " + str(player_id) + " Connected")
	var player_info: Dictionary = generate_player_information(player_id)
	add_player_information(player_info)


func _peer_disconnected(player_id: int):
	var player_info_index: int = find_player_info_index_by_rpc_id(player_id)
	remove_player_information(player_info_index)
	print("User " + str(player_id) + " Disconnected")
	
	if ready_player_count > 0:
		ready_player_count -= 1
		current_game_state = game_state.WAITING_FOR_2_PLAYERS_TO_CONNECT
		print("The game state was reset to WAITING FOR 2 PLAYERS TO CONNECT")

	if ready_player_count == 0:
		print("Server will reset!")
		reset_server()


func reset_server() -> void:
	all_player_info.clear()
	current_game_state = game_state.WAITING_FOR_2_PLAYERS_TO_CONNECT
	current_in_round_game_state = in_round_game_state.WAITING_FOR_2_PLAYERS_TO_CHOOSE


func generate_player_information(player_id: int) -> Dictionary:
	var one_player_info: Dictionary ={
		"player_name": "",
		"player_node_id": 0,
		"rpc_id": 0,
		"player_is_ready": false,
		"current_choice": 0,
		}
	one_player_info["rpc_id"] = player_id
	return one_player_info


func add_player_information(player_info: Dictionary) -> void:
	all_player_info.append(player_info)
	print("Current Player Count: ", all_player_info.size(), " Current Player Information: ", player_info)


func remove_player_information(player_info_index: int) -> void:
	if player_info_index == 100:
		return
	var diconnected_player_info: Dictionary = all_player_info.pop_at(player_info_index)
	print("Current Player Count: ", all_player_info.size(), " Disconnected Player Information: ", diconnected_player_info)


################################################################################
## PLAYERINFORMATION UPON CONNECTION ##


remote func receive_player_name(player_name: String) -> void:
	var player_id: int = get_tree().get_rpc_sender_id()
	var player_info_index: int = find_player_info_index_by_rpc_id(player_id)
	all_player_info[player_info_index]["player_name"] = player_name
	print("Player Name Information for Player ", player_info_index + 1, " updated; Name; ", player_name)


remote func receive_player_requester_id(id: int) -> void:
	var player_id: int = get_tree().get_rpc_sender_id()
	var player_info_index: int = find_player_info_index_by_rpc_id(player_id)
	all_player_info[player_info_index]["player_node_id"] = id
	print("Player Node ID Information for Player ", player_info_index + 1, " updated; ID; ", id)


################################################################################
## BOTH PLAYER CONNECTED ##


func exchange_player_names() -> void:
	rpc_id(all_player_info[0]["rpc_id"], "set_both_player_names", all_player_info[0]["player_name"], all_player_info[1]["player_name"], all_player_info[0]["player_node_id"])
	rpc_id(all_player_info[1]["rpc_id"], "set_both_player_names", all_player_info[1]["player_name"], all_player_info[0]["player_name"], all_player_info[1]["player_node_id"])
	
	print("Player names exchanged!")

################################################################################
## BOTH PLAYERS STARTED THE GAME ##


func start_game() -> void:
	rpc_id(all_player_info[0]["rpc_id"], "start_game", all_player_info[0]["player_node_id"])
	rpc_id(all_player_info[1]["rpc_id"], "start_game", all_player_info[1]["player_node_id"])
	
	game_finish_count = 0
	print("GAME STARTS!")


################################################################################
## GAMEPLAY, ONE ROUND ##

remote func collect_player_choice(choice: int) -> void:
	var player_id = get_tree().get_rpc_sender_id()
	var player_info_index: int = find_player_info_index_by_rpc_id(player_id)
	all_player_info[player_info_index]["current_choice"] = choice
	

func exchange_current_choices() -> void:
	rpc_id(all_player_info[0]["rpc_id"], "set_enemy_choice", all_player_info[1]["current_choice"], all_player_info[0]["player_node_id"])
	rpc_id(all_player_info[1]["rpc_id"], "set_enemy_choice", all_player_info[0]["current_choice"], all_player_info[1]["player_node_id"])


################################################################################
## GAME STATE ORGANIZER ##

var ready_player_count: int = 0


remote func notice_player_is_ready() -> void:
	ready_player_count += 1
	print("A player is ready and waiting. Count: ", ready_player_count)
	if ready_player_count == 2:
		proceed()


var game_finish_count: int = 0

remote func notice_game_is_finished() -> void:
	game_finish_count += 1
	if game_finish_count == 2:
		current_game_state = game_state.WAITING_FOR_2_PLAYER_TO_START_THE_GAME
		current_in_round_game_state = in_round_game_state.WAITING_FOR_2_PLAYERS_TO_CHOOSE


func reset_player_ready_count() -> void:
	ready_player_count = 0
	print("Player Ready Count was reset")


func proceed() -> void:
	match current_game_state:
		game_state.WAITING_FOR_2_PLAYERS_TO_CONNECT:
			exchange_player_names()
			current_game_state = game_state.WAITING_FOR_2_PLAYER_TO_START_THE_GAME
			reset_player_ready_count()
		game_state.WAITING_FOR_2_PLAYER_TO_START_THE_GAME:
			start_game()
			current_game_state = game_state.IN_ROUND
			reset_player_ready_count() 
		game_state.IN_ROUND:
			
			match current_in_round_game_state:
				in_round_game_state.WAITING_FOR_2_PLAYERS_TO_CHOOSE:
					#collect_all_players_choices()
					exchange_current_choices()
					current_in_round_game_state = in_round_game_state.WAITING_FOR_2_PLAYER_TO_START_NEXT_ROUND
					reset_player_ready_count() 
				in_round_game_state.WAITING_FOR_2_PLAYER_TO_START_NEXT_ROUND:
					all_player_info[0]["current_choice"] = 100
					all_player_info[1]["current_choice"] = 100
					start_game()
					current_in_round_game_state = in_round_game_state.WAITING_FOR_2_PLAYERS_TO_CHOOSE
					reset_player_ready_count()


################################################################################
## HELPER ##

func find_player_info_index_by_rpc_id(player_id: int) -> int:
	var return_index: int = 100
	for index in all_player_info.size():
		if all_player_info[index].get("rpc_id") == player_id:
			return_index = index
			return return_index
	return return_index
