extends GutTest

# Phase 10 - Account Integration Tests
# Tests for VodozemacAccount class functionality

var account: VodozemacAccount

func before_each():
	account = VodozemacAccount.new()

func after_each():
	account = null

# Test 1: Account Creation and Initialization
func test_account_creation():
	assert_not_null(account, "Account should be created")
	var result = account.initialize()
	assert_eq(result, OK, "Account initialization should succeed")

# Test 2: Identity Keys Retrieval
func test_identity_keys():
	account.initialize()
	var keys = account.get_identity_keys()

	assert_true(keys.has("ed25519"), "Should have ed25519 key")
	assert_true(keys.has("curve25519"), "Should have curve25519 key")
	assert_gt(keys["ed25519"].length(), 0, "Ed25519 key should not be empty")
	assert_gt(keys["curve25519"].length(), 0, "Curve25519 key should not be empty")

# Test 3: Generate One-Time Keys
func test_generate_one_time_keys():
	account.initialize()
	var result = account.generate_one_time_keys(5)
	assert_eq(result, OK, "Should generate one-time keys successfully")

# Test 4: Retrieve One-Time Keys
func test_get_one_time_keys():
	account.initialize()
	account.generate_one_time_keys(3)

	var otk = account.get_one_time_keys()
	assert_eq(otk.size(), 3, "Should have 3 one-time keys")

	# Check that keys are base64 strings
	for key_id in otk.keys():
		assert_gt(otk[key_id].length(), 0, "Key should not be empty")

# Test 5: Mark Keys as Published
func test_mark_keys_as_published():
	account.initialize()
	account.generate_one_time_keys(5)

	var otk_before = account.get_one_time_keys()
	assert_eq(otk_before.size(), 5, "Should have 5 keys before marking")

	account.mark_keys_as_published()

	var otk_after = account.get_one_time_keys()
	assert_eq(otk_after.size(), 0, "Should have 0 keys after marking as published")

# Test 6: Max Number of One-Time Keys
func test_max_number_of_one_time_keys():
	account.initialize()
	var max_keys = account.get_max_number_of_one_time_keys()
	assert_gt(max_keys, 0, "Max number of OTKs should be positive")
	assert_typeof(max_keys, TYPE_INT, "Max keys should be an integer")

# Test 7: Account Pickle (Serialization)
func test_account_pickle():
	account.initialize()
	account.generate_one_time_keys(3)

	# Create a 32-byte encryption key
	var key = PackedByteArray()
	for i in range(32):
		key.append(i + 1)

	var pickle = account.pickle(key)
	assert_gt(pickle.length(), 0, "Pickle should not be empty")
	assert_typeof(pickle, TYPE_STRING, "Pickle should be a string")

# Test 8: Account Unpickle (Deserialization)
func test_account_unpickle():
	# Create and pickle an account
	var account1 = VodozemacAccount.new()
	account1.initialize()
	account1.generate_one_time_keys(3)

	var identity_keys_before = account1.get_identity_keys()

	var key = PackedByteArray()
	for i in range(32):
		key.append(i + 1)

	var pickle = account1.pickle(key)

	# Create new account and unpickle
	var account2 = VodozemacAccount.new()
	var result = account2.from_pickle(pickle, key)
	assert_eq(result, OK, "Unpickle should succeed")

	var identity_keys_after = account2.get_identity_keys()
	assert_eq(identity_keys_before["ed25519"], identity_keys_after["ed25519"],
		"Ed25519 key should be preserved")
	assert_eq(identity_keys_before["curve25519"], identity_keys_after["curve25519"],
		"Curve25519 key should be preserved")

# Test 9: Pickle with Wrong Key Size
func test_pickle_wrong_key_size():
	account.initialize()

	# Key with wrong size (16 bytes instead of 32)
	var wrong_key = PackedByteArray()
	for i in range(16):
		wrong_key.append(i)

	var pickle = account.pickle(wrong_key)
	# Should return empty string or handle gracefully
	var error = account.get_last_error()
	assert_gt(error.length(), 0, "Should have error message for wrong key size")

# Test 10: Unpickle with Wrong Key
func test_unpickle_wrong_key():
	account.initialize()

	var key1 = PackedByteArray()
	for i in range(32):
		key1.append(i)

	var pickle = account.pickle(key1)

	# Try to unpickle with different key
	var key2 = PackedByteArray()
	for i in range(32):
		key2.append(i + 1)

	var account2 = VodozemacAccount.new()
	var result = account2.from_pickle(pickle, key2)
	assert_ne(result, OK, "Unpickle with wrong key should fail")

# Test 11: Generate Zero Keys
func test_generate_zero_keys():
	account.initialize()
	var result = account.generate_one_time_keys(0)
	assert_eq(result, OK, "Generating 0 keys should succeed")
	var otk = account.get_one_time_keys()
	assert_eq(otk.size(), 0, "Should have 0 keys")

# Test 12: Multiple Account Instances
func test_multiple_accounts():
	var account1 = VodozemacAccount.new()
	var account2 = VodozemacAccount.new()

	account1.initialize()
	account2.initialize()

	var keys1 = account1.get_identity_keys()
	var keys2 = account2.get_identity_keys()

	# Each account should have unique keys
	assert_ne(keys1["ed25519"], keys2["ed25519"], "Accounts should have different keys")
	assert_ne(keys1["curve25519"], keys2["curve25519"], "Accounts should have different keys")
