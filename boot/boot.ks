wait until ship:unpacked.
clearscreen.
set terminal:height to 15.
set terminal:width to 30.

print "Booting...".

// Copy files to local volume
copypath("utils", "1:/").
copypath("lko", "1:/").
copypath("go", "1:/").

switch to 1.

print "Done".
