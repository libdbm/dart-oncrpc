#!/bin/bash

# RPC Compatibility Test Matrix Runner
# Tests bidirectional compatibility between Dart and C RPC implementations

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Kill background processes if they exist
    if [ ! -z "$C_SERVER_PID" ]; then
        echo "Stopping C server (PID $C_SERVER_PID)..."
        kill $C_SERVER_PID 2>/dev/null || true
    fi

    if [ ! -z "$DART_SERVER_PID" ]; then
        echo "Stopping Dart server (PID $DART_SERVER_PID)..."
        kill $DART_SERVER_PID 2>/dev/null || true
    fi

    # Clean up port mapper registrations
    rpcinfo -d 0x20000100 1 2>/dev/null || true

    # Clean up generated files
    cd "$(dirname "$0")"
    rm -f rpc_test_xdr.c rpc_test_clnt.c rpc_test.h c_rpc_server c_rpc_client c_server.log dart_server.log 2>/dev/null || true
}

# Set up trap to cleanup on exit
trap cleanup EXIT INT TERM

echo ""
echo "========================================="
echo "RPC Compatibility Test Matrix"
echo "========================================="
echo ""

# Change to the compatibility test directory
cd "$(dirname "$0")"

# Step 1: Generate XDR code with rpcgen
echo -e "${BLUE}Step 1: Generating XDR code with rpcgen...${NC}"
rpcgen -h rpc_test.x -o rpc_test.h
rpcgen -c rpc_test.x -o rpc_test_xdr.c
rpcgen -l rpc_test.x -o rpc_test_clnt.c
echo -e "${GREEN}✓ XDR code generated${NC}"
echo ""

# Step 2: Compile C programs
echo -e "${BLUE}Step 2: Compiling C programs...${NC}"
cc -o c_rpc_server c_rpc_server.c rpc_test_xdr.c -Wno-unused-variable -Wno-deprecated-non-prototype
cc -o c_rpc_client c_rpc_client.c rpc_test_clnt.c rpc_test_xdr.c -Wno-unused-variable -Wno-deprecated-non-prototype -Wno-incompatible-function-pointer-types -Wno-implicit-function-declaration
echo -e "${GREEN}✓ C programs compiled${NC}"
echo ""

# Step 3: Test Matrix - Dart Client -> C Server
echo -e "${BLUE}Step 3: Testing Dart Client -> C Server${NC}"
echo "Starting C RPC server..."
./c_rpc_server > c_server.log 2>&1 &
C_SERVER_PID=$!

# Wait for C server to be ready
sleep 2

# Check if C server is running
if ! ps -p $C_SERVER_PID > /dev/null; then
    echo -e "${RED}✗ C server failed to start${NC}"
    cat c_server.log
    exit 1
fi

echo "C server started (PID $C_SERVER_PID)"
echo ""

# Run Dart client tests
echo "Running Dart client tests..."
cd ../../..
dart test test/compatibility/rpc/dart_to_c_rpc_test.dart
DART_CLIENT_RESULT=$?
cd test/compatibility/rpc

if [ $DART_CLIENT_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Dart Client -> C Server: PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Dart Client -> C Server: FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Stop C server
kill $C_SERVER_PID 2>/dev/null || true
wait $C_SERVER_PID 2>/dev/null || true
C_SERVER_PID=""
sleep 1

# Clean up port mapper registration
rpcinfo -d 0x20000100 1 2>/dev/null || true
sleep 1

# Step 4: Test Matrix - C Client -> Dart Server
echo -e "${BLUE}Step 4: Testing C Client -> Dart Server${NC}"
echo "Starting Dart RPC server..."
cd ../../..
dart run test/compatibility/rpc/dart_rpc_server.dart > test/compatibility/rpc/dart_server.log 2>&1 &
DART_SERVER_PID=$!
cd test/compatibility/rpc

# Wait for Dart server to be ready
sleep 3

# Check if Dart server is running
if ! ps -p $DART_SERVER_PID > /dev/null; then
    echo -e "${RED}✗ Dart server failed to start${NC}"
    cat dart_server.log
    exit 1
fi

echo "Dart server started (PID $DART_SERVER_PID)"
echo ""

# Run C client tests
echo "Running C client tests..."
./c_rpc_client localhost
C_CLIENT_RESULT=$?

if [ $C_CLIENT_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ C Client -> Dart Server: PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ C Client -> Dart Server: FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Stop Dart server
kill $DART_SERVER_PID 2>/dev/null || true
wait $DART_SERVER_PID 2>/dev/null || true
DART_SERVER_PID=""

# Step 5: Print Summary
echo ""
echo "========================================="
echo "Test Matrix Summary"
echo "========================================="
echo ""
printf "%-30s %s\n" "Test Scenario" "Result"
echo "-----------------------------------------"

if [ $DART_CLIENT_RESULT -eq 0 ]; then
    printf "%-30s ${GREEN}✓ PASSED${NC}\n" "Dart Client -> C Server"
else
    printf "%-30s ${RED}✗ FAILED${NC}\n" "Dart Client -> C Server"
fi

if [ $C_CLIENT_RESULT -eq 0 ]; then
    printf "%-30s ${GREEN}✓ PASSED${NC}\n" "C Client -> Dart Server"
else
    printf "%-30s ${RED}✗ FAILED${NC}\n" "C Client -> Dart Server"
fi

echo "-----------------------------------------"
echo "Total Tests: 2"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "========================================="
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All compatibility tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some compatibility tests failed.${NC}"
    echo ""
    exit 1
fi
