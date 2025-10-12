extends Node

## Group Encryption Example
##
## This example demonstrates how to use Megolm for encrypted group messaging.
## Scenario: Alice creates a group and sends messages to Bob and Charlie.
##
## Steps:
## 1. Alice creates a group session (outbound)
## 2. Alice shares the session key with Bob and Charlie (via secure channel)
## 3. Bob and Charlie create inbound sessions from the session key
## 4. Alice sends encrypted messages to the group
## 5. All members decrypt the messages

func _ready():
	print("=== Godot-Vodozemac Group Encryption Example ===\n")

	# Step 1: Alice creates a group session
	print("Step 1: Alice creates a group session...")
	var alice_group = VodozemacGroupSession.new()
	if alice_group.initialize() != OK:
		push_error("Failed to create group session: " + alice_group.get_last_error())
		return

	var session_id = alice_group.get_session_id()
	var session_key = alice_group.get_session_key()
	print("✓ Group created")
	print("  Session ID: %s..." % session_id.substr(0, 20))
	print("  Session key: %s...\n" % session_key.substr(0, 30))

	# Step 2: Bob and Charlie join the group
	print("Step 2: Bob and Charlie join the group...")
	print("(In production, the session key would be sent via encrypted Olm channels)")

	var bob_session = VodozemacInboundGroupSession.new()
	if bob_session.initialize_from_session_key(session_key) != OK:
		push_error("Bob failed to join: " + bob_session.get_last_error())
		return

	var charlie_session = VodozemacInboundGroupSession.new()
	if charlie_session.initialize_from_session_key(session_key) != OK:
		push_error("Charlie failed to join: " + charlie_session.get_last_error())
		return

	print("✓ Bob joined the group")
	print("  Session ID: %s..." % bob_session.get_session_id().substr(0, 20))
	print("✓ Charlie joined the group")
	print("  Session ID: %s...\n" % charlie_session.get_session_id().substr(0, 20))

	# Verify session IDs match
	if bob_session.get_session_id() != session_id or charlie_session.get_session_id() != session_id:
		push_error("Session ID mismatch!")
		return

	# Step 3: Alice sends messages to the group
	print("Step 3: Alice sends messages to the group...\n")

	var messages = [
		"Welcome everyone! 👋",
		"This is a secure group chat.",
		"Your messages are encrypted end-to-end with Megolm.",
		"Only members with the session key can decrypt."
	]

	for msg in messages:
		# Alice encrypts
		var encrypted = alice_group.encrypt(msg)
		if not encrypted["success"]:
			push_error("Encryption failed: " + encrypted.get("error", "Unknown error"))
			continue

		var ciphertext = encrypted["ciphertext"]
		print("─────────────────────────────────────────────")
		print("Alice (index %d): \"%s\"" % [alice_group.get_message_index() - 1, msg])
		print("  Ciphertext: %s..." % ciphertext.substr(0, 50))

		# Bob decrypts
		var bob_decrypted = bob_session.decrypt(ciphertext)
		if bob_decrypted["success"]:
			print("  📩 Bob received (index %d): \"%s\"" % [
				bob_decrypted["message_index"],
				bob_decrypted["plaintext"]
			])
		else:
			push_error("Bob failed to decrypt: " + bob_decrypted.get("error", "Unknown error"))

		# Charlie decrypts
		var charlie_decrypted = charlie_session.decrypt(ciphertext)
		if charlie_decrypted["success"]:
			print("  📩 Charlie received (index %d): \"%s\"" % [
				charlie_decrypted["message_index"],
				charlie_decrypted["plaintext"]
			])
		else:
			push_error("Charlie failed to decrypt: " + charlie_decrypted.get("error", "Unknown error"))

		print("")

	print("─────────────────────────────────────────────")
	print("\n=== Example completed successfully! ===")

	print("\n📊 Statistics:")
	print("  Total messages sent: %d" % alice_group.get_message_index())
	print("  Bob's first known index: %d" % bob_session.get_first_known_index())
	print("  Charlie's first known index: %d" % charlie_session.get_first_known_index())

	print("\n💡 Key takeaways:")
	print("1. One sender can encrypt messages for multiple recipients efficiently")
	print("2. All recipients use the same session key from the sender")
	print("3. Message indices ensure ordering and prevent replay attacks")
	print("4. Session keys should be distributed securely (e.g., via Olm 1:1 sessions)")
	print("5. Megolm provides efficient group encryption but limited forward secrecy")
	print("6. Rotate session keys regularly for better security")

	# Step 4: Demonstrate session persistence
	print("\n─────────────────────────────────────────────")
	print("Step 4: Demonstrating session persistence...")

	var pickle_key = PackedByteArray()
	pickle_key.resize(32)
	for i in range(32):
		pickle_key[i] = randi() % 256

	# Save Alice's session
	var alice_pickle = alice_group.pickle(pickle_key)
	print("✓ Alice's session pickled (%d bytes)" % alice_pickle.length())

	# Restore Alice's session
	var alice_restored = VodozemacGroupSession.new()
	if alice_restored.from_pickle(alice_pickle, pickle_key) != OK:
		push_error("Failed to restore Alice's session")
		return

	print("✓ Alice's session restored")
	print("  Session ID matches: %s" % str(alice_restored.get_session_id() == session_id))
	print("  Message index: %d" % alice_restored.get_message_index())

	# Alice can continue sending from restored session
	var new_msg = alice_restored.encrypt("This is from the restored session!")
	var bob_decrypt_new = bob_session.decrypt(new_msg["ciphertext"])
	print("  📩 Bob received new message: \"%s\"" % bob_decrypt_new["plaintext"])

	print("\n✅ Session persistence works correctly!")
