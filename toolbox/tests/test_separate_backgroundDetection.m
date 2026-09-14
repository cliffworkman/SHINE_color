function test_separate_backgroundDetection()
% Regression test for Bug F: toolbox/separate.m's automatic background
% detection must find the MODAL (most frequent) intensity in the image,
% not always return the top-left corner pixel's value
% (image(find(max(imhist(image)))) always reduces to image(1)).

n = 32;

% Case 1: flat majority value (200), with a deliberately different corner
% pixel (10) so the old bug (which returns the corner pixel) is caught.
img1 = uint8(200 * ones(n));
img1(1,1) = 10;
[~, ~, background1] = separate(img1);
assert(background1 == 200, ...
    sprintf('expected modal background 200, got %d (old bug returns the corner pixel value)', background1));

% Case 2: a different construction -- majority value 50 occupies most of
% the image, a minority region (value 90) includes the corner pixel, so
% the corner is NOT the mode here either. Confirms case 1 wasn't a
% coincidence of its particular layout.
img2 = uint8(50 * ones(n));
img2(1:10, :) = 90; % minority region (10*32 = 320 px) includes the corner
[~, ~, background2] = separate(img2);
assert(background2 == 50, sprintf('expected modal background 50, got %d', background2));

disp('PASS: test_separate_backgroundDetection');
end
