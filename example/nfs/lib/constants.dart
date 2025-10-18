/// NFS and MOUNT protocol constants.
///
/// These constants are used by the server implementation for protocol values
/// that aren't generated from the .x files.
// ignore_for_file: constant_identifier_names
library;

// Re-export generated constants
export 'nfs_types.dart';

// NFS Error codes (from nfsstat3 enum values)
const NFS3_OK = 0;
const NFS3ERR_PERM = 1;
const NFS3ERR_NOENT = 2;
const NFS3ERR_IO = 5;
const NFS3ERR_NXIO = 6;
const NFS3ERR_ACCES = 13;
const NFS3ERR_EXIST = 17;
const NFS3ERR_XDEV = 18;
const NFS3ERR_NODEV = 19;
const NFS3ERR_NOTDIR = 20;
const NFS3ERR_ISDIR = 21;
const NFS3ERR_INVAL = 22;
const NFS3ERR_FBIG = 27;
const NFS3ERR_NOSPC = 28;
const NFS3ERR_ROFS = 30;
const NFS3ERR_MLINK = 31;
const NFS3ERR_NAMETOOLONG = 63;
const NFS3ERR_NOTEMPTY = 66;
const NFS3ERR_DQUOT = 69;
const NFS3ERR_STALE = 70;
const NFS3ERR_REMOTE = 71;
const NFS3ERR_BADHANDLE = 10001;
const NFS3ERR_NOT_SYNC = 10002;
const NFS3ERR_BAD_COOKIE = 10003;
const NFS3ERR_NOTSUPP = 10004;
const NFS3ERR_TOOSMALL = 10005;
const NFS3ERR_SERVERFAULT = 10006;
const NFS3ERR_BADTYPE = 10007;
const NFS3ERR_JUKEBOX = 10008;

// MOUNT Error codes
const MNT3_OK = 0;
const MNT3ERR_PERM = 1;
const MNT3ERR_NOENT = 2;
const MNT3ERR_IO = 5;
const MNT3ERR_ACCES = 13;
const MNT3ERR_NOTDIR = 20;
const MNT3ERR_INVAL = 22;
const MNT3ERR_NAMETOOLONG = 63;
const MNT3ERR_NOTSUPP = 10004;
const MNT3ERR_SERVERFAULT = 10006;

// Program and version numbers
const NFS_PROGRAM = 100003;
const NFS_V2 = 2;
const NFS_V3 = 3;

const MOUNT_PROGRAM = 100005;
const MOUNT_V1 = 1;
const MOUNT_V3 = 3;

// Stable_how values
const UNSTABLE = 0;
const DATA_SYNC = 1;
const FILE_SYNC = 2;

// FSInfo properties
const FSF3_LINK = 1;
const FSF3_SYMLINK = 2;
const FSF3_HOMOGENEOUS = 8;
const FSF3_CANSETTIME = 16;
