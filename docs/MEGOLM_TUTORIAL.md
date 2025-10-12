# Megolm Group Encryption Tutorial

This tutorial will guide you through implementing secure group messaging in your Godot project using Megolm (group encryption).

## Table of Contents

1. [Introduction](#introduction)
2. [Basic Concepts](#basic-concepts)
3. [Creating a Group Session](#creating-a-group-session)
4. [Adding Recipients](#adding-recipients)
5. [Sending Group Messages](#sending-group-messages)
6. [Handling Late Joiners](#handling-late-joiners)
7. [Session Persistence](#session-persistence)
8. [Key Rotation](#key-rotation)
9. [Best Practices](#best-practices)
10. [Security Considerations](#security-considerations)

---

## Introduction

Megolm is a cryptographic ratchet designed for efficient group messaging. Unlike Olm (1:1 encryption), where you must encrypt separately for each recipient, Megolm allows you to encrypt a message once and send the same ciphertext to all group members.

### When to Use Megolm

- **Group chats** with 3+ participants
- **Broadcast channels** where one sender reaches many recipients
- **Team collaboration** tools
- **In-game chat systems** with multiple players

### When NOT to Use Megolm

- **1:1 conversations** (use Olm instead for better forward secrecy)
- **Small 2-person chats** (Olm is more secure)
- **Scenarios requiring perfect forward secrecy** per message

---

## Basic Concepts

### Roles

1. **Sender**: Creates the `VodozemacGroupSession` and encrypts messages
2. **Recipients**: Create `VodozemacInboundGroupSession` and decrypt messages

### Key Components

- **Session Key**: Shared secret that all recipients need
- **Session ID**: Unique identifier for the group
- **Message Index**: Sequential number for each message (prevents replay attacks)

### Workflow

```
1. Sender creates GroupSession
2. Sender generates session_key
3. Sender distributes session_key to recipients (via secure channel)
4. Recipients create InboundGroupSession from session_key
5. Sender encrypts message → all recipients can decrypt
```

---

## Creating a Group Session

The sender (typically the group creator) initializes a group session:

```gdscript
# Alice creates a group
var alice_group = VodozemacGroupSession.new()
if alice_group.initialize() != OK:
    push_error("Failed to create group: " + alice_group.get_last_error())
    return

# Get the session key to share with members
var session_key = alice_group.get_session_key()
var session_id = alice_group.get_session_id()

print("Group created!")
print("Session ID: ", session_id)
print("Session key: ", session_key)
```

### Important Notes

- The session key must be **distributed securely**
- **Never** send session keys in plaintext
- Use Olm (1:1 encryption) to send session keys to each recipient
- Store the session key safely if you need to persist it

---

## Adding Recipients

Recipients join the group by creating an inbound session from the session key:

```gdscript
# Bob receives the session key from Alice (via secure channel)
var bob_session = VodozemacInboundGroupSession.new()
if bob_session.initialize_from_session_key(session_key) != OK:
    push_error("Failed to join: " + bob_session.get_last_error())
    return

# Verify the session ID matches
if bob_session.get_session_id() != alice_group.get_session_id():
    push_error("Session ID mismatch!")
    return

print("Bob joined the group!")
```

### Multiple Recipients

```gdscript
# Add multiple recipients
var recipients = []
for member in group_members:
    var inbound = VodozemacInboundGroupSession.new()
    if inbound.initialize_from_session_key(session_key) == OK:
        recipients.append(inbound)
        print(member.name, " joined")
```

---

## Sending Group Messages

Once the group is set up, the sender encrypts messages:

```gdscript
# Alice sends a message
var plaintext = "Hello everyone!"
var encrypted = alice_group.encrypt(plaintext)

if not encrypted["success"]:
    push_error("Encryption failed: " + encrypted["error"])
    return

var ciphertext = encrypted["ciphertext"]
var message_index = alice_group.get_message_index() - 1

# Broadcast the ciphertext to all members
broadcast_to_group(ciphertext)
```

### Recipients Decrypt

All recipients decrypt using the same ciphertext:

```gdscript
# Bob decrypts
var decrypted = bob_session.decrypt(ciphertext)
if decrypted["success"]:
    print("[%d] %s" % [decrypted["message_index"], decrypted["plaintext"]])
else:
    push_error("Decryption failed: " + decrypted["error"])

# Charlie decrypts (same ciphertext!)
var decrypted2 = charlie_session.decrypt(ciphertext)
if decrypted2["success"]:
    print("[%d] %s" % [decrypted2["message_index"], decrypted2["plaintext"]])
```

### Message Ordering

The message index helps maintain order:

```gdscript
# Store messages with their indices
var messages = {}

func on_receive_message(ciphertext: String):
    var decrypted = session.decrypt(ciphertext)
    if decrypted["success"]:
        var index = decrypted["message_index"]
        messages[index] = decrypted["plaintext"]

        # Display messages in order
        display_messages_in_order()

func display_messages_in_order():
    var indices = messages.keys()
    indices.sort()
    for index in indices:
        print("[%d] %s" % [index, messages[index]])
```

---

## Handling Late Joiners

When a new member joins an existing group, you can limit their access to message history using export/import:

### Exporting for a Late Joiner

An existing member exports the session at the current index:

```gdscript
# Current state: 10 messages have been sent

# Bob exports the session for Charlie (late joiner)
var current_index = alice_group.get_message_index()
var export_result = bob_session.export_at_index(current_index)

if not export_result["success"]:
    push_error("Export failed: " + export_result["error"])
    return

var exported_key = export_result["exported_key"]

# Send exported_key to Charlie via secure channel
send_to_charlie(exported_key)
```

### Importing as a Late Joiner

```gdscript
# Charlie imports the session
var charlie_session = VodozemacInboundGroupSession.new()
if charlie_session.import_session(exported_key) != OK:
    push_error("Import failed: " + charlie_session.get_last_error())
    return

# Check what Charlie can access
var first_index = charlie_session.get_first_known_index()
print("Charlie can decrypt messages from index ", first_index, " onwards")

# Charlie CANNOT decrypt old messages (before index 10)
# Charlie CAN decrypt new messages (from index 10+)
```

### Benefits of Export/Import

1. **Message History Privacy**: New members can't see old messages
2. **Reduced Data Transfer**: Don't need to send full history
3. **Security**: Limits exposure if session key is compromised later

---

## Session Persistence

Both senders and recipients can save their sessions:

### Saving a Group Session

```gdscript
# Generate a secure pickle key (32 bytes)
var pickle_key = generate_secure_key_32_bytes()

# Save Alice's sender session
var pickle = alice_group.pickle(pickle_key)
var file = FileAccess.open("user://alice_group.pickle", FileAccess.WRITE)
file.store_string(pickle)
file.close()

print("Session saved!")
```

### Restoring a Group Session

```gdscript
# Load the pickle
var file = FileAccess.open("user://alice_group.pickle", FileAccess.READ)
var pickle = file.get_as_text()
file.close()

# Restore the session
var alice_group = VodozemacGroupSession.new()
if alice_group.from_pickle(pickle, pickle_key) != OK:
    push_error("Failed to restore: " + alice_group.get_last_error())
    return

# Alice can continue from where she left off
print("Restored at message index: ", alice_group.get_message_index())
```

### Saving Recipient Sessions

```gdscript
# Same process for recipients
var pickle = bob_session.pickle(pickle_key)
save_to_file("user://bob_session.pickle", pickle)

# Restore
var bob_session = VodozemacInboundGroupSession.new()
bob_session.from_pickle(pickle, pickle_key)
```

---

## Key Rotation

For better security, rotate group keys periodically:

### When to Rotate

- **Periodically**: Every 100-1000 messages
- **Member leaves**: When someone leaves the group
- **Compromise suspected**: If a key might be exposed
- **Time-based**: Daily or weekly for sensitive groups

### How to Rotate

```gdscript
# 1. Alice creates a NEW group session
var new_session = VodozemacGroupSession.new()
new_session.initialize()
var new_session_key = new_session.get_session_key()

# 2. Distribute new session key to all current members
for member in current_members:
    send_session_key_securely(member, new_session_key)

# 3. Members create new inbound sessions
var new_inbound = VodozemacInboundGroupSession.new()
new_inbound.initialize_from_session_key(new_session_key)

# 4. Switch to using the new session
alice_group = new_session  # Use new session for future messages

# 5. Keep old session for a grace period (optional)
# Some members might still be receiving old messages
```

### Rotation Best Practices

- Announce rotation in advance
- Support both old and new sessions temporarily
- Clean up old sessions after grace period
- Log rotation events for debugging

---

## Best Practices

### 1. Secure Key Distribution

**DO:**
```gdscript
# Use Olm 1:1 sessions to send group keys
var olm_session = alice_account.create_outbound_session(
    bob_identity, bob_one_time_key
)
var encrypted = olm_session.encrypt(group_session_key)
send_to_bob(encrypted["ciphertext"])
```

**DON'T:**
```gdscript
# NEVER send keys in plaintext
send_to_bob(group_session_key)  # ❌ INSECURE!
```

### 2. Handle Out-of-Order Messages

```gdscript
var pending_messages = {}
var last_displayed_index = -1

func on_message_received(ciphertext):
    var result = session.decrypt(ciphertext)
    if result["success"]:
        var index = result["message_index"]
        pending_messages[index] = result["plaintext"]
        display_sequential_messages()

func display_sequential_messages():
    var next_index = last_displayed_index + 1
    while pending_messages.has(next_index):
        print("[%d] %s" % [next_index, pending_messages[next_index]])
        pending_messages.erase(next_index)
        last_displayed_index = next_index
        next_index += 1
```

### 3. Detect Missing Messages

```gdscript
func check_for_gaps(new_index: int):
    var expected_index = last_received_index + 1
    if new_index > expected_index:
        var gap_size = new_index - expected_index
        push_warning("Missing %d messages (indices %d to %d)" % [
            gap_size, expected_index, new_index - 1
        ])
        # Request retransmission from server
        request_missing_messages(expected_index, new_index - 1)
```

### 4. Store Pickle Keys Securely

```gdscript
# Good: Use OS keychain
var pickle_key = OS.get_keychain_data("megolm_pickle_key")
if pickle_key.is_empty():
    pickle_key = generate_secure_key_32_bytes()
    OS.set_keychain_data("megolm_pickle_key", pickle_key)

# Bad: Store in user:// as plaintext
# var pickle_key = load_from_file("user://pickle_key.dat")  # ❌ INSECURE!
```

### 5. Error Handling

```gdscript
func handle_encryption_error(error: String):
    match error:
        "Session not initialized":
            # Recreate session
            pass
        "Invalid key size":
            # Check pickle key
            pass
        _:
            push_error("Unexpected error: " + error)
```

---

## Security Considerations

### Forward Secrecy Limitation

⚠️ **Important**: Megolm provides **limited forward secrecy**

- If a session key is compromised, all messages are compromised
- Past messages can be decrypted if the attacker has the session key
- Future messages can also be decrypted

**Mitigation:**
- Rotate keys frequently (every 100-1000 messages)
- Use Olm for highly sensitive 1:1 conversations
- Consider the sensitivity of your data when choosing Megolm

### Authentication

Megolm does **not** provide sender authentication:

- Recipients trust the sender based on who gave them the session key
- An attacker with the session key can impersonate the sender
- Verify sender identity through out-of-band means

**Mitigation:**
- Verify identity keys when establishing Olm sessions
- Use device verification (SAS, QR codes)
- Display sender identity in the UI

### Replay Attacks

Message indices prevent replay attacks:

```gdscript
var seen_indices = {}

func is_replay(message_index: int) -> bool:
    if seen_indices.has(message_index):
        return true  # This is a replay!
    seen_indices[message_index] = true
    return false
```

### Key Compromise

If you suspect a key is compromised:

1. **Immediately** create a new session with a new key
2. **Distribute** the new key via secure channels
3. **Revoke** the old session (stop using it)
4. **Log** the incident for security audit
5. **Notify** all members of the key rotation

---

## Complete Example

Here's a complete example of a group chat implementation:

```gdscript
extends Node

class_name SecureGroupChat

# Group state
var group_session: VodozemacGroupSession
var inbound_sessions = {}  # member_id -> VodozemacInboundGroupSession
var session_key: String
var is_sender: bool = false

# Message history
var messages = {}  # index -> {sender: String, text: String, timestamp: int}
var last_displayed_index = -1

func create_group() -> Error:
    """Called by the group creator"""
    group_session = VodozemacGroupSession.new()
    if group_session.initialize() != OK:
        return FAILED

    session_key = group_session.get_session_key()
    is_sender = true

    print("Group created: ", group_session.get_session_id())
    return OK

func join_group(key: String) -> Error:
    """Called by group members"""
    session_key = key
    var inbound = VodozemacInboundGroupSession.new()
    if inbound.initialize_from_session_key(session_key) != OK:
        return FAILED

    inbound_sessions[get_my_id()] = inbound
    is_sender = false

    print("Joined group: ", inbound.get_session_id())
    return OK

func send_message(text: String):
    """Send a message to the group"""
    if not is_sender:
        push_error("Only the sender can encrypt messages")
        return

    var result = group_session.encrypt(text)
    if result["success"]:
        var index = group_session.get_message_index() - 1
        broadcast_to_network({
            "ciphertext": result["ciphertext"],
            "sender_id": get_my_id(),
            "timestamp": Time.get_unix_time_from_system()
        })

func on_message_received(data: Dictionary):
    """Handle incoming message"""
    var session = inbound_sessions.get(get_my_id())
    if not session:
        push_error("No inbound session available")
        return

    var result = session.decrypt(data["ciphertext"])
    if result["success"]:
        var index = result["message_index"]
        messages[index] = {
            "sender": data["sender_id"],
            "text": result["plaintext"],
            "timestamp": data["timestamp"]
        }
        display_new_messages()

func display_new_messages():
    """Display messages in order"""
    var next_index = last_displayed_index + 1
    while messages.has(next_index):
        var msg = messages[next_index]
        display_message(msg["sender"], msg["text"], msg["timestamp"])
        last_displayed_index = next_index
        next_index += 1

func display_message(sender: String, text: String, timestamp: int):
    print("[%s] %s: %s" % [
        Time.get_datetime_string_from_unix_time(timestamp),
        sender,
        text
    ])

# Implement these based on your networking solution
func broadcast_to_network(data: Dictionary):
    pass

func get_my_id() -> String:
    return ""
```

---

## Conclusion

Megolm provides efficient group encryption for Godot applications. Key takeaways:

1. ✅ Use Megolm for group chats (3+ people)
2. ✅ Distribute session keys securely via Olm
3. ✅ Rotate keys regularly for better security
4. ✅ Handle message ordering with indices
5. ✅ Use export/import for late joiners
6. ⚠️ Remember: Megolm has limited forward secrecy

For more examples, see:
- [group_encryption.gd](https://github.com/NodotProject/godot-vodozemac/blob/main/examples/group_encryption.gd) - Basic group chat
- [late_joiner.gd](https://github.com/NodotProject/godot-vodozemac/blob/main/examples/late_joiner.gd) - Late joiner scenario

For API details, see:
- [API Reference](API.md) - Complete API documentation

Happy secure coding! 🔐
