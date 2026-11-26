function value = huberLoss(residual, delta)
%HUBERLOSS Twice the conventional Huber loss; quadratic below delta.
    a = abs(residual);
    value = a.^2;
    outside = a > delta;
    value(outside) = 2*delta*a(outside)-delta^2;
end
