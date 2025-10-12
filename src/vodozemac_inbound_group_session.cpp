#include "vodozemac_inbound_group_session.h"
#include "godot_cpp/core/class_db.hpp"
#include "vodozemac/src/lib.rs.h"
#include <array>
#include <stdexcept>

using namespace godot;

void VodozemacInboundGroupSession::_bind_methods() {
    // Session operations
    ClassDB::bind_method(D_METHOD("initialize_from_session_key", "session_key"),
        &VodozemacInboundGroupSession::initialize_from_session_key);
    ClassDB::bind_method(D_METHOD("import_session", "exported_key"),
        &VodozemacInboundGroupSession::import_session);
    ClassDB::bind_method(D_METHOD("get_session_id"), &VodozemacInboundGroupSession::get_session_id);
    ClassDB::bind_method(D_METHOD("decrypt", "ciphertext"), &VodozemacInboundGroupSession::decrypt);
    ClassDB::bind_method(D_METHOD("get_first_known_index"), &VodozemacInboundGroupSession::get_first_known_index);
    ClassDB::bind_method(D_METHOD("export_at_index", "message_index"),
        &VodozemacInboundGroupSession::export_at_index);

    // Persistence
    ClassDB::bind_method(D_METHOD("pickle", "key"), &VodozemacInboundGroupSession::pickle);
    ClassDB::bind_method(D_METHOD("from_pickle", "pickle_str", "key"),
        &VodozemacInboundGroupSession::from_pickle);

    // Error handling
    ClassDB::bind_method(D_METHOD("get_last_error"), &VodozemacInboundGroupSession::get_last_error);
}

VodozemacInboundGroupSession::VodozemacInboundGroupSession() : session(nullptr) {
}

VodozemacInboundGroupSession::~VodozemacInboundGroupSession() {
    if (session) {
        delete session;
        session = nullptr;
    }
}

Error VodozemacInboundGroupSession::initialize_from_session_key(const String& session_key) {
    try {
        // Convert String to rust::Str
        CharString key_cstr = session_key.utf8();
        rust::Str key_rust(key_cstr.get_data(), key_cstr.length());

        // Parse session key from base64
        auto parsed_key = megolm::session_key_from_base64(key_rust);

        if (session) {
            delete session;
        }
        session = new rust::Box<megolm::InboundGroupSession>(
            megolm::new_inbound_group_session(*parsed_key)
        );
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

Error VodozemacInboundGroupSession::import_session(const String& exported_key) {
    try {
        // Convert String to rust::Str
        CharString key_cstr = exported_key.utf8();
        rust::Str key_rust(key_cstr.get_data(), key_cstr.length());

        // Parse exported session key from base64
        auto parsed_key = megolm::exported_session_key_from_base64(key_rust);

        if (session) {
            delete session;
        }
        session = new rust::Box<megolm::InboundGroupSession>(
            megolm::import_inbound_group_session(*parsed_key)
        );
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

String VodozemacInboundGroupSession::get_session_id() {
    if (!session) {
        last_error = "Inbound group session not initialized";
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

Dictionary VodozemacInboundGroupSession::decrypt(const String& ciphertext) {
    Dictionary result;
    result["success"] = false;

    if (!session) {
        last_error = "Inbound group session not initialized";
        result["error"] = last_error;
        return result;
    }

    try {
        // Convert String to rust::Str
        CharString cipher_cstr = ciphertext.utf8();
        rust::Str cipher_rust(cipher_cstr.get_data(), cipher_cstr.length());

        // Parse megolm message from base64
        auto megolm_message = megolm::megolm_message_from_base64(cipher_rust);

        // Decrypt
        auto decrypted = (*session)->decrypt(*megolm_message);

        result["success"] = true;
        result["plaintext"] = String(std::string(decrypted.plaintext).c_str());
        result["message_index"] = static_cast<int64_t>(decrypted.message_index);
        last_error = "";

    } catch (const std::exception& e) {
        last_error = String(e.what());
        result["error"] = last_error;
    }

    return result;
}

int64_t VodozemacInboundGroupSession::get_first_known_index() {
    if (!session) {
        last_error = "Inbound group session not initialized";
        return -1;
    }

    try {
        auto index = (*session)->first_known_index();
        last_error = "";
        return static_cast<int64_t>(index);
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return -1;
    }
}

Dictionary VodozemacInboundGroupSession::export_at_index(int64_t message_index) {
    Dictionary result;
    result["success"] = false;

    if (!session) {
        last_error = "Inbound group session not initialized";
        result["error"] = last_error;
        return result;
    }

    try {
        // Export at index
        auto exported_key = (*session)->export_at(static_cast<uint32_t>(message_index));

        // Convert to base64
        auto exported_key_base64 = exported_key->to_base64();
        auto exported_key_std = std::string(exported_key_base64);

        result["success"] = true;
        result["exported_key"] = String(exported_key_std.c_str());
        last_error = "";

    } catch (const std::exception& e) {
        last_error = String(e.what());
        result["error"] = last_error;
    }

    return result;
}

String VodozemacInboundGroupSession::pickle(const PackedByteArray& key) {
    if (!session) {
        last_error = "Inbound group session not initialized";
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

Error VodozemacInboundGroupSession::from_pickle(const String& pickle_str, const PackedByteArray& key) {
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
        session = new rust::Box<megolm::InboundGroupSession>(
            megolm::inbound_group_session_from_pickle(pickle_rust, key_array)
        );
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

String VodozemacInboundGroupSession::get_last_error() const {
    return last_error;
}
