
clear;
clc;

inputFile = 'F:\AWR2243\数据\am273x_20260725_123207_Raw_0.bin';
outputFile = 'F:\AWR2243\数据\123207_frames_126_135.bin';

numSamples = 64;
numChirps = 256;
numRx = 8;

% I/Q各一个int16，因此每个复采样点4字节
bytesPerFrame = numSamples * numChirps * numRx * 2 * 2;

frameStart = 126;
frameEnd = 135;

fidIn = fopen(inputFile, 'rb');
assert(fidIn >= 0, '无法打开输入文件');

fidOut = fopen(outputFile, 'wb');
assert(fidOut >= 0, '无法创建输出文件');

cleanupObj = onCleanup(@() closeFiles(fidIn, fidOut));

offset = (frameStart - 1) * bytesPerFrame;
fseek(fidIn, offset, 'bof');

numFrames = frameEnd - frameStart + 1;
numBytes = numFrames * bytesPerFrame;

data = fread(fidIn, numBytes, 'uint8=>uint8');
fwrite(fidOut, data, 'uint8');

fprintf('已提取物理帧 %d-%d\n', frameStart, frameEnd);
fprintf('输出大小：%.2f MB\n', numel(data) / 1024^2);

function closeFiles(fidIn, fidOut)
    if fidIn >= 0
        fclose(fidIn);
    end
    if fidOut >= 0
        fclose(fidOut);
    end
end