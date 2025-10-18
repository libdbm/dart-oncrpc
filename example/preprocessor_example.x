/*
 * Example demonstrating preprocessor features
 */

#ifndef EXAMPLE_X
#define EXAMPLE_X

#define MAX_NAME_LEN 256
#define API_VERSION 1

/* Conditional compilation based on defines */
#ifdef DEBUG
const DEBUG_ENABLED = 1;
#else  
const DEBUG_ENABLED = 0;
#endif

/* Types using defined constants */
typedef string username<MAX_NAME_LEN>;
typedef opaque session_data<1024>;

struct user_info {
    username name;
    int uid;
    int gid;
};

/* You can include other .x files */
/* #include "common_types.x" */

program USER_PROG {
    version USER_V1 {
        user_info GET_USER_INFO(username) = 1;
    } = API_VERSION;
} = 100000;

#endif /* EXAMPLE_X */