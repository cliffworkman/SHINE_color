function test_userWizard_capturesIterations()
% Regression test for Bug B: the wizard-entered iteration count must be
% returned by userWizard.m (its new 13th output, `it`) and not silently
% discarded. Isolated at the userWizard level -- no image I/O needed,
% since userWizard.m never touches the filesystem itself.

thisdir = fileparts(mfilename('fullpath'));
mockdir = fullfile(thisdir, 'mocks');
addpath(mockdir);
cleanupObj = onCleanup(@() rmpath(mockdir)); %#ok<NASGU>

global SHINE_TEST_INPUT_QUEUE
% Sequence (im_vid=1 images branch):
%  1: Input [1=images,2=video]                     -> 1
%  2: Type the image format                        -> 'png'
%  3: Select the colorspace                        -> 3 (RGB)
%  4: Do you want diagnostic plots?                 -> 2 (no)
%  5: SHINE_color options [1=default,2=custom]      -> 2 (custom)
%  6: Matching mode [1=lum,2=sf,3=both]              -> 3 (both)
%  7: Matching of both [1..4]                        -> 4 (-> md = 4+4 = 8)
%  8: Optimize SSIM [1=no,2=yes]                      -> 1 (-> optim = 0)
%  9: # of iterations?                                -> 3   <-- value under test
% cs==3 (RGB) skips the matching-region/background prompts entirely.
SHINE_TEST_INPUT_QUEUE = {1, 'png', 3, 2, 2, 3, 4, 1, 3};

[~,~,~,cs,~,~,~,mode,~,~,optim,~,it] = userWizard(8, 300, 1, 0);

assert(it == 3, sprintf('expected it=3 to propagate from the wizard, got %s', mat2str(it)));
assert(mode == 8, sprintf('expected mode=8 (spec&hist), got %d', mode));
assert(cs == 3, sprintf('expected cs=3 (RGB), got %d', cs));
assert(optim == 0, sprintf('expected optim=0 (no SSIM optimization), got %d', optim));

disp('PASS: test_userWizard_capturesIterations');
end
