%% run_analysis.m
% EEE4120F Practical 2 - Performance Analysis Script
% Benchmarks sequential vs parallel Mandelbrot set computation
% across all standard resolutions and varying worker counts.
%
% Usage: run run_analysis  (from MATLAB command window)

clear; clc; close all;

%% =====================================================================
%  CONFIGURATION
%% =====================================================================

MAX_ITERATIONS = 1000;

% Standard resolutions as specified in the practical manual
resolutions = {
    'SVGA',    800,  600;
    'HD',     1280,  720;
    'Full HD',1920, 1080;
    '2K',     2048, 1080;
    'QHD',    2560, 1440;
    '4K UHD', 3840, 2160;
    '5K',     5120, 2880;
    '8K UHD', 7680, 4320;
};

num_resolutions = size(resolutions, 1);

% Determine max physical cores available
max_workers = feature('numcores');
fprintf('Detected %d physical cores on this machine.\n\n', max_workers);

% Worker counts to test (2 up to max_workers)
worker_counts = 2:max_workers;

% Output directory for saved images
output_dir = 'mandelbrot_images';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% =====================================================================
%  STEP 1: SEQUENTIAL BENCHMARK
%% =====================================================================
fprintf('=== SEQUENTIAL BENCHMARK ===\n');

seq_times = zeros(num_resolutions, 1);

for r = 1:num_resolutions
    name   = resolutions{r, 1};
    width  = resolutions{r, 2};
    height = resolutions{r, 3};

    [img, t] = mandelbrot_sequential(width, height, MAX_ITERATIONS);
    seq_times(r) = t;

    % Save image
    fname = fullfile(output_dir, sprintf('seq_%s_%dx%d.png', ...
        strrep(name, ' ', '_'), width, height));
    mandelbrot_plot(img, width, height, fname);
end

fprintf('\nSequential benchmarking complete.\n\n');

%% =====================================================================
%  STEP 2: PARALLEL BENCHMARK (varying worker counts)
%% =====================================================================
fprintf('=== PARALLEL BENCHMARK ===\n');

% par_times(r, w) = time for resolution r with worker_counts(w) workers
num_worker_configs = length(worker_counts);
par_times = zeros(num_resolutions, num_worker_configs);

for w = 1:num_worker_configs
    nw = worker_counts(w);
    fprintf('\n-- %d Workers --\n', nw);

    for r = 1:num_resolutions
        name   = resolutions{r, 1};
        width  = resolutions{r, 2};
        height = resolutions{r, 3};

        [img, t] = mandelbrot_parallel(width, height, MAX_ITERATIONS, nw);
        par_times(r, w) = t;

        % Save image only for the first worker config to avoid duplicates
        if w == 1
            fname = fullfile(output_dir, sprintf('par_%s_%dx%d.png', ...
                strrep(name, ' ', '_'), width, height));
            mandelbrot_plot(img, width, height, fname);
        end
    end
end

fprintf('\nParallel benchmarking complete.\n\n');

%% =====================================================================
%  STEP 3: COMPUTE METRICS
%% =====================================================================

% Megapixels for x-axis labelling
megapixels = zeros(num_resolutions, 1);
for r = 1:num_resolutions
    megapixels(r) = (resolutions{r,2} * resolutions{r,3}) / 1e6;
end

% Speedup and Efficiency matrices
% speedup(r, w)    = seq_time / par_time
% efficiency(r, w) = speedup / num_workers * 100
speedup    = seq_times ./ par_times;          % broadcast division
efficiency = speedup ./ worker_counts * 100;  % worker_counts is row vector -> broadcasting

%% =====================================================================
%  STEP 4: PRINT RESULTS TABLE
%% =====================================================================

fprintf('=== RESULTS TABLE ===\n');
header = sprintf('%-10s | %8s | %8s', 'Resolution', 'Seq (s)', 'MP');
for w = 1:num_worker_configs
    header = [header, sprintf(' | W%-2d Spd', worker_counts(w))]; %#ok<AGROW>
end
fprintf('%s\n', header);
fprintf('%s\n', repmat('-', 1, length(header)));

for r = 1:num_resolutions
    row_str = sprintf('%-10s | %8.3f | %8.2f', ...
        resolutions{r,1}, seq_times(r), megapixels(r));
    for w = 1:num_worker_configs
        row_str = [row_str, sprintf(' | %7.2fx', speedup(r, w))]; %#ok<AGROW>
    end
    fprintf('%s\n', row_str);
