extends GutTest

# Phase 10 - Session Integration Tests
# Tests for VodozemacSession class functionality

var alice_account: VodozemacAccount
var bob_account: VodozemacAccount

func before_each():
	alice_account = VodozemacAccount.new()
	bob_account = VodozemacAccount.new()
	alice_account.initialize()
	bob_account.initialize()

	# Generate one-time keys for Bob (receiver)
	bob_account.generate_one_time_keys(5)

func after_each():
	alice_account = null
	bob_account = null

# Test 1: Create Outbound Session
func test_create_outbound_session():
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]  # Get first OTK

	var session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	assert_not_null(session, "Session should be created")
	assert_is(session, VodozemacSession, "Should be a VodozemacSession instance")

# Test 2: Get Session ID
func test_get_session_id():
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	var session_id = session.get_session_id()
	assert_not_null(session_id, "Session ID should exist")
	assert_gt(session_id.length(), 0, "Session ID should not be empty")
	assert_typeof(session_id, TYPE_STRING, "Session ID should be a string")

# Test 3: Session Pickle
func test_session_pickle():
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	var key = PackedByteArray()
	for i in range(32):
		key.append(i + 10)

	var pickle = session.pickle(key)
	assert_gt(pickle.length(), 0, "Session pickle should not be empty")
	assert_typeof(pickle, TYPE_STRING, "Pickle should be a string")

# Test 4: Session Unpickle
func test_session_unpickle():
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var session1 = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	var session_id_before = session1.get_session_id()

	var key = PackedByteArray()
	for i in range(32):
		key.append(i + 10)

	var pickle = session1.pickle(key)

	# Create new session and unpickle
	var session2 = VodozemacSession.new()
	var result = session2.from_pickle(pickle, key)
	assert_eq(result, OK, "Session unpickle should succeed")

	var session_id_after = session2.get_session_id()
	assert_eq(session_id_before, session_id_after, "Session ID should be preserved")

# Test 5: Session Unpickle with Wrong Key
func test_session_unpickle_wrong_key():
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	var key1 = PackedByteArray()
	for i in range(32):
		key1.append(i)

	var pickle = session.pickle(key1)

	var key2 = PackedByteArray()
	for i in range(32):
		key2.append(i + 5)

	var session2 = VodozemacSession.new()
	var result = session2.from_pickle(pickle, key2)
	assert_ne(result, OK, "Unpickle with wrong key should fail")

# Test 6: Create Inbound Session from Pre-Key Message
func test_create_inbound_session():
	# Alice creates outbound session
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var alice_session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	# Alice encrypts a message (this will be a PreKey message)
	var encrypt_result = alice_session.encrypt("Hello Bob!")
	assert_true(encrypt_result["success"], "Encryption should succeed")
	assert_eq(encrypt_result["message_type"], 0, "First message should be PreKey (type 0)")

	# Bob creates inbound session from the pre-key message
	var alice_identity = alice_account.get_identity_keys()
	var inbound_result = bob_account.create_inbound_session(
		alice_identity["curve25519"],
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	assert_true(inbound_result["success"], "Inbound session creation should succeed")
	assert_not_null(inbound_result["session"], "Should return a session")
	assert_eq(inbound_result["plaintext"], "Hello Bob!", "Should decrypt initial message")

# Test 7: Session Matching
func test_session_matches():
	# Alice creates outbound session
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var alice_session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	# Encrypt a pre-key message
	var encrypt_result = alice_session.encrypt("Test message")

	# Bob creates inbound session
	var alice_identity = alice_account.get_identity_keys()
	var inbound_result = bob_account.create_inbound_session(
		alice_identity["curve25519"],
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)

	var bob_session = inbound_result["session"]

	# Test session matching with the same message
	var matches = bob_session.session_matches(
		encrypt_result["message_type"],
		encrypt_result["ciphertext"]
	)
	assert_true(matches, "Session should match the pre-key message")

# Test 8: Multiple Sessions Per Account
func test_multiple_sessions():
	bob_account.generate_one_time_keys(5)  # Ensure enough OTKs

	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk_values = bob_otks.values()

	# Create two different sessions
	var session1 = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk_values[0]
	)

	var session2 = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk_values[1]
	)

	var id1 = session1.get_session_id()
	var id2 = session2.get_session_id()

	# Sessions should have different IDs
	assert_ne(id1, id2, "Different sessions should have different IDs")

# Test 9: Session Pickle Wrong Key Size
func test_session_pickle_wrong_key_size():
	var bob_identity = bob_account.get_identity_keys()
	var bob_otks = bob_account.get_one_time_keys()
	var bob_otk = bob_otks.values()[0]

	var session = alice_account.create_outbound_session(
		bob_identity["curve25519"],
		bob_otk
	)

	# Wrong key size (16 instead of 32)
	var wrong_key = PackedByteArray()
	for i in range(16):
		wrong_key.append(i)

	var pickle = session.pickle(wrong_key)
	var error = session.get_last_error()
	assert_gt(error.length(), 0, "Should have error for wrong key size")

# Test 10: Get Last Error
func test_get_last_error():
	var session = VodozemacSession.new()

	# Try to get session ID without initializing
	var session_id = session.get_session_id()
	var error = session.get_last_error()

	# Should have an error message
	assert_typeof(error, TYPE_STRING, "Error should be a string")
