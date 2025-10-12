#include "vodozemac_account.h"
#include "vodozemac_session.h"
#include "godot_cpp/core/class_db.hpp"
#include "vodozemac/src/lib.rs.h"
#include <array>
#include <stdexcept>

using namespace godot;

void VodozemacAccount::_bind_methods() {
    // Account operations
    ClassDB::bind_method(D_METHOD("initialize"), &VodozemacAccount::initialize);
    ClassDB::bind_method(D_METHOD("get_identity_keys"), &VodozemacAccount::get_identity_keys);
    ClassDB::bind_method(D_METHOD("generate_one_time_keys", "count"), &VodozemacAccount::generate_one_time_keys);
    ClassDB::bind_method(D_METHOD("get_one_time_keys"), &VodozemacAccount::get_one_time_keys);
    ClassDB::bind_method(D_METHOD("mark_keys_as_published"), &VodozemacAccount::mark_keys_as_published);
    ClassDB::bind_method(D_METHOD("get_max_number_of_one_time_keys"), &VodozemacAccount::get_max_number_of_one_time_keys);

    // Persistence (Phase 3)
    ClassDB::bind_method(D_METHOD("pickle", "key"), &VodozemacAccount::pickle);
    ClassDB::bind_method(D_METHOD("from_pickle", "pickle_str", "key"), &VodozemacAccount::from_pickle);

    // Session creation (Phase 4)
    ClassDB::bind_method(D_METHOD("create_outbound_session", "identity_key_base64", "one_time_key_base64"),
                        &VodozemacAccount::create_outbound_session);
    ClassDB::bind_method(D_METHOD("create_inbound_session", "identity_key_base64", "message_type", "ciphertext"),
                        &VodozemacAccount::create_inbound_session);

    // Error handling
    ClassDB::bind_method(D_METHOD("get_last_error"), &VodozemacAccount::get_last_error);
}

VodozemacAccount::VodozemacAccount() : account(nullptr) {
}

VodozemacAccount::~VodozemacAccount() {
    if (account) {
        delete account;
        account = nullptr;
    }
}

Error VodozemacAccount::initialize() {
    try {
        if (account) {
            delete account;
        }
        account = new rust::Box<olm::Account>(olm::new_account());
        last_error = "";
        return OK;
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return FAILED;
    }
}

Dictionary VodozemacAccount::get_identity_keys() {
    Dictionary result;
    if (!account) {
        last_error = "Account not initialized";
        return result;
    }

    try {
        auto ed25519_key = (*account)->ed25519_key();
        auto curve25519_key = (*account)->curve25519_key();

        auto ed_str = ed25519_key->to_base64();
        auto curve_str = curve25519_key->to_base64();

        result["ed25519"] = String(std::string(ed_str).c_str());
        result["curve25519"] = String(std::string(curve_str).c_str());
        last_error = "";
    } catch (const std::exception& e) {
        last_error = String(e.what());
    }

    return result;
}

Error VodozemacAccount::generate_one_time_keys(int count) {
    if (!account) {
        last_error = "Account not initialized";
        return FAILED;
    }

    try {
        (*account)->generate_one_time_keys(count);
        last_error = "";
        return OK;
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return FAILED;
    }
}

Dictionary VodozemacAccount::get_one_time_keys() {
    Dictionary result;
    if (!account) {
        last_error = "Account not initialized";
        return result;
    }

    try {
        auto keys = (*account)->one_time_keys();
        for (auto& key : keys) {
            auto key_id_str = std::string(key.key_id);
            auto key_str = std::string(key.key->to_base64());
            result[String(key_id_str.c_str())] = String(key_str.c_str());
        }
        last_error = "";
    } catch (const std::exception& e) {
        last_error = String(e.what());
    }

    return result;
}

void VodozemacAccount::mark_keys_as_published() {
    if (!account) {
        last_error = "Account not initialized";
        return;
    }

    try {
        (*account)->mark_keys_as_published();
        last_error = "";
    } catch (const std::exception& e) {
        last_error = String(e.what());
    }
}

