%% ================================================================
%  INTELLIGENT ADAPTIVE ACTIVE SUSPENSION CONTROL SYSTEM
%  Vehicle Vibration Reduction and Stability Enhancement
%  Transfer Function: G(s) = 1 / (s^2 + 3s + 2)
%% ================================================================
clc; clear all; close all;

fprintf('==========================================================\n');
fprintf(' INTELLIGENT ADAPTIVE ACTIVE SUSPENSION CONTROL SYSTEM\n');
fprintf('==========================================================\n\n');

%% ================================================================
%  SECTION 1: SYSTEM MODELING & OPEN-LOOP ANALYSIS
%% ================================================================
fprintf('--- SECTION 1: Open-Loop System Analysis ---\n');

% Define suspension plant transfer function
num = [1];
den = [1, 3, 2];
G = tf(num, den);

fprintf('\nPlant Transfer Function G(s) = 1 / (s^2 + 3s + 2)\n');
disp(G);

% Poles and Damping Analysis
p = pole(G);
fprintf('\nSystem Poles:\n');
disp(p);

[wn, zeta, poles] = damp(G);
fprintf('\nNatural Frequency (wn): %.4f rad/s\n', wn(1));
fprintf('Damping Ratio (zeta):   %.4f\n', zeta(1));

% Verify stability
if all(real(p) < 0)
    fprintf('\nSystem STABLE: All poles in left-half plane.\n');
    fprintf('  Pole 1: s = %.2f (fast decay, mechanical stiffness)\n', p(1));
    fprintf('  Pole 2: s = %.2f (slow decay, damping effect)\n', p(2));
else
    fprintf('\nSystem UNSTABLE: Pole(s) in right-half plane.\n');
end

% Pole-Zero Map
figure('Name','Pole-Zero Map','Position',[100,100,600,500]);
pzmap(G);
title('Suspension System Pole-Zero Map');
grid on;
fprintf('\nPole-Zero Map displayed.\n');

% Step Response Analysis
figure('Name','Open-Loop Step Response','Position',[720,100,600,500]);
step(G);
title('Open-Loop Step Response (Road Bump)');
grid on;

info = stepinfo(G);
fprintf('\n--- Step Response Performance ---\n');
fprintf('Rise Time:       %.4f s\n', info.RiseTime);
fprintf('Settling Time:   %.4f s\n', info.SettlingTime);
fprintf('Overshoot:       %.2f %%\n', info.Overshoot);
fprintf('Peak:            %.4f\n', info.Peak);
fprintf('Peak Time:       %.4f s\n', info.PeakTime);

%% ================================================================
%  SECTION 2: UNCONTROLLED DISTURBANCE RESPONSES
%% ================================================================
fprintf('\n--- SECTION 2: Uncontrolled Disturbance Responses ---\n');

t = 0:0.01:15;
figure('Name','Uncontrolled Responses','Position',[100,620,1200,500]);

% Step input (road bump)
subplot(2,2,1);
[y_step, t_step] = step(G, t);
plot(t_step, y_step, 'b', 'LineWidth', 1.5);
title('Step Input (Road Bump)');
xlabel('Time (s)'); ylabel('Displacement (m)');
grid on;

% Impulse input (pothole)
subplot(2,2,2);
[y_imp, t_imp] = impulse(G, t);
plot(t_imp, y_imp, 'r', 'LineWidth', 1.5);
title('Impulse Input (Pothole)');
xlabel('Time (s)'); ylabel('Displacement (m)');
grid on;

% Sinusoidal input (uneven road)
subplot(2,2,3);
u_sin = sin(2*pi*0.5*t);
[y_sin, ~] = lsim(G, u_sin, t);
plot(t, u_sin, 'g--', t, y_sin, 'b', 'LineWidth', 1.5);
legend('Input','Response');
title('Sinusoidal Input (Uneven Road)');
xlabel('Time (s)'); ylabel('Displacement (m)');
grid on;

% Random disturbance (rough terrain)
subplot(2,2,4);
rng(42);
u_rand = 0.5*randn(size(t));
[y_rand, ~] = lsim(G, u_rand, t);
plot(t, u_rand, 'g--', t, y_rand, 'b', 'LineWidth', 1.5);
legend('Disturbance','Response');
title('Random Input (Rough Terrain)');
xlabel('Time (s)'); ylabel('Displacement (m)');
grid on;

sgtitle('Uncontrolled Suspension Responses to Road Disturbances');

