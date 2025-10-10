# Godot-Vodozemac API Reference

Complete API documentation for godot-vodozemac GDExtension.

## Table of Contents

- [VodozemacAccount](#vodozemacaccount)
- [VodozemacSession](#vodozemacsession)
- [Data Types](#data-types)
- [Error Handling](#error-handling)

---

## VodozemacAccount

The `VodozemacAccount` class represents a cryptographic account that manages identity keys and one-time keys for establishing encrypted sessions.

### Methods

#### `initialize() -> Error`

Initializes a new Olm account with freshly generated identity keys.

**Returns:**
- `OK` (0) on success
- `FAILED` on error

**Example:**
```gdscript
var account = VodozemacAccount.new()
if account.initialize() != OK:
    push_error("Failed to initialize: " + account.get_last_error())
```

---

#### `get_identity_keys() -> Dictionary`

Retrieves the account's identity keys (Ed25519 and Curve25519).

**Returns:**
Dictionary with the following keys:
- `"ed25519"` (String): Base64-encoded Ed25519 signing key
- `"curve25519"` (String): Base64-encoded Curve25519 encryption key

**Example:**
```gdscript
var keys = account.get_identity_keys()
print("Ed25519: ", keys["ed25519"])
print("Curve25519: ", keys["curve25519"])
```

**Notes:**
- Identity keys are stable for the lifetime of the account
- They should be shared with other parties to verify identity

---

#### `generate_one_time_keys(count: int) -> Error`

Generates a specified number of one-time pre-keys for session establishment.

**Parameters:**
- `count` (int): Number of keys to generate (typically 10-100)

**Returns:**
- `OK` on success
- `FAILED` on error

**Example:**
```gdscript
if account.generate_one_time_keys(10) != OK:
    push_error("Failed to generate keys: " + account.get_last_error())
```

**Notes:**
- Generate more keys than you expect to need to avoid running out
- Maximum number of keys is device-dependent (see `get_max_number_of_one_time_keys()`)

---

#### `get_one_time_keys() -> Dictionary`

Retrieves all unpublished one-time keys.

**Returns:**
Dictionary mapping key IDs (String) to base64-encoded Curve25519 keys (String).

**Example:**
```gdscript
var otks = account.get_one_time_keys()
for key_id in otks.keys():
    print("Key ID: ", key_id, " -> ", otks[key_id])

# Get a single OTK
var first_otk = otks.values()[0]
```

**Notes:**
- Returns empty dictionary if no unpublished keys exist
- Keys should be uploaded to a server and distributed to clients

---

#### `mark_keys_as_published() -> void`

Marks all one-time keys as published and clears them from memory.

**Example:**
```gdscript
# After uploading keys to server
account.mark_keys_as_published()
```

**Notes:**
- Call this after successfully uploading keys to prevent reuse
- After calling, `get_one_time_keys()` will return an empty dictionary

---

#### `get_max_number_of_one_time_keys() -> int`

Returns the maximum number of one-time keys that can be stored.

**Returns:**
Maximum OTK capacity (typically 50-100)

**Example:**
```gdscript
var max_keys = account.get_max_number_of_one_time_keys()
print("Can store up to ", max_keys, " one-time keys")
```

---

#### `pickle(key: PackedByteArray) -> String`

Serializes (pickles) the account to an encrypted string for persistence.

**Parameters:**
- `key` (PackedByteArray): 32-byte encryption key

**Returns:**
Base64-encoded encrypted pickle string

**Example:**
```gdscript
var key = PackedByteArray()
# ... fill with 32 random bytes ...

var pickle = account.pickle(key)
# Save `pickle` to file
var file = FileAccess.open("user://account.pickle", FileAccess.WRITE)
file.store_string(pickle)
file.close()
```

**Notes:**
- Key MUST be exactly 32 bytes
- Store the key securely (OS keychain, not plaintext)
- The pickle contains all account state (identity keys, one-time keys)

---

#### `from_pickle(pickle: String, key: PackedByteArray) -> Error`

Deserializes (unpickles) an account from an encrypted string.

**Parameters:**
- `pickle` (String): Base64-encoded encrypted pickle
- `key` (PackedByteArray): 32-byte decryption key (same as used for pickling)

**Returns:**
- `OK` on success
- `FAILED` on error (wrong key, corrupted data)

**Example:**
```gdscript
var file = FileAccess.open("user://account.pickle", FileAccess.READ)
var pickle = file.get_as_text()
file.close()

var account = VodozemacAccount.new()
if account.from_pickle(pickle, key) != OK:
    push_error("Failed to restore: " + account.get_last_error())
```

---

#### `create_outbound_session(identity_key: String, one_time_key: String) -> VodozemacSession`

Creates an outbound session to another party.

**Parameters:**
- `identity_key` (String): Recipient's Curve25519 identity key (base64)
- `one_time_key` (String): Recipient's one-time key (base64)

**Returns:**
`VodozemacSession` object, or `null` on error

**Example:**
```gdscript
var bob_identity = bob_account.get_identity_keys()
var bob_otk = bob_account.get_one_time_keys().values()[0]

var session = alice_account.create_outbound_session(
    bob_identity["curve25519"],
    bob_otk
)

if session == null:
    push_error("Failed: " + alice_account.get_last_error())
```

---

#### `create_inbound_session(identity_key: String, message_type: int, ciphertext: String) -> Dictionary`

Creates an inbound session from a pre-key message.

**Parameters:**
- `identity_key` (String): Sender's Curve25519 identity key (base64)
- `message_type` (int): Message type (should be 0 for pre-key messages)
- `ciphertext` (String): The encrypted pre-key message

**Returns:**
Dictionary with the following keys:
- `"success"` (bool): Whether session creation succeeded
- `"session"` (VodozemacSession): The created session (if successful)
- `"plaintext"` (String): The decrypted first message (if successful)
- `"error"` (String): Error message (if failed)

**Example:**
```gdscript
var alice_identity = alice_account.get_identity_keys()
var result = bob_account.create_inbound_session(
    alice_identity["curve25519"],
    encrypted_msg["message_type"],
    encrypted_msg["ciphertext"]
)

if result["success"]:
    var bob_session = result["session"]
    print("First message: ", result["plaintext"])
else:
    push_error("Failed: " + result["error"])
```

---

#### `get_last_error() -> String`

Returns the last error message for this account.

**Returns:**
Error message string (empty if no error)

**Example:**
```gdscript
if account.initialize() != OK:
    print("Error: ", account.get_last_error())
```

---

## VodozemacSession

The `VodozemacSession` class represents an encrypted communication channel between two parties.

### Methods

#### `get_session_id() -> String`

Returns a unique identifier for this session.

**Returns:**
Session ID string

**Example:**
```gdscript
var session_id = session.get_session_id()
print("Session ID: ", session_id)
```

**Notes:**
- Session IDs are unique and deterministic
- Can be used to identify sessions when managing multiple conversations

---

#### `session_matches(message_type: int, ciphertext: String) -> bool`

Checks if a pre-key message matches this session.

**Parameters:**
- `message_type` (int): Message type (0 for pre-key)
- `ciphertext` (String): The encrypted message

**Returns:**
`true` if the message matches this session, `false` otherwise

**Example:**
```gdscript
if session.session_matches(msg_type, ciphertext):
    print("This message belongs to this session")
```

**Notes:**
- Useful when managing multiple sessions
- Only works with pre-key messages (type 0)

---

#### `encrypt(plaintext: String) -> Dictionary`

Encrypts a plaintext message.

**Parameters:**
- `plaintext` (String): The message to encrypt

**Returns:**
Dictionary with the following keys:
- `"success"` (bool): Whether encryption succeeded
- `"message_type"` (int): 0 for PreKey message, 1 for Normal message
- `"ciphertext"` (String): Base64-encoded encrypted message
- `"error"` (String): Error message (if failed)

**Example:**
```gdscript
var result = session.encrypt("Hello, World!")
if result["success"]:
    print("Type: ", result["message_type"])
    print("Ciphertext: ", result["ciphertext"])
else:
    push_error("Encryption failed: " + result["error"])
```

**Notes:**
- First message is always PreKey type (0)
- Subsequent messages are Normal type (1)
- PreKey messages are larger but allow session establishment

---

#### `decrypt(message_type: int, ciphertext: String) -> Dictionary`

Decrypts an encrypted message.

**Parameters:**
- `message_type` (int): The message type (0 or 1)
- `ciphertext` (String): Base64-encoded encrypted message

**Returns:**
Dictionary with the following keys:
- `"success"` (bool): Whether decryption succeeded
- `"plaintext"` (String): The decrypted message (if successful)
- `"error"` (String): Error message (if failed)

**Example:**
```gdscript
var result = session.decrypt(msg_type, ciphertext)
if result["success"]:
    print("Decrypted: ", result["plaintext"])
else:
    push_error("Decryption failed: " + result["error"])
```

**Notes:**
- Message order matters - messages must be decrypted in the order sent
- Out-of-order decryption will fail
- Message type must match the actual message

---

#### `pickle(key: PackedByteArray) -> String`

Serializes (pickles) the session for persistence.

**Parameters:**
- `key` (PackedByteArray): 32-byte encryption key

**Returns:**
Base64-encoded encrypted pickle string

**Example:**
```gdscript
var key = create_32_byte_key()
var pickle = session.pickle(key)
# Save to file...
```

**Notes:**
- Same requirements as `VodozemacAccount.pickle()`
- Preserves all session state including ratchet state

---

#### `from_pickle(pickle: String, key: PackedByteArray) -> Error`

Deserializes (unpickles) a session.

**Parameters:**
- `pickle` (String): Encrypted pickle string
- `key` (PackedByteArray): 32-byte decryption key

**Returns:**
- `OK` on success
- `FAILED` on error

**Example:**
```gdscript
var session = VodozemacSession.new()
if session.from_pickle(pickle, key) != OK:
    push_error("Failed: " + session.get_last_error())
```

---

#### `get_last_error() -> String`

Returns the last error message for this session.

**Returns:**
Error message string

**Example:**
```gdscript
if not result["success"]:
    print("Error: ", session.get_last_error())
```

---

## Data Types

### Message Types

| Type | Value | Description |
|------|-------|-------------|
| PreKey | 0 | Initial message that establishes a session |
| Normal | 1 | Regular message in an established session |

### Identity Keys

Each account has two identity keys:
- **Ed25519**: Used for signing (authentication)
- **Curve25519**: Used for encryption (key agreement)

Both are base64-encoded strings.

### One-Time Keys

- Single-use Curve25519 keys for session establishment
- Base64-encoded strings
- Identified by unique key IDs

---

## Error Handling

### Error Enum Values

Functions return Godot's `Error` enum:
- `OK` (0): Success
- `FAILED` (1): Generic failure

### Getting Error Details

Use `get_last_error()` to get a human-readable error message:

```gdscript
if account.initialize() != OK:
    var error = account.get_last_error()
    push_error("Initialization failed: " + error)
```

### Dictionary Return Values

Some methods return dictionaries with a `"success"` key:

```gdscript
var result = session.encrypt("message")
if not result["success"]:
    push_error("Error: " + result.get("error", "Unknown error"))
```

### Common Error Scenarios

1. **Invalid Key Size**
   - Pickle keys must be exactly 32 bytes
   - Check key length before calling `pickle()` or `from_pickle()`

2. **Wrong Decryption Key**
   - `from_pickle()` will fail if the key doesn't match
   - Error message will indicate decryption failure

3. **Corrupted Ciphertext**
   - `decrypt()` will fail if ciphertext is modified
   - Base64 decoding errors will be reported

4. **Null Pointer**
   - Calling methods on uninitialized objects
   - Always check return values of creation methods

---

## Best Practices

### 1. Always Check Return Values

```gdscript
# Good
if account.initialize() != OK:
    handle_error()

# Bad
account.initialize()  # Ignores errors!
```

### 2. Store Encryption Keys Securely

```gdscript
# Good: Use OS keychain
var key = OS.get_keychain_value("vodozemac_key")

# Bad: Hardcode keys
var key = [1, 2, 3, ...]  # Never do this!
```

### 3. Verify Identity Keys Out-of-Band

```gdscript
# After exchanging keys, verify them via another channel
var fingerprint = identity_key.sha256_text()
print("Verify this fingerprint: ", fingerprint.substr(0, 8))
```

### 4. Handle Session Lifecycle

```gdscript
# Create session
var session = account.create_outbound_session(...)

# Use session for communication
session.encrypt("message 1")
session.encrypt("message 2")

# Persist session before closing app
var pickle = session.pickle(key)
save_to_file(pickle)
```

---

## See Also

- [Examples](../examples/) - Practical usage examples
- [Tutorial](TUTORIAL.md) - Step-by-step guide
- [Security Guide](SECURITY.md) - Security best practices
- [Architecture](ARCHITECTURE.md) - Internal design
