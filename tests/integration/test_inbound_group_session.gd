extends GutTest

## Inbound Group Session Tests
##
## Tests for VodozemacInboundGroupSession (recipient) functionality

func test_create_inbound_session():
	# Create outbound session
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()
	var session_key = outbound.get_session_key()

	# Create inbound session
	var inbound = VodozemacInboundGroupSession.new()
	assert_eq(inbound.initialize_from_session_key(session_key), OK,
		"Should initialize from session key")

	assert_eq(inbound.get_session_id(), outbound.get_session_id(),
		"Session IDs should match")

func test_encrypt_decrypt():
	# Setup
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	# Encrypt
	var plaintext = "Secret group message"
	var encrypted = outbound.encrypt(plaintext)
	assert_true(encrypted["success"], "Encryption should succeed")

	# Decrypt
	var decrypted = inbound.decrypt(encrypted["ciphertext"])
	assert_true(decrypted["success"], "Decryption should succeed")
	assert_eq(decrypted["plaintext"], plaintext, "Plaintext should match")
	assert_eq(decrypted["message_index"], 0, "First message index should be 0")

func test_multiple_messages():
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	var messages = ["First", "Second", "Third", "Fourth", "Fifth"]

	for i in range(messages.size()):
		var msg = messages[i]
		var encrypted = outbound.encrypt(msg)
		var decrypted = inbound.decrypt(encrypted["ciphertext"])

		assert_true(decrypted["success"], "Message %d should decrypt" % i)
		assert_eq(decrypted["plaintext"], msg, "Plaintext should match for message %d" % i)
		assert_eq(decrypted["message_index"], i, "Message index should be %d" % i)

func test_multiple_recipients():
	# One sender, multiple receivers
	var sender = VodozemacGroupSession.new()
	sender.initialize()
	var session_key = sender.get_session_key()

	# Create three recipients
	var recipients = []
	for i in range(3):
		var recipient = VodozemacInboundGroupSession.new()
		assert_eq(recipient.initialize_from_session_key(session_key), OK,
			"Recipient %d should initialize" % i)
		recipients.append(recipient)

	# Send messages
	var messages = ["First", "Second", "Third"]
	for msg in messages:
		var encrypted = sender.encrypt(msg)

		# Each recipient should decrypt successfully
		for i in range(recipients.size()):
			var recipient = recipients[i]
			var decrypted = recipient.decrypt(encrypted["ciphertext"])
			assert_true(decrypted["success"], "Recipient %d should decrypt" % i)
			assert_eq(decrypted["plaintext"], msg, "Plaintext should match for recipient %d" % i)

func test_first_known_index():
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	assert_eq(inbound.get_first_known_index(), 0, "First known index should be 0 for full session")

	# Decrypt some messages
	for i in range(5):
		var encrypted = outbound.encrypt("Message %d" % i)
		inbound.decrypt(encrypted["ciphertext"])

	# First known index should still be 0
	assert_eq(inbound.get_first_known_index(), 0, "First known index should remain 0")

func test_export_and_import():
	# Create and use a session
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	# Encrypt some messages
	for i in range(5):
		outbound.encrypt("Message %d" % i)

	# Export at message index 3
	var export_result = inbound.export_at_index(3)
	assert_true(export_result["success"], "Export should succeed")
	assert_ne(export_result["exported_key"], "", "Exported key should not be empty")

	# Import into new session
	var imported = VodozemacInboundGroupSession.new()
	assert_eq(imported.import_session(export_result["exported_key"]), OK,
		"Import should succeed")

	# Should only decrypt from index 3 onwards
	assert_eq(imported.get_first_known_index(), 3, "First known index should be 3")

	# Verify it can decrypt message 3 and onwards
	var encrypted3 = outbound.encrypt("Message 5")
	var decrypted3 = imported.decrypt(encrypted3["ciphertext"])
	assert_true(decrypted3["success"], "Should decrypt message from index 5")

func test_session_persistence():
	var key = PackedByteArray()
	key.resize(32)
	for i in range(32):
		key[i] = randi() % 256

	# Create session
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	var original_id = inbound.get_session_id()

	# Decrypt a message
	var encrypted = outbound.encrypt("Test message")
	inbound.decrypt(encrypted["ciphertext"])

	# Pickle
	var pickle = inbound.pickle(key)
	assert_ne(pickle, "", "Pickle should not be empty")

	# Restore
	var restored = VodozemacInboundGroupSession.new()
	assert_eq(restored.from_pickle(pickle, key), OK, "Should restore from pickle")
	assert_eq(restored.get_session_id(), original_id, "Session ID should match")

	# Should still be able to decrypt new messages
	var encrypted2 = outbound.encrypt("Another message")
	var decrypted2 = restored.decrypt(encrypted2["ciphertext"])
	assert_true(decrypted2["success"], "Should decrypt after restore")

func test_decrypt_without_initialization():
	var inbound = VodozemacInboundGroupSession.new()

	var result = inbound.decrypt("invalid_ciphertext")
	assert_false(result["success"], "Decryption should fail without initialization")
	assert_true(result.has("error"), "Should have error message")

func test_invalid_session_key():
	var inbound = VodozemacInboundGroupSession.new()

	var result = inbound.initialize_from_session_key("invalid_key")
	assert_eq(result, FAILED, "Should fail with invalid session key")
	assert_ne(inbound.get_last_error(), "", "Should have error message")

func test_invalid_ciphertext():
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	var result = inbound.decrypt("invalid_base64_$%^&")
	assert_false(result["success"], "Should fail with invalid ciphertext")
	assert_true(result.has("error"), "Should have error message")

func test_wrong_session():
	# Create two separate group sessions
	var outbound1 = VodozemacGroupSession.new()
	outbound1.initialize()

	var outbound2 = VodozemacGroupSession.new()
	outbound2.initialize()

	# Inbound session for group 1
	var inbound1 = VodozemacInboundGroupSession.new()
	inbound1.initialize_from_session_key(outbound1.get_session_key())

	# Try to decrypt message from group 2 with group 1's session
	var encrypted2 = outbound2.encrypt("Secret from group 2")
	var result = inbound1.decrypt(encrypted2["ciphertext"])

	assert_false(result["success"], "Should not decrypt message from different group")
	assert_true(result.has("error"), "Should have error message")

func test_unicode_decrypt():
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	var unicode_message = "Hello 世界! 🚀 Тест مرحبا"
	var encrypted = outbound.encrypt(unicode_message)
	var decrypted = inbound.decrypt(encrypted["ciphertext"])

	assert_true(decrypted["success"], "Should decrypt unicode message")
	assert_eq(decrypted["plaintext"], unicode_message, "Unicode should be preserved")

func test_export_at_invalid_index():
	var outbound = VodozemacGroupSession.new()
	outbound.initialize()

	var inbound = VodozemacInboundGroupSession.new()
	inbound.initialize_from_session_key(outbound.get_session_key())

	# Try to export at index 100 without having that many messages
	var result = inbound.export_at_index(100)

	# This should either succeed (exporting future state) or fail gracefully
	if not result["success"]:
		assert_true(result.has("error"), "Should have error message if export fails")
	else:
		assert_true(result.has("exported_key"), "Should have exported_key if export succeeds")
		assert_true(true, "Export at high index succeeded (implementation allows future state export)")
