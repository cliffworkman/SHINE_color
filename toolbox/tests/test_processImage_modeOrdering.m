function test_processImage_modeOrdering()
% Regression test for Bug A: toolbox/processImage.m's combined modes
% (5-8) must chain op2(op1(x)), not silently discard op1's result and
% recompute op2(x) on the untouched original input.
%
% Uses a 3-image fixture of deliberately different patterns (gradient /
% checkerboard / sinusoid: see synthetic_pattern.m) rather than a single
% image, because with only one image several SHINE operations derive
% their target from the image set itself and can become near-identity
% transforms -- which would make op2(op1(x)) indistinguishable from
% op2(x) for accidental reasons and silently weaken this test.
%
% Note on determinism: toolbox/match.m (used internally by histMatch)
% deliberately reseeds MATLAB/Octave's rand() from the system clock to
% break ties in its exact histogram specification -- a legitimate SHINE
% toolbox algorithm design choice (randomized tie-breaking is a standard
% technique for exact histogram specification), not a bug, and out of
% scope to change. It means two SEPARATE calls that both go through
% histMatch will not be pixel-identical even when both are "correct".
% This test therefore avoids raw pixel equality wherever histMatch is
% involved and instead uses: (a) an exact HISTOGRAM-level invariant where
% available -- histMatch's resulting histogram is always exactly its
% target, even though the pixel arrangement that produces it is
% randomized -- or (b) a relative-distance comparison where the final
% stage is not histMatch.

channels = {
    synthetic_pattern('gradient', 64)
    synthetic_pattern('checker',  64)
    synthetic_pattern('sinusoid', 64)
};
wholeIm = 1; mask_fgr = []; mask_bgr = []; optim = 0; rescaling = 1; % deterministic (no SSIM optimization)

% --- Modes 1, 3, 4: no histMatch anywhere in these paths -- fully
% deterministic, compared pixel-exact against the direct operation.
assert(isequal(processImage(channels, 1, wholeIm, mask_fgr, mask_bgr, optim, rescaling), lumMatch(channels)), ...
    'mode 1 must equal direct lumMatch(channels)');
assert(isequal(processImage(channels, 3, wholeIm, mask_fgr, mask_bgr, optim, rescaling), sfMatch(channels, rescaling)), ...
    'mode 3 must equal direct sfMatch(channels, rescaling)');
assert(isequal(processImage(channels, 4, wholeIm, mask_fgr, mask_bgr, optim, rescaling), specMatch(channels, rescaling)), ...
    'mode 4 must equal direct specMatch(channels, rescaling)');

% --- Mode 2: histMatch alone. Two INDEPENDENT calls to histMatch on the
% SAME input set always produce the exact same resulting histogram, even
% though the pixel arrangement each produces is randomized (verified
% empirically: match.m's target list is a deterministic function of the
% input set's average histogram and image size -- comparing against that
% average histogram directly is NOT reliable, since match.m resamples it
% to match each image's exact pixel count when the two don't divide
% evenly, e.g. due to independent per-bin rounding in avgHist.m).
result2 = processImage(channels, 2, wholeIm, mask_fgr, mask_bgr, optim, rescaling);
reference2 = histMatch(channels, optim);
for i = 1:numel(channels)
    assert(isequal(double(imhist(result2{i})), double(imhist(reference2{i}))), ...
        sprintf('mode 2, image %d: resulting histogram does not match a direct histMatch(channels,optim) reference', i));
end

% --- Combined modes 7, 8 END in histMatch: use the same exact-histogram
% trick to test chaining precisely.
check_combined_mode_hist(channels, 7, @() sfMatch(channels, rescaling),   wholeIm, mask_fgr, mask_bgr, optim, rescaling);
check_combined_mode_hist(channels, 8, @() specMatch(channels, rescaling), wholeIm, mask_fgr, mask_bgr, optim, rescaling);

