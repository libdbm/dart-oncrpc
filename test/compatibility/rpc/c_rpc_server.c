/*
 * C RPC Server for compatibility testing with Dart client
 *
 * Compile:
 *   rpcgen -h rpc_test.x -o rpc_test.h
 *   rpcgen -c rpc_test.x -o rpc_test_xdr.c
 *   rpcgen -s tcp rpc_test.x -o rpc_test_svc.c
 *   cc -o c_rpc_server c_rpc_server.c rpc_test_svc.c rpc_test_xdr.c -Wno-unused-variable
 *
 * Run:
 *   ./c_rpc_server
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <rpc/rpc.h>
#include <rpc/pmap_clnt.h>
#include <math.h>
#include "rpc_test.h"

/* Procedure 0: NULL (ping) */
void *
rpc_null_1_svc(void *argp, struct svc_req *rqstp)
{
    static char result;
    printf("[C Server] RPC_NULL called\n");
    return (void *)&result;
}

/* Procedure 1: Simple addition */
int *
add_1_svc(AddRequest *argp, struct svc_req *rqstp)
{
    static int result;
    int a = argp->a;
    int b = argp->b;
    result = a + b;
    printf("[C Server] ADD(%d, %d) = %d\n", a, b, result);
    return &result;
}

/* Procedure 2: Echo string */
char **
echo_1_svc(char **argp, struct svc_req *rqstp)
{
    static char *result;
    result = *argp;
    printf("[C Server] ECHO(\"%s\") = \"%s\"\n", *argp, result);
    return &result;
}

/* Procedure 3: Calculate with operation */
CalcResult *
calculate_1_svc(CalcRequest *argp, struct svc_req *rqstp)
{
    static CalcResult result;
    static char message[MAX_NAME_LEN];
    int a = argp->a;
    int b = argp->b;

    switch (argp->op) {
        case 0:  /* ADD */
            result.result = a + b;
            snprintf(message, sizeof(message), "Added %d + %d", a, b);
            break;
        case 1:  /* SUBTRACT */
            result.result = a - b;
            snprintf(message, sizeof(message), "Subtracted %d - %d", a, b);
            break;
        case 2:  /* MULTIPLY */
            result.result = a * b;
            snprintf(message, sizeof(message), "Multiplied %d * %d", a, b);
            break;
        case 3:  /* DIVIDE */
            if (b != 0) {
                result.result = a / b;
                snprintf(message, sizeof(message), "Divided %d / %d", a, b);
            } else {
                result.result = 0;
                snprintf(message, sizeof(message), "Error: Division by zero");
            }
            break;
    }

    result.message = message;
    printf("[C Server] CALCULATE(op=%d, %d, %d) = %d (%s)\n",
           argp->op, a, b, result.result, message);
    return &result;
}

/* Procedure 4: Echo with count */
EchoResponse *
echo_many_1_svc(EchoRequest *argp, struct svc_req *rqstp)
{
    static EchoResponse result;
    static char echoed[MAX_NAME_LEN];

    strncpy(echoed, argp->text, sizeof(echoed) - 1);
    echoed[sizeof(echoed) - 1] = '\0';

    result.echoed_text = echoed;
    result.times_echoed = argp->count;

    printf("[C Server] ECHO_MANY(\"%s\", %d)\n", argp->text, argp->count);
    return &result;
}

/* Procedure 5: Sum array of integers */
SumResult *
sum_array_1_svc(SumRequest *argp, struct svc_req *rqstp)
{
    static SumResult result;
    int total = 0;
    unsigned int i;

    for (i = 0; i < argp->numbers.numbers_len; i++) {
        total += argp->numbers.numbers_val[i];
    }

    result.total = total;
    result.count = argp->numbers.numbers_len;

    printf("[C Server] SUM_ARRAY(%u numbers) = %d\n",
           argp->numbers.numbers_len, total);
    return &result;
}

/* Procedure 6: Point distance calculation */
int *
point_distance_1_svc(PointPair *argp, struct svc_req *rqstp)
{
    static int result;
    Point p1 = argp->p1;
    Point p2 = argp->p2;

    int dx = p2.x - p1.x;
    int dy = p2.y - p1.y;
    result = (int)sqrt(dx * dx + dy * dy);

    printf("[C Server] POINT_DISTANCE((%d,%d), (%d,%d)) = %d\n",
           p1.x, p1.y, p2.x, p2.y, result);
    return &result;
}

/* Procedure 7: Test union result */
TestResult *
divide_safe_1_svc(DivideRequest *argp, struct svc_req *rqstp)
{
    static TestResult result;
    static CalcResult calc_result;
    static char success_msg[MAX_NAME_LEN];
    static char error_msg[MAX_NAME_LEN];

    int a = argp->dividend;
    int b = argp->divisor;

    if (b == 0) {
        result.status = 1;  /* Error */
        snprintf(error_msg, sizeof(error_msg), "Cannot divide by zero");
        result.TestResult_u.error = error_msg;
        printf("[C Server] DIVIDE_SAFE(%d, %d) = ERROR\n", a, b);
    } else {
        result.status = 0;  /* Success */
        calc_result.result = a / b;
        snprintf(success_msg, sizeof(success_msg), "Division successful");
        calc_result.message = success_msg;
        result.TestResult_u.success = calc_result;
        printf("[C Server] DIVIDE_SAFE(%d, %d) = %d\n", a, b, calc_result.result);
    }

    return &result;
}