%% ================================================================
%  SECTION 3: ADAPTIVE PD CONTROLLER DESIGN
%% ================================================================
fprintf('\n--- SECTION 3: Adaptive PD Controller Design ---\n');

% Adaptive gain scheduling function
% Kp = 10 + 5 * disturbance_magnitude
% Kd = 3  + 2 * disturbance_magnitude

fprintf('\nAdaptive Gain Equations:\n');
fprintf('  Kp = 10 + 5 * disturbance_magnitude\n');
fprintf('  Kd =  3 + 2 * disturbance_magnitude\n');
fprintf('\nOperating Modes:\n');
fprintf('  Comfort Mode  (d < 0.3): Kp=%.1f, Kd=%.1f\n', 10+5*0.15, 3+2*0.15);
fprintf('  Off-Road Mode (0.3<=d<0.7): Kp=%.1f, Kd=%.1f\n', 10+5*0.5, 3+2*0.5);
fprintf('  Sport Mode    (d >= 0.7): Kp=%.1f, Kd=%.1f\n', 10+5*0.85, 3+2*0.85);

% Fixed PD controller (moderate gains for comparison)
Kp_fixed = 15;
Kd_fixed = 5;
C_fixed = tf([Kd_fixed, Kp_fixed], [1, 0]);
fprintf('\nFixed PD Controller: Kp=%.1f, Kd=%.1f\n', Kp_fixed, Kd_fixed);

% Closed-loop systems
CL_fixed = feedback(C_fixed * G, 1);

% Compute closed-loop for each mode
Kp_comfort = 10 + 5*0.15; Kd_comfort = 3 + 2*0.15;
Kp_offroad = 10 + 5*0.50; Kd_offroad = 3 + 2*0.50;
Kp_sport   = 10 + 5*0.85; Kd_sport   = 3 + 2*0.85;

C_comfort = tf([Kd_comfort, Kp_comfort], [1, 0]);
C_offroad = tf([Kd_offroad, Kp_offroad], [1, 0]);
C_sport   = tf([Kd_sport,   Kp_sport],   [1, 0]);

CL_comfort = feedback(C_comfort * G, 1);
CL_offroad = feedback(C_offroad * G, 1);
CL_sport   = feedback(C_sport   * G, 1);

%% ================================================================
%  SECTION 4: CONTROLLED VS UNCONTROLLED COMPARISON
%% ================================================================
fprintf('\n--- SECTION 4: Controlled vs Uncontrolled Comparison ---\n');

t_comp = 0:0.01:10;
[y_open, ~]   = step(G, t_comp);
[y_fixed, ~]  = step(CL_fixed, t_comp);
[y_comfort, ~] = step(CL_comfort, t_comp);
[y_offroad, ~] = step(CL_offroad, t_comp);
[y_sport, ~]   = step(CL_sport,   t_comp);

figure('Name','Controlled vs Uncontrolled','Position',[100,100,900,600]);
plot(t_comp, y_open,    'k--',  'LineWidth', 2, 'DisplayName', 'Uncontrolled');
hold on;
plot(t_comp, y_fixed,   'b-',   'LineWidth', 1.5, 'DisplayName', 'Fixed PD');
plot(t_comp, y_comfort, 'g-',   'LineWidth', 1.5, 'DisplayName', 'Comfort Mode');
plot(t_comp, y_offroad, 'm-',   'LineWidth', 1.5, 'DisplayName', 'Off-Road Mode');
plot(t_comp, y_sport,   'r-',   'LineWidth', 1.5, 'DisplayName', 'Sport Mode');
xlabel('Time (s)'); ylabel('Displacement (m)');
title('Controlled vs Uncontrolled Suspension Response (Step Input)');
legend('Location','best');
grid on;

%% ================================================================
%  SECTION 5: ADAPTIVE SIMULATION WITH CONTINUOUS GAIN SCHEDULING
%% ================================================================
fprintf('\n--- SECTION 5: Adaptive Simulation with Gain Scheduling ---\n');

t_sim = 0:0.005:20;
dt = t_sim(2) - t_sim(1);

