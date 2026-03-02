function [image_data, elapsed_time] = mandelbrot_sequential(width, height, max_iterations)
% MANDELBROT_SEQUENTIAL Computes the Mandelbrot set sequentially using nested for-loops.
%
% Inputs:
%   width          - Image width in pixels
%   height         - Image height in pixels
%   max_iterations - Maximum number of iterations before declaring a point in the set
%
% Outputs:
%   image_data     - 2D matrix (height x width) of iteration counts
%   elapsed_time   - Time taken to compute in seconds

    % Define the coordinate space
    x_min = -2.0; x_max = 0.5;
    y_min = -1.2; y_max = 1.2;

    % Map pixel indices to complex plane coordinates
    x_coords = linspace(x_min, x_max, width);
    y_coords = linspace(y_min, y_max, height);

    image_data = zeros(height, width);

    tic;  % Start timer
    
    for row = 1:height
        y0 = y_coords(row);
        for col = 1:width
            x0 = x_coords(col);

            % Mandelbrot iteration
            x = 0.0;
            y = 0.0;
            iteration = 0;

            while (iteration < max_iterations) && (x*x + y*y <= 4.0)
                x_next = x*x - y*y + x0;
                y_next = 2.0*x*y + y0;
                x = x_next;
                y = y_next;
                iteration = iteration + 1;
            end

            image_data(row, col) = iteration;
        end
    end
    
    elapsed_time = toc;  % Stop timer

    fprintf('[Sequential] %dx%d => %.4f seconds\n', width, height, elapsed_time);
end
