extends Control

## Demo Scene for Godot-Vodozemac Examples
##
## This scene provides a UI to run the example scripts and view their output.
## Since we can't easily capture print() output in Godot, this demo
## re-implements the examples inline with output going to the UI.

@onready var output_text: RichTextLabel = $MarginContainer/VBoxContainer/OutputPanel/ScrollContainer/OutputText
@onready var basic_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/BasicEncryptionButton
@onready var persistence_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/SessionPersistenceButton

func _ready():
	_append_output("[b]Welcome to Godot-Vodozemac Demo![/b]\n")
	_append_output("Click a button above to run an example.\n\n")

func _on_basic_encryption_button_pressed():
	_clear_output()
	_append_output("[b][color=cyan]Running Basic Encryption Example...[/color][/b]\n\n")
	_disable_buttons()
	await get_tree().process_frame
	_run_basic_encryption_example()
	_enable_buttons()

func _on_session_persistence_button_pressed():
	_clear_output()
	_append_output("[b][color=cyan]Running Session Persistence Example...[/color][/b]\n\n")
	_disable_buttons()
	await get_tree().process_frame
	_run_session_persistence_example()
	_enable_buttons()

func _on_clear_button_pressed():
	_clear_output()
	_append_output("[b]Output cleared.[/b]\n")
	_append_output("Click a button above to run an example.\n\n")

func _clear_output():
	output_text.clear()

func _append_output(text: String):
	output_text.append_text(text)

func _append_error(text: String):
	_append_output("[color=red]ERROR: " + text + "[/color]\n")

func _disable_buttons():
	basic_button.disabled = true
	persistence_button.disabled = true

func _enable_buttons():
	basic_button.disabled = false
	persistence_button.disabled = false

