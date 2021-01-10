# OETF #7 ON2
An implementation of OETF #7 as a library for OpenOS.


on2.lua is the library file, on2d.lua is a simple rc daemon that listens for ON2 packets on the main network card and generates on2_message signals for other programs to use. The on2_message signals have the same parameters as the return value from on2.listen().
