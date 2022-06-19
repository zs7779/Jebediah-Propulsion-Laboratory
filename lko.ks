run globals.

clearScreen.

stagingToOrbit().

PILoopControlToOrbit(LKOSteers).

//we'll make sure our throttle is zero and that we're pointed prograde
lock throttle to 0.

circularizeOrbit().

//This sets the user's throttle setting to zero to prevent the throttle
//from returning to the position it was at before the script was run.
set ship:CONTROL:PILOTMAINTHROTTLE to 0.

sas on.
print "SAS on".
wait 1.
set sasmode to "PROGRADE".
