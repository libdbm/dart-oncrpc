/*
 * time.x: Get or set the time. Time is represented as seconds
 * since 0:00, January 1, 1970.
 */
 program TIMEPROG {
   version TIMEVERS {
      unsigned int TIMEGET(void) = 1;
 		void TIMESET(unsigned) = 2;
 	} = 1;
} = 0x20000044;
