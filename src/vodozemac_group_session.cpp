#include "vodozemac_group_session.h"
#include "godot_cpp/core/class_db.hpp"
#include "vodozemac/src/lib.rs.h"
#include <array>
#include <stdexcept>

using namespace godot;

void VodozemacGroupSession::_bind_methods() {
    // Session operations
    ClassDB::bind_method(D_METHOD("initialize"), &VodozemacGroupSession::initialize);
    ClassDB::bind_method(D_METHOD("get_session_id"), &VodozemacGroupSession::get_session_id);
    ClassDB::bind_method(D_METHOD("encrypt", "plaintext"), &VodozemacGroupSession::encrypt);
    ClassDB::bind_method(D_METHOD("get_session_key"), &VodozemacGroupSession::get_session_key);
    ClassDB::bind_method(D_METHOD("get_message_index"), &VodozemacGroupSession::get_message_index);

    // Persistence
    ClassDB::bind_method(D_METHOD("pickle", "key"), &VodozemacGroupSession::pickle);
    ClassDB::bind_method(D_METHOD("from_pickle", "pickle_str", "key"), &VodozemacGroupSession::from_pickle);

    // Error handling
    ClassDB::bind_method(D_METHOD("get_last_error"), &VodozemacGroupSession::get_last_error);
}

VodozemacGroupSession::VodozemacGroupSession() : session(nullptr) {
}

VodozemacGroupSession::~VodozemacGroupSession() {
    if (session) {
        delete session;
        session = nullptr;
    }
}

Error VodozemacGroupSession::initialize() {
    try {
        if (session) {
            delete session;
        }
        session = new rust::Box<megolm::GroupSession>(megolm::new_group_session());
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

String VodozemacGroupSession::get_session_id() {
    if (!session) {
        last_error = "Group session not initialized";
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

Dictionary VodozemacGroupSession::encrypt(const String& plaintext) {
    Dictionary result;
    result["success"] = false;

    if (!session) {
        last_error = "Group session not initialized";
        result["error"] = last_error;
        return result;
    }

    try {
        // Convert plaintext to rust::Str
        CharString plaintext_cstr = plaintext.utf8();
        rust::Str plaintext_rust(plaintext_cstr.get_data(), plaintext_cstr.length());

        // Encrypt
        auto megolm_message = (*session)->encrypt(plaintext_rust);

        // Convert to base64
        auto ciphertext_rust = megolm_message->to_base64();
        auto ciphertext_std = std::string(ciphertext_rust);

        result["success"] = true;
        result["ciphertext"] = String(ciphertext_std.c_str());
        last_error = "";

    } catch (const std::exception& e) {
        last_error = String(e.what());
        result["error"] = last_error;
    }

    return result;
}

String VodozemacGroupSession::get_session_key() {
    if (!session) {
        last_error = "Group session not initialized";
        return "";
    }

    try {
        auto session_key = (*session)->session_key();
        auto session_key_base64 = session_key->to_base64();
        auto session_key_std = std::string(session_key_base64);
        last_error = "";
        return String(session_key_std.c_str());
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return "";
    }
}

int64_t VodozemacGroupSession::get_message_index() {
    if (!session) {
        last_error = "Group session not initialized";
        return -1;
    }

    try {
        auto index = (*session)->message_index();
        last_error = "";
        return static_cast<int64_t>(index);
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return -1;
    }
}

String VodozemacGroupSession::pickle(const PackedByteArray& key) {
    if (!session) {
        last_error = "Group session not initialized";
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

Error VodozemacGroupSession::from_pickle(const String& pickle_str, const PackedByteArray& key) {
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
        session = new rust::Box<megolm::GroupSession>(megolm::group_session_from_pickle(pickle_rust, key_array));
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

String VodozemacGroupSession::get_last_error() const {
    return last_error;
}
