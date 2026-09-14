function run_tests()
% SHINE_color regression test runner.
%
% Adds the toolbox and this tests/helpers folder to the path and runs
% each test_*.m function listed below, reporting a pass/fail summary.
% Written as plain script-style assertions (no matlab.unittest.TestCase)
% so the same suite runs unmodified under both MATLAB
% (matlab -batch "run_tests") and GNU Octave (octave --eval "run_tests"),
% since matlab.unittest is not available in Octave.
thisdir = fileparts(mfilename('fullpath'));
toolboxdir = fileparts(thisdir);
addpath(toolboxdir);
addpath(fullfile(thisdir, 'helpers'));

is_octave = (exist('OCTAVE_VERSION', 'builtin') ~= 0);
if is_octave
    pkg load image
    % SHINE_color.m calls datetime() for its Command Window log header.
    % Base Octave doesn't ship datetime (it's in the separate 'datatypes'
    % package); this is a test-environment accommodation only, not a
    % change to the toolbox itself -- see the repair report's Octave
    % compatibility notes.
    try
        pkg load datatypes
    catch
        warning('run_tests:NoDatatypes', ...
            'Octave "datatypes" package unavailable; SHINE_color.m''s datetime() call will fail.');
    end
end

tests = {
    'test_processImage_modeOrdering'
    'test_separate_backgroundDetection'
    'test_userWizard_capturesIterations'
    'test_SHINE_iterationChaining'
    'test_SHINE_color_returnsTransformedImages'
    'test_SHINE_color_diagnosticScale'
};

npass = 0;
nfail = 0;
for i = 1:numel(tests)
    name = tests{i};
    try
        feval(name);
        npass = npass + 1;
    catch err
        nfail = nfail + 1;
        fprintf(2, 'FAIL: %s\n  %s\n', name, err.message);
    end
end

fprintf('\n%d passed, %d failed (of %d)\n', npass, nfail, numel(tests));
if nfail > 0
    error('SHINE_test:Failures', '%d test(s) failed', nfail);
end
end
