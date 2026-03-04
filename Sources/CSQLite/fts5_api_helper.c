#include "include/sqlite3.h"

/* Helper to get fts5_api pointer from C, avoiding Swift pointer bridging issues */
typedef struct fts5_api fts5_api;
int cjk_get_fts5_api(sqlite3 *db, fts5_api **ppApi) {
    sqlite3_stmt *pStmt = 0;
    int rc;
    *ppApi = 0;
    rc = sqlite3_prepare_v2(db, "SELECT fts5(?1)", -1, &pStmt, 0);
    if (rc != SQLITE_OK) return rc;
    sqlite3_bind_pointer(pStmt, 1, (void*)ppApi, "fts5_api_ptr", 0);
    rc = sqlite3_step(pStmt);
    sqlite3_finalize(pStmt);
    if (rc != SQLITE_ROW) return SQLITE_ERROR;
    if (*ppApi == 0) return SQLITE_ERROR;
    return SQLITE_OK;
}
