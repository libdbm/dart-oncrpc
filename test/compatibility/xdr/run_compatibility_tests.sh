#!/bin/bash

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [clean]"
    echo ""
    echo "XDR Compatibility Test Suite for dart-oncrpc"
    echo ""
    echo "This script:"
    echo "  1. Compiles C programs using rpcgen-generated XDR code"
    echo "  2. Generates test data in XDR format using C"
    echo "  3. Generates equivalent test data using Dart"
    echo "  4. Verifies bidirectional compatibility between C and Dart XDR implementations"
    echo ""
    echo "Options:"
    echo "  clean    Remove all generated files and binaries"
    echo "  -h, --help  Show this help message"
    echo ""
    echo "Requirements:"
    echo "  - rpcgen (usually part of RPC development packages)"
    echo "  - C compiler (cc/gcc/clang)"
    echo "  - Dart SDK"
    exit 0
fi

# Handle clean option
if [ "$1" = "clean" ]; then
    echo "Cleaning up generated files..."
    cd "$(dirname "$0")"
    rm -f serialize_test_data verify_dart_xdr test_types_xdr.c test_types.h
    rm -rf output
    rm -rf output_dart
    echo "✓ Cleaned up successfully"
    exit 0
fi

echo "========================================="
echo "XDR Compatibility Test Suite"
echo "========================================="
echo ""

# Change to the test/compatibility directory
cd "$(dirname "$0")"

echo "0. Compiling C programs..."

# Check if rpcgen is available
if ! command -v rpcgen &> /dev/null; then
    echo "✗ Error: rpcgen not found. Please install rpcgen to continue."
    exit 1
fi

# Generate XDR code from the .x file if needed
if [ ! -f test_types_xdr.c ] || [ ! -f test_types.h ] || [ test_types.x -nt test_types_xdr.c ]; then
    echo "   Generating XDR code with rpcgen..."
    # Generate the header file
    rpcgen -h test_types.x -o test_types.h
    # Generate the XDR routines
    rpcgen -c test_types.x -o test_types_xdr.c
fi

# Compile serialize_test_data
if [ ! -f serialize_test_data ] || [ serialize_test_data.c -nt serialize_test_data ] || [ test_types_xdr.c -nt serialize_test_data ]; then
    echo "   Compiling serialize_test_data..."
    # Use -Wno-deprecated-non-prototype to suppress rpcgen's old-style function warnings
    cc -o serialize_test_data serialize_test_data.c test_types_xdr.c -Wno-deprecated-non-prototype 2>/dev/null || \
    cc -o serialize_test_data serialize_test_data.c test_types_xdr.c
    if [ $? -ne 0 ]; then
        echo "✗ Error: Failed to compile serialize_test_data"
        exit 1
    fi
fi

# Compile verify_dart_xdr
if [ ! -f verify_dart_xdr ] || [ verify_dart_xdr.c -nt verify_dart_xdr ] || [ test_types_xdr.c -nt verify_dart_xdr ]; then
    echo "   Compiling verify_dart_xdr..."
    # Use -Wno-deprecated-non-prototype to suppress rpcgen's old-style function warnings
    cc -o verify_dart_xdr verify_dart_xdr.c test_types_xdr.c -Wno-deprecated-non-prototype 2>/dev/null || \
    cc -o verify_dart_xdr verify_dart_xdr.c test_types_xdr.c
    if [ $? -ne 0 ]; then
        echo "✗ Error: Failed to compile verify_dart_xdr"
        exit 1
    fi
fi

echo "✓ C programs compiled successfully"
echo ""

echo "1. Generating test data with rpcgen/C..."
# Create output directory if it doesn't exist
mkdir -p output

if [ ! -f output/point.xdr ]; then
    ./serialize_test_data
    if [ $? -ne 0 ]; then
        echo "✗ Error: Failed to generate test data"
        exit 1
    fi
fi
echo "✓ C/rpcgen test data ready"
echo ""

echo "2. Generating test data with Dart..."
cd ../../..
dart run test/compatibility/xdr/generate_dart_xdr.dart > /dev/null 2>&1
echo "✓ Dart test data generated"
echo ""

echo "3. Verifying Dart can deserialize C/rpcgen data..."
echo -n "   Point: "
dart test test/compatibility/xdr/xdr_compatibility_test.dart --name "should deserialize Point" --reporter silent && echo "✓" || echo "✗"
echo -n "   Person: "
dart test test/compatibility/xdr/xdr_compatibility_test.dart --name "should deserialize Person" --reporter silent && echo "✓" || echo "✗"
echo -n "   Result: "
dart test test/compatibility/xdr/xdr_compatibility_test.dart --name "should deserialize Result" --reporter silent && echo "✓" || echo "✗"
echo ""

echo "4. Verifying C/rpcgen can deserialize Dart data..."
cd test/compatibility/xdr
echo -n "   Point: "
./verify_dart_xdr verify-point output_dart/point.xdr > /dev/null 2>&1 && echo "✓" || echo "✗"
echo -n "   Person: "
./verify_dart_xdr verify-person output_dart/person.xdr > /dev/null 2>&1 && echo "✓" || echo "✗"
echo -n "   Result (success): "
./verify_dart_xdr verify-result output_dart/result_success.xdr > /dev/null 2>&1 && echo "✓" || echo "✗"
echo -n "   Result (error): "
./verify_dart_xdr verify-result output_dart/result_error.xdr > /dev/null 2>&1 && echo "✓" || echo "✗"
echo ""

echo "5. Comparing binary output (Dart vs C)..."
echo -n "   Point.xdr: "
./verify_dart_xdr compare output_dart/point.xdr output/point.xdr | grep -q "identical" && echo "✓ Identical" || echo "✗ Different"
echo -n "   Person.xdr: "
./verify_dart_xdr compare output_dart/person.xdr output/person.xdr | grep -q "identical" && echo "✓ Identical" || echo "✗ Different"
echo -n "   Result_success.xdr: "
./verify_dart_xdr compare output_dart/result_success.xdr output/result_success.xdr | grep -q "identical" && echo "✓ Identical" || echo "✗ Different"
echo -n "   Result_error.xdr: "
./verify_dart_xdr compare output_dart/result_error.xdr output/result_error.xdr | grep -q "identical" && echo "✓ Identical" || echo "✗ Different"
echo ""

echo "========================================="
echo "Done"
echo "========================================="