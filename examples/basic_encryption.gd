extends Node

## Basic Encryption Example
##
## This example demonstrates the basic usage of godot-vodozemac for
## end-to-end encryption between two parties (Alice and Bob).
##
## Steps:
## 1. Create accounts for both parties
## 2. Generate and exchange keys
## 3. Establish encrypted session
## 4. Exchange encrypted messages

func _ready():
	print("=== Godot-Vodozemac Basic Encryption Example ===\n")

	# Step 1: Create accounts
	print("Step 1: Creating accounts for Alice and Bob...")
	var alice_account = VodozemacAccount.new()
	var bob_account = VodozemacAccount.new()

	if alice_account.initialize() != OK:
		push_error("Failed to initialize Alice's account: " + alice_account.get_last_error())
		return

	if bob_account.initialize() != OK:
		push_error("Failed to initialize Bob's account: " + bob_account.get_last_error())
		return

	print("✓ Accounts created successfully\n")

	# Step 2: Get identity keys
	print("Step 2: Retrieving identity keys...")
	var alice_identity = alice_account.get_identity_keys()
	var bob_identity = bob_account.get_identity_keys()

	print("Alice's Ed25519 key: %s" % alice_identity["ed25519"].substr(0, 20) + "...")
	print("Alice's Curve25519 key: %s" % alice_identity["curve25519"].substr(0, 20) + "...")
	print("Bob's Ed25519 key: %s" % bob_identity["ed25519"].substr(0, 20) + "...")
	print("Bob's Curve25519 key: %s" % bob_identity["curve25519"].substr(0, 20) + "...\n")

	# Step 3: Bob generates one-time keys
	print("Step 3: Bob generating one-time keys...")
	if bob_account.generate_one_time_keys(5) != OK:
		push_error("Failed to generate one-time keys: " + bob_account.get_last_error())
		return

	var bob_one_time_keys = bob_account.get_one_time_keys()
	print("✓ Bob generated %d one-time keys" % bob_one_time_keys.size())

	# Get one of Bob's one-time keys for session establishment
	var bob_otk = bob_one_time_keys.values()[0]
	print("Using Bob's OTK: %s...\n" % bob_otk.substr(0, 20))

	# Step 4: Alice creates an outbound session to Bob
	print("Step 4: Alice creating outbound session to Bob...")
	var alice_session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	if alice_session == null:
		push_error("Failed to create outbound session: " + alice_account.get_last_error())
		return

	print("✓ Outbound session created")
	print("Session ID: %s\n" % alice_session.get_session_id())

	# Step 5: Alice encrypts a message
	print("Step 5: Alice encrypting message...")
	var plaintext = "Hello Bob! This is a secure message from Alice."
	var encrypt_result = alice_session.encrypt(plaintext)

	if not encrypt_result["success"]:
		push_error("Encryption failed: " + encrypt_result.get("error", "Unknown error"))
		return

	print("✓ Message encrypted")
	print("Message type: %d (0 = PreKey, 1 = Normal)" % encrypt_result["message_type"])
	print("Ciphertext: %s...\n" % encrypt_result["ciphertext"].substr(0, 50))

	# Step 6: Bob creates an inbound session and decrypts
	print("Step 6: Bob creating inbound session and decrypting...")
	var inbound_result = bob_account.create_inbound_session(
		alice_identity["curve25519"],
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	if not inbound_result["success"]:
		push_error("Failed to create inbound session: " + inbound_result.get("error", "Unknown error"))
		return

	var bob_session = inbound_result["session"]
	var decrypted_text = inbound_result["plaintext"]

	print("✓ Inbound session created")
	print("Session ID: %s" % bob_session.get_session_id())
	print("Decrypted message: \"%s\"\n" % decrypted_text)

	# Step 7: Bob marks the one-time key as used
	print("Step 7: Bob marking one-time keys as published...")
	bob_account.mark_keys_as_published()
	print("✓ One-time keys marked as published\n")

	# Step 8: Continue the conversation
	print("Step 8: Continuing the conversation...")

	# Bob replies to Alice
	var bob_message = "Hi Alice! I received your message securely."
	var bob_encrypt = bob_session.encrypt(bob_message)

	if not bob_encrypt["success"]:
		push_error("Bob's encryption failed")
		return

	print("Bob -> Alice: \"%s\"" % bob_message)

	# Alice decrypts Bob's message
	var alice_decrypt = alice_session.decrypt(
		bob_encrypt["message_type"],
		bob_encrypt["ciphertext"]
	)

	if not alice_decrypt["success"]:
		push_error("Alice's decryption failed")
		return

	print("Alice received: \"%s\"" % alice_decrypt["plaintext"])

	# Alice sends another message
	var alice_message2 = "Great! Let's keep chatting securely."
	var alice_encrypt2 = alice_session.encrypt(alice_message2)

	print("Alice -> Bob: \"%s\"" % alice_message2)

	# Bob decrypts Alice's second message
	var bob_decrypt2 = bob_session.decrypt(
		alice_encrypt2["message_type"],
		alice_encrypt2["ciphertext"]
	)

	print("Bob received: \"%s\"\n" % bob_decrypt2["plaintext"])

	print("=== Example completed successfully! ===")
	print("\nKey takeaways:")
	print("1. Each party needs an Account with identity keys")
	print("2. The receiver generates one-time keys for session establishment")
	print("3. The sender creates an outbound session using receiver's keys")
	print("4. The first message is a PreKey message (type 0)")
	print("5. The receiver creates an inbound session from the PreKey message")
	print("6. After that, both parties can exchange Normal messages (type 1)")
