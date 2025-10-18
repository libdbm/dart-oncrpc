/* Simple calculator RPC service */

const MAX_NUMBERS = 100;

enum Operation {
    ADD = 0,
    SUBTRACT = 1,
    MULTIPLY = 2,
    DIVIDE = 3
};

struct CalculatorRequest {
    Operation op;
    double operand1;
    double operand2;
};

struct CalculatorResult {
    bool success;
    double result;
    string error_message<256>;
};

struct BatchRequest {
    int count;
    CalculatorRequest requests<MAX_NUMBERS>;
};

struct BatchResult {
    int count;
    CalculatorResult results<MAX_NUMBERS>;
};

program CALCULATOR_PROG {
    version CALCULATOR_VERS {
        CalculatorResult CALCULATE(CalculatorRequest) = 1;
        BatchResult BATCH_CALCULATE(BatchRequest) = 2;
        void PING(void) = 3;
    } = 1;
} = 0x20000001;