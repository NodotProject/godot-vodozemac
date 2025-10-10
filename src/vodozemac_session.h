#ifndef VODOZEMAC_SESSION_H
#define VODOZEMAC_SESSION_H

#include "godot_cpp/classes/ref_counted.hpp"

namespace godot {

class VodozemacSession : public RefCounted {
    GDCLASS(VodozemacSession, RefCounted);

protected:
    static void _bind_methods();

public:
    VodozemacSession();
    ~VodozemacSession();
};

}

#endif // VODOZEMAC_SESSION_H
