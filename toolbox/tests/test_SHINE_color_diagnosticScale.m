function test_SHINE_color_diagnosticScale()
% Regression test for the Bug E scale-mismatch fix: RMSE/SSIM must be
% computed while the original and modified luminance/value channel are
% BOTH still in SHINE's internal 0-255 representation, not after one side
% has already been rescaled to HSV's native 0-1 (or CIELab's native
% 0-100) range.
%
% Rather than asserting only that the reported values are "sane", this
% builds an independent reference computation (bypassing SHINE_color
% entirely) that reproduces both the CORRECT (same-scale) and the
% historically-buggy (mismatched-scale) RMSE/SSIM, confirms the two
% differ enough to be a meaningful test, then captures SHINE_color's own
% printed diagnostics via evalc (no public API change) and checks they
% land clearly closer to the correct value than to the buggy one.
%
% Note on determinism: mode 8 ends in histMatch, and toolbox/match.m
% deliberately reseeds rand() from the system clock to break histogram-
% matching ties (see test_processImage_modeOrdering.m), so SHINE_color's
% own internal computation and this test's independent reference are two
% SEPARATE draws and will not agree to tight numerical precision even
% when both are correct -- hence the "closer to correct than to buggy"
% relative comparison below rather than a tight absolute tolerance. The
% scale-mismatch bug this test targets is a large, order-of-magnitude
% error (comparing 0-255 against a 0-1 or 0-100 range), which remains
% clearly distinguishable from ordinary run-to-run tie-breaking noise.

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, 'helpers'));

check_scale_for_colorspace(1, 'hsv');    % HSV: native range 0-1
check_scale_for_colorspace(2, 'cielab'); % CIELab: native range 0-100

disp('PASS: test_SHINE_color_diagnosticScale');
end

function check_scale_for_colorspace(cs, label)
origdir = pwd();
testroot = setup_shine_folders();
cleanupDir = onCleanup(@() cd(origdir)); %#ok<NASGU>
cd(testroot);

input_folder = fullfile(testroot, 'SHINE_color_INPUT');
write_synthetic_rgb_pngs(input_folder, 64);

mode = 8; wholeIm = 1; optim = 0; rescaling = 1; % SHINE_color's own hardcoded defaults

% --- Independent reference computation, deriving the SAME channel
% SHINE_color operates on internally, and running the SAME processImage
% transformation, then computing RMSE/SSIM two ways.
[channel1, channel2, channel3] = readImages(input_folder, 'png', cs, 0);
if cs == 1
    orig_chan = channel3; % HSV: SHINE_color operates on the V channel
else
    orig_chan = channel1; % CIELab: SHINE_color operates on the L channel
end
mod_chan = processImage(orig_chan, mode, wholeIm, [], [], optim, rescaling);

correct_rmse = getRMSE(orig_chan{1}, mod_chan{1}); % both still 0-255 -- correct
correct_ssim = ssim_index(orig_chan{1}, mod_chan{1});

mismatched_mod = scale2lum(mod_chan{1}, cs); % converted to native range
buggy_rmse = getRMSE(orig_chan{1}, mismatched_mod); % 0-255 vs native -- the historical bug
buggy_ssim = ssim_index(orig_chan{1}, mismatched_mod);

% Fixture discriminating-power check.
assert(abs(correct_rmse - buggy_rmse) > 1, ...
    sprintf('[%s] fixture has no discriminating power: correctly- and incorrectly-scaled RMSE are nearly equal (%.4f vs %.4f)', ...
    label, correct_rmse, buggy_rmse));

% --- Drive the real SHINE_color() (plain command-line call, no wizard
% needed -- cs/im_vid/plots are genuine arguments) and capture its
% printed RMSE/SSIM via evalc, since they are never returned/written to
% a file, only printed -- evalc does not change SHINE_color's public API.
output_folder = fullfile(testroot, 'SHINE_color_OUTPUT');
log = evalc('SHINE_color(input_folder, output_folder, ''png'', cs, 0, 2);');

reported_rmse = parse_diagnostic(log, 'RMSE:');
reported_ssim = parse_diagnostic(log, 'SSIM:');

assert(~isempty(reported_rmse), sprintf('[%s] could not find a printed RMSE value in SHINE_color''s output', label));
assert(abs(reported_rmse - correct_rmse) < abs(reported_rmse - buggy_rmse), ...
    sprintf('[%s] SHINE_color reported RMSE %.4f, closer to the historically mismatched-scale value %.4f than to a correctly-scaled reference %.4f -- scale regression', ...
    label, reported_rmse, buggy_rmse, correct_rmse));

assert(~isempty(reported_ssim), sprintf('[%s] could not find a printed SSIM value in SHINE_color''s output', label));
assert(abs(reported_ssim - correct_ssim) < abs(reported_ssim - buggy_ssim), ...
    sprintf('[%s] SHINE_color reported SSIM %.4f, closer to the historically mismatched-scale value %.4f than to a correctly-scaled reference %.4f -- scale regression', ...
    label, reported_ssim, buggy_ssim, correct_ssim));
end

function val = parse_diagnostic(log, marker)
tok = regexp(log, [marker '\s*([-\d.eE+]+)'], 'tokens', 'once');
if isempty(tok)
    val = [];
else
    val = str2double(tok{1});
end
end
