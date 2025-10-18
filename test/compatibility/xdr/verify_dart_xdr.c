#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <rpc/rpc.h>
#include "test_types.h"

int verify_point(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        printf("Failed to open %s\n", filename);
        return 0;
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_DECODE);
    
    Point point;
    if (!xdr_Point(&xdr, &point)) {
        printf("Failed to deserialize Point from %s\n", filename);
        xdr_destroy(&xdr);
        fclose(file);
        return 0;
    }
    
    xdr_destroy(&xdr);
    fclose(file);
    
    printf("Point from %s: x=%d, y=%d\n", filename, point.x, point.y);
    return 1;
}

int verify_person(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        printf("Failed to open %s\n", filename);
        return 0;
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_DECODE);
    
    Person person;
    person.name = NULL; // Important: initialize pointer
    
    if (!xdr_Person(&xdr, &person)) {
        printf("Failed to deserialize Person from %s\n", filename);
        xdr_destroy(&xdr);
        fclose(file);
        return 0;
    }
    
    xdr_destroy(&xdr);
    fclose(file);
    
    printf("Person from %s:\n", filename);
    printf("  Name: %s\n", person.name);
    printf("  Age: %u\n", person.age);
    printf("  Color: %d\n", person.favorite_color);
    printf("  Scores: ");
    for (int i = 0; i < ARRAY_SIZE; i++) {
        printf("%d ", person.scores[i]);
    }
    printf("\n");
    
    free(person.name);
    return 1;
}

int verify_result(const char *filename) {
    FILE *file = fopen(filename, "rb");
    if (!file) {
        printf("Failed to open %s\n", filename);
        return 0;
    }
    
    XDR xdr;
    xdrstdio_create(&xdr, file, XDR_DECODE);
    
    Result result;
    memset(&result, 0, sizeof(result)); // Initialize
    
    if (!xdr_Result(&xdr, &result)) {
        printf("Failed to deserialize Result from %s\n", filename);
        xdr_destroy(&xdr);
        fclose(file);
        return 0;
    }
    
    xdr_destroy(&xdr);
    fclose(file);
    
    printf("Result from %s:\n", filename);
    printf("  Status: %d\n", result.status);
    
    switch (result.status) {
        case 0:
            printf("  Person:\n");
            printf("    Name: %s\n", result.Result_u.person.name);
            printf("    Age: %u\n", result.Result_u.person.age);
            printf("    Color: %d\n", result.Result_u.person.favorite_color);
            printf("    Scores: ");
            for (int i = 0; i < ARRAY_SIZE; i++) {
                printf("%d ", result.Result_u.person.scores[i]);
            }
            printf("\n");
            xdr_free((xdrproc_t)xdr_Person, (char*)&result.Result_u.person);
            break;
            
        case 1:
            printf("  Error: %s\n", result.Result_u.error_message);
            free(result.Result_u.error_message);
            break;
            
        default:
            printf("  (void)\n");
            break;
    }
    
    return 1;
}

int compare_files(const char *file1, const char *file2) {
    FILE *f1 = fopen(file1, "rb");
    FILE *f2 = fopen(file2, "rb");
    
    if (!f1 || !f2) {
        if (f1) fclose(f1);
        if (f2) fclose(f2);
        printf("Failed to open files for comparison\n");
        return 0;
    }
    
    // Get file sizes
    fseek(f1, 0, SEEK_END);
    long size1 = ftell(f1);
    fseek(f1, 0, SEEK_SET);
    
    fseek(f2, 0, SEEK_END);
    long size2 = ftell(f2);
    fseek(f2, 0, SEEK_SET);
    
    if (size1 != size2) {
        printf("Files have different sizes: %ld vs %ld\n", size1, size2);
        fclose(f1);
        fclose(f2);
        return 0;
    }
    
    // Compare byte by byte
    int byte1, byte2;
    long position = 0;
    int differences = 0;
    
    while ((byte1 = fgetc(f1)) != EOF && (byte2 = fgetc(f2)) != EOF) {
        if (byte1 != byte2) {
            if (differences < 10) { // Show first 10 differences
                printf("Difference at byte %ld: 0x%02X vs 0x%02X\n", 
                       position, byte1, byte2);
            }
            differences++;
        }
        position++;
    }
    
    fclose(f1);
    fclose(f2);
    
    if (differences == 0) {
        printf("Files are identical (%ld bytes)\n", size1);
        return 1;
    } else {
        printf("Files differ at %d positions\n", differences);
        return 0;
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <command> [args...]\n", argv[0]);
        printf("Commands:\n");
        printf("  verify-point <file>     - Deserialize Point from Dart XDR\n");
        printf("  verify-person <file>    - Deserialize Person from Dart XDR\n");
        printf("  verify-result <file>    - Deserialize Result from Dart XDR\n");
        printf("  compare <file1> <file2> - Compare two XDR files byte-by-byte\n");
        return 1;
    }
    
    const char *command = argv[1];
    
    if (strcmp(command, "verify-point") == 0 && argc == 3) {
        return verify_point(argv[2]) ? 0 : 1;
    }
    else if (strcmp(command, "verify-person") == 0 && argc == 3) {
        return verify_person(argv[2]) ? 0 : 1;
    }
    else if (strcmp(command, "verify-result") == 0 && argc == 3) {
        return verify_result(argv[2]) ? 0 : 1;
    }
    else if (strcmp(command, "compare") == 0 && argc == 4) {
        return compare_files(argv[2], argv[3]) ? 0 : 1;
    }
    else {
        printf("Invalid command or arguments\n");
        return 1;
    }
}