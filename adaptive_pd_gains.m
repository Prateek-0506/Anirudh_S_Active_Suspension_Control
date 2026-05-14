function [Kp, Kd, mode, pred_Kp, pred_Kd] = adaptive_pd_gains(disturbance_magnitude)
%% ADAPTIVE_PD_GAINS  Compute reactive AND predictive PD gains
%
%  Usage:
%    [Kp, Kd, mode, pred_Kp, pred_Kd] = adaptive_pd_gains(disturbance_magnitude)
%
%  Reactive schedule  : Kp=25+10·d,  Kd=20+8·d
%  Predictive schedule: Kp=25+12·d,  Kd=20+10·d  (higher headroom)
%
%  Modes:
%    Comfort  (d<0.30): smooth roads, soft damping
%    Off-Road (0.30≤d<0.65): medium disturbance, balanced
%    Sport    (d≥0.65): severe, aggressive stabilisation

    %% Reactive gains
    Kp = 25 + 10 .* disturbance_magnitude;
    Kd = 20 +  8 .* disturbance_magnitude;

    %% Predictive gains (pre-emptively higher)
    pred_Kp = 25 + 12 .* disturbance_magnitude;
    pred_Kd = 20 + 10 .* disturbance_magnitude;

    %% Mode classification
    if isscalar(disturbance_magnitude)
        if disturbance_magnitude < 0.30
            mode = 'Comfort';
        elseif disturbance_magnitude < 0.65
            mode = 'Off-Road';
        else
            mode = 'Sport';
        end
    else
        mode = cell(size(disturbance_magnitude));
        for i = 1:numel(disturbance_magnitude)
            if disturbance_magnitude(i) < 0.30
                mode{i} = 'Comfort';
            elseif disturbance_magnitude(i) < 0.65
                mode{i} = 'Off-Road';
            else
                mode{i} = 'Sport';
            end
        end
    end
end
