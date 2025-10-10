extends Node

## Session Persistence Example
##
## This example demonstrates how to save (pickle) and restore (unpickle)
## both accounts and sessions for persistence across application restarts.
##
## Use cases:
## - Saving encrypted chat history
## - Maintaining long-lived encrypted connections
## - Application state preservation

func _ready():
	print("=== Godot-Vodozemac Session Persistence Example ===\n")

	# Simulate two application runs
	simulate_first_run()
	print("\n" + "=".repeat(60) + "\n")
	simulate_second_run()

## Simulates the first application run where we create accounts,
## establish a session, and save everything to disk (simulated)
func simulate_first_run():
	print(">>> FIRST RUN: Creating and saving accounts/sessions <<<\n")

	# Create accounts
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()
	alice.initialize()
	bob.initialize()

	print("Step 1: Accounts created")

	# Generate one-time keys for Bob
	bob.generate_one_time_keys(10)
	print("Step 2: Bob generated one-time keys")

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

	print("Step 3: Session established between Alice and Bob")

	# Exchange a few messages
	alice_session.encrypt("Message 1")
	alice_session.encrypt("Message 2")
	var msg3 = alice_session.encrypt("Message 3")
	bob_session.decrypt(msg3["message_type"], msg3["ciphertext"])

	print("Step 4: Exchanged 3 messages")

	# Now save everything using pickle
	print("\nStep 5: Pickling (saving) accounts and sessions...")

	# Create encryption keys (32 bytes each)
	# In a real app, these should be securely derived from a password
	# or stored in a secure keychain
	var account_key = create_encryption_key("account_key_secret")
	var session_key = create_encryption_key("session_key_secret")

	# Pickle accounts
	var alice_account_pickle = alice.pickle(account_key)
	var bob_account_pickle = bob.pickle(account_key)

	# Pickle sessions
	var alice_session_pickle = alice_session.pickle(session_key)
	var bob_session_pickle = bob_session.pickle(session_key)

	print("  ✓ Alice account pickle: %d bytes" % alice_account_pickle.length())
	print("  ✓ Bob account pickle: %d bytes" % bob_account_pickle.length())
	print("  ✓ Alice session pickle: %d bytes" % alice_session_pickle.length())
	print("  ✓ Bob session pickle: %d bytes" % bob_session_pickle.length())

	# In a real application, you would save these to files:
	# var file = FileAccess.open("user://alice_account.pickle", FileAccess.WRITE)
	# file.store_string(alice_account_pickle)
	# file.close()

	# For this example, we'll store them in temporary variables
	# that will be accessed in simulate_second_run()
	# In reality, this would be read from disk
	_temp_storage = {
		"alice_account": alice_account_pickle,
		"bob_account": bob_account_pickle,
		"alice_session": alice_session_pickle,
		"bob_session": bob_session_pickle,
		"account_key": account_key,
		"session_key": session_key
	}

	print("\n✓ All data saved (in real app, this would be written to disk)")

## Simulates the second application run where we load everything from disk
## and continue the conversation
func simulate_second_run():
	print(">>> SECOND RUN: Loading and restoring accounts/sessions <<<\n")

	# Retrieve saved data (simulating reading from disk)
	var stored_data = _temp_storage

	print("Step 1: Loading pickled data from 'disk'...")

	# Create new account instances
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()

	# Unpickle accounts
	var alice_result = alice.from_pickle(
		stored_data["alice_account"],
		stored_data["account_key"]
	)

	var bob_result = bob.from_pickle(
		stored_data["bob_account"],
		stored_data["account_key"]
	)

	if alice_result != OK:
		push_error("Failed to restore Alice's account: " + alice.get_last_error())
		return

	if bob_result != OK:
		push_error("Failed to restore Bob's account: " + bob.get_last_error())
		return

	print("  ✓ Alice account restored")
	print("  ✓ Bob account restored")

	# Verify identity keys are preserved
	var alice_identity = alice.get_identity_keys()
	var bob_identity = bob.get_identity_keys()

	print("\nStep 2: Verifying identity keys are preserved...")
	print("  Alice Ed25519: %s..." % alice_identity["ed25519"].substr(0, 20))
	print("  Bob Ed25519: %s..." % bob_identity["ed25519"].substr(0, 20))

	# Create new session instances
	var alice_session = VodozemacSession.new()
	var bob_session = VodozemacSession.new()

	# Unpickle sessions
	var alice_sess_result = alice_session.from_pickle(
		stored_data["alice_session"],
		stored_data["session_key"]
	)

	var bob_sess_result = bob_session.from_pickle(
		stored_data["bob_session"],
		stored_data["session_key"]
	)

	if alice_sess_result != OK:
		push_error("Failed to restore Alice's session: " + alice_session.get_last_error())
		return

	if bob_sess_result != OK:
		push_error("Failed to restore Bob's session: " + bob_session.get_last_error())
		return

	print("\nStep 3: Sessions restored")
	print("  Alice session ID: %s" % alice_session.get_session_id())
	print("  Bob session ID: %s" % bob_session.get_session_id())

	# Continue the conversation with restored sessions
	print("\nStep 4: Continuing conversation with restored sessions...")

	# Alice sends a new message
	var new_message = "This message was sent after restarting the application!"
	var encrypt_result = alice_session.encrypt(new_message)

	if not encrypt_result["success"]:
		push_error("Encryption failed after restore")
		return

	print("  Alice -> Bob: \"%s\"" % new_message)
	print("  Message type: %d (should be 1 - Normal message)" % encrypt_result["message_type"])

	# Bob decrypts it
	var decrypt_result = bob_session.decrypt(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	if not decrypt_result["success"]:
		push_error("Decryption failed after restore")
		return

	print("  Bob received: \"%s\"" % decrypt_result["plaintext"])

	# Bob replies
	var bob_reply = "Great! The session survived the restart."
	var bob_encrypt = bob_session.encrypt(bob_reply)
	print("\n  Bob -> Alice: \"%s\"" % bob_reply)

	var alice_decrypt = alice_session.decrypt(
		bob_encrypt["message_type"],
		bob_encrypt["ciphertext"]
	)

	print("  Alice received: \"%s\"" % alice_decrypt["plaintext"])

	print("\n=== Persistence example completed successfully! ===")
	print("\nKey takeaways:")
	print("1. Use pickle() to serialize accounts and sessions")
	print("2. Provide a 32-byte encryption key to protect pickled data")
	print("3. Save pickled strings to disk (e.g., FileAccess.open())")
	print("4. Use from_pickle() to restore state on next app run")
	print("5. Sessions remain fully functional after restoration")
	print("6. IMPORTANT: Store encryption keys securely!")

## Helper function to create a 32-byte encryption key from a seed string
func create_encryption_key(seed: String) -> PackedByteArray:
	var key = PackedByteArray()
	var hash = seed.sha256_text()

	# Convert hex string to bytes (take first 32 bytes)
	for i in range(32):
		var hex_pair = hash.substr(i * 2, 2)
		var byte_value = ("0x" + hex_pair).hex_to_int()
		key.append(byte_value)

	return key

# Temporary storage to simulate disk persistence
var _temp_storage: Dictionary = {}
