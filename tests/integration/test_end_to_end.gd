extends GutTest

# Phase 10 - End-to-End Integration Tests
# Complete workflow tests simulating real-world usage scenarios

# Test 1: Complete Alice-Bob Workflow
func test_complete_alice_bob_workflow():
	# Step 1: Create accounts
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()

	alice.initialize()
	bob.initialize()

	# Step 2: Exchange identity keys and OTKs
	bob.generate_one_time_keys(10)
	var bob_identity = bob.get_identity_keys()
	var bob_otks = bob.get_one_time_keys()

	assert_eq(bob_otks.size(), 10, "Bob should have 10 OTKs")

	# Step 3: Alice creates outbound session
	var bob_otk = bob_otks.values()[0]
	var alice_session = alice.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	assert_not_null(alice_session, "Alice should create session")

	# Step 4: Alice sends first message
	var first_message = "Hello Bob! Let's establish a secure channel."
	var first_encrypt = alice_session.encrypt(first_message)

	assert_true(first_encrypt["success"], "First encryption should succeed")
	assert_eq(first_encrypt["message_type"], 0, "First message should be PreKey")

	# Step 5: Bob receives and creates inbound session
	var alice_identity = alice.get_identity_keys()
	var bob_inbound = bob.create_inbound_session(
		alice_identity["curve25519"],
		first_encrypt["message_type"],
		first_encrypt["ciphertext"]
	)

	assert_true(bob_inbound["success"], "Bob should create inbound session")
	assert_eq(bob_inbound["plaintext"], first_message, "Bob should decrypt first message")

	var bob_session = bob_inbound["session"]

	# Step 6: Bob marks the used OTK as published
	bob.mark_keys_as_published()
	var remaining_otks = bob.get_one_time_keys()
	assert_eq(remaining_otks.size(), 0, "OTKs should be cleared after marking")

	# Step 7: Bob responds
	var bob_message = "Hi Alice! Channel established."
	var bob_encrypt = bob_session.encrypt(bob_message)

	assert_true(bob_encrypt["success"], "Bob's encryption should succeed")

	# Step 8: Alice receives Bob's response
	var alice_decrypt = alice_session.decrypt(
		bob_encrypt["message_type"],
		bob_encrypt["ciphertext"]
	)

	assert_true(alice_decrypt["success"], "Alice should decrypt Bob's message")
	assert_eq(alice_decrypt["plaintext"], bob_message, "Alice should receive Bob's message")

	# Step 9: Continue conversation
	for i in range(5):
		# Alice -> Bob
		var alice_msg = "Alice message " + str(i)
		var alice_enc = alice_session.encrypt(alice_msg)
		var bob_dec = bob_session.decrypt(alice_enc["message_type"], alice_enc["ciphertext"])
		assert_eq(bob_dec["plaintext"], alice_msg)

		# Bob -> Alice
		var bob_msg = "Bob response " + str(i)
		var bob_enc = bob_session.encrypt(bob_msg)
		var alice_dec = alice_session.decrypt(bob_enc["message_type"], bob_enc["ciphertext"])
		assert_eq(alice_dec["plaintext"], bob_msg)