/* Procedure 8: Get server info */
char **
get_server_info_1_svc(void *argp, struct svc_req *rqstp)
{
    static char *result;
    static char info[MAX_NAME_LEN];

    snprintf(info, sizeof(info), "C RPC Server v1.0 (rpcgen)");
    result = info;

    printf("[C Server] GET_SERVER_INFO() = \"%s\"\n", info);
    return &result;
}

/* RPC dispatcher function */
void
rpc_test_prog_1(struct svc_req *rqstp, SVCXPRT *transp)
{
    union {
        AddRequest add_1_arg;
        char *echo_1_arg;
        CalcRequest calculate_1_arg;
        EchoRequest echo_many_1_arg;
        SumRequest sum_array_1_arg;
        PointPair point_distance_1_arg;
        DivideRequest divide_safe_1_arg;
    } argument;
    char *result;
    xdrproc_t xdr_argument, xdr_result;
    char *(*local)(char *, struct svc_req *);

    switch (rqstp->rq_proc) {
    case 0:  /* RPC_NULL */
        svc_sendreply(transp, (xdrproc_t)xdr_void, NULL);
        return;

    case 1:  /* ADD */
        xdr_argument = (xdrproc_t)xdr_AddRequest;
        xdr_result = (xdrproc_t)xdr_int;
        local = (char *(*)(char *, struct svc_req *))add_1_svc;
        break;

    case 2:  /* ECHO */
        xdr_argument = (xdrproc_t)xdr_wrapstring;
        xdr_result = (xdrproc_t)xdr_wrapstring;
        local = (char *(*)(char *, struct svc_req *))echo_1_svc;
        break;

    case 3:  /* CALCULATE */
        xdr_argument = (xdrproc_t)xdr_CalcRequest;
        xdr_result = (xdrproc_t)xdr_CalcResult;
        local = (char *(*)(char *, struct svc_req *))calculate_1_svc;
        break;

    case 4:  /* ECHO_MANY */
        xdr_argument = (xdrproc_t)xdr_EchoRequest;
        xdr_result = (xdrproc_t)xdr_EchoResponse;
        local = (char *(*)(char *, struct svc_req *))echo_many_1_svc;
        break;

    case 5:  /* SUM_ARRAY */
        xdr_argument = (xdrproc_t)xdr_SumRequest;
        xdr_result = (xdrproc_t)xdr_SumResult;
        local = (char *(*)(char *, struct svc_req *))sum_array_1_svc;
        break;

    case 6:  /* POINT_DISTANCE */
        xdr_argument = (xdrproc_t)xdr_PointPair;
        xdr_result = (xdrproc_t)xdr_int;
        local = (char *(*)(char *, struct svc_req *))point_distance_1_svc;
        break;

    case 7:  /* DIVIDE_SAFE */
        xdr_argument = (xdrproc_t)xdr_DivideRequest;
        xdr_result = (xdrproc_t)xdr_TestResult;
        local = (char *(*)(char *, struct svc_req *))divide_safe_1_svc;
        break;

    case 8:  /* GET_SERVER_INFO */
        xdr_argument = (xdrproc_t)xdr_void;
        xdr_result = (xdrproc_t)xdr_wrapstring;
        local = (char *(*)(char *, struct svc_req *))get_server_info_1_svc;
        break;

    default:
        svcerr_noproc(transp);
        return;
    }

    memset(&argument, 0, sizeof(argument));
    if (!svc_getargs(transp, xdr_argument, (caddr_t)&argument)) {
        svcerr_decode(transp);
        return;
    }

    result = (*local)((char *)&argument, rqstp);
    if (result != NULL && !svc_sendreply(transp, xdr_result, result)) {
        svcerr_systemerr(transp);
    }

    if (!svc_freeargs(transp, xdr_argument, (caddr_t)&argument)) {
        fprintf(stderr, "unable to free arguments\n");
        exit(1);
    }
}

#define C_SERVER_PORT 7777

int
main(void)
{
    SVCXPRT *transp;
    int sock;
    struct sockaddr_in addr;

    printf("Starting C RPC Test Server...\n");
    printf("Program: 0x%x, Version: 1\n", RPC_TEST_PROG);
    printf("Listening on TCP port %d...\n", C_SERVER_PORT);

    /* Unregister any previous instances */
    pmap_unset(RPC_TEST_PROG, RPC_TEST_V1);

    /* Create socket and bind to specific port */
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        exit(1);
    }

    /* Allow reuse of address */
    int reuse = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) < 0) {
        perror("setsockopt");
        close(sock);
        exit(1);
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(C_SERVER_PORT);

    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        exit(1);
    }

    if (listen(sock, 5) < 0) {
        perror("listen");
        close(sock);
        exit(1);
    }

    /* Create TCP transport on the bound socket */
    transp = svctcp_create(sock, 0, 0);
    if (transp == NULL) {
        fprintf(stderr, "Failed to create TCP transport\n");
        close(sock);
        exit(1);
    }

    /* Register the service */
    if (!svc_register(transp, RPC_TEST_PROG, RPC_TEST_V1, rpc_test_prog_1, IPPROTO_TCP)) {
        fprintf(stderr, "Failed to register RPC service\n");
        exit(1);
    }

    printf("C RPC Server ready on port %d. Waiting for requests...\n", C_SERVER_PORT);

    /* Run the service */
    svc_run();

    fprintf(stderr, "svc_run returned unexpectedly\n");
    exit(1);
}
