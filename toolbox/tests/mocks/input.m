function out = input(prompt, varargin)
% SHINE_color test mock: shadows the built-in input() so userWizard.m's
% interactive prompts can be driven from an automated test via a canned
% response queue (global SHINE_TEST_INPUT_QUEUE), instead of blocking on
% real console input. This file must be named exactly "input.m" so its
% folder, once added to the path, shadows the built-in for the duration
% of a wizard-driven test -- see the addpath/onCleanup pattern in the
% tests that use it. The optional second arg ('s', string-mode) is
% accepted for signature compatibility but ignored: the queue entry is
% returned as-is regardless of type.
global SHINE_TEST_INPUT_QUEUE
if isempty(SHINE_TEST_INPUT_QUEUE)
    error('SHINE_test:InputQueueExhausted', ...
        'mock input() queue exhausted at prompt: %s', prompt);
end
out = SHINE_TEST_INPUT_QUEUE{1};
SHINE_TEST_INPUT_QUEUE(1) = [];
end
