# Godot-Vodozemac Examples

This directory contains example scripts demonstrating how to use the godot-vodozemac GDExtension for end-to-end encryption in your Godot projects.

## Available Examples

### 1. Basic Encryption (`basic_encryption.gd`)

A comprehensive introduction to the core functionality:
- Creating accounts for two parties (Alice and Bob)
- Generating and exchanging identity keys
- Generating one-time keys for session establishment
- Creating outbound and inbound sessions
- Encrypting and decrypting messages
- Understanding PreKey vs Normal message types

**Best for:** First-time users learning the basics.

### 2. Session Persistence (`session_persistence.gd`)

Demonstrates how to save and restore encrypted sessions:
- Pickling (serializing) accounts and sessions
- Unpickling (deserializing) to restore state
- Continuing conversations after application restart
- Secure key management considerations

**Best for:** Applications that need to persist encrypted chat state.

## Running the Examples

### In Godot Editor

1. Open the project in Godot 4.1+
2. Attach an example script to a Node in your scene
3. Run the scene
4. Check the Output tab for results

### From Command Line

```bash
# Make sure the extension is built first
./build_local.sh

# Run an example (requires Godot in PATH)
godot --headless --script examples/basic_encryption.gd
```

## Example Structure

Each example follows a similar pattern:

```gdscript
extends Node

func _ready():
    # Example code here
    # All examples are self-contained and print results
```

## Common Patterns

### Creating an Account

```gdscript
var account = VodozemacAccount.new()
if account.initialize() != OK:
    push_error("Failed to initialize: " + account.get_last_error())
```

### Establishing a Session

```gdscript
# Sender creates outbound session
var session = sender_account.create_outbound_session(
    receiver_identity_key,
    receiver_one_time_key
)

# Receiver creates inbound session from first message
var result = receiver_account.create_inbound_session(
    sender_identity_key,
    message_type,
    ciphertext
)
var receiver_session = result["session"]
var plaintext = result["plaintext"]
```

### Encrypting/Decrypting

```gdscript
# Encrypt
var result = session.encrypt("Hello, World!")
if result["success"]:
    var message_type = result["message_type"]  # 0 = PreKey, 1 = Normal
    var ciphertext = result["ciphertext"]

# Decrypt
var result = session.decrypt(message_type, ciphertext)
if result["success"]:
    var plaintext = result["plaintext"]
```

### Persistence

```gdscript
# Save (pickle)
var key = create_32_byte_key()  # Must be 32 bytes!
var pickle = account.pickle(key)
# Save `pickle` string to disk

# Restore (unpickle)
var account = VodozemacAccount.new()
var result = account.from_pickle(pickle, key)
if result != OK:
    push_error("Failed to restore: " + account.get_last_error())
```

## Error Handling

Always check return values and handle errors:

```gdscript
var result = account.generate_one_time_keys(10)
if result != OK:
    var error = account.get_last_error()
    push_error("Operation failed: " + error)
```

For Dictionary returns (encrypt, decrypt, create_inbound_session):

```gdscript
var result = session.encrypt("message")
if not result["success"]:
    push_error("Encryption failed: " + result.get("error", "Unknown"))
```

## Security Considerations

1. **Key Storage**: Encryption keys (for pickling) should be stored securely, not hardcoded
2. **Identity Verification**: Always verify identity keys out-of-band to prevent MITM attacks
3. **One-Time Keys**: Mark keys as published after use to prevent reuse
4. **Key Rotation**: Generate new one-time keys regularly

## Further Reading

- See the main [README.md](../README.md) for installation and building
- See [docs/](../docs/) for detailed API documentation
- Check [tests/integration/](../tests/integration/) for more usage examples

## Contributing Examples

Found a useful pattern? Consider contributing an example!
1. Create a new `.gd` file in this directory
2. Add documentation comments
3. Add it to this README
4. Submit a pull request
