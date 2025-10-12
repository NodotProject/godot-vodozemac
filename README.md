# Godot-Vodozemac

<p align="center">
    <img width="512" height="512" alt="image" src="https://github.com/NodotProject/godot-vodozemac/blob/main/docs/web-app-manifest-512x512.png?raw=true" />
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Discord](https://img.shields.io/discord/1089846386566111322)](https://discord.gg/Rx9CZX4sjG) [![Mastodon](https://img.shields.io/mastodon/follow/110106863700290562?domain=mastodon.gamedev.place)](https://mastodon.gamedev.place/@krazyjakee) [![Youtube](https://img.shields.io/youtube/channel/subscribers/UColWkNMgHseKyU7D1QGeoyQ)](https://www.youtube.com/@GodotNodot) [![GitHub Sponsors](https://img.shields.io/github/sponsors/krazyjakee)](https://github.com/sponsors/krazyjakee) [![GitHub Stars](https://img.shields.io/github/stars/NodotProject/godot-vodozemac)](https://github.com/NodotProject/godot-vodozemac)

**End-to-end encryption for Godot using the Matrix.org Olm & Megolm protocols**

Godot-Vodozemac is a GDExtension that brings battle-tested end-to-end encryption to Godot Engine projects. It wraps the [vodozemac](https://github.com/matrix-org/vodozemac) Rust library (the modern implementation of the Olm/Megolm ratchets used by Matrix) and provides an easy-to-use GDScript API.

## ✨ Features

- ✅ **Olm (1:1 Encryption)** - Secure peer-to-peer messaging with Double Ratchet
- ✅ **Megolm (Group Encryption)** - Efficient group messaging for 3+ participants
- ✅ **Session Persistence** - Save and restore encrypted sessions
- ✅ **Cross-Platform** - Works on Linux, Windows, and macOS
- ✅ **Memory Safe** - Rust-powered cryptography with automatic memory management
- ✅ **Well-Tested** - Comprehensive test suite with 25+ integration tests

## 📋 Requirements

- **Godot Engine** 4.5 or later
- **Platforms**: Linux (x86_64), Windows (x86_64), macOS (x86_64, ARM64)
- For building from source:
  - Python 3.6+
  - SCons 4.0+
  - Rust 1.70+
  - GCC/Clang (Linux), MSVC (Windows), or Xcode (macOS)

## 🚀 Quick Start

### Installation

#### Option 1: Pre-built Binaries (Recommended)

1. Download the latest release from [Releases](https://github.com/NodotProject/godot-vodozemac/releases)
2. Extract the `addons/godot-vodozemac/` folder into your project's `addons/` directory
3. Restart Godot or reload the project

#### Option 2: Build from Source

```bash
# 1. Clone the repository
git clone https://github.com/NodotProject/godot-vodozemac.git
cd godot-vodozemac

# 2. Initialize submodules
git submodule update --init --recursive

# 3. Install the GUT testing addon (for running tests)
git clone https://github.com/bitwes/Gut.git gut_temp
mv gut_temp/addons/gut addons/
rm -rf gut_temp

# 4. Build the extension
./build_local.sh

# 5. Copy the addon to your project
cp -r addons/godot-vodozemac /path/to/your/project/addons/
```

### Basic Usage

```gdscript
extends Node

func _ready():
    # Create accounts for two parties
    var alice = VodozemacAccount.new()
    var bob = VodozemacAccount.new()

    alice.initialize()
    bob.initialize()

    # Bob generates one-time keys
    bob.generate_one_time_keys(10)

    # Alice creates an outbound session to Bob
    var bob_identity = bob.get_identity_keys()
    var bob_otk = bob.get_one_time_keys().values()[0]

    var alice_session = alice.create_outbound_session(
        bob_identity["curve25519"],
        bob_otk
    )

    # Alice encrypts a message
    var encrypted = alice_session.encrypt("Hello, Bob!")
    print("Encrypted: ", encrypted["ciphertext"])

    # Bob creates inbound session and decrypts
    var alice_identity = alice.get_identity_keys()
    var bob_inbound = bob.create_inbound_session(
        alice_identity["curve25519"],
        encrypted["message_type"],
        encrypted["ciphertext"]
    )

    print("Decrypted: ", bob_inbound["plaintext"])  # "Hello, Bob!"
```

### Group Encryption (Megolm)

```gdscript
extends Node

func _ready():
    # Alice creates a group session
    var alice_group = VodozemacGroupSession.new()
    alice_group.initialize()

    # Get session key to share with members
    var session_key = alice_group.get_session_key()

    # Bob and Charlie join the group
    var bob_session = VodozemacInboundGroupSession.new()
    bob_session.initialize_from_session_key(session_key)

    var charlie_session = VodozemacInboundGroupSession.new()
    charlie_session.initialize_from_session_key(session_key)

    # Alice sends one message to everyone
    var encrypted = alice_group.encrypt("Hello everyone!")

    # Both Bob and Charlie decrypt the same ciphertext
    var bob_msg = bob_session.decrypt(encrypted["ciphertext"])
    var charlie_msg = charlie_session.decrypt(encrypted["ciphertext"])

    print("Bob received: ", bob_msg["plaintext"])
    print("Charlie received: ", charlie_msg["plaintext"])
```

See [`examples/`](examples/) for more detailed examples including session persistence and late joiners.

## 📚 Documentation

- **[API Reference](docs/API.md)** - Complete API documentation
- **[Megolm Tutorial](docs/MEGOLM_TUTORIAL.md)** - Group encryption guide with best practices

## 🏗️ Architecture

```
┌───────────────────────────────────────────────────────────┐
│               GDScript (Your Game)                        │
│  VodozemacAccount │ VodozemacSession │ VodozemacGroupSession  │
│                   │                  │ VodozemacInboundGroupSession │
└──────────────────────┬────────────────────────────────────┘
               │ GDExtension Bindings
┌──────────────▼──────────────────────────┐
│           C++ Wrapper Layer            │
│   (vodozemac_account.cpp/h,            │
│    vodozemac_session.cpp/h)            │
└──────────────┬──────────────────────────┘
               │ FFI (cxx crate)
┌──────────────▼──────────────────────────┐
│         vodozemac-ffi (Rust)           │
│    Matrix.org's Olm/Megolm impl        │
└─────────────────────────────────────────┘
```

The extension uses a three-layer architecture:
1. **GDScript API** - High-level, Godot-native interface
2. **C++ Wrapper** - RAII memory management and GDExtension bindings
3. **Rust FFI** - The vodozemac cryptographic implementation

## 🔧 Building from Source

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install build-essential scons python3 clang libssl-dev

# macOS
brew install scons python3

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Build Steps

```bash
# 1. Clone the repository and initialize submodules
git clone https://github.com/NodotProject/godot-vodozemac.git
cd godot-vodozemac
git submodule update --init --recursive

# 2. Install the GUT addon (optional, for tests)
git clone https://github.com/bitwes/Gut.git gut_temp
mv gut_temp/addons/gut addons/
rm -rf gut_temp

# 3. Build vodozemac-ffi (Rust)
cd vodozemac-ffi/cpp
cargo build --release
cd ../..

# 4. Build godot-cpp
cd godot-cpp
scons platform=linux target=template_release
cd ..

# 5. Build the GDExtension
scons platform=linux target=template_release

# The binary will be in addons/godot-vodozemac/bin/
```

### Development Setup

```bash
# 1. Clone and setup submodules
git clone https://github.com/NodotProject/godot-vodozemac.git
cd godot-vodozemac
git submodule update --init --recursive

# 2. Install GUT
git clone https://github.com/bitwes/Gut.git gut_temp
mv gut_temp/addons/gut addons/
rm -rf gut_temp

# 3. Build for development
./build_local.sh

# 4. Run tests
./run_tests.sh
```

## 🔐 Security

### General
- Always verify identity keys out-of-band to prevent MITM attacks
- Store pickle encryption keys securely (use OS keychain, not plaintext files)
- Generate new one-time keys regularly and mark used keys as published
- Use secure random number generators (provided by vodozemac)

### Megolm-Specific
- **⚠️ Limited Forward Secrecy**: Megolm session keys can decrypt all past and future messages
- **Rotate Keys Frequently**: Change group session keys every 100-1000 messages or when members leave
- **Secure Key Distribution**: Always distribute session keys via encrypted Olm 1:1 sessions
- **Use Olm for Sensitive 1:1**: For highly sensitive conversations, use Olm instead of Megolm

See [Megolm Tutorial](docs/MEGOLM_TUTORIAL.md) for detailed security best practices.


## 🙏 Acknowledgments

- [Matrix.org](https://matrix.org/) for the vodozemac library and Olm protocol
- [Godot Engine](https://godotengine.org/) community
- The Signal Protocol team for the original Double Ratchet design

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

- **vodozemac** - Apache 2.0 License ([matrix-org/vodozemac](https://github.com/matrix-org/vodozemac))
- **godot-cpp** - MIT License ([godotengine/godot-cpp](https://github.com/godotengine/godot-cpp))

## 💖 Support Me
Hi! I’m krazyjakee 🎮, creator and maintain­er of the *NodotProject* - a suite of open‑source Godot tools (e.g. Nodot, Gedis, GedisQueue etc) that empower game developers to build faster and maintain cleaner code.

I’m looking for sponsors to help sustain and grow the project: more dev time, better docs, more features, and deeper community support. Your support means more stable, polished tools used by indie makers and studios alike.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/krazyjakee)

Every contribution helps maintain and improve this project. And encourage me to make more projects like this!

*This is optional support. The tool remains free and open-source regardless.*

---

**Created with ❤️ for Godot Developers**  
For contributions, please open PRs on GitHub
