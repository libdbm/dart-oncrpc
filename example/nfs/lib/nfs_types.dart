//  Generated ONC-RPC code
//  DO NOT EDIT - Generated from .x file
//  ignore_for_file: constant_identifier_names, non_constant_identifier_names, unreachable_switch_default, cascade_invocations, unused_import, prefer_constructors_over_static_methods, sort_constructors_first, avoid_positional_boolean_parameters, no_leading_underscores_for_local_identifiers

import 'dart:typed_data';
import 'package:dart_oncrpc/src/rpc/rpc_authentication.dart';
import 'package:dart_oncrpc/src/rpc/rpc_client.dart';
import 'package:dart_oncrpc/src/rpc/rpc_server.dart';
import 'package:dart_oncrpc/src/xdr/xdr_io.dart';

//  Standard XDR boolean constants
const TRUE = 1;
const FALSE = 0;

const NFS3_FHSIZE = 64;
const NFS3_WRITEVERFSIZE = 8;
const NFS3_CREATEVERFSIZE = 8;
const NFS3_COOKIEVERFSIZE = 8;
const ACCESS3_READ = 1;
const ACCESS3_LOOKUP = 2;
const ACCESS3_MODIFY = 4;
const ACCESS3_EXTEND = 8;
const ACCESS3_DELETE = 16;
const ACCESS3_EXECUTE = 32;
const FSF3_LINK = 1;
const FSF3_SYMLINK = 2;
const FSF3_HOMOGENEOUS = 8;
const FSF3_CANSETTIME = 16;
const FHSIZE2 = 32;
const MAXNAMLEN2 = 255;
const MAXPATHLEN2 = 1024;
const NFSMAXDATA2 = 8192;
const NFSCOOKIESIZE2 = 4;
const NFSACL_PERM_READ = 4;
const NFSACL_PERM_WRITE = 2;
const NFSACL_PERM_EXEC = 1;
const NFSACL_MASK_ACL_ENTRY = 1;
const NFSACL_MASK_ACL_COUNT = 2;
const NFSACL_MASK_ACL_DEFAULT_ENTRY = 4;
const NFSACL_MASK_ACL_DEFAULT_COUNT = 8;

// Typedef: cookieverf3
typedef cookieverf3 = Uint8List;


// Typedef: cookie3
typedef cookie3 = BigInt;


// Struct: nfs_fh3
class nfs_fh3 {
  final Uint8List data;

  nfs_fh3({
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(data);
  }

  static nfs_fh3 decode(XdrInputStream stream) {
    final data = stream.readOpaque();
    return nfs_fh3 (
      data: data,
    );
  }
}


// Typedef: filename3
typedef filename3 = String;


// Struct: diropargs3
class diropargs3 {
  final nfs_fh3 dir;
  final filename3 name;

  diropargs3({
    required this.dir,
    required this.name,
  });

  void encode(XdrOutputStream stream) {
    dir.encode(stream);
    stream.writeString(name);
  }

  static diropargs3 decode(XdrInputStream stream) {
    final dir = nfs_fh3.decode(stream);
    final name = stream.readString();
    return diropargs3 (
      dir: dir,
      name: name,
    );
  }
}


//  Enum: ftype3
enum ftype3 {
  nf3reg(1),
  nf3dir(2),
  nf3blk(3),
  nf3chr(4),
  nf3lnk(5),
  nf3sock(6),
  nf3fifo(7),
  ;

  final int value;
  const ftype3(this.value);

//    Create from XDR integer value
  factory ftype3.fromValue(final int value) => switch (value) {
      1 => nf3reg,
      2 => nf3dir,
      3 => nf3blk,
      4 => nf3chr,
      5 => nf3lnk,
      6 => nf3sock,
      7 => nf3fifo,
      _ => throw ArgumentError('Unknown ftype3 value: $value'),
    };

//    Get all possible values
  static List<ftype3> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      1 => true,
      2 => true,
      3 => true,
      4 => true,
      5 => true,
      6 => true,
      7 => true,
      _ => false,
    };
}


// Typedef: mode3
typedef mode3 = int;


// Typedef: uid3
typedef uid3 = int;


// Typedef: gid3
typedef gid3 = int;


// Typedef: size3
typedef size3 = BigInt;


// Typedef: fileid3
typedef fileid3 = BigInt;


// Struct: specdata3
class specdata3 {
  final int specdata1;
  final int specdata2;

  specdata3({
    required this.specdata1,
    required this.specdata2,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedInt(specdata1);
    stream.writeUnsignedInt(specdata2);
  }

  static specdata3 decode(XdrInputStream stream) {
    final specdata1 = stream.readUnsignedInt();
    final specdata2 = stream.readUnsignedInt();
    return specdata3 (
      specdata1: specdata1,
      specdata2: specdata2,
    );
  }
}


// Struct: nfstime3
class nfstime3 {
  final int seconds;
  final int nseconds;

  nfstime3({
    required this.seconds,
    required this.nseconds,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedInt(seconds);
    stream.writeUnsignedInt(nseconds);
  }

  static nfstime3 decode(XdrInputStream stream) {
    final seconds = stream.readUnsignedInt();
    final nseconds = stream.readUnsignedInt();
    return nfstime3 (
      seconds: seconds,
      nseconds: nseconds,
    );
  }
}


// Struct: fattr3
class fattr3 {
  final ftype3 type;
  final mode3 mode;
  final int nlink;
  final uid3 uid;
  final gid3 gid;
  final size3 size;
  final size3 used;
  final specdata3 rdev;
  final BigInt fsid;
  final fileid3 fileid;
  final nfstime3 atime;
  final nfstime3 mtime;
  final nfstime3 ctime;

  fattr3({
    required this.type,
    required this.mode,
    required this.nlink,
    required this.uid,
    required this.gid,
    required this.size,
    required this.used,
    required this.rdev,
    required this.fsid,
    required this.fileid,
    required this.atime,
    required this.mtime,
    required this.ctime,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(type.value);
    stream.writeUnsignedInt(mode);
    stream.writeUnsignedInt(nlink);
    stream.writeUnsignedInt(uid);
    stream.writeUnsignedInt(gid);
    stream.writeUnsignedHyper(size);
    stream.writeUnsignedHyper(used);
    rdev.encode(stream);
    stream.writeUnsignedHyper(fsid);
    stream.writeUnsignedHyper(fileid);
    atime.encode(stream);
    mtime.encode(stream);
    ctime.encode(stream);
  }

  static fattr3 decode(XdrInputStream stream) {
     final typeValue = stream.readInt();
    final type =ftype3.fromValue(typeValue);
    final mode = stream.readUnsignedInt();
    final nlink = stream.readUnsignedInt();
    final uid = stream.readUnsignedInt();
    final gid = stream.readUnsignedInt();
    final size = stream.readUnsignedHyper();
    final used = stream.readUnsignedHyper();
    final rdev = specdata3.decode(stream);
    final fsid = stream.readUnsignedHyper();
    final fileid = stream.readUnsignedHyper();
    final atime = nfstime3.decode(stream);
    final mtime = nfstime3.decode(stream);
    final ctime = nfstime3.decode(stream);
    return fattr3 (
      type: type,
      mode: mode,
      nlink: nlink,
      uid: uid,
      gid: gid,
      size: size,
      used: used,
      rdev: rdev,
      fsid: fsid,
      fileid: fileid,
      atime: atime,
      mtime: mtime,
      ctime: ctime,
    );
  }
}


// Union: post_op_attr
abstract class post_op_attr {
  final bool discriminant;
  post_op_attr(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static post_op_attr decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = fattr3.decode(stream);
        return post_op_attrTrue(value);
      case false:
        return post_op_attrFalse();
      default:
        throw ArgumentError('Unknown discriminant: $discriminant');
    }
  }
}

class post_op_attrTrue extends post_op_attr {
  final fattr3 value;
  post_op_attrTrue(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class post_op_attrFalse extends post_op_attr {
  post_op_attrFalse() : super(false);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


//  Enum: nfsstat3
enum nfsstat3 {
  nfs3_ok(0),
  nfs3err_perm(1),
  nfs3err_noent(2),
  nfs3err_io(5),
  nfs3err_nxio(6),
  nfs3err_acces(13),
  nfs3err_exist(17),
  nfs3err_xdev(18),
  nfs3err_nodev(19),
  nfs3err_notdir(20),
  nfs3err_isdir(21),
  nfs3err_inval(22),
  nfs3err_fbig(27),
  nfs3err_nospc(28),
  nfs3err_rofs(30),
  nfs3err_mlink(31),
  nfs3err_nametoolong(63),
  nfs3err_notempty(66),
  nfs3err_dquot(69),
  nfs3err_stale(70),
  nfs3err_remote(71),
  nfs3err_badhandle(10001),
  nfs3err_not_sync(10002),
  nfs3err_bad_cookie(10003),
  nfs3err_notsupp(10004),
  nfs3err_toosmall(10005),
  nfs3err_serverfault(10006),
  nfs3err_badtype(10007),
  nfs3err_jukebox(10008),
  ;

  final int value;
  const nfsstat3(this.value);

//    Create from XDR integer value
  factory nfsstat3.fromValue(final int value) => switch (value) {
      0 => nfs3_ok,
      1 => nfs3err_perm,
      2 => nfs3err_noent,
      5 => nfs3err_io,
      6 => nfs3err_nxio,
      13 => nfs3err_acces,
      17 => nfs3err_exist,
      18 => nfs3err_xdev,
      19 => nfs3err_nodev,
      20 => nfs3err_notdir,
      21 => nfs3err_isdir,
      22 => nfs3err_inval,
      27 => nfs3err_fbig,
      28 => nfs3err_nospc,
      30 => nfs3err_rofs,
      31 => nfs3err_mlink,
      63 => nfs3err_nametoolong,
      66 => nfs3err_notempty,
      69 => nfs3err_dquot,
      70 => nfs3err_stale,
      71 => nfs3err_remote,
      10001 => nfs3err_badhandle,
      10002 => nfs3err_not_sync,
      10003 => nfs3err_bad_cookie,
      10004 => nfs3err_notsupp,
      10005 => nfs3err_toosmall,
      10006 => nfs3err_serverfault,
      10007 => nfs3err_badtype,
      10008 => nfs3err_jukebox,
      _ => throw ArgumentError('Unknown nfsstat3 value: $value'),
    };

//    Get all possible values
  static List<nfsstat3> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      0 => true,
      1 => true,
      2 => true,
      5 => true,
      6 => true,
      13 => true,
      17 => true,
      18 => true,
      19 => true,
      20 => true,
      21 => true,
      22 => true,
      27 => true,
      28 => true,
      30 => true,
      31 => true,
      63 => true,
      66 => true,
      69 => true,
      70 => true,
      71 => true,
      10001 => true,
      10002 => true,
      10003 => true,
      10004 => true,
      10005 => true,
      10006 => true,
      10007 => true,
      10008 => true,
      _ => false,
    };
}


//  Enum: stable_how
enum stable_how {
  unstable(0),
  data_sync(1),
  file_sync(2),
  ;

  final int value;
  const stable_how(this.value);

//    Create from XDR integer value
  factory stable_how.fromValue(final int value) => switch (value) {
      0 => unstable,
      1 => data_sync,
      2 => file_sync,
      _ => throw ArgumentError('Unknown stable_how value: $value'),
    };

//    Get all possible values
  static List<stable_how> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      0 => true,
      1 => true,
      2 => true,
      _ => false,
    };
}


// Typedef: offset3
typedef offset3 = BigInt;


// Typedef: count3
typedef count3 = int;


// Struct: wcc_attr
class wcc_attr {
  final size3 size;
  final nfstime3 mtime;
  final nfstime3 ctime;

