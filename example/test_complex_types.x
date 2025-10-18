/*
 * Test file for complex ONC-RPC types
 */

/* Constants */
const MAX_NAME_LEN = 256;
const MAX_DATA_SIZE = 8192;
const DEFAULT_PORT = 2049;

/* Enums */
enum file_type {
    FILE_TYPE_REGULAR = 1,
    FILE_TYPE_DIRECTORY = 2,
    FILE_TYPE_SYMLINK = 3,
    FILE_TYPE_DEVICE = 4
};

/* Simple typedef */
typedef opaque file_handle<64>;
typedef string filename<MAX_NAME_LEN>;
typedef unsigned int uid_t;
typedef unsigned int gid_t;

/* Struct with various field types */
struct file_attributes {
    file_type type;
    unsigned int mode;
    uid_t uid;
    gid_t gid;
    unsigned hyper size;
    unsigned int atime;
    unsigned int mtime;
    unsigned int ctime;
};

/* Recursive linked list structure */
struct dir_entry {
    filename name;
    file_handle fh;
    file_attributes attrs;
    dir_entry *next;  /* Recursive pointer */
};

/* Union with discriminant */
union read_result switch (int status) {
    case 0:
        struct {
            opaque data<MAX_DATA_SIZE>;
            bool eof;
        } success;
    case 1:
        string error_msg<256>;
    default:
        void;
};

/* Complex struct with arrays and optional fields */
struct batch_request {
    unsigned int request_id;
    file_handle handles<10>;        /* Array of handles */
    unsigned int *optional_flags;   /* Optional field */
    opaque metadata<>;              /* Variable-length opaque */
};

/* Nested structures */
struct tree_node {
    string name<256>;
    unsigned int value;
    tree_node *children<>;  /* Array of pointers to children */
};

/* Program definition */
program COMPLEX_PROG {
    version COMPLEX_V1 {
        void
        NULL(void) = 0;
        
        file_attributes
        GET_ATTRS(file_handle) = 1;
        
        dir_entry
        LIST_DIR(file_handle) = 2;
        
        read_result
        READ_FILE(file_handle, unsigned int offset, unsigned int count) = 3;
        
        bool
        WRITE_FILE(file_handle, unsigned int offset, opaque data<>) = 4;
        
        batch_request
        BATCH_OP(batch_request) = 5;
        
        tree_node
        GET_TREE(string path<>) = 6;
        
    } = 1;
} = 100100;