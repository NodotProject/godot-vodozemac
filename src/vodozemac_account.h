#ifndef VODOZEMAC_ACCOUNT_H
#define VODOZEMAC_ACCOUNT_H

#include "godot_cpp/classes/ref_counted.hpp"
#include "godot_cpp/variant/dictionary.hpp"
#include "godot_cpp/variant/string.hpp"
#include "godot_cpp/variant/packed_byte_array.hpp"
#include "vodozemac/src/lib.rs.h"

namespace godot {

// Forward declaration
class VodozemacSession;

class VodozemacAccount : public RefCounted {
    GDCLASS(VodozemacAccount, RefCounted);

private:
    rust::Box<olm::Account>* account;
    String last_error;

protected:
    static void _bind_methods();

public:
    VodozemacAccount();
    ~VodozemacAccount();

    // Account operations
    Error initialize();
    Dictionary get_identity_keys();
    Error generate_one_time_keys(int count);
    Dictionary get_one_time_keys();
    void mark_keys_as_published();
    int64_t get_max_number_of_one_time_keys();

    // Persistence (Phase 3)
    String pickle(const PackedByteArray& key);
    Error from_pickle(const String& pickle_str, const PackedByteArray& key);

    // Session creation (Phase 4) - these will be called by VodozemacSession
    Ref<VodozemacSession> create_outbound_session(const String& identity_key_base64,
                                                   const String& one_time_key_base64);
    Dictionary create_inbound_session(const String& identity_key_base64,
                                     int message_type,
                                     const String& ciphertext);

    // Error handling
    String get_last_error() const;
};

}

#endif // VODOZEMAC_ACCOUNT_H