int64_t VodozemacAccount::get_max_number_of_one_time_keys() {
    if (!account) {
        last_error = "Account not initialized";
        return 0;
    }

    try {
        last_error = "";
        return (*account)->max_number_of_one_time_keys();
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return 0;
    }
}

// Phase 3: Persistence
String VodozemacAccount::pickle(const PackedByteArray& key) {
    if (!account) {
        last_error = "Account not initialized";
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

        auto pickle_rust_str = (*account)->pickle(key_array);
        auto pickle_std_str = std::string(pickle_rust_str);
        last_error = "";
        return String(pickle_std_str.c_str());
    } catch (const std::exception& e) {
        last_error = String(e.what());
        return "";
    }
}

Error VodozemacAccount::from_pickle(const String& pickle_str, const PackedByteArray& key) {
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

        if (account) {
            delete account;
        }
        account = new rust::Box<olm::Account>(olm::account_from_pickle(pickle_rust, key_array));
        last_error = "";
        return OK;
    } catch (const std::exception& e) {
        last_error = String(e.what());
        if (account) {
            delete account;
        }
        account = nullptr;
        return FAILED;
    }
}

String VodozemacAccount::get_last_error() const {
    return last_error;
}

// Phase 4: Session creation
Ref<VodozemacSession> VodozemacAccount::create_outbound_session(const String& identity_key_base64,
                                                                 const String& one_time_key_base64) {
    Ref<VodozemacSession> session_ref;
    session_ref.instantiate();

    if (!account) {
        last_error = "Account not initialized";
        return session_ref;
    }

    try {
        // Convert strings to rust::Str
        CharString identity_cstr = identity_key_base64.utf8();
        rust::Str identity_rust(identity_cstr.get_data(), identity_cstr.length());

        CharString otk_cstr = one_time_key_base64.utf8();
        rust::Str otk_rust(otk_cstr.get_data(), otk_cstr.length());

        // Parse keys from base64
        auto identity_key = types::curve_key_from_base64(identity_rust);
        auto one_time_key = types::curve_key_from_base64(otk_rust);

        // Create outbound session
        auto session_box = (*account)->create_outbound_session(*identity_key, *one_time_key);

        // Store session in VodozemacSession object using friend access
        session_ref->_set_session(new rust::Box<olm::Session>(std::move(session_box)));
        last_error = "";

        return session_ref;

    } catch (const std::exception& e) {
        last_error = String(e.what());
        return session_ref;
    }
}

Dictionary VodozemacAccount::create_inbound_session(const String& identity_key_base64,
                                                    int message_type,
                                                    const String& ciphertext) {
    Dictionary result;
    result["success"] = false;
    result["session"] = Ref<VodozemacSession>();
    result["plaintext"] = "";

    if (!account) {
        last_error = "Account not initialized";
        result["error"] = last_error;
        return result;
    }

    try {
        // Convert strings to rust::Str
        CharString identity_cstr = identity_key_base64.utf8();
        rust::Str identity_rust(identity_cstr.get_data(), identity_cstr.length());

        // Parse identity key from base64
        auto identity_key = types::curve_key_from_base64(identity_rust);

        // Create OlmMessage from parts
        olm::OlmMessageParts parts;
        parts.message_type = message_type;
        CharString cipher_cstr = ciphertext.utf8();
        parts.ciphertext = rust::String(std::string(cipher_cstr.get_data()));

        auto olm_message = olm::olm_message_from_parts(parts);

        // Create inbound session
        auto inbound_result = (*account)->create_inbound_session(*identity_key, *olm_message);

        // Create session object
        Ref<VodozemacSession> session_ref;
        session_ref.instantiate();

        // Store session using friend access
        session_ref->_set_session(new rust::Box<olm::Session>(std::move(inbound_result.session)));

        auto plaintext_std = std::string(inbound_result.plaintext);
        result["success"] = true;
        result["session"] = session_ref;
        result["plaintext"] = String::utf8(plaintext_std.c_str(), plaintext_std.length());
        last_error = "";

    } catch (const std::exception& e) {
        last_error = String(e.what());
        result["error"] = last_error;
    }

    return result;
}
