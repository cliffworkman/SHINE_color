function root = setup_shine_folders()
% SHINE_color test helper: creates a fresh temp working directory with the
% SHINE_color_INPUT / SHINE_color_OUTPUT / SHINE_color_OUTPUT/DIAGNOSTICS /
% SHINE_color_TEMPLATE folder layout that userWizard.m (pwd-relative
% paths), SHINE_color.m's diary log, and lumCalc.m all expect to already
% exist. Returns the new root; the caller is responsible for cd'ing into
% it (and cd'ing back afterward, e.g. via onCleanup).
root = tempname();
mkdir(root);
mkdir(fullfile(root, 'SHINE_color_INPUT'));
mkdir(fullfile(root, 'SHINE_color_OUTPUT'));
mkdir(fullfile(root, 'SHINE_color_OUTPUT', 'DIAGNOSTICS'));
mkdir(fullfile(root, 'SHINE_color_TEMPLATE'));
end
