function img = synthetic_pattern(kind, n, phase)
% SHINE_color test helper: deterministic n x n uint8 test pattern used to
% build image/channel sets with genuinely different means, SDs,
% histograms, and spatial-frequency / Fourier-amplitude content -- needed
% so combined-mode and multi-iteration regression tests have real
% discriminating power (a single near-constant image would make several
% SHINE operations near-identity transforms and could mask a chaining
% bug). No randomness is used anywhere, so results are exactly
% reproducible across runs and across MATLAB/Octave.
if nargin < 2
    n = 64;
end
if nargin < 3
    phase = 0;
end
[X, Y] = meshgrid(0:n-1, 0:n-1);
switch kind
    case 'gradient' % smooth, low spatial frequency, wide/flat histogram
        img = uint8(round(255 * mod((X + phase) / (n-1), 1)));
    case 'checker' % high spatial frequency, sharply bimodal histogram
        blockSize = 4;
        checker = mod(floor((X+phase)/blockSize) + floor(Y/blockSize), 2);
        img = uint8(40 + checker * 180); % values in {40, 220}
    case 'sinusoid' % mid-band spatial frequency, roughly smooth histogram
        pattern = sin(2*pi*(X+phase)/8) + cos(2*pi*Y/13);
        pattern = (pattern - min(pattern(:))) / (max(pattern(:)) - min(pattern(:)));
        img = uint8(round(60 + pattern * 140));
    otherwise
        error('synthetic_pattern: unknown kind "%s"', kind);
end
end
