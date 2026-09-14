function test_SHINE_color_returnsTransformedImages()
% Regression test for Bug D: a captured return value
% (`out = SHINE_color(...)`) must contain the actual transformed images --
% matching what script mode writes to disk -- not empty cells, and the
% disk write must stay opt-in (skipped when the caller captures a return
% value), unchanged from the original script-mode behavior.
%
% cs=3 (RGB) is used deliberately: RGB reconstruction is a direct
% cat(3, ...) of the modified channels with no HSV/CIELab rescale step, so
% this isolates Bug D's control-flow fix from Bug E's scale fix (covered
% separately by test_SHINE_color_diagnosticScale.m). No wizard/mocked
% input is needed here since cs/im_vid/plots are genuine command-line
% arguments of SHINE_color(inputpath,outputpath,extension,cs,im_vid,plots).
%
% Note on determinism: the default command-line mode is 8 (specMatch then
% histMatch), and toolbox/match.m (used internally by histMatch)
% deliberately reseeds rand() from the system clock to break histogram-
% matching ties (see test_processImage_modeOrdering.m) -- so the captured
% run (nargout==1) and the script-mode run (nargout==0) are two SEPARATE
% invocations and will not be pixel-identical even though both are
% correct. "Agreement" is therefore verified via each image's resulting
% per-channel HISTOGRAM against a deterministic reference (histMatch's
% resulting histogram is exactly reproducible given the same input set,
% verified empirically), not via raw pixel equality.

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, 'helpers'));

origdir = pwd();
testroot = setup_shine_folders();
cleanupDir = onCleanup(@() cd(origdir)); %#ok<NASGU>
cd(testroot);

input_folder = fullfile(testroot, 'SHINE_color_INPUT');
write_synthetic_rgb_pngs(input_folder, 64);

output_written  = fullfile(testroot, 'out_written');
output_captured = fullfile(testroot, 'out_captured');
mkdir(output_written);
mkdir(output_captured);

rescaling = 1; optim = 0; wholeIm = 1; mode = 8; % SHINE_color's own hardcoded command-line defaults

% Deterministic per-channel reference histogram (what the final histMatch
% stage of mode 8 must reach for each RGB channel), independent of either
% SHINE_color run below.
[channel1, channel2, channel3] = readImages(input_folder, 'png', 3, 0);
channels_orig = {channel1, channel2, channel3};
ref = cell(1,3);
for c = 1:3
    ref{c} = histMatch(specMatch(channels_orig{c}, rescaling), optim);
end

SHINE_color(input_folder, output_written, 'png', 3, 0, 2); % nargout==0: script mode, writes files
out = SHINE_color(input_folder, output_captured, 'png', 3, 0, 2); % nargout==1: captures images

writtenWhenCaptured = dir(fullfile(output_captured, '*.png'));
assert(isempty(writtenWhenCaptured), ...
    'SHINE_color wrote output files even though its return value was captured (nargout>=1) -- disk write should stay opt-in');

assert(iscell(out) && numel(out) == 3, 'expected 3 returned images');

rawFiles = dir(fullfile(input_folder, '*.png'));
rawFiles = sort({rawFiles.name});

for k = 1:numel(out)
    img = out{k};
    assert(~isempty(img), sprintf('out{%d} is empty', k));
    assert(isequal(size(img), [64 64 3]), sprintf('out{%d} has unexpected size', k));

    raw = imread(fullfile(input_folder, rawFiles{k}));
    assert(~isequal(img, raw), ...
        sprintf('out{%d} is pixel-identical to the raw input -- no transformation occurred', k));

    written = imread(fullfile(output_written, sprintf('SHINE_color_rgb_%d.png', k)));
    assert(isequal(size(written), [64 64 3]), sprintf('script-mode output %d has unexpected size', k));

    for c = 1:3
        ref_hist = double(imhist(ref{c}{k}));
        assert(isequal(double(imhist(img(:,:,c))), ref_hist), ...
            sprintf('out{%d} channel %d: histogram does not match the deterministic mode-8 reconstruction target', k, c));
        assert(isequal(double(imhist(written(:,:,c))), ref_hist), ...
            sprintf('script-mode output %d channel %d: histogram does not match the deterministic mode-8 reconstruction target', k, c));
    end
end

disp('PASS: test_SHINE_color_returnsTransformedImages');
end
