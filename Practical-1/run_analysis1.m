% =========================================================================
% Practical 1: 2D Convolution Analysis
% =========================================================================
%
% GROUP NUMBER: 24
%
% MEMBERS:
%   - Member 1 Nyakallo Peete, PTXNYA001
%   - Member 2 Samson Okuthe, OKTSAM001
%
% NOTES:
% - This version improves benchmarking by:
%   (1) Doing warm-up calls (avoids JIT + cache cold-start bias)
%   (2) Timing EACH run individually
%   (3) Using MEDIAN time (robust to OS noise spikes)
%   (4) Allowing different run-counts per image size
%
% HOW TO RUN:
%   >> run_analysis
%
% =========================================================================

function run_analysis()
    clc; close all;
    fprintf('Starting Benchmarking Analysis for Group 24...\n\n');

    %% -------------------------------------------------------------
    % TODO 1: Load all the sample images from the 'sample_images' folder
    %% -------------------------------------------------------------
    img_names = { ...
        'image_128x128.png', ...
        'image_256x256.png', ...
        'image_512x512.png', ...
        'image_1024x1024.png', ...
        'image_2048x2048.png' ...
    };
    num_images = length(img_names);

    imgs = cell(1, num_images);
    pixels_count = zeros(1, num_images);

    fprintf('Loading Images...\n');
    for i = 1:num_images
        path = fullfile('sample_images', img_names{i});

        if ~isfile(path)
            error('Image not found: %s. Check your folder path and file names.', path);
        end

        temp_img = imread(path);

        % Convert to grayscale if RGB
        if size(temp_img, 3) == 3
            temp_img = rgb2gray(temp_img);
        end

        % Convert to double for safe arithmetic
        imgs{i} = double(temp_img);

        [r, c] = size(imgs{i});
        pixels_count(i) = r * c;

        fprintf('  Loaded: %s (%dx%d)\n', img_names{i}, r, c);
    end
    fprintf('\n');

    %% -------------------------------------------------------------
    % TODO 2: Define edge detection kernels (Sobel kernel)
    %% -------------------------------------------------------------
    Gx = [-1,  0,  1;
          -2,  0,  2;
          -1,  0,  1];

    Gy = [ 1,  2,  1;
           0,  0,  0;
          -1, -2, -1];

    %% -------------------------------------------------------------
    % TODO 3: Testing and Benchmarking
    %% -------------------------------------------------------------
    manual_times = zeros(1, num_images);
    builtin_times = zeros(1, num_images);
    speedups      = zeros(1, num_images);

    % Store max absolute differences (for reporting)
    max_diff_x = zeros(1, num_images);
    max_diff_y = zeros(1, num_images);

    % Choose number of runs based on image size (bigger = fewer runs)
    % Feel free to tune these.
    runs_by_size = zeros(1, num_images);

    for i = 1:num_images
        img = imgs{i};
        [r, c] = size(img);

        if max(r, c) <= 512
            runs_by_size(i) = 30;
        elseif max(r, c) <= 1024
            runs_by_size(i) = 15;
        else
            runs_by_size(i) = 10;
        end
    end

    for i = 1:num_images
        fprintf('Processing Image %d/%d (%s)...\n', i, num_images, img_names{i});
        img = imgs{i};
        num_runs = runs_by_size(i);

        % ----------------------------
        % Warm-up calls (NOT timed)
        % ----------------------------
        my_conv2(img, Gx);
        my_conv2(img, Gy);
        inbuilt_conv2(img, Gx);
        inbuilt_conv2(img, Gy);

        % ----------------------------
        % Manual timing (time EACH run)
        % ----------------------------
        manual_run_times = zeros(1, num_runs);

        for r = 1:num_runs
            tic;
            man_Gx = my_conv2(img, Gx);
            man_Gy = my_conv2(img, Gy);
            manual_run_times(r) = toc;
        end

        manual_times(i) = median(manual_run_times);

        % ----------------------------
        % Built-in timing (time EACH run)
        % ----------------------------
        builtin_run_times = zeros(1, num_runs);

        for r = 1:num_runs
            tic;
            built_Gx = inbuilt_conv2(img, Gx);
            built_Gy = inbuilt_conv2(img, Gy);
            builtin_run_times(r) = toc;
        end

        builtin_times(i) = median(builtin_run_times);

        % ----------------------------
        % Speedup
        % ----------------------------
        speedups(i) = manual_times(i) / builtin_times(i);

        % ----------------------------
        % Verify correctness (use last computed results)
        % ----------------------------
        diff_x = max(abs(man_Gx(:) - built_Gx(:)));
        diff_y = max(abs(man_Gy(:) - built_Gy(:)));
        max_diff_x(i) = diff_x;
        max_diff_y(i) = diff_y;

        if diff_x > 1e-6 || diff_y > 1e-6
            warning('VERIFICATION FAILED for %s: diff_x=%.3e, diff_y=%.3e', ...
                img_names{i}, diff_x, diff_y);
        else
            fprintf('  -> Verification: PASSED! Outputs match.\n');
        end

        % ----------------------------
        % Print run statistics (optional but useful)
        % ----------------------------
        fprintf('  Runs used: %d\n', num_runs);
        fprintf('  -> Manual Median Time:   %.6f s\n', manual_times(i));
        fprintf('  -> Built-in Median Time: %.6f s\n', builtin_times(i));
        fprintf('  -> Speedup Ratio:        %.2fx\n', speedups(i));
        fprintf('  -> Max diff Gx: %.3e | Max diff Gy: %.3e\n\n', diff_x, diff_y);
    end

    %% -------------------------------------------------------------
    % Summary Table
    %% -------------------------------------------------------------
    disp('=== FINAL BENCHMARKING RESULTS (MEDIAN TIMES) ===');

    T = table( ...
        img_names', ...
        pixels_count', ...
        runs_by_size', ...
        manual_times', ...
        builtin_times', ...
        speedups', ...
        max_diff_x', ...
        max_diff_y', ...
        'VariableNames', { ...
            'Image_Name', ...
            'Total_Pixels', ...
            'Runs_Used', ...
            'Manual_Median_Time_s', ...
            'BuiltIn_Median_Time_s', ...
            'Speedup', ...
            'MaxAbsDiff_Gx', ...
            'MaxAbsDiff_Gy' ...
        } ...
    );

    disp(T);

    %% -------------------------------------------------------------
    % Plot results (no subplots: clearer figures)
    %% -------------------------------------------------------------
    figure('Name', 'Execution Time vs Image Size', 'NumberTitle', 'off');
    plot(pixels_count, manual_times, '-o', 'LineWidth', 2, 'MarkerSize', 7);
    hold on;
    plot(pixels_count, builtin_times, '-s', 'LineWidth', 2, 'MarkerSize', 7);
    grid on;
    title('Execution Time vs Image Size (Median of Multiple Runs)');
    xlabel('Image Size (Total Pixels)');
    ylabel('Execution Time (Seconds)');
    legend('Manual (my\_conv2)', 'Built-in (conv2)', 'Location', 'northwest');

    figure('Name', 'Speedup vs Image Size', 'NumberTitle', 'off');
    plot(pixels_count, speedups, '-^', 'LineWidth', 2, 'MarkerSize', 7);
    grid on;
    title('Speedup Ratio vs Image Size');
    xlabel('Image Size (Total Pixels)');
    ylabel('Speedup Factor (Manual / Built-in)');

    fprintf('Done. Figures generated and summary table printed.\n');
