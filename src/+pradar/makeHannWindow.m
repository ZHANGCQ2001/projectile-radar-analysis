function window = makeHannWindow(lengthValue)
%MAKEHANNWINDOW Generate a symmetric Hann window without toolbox dependency.

    if lengthValue == 1
        window = 1;
        return;
    end

    index = (0:lengthValue - 1).';
    window = 0.5 - 0.5 * cos(2 * pi * index / (lengthValue - 1));
end
