#ifndef FTS5_API_HELPER_H
#define FTS5_API_HELPER_H

#include "sqlite3.h"

typedef struct fts5_api fts5_api;

/**
 * Get the FTS5 API pointer from a database connection.
 * This is done in C to avoid Swift pointer bridging issues with sqlite3_bind_pointer.
 * Returns SQLITE_OK on success, with *ppApi pointing to the fts5_api struct.
 */
int cjk_get_fts5_api(sqlite3 *db, fts5_api **ppApi);

#endif