# Test 2: Session Persistence Across Save/Load
func test_session_persistence_across_save_load():
	# Create and establish session
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()
	alice.initialize()
	bob.initialize()

	bob.generate_one_time_keys(5)
	var bob_identity = bob.get_identity_keys()
	var bob_otk = bob.get_one_time_keys().values()[0]

	var alice_session = alice.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	# Send some messages
	var msg1_enc = alice_session.encrypt("Message before save")
	var alice_identity = alice.get_identity_keys()
	var bob_inbound = bob.create_inbound_session(
		alice_identity["curve25519"],
		msg1_enc["message_type"],
		msg1_enc["ciphertext"]
	)
	var bob_session = bob_inbound["session"]

	alice_session.encrypt("Message 2")
	alice_session.encrypt("Message 3")

	# Save both accounts and sessions
	var account_key = PackedByteArray()
	var session_key = PackedByteArray()
	for i in range(32):
		account_key.append(i + 1)
		session_key.append(i + 100)

	var alice_pickle = alice.pickle(account_key)
	var bob_pickle = bob.pickle(account_key)
	var alice_session_pickle = alice_session.pickle(session_key)
	var bob_session_pickle = bob_session.pickle(session_key)

	# Simulate restart - create new objects and restore
	var alice_restored = VodozemacAccount.new()
	var bob_restored = VodozemacAccount.new()
	var alice_session_restored = VodozemacSession.new()
	var bob_session_restored = VodozemacSession.new()

	assert_eq(alice_restored.from_pickle(alice_pickle, account_key), OK)
	assert_eq(bob_restored.from_pickle(bob_pickle, account_key), OK)
	assert_eq(alice_session_restored.from_pickle(alice_session_pickle, session_key), OK)
	assert_eq(bob_session_restored.from_pickle(bob_session_pickle, session_key), OK)

	# Continue conversation with restored sessions
	var msg_after_restore = "Message after restore"
	var enc_after = alice_session_restored.encrypt(msg_after_restore)
	var dec_after = bob_session_restored.decrypt(enc_after["message_type"], enc_after["ciphertext"])

	assert_true(dec_after["success"], "Should decrypt after restore")
	assert_eq(dec_after["plaintext"], msg_after_restore, "Message should match after restore")

# Test 3: Multiple Concurrent Sessions
func test_multiple_concurrent_sessions():
	# Alice talking to multiple people
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()
	var charlie = VodozemacAccount.new()

	alice.initialize()
	bob.initialize()
	charlie.initialize()

	# Set up sessions
	bob.generate_one_time_keys(5)
	charlie.generate_one_time_keys(5)

	var bob_identity = bob.get_identity_keys()
	var charlie_identity = charlie.get_identity_keys()

	var bob_otk = bob.get_one_time_keys().values()[0]
	var charlie_otk = charlie.get_one_time_keys().values()[0]

	# Alice creates sessions with both Bob and Charlie
	var alice_bob_session = alice.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	var alice_charlie_session = alice.create_outbound_session(
		charlie_identity["curve25519"],
		charlie_otk
	)

	# Verify sessions are different
	assert_ne(alice_bob_session.get_session_id(), alice_charlie_session.get_session_id(),
		"Sessions should be different")

	# Alice sends messages to both
	var msg_to_bob = "Hi Bob!"
	var msg_to_charlie = "Hi Charlie!"

	var enc_bob = alice_bob_session.encrypt(msg_to_bob)
	var enc_charlie = alice_charlie_session.encrypt(msg_to_charlie)

	# Bob and Charlie establish their inbound sessions
	var alice_identity = alice.get_identity_keys()

	var bob_inbound = bob.create_inbound_session(
		alice_identity["curve25519"],
		enc_bob["message_type"],
		enc_bob["ciphertext"]
	)

	var charlie_inbound = charlie.create_inbound_session(
		alice_identity["curve25519"],
		enc_charlie["message_type"],
		enc_charlie["ciphertext"]
	)

	# Verify correct decryption
	assert_eq(bob_inbound["plaintext"], msg_to_bob, "Bob should get his message")
	assert_eq(charlie_inbound["plaintext"], msg_to_charlie, "Charlie should get his message")

	# Continue conversations independently
	var bob_session = bob_inbound["session"]
	var charlie_session = charlie_inbound["session"]

	# Alice -> Bob
	var msg2_bob = "How are you, Bob?"
	var enc2_bob = alice_bob_session.encrypt(msg2_bob)
	var dec2_bob = bob_session.decrypt(enc2_bob["message_type"], enc2_bob["ciphertext"])
	assert_eq(dec2_bob["plaintext"], msg2_bob)

	# Alice -> Charlie
	var msg2_charlie = "How are you, Charlie?"
	var enc2_charlie = alice_charlie_session.encrypt(msg2_charlie)
	var dec2_charlie = charlie_session.decrypt(enc2_charlie["message_type"], enc2_charlie["ciphertext"])
	assert_eq(dec2_charlie["plaintext"], msg2_charlie)

