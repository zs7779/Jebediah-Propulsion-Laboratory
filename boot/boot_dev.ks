wait until ship:unpacked.
clearscreen.
print "Booting...".

// Copy files to local volume
copypath("globals", "1:/").
copypath("lko", "1:/").

print "Done".
run lko.