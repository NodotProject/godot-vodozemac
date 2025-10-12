# Godot-Vodozemac API Reference

Complete API documentation for godot-vodozemac GDExtension.

## Table of Contents

- [VodozemacAccount](#vodozemacaccount)
- [VodozemacSession](#vodozemacsession)
- [VodozemacGroupSession](#vodozemacgroupsession)
- [VodozemacInboundGroupSession](#vodozemacinboundgroupsession)
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

## VodozemacGroupSession

The `VodozemacGroupSession` class represents an outbound group session for encrypting messages to multiple recipients using the Megolm ratchet.

### Overview

Group sessions enable efficient group messaging where a single encrypted message can be sent to multiple recipients. The sender creates one `VodozemacGroupSession` and shares the session key with all recipients, who each create their own `VodozemacInboundGroupSession`.

### Methods

#### `initialize() -> Error`

Creates a new group session with freshly generated keys and ratchet state.

**Returns:**
- `OK` (0) on success
- `FAILED` on error

**Example:**
```gdscript
var group_session = VodozemacGroupSession.new()
if group_session.initialize() != OK:
    push_error("Failed to initialize: " + group_session.get_last_error())
```

**Notes:**
- Must be called before any other operations
- Generates a new session ID and session key
- Initializes the message index to 0

---

#### `get_session_id() -> String`

Returns the unique identifier for this group session.

**Returns:**
Base64-encoded session ID string

**Example:**
```gdscript
var session_id = group_session.get_session_id()
print("Group session ID: ", session_id)
```

**Notes:**
- Session IDs are deterministic and unique
- All recipients with the same session key will have the same session ID
- Can be used to verify that all participants are in the same group

---

#### `encrypt(plaintext: String) -> Dictionary`

Encrypts a message for the group.

**Parameters:**
- `plaintext` (String): The message to encrypt

**Returns:**
Dictionary with the following keys:
- `"success"` (bool): Whether encryption succeeded
- `"ciphertext"` (String): Base64-encoded encrypted message
- `"error"` (String): Error message (if failed)

**Example:**
```gdscript
var result = group_session.encrypt("Hello everyone!")
if result["success"]:
    # Broadcast result["ciphertext"] to all group members
    broadcast_to_group(result["ciphertext"])
else:
    push_error("Encryption failed: " + result["error"])
```

**Notes:**
- Each encryption increments the message index
- The same ciphertext can be sent to all recipients
- Much more efficient than encrypting individually for each recipient

---

#### `get_session_key() -> String`

Returns the session key that recipients need to decrypt messages.

**Returns:**
Base64-encoded session key

**Example:**
```gdscript
var session_key = group_session.get_session_key()
# Distribute this key securely to all group members
# (e.g., via Olm 1:1 sessions)
```

**Security Notes:**
- ⚠️ This key must be distributed securely (e.g., via Olm encrypted channels)
- Anyone with this key can decrypt all past and future messages
- Never send session keys in plaintext
- Consider rotating keys regularly

---

#### `get_message_index() -> int`

Returns the current ratchet index (number of messages encrypted).

**Returns:**
Current message index (starts at 0)

**Example:**
```gdscript
var index = group_session.get_message_index()
print("Messages sent: ", index)
```

**Notes:**
- Increments after each `encrypt()` call
- Recipients use this to verify message ordering
- Can be used to detect missing messages

---

#### `pickle(key: PackedByteArray) -> String`

Serializes the group session for persistence.

**Parameters:**
- `key` (PackedByteArray): 32-byte encryption key

**Returns:**
Base64-encoded encrypted pickle string

**Example:**
```gdscript
var pickle_key = PackedByteArray()
pickle_key.resize(32)
# ... fill with secure random bytes ...

var pickle = group_session.pickle(pickle_key)
save_to_file("user://group_session.pickle", pickle)
```

**Notes:**
- Key MUST be exactly 32 bytes
- Preserves session state including message index
- Can continue encrypting after unpickling

---

#### `from_pickle(pickle: String, key: PackedByteArray) -> Error`

Restores a group session from a pickle.

**Parameters:**
- `pickle` (String): Base64-encoded encrypted pickle
- `key` (PackedByteArray): 32-byte decryption key (same as used for pickling)

**Returns:**
- `OK` on success
- `FAILED` on error

**Example:**
```gdscript
var pickle = load_from_file("user://group_session.pickle")
var group_session = VodozemacGroupSession.new()
if group_session.from_pickle(pickle, pickle_key) != OK:
    push_error("Failed to restore: " + group_session.get_last_error())
```

---

#### `get_last_error() -> String`

Returns the last error message for this group session.

**Returns:**
Error message string (empty if no error)

**Example:**
```gdscript
if group_session.initialize() != OK:
    print("Error: ", group_session.get_last_error())
```

---

## VodozemacInboundGroupSession

The `VodozemacInboundGroupSession` class represents an inbound group session for decrypting messages from a group sender.

### Overview

Recipients use inbound group sessions to decrypt messages encrypted by a `VodozemacGroupSession`. Multiple recipients can use the same session key, and each maintains their own inbound session independently.

### Methods

#### `initialize_from_session_key(session_key: String) -> Error`

Creates an inbound session from a session key provided by the sender.

**Parameters:**
- `session_key` (String): Base64-encoded session key from the sender

**Returns:**
- `OK` on success
- `FAILED` on error

**Example:**
```gdscript
var inbound_session = VodozemacInboundGroupSession.new()
if inbound_session.initialize_from_session_key(session_key) != OK:
    push_error("Failed to join group: " + inbound_session.get_last_error())
```

**Notes:**
- Session key must be received securely from the sender
- Creates a full session that can decrypt from message index 0
- All recipients share the same session key

---

#### `import_session(exported_key: String) -> Error`

Imports a session that was exported at a specific message index (for late joiners).

**Parameters:**
- `exported_key` (String): Base64-encoded exported session key

**Returns:**
- `OK` on success
- `FAILED` on error

**Example:**
```gdscript
# Charlie joins late, Bob exports the session for him
var export_result = bob_session.export_at_index(current_index)

var charlie_session = VodozemacInboundGroupSession.new()
if charlie_session.import_session(export_result["exported_key"]) != OK:
    push_error("Failed to import: " + charlie_session.get_last_error())
```

**Use Cases:**
- New members joining an existing group
- Limiting access to message history for privacy
- Key rotation without sharing full history

**Notes:**
- Imported sessions can only decrypt messages from the export index forward
- Cannot decrypt messages sent before the export point
- Use `get_first_known_index()` to check the earliest decryptable message

---

#### `get_session_id() -> String`

Returns the session identifier.

**Returns:**
Base64-encoded session ID string

**Example:**
```gdscript
var session_id = inbound_session.get_session_id()
# Should match the sender's session ID
```

**Notes:**
- Must match the sender's session ID
- Can be used to verify all participants are in the same group

---

#### `decrypt(ciphertext: String) -> Dictionary`

Decrypts a group message.

**Parameters:**
- `ciphertext` (String): Base64-encoded encrypted message

**Returns:**
Dictionary with the following keys:
- `"success"` (bool): Whether decryption succeeded
- `"plaintext"` (String): The decrypted message (if successful)
- `"message_index"` (int): The message's index in the ratchet
- `"error"` (String): Error message (if failed)

**Example:**
```gdscript
var result = inbound_session.decrypt(ciphertext)
if result["success"]:
    print("[%d] %s" % [result["message_index"], result["plaintext"]])
else:
    push_error("Decryption failed: " + result["error"])
```

**Notes:**
- Messages can be decrypted out of order
- Message index helps with ordering and detecting duplicates/gaps
- Each ciphertext can only be decrypted once per session

---

#### `get_first_known_index() -> int`

Returns the earliest message index this session can decrypt.

**Returns:**
First known index (0 for full sessions, higher for imported sessions)

**Example:**
```gdscript
var first_index = inbound_session.get_first_known_index()
if first_index > 0:
    print("This session can only decrypt messages from index ", first_index, " onwards")
```

**Notes:**
- Returns 0 for sessions created with `initialize_from_session_key()`
- Returns the export index for sessions created with `import_session()`
- Useful for determining message history visibility

---

#### `export_at_index(message_index: int) -> Dictionary`

Exports the session state at a specific message index for sharing with new members.

**Parameters:**
- `message_index` (int): The index to export from

**Returns:**
Dictionary with the following keys:
- `"success"` (bool): Whether export succeeded
- `"exported_key"` (String): Base64-encoded exported session key (if successful)
- `"error"` (String): Error message (if failed)

**Example:**
```gdscript
# Export for a late joiner at current message index
var current_index = sender.get_message_index()
var export_result = inbound_session.export_at_index(current_index)

if export_result["success"]:
    # Send exported_key to new member via secure channel
    send_to_new_member(export_result["exported_key"])
```

**Use Cases:**
- Onboarding new group members
- Key rotation
- Limiting message history access

**Security Notes:**
- Exported keys grant access to messages from the export point forward
- Only export to trusted parties
- Consider group policy for who can export sessions

---

#### `pickle(key: PackedByteArray) -> String`

Serializes the inbound group session for persistence.

**Parameters:**
- `key` (PackedByteArray): 32-byte encryption key

**Returns:**
Base64-encoded encrypted pickle string

**Example:**
```gdscript
var pickle = inbound_session.pickle(pickle_key)
save_to_file("user://inbound_session.pickle", pickle)
```

---

#### `from_pickle(pickle: String, key: PackedByteArray) -> Error`

Restores an inbound group session from a pickle.

**Parameters:**
- `pickle` (String): Encrypted pickle string
- `key` (PackedByteArray): 32-byte decryption key

**Returns:**
- `OK` on success
- `FAILED` on error

**Example:**
```gdscript
var pickle = load_from_file("user://inbound_session.pickle")
var inbound_session = VodozemacInboundGroupSession.new()
if inbound_session.from_pickle(pickle, pickle_key) != OK:
    push_error("Failed to restore: " + inbound_session.get_last_error())
```

---

#### `get_last_error() -> String`

Returns the last error message for this inbound group session.

**Returns:**
Error message string

**Example:**
```gdscript
if not result["success"]:
    print("Error: ", inbound_session.get_last_error())
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

### Megolm Session Keys

Group encryption uses session keys:
- **Session Key**: Shared by sender to all recipients for creating inbound sessions
- **Exported Session Key**: Session key exported at a specific message index for late joiners
- Both are base64-encoded strings

### Message Index

- Integer value tracking the position in the ratchet
- Starts at 0 and increments with each encrypted message
- Used for message ordering and detecting gaps
- Recipients receive the index with each decrypted message

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
  - [basic_encryption.gd](../examples/basic_encryption.gd) - Olm 1:1 encryption
  - [group_encryption.gd](../examples/group_encryption.gd) - Megolm group encryption
  - [late_joiner.gd](../examples/late_joiner.gd) - Late joiner scenario
  - [session_persistence.gd](../examples/session_persistence.gd) - Session persistence
- [Megolm Tutorial](MEGOLM_TUTORIAL.md) - Group encryption guide
- [Security Guide](SECURITY.md) - Security best practices
