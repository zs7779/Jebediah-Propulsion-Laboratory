wait until ship:unpacked.
clearscreen.
print "Booting...".

// Copy files to local volume
copypath("utils", "1:/").
copypath("lko", "1:/").
copypath("go", "1:/").

print "Done".
run lko.