% Realistic road profile (multiple disturbance types)
d_road = zeros(size(t_sim));
d_road(t_sim >= 1  & t_sim < 3)  = 0.15;   % slight bump
d_road(t_sim >= 5  & t_sim < 6)  = 0.55;   % pothole / off-road
d_road(t_sim >= 9  & t_sim < 10) = 0.90;   % speed breaker (sport)
d_road(t_sim >= 13 & t_sim < 15) = 0.35 + 0.15*sin(2*pi*1.0*(t_sim(t_sim>=13&t_sim<15)-13));
d_road(t_sim >= 17 & t_sim < 20) = 0.10 + 0.05*randn(1, sum(t_sim>=17 & t_sim<20));
d_road = max(0, d_road);

% Compute adaptive gains
Kp_adaptive = 10 + 5 * d_road;
Kd_adaptive =  3 + 2 * d_road;

% Determine mode labels
mode_label = zeros(size(t_sim));
mode_label(d_road >= 0.3 & d_road < 0.7) = 1;
mode_label(d_road >= 0.7) = 2;

% Simulate adaptive response using numerical integration (Euler method)
% State-space: G(s) = 1/(s^2+3s+2) => dx1/dt=x2, dx2/dt=-2x1-3x2+u
n = length(t_sim);
x1 = zeros(1,n); x2 = zeros(1,n);  % plant states
x1_open = zeros(1,n); x2_open = zeros(1,n);
e_int = 0;  % integral for reference tracking (not used in PD)

y_adapt = zeros(1,n);
y_uncontrolled_sim = zeros(1,n);
u_ctrl = zeros(1,n);
ref = d_road;  % reference: follow disturbance with damped response

for k = 1:n-1
    % Adaptive gains
    Kp = Kp_adaptive(k);
    Kd = Kd_adaptive(k);
    
    % Error
    e = ref(k) - x1(k);
    de = -x2(k);
    
    % Control input
    u = Kp*e + Kd*de;
    u_ctrl(k) = u;
    
    % Plant update (controlled)
    dx1 = x2(k);
    dx2 = -2*x1(k) - 3*x2(k) + u;
    x1(k+1) = x1(k) + dt*dx1;
    x2(k+1) = x2(k) + dt*dx2;
    
    % Plant update (uncontrolled, only disturbance)
    dx1_o = x2_open(k);
    dx2_o = -2*x1_open(k) - 3*x2_open(k) + d_road(k);
    x1_open(k+1) = x1_open(k) + dt*dx1_o;
    x2_open(k+1) = x2_open(k) + dt*dx2_o;
end

y_adapt = x1;
y_uncontrolled_sim = x1_open;

%% ================================================================
%  SECTION 6: COMPREHENSIVE PLOTS
%% ================================================================
figure('Name','Adaptive System Comprehensive','Position',[50,50,1400,900]);

subplot(3,2,1);
plot(t_sim, d_road, 'k', 'LineWidth', 1.5);
title('Road Disturbance Profile'); xlabel('Time (s)'); ylabel('Magnitude');
ylim([-0.2, 1.2]); grid on;

subplot(3,2,2);
plot(t_sim, y_uncontrolled_sim, 'r--', t_sim, y_adapt, 'b', 'LineWidth', 1.5);
legend('Uncontrolled','Adaptive PD'); grid on;
title('Controlled vs Uncontrolled Displacement');
xlabel('Time (s)'); ylabel('Displacement (m)');

subplot(3,2,3);
plot(t_sim, u_ctrl, 'g', 'LineWidth', 1.2);
title('Controller Output (Actuator Force)');
xlabel('Time (s)'); ylabel('Force (N)'); grid on;

subplot(3,2,4);
yyaxis left;
plot(t_sim, Kp_adaptive, 'b', 'LineWidth', 1.5);
ylabel('Kp');
yyaxis right;
plot(t_sim, Kd_adaptive, 'r', 'LineWidth', 1.5);
ylabel('Kd');
title('Adaptive Gain Variation'); xlabel('Time (s)'); grid on;
legend('Kp','Kd');

subplot(3,2,5);
area(t_sim, mode_label, 'FaceAlpha', 0.4, 'FaceColor', 'cyan');
ylim([-0.5, 2.5]);
yticks([0 1 2]); yticklabels({'Comfort','Off-Road','Sport'});
title('Adaptive Mode Switching'); xlabel('Time (s)'); grid on;

subplot(3,2,6);
e_reduction = abs(y_uncontrolled_sim) - abs(y_adapt);
plot(t_sim, e_reduction, 'm', 'LineWidth', 1.5);
title('Vibration Reduction (Uncontrolled - Controlled)');
xlabel('Time (s)'); ylabel('\DeltaDisplacement (m)'); grid on;

