#ifndef VODOZEMAC_SESSION_H
#define VODOZEMAC_SESSION_H

#include "godot_cpp/classes/ref_counted.hpp"
#include "godot_cpp/variant/dictionary.hpp"
#include "godot_cpp/variant/string.hpp"
#include "godot_cpp/variant/packed_byte_array.hpp"
#include "vodozemac/src/lib.rs.h"

namespace godot {

// Forward declaration
class VodozemacAccount;

class VodozemacSession : public RefCounted {
    GDCLASS(VodozemacSession, RefCounted);

    friend class VodozemacAccount;  // Allow Account to access private members

private:
    rust::Box<olm::Session>* session;
    String last_error;

    // Internal method for VodozemacAccount to set session
    void _set_session(rust::Box<olm::Session>* new_session) {
        if (session) {
            delete session;
        }
        session = new_session;
    }

protected:
    static void _bind_methods();

public:
    VodozemacSession();
    ~VodozemacSession();

    // Session operations
    String get_session_id();
    bool session_matches(int message_type, const String& ciphertext);

    // Encryption/Decryption
    Dictionary encrypt(const String& plaintext);
    Dictionary decrypt(int message_type, const String& ciphertext);

    // Persistence
    String pickle(const PackedByteArray& key);
    Error from_pickle(const String& pickle_str, const PackedByteArray& key);

    // Error handling
    String get_last_error() const;
};

}

#endif // VODOZEMAC_SESSION_H
