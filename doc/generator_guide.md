# Code Generator Guide

The `dart_oncrpc` code generator (rpcgen) parses XDR/RPC specification files (`.x` files) and generates client/server code in multiple target languages. The generator is compatible with standard rpcgen and produces production-ready code.

## Table of Contents

- [Quick Start](#quick-start)
- [Command Line Usage](#command-line-usage)
- [Input Format (.x files)](#input-format-x-files)
- [Output Languages](#output-languages)
- [Generated Code Structure](#generated-code-structure)
- [Preprocessing](#preprocessing)
- [Type Mappings](#type-mappings)
- [Advanced Usage](#advanced-usage)

## Quick Start

Generate Dart client and server code:

```bash
dart run bin/rpcgen.dart -c -s -t myservice.x -o lib/generated/myservice.dart
```

Generate C code compatible with standard rpcgen:

```bash
dart run bin/rpcgen.dart -l c -o generated/ myservice.x
```

Generate Java code compatible with oncrpc4j:

```bash
dart run bin/rpcgen.dart -l java -p com.example.rpc -o generated/ myservice.x
```

## Command Line Usage

### Basic Syntax

```bash
dart run bin/rpcgen.dart [options] <input.x>
```

### Options

| Option | Abbr | Description |
|--------|------|-------------|
| `--help` | `-h` | Show help message |
| `--client` | `-c` | Generate client stubs |
| `--server` | `-s` | Generate server stubs |
| `--types` | `-t` | Generate type definitions |
| `--output` | `-o` | Output file (single artifact) or directory (multiple artifacts) |
| `--language` | `-l` | Target language: dart, c, java (default: dart) |
| `--package` | `-p` | Package name (for Java) |
| `--include-path` | `-I` | Add directory to include search path |
| `--define` | `-D` | Define a macro (NAME or NAME=VALUE) |
| `--no-preprocess` | | Skip preprocessing |
| `--save-preprocessed` | | Save preprocessed output to .pp file |

### Examples

Generate only client code:

```bash
dart run bin/rpcgen.dart -c --no-server myservice.x
```

Generate with preprocessor defines:

```bash
dart run bin/rpcgen.dart -DDEBUG -DMAX_SIZE=1024 myservice.x
```

Generate with includes:

```bash
dart run bin/rpcgen.dart -I/usr/include/rpc -I./common myservice.x
```

Output to stdout (useful for inspection):

```bash
dart run bin/rpcgen.dart myservice.x
```

> **Note:** If none of `-c`, `-s`, or `-t` are provided the generator produces all components. As soon as you specify one of these flags, the others remain disabled unless explicitly enabled (use `--no-client`, `--no-server`, or `--no-types` to disable them).

## Input Format (.x files)

XDR/RPC specification files use a C-like syntax to define types and RPC programs.

### Basic Structure

```c
/* Constants */
const MAX_NAME_LENGTH = 255;
const VERSION = 1;

/* Type definitions */
typedef string username<MAX_NAME_LENGTH>;

enum status {
    OK = 0,
    ERROR = 1,
    NOT_FOUND = 2
};

struct user {
    int id;
    username name;
    bool active;
};

/* RPC program definition */
program USER_SERVICE {
    version USER_V1 {
        user GET_USER(int) = 1;
        void SET_ACTIVE(int, bool) = 2;
    } = 1;
} = 0x20000001;
```

### Supported XDR Types

**Primitive Types:**
- `int` - 32-bit signed integer
- `unsigned int` - 32-bit unsigned integer
- `hyper` - 64-bit signed integer (BigInt in Dart)
- `unsigned hyper` - 64-bit unsigned integer
- `float` - 32-bit floating point
- `double` - 64-bit floating point
- `bool` - Boolean value
- `void` - No value (for procedures)

**Constructed Types:**
- `string<max>` - Variable-length string with optional max length
- `opaque<max>` - Variable-length byte array
- `opaque[size]` - Fixed-length byte array
- `type array[size]` - Fixed-length array
- `type array<max>` - Variable-length array
- `type *` - Optional value (pointer)
- `struct { ... }` - Structure
- `union switch(...) { ... }` - Discriminated union
- `enum { ... }` - Enumeration
- `typedef` - Type alias

### Structures

```c
struct file_info {
    string name<255>;
    unsigned hyper size;
    int mode;
    int owner;
    int group;
};
```

### Unions

```c
union read_result switch (int status) {
    case 0:
        opaque data<>;
    case 1:
        string error<>;
    default:
        void;
};
```

### Enumerations

```c
enum file_type {
    REGULAR = 1,
    DIRECTORY = 2,
    SYMLINK = 3,
    DEVICE = 4
};
```

### Optional Types

```c
struct node {
    int value;
    node *next;  /* Optional pointer to next node */
};
```

### Multi-Dimensional Arrays

```c
struct matrix {
    int data[10][10];  /* 10x10 fixed array */
    int values<><>;    /* Variable 2D array */
};
```

## Output Languages

### Dart

Generates type-safe Dart code with classes, enums, and encode/decode methods.

**Features:**
- Null-safe types
- Immutable classes with final fields
- Extension methods for XDR encoding/decoding
- Async client methods
- Abstract server interfaces

**Generated Files:**
- `{name}.dart` - Single file with types, client, and server

### C

Generates standard rpcgen-compatible C code.

**Features:**
- Header files with typedefs and function declarations
- XDR encoding/decoding functions
- Compatible with system RPC libraries
- Uses modern C types (int64_t, u_int64_t)

**Generated Files:**
- `{name}.h` - Header file with type definitions
- `{name}_xdr.c` - XDR encoding/decoding implementation

**Compatibility:**
The C generator produces output 100% compatible with standard rpcgen. You can:
- Compile generated code with system RPC libraries
- Mix generated code with hand-written C
- Use with existing RPC infrastructure

### Java

Generates code compatible with oncrpc4j and Remote Tea.

**Features:**
- Implements XdrAble interface
- Uses org.dcache.oncrpc4j.xdr packages
- Proper encapsulation with getters/setters
- Type-safe enums
- Static factory methods for decoding

**Generated Files:**
- `{TypeName}.java` - One file per type
- `Constants.java` - Interface with constant definitions

**Example:**
```bash
dart run bin/rpcgen.dart -l java -p com.example.myservice myservice.x
```

## Generated Code Structure

### Dart Client

```dart
class UserServiceClient {
  final RpcClient client;

  UserServiceClient(this.client);

  Future<User> getUser(int id) async {
    // XDR encode parameters
    // Make RPC call
    // XDR decode result
  }
}
```

### Dart Server

```dart
abstract class UserServiceServer {
  Future<User> getUser(int id);
  Future<void> setActive(int id, bool active);
}

class UserServiceServerRegistration {
  static void register(RpcServer server, UserServiceServer implementation) {
    // Register procedures with RPC server
  }
}
```

Usage:

```dart
class MyUserService implements UserServiceServer {
  @override
  Future<User> getUser(int id) async {
    // Implementation
  }

  @override
  Future<void> setActive(int id, bool active) async {
    // Implementation
  }
}

final server = RpcServer(transports: [TcpServerTransport(port: 8080)]);
UserServiceServerRegistration.register(server, MyUserService());
await server.listen();
```

### C Types

```c
// Header file
typedef char *username;

enum status {
    OK = 0,
    ERROR = 1,
    NOT_FOUND = 2
};

struct user {
    int id;
    username name;
    bool_t active;
};

// XDR functions
extern bool_t xdr_username(XDR *, username *);
extern bool_t xdr_status(XDR *, enum status *);
extern bool_t xdr_user(XDR *, struct user *);
```

### Java Types

```java
public class User implements XdrAble {
    private int id;
    private String name;
    private boolean active;

    // Getters and setters

    public void xdrEncode(XdrEncodingStream xdr) throws IOException {
        xdr.xdrEncodeInt(id);
        xdr.xdrEncodeString(name);
        xdr.xdrEncodeBoolean(active);
    }

    public static User xdrDecode(XdrDecodingStream xdr) throws IOException {
        User obj = new User();
        obj.id = xdr.xdrDecodeInt();
        obj.name = xdr.xdrDecodeString();
        obj.active = xdr.xdrDecodeBoolean();
        return obj;
    }
}
```

## Preprocessing

The generator includes a C-style preprocessor that handles:

### Include Directives

```c
#include "common.x"
#include <rpc/types.x>
```

Use `-I` to add include paths:

```bash
dart run bin/rpcgen.dart -I/usr/include/rpc -I./common myservice.x
```

### Macro Definitions

In .x file:

```c
#define MAX_SIZE 1024
#define VERSION 1

struct buffer {
    opaque data<MAX_SIZE>;
    int version;  /* Should be VERSION */
};
```

From command line:

```bash
dart run bin/rpcgen.dart -DMAX_SIZE=2048 -DVERSION=2 myservice.x
```

### Conditional Compilation

```c
#ifdef DEBUG
const LOG_LEVEL = 5;
#else
const LOG_LEVEL = 1;
#endif

#ifndef MAX_RETRIES
#define MAX_RETRIES 3
#endif
```

### Saving Preprocessed Output

To see what the preprocessor generated:

```bash
dart run bin/rpcgen.dart --save-preprocessed myservice.x
# Creates myservice.x.pp
```

## Type Mappings

### Dart Type Mapping

| XDR Type | Dart Type |
|----------|-----------|
| int | int |
| unsigned int | int |
| hyper | BigInt |
| unsigned hyper | BigInt |
| float | double |
| double | double |
| bool | bool |
| string | String |
| opaque | Uint8List |
| array | List&lt;T&gt; |
| optional | T? |
| struct | class |
| union | abstract class + subclasses |
| enum | enum |

### C Type Mapping

| XDR Type | C Type |
|----------|--------|
| int | int32_t |
| unsigned int | u_int32_t |
| hyper | int64_t |
| unsigned hyper | u_int64_t |
| float | float |
| double | double |
| bool | bool_t |
| string | char * |
| opaque | struct { u_int len; char *val; } |
| optional | pointer |

### Java Type Mapping

| XDR Type | Java Type |
|----------|-----------|
| int | int |
| unsigned int | int |
| hyper | long |
| unsigned hyper | long |
| float | float |
| double | double |
| bool | boolean |
| string | String |
| opaque | byte[] |
| array | T[] |
| optional | nullable |

## Advanced Usage

### Custom Type Prefixes

For avoiding name collisions:

```c
/* In your .x file, use prefixes */
struct myservice_user {
    int id;
    string name<>;
};

program MY_SERVICE {
    version V1 {
        myservice_user GET_USER(int) = 1;
    } = 1;
} = 0x20000001;
```

### Generating Multiple Languages

Generate for all languages:

```bash
# Dart
dart run bin/rpcgen.dart -l dart -o lib/generated/ myservice.x

# C
dart run bin/rpcgen.dart -l c -o c_generated/ myservice.x

# Java
dart run bin/rpcgen.dart -l java -p com.example -o java_generated/ myservice.x
```

### Integration with Build Systems

**Dart build.yaml:**

```yaml
targets:
  $default:
    builders:
      dart_oncrpc|rpcgen:
        generate_for:
          - lib/specs/*.x
        options:
          client: true
          server: true
```

**Makefile:**

```makefile
RPCGEN = dart run bin/rpcgen.dart

%.dart: %.x
	$(RPCGEN) -l dart -o $@ $<

%.h %_xdr.c: %.x
	$(RPCGEN) -l c -o . $<

all: myservice.dart myservice.h
```

### Error Handling

The generator provides detailed error messages:

```
Parse error: Expected identifier
At position: 245

Context:
Before: "struct user {
    int id;"
At error: " @#$ invalid
    string name;"
```

Common errors:
- Missing semicolons
- Undefined constants or types
- Invalid syntax in unions or structs
- Include file not found

### Best Practices

1. **Use constants for sizes:**
   ```c
   const MAX_PATH = 1024;
   typedef string path<MAX_PATH>;
   ```

2. **Version your programs:**
   ```c
   program MY_SERVICE {
       version V1 { ... } = 1;
       version V2 { ... } = 2;  /* New version for compatibility */
   } = 0x20000001;
   ```

3. **Document your types:**
   ```c
   /* User information structure
    * Used by GET_USER and LIST_USERS procedures
    */
   struct user {
       int id;          /* Unique user ID */
       string name<>;   /* Username */
   };
   ```

4. **Use descriptive names:**
   ```c
   /* Good */
   program USER_MANAGEMENT_SERVICE { ... }

   /* Avoid */
   program PROG1 { ... }
   ```

5. **Always implement procedure 0 (NULL):**
   ```c
   program MY_SERVICE {
       version V1 {
           void NULL(void) = 0;  /* Required for ping/health checks */
           /* ... other procedures ... */
       } = 1;
   } = 0x20000001;
   ```

## Examples

See the `test/data/` directory for complete examples:
- `ping.x` - Simple ping/echo service
- `types.x` - All XDR type demonstrations
- `mount.x` - NFS mount protocol
- `nfs3.x` - NFS version 3 protocol

## Troubleshooting

### "Parse error" messages

Check for:
- Missing semicolons
- Unclosed braces
- Invalid identifiers (must start with letter/underscore)

### "Type not found" errors

Ensure:
- Type is defined before use
- Include files are in the include path
- Preprocessor defines are correct

### C compilation errors

The generated C code requires:
- `#include <rpc/xdr.h>` in your project
- Link with `-lrpc` or `-ltirpc` (depending on system)

### Java compilation errors

Ensure:
- oncrpc4j or Remote Tea library is in classpath
- Package name matches directory structure
- Import statements are correct

## See Also

- [RPC Client Guide](client_guide.md)
- [RPC Server Guide](server_guide.md)
- [XDR Serialization Guide](xdr_guide.md)
- [RFC 4506 - XDR Specification](https://tools.ietf.org/html/rfc4506)
- [RFC 5531 - RPC Specification](https://tools.ietf.org/html/rfc5531)
