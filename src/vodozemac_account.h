#ifndef VODOZEMAC_ACCOUNT_H
#define VODOZEMAC_ACCOUNT_H

#include "godot_cpp/classes/ref_counted.hpp"

namespace godot {

class VodozemacAccount : public RefCounted {
    GDCLASS(VodozemacAccount, RefCounted);

protected:
    static void _bind_methods();

public:
    VodozemacAccount();
    ~VodozemacAccount();
};

}

#endif // VODOZEMAC_ACCOUNT_H
