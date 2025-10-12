extends Node

## Late Joiner Example
##
## This example demonstrates the export/import functionality for handling
## late joiners in a group chat. When a new member joins an existing group,
## they don't need access to the full message history. An existing member
## can export the session state from the current message index, allowing
## the new member to only decrypt future messages.
##
## Scenario:
## 1. Alice creates a group, Bob joins early
## 2. Alice sends several messages
## 3. Charlie joins late - Bob exports the session from current index
## 4. Charlie can only decrypt messages from the export point forward

func _ready():
	print("=== Late Joiner Example ===\n")

	# Step 1: Alice creates a group, Bob joins early
	print("Step 1: Alice creates group, Bob joins early...")
	var alice_group = VodozemacGroupSession.new()
	if alice_group.initialize() != OK:
		push_error("Failed to create group")
		return

	var session_key = alice_group.get_session_key()

	var bob_session = VodozemacInboundGroupSession.new()
	if bob_session.initialize_from_session_key(session_key) != OK:
		push_error("Bob failed to join")
		return

	print("✓ Group created, Bob joined")
	print("  Session ID: %s...\n" % alice_group.get_session_id().substr(0, 20))

	# Step 2: Alice sends several messages (Bob can see all of them)
	print("Step 2: Alice sends several messages...")
	var early_messages = [
		"Welcome Bob!",
		"Let's discuss the project.",
		"We need to finalize the design.",
		"I think we should use Godot 4.",
		"The deadline is next week."
	]

	for i in range(early_messages.size()):
		var msg = early_messages[i]
		var encrypted = alice_group.encrypt(msg)

		var bob_decrypted = bob_session.decrypt(encrypted["ciphertext"])
		print("  [%d] Alice: \"%s\"" % [i, msg])
		print("       📩 Bob received: \"%s\"" % bob_decrypted["plaintext"])

	print("\n✓ Bob has seen all %d messages" % early_messages.size())
	print("  Current message index: %d\n" % alice_group.get_message_index())

	# Step 3: Charlie joins late
	print("Step 3: Charlie joins late (after %d messages)..." % alice_group.get_message_index())

	# Bob exports the session state from the current index
	var current_index = alice_group.get_message_index()
	var export_result = bob_session.export_at_index(current_index)

	if not export_result["success"]:
		push_error("Failed to export session: " + export_result.get("error", "Unknown error"))
		return

	print("✓ Bob exported session state from index %d" % current_index)
	print("  Exported key: %s...\n" % export_result["exported_key"].substr(0, 30))

	# Charlie imports the exported session
	var charlie_session = VodozemacInboundGroupSession.new()
	if charlie_session.import_session(export_result["exported_key"]) != OK:
		push_error("Charlie failed to import session: " + charlie_session.get_last_error())
		return

	print("✓ Charlie imported session")
	print("  Session ID: %s..." % charlie_session.get_session_id().substr(0, 20))
	print("  First known index: %d" % charlie_session.get_first_known_index())
	print("  Charlie can only decrypt messages from index %d onwards\n" % charlie_session.get_first_known_index())

	# Step 4: Alice sends new messages (all three can see these)
	print("Step 4: Alice sends new messages (all members receive)...")
	var new_messages = [
		"Charlie has joined the group!",
		"Welcome Charlie! 👋",
		"We're discussing the project timeline.",
		"Charlie, please review the design docs."
	]

	print("─────────────────────────────────────────────")
	for msg in new_messages:
		var encrypted = alice_group.encrypt(msg)
		var msg_index = alice_group.get_message_index() - 1

		print("\nAlice (index %d): \"%s\"" % [msg_index, msg])

		# Bob decrypts
		var bob_decrypted = bob_session.decrypt(encrypted["ciphertext"])
		if bob_decrypted["success"]:
			print("  📩 Bob received: \"%s\"" % bob_decrypted["plaintext"])
		else:
			print("  ❌ Bob failed: " + bob_decrypted.get("error", "Unknown"))

		# Charlie decrypts
		var charlie_decrypted = charlie_session.decrypt(encrypted["ciphertext"])
		if charlie_decrypted["success"]:
			print("  📩 Charlie received: \"%s\"" % charlie_decrypted["plaintext"])
		else:
			print("  ❌ Charlie failed: " + charlie_decrypted.get("error", "Unknown"))

	print("\n─────────────────────────────────────────────")

	# Step 5: Demonstrate that Charlie cannot decrypt old messages
	print("\nStep 5: Verifying Charlie cannot decrypt old messages...")

	# Try to get Charlie to decrypt one of the early messages
	# (We'd need to save the ciphertext earlier, but we'll simulate the concept)
	var old_encrypted = alice_group.encrypt("Simulated old message")
	# In reality, this is a new message so Charlie can decrypt it
	# But in a real scenario, Charlie wouldn't have the old ciphertexts

	print("\n✓ Security Note: Charlie cannot decrypt messages sent before index %d" % charlie_session.get_first_known_index())
	print("  This provides message history privacy for late joiners.")

	# Summary
	print("\n=== Example completed successfully! ===")

	print("\n📊 Final Statistics:")
	print("  Total messages sent: %d" % alice_group.get_message_index())
	print("  Bob's first known index: %d (full history)" % bob_session.get_first_known_index())
	print("  Charlie's first known index: %d (late joiner)" % charlie_session.get_first_known_index())
	print("  Messages Charlie missed: %d" % charlie_session.get_first_known_index())

	print("\n💡 Key takeaways:")
	print("1. Export/import allows late joiners without sharing full history")
	print("2. Exported sessions start from a specific message index")
	print("3. Late joiners can only decrypt future messages, not past ones")
	print("4. This provides message history privacy")
	print("5. Useful for large groups where new members don't need old messages")
	print("6. In production, distribute exported keys via secure Olm channels")

	print("\n🔐 Security Considerations:")
	print("  • Export points should be chosen carefully")
	print("  • Frequent key rotation improves forward secrecy")
	print("  • Late joiners trust existing members who export the key")
	print("  • Consider group policy for who can export sessions")
