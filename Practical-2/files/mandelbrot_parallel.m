function [image_data, elapsed_time] = mandelbrot_parallel(width, height, max_iterations, num_workers)
% MANDELBROT_PARALLEL Computes the Mandelbrot set using a parfor parallel loop.
%
% Inputs:
%   width          - Image width in pixels
%   height         - Image height in pixels
%   max_iterations - Maximum number of iterations
%   num_workers    - Number of parallel workers to use
%
% Outputs:
%   image_data     - 2D matrix (height x width) of iteration counts
%   elapsed_time   - Computation time in seconds (excludes pool startup)

    % Define the coordinate space (broadcast variables - read-only)
    x_min = -2.0; x_max = 0.5;
    y_min = -1.2; y_max = 1.2;

    % Pre-compute coordinate vectors to broadcast (scalars/small vectors preferred)
    x_coords = linspace(x_min, x_max, width);
    y_coords = linspace(y_min, y_max, height);

    % Pre-allocate output (sliced variable)
    image_data = zeros(height, width);

    % Ensure a parallel pool exists with the requested number of workers
    poolobj = gcp('nocreate');
    if isempty(poolobj) || poolobj.NumWorkers ~= num_workers
        if ~isempty(poolobj)
            delete(poolobj);
        end
        parpool('local', num_workers);
    end

    % ---- Timed section: exclude pool startup ----
    tic;

    % Parallelise the outer (row) loop.
    % x_coords and y_coords are broadcast (read-only).
    % image_data rows are sliced: each worker writes to its own rows.
    parfor row = 1:height
        y0 = y_coords(row);
        row_data = zeros(1, width);  % temporary variable (local to worker)

        for col = 1:width
            x0 = x_coords(col);

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

            row_data(col) = iteration;
        end

        image_data(row, :) = row_data;  % sliced write
    end

    elapsed_time = toc;
    % ---- End timed section ----

    fprintf('[Parallel | %d workers] %dx%d => %.4f seconds\n', ...
        num_workers, width, height, elapsed_time);
end
