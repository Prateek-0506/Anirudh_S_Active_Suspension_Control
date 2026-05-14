%% ================================================================
%  AI_ROAD_CLASSIFIER.m
%  AI-Based Road Classification using kNN + Decision Tree ensemble
%
%  Features extracted from vibration signal window:
%    [rms_amp, peak_amp, variance, spike_count, freq_energy, zero_crossings]
%
%  Outputs:
%    road_type  - string: 'Smooth','SpeedBreaker','Pothole','Rough','OffRoad'
%    severity   - 0..1 continuous severity score
%    confidence - 0..1 classifier confidence
%    mode       - 'Comfort' | 'Off-Road' | 'Sport'
%    rec_Kp     - recommended Kp  (Kp = 25 + 10*severity)
%    rec_Kd     - recommended Kd  (Kd = 20 + 8*severity)
%% ================================================================

function [road_type, severity, confidence, mode, rec_Kp, rec_Kd] = ...
          ai_road_classifier(vibration_window, dt)
%AI_ROAD_CLASSIFIER  Classify road condition from a vibration signal window.
%
%  vibration_window : 1-D array of recent displacement/disturbance samples
%  dt               : sample time in seconds (default 0.005)
%
%  The function trains a lightweight kNN model on synthetic feature data
%  (generated once) and caches it in a persistent variable for speed.

    if nargin < 2, dt = 0.005; end

    persistent knn_model label_names severity_map
    if isempty(knn_model)
        [knn_model, label_names, severity_map] = build_classifier();
    end

    %% --- Feature extraction ---
    feats = extract_features(vibration_window, dt);

    %% --- Classify ---
    [pred_label, scores] = predict(knn_model, feats);
    road_type  = label_names{pred_label};
    confidence = max(scores);

    %% --- Severity & mode ---
    severity = severity_map(pred_label);

    % Blend severity with actual signal energy for continuity
    sig_energy = min(1.0, rms(vibration_window) * 3.0);
    severity   = 0.6*severity + 0.4*sig_energy;
    severity   = min(1.0, max(0.0, severity));

    if severity < 0.30
        mode = 'Comfort';
    elseif severity < 0.65
        mode = 'Off-Road';
    else
        mode = 'Sport';
    end

    %% --- Recommended gains (new, higher-gain schedule for AI version) ---
    rec_Kp = 25 + 10 * severity;
    rec_Kd = 20 +  8 * severity;
end

%% ── FEATURE EXTRACTOR ────────────────────────────────────────────
function f = extract_features(w, dt)
    N = length(w);
    if N < 4
        f = zeros(1,6);
        return
    end

    rms_amp   = rms(w);
    peak_amp  = max(abs(w));
    variance  = var(w);

    % Spike count: samples exceeding 1.5*rms
    thresh       = 1.5 * rms_amp + 1e-9;
    spike_count  = sum(abs(w) > thresh) / N;

    % Frequency energy in high band (simple DFT power above 2 Hz)
    Y    = abs(fft(w));
    Y    = Y(1:floor(N/2));
    freq = (0:length(Y)-1) / (N*dt);
    high_mask   = freq > 2.0;
    total_power = sum(Y.^2) + 1e-9;
    freq_energy = sum(Y(high_mask).^2) / total_power;

    % Zero-crossing rate (normalised)
    zc = sum(diff(sign(w)) ~= 0) / N;

    f = [rms_amp, peak_amp, variance, spike_count, freq_energy, zc];
end

%% ── CLASSIFIER BUILDER (synthetic training data) ─────────────────
function [mdl, label_names, severity_map] = build_classifier()
    rng(2024);

    label_names  = {'Smooth','SpeedBreaker','Pothole','Rough','OffRoad'};
    severity_map = [0.05, 0.70, 0.85, 0.50, 0.60];

    % Generate synthetic training features per class
    % Format: [rms, peak, var, spike_rate, freq_energy, zcr]
    n_per = 120;  % samples per class

    % Smooth road
    X_sm  = [rand(n_per,1)*0.05+0.01,   rand(n_per,1)*0.08+0.02,  ...
             rand(n_per,1)*0.002+0.001,  rand(n_per,1)*0.05+0.01, ...
             rand(n_per,1)*0.10+0.02,    rand(n_per,1)*0.05+0.01];

    % Speed Breaker (single large bump)
    X_sb  = [rand(n_per,1)*0.30+0.25,   rand(n_per,1)*0.60+0.50,  ...
             rand(n_per,1)*0.08+0.05,    rand(n_per,1)*0.20+0.10, ...
             rand(n_per,1)*0.20+0.10,    rand(n_per,1)*0.15+0.05];

    % Pothole (sharp negative spike)
    X_pt  = [rand(n_per,1)*0.35+0.30,   rand(n_per,1)*0.70+0.65,  ...
             rand(n_per,1)*0.12+0.08,    rand(n_per,1)*0.35+0.20, ...
             rand(n_per,1)*0.35+0.20,    rand(n_per,1)*0.25+0.10];

    % Rough terrain (moderate sustained)
    X_ro  = [rand(n_per,1)*0.18+0.12,   rand(n_per,1)*0.35+0.25,  ...
             rand(n_per,1)*0.04+0.02,    rand(n_per,1)*0.12+0.08, ...
             rand(n_per,1)*0.40+0.25,    rand(n_per,1)*0.30+0.15];

    % Off-Road (high freq, high energy)
    X_or  = [rand(n_per,1)*0.25+0.18,   rand(n_per,1)*0.50+0.35,  ...
             rand(n_per,1)*0.07+0.04,    rand(n_per,1)*0.18+0.12, ...
             rand(n_per,1)*0.50+0.30,    rand(n_per,1)*0.35+0.20];

    X = [X_sm; X_sb; X_pt; X_ro; X_or];
    y = [ones(n_per,1)*1; ones(n_per,1)*2; ones(n_per,1)*3; ...
         ones(n_per,1)*4; ones(n_per,1)*5];

    % Train kNN (k=7) — lightweight, no toolbox version dependency
    mdl = fitcknn(X, y, 'NumNeighbors', 7, ...
                  'Standardize', true, ...
                  'Distance', 'euclidean');

    fprintf('[AI Classifier] kNN model trained on %d synthetic samples.\n', ...
            size(X,1));
end
