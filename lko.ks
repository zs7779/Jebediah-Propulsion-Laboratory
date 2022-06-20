set LKOSteers to queue().
LKOSteers:push(list(1000, R(0,0,0))).
LKOSteers:push(list(3000, R(0,10,0))).
LKOSteers:push(list(6000, R(0,20,0))).
LKOSteers:push(list(10000, R(0,30,0))).
LKOSteers:push(list(20000, R(0,45,0))).
LKOSteers:push(list(30000, R(0,60,0))).
LKOSteers:push(list(1000000, R(0,80,0))).

function getThrottle {
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

function getSteer {
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

function PILoopControlToOrbit {
    parameter PIDGains is lexicon(
        "throttle", lexicon(
            "Kp", 0.01,
            "Ki", 0.001
        ),
        "steering", lexicon(
            "Kp", 0.01,
            "Ki", 0.003
        )
    ).

    local targetSteer is LKOSteers:pop().

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
        if not LKOSteers:empty() {
            set targetSteer to LKOSteers:pop().
            set steeringVars:target to targetSteer[1].
        }
        preserve.
    }

    local t0 is time:seconds.
    until ship:APOAPSIS > 90000 {
        local dt is time:seconds - t0.
        local dThrottle to getThrottle(throttleVars, PIDGains:throttle, dt, 50).
        local dSteering to getSteer(steeringVars, PIDGains:steering, dt).

        set throttleVars:current to min(max(throttleVars:current + dThrottle:update, 0), 1).
        set throttleVars:I to dThrottle:I.
        set steeringVars:current to steeringVars:current + dSteering:update.
        set steeringVars:I to dSteering:I.
        set t0 to time:seconds.
        wait 0.001.
    }.
    lock throttle to 0.
    wait 0.5.
    print "Main engine cutoff".
    unlock steering.
    unlock throttle.
}

global LKO_PILoopControlToOrbit is PILoopControlToOrbit@.
