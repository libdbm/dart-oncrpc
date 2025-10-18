# XDR Serialization Guide

This guide covers XDR (External Data Representation) serialization and deserialization using the dart_oncrpc library.

## Table of Contents

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [XdrOutputStream](#xdroutputstream)
- [XdrInputStream](#xdrinputstream)
- [Primitive Types](#primitive-types)
- [Strings and Opaque Data](#strings-and-opaque-data)
- [Arrays](#arrays)
- [Structs](#structs)
- [Unions](#unions)
- [Enums](#enums)
- [Optional Types](#optional-types)
- [Custom Types](#custom-types)
- [Error Handling](#error-handling)
- [Performance Tips](#performance-tips)
- [Best Practices](#best-practices)

## Introduction

XDR (External Data Representation) is a standard for representing data structures in a machine-independent way. It's defined in RFC 4506 and is used by ONC-RPC for encoding parameters and results.

### Key Features

- **Platform Independent**: Works across different architectures and byte orders
- **Strongly Typed**: Each data type has specific encoding rules
- **4-byte Alignment**: All data is aligned to 4-byte boundaries
- **Big Endian**: Network byte order (most significant byte first)

### XDR vs Other Formats

| Feature | XDR | JSON | Protocol Buffers |
|---------|-----|------|------------------|
| Binary | Yes | No | Yes |
| Schema | Optional | No | Required |
| Alignment | 4-byte | N/A | Varies |
| Compatibility | RFC standard | Ubiquitous | Wide adoption |
| Size | Medium | Large | Small |

## Quick Start

### Encoding Data

```dart
import 'package:dart_oncrpc/dart_oncrpc.dart';

// Create output stream
final output = XdrOutputStream();

// Write data
output.writeInt(42);
output.writeString('Hello, XDR!');
output.writeBoolean(true);

// Get encoded bytes
final bytes = output.toBytes();
```

### Decoding Data

```dart
// Create input stream from bytes
final input = XdrInputStream(bytes);

// Read data in same order
final number = input.readInt();
final message = input.readString();
final flag = input.readBoolean();

print('Number: $number');
print('Message: $message');
print('Flag: $flag');
```

## XdrOutputStream

`XdrOutputStream` encodes Dart values into XDR format.

### Creating a Stream

```dart
final stream = XdrOutputStream();
```

### Getting Encoded Bytes

```dart
// Get as Uint8List
final bytes = stream.toBytes();

// Or use bytes property
final bytes = stream.bytes;
```

Both methods return the same result and can be called multiple times.

### Writing Methods

| Method | Parameter Type | XDR Type |
|--------|----------------|----------|
| `writeInt()` | int | 32-bit signed |
| `writeUnsignedInt()` | int | 32-bit unsigned |
| `writeHyper()` | BigInt | 64-bit signed |
| `writeUnsignedHyper()` | BigInt | 64-bit unsigned |
| `writeFloat()` | double | 32-bit float |
| `writeDouble()` | double | 64-bit double |
| `writeBoolean()` | bool | Boolean |
| `writeString()` | String | Variable string |
| `writeOpaque()` | Uint8List | Byte array |
| `writeBytes()` | Uint8List | Alias for writeOpaque |

## XdrInputStream

`XdrInputStream` decodes XDR-formatted bytes into Dart values.

### Creating a Stream

```dart
final stream = XdrInputStream(bytes);
```

### Stream Position

```dart
// Total size
final size = stream.size;

// Bytes remaining
final remaining = stream.remaining;

// Check if bytes available
if (stream.canRead(4)) {
  final value = stream.readInt();
}
```

### Reading Methods

| Method | Return Type | XDR Type |
|--------|-------------|----------|
| `readInt()` | int | 32-bit signed |
| `readUnsignedInt()` | int | 32-bit unsigned |
| `readHyper()` | BigInt | 64-bit signed |
| `readUnsignedHyper()` | BigInt | 64-bit unsigned |
| `readFloat()` | double | 32-bit float |
| `readDouble()` | double | 64-bit double |
| `readBoolean()` | bool | Boolean |
| `readString()` | String | Variable string |
| `readOpaque()` | Uint8List | Byte array |
| `readBytes()` | Uint8List | Alias for readOpaque |

## Primitive Types

### Integers

**32-bit signed integer:**

```dart
// Write
output.writeInt(42);
output.writeInt(-100);

// Read
final value = input.readInt();  // -2^31 to 2^31-1
```

**32-bit unsigned integer:**

```dart
// Write
output.writeUnsignedInt(4294967295);

// Read
final value = input.readUnsignedInt();  // 0 to 2^32-1
```

**64-bit integers (hyper):**

```dart
// Write
output.writeHyper(BigInt.parse('9223372036854775807'));
output.writeUnsignedHyper(BigInt.parse('18446744073709551615'));

// Read
final signed = input.readHyper();
final unsigned = input.readUnsignedHyper();
```

### Floating Point

**32-bit float:**

```dart
output.writeFloat(3.14);
final value = input.readFloat();
```

**64-bit double:**

```dart
output.writeDouble(3.141592653589793);
final value = input.readDouble();
```

### Boolean

```dart
output.writeBoolean(true);
output.writeBoolean(false);

final flag1 = input.readBoolean();
final flag2 = input.readBoolean();
```

Booleans are encoded as 32-bit integers (0 for false, 1 for true).

## Strings and Opaque Data

### Strings

Variable-length strings with UTF-8 encoding (ASCII by default per RFC):

```dart
// Write
output.writeString('Hello, World!');

// With maximum length
output.writeString('test', maxLength: 255);

// Strict ASCII mode
output.writeString('ASCII only', strict: true);

// Read
final str = input.readString();

// With maximum length check
final str = input.readString(maxLength: 255);

// Strict ASCII mode
final str = input.readString(strict: true);
```

**String Encoding:**
- Default: UTF-8 (for compatibility)
- Strict mode: ASCII only (RFC 4506 compliant)
- Length is encoded as 32-bit unsigned integer
- Padding to 4-byte boundary

### Opaque Data

Raw byte arrays:

```dart
// Variable-length opaque
final data = Uint8List.fromList([1, 2, 3, 4, 5]);
output.writeOpaque(data);

final decoded = input.readOpaque();

// Fixed-length opaque
output.writeOpaque(data, fixed: true);
final decoded = input.readOpaque(data.length);

// With maximum length
output.writeOpaque(data, maxLength: 1024);
final decoded = input.readOpaque(null, 1024);
```

## Arrays

### Fixed-Length Arrays

Arrays with known, constant size:

```dart
// Write fixed array
final items = [1, 2, 3, 4, 5];
output.writeFixedArray(items, (item, out) {
  out.writeInt(item);
});

// Read fixed array
final decoded = input.readFixedLengthArray(5, (inp) {
  return inp.readInt();
});
```

### Variable-Length Arrays

Arrays with runtime-determined size:

```dart
// Write variable array
final items = [10, 20, 30];
output.writeVarArray(items, (item, out) {
  out.writeInt(item);
});

// With maximum length
output.writeVarArray(items, (item, out) {
  out.writeInt(item);
}, maxLength: 100);

// Read variable array
final decoded = input.readVariableLengthArray((inp) {
  return inp.readInt();
});

// With maximum length check
final decoded = input.readVariableLengthArray(
  (inp) => inp.readInt(),
  maxLength: 100,
);
```

### Complex Array Elements

```dart
// Array of strings
output.writeVarArray(['Alice', 'Bob', 'Charlie'], (item, out) {
  out.writeString(item);
});

final names = input.readVariableLengthArray((inp) {
  return inp.readString();
});

// Array of structs
final users = [
  {'id': 1, 'name': 'Alice'},
  {'id': 2, 'name': 'Bob'},
];

output.writeVarArray(users, (user, out) {
  out.writeInt(user['id'] as int);
  out.writeString(user['name'] as String);
});

final decoded = input.readVariableLengthArray((inp) {
  return {
    'id': inp.readInt(),
    'name': inp.readString(),
  };
});
```

## Structs

Structures are sequences of typed fields.

### Manual Encoding

```dart
// Encode struct
void encodeUser(Map<String, dynamic> user, XdrOutputStream out) {
  out.writeInt(user['id'] as int);
  out.writeString(user['name'] as String);
  out.writeBoolean(user['active'] as bool);
  out.writeHyper(BigInt.from(user['created'] as int));
}

// Decode struct
Map<String, dynamic> decodeUser(XdrInputStream input) {
  return {
    'id': input.readInt(),
    'name': input.readString(),
    'active': input.readBoolean(),
    'created': input.readHyper().toInt(),
  };
}

// Usage
final user = {'id': 1, 'name': 'Alice', 'active': true, 'created': 1234567890};
encodeUser(user, output);

final decoded = decodeUser(input);
```

### Using XdrType Interface

```dart
class User implements XdrType {
  final int id;
  final String name;
  final bool active;

  User({required this.id, required this.name, required this.active});

  @override
  void encode(XdrOutputStream out) {
    out.writeInt(id);
    out.writeString(name);
    out.writeBoolean(active);
  }

  static User decode(XdrInputStream input) {
    return User(
      id: input.readInt(),
      name: input.readString(),
      active: input.readBoolean(),
    );
  }

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}

// Usage
final user = User(id: 1, name: 'Alice', active: true);
user.encode(output);

final decoded = User.decode(input);
```

### Nested Structs

```dart
class Address implements XdrType {
  final String street;
  final String city;
  final int zip;

  Address({required this.street, required this.city, required this.zip});

  @override
  void encode(XdrOutputStream out) {
    out.writeString(street);
    out.writeString(city);
    out.writeInt(zip);
  }

  static Address decode(XdrInputStream input) {
    return Address(
      street: input.readString(),
      city: input.readString(),
      zip: input.readInt(),
    );
  }

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}

class Person implements XdrType {
  final String name;
  final Address address;

  Person({required this.name, required this.address});

  @override
  void encode(XdrOutputStream out) {
    out.writeString(name);
    address.encode(out);  // Encode nested struct
  }

  static Person decode(XdrInputStream input) {
    return Person(
      name: input.readString(),
      address: Address.decode(input),  // Decode nested struct
    );
  }

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}
```

## Unions

Discriminated unions (tagged unions) where one of several alternatives is chosen based on a discriminant.

### Manual Union Encoding

```dart
// Union: either int value or string error
void encodeResult(Map<String, dynamic> result, XdrOutputStream out) {
  final type = result['type'] as int;
  out.writeInt(type);  // Discriminant

  switch (type) {
    case 0:  // Success - int value
      out.writeInt(result['value'] as int);
      break;
    case 1:  // Error - string message
      out.writeString(result['error'] as String);
      break;
    default:
      // Default case - void
      break;
  }
}

Map<String, dynamic> decodeResult(XdrInputStream input) {
  final type = input.readInt();

  switch (type) {
    case 0:
      return {'type': 0, 'value': input.readInt()};
    case 1:
      return {'type': 1, 'error': input.readString()};
    default:
      return {'type': type};
  }
}
```

### Using XdrUnion Base Class

```dart
abstract class Result extends XdrUnion {
  Result(super.discriminant, super.value);
}

class SuccessResult extends Result {
  final int value;

  SuccessResult(this.value) : super(0, XdrInt(value));

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}

class ErrorResult extends Result {
  final String error;

  ErrorResult(this.error) : super(1, XdrString(error));

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}

// Encoding is automatic via XdrUnion.encode()
final result = SuccessResult(42);
result.encode(output);

// Decoding
static Result decode(XdrInputStream input) {
  final discriminant = input.readInt();

  switch (discriminant) {
    case 0:
      final value = input.readInt();
      return SuccessResult(value);
    case 1:
      final error = input.readString();
      return ErrorResult(error);
    default:
      throw ArgumentError('Unknown discriminant: $discriminant');
  }
}
```

## Enums

Enumerations are encoded as 32-bit signed integers.

### Manual Enum Encoding

```dart
enum Status {
  ok(0),
  error(1),
  pending(2);

  final int value;
  const Status(this.value);

  static Status fromValue(int value) {
    return Status.values.firstWhere((e) => e.value == value);
  }
}

// Encode
output.writeInt(Status.ok.value);

// Decode
final status = Status.fromValue(input.readInt());
```

### Generated Enum Code

The code generator creates proper enum classes:

```dart
// Generated from: enum status { OK = 0, ERROR = 1, PENDING = 2 };

enum Status {
  ok(0),
  error(1),
  pending(2);

  final int value;
  const Status(this.value);

  factory Status.fromValue(int value) {
    switch (value) {
      case 0: return ok;
      case 1: return error;
      case 2: return pending;
      default: throw ArgumentError('Unknown Status value: $value');
    }
  }
}
```

## Optional Types

Optional values (pointers in XDR) are encoded with a presence flag.

### Manual Optional Encoding

```dart
// Encode optional value
void encodeOptional<T>(
  T? value,
  XdrOutputStream out,
  void Function(T, XdrOutputStream) encode,
) {
  if (value != null) {
    out.writeInt(1);  // Present
    encode(value, out);
  } else {
    out.writeInt(0);  // Not present
  }
}

// Decode optional value
T? decodeOptional<T>(
  XdrInputStream input,
  T Function(XdrInputStream) decode,
) {
  final present = input.readInt();
  if (present != 0) {
    return decode(input);
  }
  return null;
}

// Usage
encodeOptional(42, output, (val, out) => out.writeInt(val));
final value = decodeOptional<int>(input, (inp) => inp.readInt());

// Optional string
encodeOptional('test', output, (val, out) => out.writeString(val));
final str = decodeOptional<String>(input, (inp) => inp.readString());

// Optional null
encodeOptional<int>(null, output, (val, out) => out.writeInt(val));
final nullValue = decodeOptional<int>(input, (inp) => inp.readInt());
```

### Optional Structs

```dart
class OptionalUser {
  final User? user;

  OptionalUser({this.user});

  void encode(XdrOutputStream out) {
    if (user != null) {
      out.writeInt(1);
      user!.encode(out);
    } else {
      out.writeInt(0);
    }
  }

  static OptionalUser decode(XdrInputStream input) {
    final present = input.readInt();
    if (present != 0) {
      return OptionalUser(user: User.decode(input));
    }
    return OptionalUser(user: null);
  }
}
```

## Custom Types

### Creating Custom XDR Types

Implement the `XdrType` interface:

```dart
class Coordinate implements XdrType {
  final double latitude;
  final double longitude;

  Coordinate({required this.latitude, required this.longitude});

  @override
  void encode(XdrOutputStream out) {
    out.writeDouble(latitude);
    out.writeDouble(longitude);
  }

  static Coordinate decode(XdrInputStream input) {
    return Coordinate(
      latitude: input.readDouble(),
      longitude: input.readDouble(),
    );
  }

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}
```

### Type Aliases

Create type aliases for clarity:

```dart
typedef UserId = int;
typedef Username = String;
typedef Timestamp = BigInt;

class UserInfo {
  final UserId id;
  final Username name;
  final Timestamp created;

  UserInfo({required this.id, required this.name, required this.created});

  void encode(XdrOutputStream out) {
    out.writeInt(id);
    out.writeString(name);
    out.writeHyper(created);
  }

  static UserInfo decode(XdrInputStream input) {
    return UserInfo(
      id: input.readInt(),
      name: input.readString(),
      created: input.readHyper(),
    );
  }
}
```

## Error Handling

### XDR Exceptions

The library provides specific exceptions for XDR errors:

#### XdrEofException

Thrown when attempting to read beyond buffer:

```dart
try {
  final value = input.readInt();
} on XdrEofException catch (e) {
  print('Tried to read ${e.requested} bytes, only ${e.available} available');
}
```

#### XdrRangeException

Thrown when size limits are exceeded:

```dart
try {
  output.writeString('very long string...', maxLength: 10);
} on XdrRangeException catch (e) {
  print('Value ${e.value} exceeds limit for ${e.context}');
}

try {
  input.readString(maxLength: 10);
} on XdrRangeException catch (e) {
  print('String too long');
}
```

#### XdrFormatException

Thrown for invalid data format:

```dart
try {
  input.readString(strict: true);  // Expect ASCII only
} on XdrFormatException catch (e) {
  print('Format error: ${e.message}');
}
```

### Comprehensive Error Handling

```dart
Uint8List encodeData(Map<String, dynamic> data) {
  try {
    final output = XdrOutputStream();
    output.writeInt(data['id'] as int);
    output.writeString(data['name'] as String, maxLength: 255);
    return output.toBytes();
  } on XdrRangeException catch (e) {
    throw ArgumentError('Data exceeds size limits: $e');
  } catch (e) {
    throw ArgumentError('Failed to encode data: $e');
  }
}

Map<String, dynamic> decodeData(Uint8List bytes) {
  try {
    final input = XdrInputStream(bytes);
    return {
      'id': input.readInt(),
      'name': input.readString(maxLength: 255),
    };
  } on XdrEofException catch (e) {
    throw ArgumentError('Incomplete data: $e');
  } on XdrRangeException catch (e) {
    throw ArgumentError('Data validation failed: $e');
  } on XdrFormatException catch (e) {
    throw ArgumentError('Invalid data format: $e');
  } catch (e) {
    throw ArgumentError('Failed to decode data: $e');
  }
}
```

## Performance Tips

### 1. Reuse Streams for Multiple Operations

```dart
// Good - reuse stream
final output = XdrOutputStream();
for (final item in items) {
  encodeItem(item, output);
}
final bytes = output.toBytes();

// Avoid - creates many streams
final bytes = items.map((item) {
  final output = XdrOutputStream();
  encodeItem(item, output);
  return output.toBytes();
}).expand((x) => x).toList();
```

### 2. Batch Array Operations

```dart
// Good - batch write
output.writeVarArray(items, (item, out) {
  out.writeInt(item);
});

// Avoid - individual writes with length
output.writeInt(items.length);
for (final item in items) {
  output.writeInt(item);
}
```

### 3. Pre-calculate Sizes

For large data, pre-calculate size to avoid buffer resizing:

```dart
// Calculate size
int calculateSize(List<String> items) {
  var size = 4;  // Length prefix
  for (final item in items) {
    size += 4;  // String length
    size += item.length;  // String bytes
    size += (4 - (item.length % 4)) % 4;  // Padding
  }
  return size;
}
```

### 4. Use Typed Arrays

```dart
// Good - typed
final data = Uint8List(1024);

// Avoid - untyped
final data = List<int>.filled(1024, 0);
```

### 5. Avoid Unnecessary Conversions

```dart
// Good - direct bytes
output.writeOpaque(data);

// Avoid - conversion
output.writeOpaque(Uint8List.fromList(data.toList()));
```

## Best Practices

### 1. Always Validate Input

```dart
void encodeUser(User user, XdrOutputStream out) {
  if (user.name.length > 255) {
    throw ArgumentError('Name too long');
  }
  out.writeInt(user.id);
  out.writeString(user.name, maxLength: 255);
}
```

### 2. Document Size Limits

```dart
/// Encodes user information.
///
/// Constraints:
/// - name: max 255 characters
/// - email: max 320 characters (RFC standard)
void encodeUser(User user, XdrOutputStream out) {
  out.writeString(user.name, maxLength: 255);
  out.writeString(user.email, maxLength: 320);
}
```

### 3. Use Type-Safe Wrappers

```dart
class UserId {
  final int value;
  const UserId(this.value);

  void encode(XdrOutputStream out) => out.writeInt(value);
  static UserId decode(XdrInputStream input) => UserId(input.readInt());
}
```

### 4. Test Round-Trip Encoding

```dart
test('User round-trip encoding', () {
  final original = User(id: 1, name: 'Alice', active: true);

  // Encode
  final output = XdrOutputStream();
  original.encode(output);
  final bytes = output.toBytes();

  // Decode
  final input = XdrInputStream(bytes);
  final decoded = User.decode(input);

  // Verify
  expect(decoded.id, equals(original.id));
  expect(decoded.name, equals(original.name));
  expect(decoded.active, equals(original.active));
});
```

### 5. Handle Endianness Correctly

XDR always uses big-endian (network byte order). The library handles this automatically, but be aware when integrating with other systems:

```dart
// Library handles endianness automatically
output.writeInt(0x12345678);

// Don't manually swap bytes
// BAD: output.writeInt(swap32(value));
```

### 6. Use Generated Code

For complex types, use the code generator:

```bash
dart run bin/rpcgen.dart -t mytypes.x -o lib/types.dart
```

This ensures correct encoding/decoding and maintains compatibility.

### 7. Version Your Data

Include version numbers in serialized data:

```dart
const VERSION = 1;

void encode(XdrOutputStream out) {
  out.writeInt(VERSION);
  // ... encode fields ...
}

static MyType decode(XdrInputStream input) {
  final version = input.readInt();
  if (version != VERSION) {
    throw ArgumentError('Unsupported version: $version');
  }
  // ... decode fields ...
}
```

### 8. Check Remaining Bytes

```dart
MyType decode(XdrInputStream input) {
  final data = MyType(
    id: input.readInt(),
    name: input.readString(),
  );

  if (input.remaining > 0) {
    print('Warning: ${input.remaining} unread bytes');
  }

  return data;
}
```

## Examples

### Complete Example: File Metadata

```dart
class FileMetadata implements XdrType {
  final String name;
  final int size;
  final int mode;
  final BigInt modified;
  final String? owner;

  FileMetadata({
    required this.name,
    required this.size,
    required this.mode,
    required this.modified,
    this.owner,
  });

  @override
  void encode(XdrOutputStream out) {
    out.writeString(name, maxLength: 255);
    out.writeUnsignedInt(size);
    out.writeInt(mode);
    out.writeHyper(modified);

    // Optional owner
    if (owner != null) {
      out.writeInt(1);
      out.writeString(owner!, maxLength: 32);
    } else {
      out.writeInt(0);
    }
  }

  static FileMetadata decode(XdrInputStream input) {
    final name = input.readString(maxLength: 255);
    final size = input.readUnsignedInt();
    final mode = input.readInt();
    final modified = input.readHyper();

    String? owner;
    final ownerPresent = input.readInt();
    if (ownerPresent != 0) {
      owner = input.readString(maxLength: 32);
    }

    return FileMetadata(
      name: name,
      size: size,
      mode: mode,
      modified: modified,
      owner: owner,
    );
  }

  @override
  Uint8List toXdr() {
    final stream = XdrOutputStream();
    encode(stream);
    return stream.toBytes();
  }
}

// Usage
void main() {
  final metadata = FileMetadata(
    name: 'document.txt',
    size: 1024,
    mode: 0644,
    modified: BigInt.from(DateTime.now().millisecondsSinceEpoch),
    owner: 'alice',
  );

  // Encode
  final output = XdrOutputStream();
  metadata.encode(output);
  final bytes = output.toBytes();

  print('Encoded ${bytes.length} bytes');

  // Decode
  final input = XdrInputStream(bytes);
  final decoded = FileMetadata.decode(input);

  print('Name: ${decoded.name}');
  print('Size: ${decoded.size}');
  print('Mode: ${decoded.mode.toRadixString(8)}');
  print('Owner: ${decoded.owner}');
}
```

## See Also

- [RPC Client Guide](client_guide.md)
- [RPC Server Guide](server_guide.md)
- [Code Generator Guide](generator_guide.md)
- [RFC 4506 - XDR Specification](https://tools.ietf.org/html/rfc4506)
