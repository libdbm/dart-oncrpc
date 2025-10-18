#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <rpc/rpc.h>
#include "test_types.h"

void serialize_point(const char *filename) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("Failed to open file");
        exit(1);
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_ENCODE);
    
    Point point;
    point.x = 100;
    point.y = 200;
    
    if (!xdr_Point(&xdr, &point)) {
        fprintf(stderr, "Failed to serialize Point\n");
        exit(1);
    }
    
    xdr_destroy(&xdr);
    fclose(file);
    printf("Serialized Point to %s\n", filename);
}

void serialize_person(const char *filename) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("Failed to open file");
        exit(1);
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_ENCODE);
    
    Person person;
    person.name = strdup("Alice Johnson");
    person.age = 30;
    person.favorite_color = GREEN;
    for (int i = 0; i < ARRAY_SIZE; i++) {
        person.scores[i] = (i + 1) * 10;
    }
    
    if (!xdr_Person(&xdr, &person)) {
        fprintf(stderr, "Failed to serialize Person\n");
        exit(1);
    }
    
    xdr_destroy(&xdr);
    free(person.name);
    fclose(file);
    printf("Serialized Person to %s\n", filename);
}

void serialize_result_success(const char *filename) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("Failed to open file");
        exit(1);
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_ENCODE);
    
    Result result;
    result.status = 0;
    result.Result_u.person.name = strdup("Bob Smith");
    result.Result_u.person.age = 25;
    result.Result_u.person.favorite_color = BLUE;
    for (int i = 0; i < ARRAY_SIZE; i++) {
        result.Result_u.person.scores[i] = (i + 1) * 5;
    }
    
    if (!xdr_Result(&xdr, &result)) {
        fprintf(stderr, "Failed to serialize Result\n");
        exit(1);
    }
    
    xdr_destroy(&xdr);
    free(result.Result_u.person.name);
    fclose(file);
    printf("Serialized Result (success) to %s\n", filename);
}

void serialize_result_error(const char *filename) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("Failed to open file");
        exit(1);
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_ENCODE);
    
    Result result;
    result.status = 1;
    result.Result_u.error_message = strdup("Something went wrong");
    
    if (!xdr_Result(&xdr, &result)) {
        fprintf(stderr, "Failed to serialize Result\n");
        exit(1);
    }
    
    xdr_destroy(&xdr);
    free(result.Result_u.error_message);
    fclose(file);
    printf("Serialized Result (error) to %s\n", filename);
}

void serialize_complex_type(const char *filename) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("Failed to open file");
        exit(1);
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_ENCODE);
    
    ComplexType complex;
    complex.big_number = 9223372036854775807LL; // max int64
    complex.unsigned_big = 18446744073709551615ULL; // max uint64
    complex.float_val = 3.14159f;
    complex.double_val = 2.718281828;
    complex.bool_val = TRUE;
    
    // Binary data
    complex.binary_data.Data_len = 10;
    complex.binary_data.Data_val = (char*)malloc(10);
    for (int i = 0; i < 10; i++) {
        complex.binary_data.Data_val[i] = i;
    }
    
    // Optional point (present)
    Point point;
    point.x = 42;
    point.y = 84;
    complex.optional_point = &point;
    
    if (!xdr_ComplexType(&xdr, &complex)) {
        fprintf(stderr, "Failed to serialize ComplexType\n");
        exit(1);
    }
    
    xdr_destroy(&xdr);
    free(complex.binary_data.Data_val);
    fclose(file);
    printf("Serialized ComplexType to %s\n", filename);
}

void serialize_complex_type_null(const char *filename) {
    FILE *file = fopen(filename, "wb");
    if (!file) {
        perror("Failed to open file");
        exit(1);
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_ENCODE);
    
    ComplexType complex;
    complex.big_number = -9223372036854775808LL; // min int64
    complex.unsigned_big = 0;
    complex.float_val = -123.456f;
    complex.double_val = -987.654321;
    complex.bool_val = FALSE;
    
    // Empty binary data
    complex.binary_data.Data_len = 0;
    complex.binary_data.Data_val = NULL;
    
    // Optional point (null)
    complex.optional_point = NULL;
    
    if (!xdr_ComplexType(&xdr, &complex)) {
        fprintf(stderr, "Failed to serialize ComplexType\n");
        exit(1);
    }
    
    xdr_destroy(&xdr);
    fclose(file);
    printf("Serialized ComplexType (with null) to %s\n", filename);
}

int main() {
    // Create test data directory
    system("mkdir -p output");
    
    // Serialize different types
    serialize_point("output/point.xdr");
    serialize_person("output/person.xdr");
    serialize_result_success("output/result_success.xdr");
    serialize_result_error("output/result_error.xdr");
    serialize_complex_type("output/complex.xdr");
    serialize_complex_type_null("output/complex_null.xdr");
    
    printf("\nAll test data serialized successfully!\n");
    return 0;
}