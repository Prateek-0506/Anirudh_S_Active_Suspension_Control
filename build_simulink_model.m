%% ================================================================
%  BUILD_SIMULINK_MODEL.m
%  Programmatically creates the Simulink model for the
%  Intelligent Adaptive Active Suspension Control System
%% ================================================================
%
%  This script builds and opens a Simulink model containing:
%    - Road disturbance signal generator
%    - Adaptive PD controller with gain scheduler
%    - Suspension plant (transfer function block)
%    - Feedback loop
%    - Multiple scope outputs
%
%  Prerequisites: MATLAB + Simulink installed
%
%  Run: build_simulink_model
%
%% ================================================================

function build_simulink_model()

    mdl = 'AdaptiveSuspensionSystem';
    
    % Close and delete existing model if open
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end
    if exist([mdl '.slx'], 'file')
        delete([mdl '.slx']);
    end
    
    % Create new model
    new_system(mdl);
    open_system(mdl);
    
    fprintf('Building Simulink model: %s\n', mdl);
    
    %% --- DISTURBANCE SIGNAL GENERATOR (using Signal Builder or Step) ---
    add_block('simulink/Sources/Step', [mdl '/RoadBump'], ...
        'Position', [50, 150, 100, 190], ...
        'Time', '2', 'Before', '0', 'After', '1', ...
        'SampleTime', '0', ...
        'Name', 'RoadBump');
    
    add_block('simulink/Sources/Sine Wave', [mdl '/SineRoad'], ...
        'Position', [50, 220, 100, 260], ...
        'Amplitude', '0.5', 'Frequency', '3.14159', ...
        'Phase', '0', 'SampleTime', '0', ...
        'Name', 'SineRoad');

    add_block('simulink/Signal Routing/Mux', [mdl '/DistMux'], ...
        'Inputs', '2', ...
        'Position', [130, 155, 160, 265]);

    add_block('simulink/Math Operations/Sum', [mdl '/DistSum'], ...
        'Inputs', '++', ...
        'Position', [190, 170, 220, 250]);

    %% --- DISTURBANCE MAGNITUDE ESTIMATOR (Abs + Low-Pass Filter) ---
    add_block('simulink/Math Operations/Abs', [mdl '/DistAbs'], ...
        'Position', [270, 50, 310, 90]);

    % Low-pass filter for disturbance estimation (1/(0.1s+1))
    add_block('simulink/Continuous/Transfer Fcn', [mdl '/LPFilter'], ...
        'Numerator', '[1]', 'Denominator', '[0.1, 1]', ...
        'Position', [350, 50, 430, 90], ...
        'Name', 'LPFilter');

    %% --- ADAPTIVE GAIN SCHEDULER (Matlab Function Block) ---
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
        [mdl '/AdaptiveGainScheduler'], ...
        'Position', [480, 30, 620, 110]);

    % Set the MATLAB Function content
    gain_fn_code = sprintf([...
        'function [Kp, Kd] = fcn(d)\n' ...
        '%%#codegen\n' ...
        'Kp = 10 + 5 * d;\n' ...
        'Kd =  3 + 2 * d;\n' ...
        'end\n']);
    
    % Note: For actual embedded code, set via set_param after opening
    % set_param([mdl '/AdaptiveGainScheduler'], 'Script', gain_fn_code);

    %% --- PD CONTROLLER COMPONENTS ---
    % Proportional path: Gain block for Kp
    add_block('simulink/Math Operations/Product', [mdl '/KpMult'], ...
        'Position', [660, 130, 710, 180]);

    % Derivative path: s (approximate derivative: s/(0.01s+1))
    add_block('simulink/Continuous/Transfer Fcn', [mdl '/DerivFilter'], ...
        'Numerator', '[1, 0]', 'Denominator', '[0.01, 1]', ...
        'Position', [660, 220, 760, 260]);

    add_block('simulink/Math Operations/Product', [mdl '/KdMult'], ...
        'Position', [800, 220, 850, 260]);

    % Sum PD output
    add_block('simulink/Math Operations/Sum', [mdl '/PDSum'], ...
        'Inputs', '++', ...
        'Position', [880, 150, 920, 270]);

    %% --- SUSPENSION PLANT: G(s) = 1/(s^2+3s+2) ---
    add_block('simulink/Continuous/Transfer Fcn', [mdl '/SuspensionPlant'], ...
        'Numerator', '[1]', 'Denominator', '[1, 3, 2]', ...
        'Position', [960, 180, 1080, 240]);

    %% --- FEEDBACK SUBTRACTION ---
    add_block('simulink/Math Operations/Sum', [mdl '/ErrorSum'], ...
        'Inputs', '+-', ...
        'Position', [590, 170, 630, 220]);

    %% --- OUTPUT SCOPES ---
    add_block('simulink/Sinks/Scope', [mdl '/DisplacementScope'], ...
        'Position', [1130, 165, 1180, 255]);
    set_param([mdl '/DisplacementScope'], 'NumInputPorts', '1');
    
    add_block('simulink/Sinks/Scope', [mdl '/ControlScope'], ...
        'Position', [940, 100, 990, 140]);

    add_block('simulink/Sinks/Scope', [mdl '/GainScope'], ...
        'Position', [660, 50, 710, 90]);
    set_param([mdl '/GainScope'], 'NumInputPorts', '2');

    %% --- TO WORKSPACE blocks for post-processing ---
    add_block('simulink/Sinks/To Workspace', [mdl '/YOut'], ...
        'VariableName', 'y_sim', 'MaxDataPoints', 'inf', ...
        'Position', [1130, 280, 1180, 320]);

    add_block('simulink/Sinks/To Workspace', [mdl '/UOut'], ...
        'VariableName', 'u_sim', 'MaxDataPoints', 'inf', ...
        'Position', [940, 280, 990, 320]);

    %% --- CONNECT BLOCKS ---
    % Disturbance -> ErrorSum (reference input)
    add_line(mdl, 'RoadBump/1',    'DistMux/1');
    add_line(mdl, 'SineRoad/1',    'DistMux/2');
    add_line(mdl, 'DistMux/1',     'DistSum/1');
    add_line(mdl, 'DistSum/1',     'DistAbs/1');
    add_line(mdl, 'DistAbs/1',     'LPFilter/1');
    add_line(mdl, 'LPFilter/1',    'AdaptiveGainScheduler/1');
    
    % Gains to scope
    add_line(mdl, 'AdaptiveGainScheduler/1', 'GainScope/1');
    add_line(mdl, 'AdaptiveGainScheduler/2', 'GainScope/2');
    
    % Error signal
    add_line(mdl, 'DistSum/1',     'ErrorSum/1');
    
    % Controller paths
    add_line(mdl, 'ErrorSum/1',    'KpMult/1');
    add_line(mdl, 'AdaptiveGainScheduler/1', 'KpMult/2');
    add_line(mdl, 'ErrorSum/1',    'DerivFilter/1');
    add_line(mdl, 'DerivFilter/1', 'KdMult/1');
    add_line(mdl, 'AdaptiveGainScheduler/2', 'KdMult/2');
    add_line(mdl, 'KpMult/1',      'PDSum/1');
    add_line(mdl, 'KdMult/1',      'PDSum/2');
    
    % Control to scope and plant
    add_line(mdl, 'PDSum/1',       'ControlScope/1');
    add_line(mdl, 'PDSum/1',       'SuspensionPlant/1');
    
    % Plant output to scope and feedback
    add_line(mdl, 'SuspensionPlant/1', 'DisplacementScope/1');
    add_line(mdl, 'SuspensionPlant/1', 'ErrorSum/2');
    add_line(mdl, 'SuspensionPlant/1', 'YOut/1');
    add_line(mdl, 'PDSum/1',           'UOut/1');

    %% --- SIMULATION SETTINGS ---
    set_param(mdl, 'Solver', 'ode45');
    set_param(mdl, 'StopTime', '20');
    set_param(mdl, 'MaxStep',  '0.01');
    set_param(mdl, 'RelTol',   '1e-4');
    
    % Save model
    save_system(mdl);
    fprintf('Simulink model "%s" built and saved successfully.\n', mdl);
    fprintf('Open via: open_system(''%s'')\n', mdl);
    fprintf('Simulate via: sim(''%s'')\n', mdl);
end
