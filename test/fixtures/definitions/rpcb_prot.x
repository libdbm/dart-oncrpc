/*
 * rpcb_prot.x
 * RPCBIND protocol in rpc language
 */
/*
 * A mapping of (program, version, network ID) to universal
address
 */
struct rpcb {
	rpcproc_t r_prog;           /* program number */
	rpcvers_t r_vers;           /* version number */
	string r_netid<>;               /* network id */
	string r_addr<>;                /* universal address */
	string r_owner<>;               /* owner of this service */ };
/* A list of mappings */
struct rpcblist {
	rpcb rpcb_map;
	struct rpcblist *rpcb_next;
};

/* Arguments of remote calls */
struct rpcb_rmtcallargs {
	rpcprog_t prog;             /* program number */
	rpcvers_t vers;             /* version number */
	rpcproc_t proc;             /* procedure number */
	opaque args<>;                  /* argument */
};

/* Results of the remote call */
struct rpcb_rmtcallres {
	string addr<>;                  /* remote universal address */
	opaque results<>;               /* result */
};

/*
 * rpcb_entry contains a merged address of a service on a
particular
 * transport, plus associated netconfig information. A list of
 * rpcb_entrys is returned by RPCBPROC_GETADDRLIST. See
netconfig.h
 * for values used in r_nc_* fields.
 */
struct rpcb_entry {
	string          r_maddr<>;      /* merged address of service */
	string          r_nc_netid<>;   /* netid field */
	unsigned int   r_nc_semantics; /* semantics of transport */
	string          r_nc_protofmly<>; /* protocol family */
	string          r_nc_proto<>;   /* protocol name */
};

/* A list of addresses supported by a service. */
struct rpcb_entry_list {
	rpcb_entry rpcb_entry_map;
	struct rpcb_entry_list *rpcb_entry_next;
};

typedef rpcb_entry_list *rpcb_entry_list_ptr;

/* rpcbind statistics */
const rpcb_highproc_2 = RPCBPROC_CALLIT;
const rpcb_highproc_3 = RPCBPROC_TADDR2UADDR;
const rpcb_highproc_4 = RPCBPROC_GETSTAT;
const RPCBSTAT_HIGHPROC = 13;  /* # of procs in rpcbind V4 plus
one */
const RPCBVERS_STAT = 3;  /* provide only for rpcbind V2, V3 and
V4 */
const RPCBVERS_4_STAT = 2;
const RPCBVERS_3_STAT = 1;
const RPCBVERS_2_STAT = 0;

/* Link list of all the stats about getport and getaddr */
struct rpcbs_addrlist {
	rpcprog_t prog;
	rpcvers_t vers;
	int success;
	int failure;
	string netid<>;
	struct rpcbs_addrlist *next;
};

/* Link list of all the stats about rmtcall */
struct rpcbs_rmtcalllist {
	rpcprog_t prog;
	rpcvers_t vers;
	rpcproc_t proc;
	int success;
	int failure;
	int indirect;   /* whether callit or indirect */
	string netid<>;
	struct rpcbs_rmtcalllist *next;
};

typedef int rpcbs_proc[RPCBSTAT_HIGHPROC];
typedef rpcbs_addrlist *rpcbs_addrlist_ptr;
typedef rpcbs_rmtcalllist *rpcbs_rmtcalllist_ptr;

struct rpcb_stat {
	rpcbs_proc              info;
	int                     setinfo;
	int                     unsetinfo;
	rpcbs_addrlist_ptr      addrinfo;
	rpcbs_rmtcalllist_ptr   rmtinfo;
};

/*
 * One rpcb_stat structure is returned for each version of rpcbind
 * being monitored.
 */
typedef rpcb_stat rpcb_stat_byvers[RPCBVERS_STAT];
/* rpcbind procedures */
program RPCBPROG {
	version RPCBVERS {
		void
		RPCBPROC_NULL(void) = 0;

		/*
		 * Registers the tuple [r_prog, r_vers, r_addr, r_owner,

		 * r_netid]. The rpcbind server accepts requests for this
		 * procedure on only the loopback transport for security
		 * reasons. Returns TRUE if successful, FALSE on failure.
		 */
		bool
		RPCBPROC_SET(rpcb) = 1;

		/*
		 * Unregisters the tuple [r_prog, r_vers, r_owner, r_netid].

		 * If vers is zero, all versions are
unregistered. The rpcbind
		 * server accepts requests for this procedure on only the
		 * loopback transport for security reasons.  Returns TRUE if
		 * successful, FALSE on failure.
		 */
		bool
		RPCBPROC_UNSET(rpcb) = 2;

		/*
		 * Returns the universal address where the triple [r_prog,

		 * r_vers, r_netid] is registered.  If r_addr specified,
		 * return a universal address merged on r_addr. Ignores
		 * r_owner. Returns FALSE on failure.
		 */
		string
		RPCBPROC_GETADDR(rpcb) = 3;

		/* Returns a list of all mappings. */

	rpcblist
		RPCBPROC_DUMP(void) = 4;

		/*
		 * Calls the procedure on the remote machine.  If it is not

		 * registered, this procedure IS quiet; that is, it DOES NOT
		 * return error information.
		 */
		rpcb_rmtcallres
		RPCBPROC_CALLIT(rpcb_rmtcallargs) = 5;

		/*
		 * Returns the time on the rpcbind server's system.

		 */
		unsigned int
		RPCBPROC_GETTIME(void) = 6;

		struct netbuf
		RPCBPROC_UADDR2TADDR(string) = 7;


		string
		RPCBPROC_TADDR2UADDR(struct netbuf) = 8;

		} = 3;
		version RPCBVERS4 {
		bool
		RPCBPROC_SET(rpcb) = 1;

		bool
		RPCBPROC_UNSET(rpcb) = 2;

		string
		RPCBPROC_GETADDR(rpcb) = 3;

		rpcblist_ptr
		RPCBPROC_DUMP(void) = 4;

		/*
		 * NOTE: RPCBPROC_BCAST has the same functionality as CALLIT;

		 * the new name is
intended to indicate that this procedure
		 * should be used for broadcast RPC, and RPCBPROC_INDIRECT
		 * should be used for indirect calls.
		 */
		rpcb_rmtcallres
		RPCBPROC_BCAST(rpcb_rmtcallargs) = RPCBPROC_CALLIT;

		unsigned int
		RPCBPROC_GETTIME(void) = 6;

		struct netbuf
		RPCBPROC_UADDR2TADDR(string) = 7;


		string
		RPCBPROC_TADDR2UADDR(struct netbuf) = 8;


		/*
		 * Same as RPCBPROC_GETADDR except that if the given version

		 * number is not available, the address is not returned.
		 */
		string
		RPCBPROC_GETVERSADDR(rpcb) = 9;


		/*
		 * Calls the procedure on the remote machine.  If it is not
		 * registered, this procedure IS NOT quiet; that is, it DOES
		 * return error information.
		 */
		rpcb_rmtcallres
		RPCBPROC_INDIRECT(rpcb_rmtcallargs) = 10;

		/*
		 * Same as RPCBPROC_GETADDR except that it returns a list of

		 * addresses registered for the combination (prog, vers).
		 */
		rpcb_entry_list_ptr
		RPCBPROC_GETADDRLIST(rpcb) = 11;

		/*
		 * Returns statistics about the rpcbind server's activity.

		 */
		rpcb_stat_byvers
		RPCBPROC_GETSTAT(void) = 12;
	} = 4;
} = 100000;