  wcc_attr({
    required this.size,
    required this.mtime,
    required this.ctime,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedHyper(size);
    mtime.encode(stream);
    ctime.encode(stream);
  }

  static wcc_attr decode(XdrInputStream stream) {
    final size = stream.readUnsignedHyper();
    final mtime = nfstime3.decode(stream);
    final ctime = nfstime3.decode(stream);
    return wcc_attr (
      size: size,
      mtime: mtime,
      ctime: ctime,
    );
  }
}


// Union: pre_op_attr
abstract class pre_op_attr {
  final bool discriminant;
  pre_op_attr(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static pre_op_attr decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = wcc_attr.decode(stream);
        return pre_op_attrTrue(value);
      case false:
        return pre_op_attrFalse();
      default:
        throw ArgumentError('Unknown discriminant: $discriminant');
    }
  }
}

class pre_op_attrTrue extends pre_op_attr {
  final wcc_attr value;
  pre_op_attrTrue(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class pre_op_attrFalse extends pre_op_attr {
  pre_op_attrFalse() : super(false);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: wcc_data
class wcc_data {
  final pre_op_attr before;
  final post_op_attr after;

  wcc_data({
    required this.before,
    required this.after,
  });

  void encode(XdrOutputStream stream) {
    before.encode(stream);
    after.encode(stream);
  }

  static wcc_data decode(XdrInputStream stream) {
    final before = pre_op_attr.decode(stream);
    final after = post_op_attr.decode(stream);
    return wcc_data (
      before: before,
      after: after,
    );
  }
}


// Struct: WRITE3args
class WRITE3args {
  final nfs_fh3 file;
  final offset3 offset;
  final count3 count;
  final stable_how stable;
  final Uint8List data;

  WRITE3args({
    required this.file,
    required this.offset,
    required this.count,
    required this.stable,
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    file.encode(stream);
    stream.writeUnsignedHyper(offset);
    stream.writeUnsignedInt(count);
    stream.writeInt(stable.value);
    stream.writeOpaque(data);
  }

  static WRITE3args decode(XdrInputStream stream) {
    final file = nfs_fh3.decode(stream);
    final offset = stream.readUnsignedHyper();
    final count = stream.readUnsignedInt();
     final stableValue = stream.readInt();
    final stable =stable_how.fromValue(stableValue);
    final data = stream.readOpaque();
    return WRITE3args (
      file: file,
      offset: offset,
      count: count,
      stable: stable,
      data: data,
    );
  }
}


// Typedef: writeverf3
typedef writeverf3 = Uint8List;


// Struct: WRITE3resok
class WRITE3resok {
  final wcc_data file_wcc;
  final count3 count;
  final stable_how committed;
  final writeverf3 verf;

  WRITE3resok({
    required this.file_wcc,
    required this.count,
    required this.committed,
    required this.verf,
  });

  void encode(XdrOutputStream stream) {
    file_wcc.encode(stream);
    stream.writeUnsignedInt(count);
    stream.writeInt(committed.value);
    stream.writeOpaque(verf);
  }

  static WRITE3resok decode(XdrInputStream stream) {
    final file_wcc = wcc_data.decode(stream);
    final count = stream.readUnsignedInt();
     final committedValue = stream.readInt();
    final committed =stable_how.fromValue(committedValue);
    final verf = stream.readOpaque();
    return WRITE3resok (
      file_wcc: file_wcc,
      count: count,
      committed: committed,
      verf: verf,
    );
  }
}


// Struct: WRITE3resfail
class WRITE3resfail {
  final wcc_data file_wcc;

  WRITE3resfail({
    required this.file_wcc,
  });

  void encode(XdrOutputStream stream) {
    file_wcc.encode(stream);
  }

  static WRITE3resfail decode(XdrInputStream stream) {
    final file_wcc = wcc_data.decode(stream);
    return WRITE3resfail (
      file_wcc: file_wcc,
    );
  }
}


// Union: WRITE3res
abstract class WRITE3res {
  final nfsstat3 discriminant;
  WRITE3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static WRITE3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = WRITE3resok.decode(stream);
        return WRITE3resNfs3Ok(value);
      default:
        final value = WRITE3resfail.decode(stream);
        return WRITE3resDefault(discriminant, value);
    }
  }
}

class WRITE3resNfs3Ok extends WRITE3res {
  final WRITE3resok value;
  WRITE3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class WRITE3resDefault extends WRITE3res {
  final WRITE3resfail value;
  WRITE3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: LOOKUP3args
class LOOKUP3args {
  final diropargs3 what;

  LOOKUP3args({
    required this.what,
  });

  void encode(XdrOutputStream stream) {
    what.encode(stream);
  }

  static LOOKUP3args decode(XdrInputStream stream) {
    final what = diropargs3.decode(stream);
    return LOOKUP3args (
      what: what,
    );
  }
}


// Struct: LOOKUP3resok
class LOOKUP3resok {
  final nfs_fh3 object;
  final post_op_attr obj_attributes;
  final post_op_attr dir_attributes;

  LOOKUP3resok({
    required this.object,
    required this.obj_attributes,
    required this.dir_attributes,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
    obj_attributes.encode(stream);
    dir_attributes.encode(stream);
  }

  static LOOKUP3resok decode(XdrInputStream stream) {
    final object = nfs_fh3.decode(stream);
    final obj_attributes = post_op_attr.decode(stream);
    final dir_attributes = post_op_attr.decode(stream);
    return LOOKUP3resok (
      object: object,
      obj_attributes: obj_attributes,
      dir_attributes: dir_attributes,
    );
  }
}


// Struct: LOOKUP3resfail
class LOOKUP3resfail {
  final post_op_attr dir_attributes;

  LOOKUP3resfail({
    required this.dir_attributes,
  });

  void encode(XdrOutputStream stream) {
    dir_attributes.encode(stream);
  }

  static LOOKUP3resfail decode(XdrInputStream stream) {
    final dir_attributes = post_op_attr.decode(stream);
    return LOOKUP3resfail (
      dir_attributes: dir_attributes,
    );
  }
}


// Union: LOOKUP3res
abstract class LOOKUP3res {
  final nfsstat3 discriminant;
  LOOKUP3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static LOOKUP3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = LOOKUP3resok.decode(stream);
        return LOOKUP3resNfs3Ok(value);
      default:
        final value = LOOKUP3resfail.decode(stream);
        return LOOKUP3resDefault(discriminant, value);
    }
  }
}

class LOOKUP3resNfs3Ok extends LOOKUP3res {
  final LOOKUP3resok value;
  LOOKUP3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class LOOKUP3resDefault extends LOOKUP3res {
  final LOOKUP3resfail value;
  LOOKUP3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: COMMIT3args
class COMMIT3args {
  final nfs_fh3 file;
  final offset3 offset;
  final count3 count;

  COMMIT3args({
    required this.file,
    required this.offset,
    required this.count,
  });

  void encode(XdrOutputStream stream) {
    file.encode(stream);
    stream.writeUnsignedHyper(offset);
    stream.writeUnsignedInt(count);
  }

  static COMMIT3args decode(XdrInputStream stream) {
    final file = nfs_fh3.decode(stream);
    final offset = stream.readUnsignedHyper();
    final count = stream.readUnsignedInt();
    return COMMIT3args (
      file: file,
      offset: offset,
      count: count,
    );
  }
}


// Struct: COMMIT3resok
class COMMIT3resok {
  final wcc_data file_wcc;
  final writeverf3 verf;

  COMMIT3resok({
    required this.file_wcc,
    required this.verf,
  });

  void encode(XdrOutputStream stream) {
    file_wcc.encode(stream);
    stream.writeOpaque(verf);
  }

  static COMMIT3resok decode(XdrInputStream stream) {
    final file_wcc = wcc_data.decode(stream);
    final verf = stream.readOpaque();
    return COMMIT3resok (
      file_wcc: file_wcc,
      verf: verf,
    );
  }
}


// Struct: COMMIT3resfail
class COMMIT3resfail {
  final wcc_data file_wcc;

  COMMIT3resfail({
    required this.file_wcc,
  });

  void encode(XdrOutputStream stream) {
    file_wcc.encode(stream);
  }

  static COMMIT3resfail decode(XdrInputStream stream) {
    final file_wcc = wcc_data.decode(stream);
    return COMMIT3resfail (
      file_wcc: file_wcc,
    );
  }
}


// Union: COMMIT3res
abstract class COMMIT3res {
  final nfsstat3 discriminant;
  COMMIT3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static COMMIT3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = COMMIT3resok.decode(stream);
        return COMMIT3resNfs3Ok(value);
      default:
        final value = COMMIT3resfail.decode(stream);
        return COMMIT3resDefault(discriminant, value);
    }
  }
}

class COMMIT3resNfs3Ok extends COMMIT3res {
  final COMMIT3resok value;
  COMMIT3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class COMMIT3resDefault extends COMMIT3res {
  final COMMIT3resfail value;
  COMMIT3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: ACCESS3args
class ACCESS3args {
  final nfs_fh3 object;
  final int access;

  ACCESS3args({
    required this.object,
    required this.access,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
    stream.writeUnsignedInt(access);
  }

  static ACCESS3args decode(XdrInputStream stream) {
    final object = nfs_fh3.decode(stream);
    final access = stream.readUnsignedInt();
    return ACCESS3args (
      object: object,
      access: access,
    );
  }
}


// Struct: ACCESS3resok
class ACCESS3resok {
  final post_op_attr obj_attributes;
  final int access;

  ACCESS3resok({
    required this.obj_attributes,
    required this.access,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
    stream.writeUnsignedInt(access);
  }

  static ACCESS3resok decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    final access = stream.readUnsignedInt();
    return ACCESS3resok (
      obj_attributes: obj_attributes,
      access: access,
    );
  }
}


// Struct: ACCESS3resfail
class ACCESS3resfail {
  final post_op_attr obj_attributes;

  ACCESS3resfail({
    required this.obj_attributes,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
  }

  static ACCESS3resfail decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    return ACCESS3resfail (
      obj_attributes: obj_attributes,
    );
  }
}


// Union: ACCESS3res
abstract class ACCESS3res {
  final nfsstat3 discriminant;
  ACCESS3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static ACCESS3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = ACCESS3resok.decode(stream);
        return ACCESS3resNfs3Ok(value);
      default:
        final value = ACCESS3resfail.decode(stream);
        return ACCESS3resDefault(discriminant, value);
    }
  }
}

class ACCESS3resNfs3Ok extends ACCESS3res {
  final ACCESS3resok value;
  ACCESS3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class ACCESS3resDefault extends ACCESS3res {
  final ACCESS3resfail value;
  ACCESS3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: GETATTR3args
class GETATTR3args {
  final nfs_fh3 object;

  GETATTR3args({
    required this.object,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
  }

  static GETATTR3args decode(XdrInputStream stream) {
    final object = nfs_fh3.decode(stream);
    return GETATTR3args (
      object: object,
    );
  }
}


// Struct: GETATTR3resok
class GETATTR3resok {
  final fattr3 obj_attributes;

  GETATTR3resok({
    required this.obj_attributes,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
  }

  static GETATTR3resok decode(XdrInputStream stream) {
    final obj_attributes = fattr3.decode(stream);
    return GETATTR3resok (
      obj_attributes: obj_attributes,
    );
  }
}


// Union: GETATTR3res
abstract class GETATTR3res {
  final nfsstat3 discriminant;
  GETATTR3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static GETATTR3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = GETATTR3resok.decode(stream);
        return GETATTR3resNfs3Ok(value);
      default:
        return GETATTR3resDefault(discriminant);
    }
  }
}

class GETATTR3resNfs3Ok extends GETATTR3res {
  final GETATTR3resok value;
  GETATTR3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class GETATTR3resDefault extends GETATTR3res {
  GETATTR3resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


//  Enum: time_how
enum time_how {
  dont_change(0),
  set_to_server_time(1),
  set_to_client_time(2),
  ;

  final int value;
  const time_how(this.value);

//    Create from XDR integer value
  factory time_how.fromValue(final int value) => switch (value) {
      0 => dont_change,
      1 => set_to_server_time,
      2 => set_to_client_time,
      _ => throw ArgumentError('Unknown time_how value: $value'),
    };

//    Get all possible values
  static List<time_how> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      0 => true,
      1 => true,
      2 => true,
      _ => false,
    };
}


// Union: set_mode3
abstract class set_mode3 {
  final bool discriminant;
  set_mode3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static set_mode3 decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = stream.readUnsignedInt();
        return set_mode3True(value);
      default:
        return set_mode3Default(discriminant);
    }
  }
}

class set_mode3True extends set_mode3 {
  final mode3 value;
  set_mode3True(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    stream.writeUnsignedInt(value);
  }
}

class set_mode3Default extends set_mode3 {
  set_mode3Default(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Union: set_uid3
abstract class set_uid3 {
  final bool discriminant;
  set_uid3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static set_uid3 decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = stream.readUnsignedInt();
        return set_uid3True(value);
      default:
        return set_uid3Default(discriminant);
    }
  }
}

class set_uid3True extends set_uid3 {
  final uid3 value;
  set_uid3True(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    stream.writeUnsignedInt(value);
  }
}

class set_uid3Default extends set_uid3 {
  set_uid3Default(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Union: set_gid3
abstract class set_gid3 {
  final bool discriminant;
  set_gid3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static set_gid3 decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = stream.readUnsignedInt();
        return set_gid3True(value);
      default:
        return set_gid3Default(discriminant);
    }
  }
}

class set_gid3True extends set_gid3 {
  final gid3 value;
  set_gid3True(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    stream.writeUnsignedInt(value);
  }
}

class set_gid3Default extends set_gid3 {
  set_gid3Default(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Union: set_size3
abstract class set_size3 {
  final bool discriminant;
  set_size3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static set_size3 decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = stream.readUnsignedHyper();
        return set_size3True(value);
      default:
        return set_size3Default(discriminant);
    }
  }
}

class set_size3True extends set_size3 {
  final size3 value;
  set_size3True(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    stream.writeUnsignedHyper(value);
  }
}

class set_size3Default extends set_size3 {
  set_size3Default(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Union: set_atime
abstract class set_atime {
  final time_how discriminant;
  set_atime(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static set_atime decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =time_how.fromValue(discriminantValue);
    switch (discriminant) {
      case time_how.set_to_client_time:
        final value = nfstime3.decode(stream);
        return set_atimeSetToClientTime(value);
      default:
        return set_atimeDefault(discriminant);
    }
  }
}

class set_atimeSetToClientTime extends set_atime {
  final nfstime3 value;
  set_atimeSetToClientTime(this.value) : super(time_how.set_to_client_time);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class set_atimeDefault extends set_atime {
  set_atimeDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Union: set_mtime
abstract class set_mtime {
  final time_how discriminant;
  set_mtime(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static set_mtime decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =time_how.fromValue(discriminantValue);
    switch (discriminant) {
      case time_how.set_to_client_time:
        final value = nfstime3.decode(stream);
        return set_mtimeSetToClientTime(value);
      default:
        return set_mtimeDefault(discriminant);
    }
  }
}

class set_mtimeSetToClientTime extends set_mtime {
  final nfstime3 value;
  set_mtimeSetToClientTime(this.value) : super(time_how.set_to_client_time);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class set_mtimeDefault extends set_mtime {
  set_mtimeDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: sattr3
class sattr3 {
  final set_mode3 mode;
  final set_uid3 uid;
  final set_gid3 gid;
  final set_size3 size;
  final set_atime atime;
  final set_mtime mtime;

  sattr3({
    required this.mode,
    required this.uid,
    required this.gid,
    required this.size,
    required this.atime,
    required this.mtime,
  });

  void encode(XdrOutputStream stream) {
    mode.encode(stream);
    uid.encode(stream);
    gid.encode(stream);
    size.encode(stream);
    atime.encode(stream);
    mtime.encode(stream);
  }

  static sattr3 decode(XdrInputStream stream) {
    final mode = set_mode3.decode(stream);
    final uid = set_uid3.decode(stream);
    final gid = set_gid3.decode(stream);
    final size = set_size3.decode(stream);
    final atime = set_atime.decode(stream);
    final mtime = set_mtime.decode(stream);
    return sattr3 (
      mode: mode,
      uid: uid,
      gid: gid,
      size: size,
      atime: atime,
      mtime: mtime,
    );
  }
}


//  Enum: createmode3
enum createmode3 {
  unchecked(0),
  guarded(1),
  exclusive(2),
  ;

  final int value;
  const createmode3(this.value);

//    Create from XDR integer value
  factory createmode3.fromValue(final int value) => switch (value) {
      0 => unchecked,
      1 => guarded,
      2 => exclusive,
      _ => throw ArgumentError('Unknown createmode3 value: $value'),
    };

//    Get all possible values
  static List<createmode3> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      0 => true,
      1 => true,
      2 => true,
      _ => false,
    };
}


// Typedef: createverf3
typedef createverf3 = Uint8List;


// Union: createhow3
abstract class createhow3 {
  final createmode3 discriminant;
  createhow3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static createhow3 decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =createmode3.fromValue(discriminantValue);
    switch (discriminant) {
      case createmode3.unchecked:
        final value = sattr3.decode(stream);
        return createhow3Unchecked(value);
      case createmode3.guarded:
        final value = sattr3.decode(stream);
        return createhow3Guarded(value);
      case createmode3.exclusive:
        final value = stream.readOpaque();
        return createhow3Exclusive(value);
      default:
        throw ArgumentError('Unknown discriminant: $discriminant');
    }
  }
}

class createhow3Unchecked extends createhow3 {
  final sattr3 value;
  createhow3Unchecked(this.value) : super(createmode3.unchecked);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class createhow3Guarded extends createhow3 {
  final sattr3 value;
  createhow3Guarded(this.value) : super(createmode3.guarded);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class createhow3Exclusive extends createhow3 {
  final createverf3 value;
  createhow3Exclusive(this.value) : super(createmode3.exclusive);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    stream.writeOpaque(value);
  }
}


// Struct: CREATE3args
class CREATE3args {
  final diropargs3 where;
  final createhow3 how;

  CREATE3args({
    required this.where,
    required this.how,
  });

  void encode(XdrOutputStream stream) {
    where.encode(stream);
    how.encode(stream);
  }

  static CREATE3args decode(XdrInputStream stream) {
    final where = diropargs3.decode(stream);
    final how = createhow3.decode(stream);
    return CREATE3args (
      where: where,
      how: how,
    );
  }
}


// Union: post_op_fh3
abstract class post_op_fh3 {
  final bool discriminant;
  post_op_fh3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static post_op_fh3 decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = nfs_fh3.decode(stream);
        return post_op_fh3True(value);
      case false:
        return post_op_fh3False();
      default:
        throw ArgumentError('Unknown discriminant: $discriminant');
    }
  }
}

class post_op_fh3True extends post_op_fh3 {
  final nfs_fh3 value;
  post_op_fh3True(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class post_op_fh3False extends post_op_fh3 {
  post_op_fh3False() : super(false);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: CREATE3resok
class CREATE3resok {
  final post_op_fh3 obj;
  final post_op_attr obj_attributes;
  final wcc_data dir_wcc;

  CREATE3resok({
    required this.obj,
    required this.obj_attributes,
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    obj.encode(stream);
    obj_attributes.encode(stream);
    dir_wcc.encode(stream);
  }

  static CREATE3resok decode(XdrInputStream stream) {
    final obj = post_op_fh3.decode(stream);
    final obj_attributes = post_op_attr.decode(stream);
    final dir_wcc = wcc_data.decode(stream);
    return CREATE3resok (
      obj: obj,
      obj_attributes: obj_attributes,
      dir_wcc: dir_wcc,
    );
  }
}


// Struct: CREATE3resfail
class CREATE3resfail {
  final wcc_data dir_wcc;

  CREATE3resfail({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static CREATE3resfail decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return CREATE3resfail (
      dir_wcc: dir_wcc,
    );
  }
}


// Union: CREATE3res
abstract class CREATE3res {
  final nfsstat3 discriminant;
  CREATE3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static CREATE3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = CREATE3resok.decode(stream);
        return CREATE3resNfs3Ok(value);
      default:
        final value = CREATE3resfail.decode(stream);
        return CREATE3resDefault(discriminant, value);
    }
  }
}

class CREATE3resNfs3Ok extends CREATE3res {
  final CREATE3resok value;
  CREATE3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class CREATE3resDefault extends CREATE3res {
  final CREATE3resfail value;
  CREATE3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: REMOVE3args
class REMOVE3args {
  final diropargs3 object;

  REMOVE3args({
    required this.object,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
  }

  static REMOVE3args decode(XdrInputStream stream) {
    final object = diropargs3.decode(stream);
    return REMOVE3args (
      object: object,
    );
  }
}


// Struct: REMOVE3resok
class REMOVE3resok {
  final wcc_data dir_wcc;

  REMOVE3resok({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static REMOVE3resok decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return REMOVE3resok (
      dir_wcc: dir_wcc,
    );
  }
}


// Struct: REMOVE3resfail
class REMOVE3resfail {
  final wcc_data dir_wcc;

  REMOVE3resfail({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static REMOVE3resfail decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return REMOVE3resfail (
      dir_wcc: dir_wcc,
    );
  }
}


// Union: REMOVE3res
abstract class REMOVE3res {
  final nfsstat3 discriminant;
  REMOVE3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static REMOVE3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = REMOVE3resok.decode(stream);
        return REMOVE3resNfs3Ok(value);
      default:
        final value = REMOVE3resfail.decode(stream);
        return REMOVE3resDefault(discriminant, value);
    }
  }
}

class REMOVE3resNfs3Ok extends REMOVE3res {
  final REMOVE3resok value;
  REMOVE3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class REMOVE3resDefault extends REMOVE3res {
  final REMOVE3resfail value;
  REMOVE3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: READ3args
class READ3args {
  final nfs_fh3 file;
  final offset3 offset;
  final count3 count;

  READ3args({
    required this.file,
    required this.offset,
    required this.count,
  });

  void encode(XdrOutputStream stream) {
    file.encode(stream);
    stream.writeUnsignedHyper(offset);
    stream.writeUnsignedInt(count);
  }

  static READ3args decode(XdrInputStream stream) {
    final file = nfs_fh3.decode(stream);
    final offset = stream.readUnsignedHyper();
    final count = stream.readUnsignedInt();
    return READ3args (
      file: file,
      offset: offset,
      count: count,
    );
  }
}


// Struct: READ3resok
class READ3resok {
  final post_op_attr file_attributes;
  final count3 count;
  final bool eof;
  final Uint8List data;

  READ3resok({
    required this.file_attributes,
    required this.count,
    required this.eof,
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    file_attributes.encode(stream);
    stream.writeUnsignedInt(count);
    stream.writeBoolean(eof);
    stream.writeOpaque(data);
  }

  static READ3resok decode(XdrInputStream stream) {
    final file_attributes = post_op_attr.decode(stream);
    final count = stream.readUnsignedInt();
    final eof = stream.readBoolean();
    final data = stream.readOpaque();
    return READ3resok (
      file_attributes: file_attributes,
      count: count,
      eof: eof,
      data: data,
    );
  }
}


// Struct: READ3resfail
class READ3resfail {
  final post_op_attr file_attributes;

  READ3resfail({
    required this.file_attributes,
  });

  void encode(XdrOutputStream stream) {
    file_attributes.encode(stream);
  }

  static READ3resfail decode(XdrInputStream stream) {
    final file_attributes = post_op_attr.decode(stream);
    return READ3resfail (
      file_attributes: file_attributes,
    );
  }
}


// Union: READ3res
abstract class READ3res {
  final nfsstat3 discriminant;
  READ3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READ3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READ3resok.decode(stream);
        return READ3resNfs3Ok(value);
      default:
        final value = READ3resfail.decode(stream);
        return READ3resDefault(discriminant, value);
    }
  }
}

class READ3resNfs3Ok extends READ3res {
  final READ3resok value;
  READ3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READ3resDefault extends READ3res {
  final READ3resfail value;
  READ3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: FSINFO3args
class FSINFO3args {
  final nfs_fh3 fsroot;

  FSINFO3args({
    required this.fsroot,
  });

  void encode(XdrOutputStream stream) {
    fsroot.encode(stream);
  }

  static FSINFO3args decode(XdrInputStream stream) {
    final fsroot = nfs_fh3.decode(stream);
    return FSINFO3args (
      fsroot: fsroot,
    );
  }
}


// Struct: FSINFO3resok
class FSINFO3resok {
  final post_op_attr obj_attributes;
  final int rtmax;
  final int rtpref;
  final int rtmult;
  final int wtmax;
  final int wtpref;
  final int wtmult;
  final int dtpref;
  final size3 maxfilesize;
  final nfstime3 time_delta;
  final int properties;

  FSINFO3resok({
    required this.obj_attributes,
    required this.rtmax,
    required this.rtpref,
    required this.rtmult,
    required this.wtmax,
    required this.wtpref,
    required this.wtmult,
    required this.dtpref,
    required this.maxfilesize,
    required this.time_delta,
    required this.properties,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
    stream.writeUnsignedInt(rtmax);
    stream.writeUnsignedInt(rtpref);
    stream.writeUnsignedInt(rtmult);
    stream.writeUnsignedInt(wtmax);
    stream.writeUnsignedInt(wtpref);
    stream.writeUnsignedInt(wtmult);
    stream.writeUnsignedInt(dtpref);
    stream.writeUnsignedHyper(maxfilesize);
    time_delta.encode(stream);
    stream.writeUnsignedInt(properties);
  }

  static FSINFO3resok decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    final rtmax = stream.readUnsignedInt();
    final rtpref = stream.readUnsignedInt();
    final rtmult = stream.readUnsignedInt();
    final wtmax = stream.readUnsignedInt();
    final wtpref = stream.readUnsignedInt();
    final wtmult = stream.readUnsignedInt();
    final dtpref = stream.readUnsignedInt();
    final maxfilesize = stream.readUnsignedHyper();
    final time_delta = nfstime3.decode(stream);
    final properties = stream.readUnsignedInt();
    return FSINFO3resok (
      obj_attributes: obj_attributes,
      rtmax: rtmax,
      rtpref: rtpref,
      rtmult: rtmult,
      wtmax: wtmax,
      wtpref: wtpref,
      wtmult: wtmult,
      dtpref: dtpref,
      maxfilesize: maxfilesize,
      time_delta: time_delta,
      properties: properties,
    );
  }
}


// Struct: FSINFO3resfail
class FSINFO3resfail {
  final post_op_attr obj_attributes;

  FSINFO3resfail({
    required this.obj_attributes,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
  }

  static FSINFO3resfail decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    return FSINFO3resfail (
      obj_attributes: obj_attributes,
    );
  }
}


// Union: FSINFO3res
abstract class FSINFO3res {
  final nfsstat3 discriminant;
  FSINFO3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static FSINFO3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = FSINFO3resok.decode(stream);
        return FSINFO3resNfs3Ok(value);
      default:
        final value = FSINFO3resfail.decode(stream);
        return FSINFO3resDefault(discriminant, value);
    }
  }
}

class FSINFO3resNfs3Ok extends FSINFO3res {
  final FSINFO3resok value;
  FSINFO3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class FSINFO3resDefault extends FSINFO3res {
  final FSINFO3resfail value;
  FSINFO3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: FSSTAT3args
class FSSTAT3args {
  final nfs_fh3 fsroot;

  FSSTAT3args({
    required this.fsroot,
  });

  void encode(XdrOutputStream stream) {
    fsroot.encode(stream);
  }

  static FSSTAT3args decode(XdrInputStream stream) {
    final fsroot = nfs_fh3.decode(stream);
    return FSSTAT3args (
      fsroot: fsroot,
    );
  }
}


// Struct: FSSTAT3resok
class FSSTAT3resok {
  final post_op_attr obj_attributes;
  final size3 tbytes;
  final size3 fbytes;
  final size3 abytes;
  final size3 tfiles;
  final size3 ffiles;
  final size3 afiles;
  final int invarsec;

  FSSTAT3resok({
    required this.obj_attributes,
    required this.tbytes,
    required this.fbytes,
    required this.abytes,
    required this.tfiles,
    required this.ffiles,
    required this.afiles,
    required this.invarsec,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
    stream.writeUnsignedHyper(tbytes);
    stream.writeUnsignedHyper(fbytes);
    stream.writeUnsignedHyper(abytes);
    stream.writeUnsignedHyper(tfiles);
    stream.writeUnsignedHyper(ffiles);
    stream.writeUnsignedHyper(afiles);
    stream.writeUnsignedInt(invarsec);
  }

  static FSSTAT3resok decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    final tbytes = stream.readUnsignedHyper();
    final fbytes = stream.readUnsignedHyper();
    final abytes = stream.readUnsignedHyper();
    final tfiles = stream.readUnsignedHyper();
    final ffiles = stream.readUnsignedHyper();
    final afiles = stream.readUnsignedHyper();
    final invarsec = stream.readUnsignedInt();
    return FSSTAT3resok (
      obj_attributes: obj_attributes,
      tbytes: tbytes,
      fbytes: fbytes,
      abytes: abytes,
      tfiles: tfiles,
      ffiles: ffiles,
      afiles: afiles,
      invarsec: invarsec,
    );
  }
}


// Struct: FSSTAT3resfail
class FSSTAT3resfail {
  final post_op_attr obj_attributes;

  FSSTAT3resfail({
    required this.obj_attributes,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
  }

  static FSSTAT3resfail decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    return FSSTAT3resfail (
      obj_attributes: obj_attributes,
    );
  }
}


// Union: FSSTAT3res
abstract class FSSTAT3res {
  final nfsstat3 discriminant;
  FSSTAT3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static FSSTAT3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = FSSTAT3resok.decode(stream);
        return FSSTAT3resNfs3Ok(value);
      default:
        final value = FSSTAT3resfail.decode(stream);
        return FSSTAT3resDefault(discriminant, value);
    }
  }
}

class FSSTAT3resNfs3Ok extends FSSTAT3res {
  final FSSTAT3resok value;
  FSSTAT3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class FSSTAT3resDefault extends FSSTAT3res {
  final FSSTAT3resfail value;
  FSSTAT3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: PATHCONF3args
class PATHCONF3args {
  final nfs_fh3 object;

  PATHCONF3args({
    required this.object,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
  }

  static PATHCONF3args decode(XdrInputStream stream) {
    final object = nfs_fh3.decode(stream);
    return PATHCONF3args (
      object: object,
    );
  }
}


// Struct: PATHCONF3resok
class PATHCONF3resok {
  final post_op_attr obj_attributes;
  final int linkmax;
  final int name_max;
  final bool no_trunc;
  final bool chown_restricted;
  final bool case_insensitive;
  final bool case_preserving;

  PATHCONF3resok({
    required this.obj_attributes,
    required this.linkmax,
    required this.name_max,
    required this.no_trunc,
    required this.chown_restricted,
    required this.case_insensitive,
    required this.case_preserving,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
    stream.writeUnsignedInt(linkmax);
    stream.writeUnsignedInt(name_max);
    stream.writeBoolean(no_trunc);
    stream.writeBoolean(chown_restricted);
    stream.writeBoolean(case_insensitive);
    stream.writeBoolean(case_preserving);
  }

  static PATHCONF3resok decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    final linkmax = stream.readUnsignedInt();
    final name_max = stream.readUnsignedInt();
    final no_trunc = stream.readBoolean();
    final chown_restricted = stream.readBoolean();
    final case_insensitive = stream.readBoolean();
    final case_preserving = stream.readBoolean();
    return PATHCONF3resok (
      obj_attributes: obj_attributes,
      linkmax: linkmax,
      name_max: name_max,
      no_trunc: no_trunc,
      chown_restricted: chown_restricted,
      case_insensitive: case_insensitive,
      case_preserving: case_preserving,
    );
  }
}


// Struct: PATHCONF3resfail
class PATHCONF3resfail {
  final post_op_attr obj_attributes;

  PATHCONF3resfail({
    required this.obj_attributes,
  });

  void encode(XdrOutputStream stream) {
    obj_attributes.encode(stream);
  }

  static PATHCONF3resfail decode(XdrInputStream stream) {
    final obj_attributes = post_op_attr.decode(stream);
    return PATHCONF3resfail (
      obj_attributes: obj_attributes,
    );
  }
}


// Union: PATHCONF3res
abstract class PATHCONF3res {
  final nfsstat3 discriminant;
  PATHCONF3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static PATHCONF3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = PATHCONF3resok.decode(stream);
        return PATHCONF3resNfs3Ok(value);
      default:
        final value = PATHCONF3resfail.decode(stream);
        return PATHCONF3resDefault(discriminant, value);
    }
  }
}

class PATHCONF3resNfs3Ok extends PATHCONF3res {
  final PATHCONF3resok value;
  PATHCONF3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class PATHCONF3resDefault extends PATHCONF3res {
  final PATHCONF3resfail value;
  PATHCONF3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Typedef: nfspath3
typedef nfspath3 = String;


// Struct: symlinkdata3
class symlinkdata3 {
  final sattr3 symlink_attributes;
  final nfspath3 symlink_data;

  symlinkdata3({
    required this.symlink_attributes,
    required this.symlink_data,
  });

  void encode(XdrOutputStream stream) {
    symlink_attributes.encode(stream);
    stream.writeString(symlink_data);
  }

  static symlinkdata3 decode(XdrInputStream stream) {
    final symlink_attributes = sattr3.decode(stream);
    final symlink_data = stream.readString();
    return symlinkdata3 (
      symlink_attributes: symlink_attributes,
      symlink_data: symlink_data,
    );
  }
}


// Struct: SYMLINK3args
class SYMLINK3args {
  final diropargs3 where;
  final symlinkdata3 symlink;

  SYMLINK3args({
    required this.where,
    required this.symlink,
  });

  void encode(XdrOutputStream stream) {
    where.encode(stream);
    symlink.encode(stream);
  }

  static SYMLINK3args decode(XdrInputStream stream) {
    final where = diropargs3.decode(stream);
    final symlink = symlinkdata3.decode(stream);
    return SYMLINK3args (
      where: where,
      symlink: symlink,
    );
  }
}


// Struct: SYMLINK3resok
class SYMLINK3resok {
  final post_op_fh3 obj;
  final post_op_attr obj_attributes;
  final wcc_data dir_wcc;

  SYMLINK3resok({
    required this.obj,
    required this.obj_attributes,
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    obj.encode(stream);
    obj_attributes.encode(stream);
    dir_wcc.encode(stream);
  }

  static SYMLINK3resok decode(XdrInputStream stream) {
    final obj = post_op_fh3.decode(stream);
    final obj_attributes = post_op_attr.decode(stream);
    final dir_wcc = wcc_data.decode(stream);
    return SYMLINK3resok (
      obj: obj,
      obj_attributes: obj_attributes,
      dir_wcc: dir_wcc,
    );
  }
}


// Struct: SYMLINK3resfail
class SYMLINK3resfail {
  final wcc_data dir_wcc;

  SYMLINK3resfail({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static SYMLINK3resfail decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return SYMLINK3resfail (
      dir_wcc: dir_wcc,
    );
  }
}


// Union: SYMLINK3res
abstract class SYMLINK3res {
  final nfsstat3 discriminant;
  SYMLINK3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static SYMLINK3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = SYMLINK3resok.decode(stream);
        return SYMLINK3resNfs3Ok(value);
      default:
        final value = SYMLINK3resfail.decode(stream);
        return SYMLINK3resDefault(discriminant, value);
    }
  }
}

class SYMLINK3resNfs3Ok extends SYMLINK3res {
  final SYMLINK3resok value;
  SYMLINK3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class SYMLINK3resDefault extends SYMLINK3res {
  final SYMLINK3resfail value;
  SYMLINK3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: READLINK3args
class READLINK3args {
  final nfs_fh3 symlink;

  READLINK3args({
    required this.symlink,
  });

  void encode(XdrOutputStream stream) {
    symlink.encode(stream);
  }

  static READLINK3args decode(XdrInputStream stream) {
    final symlink = nfs_fh3.decode(stream);
    return READLINK3args (
      symlink: symlink,
    );
  }
}


// Struct: READLINK3resok
class READLINK3resok {
  final post_op_attr symlink_attributes;
  final nfspath3 data;

  READLINK3resok({
    required this.symlink_attributes,
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    symlink_attributes.encode(stream);
    stream.writeString(data);
  }

  static READLINK3resok decode(XdrInputStream stream) {
    final symlink_attributes = post_op_attr.decode(stream);
    final data = stream.readString();
    return READLINK3resok (
      symlink_attributes: symlink_attributes,
      data: data,
    );
  }
}


// Struct: READLINK3resfail
class READLINK3resfail {
  final post_op_attr symlink_attributes;

  READLINK3resfail({
    required this.symlink_attributes,
  });

  void encode(XdrOutputStream stream) {
    symlink_attributes.encode(stream);
  }

  static READLINK3resfail decode(XdrInputStream stream) {
    final symlink_attributes = post_op_attr.decode(stream);
    return READLINK3resfail (
      symlink_attributes: symlink_attributes,
    );
  }
}


// Union: READLINK3res
abstract class READLINK3res {
  final nfsstat3 discriminant;
  READLINK3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READLINK3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READLINK3resok.decode(stream);
        return READLINK3resNfs3Ok(value);
      default:
        final value = READLINK3resfail.decode(stream);
        return READLINK3resDefault(discriminant, value);
    }
  }
}

class READLINK3resNfs3Ok extends READLINK3res {
  final READLINK3resok value;
  READLINK3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READLINK3resDefault extends READLINK3res {
  final READLINK3resfail value;
  READLINK3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: devicedata3
class devicedata3 {
  final sattr3 dev_attributes;
  final specdata3 spec;

  devicedata3({
    required this.dev_attributes,
    required this.spec,
  });

  void encode(XdrOutputStream stream) {
    dev_attributes.encode(stream);
    spec.encode(stream);
  }

  static devicedata3 decode(XdrInputStream stream) {
    final dev_attributes = sattr3.decode(stream);
    final spec = specdata3.decode(stream);
    return devicedata3 (
      dev_attributes: dev_attributes,
      spec: spec,
    );
  }
}


// Union: mknoddata3
abstract class mknoddata3 {
  final ftype3 discriminant;
  mknoddata3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static mknoddata3 decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =ftype3.fromValue(discriminantValue);
    switch (discriminant) {
      case ftype3.nf3chr:
        final value = devicedata3.decode(stream);
        return mknoddata3Nf3chr(value);
      case ftype3.nf3blk:
        final value = devicedata3.decode(stream);
        return mknoddata3Nf3blk(value);
      case ftype3.nf3sock:
        final value = sattr3.decode(stream);
        return mknoddata3Nf3sock(value);
      case ftype3.nf3fifo:
        final value = sattr3.decode(stream);
        return mknoddata3Nf3fifo(value);
      default:
        return mknoddata3Default(discriminant);
    }
  }
}

class mknoddata3Nf3chr extends mknoddata3 {
  final devicedata3 value;
  mknoddata3Nf3chr(this.value) : super(ftype3.nf3chr);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class mknoddata3Nf3blk extends mknoddata3 {
  final devicedata3 value;
  mknoddata3Nf3blk(this.value) : super(ftype3.nf3blk);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class mknoddata3Nf3sock extends mknoddata3 {
  final sattr3 value;
  mknoddata3Nf3sock(this.value) : super(ftype3.nf3sock);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class mknoddata3Nf3fifo extends mknoddata3 {
  final sattr3 value;
  mknoddata3Nf3fifo(this.value) : super(ftype3.nf3fifo);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class mknoddata3Default extends mknoddata3 {
  mknoddata3Default(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: MKNOD3args
class MKNOD3args {
  final diropargs3 where;
  final mknoddata3 what;

  MKNOD3args({
    required this.where,
    required this.what,
  });

  void encode(XdrOutputStream stream) {
    where.encode(stream);
    what.encode(stream);
  }

  static MKNOD3args decode(XdrInputStream stream) {
    final where = diropargs3.decode(stream);
    final what = mknoddata3.decode(stream);
    return MKNOD3args (
      where: where,
      what: what,
    );
  }
}


// Struct: MKNOD3resok
class MKNOD3resok {
  final post_op_fh3 obj;
  final post_op_attr obj_attributes;
  final wcc_data dir_wcc;

  MKNOD3resok({
    required this.obj,
    required this.obj_attributes,
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    obj.encode(stream);
    obj_attributes.encode(stream);
    dir_wcc.encode(stream);
  }

  static MKNOD3resok decode(XdrInputStream stream) {
    final obj = post_op_fh3.decode(stream);
    final obj_attributes = post_op_attr.decode(stream);
    final dir_wcc = wcc_data.decode(stream);
    return MKNOD3resok (
      obj: obj,
      obj_attributes: obj_attributes,
      dir_wcc: dir_wcc,
    );
  }
}


// Struct: MKNOD3resfail
class MKNOD3resfail {
  final wcc_data dir_wcc;

  MKNOD3resfail({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static MKNOD3resfail decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return MKNOD3resfail (
      dir_wcc: dir_wcc,
    );
  }
}


// Union: MKNOD3res
abstract class MKNOD3res {
  final nfsstat3 discriminant;
  MKNOD3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static MKNOD3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = MKNOD3resok.decode(stream);
        return MKNOD3resNfs3Ok(value);
      default:
        final value = MKNOD3resfail.decode(stream);
        return MKNOD3resDefault(discriminant, value);
    }
  }
}

class MKNOD3resNfs3Ok extends MKNOD3res {
  final MKNOD3resok value;
  MKNOD3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class MKNOD3resDefault extends MKNOD3res {
  final MKNOD3resfail value;
  MKNOD3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: MKDIR3args
class MKDIR3args {
  final diropargs3 where;
  final sattr3 attributes;

  MKDIR3args({
    required this.where,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    where.encode(stream);
    attributes.encode(stream);
  }

  static MKDIR3args decode(XdrInputStream stream) {
    final where = diropargs3.decode(stream);
    final attributes = sattr3.decode(stream);
    return MKDIR3args (
      where: where,
      attributes: attributes,
    );
  }
}


// Struct: MKDIR3resok
class MKDIR3resok {
  final post_op_fh3 obj;
  final post_op_attr obj_attributes;
  final wcc_data dir_wcc;

  MKDIR3resok({
    required this.obj,
    required this.obj_attributes,
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    obj.encode(stream);
    obj_attributes.encode(stream);
    dir_wcc.encode(stream);
  }

  static MKDIR3resok decode(XdrInputStream stream) {
    final obj = post_op_fh3.decode(stream);
    final obj_attributes = post_op_attr.decode(stream);
    final dir_wcc = wcc_data.decode(stream);
    return MKDIR3resok (
      obj: obj,
      obj_attributes: obj_attributes,
      dir_wcc: dir_wcc,
    );
  }
}


// Struct: MKDIR3resfail
class MKDIR3resfail {
  final wcc_data dir_wcc;

  MKDIR3resfail({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static MKDIR3resfail decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return MKDIR3resfail (
      dir_wcc: dir_wcc,
    );
  }
}


// Union: MKDIR3res
abstract class MKDIR3res {
  final nfsstat3 discriminant;
  MKDIR3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static MKDIR3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = MKDIR3resok.decode(stream);
        return MKDIR3resNfs3Ok(value);
      default:
        final value = MKDIR3resfail.decode(stream);
        return MKDIR3resDefault(discriminant, value);
    }
  }
}

class MKDIR3resNfs3Ok extends MKDIR3res {
  final MKDIR3resok value;
  MKDIR3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class MKDIR3resDefault extends MKDIR3res {
  final MKDIR3resfail value;
  MKDIR3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: RMDIR3args
class RMDIR3args {
  final diropargs3 object;

  RMDIR3args({
    required this.object,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
  }

  static RMDIR3args decode(XdrInputStream stream) {
    final object = diropargs3.decode(stream);
    return RMDIR3args (
      object: object,
    );
  }
}


// Struct: RMDIR3resok
class RMDIR3resok {
  final wcc_data dir_wcc;

  RMDIR3resok({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static RMDIR3resok decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return RMDIR3resok (
      dir_wcc: dir_wcc,
    );
  }
}


// Struct: RMDIR3resfail
class RMDIR3resfail {
  final wcc_data dir_wcc;

  RMDIR3resfail({
    required this.dir_wcc,
  });

  void encode(XdrOutputStream stream) {
    dir_wcc.encode(stream);
  }

  static RMDIR3resfail decode(XdrInputStream stream) {
    final dir_wcc = wcc_data.decode(stream);
    return RMDIR3resfail (
      dir_wcc: dir_wcc,
    );
  }
}


// Union: RMDIR3res
abstract class RMDIR3res {
  final nfsstat3 discriminant;
  RMDIR3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static RMDIR3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = RMDIR3resok.decode(stream);
        return RMDIR3resNfs3Ok(value);
      default:
        final value = RMDIR3resfail.decode(stream);
        return RMDIR3resDefault(discriminant, value);
    }
  }
}

class RMDIR3resNfs3Ok extends RMDIR3res {
  final RMDIR3resok value;
  RMDIR3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class RMDIR3resDefault extends RMDIR3res {
  final RMDIR3resfail value;
  RMDIR3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: RENAME3args
class RENAME3args {
  final diropargs3 from;
  final diropargs3 to;

  RENAME3args({
    required this.from,
    required this.to,
  });

  void encode(XdrOutputStream stream) {
    from.encode(stream);
    to.encode(stream);
  }

  static RENAME3args decode(XdrInputStream stream) {
    final from = diropargs3.decode(stream);
    final to = diropargs3.decode(stream);
    return RENAME3args (
      from: from,
      to: to,
    );
  }
}


// Struct: RENAME3resok
class RENAME3resok {
  final wcc_data fromdir_wcc;
  final wcc_data todir_wcc;

  RENAME3resok({
    required this.fromdir_wcc,
    required this.todir_wcc,
  });

  void encode(XdrOutputStream stream) {
    fromdir_wcc.encode(stream);
    todir_wcc.encode(stream);
  }

  static RENAME3resok decode(XdrInputStream stream) {
    final fromdir_wcc = wcc_data.decode(stream);
    final todir_wcc = wcc_data.decode(stream);
    return RENAME3resok (
      fromdir_wcc: fromdir_wcc,
      todir_wcc: todir_wcc,
    );
  }
}


// Struct: RENAME3resfail
class RENAME3resfail {
  final wcc_data fromdir_wcc;
  final wcc_data todir_wcc;

  RENAME3resfail({
    required this.fromdir_wcc,
    required this.todir_wcc,
  });

  void encode(XdrOutputStream stream) {
    fromdir_wcc.encode(stream);
    todir_wcc.encode(stream);
  }

  static RENAME3resfail decode(XdrInputStream stream) {
    final fromdir_wcc = wcc_data.decode(stream);
    final todir_wcc = wcc_data.decode(stream);
    return RENAME3resfail (
      fromdir_wcc: fromdir_wcc,
      todir_wcc: todir_wcc,
    );
  }
}


// Union: RENAME3res
abstract class RENAME3res {
  final nfsstat3 discriminant;
  RENAME3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static RENAME3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = RENAME3resok.decode(stream);
        return RENAME3resNfs3Ok(value);
      default:
        final value = RENAME3resfail.decode(stream);
        return RENAME3resDefault(discriminant, value);
    }
  }
}

class RENAME3resNfs3Ok extends RENAME3res {
  final RENAME3resok value;
  RENAME3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class RENAME3resDefault extends RENAME3res {
  final RENAME3resfail value;
  RENAME3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: READDIRPLUS3args
class READDIRPLUS3args {
  final nfs_fh3 dir;
  final cookie3 cookie;
  final cookieverf3 cookieverf;
  final count3 dircount;
  final count3 maxcount;

  READDIRPLUS3args({
    required this.dir,
    required this.cookie,
    required this.cookieverf,
    required this.dircount,
    required this.maxcount,
  });

  void encode(XdrOutputStream stream) {
    dir.encode(stream);
    stream.writeUnsignedHyper(cookie);
    stream.writeOpaque(cookieverf);
    stream.writeUnsignedInt(dircount);
    stream.writeUnsignedInt(maxcount);
  }

  static READDIRPLUS3args decode(XdrInputStream stream) {
    final dir = nfs_fh3.decode(stream);
    final cookie = stream.readUnsignedHyper();
    final cookieverf = stream.readOpaque();
    final dircount = stream.readUnsignedInt();
    final maxcount = stream.readUnsignedInt();
    return READDIRPLUS3args (
      dir: dir,
      cookie: cookie,
      cookieverf: cookieverf,
      dircount: dircount,
      maxcount: maxcount,
    );
  }
}


// Struct: entryplus3
class entryplus3 {
  final fileid3 fileid;
  final filename3 name;
  final cookie3 cookie;
  final post_op_attr name_attributes;
  final post_op_fh3 name_handle;
  final entryplus3? nextentry;

  entryplus3({
    required this.fileid,
    required this.name,
    required this.cookie,
    required this.name_attributes,
    required this.name_handle,
    this.nextentry,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedHyper(fileid);
    stream.writeString(name);
    stream.writeUnsignedHyper(cookie);
    name_attributes.encode(stream);
    name_handle.encode(stream);
    if (nextentry != null) {
      stream.writeInt(1); // Present
      nextentry!.encode(stream);
    } else {
      stream.writeInt(0); // Not present
    }
  }

  static entryplus3 decode(XdrInputStream stream) {
    final fileid = stream.readUnsignedHyper();
    final name = stream.readString();
    final cookie = stream.readUnsignedHyper();
    final name_attributes = post_op_attr.decode(stream);
    final name_handle = post_op_fh3.decode(stream);
    final nextentryPresent = stream.readInt();
    entryplus3? nextentry;
    if (nextentryPresent != 0) {
      nextentry = entryplus3.decode(stream);
    }
    return entryplus3 (
      fileid: fileid,
      name: name,
      cookie: cookie,
      name_attributes: name_attributes,
      name_handle: name_handle,
      nextentry: nextentry,
    );
  }
}


// Struct: dirlistplus3
class dirlistplus3 {
  final entryplus3? entries;
  final bool eof;

  dirlistplus3({
    this.entries,
    required this.eof,
  });

  void encode(XdrOutputStream stream) {
    if (entries != null) {
      stream.writeInt(1); // Present
      entries!.encode(stream);
    } else {
      stream.writeInt(0); // Not present
    }
    stream.writeBoolean(eof);
  }

  static dirlistplus3 decode(XdrInputStream stream) {
    final entriesPresent = stream.readInt();
    entryplus3? entries;
    if (entriesPresent != 0) {
      entries = entryplus3.decode(stream);
    }
    final eof = stream.readBoolean();
    return dirlistplus3 (
      entries: entries,
      eof: eof,
    );
  }
}


// Struct: READDIRPLUS3resok
class READDIRPLUS3resok {
  final post_op_attr dir_attributes;
  final cookieverf3 cookieverf;
  final dirlistplus3 reply;

  READDIRPLUS3resok({
    required this.dir_attributes,
    required this.cookieverf,
    required this.reply,
  });

  void encode(XdrOutputStream stream) {
    dir_attributes.encode(stream);
    stream.writeOpaque(cookieverf);
    reply.encode(stream);
  }

  static READDIRPLUS3resok decode(XdrInputStream stream) {
    final dir_attributes = post_op_attr.decode(stream);
    final cookieverf = stream.readOpaque();
    final reply = dirlistplus3.decode(stream);
    return READDIRPLUS3resok (
      dir_attributes: dir_attributes,
      cookieverf: cookieverf,
      reply: reply,
    );
  }
}


// Struct: READDIRPLUS3resfail
class READDIRPLUS3resfail {
  final post_op_attr dir_attributes;

  READDIRPLUS3resfail({
    required this.dir_attributes,
  });

  void encode(XdrOutputStream stream) {
    dir_attributes.encode(stream);
  }

  static READDIRPLUS3resfail decode(XdrInputStream stream) {
    final dir_attributes = post_op_attr.decode(stream);
    return READDIRPLUS3resfail (
      dir_attributes: dir_attributes,
    );
  }
}


// Union: READDIRPLUS3res
abstract class READDIRPLUS3res {
  final nfsstat3 discriminant;
  READDIRPLUS3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READDIRPLUS3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READDIRPLUS3resok.decode(stream);
        return READDIRPLUS3resNfs3Ok(value);
      default:
        final value = READDIRPLUS3resfail.decode(stream);
        return READDIRPLUS3resDefault(discriminant, value);
    }
  }
}

class READDIRPLUS3resNfs3Ok extends READDIRPLUS3res {
  final READDIRPLUS3resok value;
  READDIRPLUS3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READDIRPLUS3resDefault extends READDIRPLUS3res {
  final READDIRPLUS3resfail value;
  READDIRPLUS3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: READDIR3args
class READDIR3args {
  final nfs_fh3 dir;
  final cookie3 cookie;
  final cookieverf3 cookieverf;
  final count3 count;

  READDIR3args({
    required this.dir,
    required this.cookie,
    required this.cookieverf,
    required this.count,
  });

  void encode(XdrOutputStream stream) {
    dir.encode(stream);
    stream.writeUnsignedHyper(cookie);
    stream.writeOpaque(cookieverf);
    stream.writeUnsignedInt(count);
  }

  static READDIR3args decode(XdrInputStream stream) {
    final dir = nfs_fh3.decode(stream);
    final cookie = stream.readUnsignedHyper();
    final cookieverf = stream.readOpaque();
    final count = stream.readUnsignedInt();
    return READDIR3args (
      dir: dir,
      cookie: cookie,
      cookieverf: cookieverf,
      count: count,
    );
  }
}


// Struct: entry3
class entry3 {
  final fileid3 fileid;
  final filename3 name;
  final cookie3 cookie;
  final entry3? nextentry;

  entry3({
    required this.fileid,
    required this.name,
    required this.cookie,
    this.nextentry,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedHyper(fileid);
    stream.writeString(name);
    stream.writeUnsignedHyper(cookie);
    if (nextentry != null) {
      stream.writeInt(1); // Present
      nextentry!.encode(stream);
    } else {
      stream.writeInt(0); // Not present
    }
  }

  static entry3 decode(XdrInputStream stream) {
    final fileid = stream.readUnsignedHyper();
    final name = stream.readString();
    final cookie = stream.readUnsignedHyper();
    final nextentryPresent = stream.readInt();
    entry3? nextentry;
    if (nextentryPresent != 0) {
      nextentry = entry3.decode(stream);
    }
    return entry3 (
      fileid: fileid,
      name: name,
      cookie: cookie,
      nextentry: nextentry,
    );
  }
}


// Struct: dirlist3
class dirlist3 {
  final entry3? entries;
  final bool eof;

  dirlist3({
    this.entries,
    required this.eof,
  });

  void encode(XdrOutputStream stream) {
    if (entries != null) {
      stream.writeInt(1); // Present
      entries!.encode(stream);
    } else {
      stream.writeInt(0); // Not present
    }
    stream.writeBoolean(eof);
  }

  static dirlist3 decode(XdrInputStream stream) {
    final entriesPresent = stream.readInt();
    entry3? entries;
    if (entriesPresent != 0) {
      entries = entry3.decode(stream);
    }
    final eof = stream.readBoolean();
    return dirlist3 (
      entries: entries,
      eof: eof,
    );
  }
}


// Struct: READDIR3resok
class READDIR3resok {
  final post_op_attr dir_attributes;
  final cookieverf3 cookieverf;
  final dirlist3 reply;

  READDIR3resok({
    required this.dir_attributes,
    required this.cookieverf,
    required this.reply,
  });

  void encode(XdrOutputStream stream) {
    dir_attributes.encode(stream);
    stream.writeOpaque(cookieverf);
    reply.encode(stream);
  }

  static READDIR3resok decode(XdrInputStream stream) {
    final dir_attributes = post_op_attr.decode(stream);
    final cookieverf = stream.readOpaque();
    final reply = dirlist3.decode(stream);
    return READDIR3resok (
      dir_attributes: dir_attributes,
      cookieverf: cookieverf,
      reply: reply,
    );
  }
}


// Struct: READDIR3resfail
class READDIR3resfail {
  final post_op_attr dir_attributes;

  READDIR3resfail({
    required this.dir_attributes,
  });

  void encode(XdrOutputStream stream) {
    dir_attributes.encode(stream);
  }

  static READDIR3resfail decode(XdrInputStream stream) {
    final dir_attributes = post_op_attr.decode(stream);
    return READDIR3resfail (
      dir_attributes: dir_attributes,
    );
  }
}


// Union: READDIR3res
abstract class READDIR3res {
  final nfsstat3 discriminant;
  READDIR3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READDIR3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READDIR3resok.decode(stream);
        return READDIR3resNfs3Ok(value);
      default:
        final value = READDIR3resfail.decode(stream);
        return READDIR3resDefault(discriminant, value);
    }
  }
}

class READDIR3resNfs3Ok extends READDIR3res {
  final READDIR3resok value;
  READDIR3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READDIR3resDefault extends READDIR3res {
  final READDIR3resfail value;
  READDIR3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Struct: LINK3args
class LINK3args {
  final nfs_fh3 file;
  final diropargs3 link;

  LINK3args({
    required this.file,
    required this.link,
  });

  void encode(XdrOutputStream stream) {
    file.encode(stream);
    link.encode(stream);
  }

  static LINK3args decode(XdrInputStream stream) {
    final file = nfs_fh3.decode(stream);
    final link = diropargs3.decode(stream);
    return LINK3args (
      file: file,
      link: link,
    );
  }
}


// Struct: LINK3resok
class LINK3resok {
  final post_op_attr file_attributes;
  final wcc_data linkdir_wcc;

  LINK3resok({
    required this.file_attributes,
    required this.linkdir_wcc,
  });

  void encode(XdrOutputStream stream) {
    file_attributes.encode(stream);
    linkdir_wcc.encode(stream);
  }

  static LINK3resok decode(XdrInputStream stream) {
    final file_attributes = post_op_attr.decode(stream);
    final linkdir_wcc = wcc_data.decode(stream);
    return LINK3resok (
      file_attributes: file_attributes,
      linkdir_wcc: linkdir_wcc,
    );
  }
}


// Struct: LINK3resfail
class LINK3resfail {
  final post_op_attr file_attributes;
  final wcc_data linkdir_wcc;

  LINK3resfail({
    required this.file_attributes,
    required this.linkdir_wcc,
  });

  void encode(XdrOutputStream stream) {
    file_attributes.encode(stream);
    linkdir_wcc.encode(stream);
  }

  static LINK3resfail decode(XdrInputStream stream) {
    final file_attributes = post_op_attr.decode(stream);
    final linkdir_wcc = wcc_data.decode(stream);
    return LINK3resfail (
      file_attributes: file_attributes,
      linkdir_wcc: linkdir_wcc,
    );
  }
}


// Union: LINK3res
abstract class LINK3res {
  final nfsstat3 discriminant;
  LINK3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static LINK3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = LINK3resok.decode(stream);
        return LINK3resNfs3Ok(value);
      default:
        final value = LINK3resfail.decode(stream);
        return LINK3resDefault(discriminant, value);
    }
  }
}

class LINK3resNfs3Ok extends LINK3res {
  final LINK3resok value;
  LINK3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class LINK3resDefault extends LINK3res {
  final LINK3resfail value;
  LINK3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Union: sattrguard3
abstract class sattrguard3 {
  final bool discriminant;
  sattrguard3(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeBoolean(discriminant);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static sattrguard3 decode(XdrInputStream stream) {
    final discriminant = stream.readBoolean();
    switch (discriminant) {
      case true:
        final value = nfstime3.decode(stream);
        return sattrguard3True(value);
      case false:
        return sattrguard3False();
      default:
        throw ArgumentError('Unknown discriminant: $discriminant');
    }
  }
}

class sattrguard3True extends sattrguard3 {
  final nfstime3 value;
  sattrguard3True(this.value) : super(true);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class sattrguard3False extends sattrguard3 {
  sattrguard3False() : super(false);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: SETATTR3args
class SETATTR3args {
  final nfs_fh3 object;
  final sattr3 new_attributes;
  final sattrguard3 guard;

  SETATTR3args({
    required this.object,
    required this.new_attributes,
    required this.guard,
  });

  void encode(XdrOutputStream stream) {
    object.encode(stream);
    new_attributes.encode(stream);
    guard.encode(stream);
  }

  static SETATTR3args decode(XdrInputStream stream) {
    final object = nfs_fh3.decode(stream);
    final new_attributes = sattr3.decode(stream);
    final guard = sattrguard3.decode(stream);
    return SETATTR3args (
      object: object,
      new_attributes: new_attributes,
      guard: guard,
    );
  }
}


// Struct: SETATTR3resok
class SETATTR3resok {
  final wcc_data obj_wcc;

  SETATTR3resok({
    required this.obj_wcc,
  });

  void encode(XdrOutputStream stream) {
    obj_wcc.encode(stream);
  }

  static SETATTR3resok decode(XdrInputStream stream) {
    final obj_wcc = wcc_data.decode(stream);
    return SETATTR3resok (
      obj_wcc: obj_wcc,
    );
  }
}


// Struct: SETATTR3resfail
class SETATTR3resfail {
  final wcc_data obj_wcc;

  SETATTR3resfail({
    required this.obj_wcc,
  });

  void encode(XdrOutputStream stream) {
    obj_wcc.encode(stream);
  }

  static SETATTR3resfail decode(XdrInputStream stream) {
    final obj_wcc = wcc_data.decode(stream);
    return SETATTR3resfail (
      obj_wcc: obj_wcc,
    );
  }
}


// Union: SETATTR3res
abstract class SETATTR3res {
  final nfsstat3 discriminant;
  SETATTR3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static SETATTR3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = SETATTR3resok.decode(stream);
        return SETATTR3resNfs3Ok(value);
      default:
        final value = SETATTR3resfail.decode(stream);
        return SETATTR3resDefault(discriminant, value);
    }
  }
}

class SETATTR3resNfs3Ok extends SETATTR3res {
  final SETATTR3resok value;
  SETATTR3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class SETATTR3resDefault extends SETATTR3res {
  final SETATTR3resfail value;
  SETATTR3resDefault(super.discriminant, this.value);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}


// Typedef: fhandle2
typedef fhandle2 = Uint8List;


//  Enum: ftype2
enum ftype2 {
  nf2non(0),
  nf2reg(1),
  nf2dir(2),
  nf2blk(3),
  nf2chr(4),
  nf2lnk(5),
  ;

  final int value;
  const ftype2(this.value);

//    Create from XDR integer value
  factory ftype2.fromValue(final int value) => switch (value) {
      0 => nf2non,
      1 => nf2reg,
      2 => nf2dir,
      3 => nf2blk,
      4 => nf2chr,
      5 => nf2lnk,
      _ => throw ArgumentError('Unknown ftype2 value: $value'),
    };

//    Get all possible values
  static List<ftype2> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      0 => true,
      1 => true,
      2 => true,
      3 => true,
      4 => true,
      5 => true,
      _ => false,
    };
}


// Struct: fattr2
class fattr2 {
  final ftype2 type;
  final int mode;
  final int nlink;
  final int uid;
  final int gid;
  final int size;
  final int blocksize;
  final int rdev;
  final int blocks;
  final int fsid;
  final int fileid;
  final nfstime3 atime;
  final nfstime3 mtime;
  final nfstime3 ctime;

  fattr2({
    required this.type,
    required this.mode,
    required this.nlink,
    required this.uid,
    required this.gid,
    required this.size,
    required this.blocksize,
    required this.rdev,
    required this.blocks,
    required this.fsid,
    required this.fileid,
    required this.atime,
    required this.mtime,
    required this.ctime,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(type.value);
    stream.writeUnsignedInt(mode);
    stream.writeUnsignedInt(nlink);
    stream.writeUnsignedInt(uid);
    stream.writeUnsignedInt(gid);
    stream.writeUnsignedInt(size);
    stream.writeUnsignedInt(blocksize);
    stream.writeUnsignedInt(rdev);
    stream.writeUnsignedInt(blocks);
    stream.writeUnsignedInt(fsid);
    stream.writeUnsignedInt(fileid);
    atime.encode(stream);
    mtime.encode(stream);
    ctime.encode(stream);
  }

  static fattr2 decode(XdrInputStream stream) {
     final typeValue = stream.readInt();
    final type =ftype2.fromValue(typeValue);
    final mode = stream.readUnsignedInt();
    final nlink = stream.readUnsignedInt();
    final uid = stream.readUnsignedInt();
    final gid = stream.readUnsignedInt();
    final size = stream.readUnsignedInt();
    final blocksize = stream.readUnsignedInt();
    final rdev = stream.readUnsignedInt();
    final blocks = stream.readUnsignedInt();
    final fsid = stream.readUnsignedInt();
    final fileid = stream.readUnsignedInt();
    final atime = nfstime3.decode(stream);
    final mtime = nfstime3.decode(stream);
    final ctime = nfstime3.decode(stream);
    return fattr2 (
      type: type,
      mode: mode,
      nlink: nlink,
      uid: uid,
      gid: gid,
      size: size,
      blocksize: blocksize,
      rdev: rdev,
      blocks: blocks,
      fsid: fsid,
      fileid: fileid,
      atime: atime,
      mtime: mtime,
      ctime: ctime,
    );
  }
}


// Struct: sattr2
class sattr2 {
  final int mode;
  final int uid;
  final int gid;
  final int size;
  final nfstime3 atime;
  final nfstime3 mtime;

  sattr2({
    required this.mode,
    required this.uid,
    required this.gid,
    required this.size,
    required this.atime,
    required this.mtime,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedInt(mode);
    stream.writeUnsignedInt(uid);
    stream.writeUnsignedInt(gid);
    stream.writeUnsignedInt(size);
    atime.encode(stream);
    mtime.encode(stream);
  }

  static sattr2 decode(XdrInputStream stream) {
    final mode = stream.readUnsignedInt();
    final uid = stream.readUnsignedInt();
    final gid = stream.readUnsignedInt();
    final size = stream.readUnsignedInt();
    final atime = nfstime3.decode(stream);
    final mtime = nfstime3.decode(stream);
    return sattr2 (
      mode: mode,
      uid: uid,
      gid: gid,
      size: size,
      atime: atime,
      mtime: mtime,
    );
  }
}


// Typedef: filename2
typedef filename2 = String;


// Typedef: path2
typedef path2 = String;


// Typedef: nfsdata2
typedef nfsdata2 = Uint8List;


// Typedef: nfscookie2
typedef nfscookie2 = Uint8List;


// Struct: entry2
class entry2 {
  final int fileid;
  final filename2 name;
  final nfscookie2 cookie;
  final entry2? nextentry;

  entry2({
    required this.fileid,
    required this.name,
    required this.cookie,
    this.nextentry,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedInt(fileid);
    stream.writeString(name);
    stream.writeOpaque(cookie);
    if (nextentry != null) {
      stream.writeInt(1); // Present
      nextentry!.encode(stream);
    } else {
      stream.writeInt(0); // Not present
    }
  }

  static entry2 decode(XdrInputStream stream) {
    final fileid = stream.readUnsignedInt();
    final name = stream.readString();
    final cookie = stream.readOpaque();
    final nextentryPresent = stream.readInt();
    entry2? nextentry;
    if (nextentryPresent != 0) {
      nextentry = entry2.decode(stream);
    }
    return entry2 (
      fileid: fileid,
      name: name,
      cookie: cookie,
      nextentry: nextentry,
    );
  }
}


// Struct: diropargs2
class diropargs2 {
  final fhandle2 dir;
  final filename2 name;

  diropargs2({
    required this.dir,
    required this.name,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(dir);
    stream.writeString(name);
  }

  static diropargs2 decode(XdrInputStream stream) {
    final dir = stream.readOpaque();
    final name = stream.readString();
    return diropargs2 (
      dir: dir,
      name: name,
    );
  }
}


// Struct: GETATTR2args
class GETATTR2args {
  final fhandle2 fhandle;

  GETATTR2args({
    required this.fhandle,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(fhandle);
  }

  static GETATTR2args decode(XdrInputStream stream) {
    final fhandle = stream.readOpaque();
    return GETATTR2args (
      fhandle: fhandle,
    );
  }
}


// Struct: GETATTR2resok
class GETATTR2resok {
  final fattr2 attributes;

  GETATTR2resok({
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    attributes.encode(stream);
  }

  static GETATTR2resok decode(XdrInputStream stream) {
    final attributes = fattr2.decode(stream);
    return GETATTR2resok (
      attributes: attributes,
    );
  }
}


// Union: GETATTR2res
abstract class GETATTR2res {
  final nfsstat3 discriminant;
  GETATTR2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static GETATTR2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = GETATTR2resok.decode(stream);
        return GETATTR2resNfs3Ok(value);
      default:
        return GETATTR2resDefault(discriminant);
    }
  }
}

class GETATTR2resNfs3Ok extends GETATTR2res {
  final GETATTR2resok value;
  GETATTR2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class GETATTR2resDefault extends GETATTR2res {
  GETATTR2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: SETATTR2args
class SETATTR2args {
  final fhandle2 fhandle;
  final sattr2 attributes;

  SETATTR2args({
    required this.fhandle,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(fhandle);
    attributes.encode(stream);
  }

  static SETATTR2args decode(XdrInputStream stream) {
    final fhandle = stream.readOpaque();
    final attributes = sattr2.decode(stream);
    return SETATTR2args (
      fhandle: fhandle,
      attributes: attributes,
    );
  }
}


// Struct: SETATTR2resok
class SETATTR2resok {
  final fattr2 attributes;

  SETATTR2resok({
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    attributes.encode(stream);
  }

  static SETATTR2resok decode(XdrInputStream stream) {
    final attributes = fattr2.decode(stream);
    return SETATTR2resok (
      attributes: attributes,
    );
  }
}


// Union: SETATTR2res
abstract class SETATTR2res {
  final nfsstat3 discriminant;
  SETATTR2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static SETATTR2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = SETATTR2resok.decode(stream);
        return SETATTR2resNfs3Ok(value);
      default:
        return SETATTR2resDefault(discriminant);
    }
  }
}

class SETATTR2resNfs3Ok extends SETATTR2res {
  final SETATTR2resok value;
  SETATTR2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class SETATTR2resDefault extends SETATTR2res {
  SETATTR2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: LOOKUP2args
class LOOKUP2args {
  final diropargs2 what;

  LOOKUP2args({
    required this.what,
  });

  void encode(XdrOutputStream stream) {
    what.encode(stream);
  }

  static LOOKUP2args decode(XdrInputStream stream) {
    final what = diropargs2.decode(stream);
    return LOOKUP2args (
      what: what,
    );
  }
}


// Struct: LOOKUP2resok
class LOOKUP2resok {
  final fhandle2 file;
  final fattr2 attributes;

  LOOKUP2resok({
    required this.file,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(file);
    attributes.encode(stream);
  }

  static LOOKUP2resok decode(XdrInputStream stream) {
    final file = stream.readOpaque();
    final attributes = fattr2.decode(stream);
    return LOOKUP2resok (
      file: file,
      attributes: attributes,
    );
  }
}


// Union: LOOKUP2res
abstract class LOOKUP2res {
  final nfsstat3 discriminant;
  LOOKUP2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static LOOKUP2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = LOOKUP2resok.decode(stream);
        return LOOKUP2resNfs3Ok(value);
      default:
        return LOOKUP2resDefault(discriminant);
    }
  }
}

class LOOKUP2resNfs3Ok extends LOOKUP2res {
  final LOOKUP2resok value;
  LOOKUP2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class LOOKUP2resDefault extends LOOKUP2res {
  LOOKUP2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: READLINK2args
class READLINK2args {
  final fhandle2 file;

  READLINK2args({
    required this.file,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(file);
  }

  static READLINK2args decode(XdrInputStream stream) {
    final file = stream.readOpaque();
    return READLINK2args (
      file: file,
    );
  }
}


// Struct: READLINK2resok
class READLINK2resok {
  final path2 data;

  READLINK2resok({
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    stream.writeString(data);
  }

  static READLINK2resok decode(XdrInputStream stream) {
    final data = stream.readString();
    return READLINK2resok (
      data: data,
    );
  }
}


// Union: READLINK2res
abstract class READLINK2res {
  final nfsstat3 discriminant;
  READLINK2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READLINK2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READLINK2resok.decode(stream);
        return READLINK2resNfs3Ok(value);
      default:
        return READLINK2resDefault(discriminant);
    }
  }
}

class READLINK2resNfs3Ok extends READLINK2res {
  final READLINK2resok value;
  READLINK2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READLINK2resDefault extends READLINK2res {
  READLINK2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: READ2args
class READ2args {
  final fhandle2 file;
  final int offset;
  final int count;
  final int totalcount;

  READ2args({
    required this.file,
    required this.offset,
    required this.count,
    required this.totalcount,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(file);
    stream.writeUnsignedInt(offset);
    stream.writeUnsignedInt(count);
    stream.writeUnsignedInt(totalcount);
  }

  static READ2args decode(XdrInputStream stream) {
    final file = stream.readOpaque();
    final offset = stream.readUnsignedInt();
    final count = stream.readUnsignedInt();
    final totalcount = stream.readUnsignedInt();
    return READ2args (
      file: file,
      offset: offset,
      count: count,
      totalcount: totalcount,
    );
  }
}


// Struct: READ2resok
class READ2resok {
  final fattr2 attributes;
  final nfsdata2 data;

  READ2resok({
    required this.attributes,
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    attributes.encode(stream);
    stream.writeOpaque(data);
  }

  static READ2resok decode(XdrInputStream stream) {
    final attributes = fattr2.decode(stream);
    final data = stream.readOpaque();
    return READ2resok (
      attributes: attributes,
      data: data,
    );
  }
}


// Union: READ2res
abstract class READ2res {
  final nfsstat3 discriminant;
  READ2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READ2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READ2resok.decode(stream);
        return READ2resNfs3Ok(value);
      default:
        return READ2resDefault(discriminant);
    }
  }
}

class READ2resNfs3Ok extends READ2res {
  final READ2resok value;
  READ2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READ2resDefault extends READ2res {
  READ2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: WRITE2args
class WRITE2args {
  final fhandle2 file;
  final int beginoffset;
  final int offset;
  final int totalcount;
  final nfsdata2 data;

  WRITE2args({
    required this.file,
    required this.beginoffset,
    required this.offset,
    required this.totalcount,
    required this.data,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(file);
    stream.writeUnsignedInt(beginoffset);
    stream.writeUnsignedInt(offset);
    stream.writeUnsignedInt(totalcount);
    stream.writeOpaque(data);
  }

  static WRITE2args decode(XdrInputStream stream) {
    final file = stream.readOpaque();
    final beginoffset = stream.readUnsignedInt();
    final offset = stream.readUnsignedInt();
    final totalcount = stream.readUnsignedInt();
    final data = stream.readOpaque();
    return WRITE2args (
      file: file,
      beginoffset: beginoffset,
      offset: offset,
      totalcount: totalcount,
      data: data,
    );
  }
}


// Struct: WRITE2resok
class WRITE2resok {
  final fattr2 attributes;

  WRITE2resok({
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    attributes.encode(stream);
  }

  static WRITE2resok decode(XdrInputStream stream) {
    final attributes = fattr2.decode(stream);
    return WRITE2resok (
      attributes: attributes,
    );
  }
}


// Union: WRITE2res
abstract class WRITE2res {
  final nfsstat3 discriminant;
  WRITE2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static WRITE2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = WRITE2resok.decode(stream);
        return WRITE2resNfs3Ok(value);
      default:
        return WRITE2resDefault(discriminant);
    }
  }
}

class WRITE2resNfs3Ok extends WRITE2res {
  final WRITE2resok value;
  WRITE2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class WRITE2resDefault extends WRITE2res {
  WRITE2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: CREATE2args
class CREATE2args {
  final diropargs2 where;
  final sattr2 attributes;

  CREATE2args({
    required this.where,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    where.encode(stream);
    attributes.encode(stream);
  }

  static CREATE2args decode(XdrInputStream stream) {
    final where = diropargs2.decode(stream);
    final attributes = sattr2.decode(stream);
    return CREATE2args (
      where: where,
      attributes: attributes,
    );
  }
}


// Struct: CREATE2resok
class CREATE2resok {
  final fhandle2 file;
  final fattr2 attributes;

  CREATE2resok({
    required this.file,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(file);
    attributes.encode(stream);
  }

  static CREATE2resok decode(XdrInputStream stream) {
    final file = stream.readOpaque();
    final attributes = fattr2.decode(stream);
    return CREATE2resok (
      file: file,
      attributes: attributes,
    );
  }
}


// Union: CREATE2res
abstract class CREATE2res {
  final nfsstat3 discriminant;
  CREATE2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static CREATE2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = CREATE2resok.decode(stream);
        return CREATE2resNfs3Ok(value);
      default:
        return CREATE2resDefault(discriminant);
    }
  }
}

class CREATE2resNfs3Ok extends CREATE2res {
  final CREATE2resok value;
  CREATE2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class CREATE2resDefault extends CREATE2res {
  CREATE2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: REMOVE2args
class REMOVE2args {
  final diropargs2 what;

  REMOVE2args({
    required this.what,
  });

  void encode(XdrOutputStream stream) {
    what.encode(stream);
  }

  static REMOVE2args decode(XdrInputStream stream) {
    final what = diropargs2.decode(stream);
    return REMOVE2args (
      what: what,
    );
  }
}


// Struct: REMOVE2res
class REMOVE2res {
  final nfsstat3 status;

  REMOVE2res({
    required this.status,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(status.value);
  }

  static REMOVE2res decode(XdrInputStream stream) {
     final statusValue = stream.readInt();
    final status =nfsstat3.fromValue(statusValue);
    return REMOVE2res (
      status: status,
    );
  }
}


// Struct: RENAME2args
class RENAME2args {
  final diropargs2 from;
  final diropargs2 to;

  RENAME2args({
    required this.from,
    required this.to,
  });

  void encode(XdrOutputStream stream) {
    from.encode(stream);
    to.encode(stream);
  }

  static RENAME2args decode(XdrInputStream stream) {
    final from = diropargs2.decode(stream);
    final to = diropargs2.decode(stream);
    return RENAME2args (
      from: from,
      to: to,
    );
  }
}


// Struct: RENAME2res
class RENAME2res {
  final nfsstat3 status;

  RENAME2res({
    required this.status,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(status.value);
  }

  static RENAME2res decode(XdrInputStream stream) {
     final statusValue = stream.readInt();
    final status =nfsstat3.fromValue(statusValue);
    return RENAME2res (
      status: status,
    );
  }
}


// Struct: LINK2args
class LINK2args {
  final fhandle2 from;
  final diropargs2 to;

  LINK2args({
    required this.from,
    required this.to,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(from);
    to.encode(stream);
  }

  static LINK2args decode(XdrInputStream stream) {
    final from = stream.readOpaque();
    final to = diropargs2.decode(stream);
    return LINK2args (
      from: from,
      to: to,
    );
  }
}


// Struct: LINK2res
class LINK2res {
  final nfsstat3 status;

  LINK2res({
    required this.status,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(status.value);
  }

  static LINK2res decode(XdrInputStream stream) {
     final statusValue = stream.readInt();
    final status =nfsstat3.fromValue(statusValue);
    return LINK2res (
      status: status,
    );
  }
}


// Struct: SYMLINK2args
class SYMLINK2args {
  final diropargs2 from;
  final path2 to;
  final sattr2 attributes;

  SYMLINK2args({
    required this.from,
    required this.to,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    from.encode(stream);
    stream.writeString(to);
    attributes.encode(stream);
  }

  static SYMLINK2args decode(XdrInputStream stream) {
    final from = diropargs2.decode(stream);
    final to = stream.readString();
    final attributes = sattr2.decode(stream);
    return SYMLINK2args (
      from: from,
      to: to,
      attributes: attributes,
    );
  }
}


// Struct: SYMLINK2res
class SYMLINK2res {
  final nfsstat3 status;

  SYMLINK2res({
    required this.status,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(status.value);
  }

  static SYMLINK2res decode(XdrInputStream stream) {
     final statusValue = stream.readInt();
    final status =nfsstat3.fromValue(statusValue);
    return SYMLINK2res (
      status: status,
    );
  }
}


// Struct: MKDIR2args
class MKDIR2args {
  final diropargs2 where;
  final sattr2 attributes;

  MKDIR2args({
    required this.where,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    where.encode(stream);
    attributes.encode(stream);
  }

  static MKDIR2args decode(XdrInputStream stream) {
    final where = diropargs2.decode(stream);
    final attributes = sattr2.decode(stream);
    return MKDIR2args (
      where: where,
      attributes: attributes,
    );
  }
}


// Struct: MKDIR2resok
class MKDIR2resok {
  final fhandle2 file;
  final fattr2 attributes;

  MKDIR2resok({
    required this.file,
    required this.attributes,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(file);
    attributes.encode(stream);
  }

  static MKDIR2resok decode(XdrInputStream stream) {
    final file = stream.readOpaque();
    final attributes = fattr2.decode(stream);
    return MKDIR2resok (
      file: file,
      attributes: attributes,
    );
  }
}


// Union: MKDIR2res
abstract class MKDIR2res {
  final nfsstat3 discriminant;
  MKDIR2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static MKDIR2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = MKDIR2resok.decode(stream);
        return MKDIR2resNfs3Ok(value);
      default:
        return MKDIR2resDefault(discriminant);
    }
  }
}

class MKDIR2resNfs3Ok extends MKDIR2res {
  final MKDIR2resok value;
  MKDIR2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class MKDIR2resDefault extends MKDIR2res {
  MKDIR2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: RMDIR2args
class RMDIR2args {
  final diropargs2 what;

  RMDIR2args({
    required this.what,
  });

  void encode(XdrOutputStream stream) {
    what.encode(stream);
  }

  static RMDIR2args decode(XdrInputStream stream) {
    final what = diropargs2.decode(stream);
    return RMDIR2args (
      what: what,
    );
  }
}


// Struct: RMDIR2res
class RMDIR2res {
  final nfsstat3 status;

  RMDIR2res({
    required this.status,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(status.value);
  }

  static RMDIR2res decode(XdrInputStream stream) {
     final statusValue = stream.readInt();
    final status =nfsstat3.fromValue(statusValue);
    return RMDIR2res (
      status: status,
    );
  }
}


// Struct: READDIR2args
class READDIR2args {
  final fhandle2 dir;
  final nfscookie2 cookie;
  final int count;

  READDIR2args({
    required this.dir,
    required this.cookie,
    required this.count,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(dir);
    stream.writeOpaque(cookie);
    stream.writeUnsignedInt(count);
  }

  static READDIR2args decode(XdrInputStream stream) {
    final dir = stream.readOpaque();
    final cookie = stream.readOpaque();
    final count = stream.readUnsignedInt();
    return READDIR2args (
      dir: dir,
      cookie: cookie,
      count: count,
    );
  }
}


// Struct: READDIR2resok
class READDIR2resok {
  final entry2? entries;
  final bool eof;

  READDIR2resok({
    this.entries,
    required this.eof,
  });

  void encode(XdrOutputStream stream) {
    if (entries != null) {
      stream.writeInt(1); // Present
      entries!.encode(stream);
    } else {
      stream.writeInt(0); // Not present
    }
    stream.writeBoolean(eof);
  }

  static READDIR2resok decode(XdrInputStream stream) {
    final entriesPresent = stream.readInt();
    entry2? entries;
    if (entriesPresent != 0) {
      entries = entry2.decode(stream);
    }
    final eof = stream.readBoolean();
    return READDIR2resok (
      entries: entries,
      eof: eof,
    );
  }
}


// Union: READDIR2res
abstract class READDIR2res {
  final nfsstat3 discriminant;
  READDIR2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static READDIR2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = READDIR2resok.decode(stream);
        return READDIR2resNfs3Ok(value);
      default:
        return READDIR2resDefault(discriminant);
    }
  }
}

class READDIR2resNfs3Ok extends READDIR2res {
  final READDIR2resok value;
  READDIR2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class READDIR2resDefault extends READDIR2res {
  READDIR2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: STATFS2args
class STATFS2args {
  final fhandle2 dir;

  STATFS2args({
    required this.dir,
  });

  void encode(XdrOutputStream stream) {
    stream.writeOpaque(dir);
  }

  static STATFS2args decode(XdrInputStream stream) {
    final dir = stream.readOpaque();
    return STATFS2args (
      dir: dir,
    );
  }
}


// Struct: STATFS2resok
class STATFS2resok {
  final int tsize;
  final int bsize;
  final int blocks;
  final int bfree;
  final int bavail;

  STATFS2resok({
    required this.tsize,
    required this.bsize,
    required this.blocks,
    required this.bfree,
    required this.bavail,
  });

  void encode(XdrOutputStream stream) {
    stream.writeUnsignedInt(tsize);
    stream.writeUnsignedInt(bsize);
    stream.writeUnsignedInt(blocks);
    stream.writeUnsignedInt(bfree);
    stream.writeUnsignedInt(bavail);
  }

  static STATFS2resok decode(XdrInputStream stream) {
    final tsize = stream.readUnsignedInt();
    final bsize = stream.readUnsignedInt();
    final blocks = stream.readUnsignedInt();
    final bfree = stream.readUnsignedInt();
    final bavail = stream.readUnsignedInt();
    return STATFS2resok (
      tsize: tsize,
      bsize: bsize,
      blocks: blocks,
      bfree: bfree,
      bavail: bavail,
    );
  }
}


// Union: STATFS2res
abstract class STATFS2res {
  final nfsstat3 discriminant;
  STATFS2res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static STATFS2res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = STATFS2resok.decode(stream);
        return STATFS2resNfs3Ok(value);
      default:
        return STATFS2resDefault(discriminant);
    }
  }
}

class STATFS2resNfs3Ok extends STATFS2res {
  final STATFS2resok value;
  STATFS2resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class STATFS2resDefault extends STATFS2res {
  STATFS2resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


//  Enum: nfsacl_type
enum nfsacl_type {
  nfsacl_type_user_obj(1),
  nfsacl_type_user(2),
  nfsacl_type_group_obj(4),
  nfsacl_type_group(8),
  nfsacl_type_class_obj(16),
  nfsacl_type_class(32),
  nfsacl_type_default(4096),
  nfsacl_type_default_user_obj(4097),
  nfsacl_type_default_user(4098),
  nfsacl_type_default_group_obj(4100),
  nfsacl_type_default_group(4104),
  nfsacl_type_default_class_obj(4112),
  nfsacl_type_default_other_obj(4128),
  ;

  final int value;
  const nfsacl_type(this.value);

//    Create from XDR integer value
  factory nfsacl_type.fromValue(final int value) => switch (value) {
      1 => nfsacl_type_user_obj,
      2 => nfsacl_type_user,
      4 => nfsacl_type_group_obj,
      8 => nfsacl_type_group,
      16 => nfsacl_type_class_obj,
      32 => nfsacl_type_class,
      4096 => nfsacl_type_default,
      4097 => nfsacl_type_default_user_obj,
      4098 => nfsacl_type_default_user,
      4100 => nfsacl_type_default_group_obj,
      4104 => nfsacl_type_default_group,
      4112 => nfsacl_type_default_class_obj,
      4128 => nfsacl_type_default_other_obj,
      _ => throw ArgumentError('Unknown nfsacl_type value: $value'),
    };

//    Get all possible values
  static List<nfsacl_type> get allValues => values;

//    Check if value is valid
  static bool isValid(final int value) => switch (value) {
      1 => true,
      2 => true,
      4 => true,
      8 => true,
      16 => true,
      32 => true,
      4096 => true,
      4097 => true,
      4098 => true,
      4100 => true,
      4104 => true,
      4112 => true,
      4128 => true,
      _ => false,
    };
}


// Struct: nfsacl_ace
class nfsacl_ace {
  final nfsacl_type type;
  final int id;
  final int perm;

  nfsacl_ace({
    required this.type,
    required this.id,
    required this.perm,
  });

  void encode(XdrOutputStream stream) {
    stream.writeInt(type.value);
    stream.writeUnsignedInt(id);
    stream.writeUnsignedInt(perm);
  }

  static nfsacl_ace decode(XdrInputStream stream) {
     final typeValue = stream.readInt();
    final type =nfsacl_type.fromValue(typeValue);
    final id = stream.readUnsignedInt();
    final perm = stream.readUnsignedInt();
    return nfsacl_ace (
      type: type,
      id: id,
      perm: perm,
    );
  }
}


// Struct: GETACL3args
class GETACL3args {
  final nfs_fh3 dir;
  final int mask;

  GETACL3args({
    required this.dir,
    required this.mask,
  });

  void encode(XdrOutputStream stream) {
    dir.encode(stream);
    stream.writeUnsignedInt(mask);
  }

  static GETACL3args decode(XdrInputStream stream) {
    final dir = nfs_fh3.decode(stream);
    final mask = stream.readUnsignedInt();
    return GETACL3args (
      dir: dir,
      mask: mask,
    );
  }
}


// Struct: GETACL3resok
class GETACL3resok {
  final post_op_attr attr;
  final int mask;
  final int ace_count;
  final List<nfsacl_ace> ace;
  final int default_ace_count;
  final List<nfsacl_ace> default_ace;

  GETACL3resok({
    required this.attr,
    required this.mask,
    required this.ace_count,
    required this.ace,
    required this.default_ace_count,
    required this.default_ace,
  });

  void encode(XdrOutputStream stream) {
    attr.encode(stream);
    stream.writeUnsignedInt(mask);
    stream.writeUnsignedInt(ace_count);
    // Variable array with no maximum
    stream.writeInt(ace.length);
    for (final item in ace) {
      item.encode(stream);
    }
    stream.writeUnsignedInt(default_ace_count);
    // Variable array with no maximum
    stream.writeInt(default_ace.length);
    for (final item in default_ace) {
      item.encode(stream);
    }
  }

  static GETACL3resok decode(XdrInputStream stream) {
    final attr = post_op_attr.decode(stream);
    final mask = stream.readUnsignedInt();
    final ace_count = stream.readUnsignedInt();
    // Variable array
    final aceLength = stream.readInt();
    final _arrayace = <nfsacl_ace>[];
    for (int i = 0; i < aceLength; i++) {
      final item = nfsacl_ace.decode(stream);
      _arrayace.add(item);
    }
    final ace = _arrayace;
    final default_ace_count = stream.readUnsignedInt();
    // Variable array
    final default_aceLength = stream.readInt();
    final _arraydefault_ace = <nfsacl_ace>[];
    for (int i = 0; i < default_aceLength; i++) {
      final item = nfsacl_ace.decode(stream);
      _arraydefault_ace.add(item);
    }
    final default_ace = _arraydefault_ace;
    return GETACL3resok (
      attr: attr,
      mask: mask,
      ace_count: ace_count,
      ace: ace,
      default_ace_count: default_ace_count,
      default_ace: default_ace,
    );
  }
}


// Union: GETACL3res
abstract class GETACL3res {
  final nfsstat3 discriminant;
  GETACL3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static GETACL3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = GETACL3resok.decode(stream);
        return GETACL3resNfs3Ok(value);
      default:
        return GETACL3resDefault(discriminant);
    }
  }
}

class GETACL3resNfs3Ok extends GETACL3res {
  final GETACL3resok value;
  GETACL3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class GETACL3resDefault extends GETACL3res {
  GETACL3resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


// Struct: SETACL3args
class SETACL3args {
  final nfs_fh3 dir;
  final int mask;
  final int ace_count;
  final List<nfsacl_ace> ace;
  final int default_ace_count;
  final List<nfsacl_ace> default_ace;

  SETACL3args({
    required this.dir,
    required this.mask,
    required this.ace_count,
    required this.ace,
    required this.default_ace_count,
    required this.default_ace,
  });

  void encode(XdrOutputStream stream) {
    dir.encode(stream);
    stream.writeUnsignedInt(mask);
    stream.writeUnsignedInt(ace_count);
    // Variable array with no maximum
    stream.writeInt(ace.length);
    for (final item in ace) {
      item.encode(stream);
    }
    stream.writeUnsignedInt(default_ace_count);
    // Variable array with no maximum
    stream.writeInt(default_ace.length);
    for (final item in default_ace) {
      item.encode(stream);
    }
  }

  static SETACL3args decode(XdrInputStream stream) {
    final dir = nfs_fh3.decode(stream);
    final mask = stream.readUnsignedInt();
    final ace_count = stream.readUnsignedInt();
    // Variable array
    final aceLength = stream.readInt();
    final _arrayace = <nfsacl_ace>[];
    for (int i = 0; i < aceLength; i++) {
      final item = nfsacl_ace.decode(stream);
      _arrayace.add(item);
    }
    final ace = _arrayace;
    final default_ace_count = stream.readUnsignedInt();
    // Variable array
    final default_aceLength = stream.readInt();
    final _arraydefault_ace = <nfsacl_ace>[];
    for (int i = 0; i < default_aceLength; i++) {
      final item = nfsacl_ace.decode(stream);
      _arraydefault_ace.add(item);
    }
    final default_ace = _arraydefault_ace;
    return SETACL3args (
      dir: dir,
      mask: mask,
      ace_count: ace_count,
      ace: ace,
      default_ace_count: default_ace_count,
      default_ace: default_ace,
    );
  }
}


// Struct: SETACL3resok
class SETACL3resok {
  final post_op_attr attr;

  SETACL3resok({
    required this.attr,
  });

  void encode(XdrOutputStream stream) {
    attr.encode(stream);
  }

  static SETACL3resok decode(XdrInputStream stream) {
    final attr = post_op_attr.decode(stream);
    return SETACL3resok (
      attr: attr,
    );
  }
}


// Union: SETACL3res
abstract class SETACL3res {
  final nfsstat3 discriminant;
  SETACL3res(this.discriminant);

  void encode(XdrOutputStream stream) {
    stream.writeInt(discriminant.value);
    encodeArm(stream);
  }

  void encodeArm(XdrOutputStream stream);

  static SETACL3res decode(XdrInputStream stream) {
     final discriminantValue = stream.readInt();
    final discriminant =nfsstat3.fromValue(discriminantValue);
    switch (discriminant) {
      case nfsstat3.nfs3_ok:
        final value = SETACL3resok.decode(stream);
        return SETACL3resNfs3Ok(value);
      default:
        return SETACL3resDefault(discriminant);
    }
  }
}

class SETACL3resNfs3Ok extends SETACL3res {
  final SETACL3resok value;
  SETACL3resNfs3Ok(this.value) : super(nfsstat3.nfs3_ok);
  
  @override
  void encodeArm(XdrOutputStream stream) {
    value.encode(stream);
  }
}

class SETACL3resDefault extends SETACL3res {
  SETACL3resDefault(super.discriminant);
  
  @override
  void encodeArm(XdrOutputStream stream) {}
}


//  Program constants
const NFS_PROGRAM = 100003;
const NFS_V2 = 2;
const NFS2_NULL = 0;
const NFS2_GETATTR = 1;
const NFS2_SETATTR = 2;
const NFS2_LOOKUP = 4;
const NFS2_READLINK = 5;
const NFS2_READ = 6;
const NFS2_WRITE = 8;
const NFS2_CREATE = 9;
const NFS2_REMOVE = 10;
const NFS2_RENAME = 11;
const NFS2_LINK = 12;
const NFS2_SYMLINK = 13;
const NFS2_MKDIR = 14;
const NFS2_RMDIR = 15;
const NFS2_READDIR = 16;
const NFS2_STATFS = 17;
const NFS_V3 = 3;
const NFS3_NULL = 0;
const NFS3_GETATTR = 1;
const NFS3_SETATTR = 2;
const NFS3_LOOKUP = 3;
const NFS3_ACCESS = 4;
const NFS3_READLINK = 5;
const NFS3_READ = 6;
const NFS3_WRITE = 7;
const NFS3_CREATE = 8;
const NFS3_MKDIR = 9;
const NFS3_SYMLINK = 10;
const NFS3_MKNOD = 11;
const NFS3_REMOVE = 12;
const NFS3_RMDIR = 13;
const NFS3_RENAME = 14;
const NFS3_LINK = 15;
const NFS3_READDIR = 16;
const NFS3_READDIRPLUS = 17;
const NFS3_FSSTAT = 18;
const NFS3_FSINFO = 19;
const NFS3_PATHCONF = 20;
const NFS3_COMMIT = 21;


//  Program constants
const NFSACL_PROGRAM = 100227;
const NFSACL_V3 = 3;
const NFSACL3_NULL = 0;
const NFSACL3_GETACL = 1;
const NFSACL3_SETACL = 2;
