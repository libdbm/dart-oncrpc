/*
 * C RPC Client for compatibility testing with Dart server
 *
 * Compile:
 *   rpcgen -h rpc_test.x -o rpc_test.h
 *   rpcgen -c rpc_test.x -o rpc_test_xdr.c
 *   rpcgen -l rpc_test.x -o rpc_test_clnt.c
 *   cc -o c_rpc_client c_rpc_client.c rpc_test_clnt.c rpc_test_xdr.c -Wno-unused-variable
 *
 * Run:
 *   ./c_rpc_client localhost
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <rpc/rpc.h>
#include <math.h>
#include "rpc_test.h"

#define DART_SERVER_PORT 8888
#define TEST_PASSED 0
#define TEST_FAILED 1

int test_count = 0;
int tests_passed = 0;
int tests_failed = 0;

void test_result(const char *test_name, int passed) {
    test_count++;
    if (passed) {
        tests_passed++;
        printf("  ✓ %s\n", test_name);
    } else {
        tests_failed++;
        printf("  ✗ %s FAILED\n", test_name);
    }
}

int main(int argc, char *argv[]) {
    CLIENT *clnt;
    char *host;
    void *result_void;
    int *result_int;
    char **result_str;
    CalcResult *result_calc;
    EchoResponse *result_echo_resp;
    SumResult *result_sum;
    TestResult *result_test;

    if (argc < 2) {
        printf("Usage: %s <server_host>\n", argv[0]);
        exit(1);
    }

    host = argv[1];

    printf("\n");
    printf("=========================================\n");
    printf("C Client → Dart Server RPC Tests\n");
    printf("=========================================\n");
    printf("Connecting to Dart RPC server at %s:%d...\n\n", host, DART_SERVER_PORT);

    /* Create RPC client */
    struct sockaddr_in addr;
    int sock = RPC_ANYSOCK;
    struct timeval timeout = {25, 0};

    addr.sin_family = AF_INET;
    addr.sin_port = htons(DART_SERVER_PORT);
    if (inet_pton(AF_INET, strcmp(host, "localhost") == 0 ? "127.0.0.1" : host, &addr.sin_addr) <= 0) {
        fprintf(stderr, "Invalid address: %s\n", host);
        exit(1);
    }

    clnt = clnttcp_create(&addr, RPC_TEST_PROG, RPC_TEST_V1, &sock, 0, 0);
    if (clnt == NULL) {
        clnt_pcreateerror(host);
        exit(1);
    }

    printf("Running tests:\n");

    /* Test 1: RPC_NULL (ping) */
    result_void = rpc_null_1(NULL, clnt);
    if (result_void == NULL) {
        clnt_perror(clnt, "RPC_NULL call failed");
        test_result("RPC_NULL (ping)", 0);
    } else {
        test_result("RPC_NULL (ping)", 1);
    }

    /* Test 2: ADD - simple addition */
    AddRequest add_req;
    add_req.a = 42;
    add_req.b = 8;
    result_int = add_1(&add_req, clnt);
    if (result_int == NULL) {
        clnt_perror(clnt, "ADD call failed");
        test_result("ADD - simple addition", 0);
    } else {
        test_result("ADD - simple addition", *result_int == 50);
    }

    /* Test 3: ECHO - string echo */
    char *test_string = "Hello from C!";
    result_str = echo_1(&test_string, clnt);
    if (result_str == NULL) {
        clnt_perror(clnt, "ECHO call failed");
        test_result("ECHO - string echo", 0);
    } else {
        test_result("ECHO - string echo", strcmp(*result_str, test_string) == 0);
    }

    /* Test 4: CALCULATE - with operation enum */
    CalcRequest calc_req;
    calc_req.op = MULTIPLY;
    calc_req.a = 7;
    calc_req.b = 6;
    result_calc = calculate_1(&calc_req, clnt);
    if (result_calc == NULL) {
        clnt_perror(clnt, "CALCULATE call failed");
        test_result("CALCULATE - with operation enum", 0);
    } else {
        int passed = (result_calc->result == 42) &&
                     (strstr(result_calc->message, "Multiplied") != NULL);
        test_result("CALCULATE - with operation enum", passed);
    }

    /* Test 5: ECHO_MANY - struct request and response */
    EchoRequest echo_req;
    echo_req.text = "Test message";
    echo_req.count = 5;
    result_echo_resp = echo_many_1(&echo_req, clnt);
    if (result_echo_resp == NULL) {
        clnt_perror(clnt, "ECHO_MANY call failed");
        test_result("ECHO_MANY - struct request and response", 0);
    } else {
        int passed = (strcmp(result_echo_resp->echoed_text, "Test message") == 0) &&
                     (result_echo_resp->times_echoed == 5);
        test_result("ECHO_MANY - struct request and response", passed);
    }

    /* Test 6: SUM_ARRAY - variable-length array */
    SumRequest sum_req;
    int numbers[] = {10, 20, 30, 40, 50};
    sum_req.numbers.numbers_len = 5;
    sum_req.numbers.numbers_val = numbers;
    result_sum = sum_array_1(&sum_req, clnt);
    if (result_sum == NULL) {
        clnt_perror(clnt, "SUM_ARRAY call failed");
        test_result("SUM_ARRAY - variable-length array", 0);
    } else {
        int passed = (result_sum->total == 150) && (result_sum->count == 5);
        test_result("SUM_ARRAY - variable-length array", passed);
    }

    /* Test 7: POINT_DISTANCE - multiple struct parameters */
    PointPair point_pair;
    point_pair.p1.x = 0;
    point_pair.p1.y = 0;
    point_pair.p2.x = 3;
    point_pair.p2.y = 4;
    result_int = point_distance_1(&point_pair, clnt);
    if (result_int == NULL) {
        clnt_perror(clnt, "POINT_DISTANCE call failed");
        test_result("POINT_DISTANCE - multiple struct parameters", 0);
    } else {
        test_result("POINT_DISTANCE - multiple struct parameters", *result_int == 5);
    }

    /* Test 8: DIVIDE_SAFE - union success case */
    DivideRequest divide_req_ok;
    divide_req_ok.dividend = 20;
    divide_req_ok.divisor = 4;
    result_test = divide_safe_1(&divide_req_ok, clnt);
    if (result_test == NULL) {
        clnt_perror(clnt, "DIVIDE_SAFE (success) call failed");
        test_result("DIVIDE_SAFE - union success case", 0);
    } else {
        int passed = (result_test->status == 0) &&
                     (result_test->TestResult_u.success.result == 5);
        test_result("DIVIDE_SAFE - union success case", passed);
    }

    /* Test 9: DIVIDE_SAFE - union error case (divide by zero) */
    DivideRequest divide_req_zero;
    divide_req_zero.dividend = 20;
    divide_req_zero.divisor = 0;
    result_test = divide_safe_1(&divide_req_zero, clnt);
    if (result_test == NULL) {
        clnt_perror(clnt, "DIVIDE_SAFE (error) call failed");
        test_result("DIVIDE_SAFE - union error case", 0);
    } else {
        int passed = (result_test->status == 1) &&
                     (strstr(result_test->TestResult_u.error, "zero") != NULL);
        test_result("DIVIDE_SAFE - union error case", passed);
    }

    /* Test 10: GET_SERVER_INFO - void parameter */
    result_str = get_server_info_1(NULL, clnt);
    if (result_str == NULL) {
        clnt_perror(clnt, "GET_SERVER_INFO call failed");
        test_result("GET_SERVER_INFO - void parameter", 0);
    } else {
        int passed = (strstr(*result_str, "Dart RPC Server") != NULL) &&
                     (strstr(*result_str, "dart-oncrpc") != NULL);
        test_result("GET_SERVER_INFO - void parameter", passed);
    }

    /* Print summary */
    printf("\n");
    printf("=========================================\n");
    printf("Test Summary:\n");
    printf("  Total:  %d\n", test_count);
    printf("  Passed: %d\n", tests_passed);
    printf("  Failed: %d\n", tests_failed);
    printf("=========================================\n");

    /* Cleanup */
    clnt_destroy(clnt);

    /* Return appropriate exit code */
    return (tests_failed == 0) ? TEST_PASSED : TEST_FAILED;
}