## Basic Encryption Example Implementation
func _run_basic_encryption_example():
	_append_output("=== Godot-Vodozemac Basic Encryption Example ===\n\n")

	# Step 1: Create accounts
	_append_output("Step 1: Creating accounts for Alice and Bob...\n")
	var alice_account = VodozemacAccount.new()
	var bob_account = VodozemacAccount.new()

	if alice_account.initialize() != OK:
		_append_error("Failed to initialize Alice's account: " + alice_account.get_last_error())
		return

	if bob_account.initialize() != OK:
		_append_error("Failed to initialize Bob's account: " + bob_account.get_last_error())
		return

	_append_output("✓ Accounts created successfully\n\n")

	# Step 2: Get identity keys
	_append_output("Step 2: Retrieving identity keys...\n")
	var alice_identity = alice_account.get_identity_keys()
	var bob_identity = bob_account.get_identity_keys()

	_append_output("Alice's Ed25519 key: %s...\n" % alice_identity["ed25519"].substr(0, 20))
	_append_output("Alice's Curve25519 key: %s...\n" % alice_identity["curve25519"].substr(0, 20))
	_append_output("Bob's Ed25519 key: %s...\n" % bob_identity["ed25519"].substr(0, 20))
	_append_output("Bob's Curve25519 key: %s...\n\n" % bob_identity["curve25519"].substr(0, 20))

	# Step 3: Bob generates one-time keys
	_append_output("Step 3: Bob generating one-time keys...\n")
	if bob_account.generate_one_time_keys(5) != OK:
		_append_error("Failed to generate one-time keys: " + bob_account.get_last_error())
		return

	var bob_one_time_keys = bob_account.get_one_time_keys()
	_append_output("✓ Bob generated %d one-time keys\n" % bob_one_time_keys.size())

	var bob_otk = bob_one_time_keys.values()[0]
	_append_output("Using Bob's OTK: %s...\n\n" % bob_otk.substr(0, 20))

	# Step 4: Alice creates an outbound session to Bob
	_append_output("Step 4: Alice creating outbound session to Bob...\n")
	var alice_session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	if alice_session == null:
		_append_error("Failed to create outbound session: " + alice_account.get_last_error())
		return

	_append_output("✓ Outbound session created\n")
	_append_output("Session ID: %s\n\n" % alice_session.get_session_id())

	# Step 5: Alice encrypts a message
	_append_output("Step 5: Alice encrypting message...\n")
	var plaintext = "Hello Bob! This is a secure message from Alice."
	var encrypt_result = alice_session.encrypt(plaintext)

	if not encrypt_result["success"]:
		_append_error("Encryption failed: " + encrypt_result.get("error", "Unknown error"))
		return

	_append_output("✓ Message encrypted\n")
	_append_output("Message type: %d (0 = PreKey, 1 = Normal)\n" % encrypt_result["message_type"])
	_append_output("Ciphertext: %s...\n\n" % encrypt_result["ciphertext"].substr(0, 50))

	# Step 6: Bob creates an inbound session and decrypts
	_append_output("Step 6: Bob creating inbound session and decrypting...\n")
	var inbound_result = bob_account.create_inbound_session(
		alice_identity["curve25519"],
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	if not inbound_result["success"]:
		_append_error("Failed to create inbound session: " + inbound_result.get("error", "Unknown error"))
		return

	var bob_session = inbound_result["session"]
	var decrypted_text = inbound_result["plaintext"]

	_append_output("✓ Inbound session created\n")
	_append_output("Session ID: %s\n" % bob_session.get_session_id())
	_append_output("Decrypted message: \"%s\"\n\n" % decrypted_text)

	# Step 7: Bob marks the one-time key as used
	_append_output("Step 7: Bob marking one-time keys as published...\n")
	bob_account.mark_keys_as_published()
	_append_output("✓ One-time keys marked as published\n\n")

	# Step 8: Continue the conversation
	_append_output("Step 8: Continuing the conversation...\n")

	# Bob replies to Alice
	var bob_message = "Hi Alice! I received your message securely."
	var bob_encrypt = bob_session.encrypt(bob_message)

	if not bob_encrypt["success"]:
		_append_error("Bob's encryption failed")
		return

	_append_output("Bob -> Alice: \"%s\"\n" % bob_message)

	# Alice decrypts Bob's message
	var alice_decrypt = alice_session.decrypt(
		bob_encrypt["message_type"],
		bob_encrypt["ciphertext"]
	)

	if not alice_decrypt["success"]:
		_append_error("Alice's decryption failed")
		return

	_append_output("Alice received: \"%s\"\n" % alice_decrypt["plaintext"])

	# Alice sends another message
	var alice_message2 = "Great! Let's keep chatting securely."
	var alice_encrypt2 = alice_session.encrypt(alice_message2)

	_append_output("Alice -> Bob: \"%s\"\n" % alice_message2)

	# Bob decrypts Alice's second message
	var bob_decrypt2 = bob_session.decrypt(
		alice_encrypt2["message_type"],
		alice_encrypt2["ciphertext"]
	)

	_append_output("Bob received: \"%s\"\n\n" % bob_decrypt2["plaintext"])

	_append_output("[b][color=green]=== Example completed successfully! ===[/color][/b]\n\n")
	_append_output("[b]Key takeaways:[/b]\n")
	_append_output("1. Each party needs an Account with identity keys\n")
	_append_output("2. The receiver generates one-time keys for session establishment\n")
	_append_output("3. The sender creates an outbound session using receiver's keys\n")
	_append_output("4. The first message is a PreKey message (type 0)\n")
	_append_output("5. The receiver creates an inbound session from the PreKey message\n")
	_append_output("6. After that, both parties can exchange Normal messages (type 1)\n")

## Session Persistence Example Implementation
func _run_session_persistence_example():
	_append_output("=== Godot-Vodozemac Session Persistence Example ===\n\n")

	var temp_storage: Dictionary = {}

	# First run
	_append_output(">>> FIRST RUN: Creating and saving accounts/sessions <<<\n\n")

	# Create accounts
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()
	alice.initialize()
	bob.initialize()

	_append_output("Step 1: Accounts created\n")

	# Generate one-time keys for Bob
	bob.generate_one_time_keys(10)
	_append_output("Step 2: Bob generated one-time keys\n")

	# Establish session
	var bob_identity = bob.get_identity_keys()
	var bob_otk = bob.get_one_time_keys().values()[0]

	var alice_session = alice.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	# Exchange initial message
	var init_msg = alice_session.encrypt("Initial session establishment")
	var alice_identity = alice.get_identity_keys()

	var bob_inbound = bob.create_inbound_session(
		alice_identity["curve25519"],
		init_msg["message_type"],
		init_msg["ciphertext"]
	)
	var bob_session = bob_inbound["session"]

	_append_output("Step 3: Session established between Alice and Bob\n")

	# Exchange a few messages
	alice_session.encrypt("Message 1")
	alice_session.encrypt("Message 2")
	var msg3 = alice_session.encrypt("Message 3")
	bob_session.decrypt(msg3["message_type"], msg3["ciphertext"])

	_append_output("Step 4: Exchanged 3 messages\n")

	# Now save everything using pickle
	_append_output("\nStep 5: Pickling (saving) accounts and sessions...\n")

	var account_key = _create_encryption_key("account_key_secret")
	var session_key = _create_encryption_key("session_key_secret")

	# Pickle accounts
	var alice_account_pickle = alice.pickle(account_key)
	var bob_account_pickle = bob.pickle(account_key)

	# Pickle sessions
	var alice_session_pickle = alice_session.pickle(session_key)
	var bob_session_pickle = bob_session.pickle(session_key)

	_append_output("  ✓ Alice account pickle: %d bytes\n" % alice_account_pickle.length())
	_append_output("  ✓ Bob account pickle: %d bytes\n" % bob_account_pickle.length())
	_append_output("  ✓ Alice session pickle: %d bytes\n" % alice_session_pickle.length())
	_append_output("  ✓ Bob session pickle: %d bytes\n" % bob_session_pickle.length())

	temp_storage = {
		"alice_account": alice_account_pickle,
		"bob_account": bob_account_pickle,
		"alice_session": alice_session_pickle,
		"bob_session": bob_session_pickle,
		"account_key": account_key,
		"session_key": session_key
	}

	_append_output("\n✓ All data saved (in real app, this would be written to disk)\n")

	# Second run
	_append_output("\n" + "=".repeat(60) + "\n\n")
	_append_output(">>> SECOND RUN: Loading and restoring accounts/sessions <<<\n\n")

	_append_output("Step 1: Loading pickled data from 'disk'...\n")

	# Create new account instances
	var alice_restored = VodozemacAccount.new()
	var bob_restored = VodozemacAccount.new()

	# Unpickle accounts
	var alice_result = alice_restored.from_pickle(
		temp_storage["alice_account"],
		temp_storage["account_key"]
	)

	var bob_result = bob_restored.from_pickle(
		temp_storage["bob_account"],
		temp_storage["account_key"]
	)

	if alice_result != OK:
		_append_error("Failed to restore Alice's account: " + alice_restored.get_last_error())
		return

	if bob_result != OK:
		_append_error("Failed to restore Bob's account: " + bob_restored.get_last_error())
		return

	_append_output("  ✓ Alice account restored\n")
	_append_output("  ✓ Bob account restored\n")

	# Verify identity keys are preserved
	var alice_identity_restored = alice_restored.get_identity_keys()
	var bob_identity_restored = bob_restored.get_identity_keys()

	_append_output("\nStep 2: Verifying identity keys are preserved...\n")
	_append_output("  Alice Ed25519: %s...\n" % alice_identity_restored["ed25519"].substr(0, 20))
	_append_output("  Bob Ed25519: %s...\n" % bob_identity_restored["ed25519"].substr(0, 20))

	# Create new session instances
	var alice_session_restored = VodozemacSession.new()
	var bob_session_restored = VodozemacSession.new()

	# Unpickle sessions
	var alice_sess_result = alice_session_restored.from_pickle(
		temp_storage["alice_session"],
		temp_storage["session_key"]
	)

	var bob_sess_result = bob_session_restored.from_pickle(
		temp_storage["bob_session"],
		temp_storage["session_key"]
	)

	if alice_sess_result != OK:
		_append_error("Failed to restore Alice's session: " + alice_session_restored.get_last_error())
		return

	if bob_sess_result != OK:
		_append_error("Failed to restore Bob's session: " + bob_session_restored.get_last_error())
		return

	_append_output("\nStep 3: Sessions restored\n")
	_append_output("  Alice session ID: %s\n" % alice_session_restored.get_session_id())
	_append_output("  Bob session ID: %s\n" % bob_session_restored.get_session_id())

	# Continue the conversation with restored sessions
	_append_output("\nStep 4: Continuing conversation with restored sessions...\n")

	# Alice sends a new message
	var new_message = "This message was sent after restarting the application!"
	var encrypt_result = alice_session_restored.encrypt(new_message)

	if not encrypt_result["success"]:
		_append_error("Encryption failed after restore")
		return

	_append_output("  Alice -> Bob: \"%s\"\n" % new_message)
	_append_output("  Message type: %d (should be 1 - Normal message)\n" % encrypt_result["message_type"])

	# Bob decrypts it
	var decrypt_result = bob_session_restored.decrypt(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	if not decrypt_result["success"]:
		_append_error("Decryption failed after restore")
		return

	_append_output("  Bob received: \"%s\"\n" % decrypt_result["plaintext"])

	# Bob replies
	var bob_reply = "Great! The session survived the restart."
	var bob_encrypt_result = bob_session_restored.encrypt(bob_reply)
	_append_output("\n  Bob -> Alice: \"%s\"\n" % bob_reply)

	var alice_decrypt_result = alice_session_restored.decrypt(
		bob_encrypt_result["message_type"],
		bob_encrypt_result["ciphertext"]
	)

	_append_output("  Alice received: \"%s\"\n" % alice_decrypt_result["plaintext"])

	_append_output("\n[b][color=green]=== Persistence example completed successfully! ===[/color][/b]\n\n")
	_append_output("[b]Key takeaways:[/b]\n")
	_append_output("1. Use pickle() to serialize accounts and sessions\n")
	_append_output("2. Provide a 32-byte encryption key to protect pickled data\n")
	_append_output("3. Save pickled strings to disk (e.g., FileAccess.open())\n")
	_append_output("4. Use from_pickle() to restore state on next app run\n")
	_append_output("5. Sessions remain fully functional after restoration\n")
	_append_output("6. IMPORTANT: Store encryption keys securely!\n")

## Helper function to create a 32-byte encryption key from a seed string
func _create_encryption_key(seed: String) -> PackedByteArray:
	var key = PackedByteArray()
	var hash = seed.sha256_text()

	# Convert hex string to bytes (take first 32 bytes)
	for i in range(32):
		var hex_pair = hash.substr(i * 2, 2)
		var byte_value = ("0x" + hex_pair).hex_to_int()
		key.append(byte_value)

	return key
