function [pred_severity, pred_Kp, pred_Kd, lookahead_mode] = ...
          predictive_suspension(win_buf, road_type, current_severity, dt)
%% ================================================================
%  PREDICTIVE_SUSPENSION.m
%  True Predictive / Feedforward Suspension Logic
%
%  Analyses the vibration window to ANTICIPATE disturbances before
%  they develop into large oscillations.  Outputs pre-emptively
%  stiffened gains whenever a rising trend or pattern is detected.
%
%  Inputs:
%    win_buf          – recent vibration / disturbance window (1-D)
%    road_type        – current AI road classification string
%    current_severity – severity from AI classifier (0..1)
%    dt               – sample period (s)
%
%  Outputs:
%    pred_severity    – predicted future severity (0..1)
%    pred_Kp          – predictive proportional gain
%    pred_Kd          – predictive derivative gain
%    lookahead_mode   – 'Anticipate' | 'React' | 'Relax'
%% ================================================================

    if nargin < 4, dt = 0.005; end

    N = length(win_buf);
    if N < 10
        pred_severity = current_severity;
        pred_Kp = 25 + 10*current_severity;
        pred_Kd = 20 +  8*current_severity;
        lookahead_mode = 'React';
        return;
    end

    %% ── 1. Trend detection (linear regression slope on last half window) ──
    half = max(4, floor(N/2));
    recent = win_buf(end-half+1:end);
    t_vec  = (0:half-1)' * dt;
    p      = polyfit(t_vec, recent(:), 1);
    slope  = p(1);          % positive slope → rising disturbance

    %% ── 2. Rate of change (first derivative mean) ──
    d_win  = diff(win_buf) / dt;
    mean_rate = mean(abs(d_win(end-min(10,length(d_win))+1:end)));

    %% ── 3. Burst detection (variance spike in recent vs full window) ──
    var_full   = var(win_buf) + 1e-9;
    var_recent = var(recent)  + 1e-9;
    var_ratio  = var_recent / var_full;   % >1.5 → growing variance

    %% ── 4. Pattern-based road lookahead ──
    % Each road type has a known disturbance signature; pre-empt accordingly
    road_anticipation = 0;
    switch road_type
        case 'SpeedBreaker'
            % Bumps are periodic – anticipate the next bump
            road_anticipation = 0.30 * (current_severity > 0.3);
        case 'Pothole'
            % Sharp impulse – pre-stiffen immediately on any rising edge
            road_anticipation = 0.40 * (slope > 0.05);
        case 'Rough'
            % Sustained – keep pre-emptive gain moderately elevated
            road_anticipation = 0.20;
        case 'OffRoad'
            % Chaotic – always pre-stiffened
            road_anticipation = 0.25;
        otherwise
            road_anticipation = 0;
    end

    %% ── 5. Compute predicted severity ──
    slope_contribution = min(0.5, max(0, slope * 2.0));   % normalise slope
    rate_contribution  = min(0.3, mean_rate * 0.5);
    var_contribution   = min(0.2, (var_ratio - 1) * 0.15);

    pred_severity = current_severity ...
                  + slope_contribution ...
                  + rate_contribution  ...
                  + var_contribution   ...
                  + road_anticipation;

    pred_severity = min(1.0, max(0.0, pred_severity));

    %% ── 6. Lookahead mode labelling ──
    delta = pred_severity - current_severity;
    if delta > 0.15
        lookahead_mode = 'Anticipate';   % actively pre-stiffening
    elseif delta > 0.03
        lookahead_mode = 'React';        % mild increase
    else
        lookahead_mode = 'Relax';        % stable / decreasing
    end

    %% ── 7. Predictive gain schedule ──
    % Predictive gains are higher than reactive gains to front-load damping
    pred_Kp = 25 + 12 * pred_severity;   % +2 headroom vs reactive schedule
    pred_Kd = 20 + 10 * pred_severity;   % +2 headroom vs reactive schedule

end
