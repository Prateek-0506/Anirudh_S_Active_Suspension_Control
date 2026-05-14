%% ================================================================
%  RUN_DASHBOARD.m
%  ── MASTER LAUNCHER ──
%  AI-Powered Predictive Adaptive Active Suspension System
%  Hackathon Edition — Quick Start
%
%  Just run this file in MATLAB to launch everything.
%% ================================================================
clc;
fprintf('==========================================================\n');
fprintf('  AI PREDICTIVE ADAPTIVE SUSPENSION SYSTEM  v3\n');
fprintf('  Hackathon Edition\n');
fprintf('==========================================================\n\n');

% Ensure this folder is on the path
here = fileparts(mfilename('fullpath'));
addpath(here);

fprintf('Starting AI Suspension Dashboard...\n\n');
fprintf('HOW TO USE:\n');
fprintf('  1. Press [▶ Start Simulation]\n');
fprintf('  2. Select different Road Profiles from the dropdown\n');
fprintf('  3. Watch the AI classify the road in real time\n');
fprintf('  4. Observe Predictive vs Reactive gain scheduling\n');
fprintf('  5. Compare controlled vs uncontrolled animations\n');
fprintf('  6. Press [Performance Report] for full analysis\n\n');

suspension_dashboard();
