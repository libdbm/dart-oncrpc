/*
 * Simple ping program
 */
program PING_PROG {
 	version PING_VERS_PINGBACK {
 		void
 		PINGPROC_NULL(void) = 0;
 		/*
		 * ping the caller, return the round-trip time
		 * in milliseconds. Return a minus one (-1) if
 		 * operation times-out
		 */
		int
 		PINGPROC_PINGBACK(void) = 1;
 		/* void - above is an argument to the call */
 	} = 2;
/*
 * Original version
 */
 	version PING_VERS_ORIG {
 		void
 		PINGPROC_NULL(void) = 0;
 	} = 1;
} = 200000;
const PING_VERS = 2; /* latest version */