sgtitle('Adaptive PD Suspension Control System - Comprehensive Analysis');

%% ================================================================
%  SECTION 7: CONTROL SYSTEM ANALYSIS (Root Locus, Bode)
%% ================================================================
fprintf('\n--- SECTION 7: Control System Analysis ---\n');

figure('Name','Control Analysis','Position',[100,100,1200,900]);

% Root locus
subplot(2,2,1);
rlocus(G);
title('Root Locus of Open-Loop System');
grid on;

% Bode plot - open loop
subplot(2,2,2);
bode(G);
title('Bode Plot - Plant G(s)');
grid on;

% Bode plot - fixed closed loop
subplot(2,2,3);
bode(CL_fixed);
title('Bode Plot - Closed Loop (Fixed PD)');
grid on;

% Bode plot comparison
subplot(2,2,4);
bode(G, CL_comfort, CL_offroad, CL_sport);
legend('Open Loop','Comfort','Off-Road','Sport','Location','southwest');
title('Bode Comparison: All Modes');
grid on;

%% ================================================================
%  SECTION 8: PERFORMANCE COMPARISON TABLE
%% ================================================================
fprintf('\n--- SECTION 8: Performance Comparison Table ---\n');

systems = {G, CL_fixed, CL_comfort, CL_offroad, CL_sport};
names   = {'Uncontrolled','Fixed PD','Comfort Mode','Off-Road Mode','Sport Mode'};

fprintf('\n%-18s %-12s %-14s %-12s %-10s\n', ...
    'System','Rise(s)','Settle(s)','Overshoot%','Peak');
fprintf('%s\n', repmat('-',1,66));

for i = 1:length(systems)
    try
        si = stepinfo(systems{i});
        [y,~] = step(systems{i}, 0:0.01:30);
        peak = max(abs(y));
        fprintf('%-18s %-12.4f %-14.4f %-12.2f %-10.4f\n', ...
            names{i}, si.RiseTime, si.SettlingTime, si.Overshoot, peak);
    catch
        fprintf('%-18s  [Unable to compute]\n', names{i});
    end
end

% Vibration reduction percentage
[y_unc, ~] = step(G, 0:0.01:30);
[y_adp, ~] = step(CL_sport, 0:0.01:30);
vr_percent = (1 - max(abs(y_adp))/max(abs(y_unc))) * 100;
fprintf('\nVibration Reduction (Sport Mode vs Uncontrolled): %.1f%%\n', vr_percent);

%% ================================================================
%  SECTION 9: ABS / WHEEL SLIP ANALYSIS
%% ================================================================
fprintf('\n--- SECTION 9: Wheel Slip & ABS Analysis ---\n');
fprintf('\nWheel Slip Equation: Slip = (V - r*omega) / V\n');
fprintf('\nWith improved suspension damping:\n');
fprintf('  - Reduced wheel hop maintains tire-road contact\n');
fprintf('  - Consistent normal force -> better traction\n');
fprintf('  - Stable wheel speed during ABS intervention\n');
fprintf('  - Improved braking distance and ABS efficiency\n');

V  = 20;        % Vehicle speed m/s
r  = 0.3;       % Wheel radius m
t_abs = 0:0.01:3;

% Simulate wheel speed variation (with/without adaptive suspension)
omega_no_ctrl  = (V/r) * (1 - 0.4*sin(2*pi*2*t_abs) .* exp(-t_abs));
omega_adaptive = (V/r) * (1 - 0.1*sin(2*pi*2*t_abs) .* exp(-2*t_abs));

slip_no_ctrl  = (V - r*omega_no_ctrl)  / V;
slip_adaptive = (V - r*omega_adaptive) / V;

figure('Name','Wheel Slip Analysis','Position',[100,100,800,500]);
plot(t_abs, slip_no_ctrl,  'r--', 'LineWidth', 2, 'DisplayName', 'Without Adaptive Suspension');
hold on;
plot(t_abs, slip_adaptive, 'b-',  'LineWidth', 2, 'DisplayName', 'With Adaptive Suspension');
yline(0.2, 'k:', 'LineWidth', 1.5, 'DisplayName', 'ABS Trigger Threshold (20%)');
xlabel('Time (s)'); ylabel('Wheel Slip Ratio');
title('Wheel Slip During Braking: Effect of Adaptive Suspension on ABS');
legend('Location','best'); grid on;

fprintf('\nSimulation Complete.\n');
fprintf('============================================================\n');