# Test 4: Key Rotation Scenario
func test_key_rotation_scenario():
	var bob = VodozemacAccount.new()
	bob.initialize()

	# Generate initial batch of OTKs
	bob.generate_one_time_keys(10)
	var initial_otks = bob.get_one_time_keys()
	assert_eq(initial_otks.size(), 10)

	# Simulate: keys are uploaded to server
	bob.mark_keys_as_published()
	assert_eq(bob.get_one_time_keys().size(), 0, "Keys should be cleared")

	# Generate new batch
	bob.generate_one_time_keys(10)
	var new_otks = bob.get_one_time_keys()
	assert_eq(new_otks.size(), 10, "Should have new batch of keys")

	# Verify keys are different (at least some should be)
	var keys_match = true
	for key_id in new_otks.keys():
		if not initial_otks.has(key_id):
			keys_match = false
			break

	assert_false(keys_match, "New OTKs should be different from old ones")

# Test 5: Account Recovery from Pickle
func test_account_recovery_from_pickle():
	# Create account with some state
	var original = VodozemacAccount.new()
	original.initialize()
	original.generate_one_time_keys(7)

	var original_identity = original.get_identity_keys()
	var original_otks = original.get_one_time_keys()

	# Pickle the account
	var key = PackedByteArray()
	for i in range(32):
		key.append(i + 50)

	var pickle = original.pickle(key)

	# Simulate data loss - create new account from pickle
	var recovered = VodozemacAccount.new()
	var result = recovered.from_pickle(pickle, key)

	assert_eq(result, OK, "Recovery should succeed")

	# Verify all state is recovered
	var recovered_identity = recovered.get_identity_keys()
	var recovered_otks = recovered.get_one_time_keys()

	assert_eq(recovered_identity["ed25519"], original_identity["ed25519"],
		"Ed25519 key should be preserved")
	assert_eq(recovered_identity["curve25519"], original_identity["curve25519"],
		"Curve25519 key should be preserved")
	assert_eq(recovered_otks.size(), original_otks.size(),
		"OTK count should be preserved")

# Test 6: Error Handling - Invalid Identity Key
func test_error_invalid_identity_key():
	var alice = VodozemacAccount.new()
	alice.initialize()

	# Try to create session with invalid identity key
	var invalid_key = "this_is_not_a_valid_base64_key"
	var fake_otk = "also_not_valid"

	var session = alice.create_outbound_session(invalid_key, fake_otk)

	# Should either return null or create an invalid session
	assert_not_null(session, "Should return a session object even if parameters are invalid")

	# Try to encrypt with it - should fail or have error
	var result = session.encrypt("test")
	var error = alice.get_last_error()

	# Either encryption fails or there's an error message
	var has_error = (not result.get("success", false)) or (error != "")
	assert_true(has_error, "Should have error when using invalid keys")

# Test 7: Max OTKs Boundary Test
func test_max_otks_boundary():
	var account = VodozemacAccount.new()
	account.initialize()

	var max_otks = account.get_max_number_of_one_time_keys()

	# Generate maximum number of keys
	var result = account.generate_one_time_keys(max_otks)
	assert_eq(result, OK, "Should generate max number of OTKs")

	var otks = account.get_one_time_keys()
	assert_lte(otks.size(), max_otks, "Should not exceed max OTKs")

# Test 8: Session ID Uniqueness
func test_session_id_uniqueness():
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()

	alice.initialize()
	bob.initialize()

	bob.generate_one_time_keys(10)
	var bob_identity = bob.get_identity_keys()
	var bob_otks = bob.get_one_time_keys()

	# Create multiple sessions with different OTKs
	var session_ids = []

	for i in range(min(5, bob_otks.size())):
		var otk = bob_otks.values()[i]
		var session = alice.create_outbound_session(
			bob_identity["curve25519"],
			otk
		)

		var session_id = session.get_session_id()
		assert_false(session_id in session_ids, "Session IDs should be unique")
		session_ids.append(session_id)

