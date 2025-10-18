/* Echo service RPC definition */

const ECHO_MAX_LEN = 1024;

/* Type for echo strings */
typedef string echo_string<ECHO_MAX_LEN>;

/* Server statistics structure */
struct echo_stats {
    int echo_count;
    int reverse_count;
    int uppercase_count;
    int total_calls;
};

program ECHO_PROG {
    version ECHO_VERS {
        /* Echo a string back to the client */
        echo_string ECHO(echo_string) = 1;
        
        /* Reverse a string and return it */
        echo_string REVERSE(echo_string) = 2;
        
        /* Convert string to uppercase */
        echo_string UPPERCASE(echo_string) = 3;
        
        /* Get server statistics */
        echo_stats GET_STATS(void) = 4;
        
        /* Reset server statistics */
        void RESET_STATS(void) = 5;
    } = 1;
} = 0x20000001;