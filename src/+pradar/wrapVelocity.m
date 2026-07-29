function wrappedVelocity = wrapVelocity(velocity, vMax)
%WRAPVELOCITY Fold velocity into the interval [-vMax, vMax).

    period = 2 * vMax;
    wrappedVelocity = mod(velocity + vMax, period) - vMax;
end
