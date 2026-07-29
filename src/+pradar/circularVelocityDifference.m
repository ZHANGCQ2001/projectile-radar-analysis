function difference = circularVelocityDifference(velocity1, velocity2, period)
%CIRCULARVELOCITYDIFFERENCE Return shortest distance on a periodic axis.

    directDifference = abs(velocity1 - velocity2);
    difference = min(directDifference, period - directDifference);
end
