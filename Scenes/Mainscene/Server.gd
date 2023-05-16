extends Node


var network = NetworkedMultiplayerENet.new()
var port = 1909
var max_players = 2

var all_player_ids = []
var player_1 
var player_2 
var player_names ={}
var game_start_player_ready=[]
var player_choices = {}


func _ready():
	StartServer()
	
func StartServer():
	network.create_server(port, max_players)
	get_tree().set_network_peer(network)
	print("Server started")
	
	network.connect("peer_connected", self, "_Peer_Connected")
	network.connect("peer_disconnected", self, "_Peer_Disconnected")
	
func _Peer_Connected(player_id):
	print("User " + str(player_id) + " Connected")
	all_player_ids.append(player_id)
	readjust_players()
	
func _Peer_Disconnected(player_id):
	print("User " + str(player_id) + " Disconnected")
	all_player_ids.erase(player_id)
	readjust_players()
	
remote func GatherEnemyChoice(requester):
	var player_id = get_tree().get_rpc_sender_id()
	var enemychoice
	for ip in player_choices.keys():
		if !player_id == ip:
			enemychoice = player_choices.get(ip)
			player_choices.erase(ip)
	rpc_id(player_id, "ReturnEnemyChoice", enemychoice, requester)

remote func ReceivePlayerChoice(player_choice):
	var player_id = get_tree().get_rpc_sender_id()
	player_choices[player_id]=player_choice
	print(player_choices)
	if player_choices.size() == 2:
		TellEveryoneIsDone()
		
func TellEveryoneIsDone():
	rpc("ReturnEveryoneIsReady")
		
func readjust_players():
	if all_player_ids.size() ==2:
		player_1 = all_player_ids[0]
		player_2 = all_player_ids[1]
	elif all_player_ids.size() ==1:
		player_1 = all_player_ids[0]
	else:
		player_1 = null
		player_2 = null
	
remote func ReceivePlayerName(names):
	var player_id= get_tree().get_rpc_sender_id()
	player_names[player_id] = names
	print("namen " + str(player_names))

		
remote func TwoPlayerCheck():
	var player_id= get_tree().get_rpc_sender_id()
	if all_player_ids.size()==2:
		rpc_id(player_id, "ReturnTwoPlayers")
		
remote func PlayerReadyCheck():
	var player_id = get_tree().get_rpc_sender_id()
	game_start_player_ready.append(player_id)
	if game_start_player_ready.size() == 2:
		rpc("GameReady")
		game_start_player_ready.clear()
		
remote func SendPlayerNames(requester):
	var player_id = get_tree().get_rpc_sender_id()
	var name_player := ""
	var name_enemy := ""
	for i in player_names.keys():
		if i == player_id:
			name_player = player_names.get(i)
		else:
			name_enemy = player_names.get(i)
	rpc_id(player_id, "ReturnNames", name_player, name_enemy, requester)
	
