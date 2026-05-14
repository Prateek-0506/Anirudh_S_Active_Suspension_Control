%% ================================================================
%  PERFORMANCE_ANALYSIS.m
%  Complete performance comparison:
%    - Uncontrolled Suspension
%    - Fixed PD Controlled Suspension
%    - Adaptive PD Controlled Suspension
%  All three modes compared with engineering metrics
%% ================================================================
clc; clear all; close all;

fprintf('=================================================\n');
fprintf(' SUSPENSION SYSTEM PERFORMANCE ANALYSIS\n');
fprintf('=================================================\n\n');

%% Plant
G = tf([1], [1, 3, 2]);

%% Controller definitions
Kp_fixed = 15; Kd_fixed = 5;
C_fixed = tf([Kd_fixed, Kp_fixed], [1, 0]);
CL_fixed = feedback(C_fixed * G, 1);

d_comfort = 0.15; d_offroad = 0.50; d_sport = 0.90;

C_comfort = tf([3+2*d_comfort, 10+5*d_comfort], [1, 0]);
C_offroad = tf([3+2*d_offroad, 10+5*d_offroad], [1, 0]);
C_sport   = tf([3+2*d_sport,   10+5*d_sport],   [1, 0]);

CL_comfort = feedback(C_comfort * G, 1);
CL_offroad = feedback(C_offroad * G, 1);
CL_sport   = feedback(C_sport   * G, 1);

%% Gather metrics
systems = {G, CL_fixed, CL_comfort, CL_offroad, CL_sport};
labels  = {'Uncontrolled', 'Fixed PD', ...
           'Adaptive: Comfort', 'Adaptive: Off-Road', 'Adaptive: Sport'};
colors  = {'k', 'b', 'g', 'm', 'r'};

t_eval = 0:0.005:15;
metrics = struct();

for i = 1:length(systems)
    try
        si = stepinfo(systems{i});
        [y, ~] = step(systems{i}, t_eval);
        [wn, zeta, ~] = damp(systems{i});
        metrics(i).Name         = labels{i};
        metrics(i).RiseTime     = si.RiseTime;
        metrics(i).SettlingTime = si.SettlingTime;
        metrics(i).Overshoot    = si.Overshoot;
        metrics(i).Peak         = max(abs(y));
        metrics(i).Zeta         = min(zeta);
        metrics(i).Wn           = min(wn);
        metrics(i).y            = y;
    catch ME
        fprintf('Warning for %s: %s\n', labels{i}, ME.message);
        metrics(i).Name         = labels{i};
        metrics(i).RiseTime     = NaN;
        metrics(i).SettlingTime = NaN;
        metrics(i).Overshoot    = NaN;
        metrics(i).Peak         = NaN;
        metrics(i).Zeta         = NaN;
        metrics(i).Wn           = NaN;
        metrics(i).y            = zeros(size(t_eval));
    end
end

%% Vibration reduction
base_peak = metrics(1).Peak;
for i = 1:length(metrics)
    if ~isnan(metrics(i).Peak) && base_peak > 0
        metrics(i).VibReduction = (1 - metrics(i).Peak / base_peak) * 100;
    else
        metrics(i).VibReduction = 0;
    end
end

%% Print performance table
fprintf('\n%-22s %-10s %-12s %-12s %-8s %-8s %-12s\n', ...
    'System','Rise(s)','Settle(s)','Overshoot%','Peak','Zeta','VibRed%');
fprintf('%s\n', repmat('-', 1, 88));
for i = 1:length(metrics)
    fprintf('%-22s %-10.4f %-12.4f %-12.2f %-8.4f %-8.4f %-12.1f\n', ...
        metrics(i).Name, ...
        metrics(i).RiseTime, ...
        metrics(i).SettlingTime, ...
        metrics(i).Overshoot, ...
        metrics(i).Peak, ...
        metrics(i).Zeta, ...
        metrics(i).VibReduction);
end

%% Figure 1: Step Response Comparison
figure('Name','Step Response Comparison','Position',[50,50,1000,600]);
hold on;
for i = 1:length(systems)
    if ~isempty(metrics(i).y)
        plot(t_eval, metrics(i).y, colors{i}, 'LineWidth', 2, ...
             'DisplayName', metrics(i).Name);
    end
end
xlabel('Time (s)'); ylabel('Displacement (m)');
title('Step Response: All Suspension Configurations');
legend('Location','best'); grid on;
xline(5, 'k--', 'Target: 5s settle', 'LabelVerticalAlignment','bottom');

%% Figure 2: Performance Bar Chart
figure('Name','Performance Metrics','Position',[50,700,1200,450]);

subplot(1,3,1);
settle_vals = [metrics.SettlingTime];
settle_vals(isnan(settle_vals)) = 0;
bar(settle_vals, 'FaceColor', 'flat', 'CData', jet(length(systems)));
set(gca, 'XTickLabel', labels, 'XTickLabelRotation', 20);
ylabel('Settling Time (s)');
title('Settling Time Comparison');
yline(5,'r--','5s target'); grid on;

subplot(1,3,2);
overshoot_vals = [metrics.Overshoot];
overshoot_vals(isnan(overshoot_vals)) = 0;
bar(overshoot_vals, 'FaceColor', 'flat', 'CData', jet(length(systems)));
set(gca,'XTickLabel',labels,'XTickLabelRotation',20);
ylabel('Overshoot (%)');
title('Overshoot Comparison'); grid on;

subplot(1,3,3);
vr_vals = [metrics.VibReduction];
vr_vals(isnan(vr_vals)) = 0;
bar(vr_vals, 'FaceColor', 'flat', 'CData', jet(length(systems)));
set(gca,'XTickLabel',labels,'XTickLabelRotation',20);
ylabel('Vibration Reduction (%)');
title('Vibration Reduction vs Uncontrolled'); grid on;

sgtitle('Suspension Performance Comparison Dashboard');

%% Figure 3: Pole Locations
figure('Name','Pole Analysis','Position',[50,50,1000,600]);
sys_list = {G, CL_fixed, CL_comfort, CL_offroad, CL_sport};
hold on;
marker_styles = {'kx','bs','g^','md','r*'};
for i = 1:length(sys_list)
    p = pole(sys_list{i});
    plot(real(p), imag(p), marker_styles{i}, 'MarkerSize', 12, ...
         'LineWidth', 2, 'DisplayName', labels{i});
end
xline(0, 'k--'); yline(0, 'k--');
xlabel('Real Axis'); ylabel('Imaginary Axis');
title('Pole Locations: All Configurations');
legend('Location','best'); grid on;
xlim([-25, 5]);

fprintf('\nPerformance analysis complete.\n');
