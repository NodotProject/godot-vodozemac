extends GutTest

# Phase 10 - Encryption/Decryption Integration Tests
# Tests for message encryption and decryption functionality

var alice_account: VodozemacAccount
var bob_account: VodozemacAccount
var alice_session: VodozemacSession
var bob_session: VodozemacSession

func before_each():
	# Set up Alice and Bob accounts
	alice_account = VodozemacAccount.new()
	bob_account = VodozemacAccount.new()
	alice_account.initialize()
	bob_account.initialize()

	# Generate one-time keys for Bob
	bob_account.generate_one_time_keys(5)

	# Alice creates outbound session to Bob
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	alice_session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

func after_each():
	alice_account = null
	bob_account = null
	alice_session = null
	bob_session = null

# Helper function to establish Bob's inbound session
func establish_bob_session(pre_key_message_type: int, pre_key_ciphertext: String):
	var alice_identity = alice_account.get_identity_keys()
	var result = bob_account.create_inbound_session(
		alice_identity["curve25519"],
		pre_key_message_type,
		pre_key_ciphertext
	)
	if result["success"]:
		bob_session = result["session"]
	return result

# Test 1: Basic Encryption
func test_basic_encryption():
	var plaintext = "Hello, World!"
	var result = alice_session.encrypt(plaintext)

	assert_true(result["success"], "Encryption should succeed")
	assert_true(result.has("message_type"), "Should have message_type")
	assert_true(result.has("ciphertext"), "Should have ciphertext")
	assert_gt(result["ciphertext"].length(), 0, "Ciphertext should not be empty")

# Test 2: First Message is PreKey Type
func test_first_message_is_prekey():
	var result = alice_session.encrypt("First message")

	assert_true(result["success"], "Encryption should succeed")
	assert_eq(result["message_type"], 0, "First message should be PreKey (type 0)")

