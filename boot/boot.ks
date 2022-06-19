wait until ship:unpacked.
clearscreen.
set terminal:height to 15.
set terminal:width to 30.

print "Booting...".

// Copy files to local volume
copypath("globals", "1:/").
copypath("lko", "1:/").

switch to 1.

print "Done".
