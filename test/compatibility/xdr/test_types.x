/*
 * Test XDR types for compatibility testing
 */

const MAX_STRING_LEN = 255;
const ARRAY_SIZE = 5;

enum Color {
    RED = 0,
    GREEN = 1,
    BLUE = 2
};

struct Point {
    int x;
    int y;
};

struct Person {
    string name<MAX_STRING_LEN>;
    unsigned int age;
    Color favorite_color;
    int scores[ARRAY_SIZE];
};

union Result switch (int status) {
case 0:
    Person person;
case 1:
    string error_message<>;
default:
    void;
};

typedef opaque Data<1024>;

struct ComplexType {
    hyper big_number;
    unsigned hyper unsigned_big;
    float float_val;
    double double_val;
    bool bool_val;
    Data binary_data;
    Point *optional_point;
};