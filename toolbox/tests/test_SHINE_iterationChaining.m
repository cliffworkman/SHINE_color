function test_SHINE_iterationChaining()
% Regression test for Bug C: SHINE_color.m's outer `for iteration = 1:it`
% loop must feed iteration N-1's result into iteration N, not recompute
% from the pristine original channels every time.
%
% Per design: this test does NOT require iteration 2 to be "better" than
% iteration 1 by any metric (the published algorithm gives no such
% monotonic-improvement guarantee) -- it tests the control-flow property
% directly: which of two candidate reference computations the real
% SHINE_color(it=2) run's output is actually closer to.
%
% Note on determinism: every combined mode (5-8) includes exactly one
% histMatch stage per processImage() call, and toolbox/match.m
% (histMatch's internal exact-histogram-specification engine)
% deliberately reseeds rand() from the system clock to break ties -- a
% legitimate SHINE toolbox algorithm design choice, not a bug (see
% test_processImage_modeOrdering.m). With it=2, that randomized step is
% exercised twice in sequence (once per iteration), so unlike a single
% processImage() call, no exact/histogram-level invariant survives across
% both rounds intact -- this test therefore uses the same relative-
% distance comparison as test_processImage_modeOrdering.m's modes 5/6:
% the real result must be substantially CLOSER (RMSE) to a freshly-drawn
% "correctly chained" reference than to a freshly-drawn "buggy reprocess
% the original" reference.

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, 'helpers'));

origdir = pwd();
testroot = setup_shine_folders();
cleanupDir = onCleanup(@() cd(origdir)); %#ok<NASGU>
cd(testroot);

input_folder = fullfile(testroot, 'SHINE_color_INPUT');
write_synthetic_rgb_pngs(input_folder, 64);

% mode 7 (sfMatch then histMatch) is used rather than the toolbox default
% (mode 8) because it empirically gives a much larger, more reliable
% separation between the "chained" and "buggy" references for this
% fixture (verified: RMSE ~68-71 across repeated draws for mode 7, vs
% ~2-4 for mode 8) -- the iteration-chaining code path under test in
% SHINE_color.m is identical regardless of which combined mode runs
% inside processImage, so this does not weaken what the test covers.
mode = 7; wholeIm = 1; optim = 0; rescaling = 1; % must match the wizard sequence below

[channel1, channel2, channel3] = readImages(input_folder, 'png', 3, 0);
channels_orig = {channel1, channel2, channel3};

% Iteration 1, a fresh reference draw (both candidate iteration-2
% references below start from SOME iteration-1 result; only whether that
% iteration-1 result was itself used, versus the original channels being
% reprocessed, is under test).
iter1 = cell(1,3);
for c = 1:3
    iter1{c} = processImage(channels_orig{c}, mode, wholeIm, [], [], optim, rescaling);
end

% CORRECT (fixed) reference: iteration 2 consumes iteration 1's output.
% BUGGY (old) reference: iteration 2 recomputes from the original
% channels again, since the old code never fed iteration 1's result
% forward (Bug C).
expected_chained = cell(1,3);
expected_buggy   = cell(1,3);
for c = 1:3
    expected_chained{c} = processImage(iter1{c}, mode, wholeIm, [], [], optim, rescaling);
    expected_buggy{c}   = processImage(channels_orig{c}, mode, wholeIm, [], [], optim, rescaling);
end

d_fixture = mean_rmse_1(expected_chained, expected_buggy);
assert(d_fixture > 5, ...
    sprintf('fixture has no discriminating power: chained and reprocessed-original references are nearly identical (RMSE=%.3f)', d_fixture));

% --- Drive the real SHINE_color() through the wizard with it=2. cs=3
% (RGB) means the returned reconstruction is a direct cat(3,...) of the
% modified channels with no HSV/CIELab rescale step.
mockdir = fullfile(thisdir, 'mocks');
addpath(mockdir);
cleanupMock = onCleanup(@() rmpath(mockdir)); %#ok<NASGU>

global SHINE_TEST_INPUT_QUEUE
% im_vid=1; imformat='png'; cs=3(RGB); y_n_plot=2(no); options=2(custom);
% matching=3(both); both-option=3(sf&hist -> mode 7); optim-choice=1
% (-> optim=0, no SSIM optimization); it=2 <-- value under test
SHINE_TEST_INPUT_QUEUE = {1, 'png', 3, 2, 2, 3, 3, 1, 2};

out = SHINE_color();
actual = out{1}; % first image; 3rd dim = R,G,B = channel1,channel2,channel3
actual_channels = {actual(:,:,1), actual(:,:,2), actual(:,:,3)};

d_actual_chained = mean_rmse_first(actual_channels, expected_chained);
d_actual_buggy   = mean_rmse_first(actual_channels, expected_buggy);

assert(d_actual_chained < d_actual_buggy, ...
    sprintf(['SHINE_color(it=2) result is not closer to a correctly-chained reference than to the OLD BUGGY ' ...
    '"reprocess original" reference (RMSE to chained=%.3f, RMSE to buggy=%.3f) -- iteration-chaining regression'], ...
    d_actual_chained, d_actual_buggy));

disp('PASS: test_SHINE_iterationChaining');
end

function d = mean_rmse_1(cellA, cellB)
% cellA{c}, cellB{c} are each themselves image-set cells; compares each
% channel's FIRST image only (matches actual, which is a single image).
n = numel(cellA);
vals = zeros(n,1);
for c = 1:n
    diffs = double(cellA{c}{1}(:)) - double(cellB{c}{1}(:));
    vals(c) = sqrt(mean(diffs.^2));
end
d = mean(vals);
end

function d = mean_rmse_first(actual_channels, expected)
n = numel(actual_channels);
vals = zeros(n,1);
for c = 1:n
    diffs = double(actual_channels{c}(:)) - double(expected{c}{1}(:));
    vals(c) = sqrt(mean(diffs.^2));
end
d = mean(vals);
end
