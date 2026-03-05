#include "sqlite3.h"
#include "sqlite-vec.h"

int sqlite_vec_auto_init(void) {
    return sqlite3_auto_extension((void(*)(void))sqlite3_vec_init);
}
