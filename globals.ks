global LKOSteers is queue().
LKOSteers:push(list(1000, R(0,0,0))).
LKOSteers:push(list(3000, R(0,10,0))).
LKOSteers:push(list(6000, R(0,20,0))).
LKOSteers:push(list(10000, R(0,30,0))).
LKOSteers:push(list(20000, R(0,45,0))).
LKOSteers:push(list(30000, R(0,60,0))).
LKOSteers:push(list(1000000, R(0,80,0))).

function getThrottleToOrbit {
    parameter vars, gains, dt, maxQ is 50.

    local KPaQ is ship:Q * constant:AtmToKPa.
    local minThrust is 2.0 * constant:g0 * ship:mass / ship:maxthrust.
    local thrustGain is min(KPaQ / maxQ, 1).
    local thrustTarget is thrustGain * minThrust + (1 - thrustGain) * vars:target.

    local P is thrustTarget - vars:current.
    local I is vars:I + P * dt.
    return lexicon(
        "I", I,
        "update", gains:Kp * P + gains:Ki * I
    ).
}

function getSteerToOrbit {
    parameter vars, gains, dt.
    
    local P is vars:target - vars:current.
    local I is vars:I + R(
        P:pitch * dt,
        P:yaw * dt,
        P:roll * dt
    ).
    return lexicon(
        "I", I,
        "update", R(
            gains:Kp * P:pitch,
            gains:Kp * P:yaw,
            gains:Kp * P:roll
        )
         + R(
            gains:Ki * I:pitch,
            gains:Ki * I:yaw,
            gains:Ki * I:roll
        )
    ).
}

function stagingToOrbit {
    wait until stage:ready.
    print "Ignition".
    stage.

    local throttleControl to 0.
    lock throttle to throttleControl.
    until throttleControl >= 1 {
        set throttleControl to throttleControl + 0.01.
        wait 0.01.
    }
    wait until stage:ready.
    print "Launch".
    stage.

    when ship:stagedeltav(ship:stagenum):duration = 0 then {
        wait until stage:ready.
        print "Stage separation".
        stage.
        preserve.
    }.
}

function PILoopControlToOrbit {
    parameter steers, PIDGains is lexicon(
        "throttle", lexicon(
            "Kp", 0.01,
            "Ki", 0.001
        ),
        "steering", lexicon(
            "Kp", 0.01,
            "Ki", 0.003
        )
    ).

    local targetSteer is steers:pop().

    local throttleVars is lexicon(
        "target", 1.0,
        "current", 1.0,
        "I", 0.0
    ).
    local steeringVars is lexicon(
        "target", targetSteer[1],
        "current", targetSteer[1],
        "I", R(0, 0, 0)
    ).

    lock throttle to throttleVars:current.
    lock steering to heading(90, 90, -90) * steeringVars:current.

    when ship:altitude > targetSteer[0] then {
        if not steers:empty() {
            set targetSteer to steers:pop().
            set steeringVars:target to targetSteer[1].
        }
        preserve.
    }

    local t0 is time:seconds.
    until ship:APOAPSIS > 90000 {
        local dt is time:seconds - t0.
        local dThrottle to getThrottleToOrbit(throttleVars, PIDGains:throttle, dt, 50).
        local dSteering to getSteerToOrbit(steeringVars, PIDGains:steering, dt).

        set throttleVars:current to min(max(throttleVars:current + dThrottle:update, 0), 1).
        set throttleVars:I to dThrottle:I.
        set steeringVars:current to steeringVars:current + dSteering:update.
        set steeringVars:I to dSteering:I.
        set t0 to time:seconds.
        wait 0.001.
    }.
    print "Main engine cutoff".
    unlock steering.
    unlock throttle.
}

function circularizeOrbit {
    print "Orbit insertion".
    local manuverNode to node(timespan(ship:orbit:ETA:apoapsis), 0, 0, 30).
    add manuverNode.
    until manuverNode:orbit:periapsis > 0.9 * manuverNode:orbit:apoapsis {
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
    local throttleControl to 0.
    lock throttle to throttleControl.
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
    wait 1.

    remove manuverNode.
}

global PILoopControlToOrbit is PILoopControlToOrbit@.
global stagingToOrbit is stagingToOrbit@.
global circularizeOrbit is circularizeOrbit@.

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
