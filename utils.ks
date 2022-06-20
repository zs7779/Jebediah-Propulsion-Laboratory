function stagingToOrbit {
    wait until stage:ready.
    print "Ignition".
    stage.
    wait 0.1.

    local throttleControl to 0.
    lock throttle to throttleControl.
    until throttleControl >= 1 {
        set throttleControl to throttleControl + 0.02.
        wait 0.01.
    }
    wait until stage:ready.
    print "Launch".
    stage.
    wait 0.1.

    when ship:stagedeltav(ship:stagenum):duration = 0 then {
        wait until stage:ready.
        print "Stage separation".
        stage.
        wait 0.1.
        preserve.
    }.
}

function circularizeOrbit {
    print "Orbit insertion".
    local throttleControl to 0.
    lock throttle to throttleControl.
    
    // calculate manuver
    local manuverNode to node(timespan(ship:orbit:ETA:apoapsis), 0, 0, 30).
    add manuverNode.
    until manuverNode:orbit:periapsis > 0.95 * manuverNode:orbit:apoapsis {
        set manuverNode:prograde to manuverNode:prograde + 0.5.
    }
    local maxAcceleration to ship:maxthrust/ship:mass.
    local burnDuration to manuverNode:deltav:mag/maxAcceleration.

    print "ETA: " + round(manuverNode:eta, 1) + "s".
    print "Delta v: " + round(manuverNode:deltav:mag, 1) + "m/s".
    print "Duration: " + round(burnDuration, 1) + "s".

    lock steering to manuverNode:deltav.
    wait until vectorAngle(manuverNode:deltav, ship:facing:vector) < 0.25.

    if manuverNode:eta - 10 > burnDuration/2 {
        set kuniverse:timewarp:mode to "PHYSICS".
        set kuniverse:timewarp:rate to 3.
        wait until manuverNode:eta - 5 <= (burnDuration/2).
        kuniverse:timeWarp:cancelwarp().
    }

    wait until manuverNode:eta <= (burnDuration/2).

    print "Burn begin".
    local done to False.
    //initial deltav
    local dv0 to manuverNode:deltav.
    until done
    {
        //recalculate current max_acceleration, as it changes while we burn through fuel
        set maxAcceleration to ship:maxthrust/ship:mass.

        //throttle is 100% until there is less than 1 second of time left to burn
        //when there is less than 1 second - decrease the throttle linearly
        set throttleControl to min(manuverNode:deltav:mag/maxAcceleration*0.5, 1).

        //here's the tricky part, we need to cut the throttle as soon as our manuverNode:deltav and initial deltav start facing opposite directions
        //this check is done via checking the dot product of those 2 vectors
        if manuverNode:deltav:mag < 0.1 or vDot(dv0, manuverNode:deltav) < 0
        {
            lock throttle to 0.
            set done to True.
        }
    }
    print "Orbit reached".
    unlock steering.
    unlock throttle.
    wait 0.5.

    remove manuverNode.
}

function releaseControlToPilot {
    lock throttle to 0.
    wait 0.5.
    unlock steering.
    unlock throttle.
    set ship:CONTROL:PILOTMAINTHROTTLE to 0.
}

global Util_stagingToOrbit is stagingToOrbit@.
global Util_circularizeOrbit is circularizeOrbit@.
global Util_releaseControlToPilot is releaseControlToPilot@.

// function drawDebug {
//     set a1 TO VECDRAW(
//         V(5,-1,0),
//         (heading(90, 90, -90) * steeringVars:current):forevector,
//         RGBA(1, 0, 1, 1),
//         "current",
//         1.0, TRUE, 0.2, TRUE, TRUE
//     ).
//     set a2 TO VECDRAW(
//         V(7,1,0),
//         (heading(90, 90, -90) * steeringVars:target):forevector,
//         RGBA(1, 1, 0, 1),
//         "target",
//         1.0, TRUE, 0.2, TRUE, TRUE
//     ).
// }