# Test 9: Long-Running Conversation
func test_long_running_conversation():
	# Establish session
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()
	alice.initialize()
	bob.initialize()

	bob.generate_one_time_keys(5)
	var bob_identity = bob.get_identity_keys()
	var bob_otk = bob.get_one_time_keys().values()[0]

	var alice_session = alice.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	# Establish Bob's session
	var first_enc = alice_session.encrypt("Init")
	var alice_identity = alice.get_identity_keys()
	var bob_inbound = bob.create_inbound_session(
		alice_identity["curve25519"],
		first_enc["message_type"],
		first_enc["ciphertext"]
	)
	var bob_session = bob_inbound["session"]

	# Exchange many messages
	for i in range(100):
		var alice_msg = "Alice message " + str(i)
		var alice_enc = alice_session.encrypt(alice_msg)
		var bob_dec = bob_session.decrypt(alice_enc["message_type"], alice_enc["ciphertext"])
		assert_eq(bob_dec["plaintext"], alice_msg, "Message " + str(i) + " should decrypt correctly")

		if i % 10 == 0:
			# Bob responds occasionally
			var bob_msg = "Bob ack " + str(i)
			var bob_enc = bob_session.encrypt(bob_msg)
			var alice_dec = alice_session.decrypt(bob_enc["message_type"], bob_enc["ciphertext"])
			assert_eq(alice_dec["plaintext"], bob_msg)

# Test 10: Complete Workflow with Persistence
func test_complete_workflow_with_persistence():
	# Day 1: Initial setup
	var alice = VodozemacAccount.new()
	var bob = VodozemacAccount.new()
	alice.initialize()
	bob.initialize()

	bob.generate_one_time_keys(10)

	# Exchange and establish session
	var bob_identity = bob.get_identity_keys()
	var bob_otk = bob.get_one_time_keys().values()[0]
	var alice_session = alice.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	var msg1 = alice_session.encrypt("Day 1 message")
	var alice_identity = alice.get_identity_keys()
	var bob_inbound = bob.create_inbound_session(
		alice_identity["curve25519"],
		msg1["message_type"],
		msg1["ciphertext"]
	)
	var bob_session = bob_inbound["session"]

	# Save everything
	var acc_key = PackedByteArray()
	var sess_key = PackedByteArray()
	for i in range(32):
		acc_key.append(i)
		sess_key.append(i + 64)

	var alice_acc_pickle = alice.pickle(acc_key)
	var bob_acc_pickle = bob.pickle(acc_key)
	var alice_sess_pickle = alice_session.pickle(sess_key)
	var bob_sess_pickle = bob_session.pickle(sess_key)

	# Day 2: Restore and continue
	var alice2 = VodozemacAccount.new()
	var bob2 = VodozemacAccount.new()
	var alice_sess2 = VodozemacSession.new()
	var bob_sess2 = VodozemacSession.new()

	alice2.from_pickle(alice_acc_pickle, acc_key)
	bob2.from_pickle(bob_acc_pickle, acc_key)
	alice_sess2.from_pickle(alice_sess_pickle, sess_key)
	bob_sess2.from_pickle(bob_sess_pickle, sess_key)

	# Continue conversation
	var msg2 = alice_sess2.encrypt("Day 2 message")
	var dec2 = bob_sess2.decrypt(msg2["message_type"], msg2["ciphertext"])
	assert_eq(dec2["plaintext"], "Day 2 message", "Should work after restore")

	var msg3 = bob_sess2.encrypt("Day 2 response")
	var dec3 = alice_sess2.decrypt(msg3["message_type"], msg3["ciphertext"])
	assert_eq(dec3["plaintext"], "Day 2 response", "Bidirectional should work after restore")
