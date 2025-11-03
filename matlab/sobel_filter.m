% sobel_filter.m
% Applies a Sobel filter to an image and saves the result.

% Read the image (change the filename if needed)
inputFile = 'example1.jpg';   % Make sure this file exists
outputFile = 'sobel.jpg';  % Output filename

% Read input image
inputImage = imread(inputFile);

% Convert color to grayscale manually (no rgb2gray)
if size(inputImage,3) == 3   % RGB image
    R = double(inputImage(:,:,1));
    G = double(inputImage(:,:,2));
    B = double(inputImage(:,:,3));
    grayImage = 0.2989 * R + 0.5870 * G + 0.1140 * B;
else                         % Already grayscale
    grayImage = double(inputImage);
end

% Apply Sobel filter manually
B = grayImage;
[m, n] = size(B);
sobelResult = zeros(m-2, n-2);

for i = 1:m-2
    for j = 1:n-2
        Gx = ((2*B(i+2,j+1) + B(i+2,j) + B(i+2,j+2)) ...
             - (2*B(i,  j+1) + B(i,  j) + B(i,  j+2)));
        Gy = ((2*B(i+1,j+2) + B(i,  j+2) + B(i+2,j+2)) ...
             - (2*B(i+1,j)   + B(i,  j) + B(i+2,j)));
        sobelResult(i,j) = sqrt(Gx.^2 + Gy.^2);
    end
end

% Normalize and convert to uint8 for saving
sobelResult = sobelResult - min(sobelResult(:));
sobelResult = sobelResult ./ max(sobelResult(:));
sobelResult = uint8(255 * sobelResult);

% Display results
figure;
imshow(uint8(grayImage));
title('Grayscale Image');

figure;
imshow(sobelResult);
title('Sobel Gradient (Edges)');

% Save the output
imwrite(sobelResult, outputFile);
disp(['✅ Sobel filter result saved as ', outputFile]);
