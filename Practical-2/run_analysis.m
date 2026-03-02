% =========================================================================
% Practical 2: Mandelbrot-Set Serial vs Parallel Analysis
% =========================================================================
%
% GROUP NUMBER: 24
%
% MEMBERS:
%   - Member 1 Nyakallo Peete, PTXNYA001
%   - Member 2 Samson Okuthe, OKTSAM001

function run_analysis()
    clc; close all;
    fprintf('Starting Mandelbrot Benchmarking Analysis...\n\n');

    % Standard testing resolutions defined in the practical
    resolutions = {
        'SVGA',    800,  600;
        'HD',     1280,  720;
        'Full_HD',1920, 1080;
        '2K',     2048, 1080;
        'QHD',    2560, 1440;
        '4K_UHD', 3840, 2160;
        '5K',     5120, 2880;
        '8K_UHD', 7680, 4320
    };
    
    num_res = size(resolutions, 1);
    max_iterations = 1000; 

    % Determine workers to test (2 up to max physical cores)
    max_cores = feature('numcores');
    % Create an array of worker counts to test (e.g., [2, 4, 8])
    if max_cores > 2
        worker_counts = unique([2, floor(max_cores/2), max_cores]);
    else
        worker_counts = 2;
    end
    num_worker_tests = length(worker_counts);

    % Pre-allocate timing arrays
    serial_times = zeros(num_res, 1);
    parallel_times = zeros(num_res, num_worker_tests);
    pixels_count = zeros(num_res, 1);

    % --- PRE-START PARALLEL POOL TO AVOID TIMING OVERHEAD ---
    fprintf('Initializing Parallel Pool up to %d workers...\n', max_cores);
    poolobj = gcp('nocreate');
    if isempty(poolobj) || poolobj.NumWorkers ~= max_cores
        delete(gcp('nocreate'));
        parpool('local', max_cores);
    end
    fprintf('Pool ready.\n\n');

    % --- BENCHMARKING LOOP ---
    for i = 1:num_res
        res_name = resolutions{i, 1};
        width = resolutions{i, 2};
        height = resolutions{i, 3};
        pixels_count(i) = width * height;
        
        fprintf('Processing %s (%dx%d) - %.2f Megapixels\n', res_name, width, height, (width*height)/1e6);
        
        % 1. Serial Execution
        tic;
        M_serial = mandelbrot_serial(width, height, max_iterations);
        serial_times(i) = toc;
        fprintf('  -> Serial Time:   %.4f s\n', serial_times(i));
        
        % Plot and save serial image (only need to save one version to satisfy Task 0)
        mandelbrot_plot(M_serial, width, height, ['Serial_', res_name]);
        
        % 2. Parallel Execution (Varying Workers)
        for w = 1:num_worker_tests
            workers = worker_counts(w);
            tic;
            M_parallel = mandelbrot_parallel(width, height, max_iterations, workers);
            parallel_times(i, w) = toc;
            
            speedup = serial_times(i) / parallel_times(i, w);
            fprintf('  -> Par Time (%dw): %.4f s (Speedup: %.2fx)\n', workers, parallel_times(i, w), speedup);
            
            % Verify correctness
            if max(abs(M_serial(:) - M_parallel(:))) > 0
                warning('Mismatch detected between Serial and Parallel outputs!');
            end
        end
        fprintf('\n');
    end

    % --- RESULTS DISPLAY & PLOTTING ---
    disp('=== FINAL BENCHMARKING RESULTS ===');
    T = table(resolutions(:,1), pixels_count, serial_times, parallel_times(:, end), ...
        serial_times ./ parallel_times(:, end), ...
        'VariableNames', {'Resolution', 'Total_Pixels', 'Serial_Time_s', sprintf('Parallel_%dw_Time', max_cores), 'Max_Speedup'});
    disp(T);

    % Plot 1: Execution Time vs Resolution
    figure('Name', 'Execution Time', 'NumberTitle', 'off');
    plot(pixels_count / 1e6, serial_times, '-ro', 'LineWidth', 2); hold on;
    colors = {'-bs', '-g^', '-md', '-kc'};
    for w = 1:num_worker_tests
        plot(pixels_count / 1e6, parallel_times(:, w), colors{mod(w-1,4)+1}, 'LineWidth', 2);
    end
    grid on; title('Execution Time vs Image Resolution');
    xlabel('Megapixels'); ylabel('Execution Time (Seconds)');
    leg_entries = {'Sequential'};
    for w = 1:num_worker_tests, leg_entries{end+1} = sprintf('Parallel (%d workers)', worker_counts(w)); end
    legend(leg_entries, 'Location', 'northwest');

    % Plot 2: Speedup vs Number of Workers (for the largest resolution)
    figure('Name', 'Amdahls Law Scaling', 'NumberTitle', 'off');
    largest_res_speedups = serial_times(end) ./ parallel_times(end, :);
    plot(worker_counts, largest_res_speedups, '-mo', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
    plot(worker_counts, worker_counts, '--k'); % Ideal linear scaling line
    grid on; title(sprintf('Speedup vs Workers (%s Resolution)', resolutions{end, 1}));
    xlabel('Number of Workers'); ylabel('Speedup Factor');
    legend('Actual Speedup', 'Ideal Linear Scaling', 'Location', 'northwest');
    
    fprintf('Benchmarking Complete! Images saved to "outputs" folder.\n');
end

%% ========================================================================
%  PART 1: Plotting Helper
%  ========================================================================
function mandelbrot_plot(M, width, height, method_name)
    out_dir = "outputs";
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end

    fig = figure('Visible','off');
    imagesc(M);
    axis image off;
    colormap(turbo); % Turbo provides great contrast for Mandelbrot sets
    colorbar;
    title(sprintf('Mandelbrot Set (%s) - %dx%d', method_name, width, height), 'Interpreter','none');

    filename = fullfile(out_dir, sprintf('mandelbrot_%s.png', method_name));
    exportgraphics(fig, filename, 'Resolution', 200);
    close(fig);
end

%% ========================================================================
%  PART 2: Serial Implementation
%  ========================================================================
function M = mandelbrot_serial(width, height, max_iterations)
    % Define Coordinate System
    xlim =[-2.0, 0.5];
    ylim = [-1.2, 1.2];
    x = linspace(xlim(1), xlim(2), width);
    y = linspace(ylim(1), ylim(2), height);

    M = zeros(height, width, 'uint16'); 

    for r = 1:height
        cy = y(r);
        for c = 1:width
            cx = x(c);
            
            % Mandelbrot Pseudocode Logic
            zx = 0; zy = 0;
            iter = 0;
            while (iter < max_iterations && (zx^2 + zy^2 <= 4))
                zx_next = zx^2 - zy^2 + cx;
                zy_next = 2 * zx * zy + cy;
                zx = zx_next;
                zy = zy_next;
                iter = iter + 1;
            end
            M(r,c) = iter;
        end
    end
end

%% ========================================================================
%  PART 3: Parallel Implementation
%  ========================================================================
function M = mandelbrot_parallel(width, height, max_iterations, num_workers)
    % Define Coordinate System
    xlim = [-2.0, 0.5];
    ylim =[-1.2, 1.2];
    x = linspace(xlim(1), xlim(2), width);
    y = linspace(ylim(1), ylim(2), height);

    M = zeros(height, width, 'uint16');

    % Parallelize over rows using parfor
    parfor (r = 1:height, num_workers)
        cy = y(r);
        % Sliced variable: Row must be constructed inside parfor to prevent broadcast overhead
        row = zeros(1, width, 'uint16');
        for c = 1:width
            cx = x(c);
            
            % Mandelbrot Pseudocode Logic
            zx = 0; zy = 0;
            iter = 0;
            while (iter < max_iterations && (zx^2 + zy^2 <= 4))
                zx_next = zx^2 - zy^2 + cx;
                zy_next = 2 * zx * zy + cy;
                zx = zx_next;
                zy = zy_next;
                iter = iter + 1;
            end
            row(c) = iter;
        end
        % Assign computed row back to the sliced output matrix
        M(r,:) = row;
    end
end