end

%% ========================================================================
%  PART 1: Manual 2D Convolution Implementation (HELPER FUNCTION)
%  ========================================================================
function output = my_conv2(img, kernel)
    [img_rows, img_cols] = size(img);
    [k_rows, k_cols] = size(kernel);

    % True convolution flips kernel by 180 degrees (to match MATLAB conv2)
    kernel = kernel(end:-1:1, end:-1:1);

    % Padding sizes for 'same' output size
    pad_r = floor(k_rows / 2);
    pad_c = floor(k_cols / 2);

    % Zero padding (matches conv2(...,'same') typical boundary handling)
    padded_img = zeros(img_rows + 2*pad_r, img_cols + 2*pad_c);
    padded_img(pad_r+1:end-pad_r, pad_c+1:end-pad_c) = img;

    output = zeros(img_rows, img_cols);

    % Strict loops (required)
    for i = 1:img_rows
        for j = 1:img_cols
            sum_val = 0;
            for ki = 1:k_rows
                for kj = 1:k_cols
                    sum_val = sum_val + padded_img(i + ki - 1, j + kj - 1) * kernel(ki, kj);
                end
            end
            output(i, j) = sum_val;
        end
    end
end

%% ========================================================================
%  PART 2: Built-in 2D Convolution Implementation (HELPER FUNCTION)
%  ========================================================================
function output = inbuilt_conv2(img, kernel)
    output = conv2(img, kernel, 'same');
end