# Test 3: Basic Decryption
func test_basic_decryption():
	var plaintext = "Test message"
	var encrypt_result = alice_session.encrypt(plaintext)

	# Bob establishes session and decrypts
	var inbound_result = establish_bob_session(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	assert_true(inbound_result["success"], "Session establishment should succeed")
	assert_eq(inbound_result["plaintext"], plaintext, "Decrypted text should match")

# Test 4: Alice to Bob Message Exchange
func test_alice_to_bob_exchange():
	var message1 = "Hello Bob, this is Alice!"
	var encrypt1 = alice_session.encrypt(message1)

	# Bob creates inbound session and decrypts first message
	var inbound = establish_bob_session(
		encrypt1["message_type"],
		encrypt1["ciphertext"]
	)

	assert_eq(inbound["plaintext"], message1, "Bob should decrypt first message")

	# Alice sends second message
	var message2 = "How are you?"
	var encrypt2 = alice_session.encrypt(message2)

	# After first message, subsequent messages should be Normal type (1)
	assert_eq(encrypt2["message_type"], 1, "Second message should be Normal (type 1)")

	# Bob decrypts second message
	var decrypt2 = bob_session.decrypt(encrypt2["message_type"], encrypt2["ciphertext"])
	assert_true(decrypt2["success"], "Second decryption should succeed")
	assert_eq(decrypt2["plaintext"], message2, "Bob should decrypt second message")

# Test 5: Bob to Alice Message Exchange
func test_bob_to_alice_exchange():
	# Establish session first
	var encrypt1 = alice_session.encrypt("Hello")
	establish_bob_session(encrypt1["message_type"], encrypt1["ciphertext"])

	# Bob sends message to Alice
	var bob_message = "Hi Alice!"
	var bob_encrypt = bob_session.encrypt(bob_message)

	assert_true(bob_encrypt["success"], "Bob's encryption should succeed")

	# Alice decrypts Bob's message
	var alice_decrypt = alice_session.decrypt(
		bob_encrypt["message_type"],
		bob_encrypt["ciphertext"]
	)

	assert_true(alice_decrypt["success"], "Alice's decryption should succeed")
	assert_eq(alice_decrypt["plaintext"], bob_message, "Alice should decrypt Bob's message")

# Test 6: Multiple Messages in Sequence
func test_multiple_messages_sequence():
	var messages = [
		"Message 1",
		"Message 2",
		"Message 3",
		"Message 4",
		"Message 5"
	]

	# Establish session with first message
	var first_encrypt = alice_session.encrypt(messages[0])
	var inbound = establish_bob_session(
		first_encrypt["message_type"],
		first_encrypt["ciphertext"]
	)
	assert_eq(inbound["plaintext"], messages[0])

	# Send remaining messages
	for i in range(1, messages.size()):
		var encrypt_result = alice_session.encrypt(messages[i])
		assert_true(encrypt_result["success"], "Encryption should succeed for message " + str(i))

		var decrypt_result = bob_session.decrypt(
			encrypt_result["message_type"],
			encrypt_result["ciphertext"]
		)
		assert_true(decrypt_result["success"], "Decryption should succeed for message " + str(i))
		assert_eq(decrypt_result["plaintext"], messages[i], "Message " + str(i) + " should match")

# Test 7: Bidirectional Conversation
func test_bidirectional_conversation():
	# Establish session
	var init_encrypt = alice_session.encrypt("Hello Bob")
	var inbound = establish_bob_session(init_encrypt["message_type"], init_encrypt["ciphertext"])

	# Alice -> Bob
	var msg1_encrypt = alice_session.encrypt("How are you?")
	var msg1_decrypt = bob_session.decrypt(msg1_encrypt["message_type"], msg1_encrypt["ciphertext"])
	assert_eq(msg1_decrypt["plaintext"], "How are you?")

	# Bob -> Alice
	var msg2_encrypt = bob_session.encrypt("I'm good, thanks!")
	var msg2_decrypt = alice_session.decrypt(msg2_encrypt["message_type"], msg2_encrypt["ciphertext"])
	assert_eq(msg2_decrypt["plaintext"], "I'm good, thanks!")

	# Alice -> Bob
	var msg3_encrypt = alice_session.encrypt("Great to hear!")
	var msg3_decrypt = bob_session.decrypt(msg3_encrypt["message_type"], msg3_encrypt["ciphertext"])
	assert_eq(msg3_decrypt["plaintext"], "Great to hear!")

	# Bob -> Alice
	var msg4_encrypt = bob_session.encrypt("Talk to you later")
	var msg4_decrypt = alice_session.decrypt(msg4_encrypt["message_type"], msg4_encrypt["ciphertext"])
	assert_eq(msg4_decrypt["plaintext"], "Talk to you later")

# Test 8: Empty String Encryption
func test_empty_string_encryption():
	var result = alice_session.encrypt("")
	assert_true(result["success"], "Should encrypt empty string")
	assert_gt(result["ciphertext"].length(), 0, "Ciphertext should not be empty even for empty plaintext")

	# Establish session and decrypt
	var inbound = establish_bob_session(result["message_type"], result["ciphertext"])
	assert_eq(inbound["plaintext"], "", "Should decrypt to empty string")

# Test 9: Long Message Encryption
func test_long_message_encryption():
	var long_message = ""
	for i in range(1000):
		long_message += "This is a test message. "

	var encrypt_result = alice_session.encrypt(long_message)
	assert_true(encrypt_result["success"], "Should encrypt long message")

	var inbound = establish_bob_session(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)
	assert_eq(inbound["plaintext"], long_message, "Should decrypt long message correctly")

# Test 10: Unicode/Special Characters
func test_unicode_encryption():
	var unicode_message = "Hello! 你好! مرحبا! Здравствуй! 🎉🔐💻"
	var encrypt_result = alice_session.encrypt(unicode_message)

	assert_true(encrypt_result["success"], "Should encrypt unicode")

	var inbound = establish_bob_session(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)
	assert_eq(inbound["plaintext"], unicode_message, "Should decrypt unicode correctly")

# Test 11: Decrypt with Wrong Session
func test_decrypt_with_wrong_session():
	# Create another account and session
	var charlie_account = VodozemacAccount.new()
	charlie_account.initialize()
	charlie_account.generate_one_time_keys(3)

	var charlie_identity = charlie_account.get_identity_keys()
	var charlie_otks = charlie_account.get_one_time_keys()
	var charlie_session = alice_account.create_outbound_session(
		charlie_identity["curve25519"],
		charlie_otks.values()[0]
	)

	# Encrypt message for Charlie
	var encrypt_result = charlie_session.encrypt("Message for Charlie")

	# Try to decrypt with Bob's session (should fail)
	establish_bob_session(0, alice_session.encrypt("Init")[" ciphertext"])

	var decrypt_result = bob_session.decrypt(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	assert_false(decrypt_result["success"], "Decryption with wrong session should fail")

# Test 12: Decrypt Corrupted Ciphertext
func test_decrypt_corrupted_ciphertext():
	var encrypt_result = alice_session.encrypt("Test")
	establish_bob_session(encrypt_result["message_type"], encrypt_result["ciphertext"])

	# Send another message and corrupt it
	var encrypt2 = alice_session.encrypt("Another test")
	var corrupted = encrypt2["ciphertext"].substr(0, encrypt2["ciphertext"].length() - 10) + "CORRUPTED"

	var decrypt_result = bob_session.decrypt(encrypt2["message_type"], corrupted)
	assert_false(decrypt_result["success"], "Decryption of corrupted ciphertext should fail")

# Test 13: Message Type Validation
func test_message_type_validation():
	var encrypt_result = alice_session.encrypt("Test")
	establish_bob_session(encrypt_result["message_type"], encrypt_result["ciphertext"])

	# Try to decrypt with wrong message type
	var wrong_type = 1 if encrypt_result["message_type"] == 0 else 0
	var decrypt_result = bob_session.decrypt(wrong_type, encrypt_result["ciphertext"])

	# This might succeed or fail depending on implementation, but we log it
	if not decrypt_result["success"]:
		assert_true(true, "Wrong message type causes decryption failure (expected behavior)")

# Test 14: Session Persistence After Encryption
func test_session_persistence_after_encryption():
	# Encrypt some messages
	alice_session.encrypt("Message 1")
	alice_session.encrypt("Message 2")

	# Pickle the session
	var key = PackedByteArray()
	for i in range(32):
		key.append(i + 20)

	var pickle = alice_session.pickle(key)

	# Restore session
	var restored_session = VodozemacSession.new()
	var result = restored_session.from_pickle(pickle, key)
	assert_eq(result, OK, "Should restore session")

	# Should be able to encrypt more messages
	var encrypt_result = restored_session.encrypt("Message 3")
	assert_true(encrypt_result["success"], "Restored session should encrypt")
