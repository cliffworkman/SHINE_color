function imnames = write_synthetic_rgb_pngs(folder, n)
% SHINE_color test helper: writes 3 deterministic same-sized truecolor RGB
% PNGs into `folder`. R/G/B channels are assigned gradient/checker/
% sinusoid patterns in a rotating (Latin-square) arrangement so that
% EVERY channel's 3-image set (not just the images as a whole) has strong
% mean/SD/histogram/spatial-frequency diversity, regardless of which
% colorspace/channel SHINE_color ends up processing.
if nargin < 2
    n = 64;
end
kinds = {'gradient','checker','sinusoid'};
imnames = cell(3,1);
for k = 1:3
    order = circshift(kinds, [0, 1-k]); % rotate assignment per image
    r = synthetic_pattern(order{1}, n, 0);
    g = synthetic_pattern(order{2}, n, 3);
    b = synthetic_pattern(order{3}, n, 6);
    rgb = cat(3, r, g, b);
    imnames{k} = sprintf('synth_%d.png', k);
    imwrite(rgb, fullfile(folder, imnames{k}));
end
end
