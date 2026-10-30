extends SceneTree
## Bounded diagnostic run through the production client, protocol and memory.
## Only synthetic games; never opens normal saves or credential storage.
const Client = preload("res://scripts/ai/client.gd")
const Protocol = preload("res://scripts/ai/protocol.gd")
const Memory = preload("res://scripts/ai/memory.gd")
const Config = preload("res://scripts/ai/config.gd")
const Trace = preload("res://scripts/ai/trace_log.gd")
const Table = preload("res://scripts/poker/table.gd")
const Bot = preload("res://scripts/poker/local_bot.gd")
var client
var secret = ""
var service: Dictionary
var requests = 0
var maximum = 20
var table_limit = 20
var dry = false
var report = {"mode": "live", "max_requests": 20, "requests": 0, "decisions": [], "speech": [], "completed_hands": [], "exchanges": [], "errors": []}
var output = "res://.local/live-behavior.json"

func _initialize() -> void: call_deferred("run")

func save_report() -> void:
	report.requests = requests
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(Trace.redact(report, [secret]), "\t"))
		file.close()

func ask(messages: Array, context: Dictionary) -> Dictionary:
	client.send(service, secret, messages, mini(4, table_limit - requests), context)
	var result: Dictionary = await client.finished
	save_report()
	return result

func run() -> void:
	dry = "--dry-run" in OS.get_cmdline_user_args()
	if OS.has_environment("SOMNICARD_TEST_LIMIT"):
		maximum = clampi(int(OS.get_environment("SOMNICARD_TEST_LIMIT")), 1, 50)
	report.max_requests = maximum
	if OS.has_environment("SOMNICARD_TEST_REPORT"):
		output = "res://.local/" + OS.get_environment("SOMNICARD_TEST_REPORT").get_file()
	if dry:
		report.mode = "dry-run-no-provider"
		output = "res://.local/live-behavior-dry.json"
	secret = OS.get_environment("SOMNICARD_TEST_KEY")
	OS.unset_environment("SOMNICARD_TEST_KEY")
	service = Config.service({"endpoint": "https://api.commandcode.ai/provider/v1", "model": OS.get_environment("SOMNICARD_TEST_MODEL")})
	if not dry and (secret.is_empty() or Config.validate(service) != ""):
		printerr("LIVE_BEHAVIOR_REQUIRES_LOCAL_CREDENTIAL_INPUT")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute("res://.local")
	report.model = service.model
	client = Client.new()
	root.add_child(client)
	client.request_issued.connect(func(): requests += 1)
	client.exchange.connect(func(entry): report.exchanges.append(Trace.redact(entry, [secret])))
	var seat = Config.seats([])[0]
	seat.name = "澜寻"
	var profile = {"difficulty": 1, "aggression": 0}
	var table_index = 0
	for count in [2, 6, 9]:
		table_index += 1
		table_limit = int(maximum * table_index / 3.0)
		var stacks: Array = []
		var bots: Array = []
		for i in range(count):
			stacks.append(1000)
			bots.append(Bot.new(20261023 + i + count * 100, 0, 1))
		var table = Table.new(stacks, 5, 10, 20261023 + count)
		table.seats[1].name = seat.name
		var memory = Memory.normalize({})
		var talk: Array = []
		# Memory survives hands at one table, resets between table sessions.
		for hand in range(3 if dry else 12):
			if requests >= table_limit or table.start_hand() != "": break
			var spoken = false
			var steps = 0
			while table.phase != "complete" and requests < table_limit and steps < 160:
				steps += 1
				var actor: int = table.actor
				var view: Dictionary = table.view_for(actor)
				var decision: Dictionary
				if actor != 1 or dry:
					decision = bots[actor].choose(view)
				else:
					var messages = Protocol.messages(view, actor, seat, profile, memory)
					var reply = await ask(messages, {"purpose": "decision", "players": count, "hand": hand + 1, "phase": table.phase})
					decision = reply if reply.has("error") else Protocol.decision(reply.content, view.legal)
					report.decisions.append({"players": count, "hand": hand + 1, "input": messages, "reply": reply, "parsed": decision})
					if decision.has("error"):
						report.errors.append(decision.error)
						save_report()
						print("LIVE_BEHAVIOR_STOPPED requests=%d" % requests)
						quit(1)
						return
				var error: String = table.act(actor, decision.action, int(decision.get("amount", 0)))
				if error != "":
					report.errors.append(error)
					save_report()
					quit(1)
					return
				if not dry and actor == 1 and not spoken and table.phase != "complete" and requests < table_limit:
					spoken = true
					var messages = Protocol.messages(table.view_for(actor), actor, seat, profile, memory, true, talk)
					var reply = await ask(messages, {"purpose": "speech", "players": count, "hand": hand + 1, "phase": table.phase})
					var parsed = reply if reply.has("error") else Protocol.table_talk(reply.content, talk.map(func(line): return line.text))
					report.speech.append({"input": messages, "reply": reply, "parsed": parsed})
					if parsed.has("text"): talk.append({"name": seat.name, "text": parsed.text})
				await process_frame
			if table.phase == "complete":
				memory = Memory.observe(memory, table.view_for(1), 1, "diagnostic-%d-%d" % [count, hand + 1])
				report.completed_hands.append({"players": count, "hand": hand + 1, "memory": memory.duplicate(true), "result": table.result.duplicate(true)})
			save_report()
			print("BEHAVIOR_PROGRESS players=%d hand=%d requests=%d complete=%s" % [count, hand + 1, requests, table.phase == "complete"])
	report["status"] = "request_cap_reached" if requests >= maximum else "completed_schedule"
	report["usage"] = Client.usage
	save_report()
	secret = ""
	print("LIVE_BEHAVIOR_FINISHED requests=%d mode=%s" % [requests, report.mode])
	quit()
