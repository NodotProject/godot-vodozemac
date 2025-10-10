#include "vodozemac_session.h"
#include "vodozemac_account.h"
#include "godot_cpp/core/class_db.hpp"
#include "vodozemac/src/lib.rs.h"
#include <array>
#include <stdexcept>

using namespace godot;

void VodozemacSession::_bind_methods() {
    // Session operations
    ClassDB::bind_method(D_METHOD("get_session_id"), &VodozemacSession::get_session_id);
    ClassDB::bind_method(D_METHOD("session_matches", "message_type", "ciphertext"),
                        &VodozemacSession::session_matches);

    // Encryption/Decryption
    ClassDB::bind_method(D_METHOD("encrypt", "plaintext"), &VodozemacSession::encrypt);
    ClassDB::bind_method(D_METHOD("decrypt", "message_type", "ciphertext"), &VodozemacSession::decrypt);

    // Persistence
    ClassDB::bind_method(D_METHOD("pickle", "key"), &VodozemacSession::pickle);
    ClassDB::bind_method(D_METHOD("from_pickle", "pickle_str", "key"), &VodozemacSession::from_pickle);

    // Error handling
    ClassDB::bind_method(D_METHOD("get_last_error"), &VodozemacSession::get_last_error);
}

VodozemacSession::VodozemacSession() : session(nullptr) {
}

VodozemacSession::~VodozemacSession() {
    if (session) {
        delete session;
        session = nullptr;
    }
}

String VodozemacSession::get_session_id() {
    if (!session) {
        last_error = "Session not initialized";
        return "";
    }

    try {
        auto session_id_rust = (*session)->session_id();
        auto session_id_std = std::string(session_id_rust);
        last_error = "";
        return String(session_id_std.c_str());
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return "";
    }
}

bool VodozemacSession::session_matches(int message_type, const String& ciphertext) {
    if (!session) {
        last_error = "Session not initialized";
        return false;
    }

    try {
        // Create OlmMessage from parts
        olm::OlmMessageParts parts;
        parts.message_type = message_type;
        CharString cipher_cstr = ciphertext.utf8();
        parts.ciphertext = rust::String(std::string(cipher_cstr.get_data()));

        auto olm_message = olm::olm_message_from_parts(parts);

        bool matches = (*session)->session_matches(*olm_message);
        last_error = "";
        return matches;
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return false;
    }
}

Dictionary VodozemacSession::encrypt(const String& plaintext) {
    Dictionary result;
    result["success"] = false;

    if (!session) {
        last_error = "Session not initialized";
        result["error"] = last_error;
        return result;
    }

    try {
        // Convert plaintext to rust::Str
        CharString plaintext_cstr = plaintext.utf8();
        rust::Str plaintext_rust(plaintext_cstr.get_data(), plaintext_cstr.length());

        // Encrypt
        auto olm_message = (*session)->encrypt(plaintext_rust);

        // Convert to parts
        auto parts = olm_message->to_parts();

        result["success"] = true;
        result["message_type"] = (int)parts.message_type;
        result["ciphertext"] = String(std::string(parts.ciphertext).c_str());
        last_error = "";

    } catch (const std::exception& e) {
        last_error = String(e.what());
        result["error"] = last_error;
    }

    return result;
}

Dictionary VodozemacSession::decrypt(int message_type, const String& ciphertext) {
    Dictionary result;
    result["success"] = false;

    if (!session) {
        last_error = "Session not initialized";
        result["error"] = last_error;
        return result;
    }

    try {
        // Create OlmMessage from parts
        olm::OlmMessageParts parts;
        parts.message_type = message_type;
        CharString cipher_cstr = ciphertext.utf8();
        parts.ciphertext = rust::String(std::string(cipher_cstr.get_data()));

        auto olm_message = olm::olm_message_from_parts(parts);

        // Decrypt
        auto plaintext_rust = (*session)->decrypt(*olm_message);
        auto plaintext_std = std::string(plaintext_rust);

        result["success"] = true;
        result["plaintext"] = String(plaintext_std.c_str());
        last_error = "";

    } catch (const std::exception& e) {
        last_error = String(e.what());
        result["error"] = last_error;
    }

    return result;
}

String VodozemacSession::pickle(const PackedByteArray& key) {
    if (!session) {
        last_error = "Session not initialized";
        return "";
    }

    if (key.size() != 32) {
        last_error = "Key must be exactly 32 bytes";
        return "";
    }

    try {
        // Convert PackedByteArray to std::array<uint8_t, 32>
        std::array<uint8_t, 32> key_array;
        for (int i = 0; i < 32; i++) {
            key_array[i] = key[i];
        }

        auto pickle_rust_str = (*session)->pickle(key_array);
        auto pickle_std_str = std::string(pickle_rust_str);
        last_error = "";
        return String(pickle_std_str.c_str());
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return "";
    }
}

Error VodozemacSession::from_pickle(const String& pickle_str, const PackedByteArray& key) {
    if (key.size() != 32) {
        last_error = "Key must be exactly 32 bytes";
        return FAILED;
    }

    try {
        // Convert PackedByteArray to std::array<uint8_t, 32>
        std::array<uint8_t, 32> key_array;
        for (int i = 0; i < 32; i++) {
            key_array[i] = key[i];
        }

        // Convert String to rust::Str
        CharString pickle_cstr = pickle_str.utf8();
        rust::Str pickle_rust(pickle_cstr.get_data(), pickle_cstr.length());

        if (session) {
            delete session;
        }
        session = new rust::Box<olm::Session>(olm::session_from_pickle(pickle_rust, key_array));
        last_error = "";
        return OK;
    } catch (const std::exception& e) {
        last_error = String(e.what());
        if (session) {
            delete session;
        }
        session = nullptr;
        return FAILED;
    }
}

String VodozemacSession::get_last_error() const {
    return last_error;
}
