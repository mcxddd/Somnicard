extends SceneTree
const Table = preload("res://scripts/poker/table.gd")
const Protocol = preload("res://scripts/ai/protocol.gd")
const Config = preload("res://scripts/ai/config.gd")
const Client = preload("res://scripts/ai/client.gd")
const Trace = preload("res://scripts/ai/trace_log.gd")
var secret = ""
var requests = 0
var results: Array = []
var output = "res://.local/behavior-cases.json"
func _initialize() -> void: call_deferred("run")

func river(own: Array, board: Array, wager: int) -> Dictionary:
	var taken = own + board
	var rest: Array = []
	for card in range(52):
		if card not in taken: rest.append(card)
	var deck = [own[0], rest.pop_front(), own[1], rest.pop_front(), rest.pop_front()]
	deck.append_array(board.slice(0, 3))
	deck.append(rest.pop_front()); deck.append(board[3])
	deck.append(rest.pop_front()); deck.append(board[4]); deck.append_array(rest)
	var table = Table.new([1000, 1000], 5, 10, 42)
	assert(table.start_hand(0, deck) == "")
	while table.phase != "river":
		assert(table.act(table.actor, "check" if table.legal_actions(table.actor).check else "call") == "")
	if wager > 0:
		assert(table.act(1, "check") == "")
		assert(table.act(0, "raise", wager) == "")
	assert(table.actor == 1)
	return table.view_for(1)

func cases() -> Array:
	var aa_deck: Array = [12, 0, 25, 1]
	for card in range(52):
		if card not in aa_deck: aa_deck.append(card)
	var aa = Table.new([80, 80], 5, 10, 42)
	assert(aa.start_hand(0, aa_deck) == "")
	assert(aa.act(0, "all_in") == "")
	var nine = Table.new([1000,1000,1000,1000,1000,1000,1000,1000,1000], 5, 10, 42)
	# Button 7 -> SB 8, BB 0, UTG 1. Fix only the deal, not the observed view.
	var deck: Array = range(52)
	var first = deck.find(5); var tmp = deck[2]; deck[2] = 5; deck[first] = tmp
	var second = deck.find(13); tmp = deck[11]; deck[11] = 13; deck[second] = tmp
	assert(nine.start_hand(7, deck) == "")
	assert(nine.actor == 1 and nine.seats[1].hole == [5,13])
	return [
		{"id": "private_royal_vs_jam", "view": river([12,11], [10,9,8,26,40], 990), "expected": ["call","all_in"]},
		{"id": "board_royal_split_vs_jam", "view": river([13,14], [12,11,10,9,8], 990), "expected": ["call","all_in"]},
		{"id": "AA_8bb_vs_jam", "view": aa.view_for(1), "expected": ["call","all_in"]},
		{"id": "72o_UTG_nine_handed", "view": nine.view_for(1), "expected": ["fold"]},
		{"id": "missed_draw_vs_5x_pot", "view": river([13,16], [1,2,24,33,36], 100), "expected": ["fold"]},
		{"id": "free_river_check", "view": river([13,16], [1,2,24,33,36], 0), "expected": ["check","raise","all_in"]}
	]

func save_result() -> void:
	var file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(Trace.redact({"requests":requests,"results":results},[secret]),"\t"))
	file.close()

func run() -> void:
	var list = cases()
	if "--dry-run" in OS.get_cmdline_user_args():
		print("BEHAVIOR_CASES_VALIDATED count=%d" % list.size())
		quit(); return
	secret = OS.get_environment("SOMNICARD_TEST_KEY")
	OS.unset_environment("SOMNICARD_TEST_KEY")
	if secret.is_empty(): quit(2); return
	output = "res://.local/" + OS.get_environment("SOMNICARD_TEST_REPORT").get_file()
	var client = Client.new()
	root.add_child(client)
	client.request_issued.connect(func(): requests += 1)
	var service = Config.service({"endpoint":"https://api.commandcode.ai/provider/v1","model":OS.get_environment("SOMNICARD_TEST_MODEL")})
	var seat = Config.seats([])[0]
	for item in list:
		var messages = Protocol.messages(item.view,1,seat,{"difficulty":1,"aggression":0},{})
		# Exactly one request per diagnostic position; no uncounted retries.
		client.send(service,secret,messages,1,{"purpose":"diagnostic","case":item.id})
		var reply: Dictionary = await client.finished
		var decision = reply if reply.has("error") else Protocol.decision(reply.content,item.view.legal)
		results.append({"case":item.id,"input":messages,"reply":reply,"decision":decision,"expected":item.expected,"matched":decision.get("action","") in item.expected})
		save_result()
		print("BEHAVIOR_CASE_DONE %s matched=%s" % [item.id, results[-1].matched])
	secret = ""
	quit()
