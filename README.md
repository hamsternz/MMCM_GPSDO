# MMCM_GPSDO
An all-digital GPS disciplined oscillator using MMCM phase shift. 

Using a BASYS3 development board, if a GPS module's PPS input is 
connected to JB0 clk signal will be soon be locked to the GPS
system's time reference.  LEDs 14:0 show the current error in HZ,
and LED15 show if it is locked.

Well, by locked I mean it will have a frequency that is kept within
one part per million of GPS time.

The control loop is woefully engineered, and the size of all the 
registers has been (not) optimized for coding simplicity, and all
the constants are empirically derived, but it works as advertised.

Plenty of room for experiment and improvement.
