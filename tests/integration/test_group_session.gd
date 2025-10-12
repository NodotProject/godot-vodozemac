extends GutTest

## Group Session Tests
##
## Tests for VodozemacGroupSession (outbound) functionality

func test_create_group_session():
	var group_session = VodozemacGroupSession.new()
	assert_eq(group_session.initialize(), OK, "Should initialize group session")

	var session_id = group_session.get_session_id()
	assert_ne(session_id, "", "Session ID should not be empty")
	assert_gt(session_id.length(), 10, "Session ID should be a reasonable length")

func test_get_session_key():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var session_key = group_session.get_session_key()
	assert_ne(session_key, "", "Session key should not be empty")
	assert_gt(session_key.length(), 20, "Session key should be a reasonable length")

func test_encrypt_message():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var plaintext = "Hello, group!"
	var result = group_session.encrypt(plaintext)

	assert_true(result["success"], "Encryption should succeed")
	assert_ne(result["ciphertext"], "", "Ciphertext should not be empty")
	assert_ne(result["ciphertext"], plaintext, "Ciphertext should differ from plaintext")

func test_message_index_increments():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var index1 = group_session.get_message_index()
	assert_eq(index1, 0, "Initial message index should be 0")

	group_session.encrypt("First message")
	var index2 = group_session.get_message_index()
	assert_eq(index2, 1, "Message index should increment to 1")

	group_session.encrypt("Second message")
	var index3 = group_session.get_message_index()
	assert_eq(index3, 2, "Message index should increment to 2")

func test_multiple_messages():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var messages = ["First", "Second", "Third", "Fourth", "Fifth"]
	var ciphertexts = []

	for msg in messages:
		var result = group_session.encrypt(msg)
		assert_true(result["success"], "All encryptions should succeed")
		ciphertexts.append(result["ciphertext"])

	# All ciphertexts should be unique
	for i in range(ciphertexts.size()):
		for j in range(i + 1, ciphertexts.size()):
			assert_ne(ciphertexts[i], ciphertexts[j], "Ciphertexts should be unique")

func test_session_persistence():
	var key = PackedByteArray()
	key.resize(32)
	for i in range(32):
		key[i] = randi() % 256

	# Create and use a session
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var original_id = group_session.get_session_id()
	var original_key = group_session.get_session_key()

	# Encrypt some messages
	group_session.encrypt("Message 1")
	group_session.encrypt("Message 2")
	var index_before = group_session.get_message_index()

	# Pickle
	var pickle = group_session.pickle(key)
	assert_ne(pickle, "", "Pickle should not be empty")

	# Restore from pickle
	var restored_session = VodozemacGroupSession.new()
	assert_eq(restored_session.from_pickle(pickle, key), OK, "Should restore from pickle")

	assert_eq(restored_session.get_session_id(), original_id, "Session ID should match")
	assert_eq(restored_session.get_session_key(), original_key, "Session key should match")
	assert_eq(restored_session.get_message_index(), index_before, "Message index should be preserved")

func test_pickle_with_wrong_key():
	var key1 = PackedByteArray()
	key1.resize(32)
	for i in range(32):
		key1[i] = i

	var key2 = PackedByteArray()
	key2.resize(32)
	for i in range(32):
		key2[i] = 255 - i

	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var pickle = group_session.pickle(key1)

	var restored_session = VodozemacGroupSession.new()
	var result = restored_session.from_pickle(pickle, key2)

	assert_eq(result, FAILED, "Unpickling with wrong key should fail")
	assert_ne(restored_session.get_last_error(), "", "Should have error message")

func test_encrypt_without_initialization():
	var group_session = VodozemacGroupSession.new()

	var result = group_session.encrypt("Test")
	assert_false(result["success"], "Encryption should fail without initialization")
	assert_true(result.has("error"), "Should have error message")

func test_get_session_id_without_initialization():
	var group_session = VodozemacGroupSession.new()

	var session_id = group_session.get_session_id()
	assert_eq(session_id, "", "Should return empty string when not initialized")
	assert_ne(group_session.get_last_error(), "", "Should have error message")

func test_empty_message():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var result = group_session.encrypt("")
	assert_true(result["success"], "Should be able to encrypt empty string")
	assert_ne(result["ciphertext"], "", "Ciphertext should not be empty even for empty plaintext")

func test_large_message():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	# Create a large message (100KB)
	var large_message = ""
	for i in range(1000):
		large_message += "This is a test message that will be repeated many times to create a large payload. "

	var result = group_session.encrypt(large_message)
	assert_true(result["success"], "Should be able to encrypt large messages")
	assert_gt(result["ciphertext"].length(), large_message.length(), "Ciphertext should contain overhead")

func test_unicode_message():
	var group_session = VodozemacGroupSession.new()
	group_session.initialize()

	var unicode_message = "Hello 世界! 🚀 Тест مرحبا"
	var result = group_session.encrypt(unicode_message)
	assert_true(result["success"], "Should be able to encrypt unicode messages")
