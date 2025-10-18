/*
 * RPC Test Protocol for Dart-C Compatibility Testing
 *
 * This protocol defines simple RPC procedures to test
 * bidirectional compatibility between Dart and C implementations.
 */

const MAX_NAME_LEN = 100;
const MAX_ITEMS = 50;

/* Test enum */
enum Operation {
    ADD = 0,
    SUBTRACT = 1,
    MULTIPLY = 2,
    DIVIDE = 3
};

/* Simple struct for testing */
struct Point {
    int x;
    int y;
};

/* Request/response structs */
struct CalcRequest {
    Operation op;
    int a;
    int b;
};

struct CalcResult {
    int result;
    string message<MAX_NAME_LEN>;
};

struct EchoRequest {
    string text<MAX_NAME_LEN>;
    int count;
};

struct EchoResponse {
    string echoed_text<MAX_NAME_LEN>;
    int times_echoed;
};

struct SumRequest {
    int numbers<MAX_ITEMS>;
};

struct SumResult {
    int total;
    int count;
};

struct AddRequest {
    int a;
    int b;
};

struct PointPair {
    Point p1;
    Point p2;
};

struct DivideRequest {
    int dividend;
    int divisor;
};

/* Union for testing discriminated unions */
union TestResult switch (int status) {
case 0:
    CalcResult success;
case 1:
    string error<>;
default:
    void;
};

/*
 * RPC Test Program
 */
program RPC_TEST_PROG {
    version RPC_TEST_V1 {
        /* Procedure 0: NULL (ping) */
        void
        RPC_NULL(void) = 0;

        /* Procedure 1: Simple addition */
        int
        ADD(AddRequest) = 1;

        /* Procedure 2: Echo string */
        string
        ECHO(string) = 2;

        /* Procedure 3: Calculate with operation */
        CalcResult
        CALCULATE(CalcRequest) = 3;

        /* Procedure 4: Echo with count */
        EchoResponse
        ECHO_MANY(EchoRequest) = 4;

        /* Procedure 5: Sum array of integers */
        SumResult
        SUM_ARRAY(SumRequest) = 5;

        /* Procedure 6: Point distance calculation */
        int
        POINT_DISTANCE(PointPair) = 6;

        /* Procedure 7: Test union result */
        TestResult
        DIVIDE_SAFE(DivideRequest) = 7;

        /* Procedure 8: Get server info */
        string
        GET_SERVER_INFO(void) = 8;
    } = 1;
} = 0x20000100;  /* Test program number */
