function backgroundPower = buildRdBackground(rdPowerCube)
%BUILDRDBACKGROUND Build a 2-D RD background with a window-wise median.

    backgroundPower = median(rdPowerCube, 3, 'omitnan');
end