end

%% =====================================================================
%  STEP 5: PLOTS
%% =====================================================================

res_labels = resolutions(:, 1);

% --- Plot 1: Execution Time vs Resolution ---
fig1 = figure('Name', 'Execution Time vs Resolution', 'Position', [100, 100, 900, 500]);
hold on;
plot(megapixels, seq_times, 'k-o', 'LineWidth', 2, 'DisplayName', 'Sequential');
colors = lines(num_worker_configs);
for w = 1:num_worker_configs
    plot(megapixels, par_times(:, w), '-s', 'Color', colors(w,:), ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%d Workers', worker_counts(w)));
end
hold off;
xlabel('Resolution (Megapixels)');
ylabel('Execution Time (seconds)');
title('Mandelbrot Set: Execution Time vs Resolution');
legend('Location', 'northwest');
grid on;
set(gca, 'XTick', megapixels, 'XTickLabel', res_labels, 'XTickLabelRotation', 45);
saveas(fig1, fullfile(output_dir, 'plot_execution_time.png'));

% --- Plot 2: Speedup vs Resolution ---
fig2 = figure('Name', 'Speedup vs Resolution', 'Position', [100, 200, 900, 500]);
hold on;
for w = 1:num_worker_configs
    plot(megapixels, speedup(:, w), '-o', 'Color', colors(w,:), ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%d Workers', worker_counts(w)));
end
% Ideal speedup lines
for w = 1:num_worker_configs
    yline(worker_counts(w), '--', 'Color', colors(w,:), 'Alpha', 0.4, ...
        'Label', sprintf('Ideal %dW', worker_counts(w)));
end
hold off;
xlabel('Resolution (Megapixels)');
ylabel('Speedup (T_{serial} / T_{parallel})');
title('Mandelbrot Set: Speedup vs Resolution');
legend('Location', 'southeast');
grid on;
set(gca, 'XTick', megapixels, 'XTickLabel', res_labels, 'XTickLabelRotation', 45);
saveas(fig2, fullfile(output_dir, 'plot_speedup.png'));

% --- Plot 3: Efficiency vs Resolution ---
fig3 = figure('Name', 'Parallel Efficiency vs Resolution', 'Position', [100, 300, 900, 500]);
hold on;
for w = 1:num_worker_configs
    plot(megapixels, efficiency(:, w), '-^', 'Color', colors(w,:), ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%d Workers', worker_counts(w)));
end
yline(100, 'k--', 'Label', 'Ideal (100%)');
hold off;
xlabel('Resolution (Megapixels)');
ylabel('Efficiency (%)');
title('Mandelbrot Set: Parallel Efficiency vs Resolution');
legend('Location', 'southeast');
grid on;
ylim([0, 120]);
set(gca, 'XTick', megapixels, 'XTickLabel', res_labels, 'XTickLabelRotation', 45);
saveas(fig3, fullfile(output_dir, 'plot_efficiency.png'));

% --- Plot 4: Speedup vs Workers (for largest resolution) ---
fig4 = figure('Name', 'Speedup vs Workers (8K)', 'Position', [100, 400, 700, 450]);
spd_8k = speedup(end, :);  % Last resolution (8K)
plot(worker_counts, spd_8k, 'b-o', 'LineWidth', 2, 'DisplayName', 'Actual Speedup');
hold on;
plot(worker_counts, worker_counts, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Ideal (Linear)');

% Amdahl's Law estimate
% Estimate parallelisable fraction f from the 2-worker data point
% Speedup_2 = 1 / ((1-f) + f/2)  =>  f = 2*(1 - 1/Speedup_2)
if spd_8k(1) > 1
    f_est = 2 * (1 - 1/spd_8k(1));
    f_est = min(max(f_est, 0), 1);  % clamp to [0,1]
    amdahl_spd = 1 ./ ((1 - f_est) + f_est ./ worker_counts);
    plot(worker_counts, amdahl_spd, 'g-.', 'LineWidth', 1.5, ...
        'DisplayName', sprintf("Amdahl's Law (f=%.2f)", f_est));
end
hold off;
xlabel('Number of Workers');
ylabel('Speedup');
title('Speedup vs Workers for 8K Resolution');
legend('Location', 'northwest');
grid on;
xticks(worker_counts);
saveas(fig4, fullfile(output_dir, 'plot_speedup_vs_workers.png'));

fprintf('\nAll plots saved to: %s/\n', output_dir);
fprintf('\n=== Analysis Complete ===\n');