% --- Combined modes 5, 6 START with histMatch and END with a
% deterministic op (sfMatch/specMatch); use a relative-distance check.
check_combined_mode_dist(channels, 5, @() histMatch(channels, optim), @(x) sfMatch(x, rescaling),   wholeIm, mask_fgr, mask_bgr, optim, rescaling);
check_combined_mode_dist(channels, 6, @() histMatch(channels, optim), @(x) specMatch(x, rescaling), wholeIm, mask_fgr, mask_bgr, optim, rescaling);

disp('PASS: test_processImage_modeOrdering');
end

function check_combined_mode_hist(channels, mode, op1_fn, wholeIm, mask_fgr, mask_bgr, optim, rescaling)
% Modes 7 (sfMatch&histMatch) and 8 (specMatch&histMatch): the final
% stage's resulting histogram is a deterministic function of ITS INPUT
% set (see note above) -- correct input is op1(channels); the old-buggy
% input would have been channels itself (op1 never applied, see Bug A).
op1_result = op1_fn();
correct_reference = histMatch(op1_result, optim);
buggy_reference    = histMatch(channels, optim);

discriminates = false;
for i = 1:numel(channels)
    if ~isequal(double(imhist(correct_reference{i})), double(imhist(buggy_reference{i})))
        discriminates = true;
    end
end
assert(discriminates, ...
    sprintf('fixture has no discriminating power for mode %d: histMatch(op1(channels)) and histMatch(channels) give the same histograms', mode));

actual = processImage(channels, mode, wholeIm, mask_fgr, mask_bgr, optim, rescaling);
for i = 1:numel(channels)
    actual_hist = double(imhist(actual{i}));
    assert(isequal(actual_hist, double(imhist(correct_reference{i}))), ...
        sprintf('mode %d, image %d: resulting histogram does not match op2(op1(x))''s histogram', mode, i));
    assert(~isequal(actual_hist, double(imhist(buggy_reference{i}))), ...
        sprintf('mode %d, image %d: resulting histogram matches the OLD BUGGY op2(x) histogram -- chaining regression', mode, i));
end
end

function check_combined_mode_dist(channels, mode, op1_fn, op2_of, wholeIm, mask_fgr, mask_bgr, optim, rescaling)
% Modes 5 (histMatch&sfMatch) and 6 (histMatch&specMatch): the final
% stage is deterministic, but its input (stage 1's histMatch output)
% carries match.m's randomized tie-breaking, so two independently-drawn
% "correct" references differ slightly even when both are genuinely
% correct. `actual` must still be substantially closer to a freshly-drawn
% correct reference than to the old-buggy one.
op1_result = op1_fn();
expected_correct = op2_of(op1_result); % op2(op1(x)) -- one valid draw of the intended, fixed behavior
expected_buggy    = op2_of(channels);   % op2(x)      -- old bug (op1 never applied)

d_fixture = mean_rmse(expected_correct, expected_buggy);
assert(d_fixture > 5, ...
    sprintf('fixture has no discriminating power for mode %d: op2(op1(x)) and op2(x) are nearly identical (RMSE=%.3f)', mode, d_fixture));

actual = processImage(channels, mode, wholeIm, mask_fgr, mask_bgr, optim, rescaling);
d_actual_correct = mean_rmse(actual, expected_correct);
d_actual_buggy   = mean_rmse(actual, expected_buggy);

assert(d_actual_correct < d_actual_buggy, ...
    sprintf(['mode %d: actual result is not closer to a correct op2(op1(x)) reference than to the OLD BUGGY ' ...
    'op2(x) reference (RMSE to correct=%.3f, RMSE to buggy=%.3f) -- possible chaining regression'], ...
    mode, d_actual_correct, d_actual_buggy));
end

function d = mean_rmse(cellA, cellB)
n = numel(cellA);
vals = zeros(n,1);
for i = 1:n
    diffs = double(cellA{i}(:)) - double(cellB{i}(:));
    vals(i) = sqrt(mean(diffs.^2));
end
d = mean(vals);
end
