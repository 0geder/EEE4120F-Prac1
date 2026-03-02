function mandelbrot_plot(image_data, width, height, filename)
% MANDELBROT_PLOT Plots and saves a Mandelbrot set image.
%
% Inputs:
%   image_data - 2D matrix of iteration counts (height x width)
%   width      - Image width in pixels
%   height     - Image height in pixels
%   filename   - Output filename (e.g., 'mandelbrot_HD.png')

    fig = figure('Visible', 'off', 'Position', [0, 0, width, height]);
    
    imagesc(image_data);
    colormap(hot);
    colorbar;
    axis image off;
    title(sprintf('Mandelbrot Set (%d x %d)', width, height), ...
        'FontSize', 12, 'Color', 'white');
    set(gca, 'Color', 'black');
    set(fig, 'Color', 'black');
    
    % Save to file
    saveas(fig, filename);
    close(fig);
    
    fprintf('Saved image: %s\n', filename);
end
