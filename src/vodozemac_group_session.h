#ifndef VODOZEMAC_GROUP_SESSION_H
#define VODOZEMAC_GROUP_SESSION_H

#include "godot_cpp/classes/ref_counted.hpp"
#include "godot_cpp/variant/dictionary.hpp"
#include "godot_cpp/variant/string.hpp"
#include "godot_cpp/variant/packed_byte_array.hpp"
#include "vodozemac/src/lib.rs.h"

namespace godot {

class VodozemacGroupSession : public RefCounted {
    GDCLASS(VodozemacGroupSession, RefCounted);

private:
    rust::Box<megolm::GroupSession>* session;
    String last_error;

protected:
    static void _bind_methods();

public:
    VodozemacGroupSession();
    ~VodozemacGroupSession();

    // Session operations
    Error initialize();
    String get_session_id();
    Dictionary encrypt(const String& plaintext);
    String get_session_key();
    int64_t get_message_index();

    // Persistence
    String pickle(const PackedByteArray& key);
    Error from_pickle(const String& pickle_str, const PackedByteArray& key);

    // Error handling
    String get_last_error() const;
};

}

#endif // VODOZEMAC_GROUP_SESSION_H
