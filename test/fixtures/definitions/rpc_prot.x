enum msg_type {
 	CALL = 0,
 	REPLY = 1
 };

/*
 * A reply to a call message can take on two forms: The message was
 * either accepted or rejected.
 */
 enum reply_stat {
 	MSG_ACCEPTED = 0,
 	MSG_DENIED = 1
 };

/*
 * Given that a call message was accepted, the following is the
 * status of an attempt to call a remote procedure.
 */
enum accept_stat {
 	SUCCESS = 0,       /* RPC executed successfully */
 	PROG_UNAVAIL = 1,  /* remote service hasn't exported prog */
 	PROG_MISMATCH = 2, /* remote service can't support versn # */
 	PROC_UNAVAIL = 3,  /* program can't support proc */
 	GARBAGE_ARGS = 4   /* procedure can't decode params */
};

/*
 * Reasons a call message was rejected:
 */
enum reject_stat {
 	RPC_MISMATCH = 0,  /* RPC version number != 2 */
 	AUTH_ERROR = 1     /* remote can't authenticate caller */
};
/*
 * Why authentication failed:
 */
enum auth_stat {
 	AUTH_BADCRED = 1,       /* bad credentials */
 	AUTH_REJECTEDCRED = 2,  /* clnt must do new session */
 	AUTH_BADVERF = 3,       /* bad verifier */
 	AUTH_REJECTEDVERF = 4,  /* verif expired or replayed */
 	AUTH_TOOWEAK = 5        /* rejected for security */
};

/*
 * The RPC message:
 * All messages start with a transaction identifier, xid, followed
 * by a two-armed discriminated union. The union's discriminant is
 * a msg_type which switches to one of the two types of the
 * message.
 * The xid of a REPLY message always matches that of the
 * initiating CALL message. NB: The xid field is only used for
 * clients matching reply messages with call messages or for servers
 * detecting retransmissions; the service side cannot treat this id as
 * any type of sequence number.
 */
struct rpc_msg {
 	unsigned int xid;
 	union switch (msg_type mtype) {
 		case CALL:
 			call_body cbody;
 		case REPLY:
 			reply_body rbody;
 	} body;
};

/*
 * Body of an RPC request call:
 * In version 2 of the RPC protocol specification, rpcvers must be
 * equal to 2. The fields prog, vers, and proc specify the remote
 * program, its version number, and the procedure within the
 * remote program to be called. After these fields are two
 * authentication parameters: cred (authentication credentials) and
 * verf (authentication verifier). The two authentication parameters
 * are followed by the parameters to the remote procedure, which are
 * specified by the specific program protocol.
 */
struct call_body {
 	unsigned int rpcvers; /* must be equal to two (2) */
 	unsigned int prog;
 	unsigned int vers;
 	unsigned int proc;
 	opaque_auth cred;
 	opaque_auth verf;
 	/* procedure specific parameters start here */
 };

/*
 * Body of a reply to an RPC request:
 * The call message was either accepted or rejected.
 */
union reply_body switch (reply_stat stat) {
 	case MSG_ACCEPTED:
 		accepted_reply areply;
 	case MSG_DENIED:
 		rejected_reply rreply;
} reply;

/*
 * Reply to an RPC request that was accepted by the server: there
 * could be an error even though the request was accepted. The
 * first field is an authentication verifier that the server
 * generates in order to validate itself to the caller. It is
 * followed by a union whose discriminant is an enum accept_stat.
 * The SUCCESS arm of the union is protocol specific.
 * The PROG_UNAVAIL, PROC_UNAVAIL, and GARBAGE_ARGP arms of
 * the union are void. The PROG_MISMATCH arm specifies the lowest
 * and highest version numbers of the remote program supported by
 * the server.
 */
struct accepted_reply {
 	opaque_auth verf;
 	union switch (accept_stat stat) {
 		case SUCCESS:
 			opaque results[0];
 			/* procedure-specific results start here */
 		case PROG_MISMATCH:
 			struct {
 				unsigned int low;
 				unsigned int high;
 			} mismatch_info;
 		default:
 			/*
 			 * Void. Cases include PROG_UNAVAIL, PROC_UNAVAIL, and
			    * GARBAGE_ARGS.
 			 */
 			void;
 	} reply_data;
 };

/*
 * Reply to an RPC request that was rejected by the server:
 * The request can be rejected for two reasons: either the server
 * is not running a compatible version of the RPC protocol
 * (RPC_MISMATCH), or the server refuses to authenticate the
 * caller AUTH_ERROR). In case of an RPC version mismatch,
 * the server returns the lowest and highest supported RPC
 * version numbers. In case of refused authentication, failure
 * status is returned.
 */
union rejected_reply switch (reject_stat stat) {
 	case RPC_MISMATCH:
 		struct {
 			unsigned int low;
 			unsigned int high;
 		} mismatch_info;
 	case AUTH_ERROR:
 		auth_stat stat;
};
