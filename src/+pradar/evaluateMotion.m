function [rangeM, radial, speed, x, projection] = evaluateMotion(timeSec, model, d)
%EVALUATEMOTION Straight-line motion in a centered time coordinate.
% model.x0 and model.v0 refer to model.timeOrigin, NOT closest approach.
    tau = double(timeSec) - model.timeOrigin;
    x = model.x0 + model.v0 .* tau + 0.5 * model.acceleration .* tau.^2;
    speed = model.v0 + model.acceleration .* tau;
    rangeM = hypot(d, x);
    projection = x ./ rangeM;
    projection(rangeM == 0) = NaN; % radar/target co-location is undefined
    radial = projection .* speed;
end
