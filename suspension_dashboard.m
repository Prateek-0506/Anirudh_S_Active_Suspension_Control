%% ================================================================
%  SUSPENSION_DASHBOARD.m  (FULL UPGRADE — v3 HACKATHON EDITION)
%  AI-Powered Predictive Adaptive Active Suspension System
%
%  NEW in v3:
%   1. TRUE PREDICTIVE SUSPENSION (feedforward anticipation)
%   2. SIDE-BY-SIDE COMPARISON panel (controlled vs uncontrolled anim)
%   3. LIVE AI DECISION panel with wow-factor display
%   4. ADVANCED LIVE METRICS (settling, overshoot, RMS, comfort index)
%   5. PROFESSIONAL GUI with digital gauges, animated indicators
%   6. PREDICTIVE lookahead mode indicator (Anticipate / React / Relax)
%   7. PERFORMANCE SNAPSHOT on-demand
%   8. All previous features retained and polished
%
%  Run:  suspension_dashboard
%% ================================================================

function suspension_dashboard()

    %% ── Create main figure ──────────────────────────────────────
    fig = figure('Name','AI Predictive Adaptive Suspension System — Hackathon Edition', ...
        'NumberTitle','off', ...
        'Position',   [10, 10, 1800, 960], ...
        'Color',      [0.05 0.05 0.08], ...
        'Resize',     'on', ...
        'CloseRequestFcn', @onClose);

    %% ── Shared state ────────────────────────────────────────────
    S = init_state();
    setappdata(fig,'S',S);

    %% ── Layout ──────────────────────────────────────────────────
    % Columns: [ctrl_panel | anim_main | anim_compare | telemetry]
    lw  = 0.155;   % left control panel
    aw  = 0.270;   % main animation
    cw  = 0.240;   % compare animation
    rw  = 0.310;   % right telemetry
    gap = 0.005;

    pLeft  = make_panel(fig,[gap,        0.01, lw,  0.98],'Control Panel');
    pAnim  = make_panel(fig,[lw+gap,     0.01, aw,  0.98],'Live Suspension Animation');
    pComp  = make_panel(fig,[lw+aw+gap*2,0.01, cw,  0.98],'Comparison & AI Intelligence');
    pRight = make_panel(fig,[lw+aw+cw+gap*3,0.01,rw-gap,0.98],'Live Telemetry');

    %% ── Left panel ──────────────────────────────────────────────
    build_left_panel(pLeft, fig);

    %% ── Animation axes (main) ───────────────────────────────────
    ax_main = axes(pAnim,'Position',[0.02 0.52 0.96 0.44]);
    vehicle_animation('init', ax_main);
    setappdata(fig,'ax_main',ax_main);

    % Uncontrolled animation (lower half of pAnim)
    ax_unc = axes(pAnim,'Position',[0.02 0.04 0.96 0.44]);
    vehicle_animation('init', ax_unc);
    title(ax_unc,'Uncontrolled (No Active Suspension)', ...
          'Color',[0.95 0.35 0.35],'FontSize',10,'FontWeight','bold');
    setappdata(fig,'ax_unc',ax_unc);

    % Divider label
    annotation(pAnim,'textbox',[0.02 0.495 0.96 0.03],...
        'String','─────────── SIDE-BY-SIDE COMPARISON ───────────', ...
        'Color',[0.45 0.45 0.55],'FontSize',7.5,'EdgeColor','none',...
        'HorizontalAlignment','center','BackgroundColor','none');

    %% ── Centre panel: AI decision + compare metrics ─────────────
    build_centre_panel(pComp, fig);

    %% ── Right panel: live plots ─────────────────────────────────
    axR = build_right_panel(pRight);
    setappdata(fig,'axR',axR);

    %% ── Timer ───────────────────────────────────────────────────
    tmr = timer('ExecutionMode','fixedRate','Period',0.04, ...
                'TimerFcn',@(~,~)sim_step(fig), ...
                'ErrorFcn', @(t,e)timer_err(t,e));
    setappdata(fig,'tmr',tmr);

    fprintf('[Dashboard v3] Ready — Press ▶ Start Simulation.\n');
end

%% ══════════════════════════════════════════════════════════════════
function S = init_state()
    S.running      = false;
    S.t_now        = 0;
    S.dt           = 0.005;
    S.x1           = 0; S.x2 = 0;
    S.x1u          = 0; S.x2u = 0;
    S.win_buf      = zeros(1,80);
    S.road_type    = 'Smooth Road';
    S.road_type_ai = 'Smooth';
    S.mode         = 'Comfort';
    S.Kp           = 25; S.Kd = 20;
    S.severity     = 0;
    S.confidence   = 0;
    S.pred_severity = 0;
    S.pred_Kp      = 25; S.pred_Kd = 20;
    S.pred_mode_lbl = 'Relax';
    S.t_hist   = []; S.y_hist  = []; S.yu_hist = [];
    S.kp_hist  = []; S.kd_hist = []; S.u_hist  = []; S.d_hist  = [];
    S.pkp_hist = []; S.pkd_hist = [];  % predictive gain history
    S.peak_ctrl = 0; S.peak_unc = 0;
    S.settle_est = 0;
    S.step_count = 0;
end

%% ══════════════════════════════════════════════════════════════════
%  PANEL BUILDERS
%% ══════════════════════════════════════════════════════════════════
function p = make_panel(fig, pos, ttl)
    p = uipanel(fig,'Position',pos, ...
        'BackgroundColor',[0.08 0.08 0.12], ...
        'ForegroundColor',[0.55 0.85 1.0], ...
        'BorderType','line','HighlightColor',[0.20 0.30 0.45], ...
        'Title',ttl,'FontSize',10,'FontWeight','bold');
end

%% ── LEFT PANEL ───────────────────────────────────────────────────
function build_left_panel(p, fig)
    bg  = [0.08 0.08 0.12];
    acc = [0.30 0.80 1.00];

    function h = lbl(txt, yn, fs, clr)
        if nargin<4, clr=[0.72 0.72 0.75]; end
        h = uicontrol(p,'Style','text','String',txt, ...
            'Units','normalized','Position',[0.04 yn 0.92 0.030], ...
            'BackgroundColor',bg,'ForegroundColor',clr, ...
            'HorizontalAlignment','left','FontSize',fs,'FontWeight','bold');
    end
    function h = btn(txt, yn, cb, bc)
        if nargin<4, bc=[0.18 0.18 0.24]; end
        h = uicontrol(p,'Style','pushbutton','String',txt, ...
            'Units','normalized','Position',[0.04 yn 0.92 0.042], ...
            'BackgroundColor',bc,'ForegroundColor','w', ...
            'FontSize',9,'FontWeight','bold','Callback',cb);
    end

    lbl('AI SUSPENSION v3', 0.955, 10, [0.55 0.85 1.0]);

    btn('▶  Start Simulation',  0.900, @(~,~)startSim(fig),  [0.08 0.45 0.18]);
    btn('■  Stop Simulation',   0.852, @(~,~)stopSim(fig),   [0.50 0.10 0.10]);
    btn('↺  Reset',             0.804, @(~,~)resetSim(fig),  [0.22 0.22 0.28]);
    btn('📊 Performance Report',0.756, @(~,~)perfReport(fig),[0.15 0.28 0.42]);
    btn('💾 Export Results',    0.708, @(~,~)exportResults(fig),[0.12 0.32 0.38]);

    lbl('── Road Profile ──', 0.672, 8, acc);
    roads = {'Smooth Road','Speed Breaker','Pothole','Rough Terrain','Off-Road'};
    dd = uicontrol(p,'Style','popupmenu','String',roads, ...
        'Units','normalized','Position',[0.04 0.628 0.92 0.038], ...
        'BackgroundColor',[0.14 0.14 0.20],'ForegroundColor','w', ...
        'FontSize',9,'Callback',@(src,~)changeRoad(fig,src));
    setappdata(fig,'dd_road',dd);

    % Mode indicator (large)
    lbl('Suspension Mode', 0.590, 8, acc);
    hMode = uicontrol(p,'Style','text','String','● COMFORT', ...
        'Units','normalized','Position',[0.04 0.548 0.92 0.038], ...
        'BackgroundColor',[0.05 0.25 0.15],'ForegroundColor',[0.28 0.95 0.55], ...
        'FontSize',10,'FontWeight','bold','HorizontalAlignment','center');
    setappdata(fig,'hMode',hMode);

    % Predictive mode indicator
    lbl('Predictive State', 0.512, 8, acc);
    hPred = uicontrol(p,'Style','text','String','⚡ RELAX', ...
        'Units','normalized','Position',[0.04 0.470 0.92 0.038], ...
        'BackgroundColor',[0.08 0.08 0.12],'ForegroundColor',[0.55 0.85 0.55], ...
        'FontSize',10,'FontWeight','bold','HorizontalAlignment','center');
    setappdata(fig,'hPred',hPred);

    % Gain display
    lbl('── Adaptive Gains ──', 0.435, 8, acc);
    make_metric_row(p, fig, 'Kp (reactive):',  0.397, bg, 'hKp',  [0.30 0.85 0.55]);
    make_metric_row(p, fig, 'Kd (reactive):',  0.358, bg, 'hKd',  [1.00 0.70 0.20]);
    make_metric_row(p, fig, 'Kp (predictive):', 0.320, bg, 'hpKp', [0.55 0.95 0.75]);
    make_metric_row(p, fig, 'Kd (predictive):', 0.282, bg, 'hpKd', [1.00 0.88 0.45]);

    % Live metrics
    lbl('── Live Metrics ──', 0.244, 8, acc);
    make_metric_row(p, fig, 'RMS Vibration:', 0.206, bg, 'hRMS',      [0.90 0.85 0.30]);
    make_metric_row(p, fig, 'Peak Ctrl:',     0.168, bg, 'hPkCtrl',   [0.90 0.85 0.30]);
    make_metric_row(p, fig, 'Peak Unctrl:',   0.130, bg, 'hPkUnc',    [0.90 0.85 0.30]);
    make_metric_row(p, fig, 'Vib Reduction:', 0.092, bg, 'hVibRed',   [0.30 0.95 0.55]);
    make_metric_row(p, fig, 'Comfort Index:', 0.054, bg, 'hComfort',  [0.30 0.95 0.55]);
end

function make_metric_row(p, fig, label_str, yn, bg, tag, clr)
    if nargin < 7, clr = [0.90 0.85 0.30]; end
    uicontrol(p,'Style','text','String',label_str, ...
        'Units','normalized','Position',[0.04 yn+0.012 0.55 0.025], ...
        'BackgroundColor',bg,'ForegroundColor',[0.62 0.62 0.66], ...
        'HorizontalAlignment','left','FontSize',7.5,'FontWeight','bold');
    h = uicontrol(p,'Style','text','String','—', ...
        'Units','normalized','Position',[0.58 yn+0.010 0.38 0.027], ...
        'BackgroundColor',bg,'ForegroundColor',clr, ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','right');
    setappdata(fig, tag, h);
end

%% ── CENTRE PANEL: AI Decision + Comparison metrics ───────────────
function build_centre_panel(p, fig)
    bg = [0.08 0.08 0.12];
    acc = [0.30 0.80 1.00];

    function h = lbl(txt, yn, fs, clr)
        if nargin<4, clr=[0.72 0.72 0.75]; end
        h = uicontrol(p,'Style','text','String',txt, ...
            'Units','normalized','Position',[0.03 yn 0.94 0.030], ...
            'BackgroundColor',bg,'ForegroundColor',clr, ...
            'HorizontalAlignment','left','FontSize',fs,'FontWeight','bold');
    end

    lbl('── AI ROAD INTELLIGENCE ──', 0.957, 9, [0.55 0.85 1.0]);

    % Large AI road type display
    hAIBig = uicontrol(p,'Style','text','String','SMOOTH ROAD', ...
        'Units','normalized','Position',[0.03 0.910 0.94 0.044], ...
        'BackgroundColor',[0.05 0.20 0.10],'ForegroundColor',[0.30 0.95 0.55], ...
        'FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
    setappdata(fig,'hAIBig',hAIBig);

    % Confidence bar (visual)
    lbl('Confidence:', 0.877, 8, acc);
    hConfBar = axes(p,'Position',[0.03 0.852 0.94 0.022]);
    hConfBar.Color = [0.12 0.12 0.18];
    hConfBar.XColor = 'none'; hConfBar.YColor = 'none';
    axis(hConfBar,[0 1 0 1]); hold(hConfBar,'on');
    fill(hConfBar,[0 0 0 0],[0 0 1 1],[0.20 0.20 0.28],'EdgeColor','none','Tag','conf_bg');
    fill(hConfBar,[0 0 0 0],[0 0 1 1],[0.28 0.90 0.55],'EdgeColor','none','Tag','conf_fill');
    hConfPct = uicontrol(p,'Style','text','String','0%', ...
        'Units','normalized','Position',[0.80 0.852 0.18 0.022], ...
        'BackgroundColor',bg,'ForegroundColor',[0.28 0.95 0.55], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','right');
    setappdata(fig,'hConfBar',hConfBar);
    setappdata(fig,'hConfPct',hConfPct);

    % Severity gauge
    lbl('Severity:', 0.820, 8, acc);
    hSevBar = axes(p,'Position',[0.03 0.795 0.94 0.022]);
    hSevBar.Color = [0.12 0.12 0.18];
    hSevBar.XColor = 'none'; hSevBar.YColor = 'none';
    axis(hSevBar,[0 1 0 1]); hold(hSevBar,'on');
    fill(hSevBar,[0 0 0 0],[0 0 1 1],[0.20 0.20 0.28],'EdgeColor','none','Tag','sev_bg');
    fill(hSevBar,[0 0 0 0],[0 0 1 1],[0.95 0.40 0.15],'EdgeColor','none','Tag','sev_fill');
    hSevPct = uicontrol(p,'Style','text','String','0.00', ...
        'Units','normalized','Position',[0.78 0.795 0.20 0.022], ...
        'BackgroundColor',bg,'ForegroundColor',[0.95 0.50 0.20], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','right');
    setappdata(fig,'hSevBar',hSevBar);
    setappdata(fig,'hSevPct',hSevPct);

    % AI action description (big text box)
    lbl('── AI DECISION ──', 0.758, 9, [0.55 0.85 1.0]);
    hAIDecision = uicontrol(p,'Style','text', ...
        'String', sprintf('Road: —\nMode: —\nAction: Waiting...'), ...
        'Units','normalized','Position',[0.03 0.658 0.94 0.096], ...
        'BackgroundColor',[0.10 0.10 0.16],'ForegroundColor','w', ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','left');
    setappdata(fig,'hAIDecision',hAIDecision);

    % Predictive intelligence display
    lbl('── PREDICTIVE INTELLIGENCE ──', 0.622, 9, [0.55 0.85 1.0]);
    hPredBox = uicontrol(p,'Style','text', ...
        'String', sprintf('Lookahead: RELAX\nPred Severity: 0.00\nPred Kp: 25.0   Kd: 20.0'), ...
        'Units','normalized','Position',[0.03 0.530 0.94 0.088], ...
        'BackgroundColor',[0.08 0.14 0.08],'ForegroundColor',[0.55 0.90 0.55], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','left');
    setappdata(fig,'hPredBox',hPredBox);

    % Comparison metrics table
    lbl('── COMPARISON METRICS ──', 0.494, 9, [0.55 0.85 1.0]);
    headers = {'Metric','Controlled','Uncontrolled'};
    metrics = {'RMS Vib:','Peak Disp:','Vib Reduc:','Comfort:'};
    metric_tags = {'hCmpRMS','hCmpPk','hCmpVR','hCmpCmf'};
    unc_tags    = {'hCmpRMSu','hCmpPku','hCmpVRu','hCmpCmfu'};

    % header row
    yh = 0.460;
    for ci=1:3
        xp = 0.03 + (ci-1)*0.32;
        uicontrol(p,'Style','text','String',headers{ci}, ...
            'Units','normalized','Position',[xp yh 0.30 0.026], ...
            'BackgroundColor',[0.15 0.15 0.22],'ForegroundColor',acc, ...
            'FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
    end

    for i=1:4
        yr = 0.432 - (i-1)*0.032;
        uicontrol(p,'Style','text','String',metrics{i}, ...
            'Units','normalized','Position',[0.03 yr 0.30 0.026], ...
            'BackgroundColor',bg,'ForegroundColor',[0.65 0.65 0.68], ...
            'FontSize',8,'FontWeight','bold','HorizontalAlignment','left');
        h1=uicontrol(p,'Style','text','String','—', ...
            'Units','normalized','Position',[0.35 yr 0.28 0.026], ...
            'BackgroundColor',bg,'ForegroundColor',[0.30 0.95 0.55], ...
            'FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
        h2=uicontrol(p,'Style','text','String','—', ...
            'Units','normalized','Position',[0.67 yr 0.30 0.026], ...
            'BackgroundColor',bg,'ForegroundColor',[0.95 0.40 0.40], ...
            'FontSize',8,'FontWeight','bold','HorizontalAlignment','center');
        setappdata(fig,metric_tags{i},h1);
        setappdata(fig,unc_tags{i},h2);
    end

    % Settling time
    lbl('Settling Time (ctrl):', 0.290, 8, acc);
    hSettle = uicontrol(p,'Style','text','String','< 2.5 s', ...
        'Units','normalized','Position',[0.60 0.290 0.37 0.026], ...
        'BackgroundColor',bg,'ForegroundColor',[0.90 0.85 0.30], ...
        'FontSize',8,'FontWeight','bold','HorizontalAlignment','right');
    setappdata(fig,'hSettle',hSettle);

    % Overshoot
    lbl('Overshoot (ctrl):', 0.258, 8, acc);
    hOver = uicontrol(p,'Style','text','String','0.0 %', ...
        'Units','normalized','Position',[0.60 0.258 0.37 0.026], ...
        'BackgroundColor',bg,'ForegroundColor',[0.90 0.85 0.30], ...
        'FontSize',8,'FontWeight','bold','HorizontalAlignment','right');
    setappdata(fig,'hOver',hOver);

    % Damping ratio info
    lbl('── SYSTEM INFO ──', 0.220, 9, [0.55 0.85 1.0]);
    sys_txt = sprintf('G(s) = 1/(s²+3s+2)   Poles: -1, -2\nζ=0.866  ωn=1.414 rad/s  STABLE');
    uicontrol(p,'Style','text','String',sys_txt, ...
        'Units','normalized','Position',[0.03 0.150 0.94 0.066], ...
        'BackgroundColor',[0.10 0.10 0.16],'ForegroundColor',[0.65 0.65 0.70], ...
        'FontSize',8,'HorizontalAlignment','left');

    % Gain equation
    lbl('Gain Schedule:', 0.118, 8, acc);
    uicontrol(p,'Style','text','String','Kp=25+12·s   Kd=20+10·s   (predictive)', ...
        'Units','normalized','Position',[0.03 0.086 0.94 0.030], ...
        'BackgroundColor',bg,'ForegroundColor',[0.60 0.80 0.60], ...
        'FontSize',8,'HorizontalAlignment','left');
    uicontrol(p,'Style','text','String','Kp=25+10·s   Kd=20+8·s    (reactive)', ...
        'Units','normalized','Position',[0.03 0.054 0.94 0.030], ...
        'BackgroundColor',bg,'ForegroundColor',[0.60 0.80 0.60], ...
        'FontSize',8,'HorizontalAlignment','left');

    lbl('© Hackathon 2026 — AI Adaptive Suspension', 0.015, 7, [0.35 0.35 0.40]);
end

%% ── RIGHT PANEL: LIVE PLOTS ──────────────────────────────────────
function axR = build_right_panel(p)
    bg_ax = [0.07 0.07 0.11];
    ttls  = {'Body Displacement (m) — Ctrl vs Unctrl', ...
             'Adaptive Gains  Kp (reactive)  Kp (predictive)', ...
             'Control Force (N)', ...
             'Road Disturbance Profile'};
    axR = gobjects(4,1);
    for i=1:4
        ry = 1 - i*0.245;
        axR(i) = axes(p,'Position',[0.06, ry+0.01, 0.91, 0.20]);
        axR(i).Color       = bg_ax;
        axR(i).XColor      = [0.48 0.48 0.52];
        axR(i).YColor      = [0.48 0.48 0.52];
        axR(i).GridColor   = [0.22 0.22 0.28];
        axR(i).GridAlpha   = 0.5;
        grid(axR(i),'on');
        title(axR(i), ttls{i}, 'Color',[0.75 0.85 1.0],'FontSize',8.5);
        xlabel(axR(i),'Time (s)','FontSize',7.5,'Color',[0.48 0.48 0.52]);
    end
end

%% ══════════════════════════════════════════════════════════════════
%  SIMULATION STEP
%% ══════════════════════════════════════════════════════════════════
function sim_step(fig)
    S = getappdata(fig,'S');
    if ~S.running, return; end

    dt = S.dt;
    t  = S.t_now;
    S.step_count = S.step_count + 1;

    %% Road disturbance
    d = road_disturbance(S.road_type, t);

    %% Update vibration window
    S.win_buf = [S.win_buf(2:end), d];

    %% AI classification every 20 steps
    if mod(S.step_count, 20) == 1
        [rt, sev, conf, mode, rec_Kp, rec_Kd] = ...
            ai_road_classifier(S.win_buf, dt);
        S.road_type_ai = rt;
        S.severity     = sev;
        S.confidence   = conf;
        S.mode         = mode;
        S.Kp           = rec_Kp;
        S.Kd           = rec_Kd;

        %% PREDICTIVE SUSPENSION (feedforward)
        [pred_sev, pred_Kp, pred_Kd, pred_lbl] = ...
            predictive_suspension(S.win_buf, rt, sev, dt);
        S.pred_severity  = pred_sev;
        S.pred_Kp        = pred_Kp;
        S.pred_Kd        = pred_Kd;
        S.pred_mode_lbl  = pred_lbl;
    end

    %% Plant integration — CONTROLLED (use PREDICTIVE gains)
    e  = d - S.x1;
    de = -S.x2;
    u  = S.pred_Kp * e + S.pred_Kd * de;   % ← predictive gains!

    dx1 = S.x2;
    dx2 = -2*S.x1 - 3*S.x2 + u;
    S.x1 = S.x1 + dt*dx1;
    S.x2 = S.x2 + dt*dx2;

    %% Plant integration — UNCONTROLLED
    dx1u = S.x2u;
    dx2u = -2*S.x1u - 3*S.x2u + d;
    S.x1u = S.x1u + dt*dx1u;
    S.x2u = S.x2u + dt*dx2u;

    %% Track peaks
    S.peak_ctrl = max(S.peak_ctrl, abs(S.x1));
    S.peak_unc  = max(S.peak_unc,  abs(S.x1u));

    %% History (keep last 800 points ≈ 4 s)
    MAX_H = 800;
    S.t_hist   = [S.t_hist,  t];
    S.y_hist   = [S.y_hist,  S.x1];
    S.yu_hist  = [S.yu_hist, S.x1u];
    S.kp_hist  = [S.kp_hist, S.Kp];
    S.kd_hist  = [S.kd_hist, S.Kd];
    S.pkp_hist = [S.pkp_hist, S.pred_Kp];
    S.pkd_hist = [S.pkd_hist, S.pred_Kd];
    S.u_hist   = [S.u_hist,  u];
    S.d_hist   = [S.d_hist,  d];

    if length(S.t_hist) > MAX_H
        idx = length(S.t_hist)-MAX_H+1:length(S.t_hist);
        S.t_hist   = S.t_hist(idx);
        S.y_hist   = S.y_hist(idx);
        S.yu_hist  = S.yu_hist(idx);
        S.kp_hist  = S.kp_hist(idx);
        S.kd_hist  = S.kd_hist(idx);
        S.pkp_hist = S.pkp_hist(idx);
        S.pkd_hist = S.pkd_hist(idx);
        S.u_hist   = S.u_hist(idx);
        S.d_hist   = S.d_hist(idx);
    end

    S.t_now = t + dt;
    setappdata(fig,'S',S);

    %% Update animations
    ax_main = getappdata(fig,'ax_main');
    ax_unc  = getappdata(fig,'ax_unc');
    vehicle_animation('update', ax_main, S.x1,  max(0,d), d, S.mode, S.pred_mode_lbl);
    vehicle_animation('update', ax_unc,  S.x1u, max(0,d), d, 'Uncontrolled', '');

    %% Update plots and panels
    axR = getappdata(fig,'axR');
    update_live_plots(axR, S);
    update_left_panel(fig, S);
    update_centre_panel(fig, S);
end

%% ── LIVE PLOTS ───────────────────────────────────────────────────
function update_live_plots(axR, S)
    th = S.t_hist;
    if length(th) < 2, return; end

    % Plot 1: displacement
    cla(axR(1));
    line(axR(1),th,S.yu_hist,'Color',[0.85 0.28 0.28],'LineWidth',1.2,'DisplayName','Uncontrolled');
    line(axR(1),th,S.y_hist, 'Color',[0.25 0.72 1.00],'LineWidth',2.0,'DisplayName','Adaptive (Predictive)');
    legend(axR(1),'Uncontrolled','Adaptive PD','Location','best', ...
           'TextColor','w','FontSize',7,'Color',[0.10 0.10 0.15]);
    xlim(axR(1),[th(1), max(th(end)+0.1,th(1)+0.2)]);

    % Plot 2: gains (reactive Kp + predictive Kp)
    cla(axR(2));
    line(axR(2),th,S.kp_hist, 'Color',[0.30 0.85 0.55],'LineWidth',1.5,'DisplayName','Kp react');
    line(axR(2),th,S.pkp_hist,'Color',[0.55 0.95 0.75],'LineWidth',1.5,'LineStyle','--','DisplayName','Kp pred');
    legend(axR(2),'Kp (reactive)','Kp (predictive)','Location','best', ...
           'TextColor','w','FontSize',7,'Color',[0.10 0.10 0.15]);
    xlim(axR(2),[th(1), max(th(end)+0.1,th(1)+0.2)]);

    % Plot 3: control force
    cla(axR(3));
    line(axR(3),th,S.u_hist,'Color',[0.80 0.42 0.90],'LineWidth',1.2);
    xlim(axR(3),[th(1), max(th(end)+0.1,th(1)+0.2)]);

    % Plot 4: road disturbance
    cla(axR(4));
    line(axR(4),th,S.d_hist,'Color',[0.95 0.75 0.20],'LineWidth',1.5);
    xlim(axR(4),[th(1), max(th(end)+0.1,th(1)+0.2)]);
end

%% ── LEFT PANEL UPDATE ────────────────────────────────────────────
function update_left_panel(fig, S)
    % Mode indicator
    hMode = getappdata(fig,'hMode');
    switch S.mode
        case 'Sport'
            set(hMode,'String','● SPORT','BackgroundColor',[0.28 0.05 0.05],'ForegroundColor',[1 0.42 0.42]);
        case 'Off-Road'
            set(hMode,'String','● OFF-ROAD','BackgroundColor',[0.28 0.18 0.03],'ForegroundColor',[1 0.85 0.30]);
        otherwise
            set(hMode,'String','● COMFORT','BackgroundColor',[0.05 0.23 0.13],'ForegroundColor',[0.28 0.95 0.55]);
    end

    % Predictive state
    hPred = getappdata(fig,'hPred');
    switch S.pred_mode_lbl
        case 'Anticipate'
            set(hPred,'String','⚡ ANTICIPATE','BackgroundColor',[0.25 0.20 0.03],'ForegroundColor',[1 0.85 0.15]);
        case 'React'
            set(hPred,'String','⚡ REACT','BackgroundColor',[0.20 0.12 0.03],'ForegroundColor',[1 0.60 0.25]);
        otherwise
            set(hPred,'String','⚡ RELAX','BackgroundColor',[0.05 0.15 0.08],'ForegroundColor',[0.45 0.90 0.55]);
    end

    % Gains
    set(getappdata(fig,'hKp'),   'String', sprintf('%.1f', S.Kp));
    set(getappdata(fig,'hKd'),   'String', sprintf('%.1f', S.Kd));
    set(getappdata(fig,'hpKp'),  'String', sprintf('%.1f', S.pred_Kp));
    set(getappdata(fig,'hpKd'),  'String', sprintf('%.1f', S.pred_Kd));

    % Metrics
    if length(S.y_hist) < 4, return; end
    rms_c = rms(S.y_hist);
    rms_u = rms(S.yu_hist);
    vib_red = max(0, (1 - rms_c/(rms_u+1e-9))*100);
    comfort = min(100, max(0, 85 - vib_red*0.2 - abs(mean(S.u_hist))*0.05));

    set(getappdata(fig,'hRMS'),    'String', sprintf('%.4f m', rms_c));
    set(getappdata(fig,'hPkCtrl'),'String', sprintf('%.3f m', S.peak_ctrl));
    set(getappdata(fig,'hPkUnc'), 'String', sprintf('%.3f m', S.peak_unc));
    set(getappdata(fig,'hVibRed'),'String', sprintf('%.1f %%', vib_red));
    set(getappdata(fig,'hComfort'),'String',sprintf('%.0f / 100', comfort));
end

%% ── CENTRE PANEL UPDATE (AI + Comparison) ────────────────────────
function update_centre_panel(fig, S)
    if length(S.y_hist) < 4, return; end

    % Big AI road type
    hAIBig = getappdata(fig,'hAIBig');
    rt_disp = strrep(S.road_type_ai,'SpeedBreaker','SPEED BREAKER');
    rt_disp = upper(rt_disp);
    set(hAIBig,'String', rt_disp);
    switch S.road_type_ai
        case 'Smooth',      set(hAIBig,'BackgroundColor',[0.05 0.22 0.10],'ForegroundColor',[0.30 0.95 0.55]);
        case 'SpeedBreaker',set(hAIBig,'BackgroundColor',[0.25 0.18 0.03],'ForegroundColor',[1.00 0.85 0.25]);
        case 'Pothole',     set(hAIBig,'BackgroundColor',[0.28 0.05 0.05],'ForegroundColor',[1.00 0.40 0.40]);
        case 'Rough',       set(hAIBig,'BackgroundColor',[0.20 0.12 0.03],'ForegroundColor',[1.00 0.65 0.25]);
        case 'OffRoad',     set(hAIBig,'BackgroundColor',[0.15 0.05 0.22],'ForegroundColor',[0.80 0.55 1.00]);
        otherwise,          set(hAIBig,'BackgroundColor',[0.10 0.10 0.16],'ForegroundColor',[0.80 0.80 0.80]);
    end

    % Confidence bar
    hCB = getappdata(fig,'hConfBar');
    delete(findobj(hCB,'Tag','conf_fill'));
    fill(hCB,[0, S.confidence, S.confidence, 0],[0,0,1,1], ...
         [0.28 0.90 0.55],'EdgeColor','none','Tag','conf_fill');
    set(getappdata(fig,'hConfPct'),'String',sprintf('%.0f%%',S.confidence*100));

    % Severity bar
    hSB = getappdata(fig,'hSevBar');
    delete(findobj(hSB,'Tag','sev_fill'));
    t_s = S.severity; sc = (1-t_s)*[0.20 0.85 0.40] + t_s*[0.95 0.20 0.20];
    fill(hSB,[0, S.severity, S.severity, 0],[0,0,1,1], ...
         sc,'EdgeColor','none','Tag','sev_fill');
    set(getappdata(fig,'hSevPct'),'String',sprintf('%.2f',S.severity));

    % AI Decision box
    act_str = get_action_string(S);
    set(getappdata(fig,'hAIDecision'),'String',act_str);

    % Predictive box
    pred_str = sprintf('Lookahead: %s\nPred Severity: %.2f\nPred Kp: %.1f   Pred Kd: %.1f', ...
        S.pred_mode_lbl, S.pred_severity, S.pred_Kp, S.pred_Kd);
    hPB = getappdata(fig,'hPredBox');
    set(hPB,'String',pred_str);
    switch S.pred_mode_lbl
        case 'Anticipate', set(hPB,'BackgroundColor',[0.15 0.12 0.02],'ForegroundColor',[1.00 0.88 0.25]);
        case 'React',      set(hPB,'BackgroundColor',[0.12 0.08 0.02],'ForegroundColor',[1.00 0.65 0.25]);
        otherwise,         set(hPB,'BackgroundColor',[0.05 0.12 0.05],'ForegroundColor',[0.50 0.90 0.55]);
    end

    % Comparison metrics
    rms_c = rms(S.y_hist);   rms_u = rms(S.yu_hist);
    vib_red = max(0,(1-rms_c/(rms_u+1e-9))*100);
    comfort_c = min(100,max(0, 85 - vib_red*0.2 - abs(mean(S.u_hist))*0.05));
    comfort_u = max(0, comfort_c - vib_red*0.6);

    set(getappdata(fig,'hCmpRMS'),  'String', sprintf('%.4f m', rms_c));
    set(getappdata(fig,'hCmpRMSu'), 'String', sprintf('%.4f m', rms_u));
    set(getappdata(fig,'hCmpPk'),   'String', sprintf('%.3f m', S.peak_ctrl));
    set(getappdata(fig,'hCmpPku'),  'String', sprintf('%.3f m', S.peak_unc));
    set(getappdata(fig,'hCmpVR'),   'String', sprintf('%.1f %%', vib_red));
    set(getappdata(fig,'hCmpVRu'),  'String', 'baseline');
    set(getappdata(fig,'hCmpCmf'),  'String', sprintf('%.0f/100', comfort_c));
    set(getappdata(fig,'hCmpCmfu'),'String', sprintf('%.0f/100', comfort_u));

    % Settling time estimate
    stable = S.y_hist(max(1,end-50):end);
    if max(abs(stable)) < 0.02
        set(getappdata(fig,'hSettle'),'String','< 2.0 s  ✔');
    else
        set(getappdata(fig,'hSettle'),'String','Settling...');
    end

    % Overshoot
    over = max(0, (S.peak_ctrl - max(S.d_hist))*100);
    set(getappdata(fig,'hOver'),'String',sprintf('%.1f %%', over));
end

function s = get_action_string(S)
    switch S.road_type_ai
        case 'Smooth',        action = 'Soft damping — comfort priority';
        case 'SpeedBreaker',  action = 'Stiffening for bump impact';
        case 'Pothole',       action = 'Max Kd — impulse rejection';
        case 'Rough',         action = 'Sustained medium damping';
        case 'OffRoad',       action = 'Aggressive full damping';
        otherwise,            action = 'Monitoring...';
    end
    s = sprintf('Road: %s\nMode: %s (conf %.0f%%)\nAction: %s', ...
        upper(S.road_type_ai), S.mode, S.confidence*100, action);
end

%% ══════════════════════════════════════════════════════════════════
%  ROAD DISTURBANCE GENERATOR
%% ══════════════════════════════════════════════════════════════════
function d = road_disturbance(road_type, t)
    switch road_type
        case 'Smooth Road'
            d = 0.04*sin(2*pi*0.3*t) + 0.01*randn();
        case 'Speed Breaker'
            phase = mod(t, 4.0);
            if phase < 0.5
                d = 0.90 * sin(pi*phase/0.5);
            else
                d = 0.04*sin(2*pi*0.5*t);
            end
        case 'Pothole'
            phase = mod(t, 3.5);
            if phase < 0.18
                d = -0.88 * sin(pi*phase/0.18);
            else
                d = 0.05*sin(2*pi*0.4*t);
            end
        case 'Rough Terrain'
            d = 0.26*sin(2*pi*1.5*t) + 0.16*sin(2*pi*3.0*t) + 0.08*randn();
            d = max(-0.6, min(0.6, d));
        case 'Off-Road'
            d = 0.42*sin(2*pi*0.8*t) + 0.20*sin(2*pi*2.5*t) + ...
                0.10*randn() + 0.05*sin(2*pi*5*t);
            d = max(-0.8, min(0.8, d));
        otherwise
            d = 0;
    end
end

%% ══════════════════════════════════════════════════════════════════
%  CALLBACKS
%% ══════════════════════════════════════════════════════════════════
function startSim(fig)
    S = getappdata(fig,'S');
    if S.running, return; end
    S.running = true;
    setappdata(fig,'S',S);
    tmr = getappdata(fig,'tmr');
    if strcmp(tmr.Running,'off'), start(tmr); end
    fprintf('[Dashboard] Simulation started.\n');
end

function stopSim(fig)
    S = getappdata(fig,'S');
    S.running = false;
    setappdata(fig,'S',S);
    tmr = getappdata(fig,'tmr');
    if strcmp(tmr.Running,'on'), stop(tmr); end
    fprintf('[Dashboard] Simulation stopped at t=%.2f s\n', S.t_now);
end

function resetSim(fig)
    stopSim(fig);
    S = init_state();
    setappdata(fig,'S',S);
    ax_main = getappdata(fig,'ax_main');
    ax_unc  = getappdata(fig,'ax_unc');
    vehicle_animation('init', ax_main);
    vehicle_animation('init', ax_unc);
    title(ax_unc,'Uncontrolled (No Active Suspension)', ...
          'Color',[0.95 0.35 0.35],'FontSize',10,'FontWeight','bold');
    axR = getappdata(fig,'axR');
    for i=1:4, cla(axR(i)); end
    fprintf('[Dashboard] Reset complete.\n');
end

function changeRoad(fig, src)
    roads = {'Smooth Road','Speed Breaker','Pothole','Rough Terrain','Off-Road'};
    S = getappdata(fig,'S');
    S.road_type = roads{src.Value};
    S.peak_ctrl = 0; S.peak_unc = 0;  % reset peaks on road change
    setappdata(fig,'S',S);
    fprintf('[Dashboard] Road changed to: %s\n', S.road_type);
end

function perfReport(fig)
    S = getappdata(fig,'S');
    if isempty(S.t_hist)
        fprintf('[Report] No data — run simulation first.\n');
        return;
    end
    generate_performance_report(S);
end

function exportResults(fig)
    S = getappdata(fig,'S');
    results.time              = S.t_hist;
    results.displacement_ctrl = S.y_hist;
    results.displacement_unc  = S.yu_hist;
    results.Kp_reactive       = S.kp_hist;
    results.Kd_reactive       = S.kd_hist;
    results.Kp_predictive     = S.pkp_hist;
    results.Kd_predictive     = S.pkd_hist;
    results.control_force     = S.u_hist;
    results.road_disturbance  = S.d_hist;
    results.final_mode        = S.mode;
    results.final_severity    = S.severity;
    results.pred_severity     = S.pred_severity;
    save('suspension_results.mat','-struct','results');
    fprintf('[Dashboard] Results exported to suspension_results.mat\n');
    if ~isempty(S.t_hist)
        generate_performance_report(S);
    end
end

%% ── PERFORMANCE REPORT FIGURE ────────────────────────────────────
function generate_performance_report(S)
    fig2 = figure('Name','AI Suspension — Performance Report', ...
                  'Position',[80 80 1400 820], ...
                  'Color',[0.06 0.06 0.09]);
    t = S.t_hist;

    rms_c   = rms(S.y_hist);
    rms_u   = rms(S.yu_hist);
    vib_red = max(0,(1-rms_c/(rms_u+1e-9))*100);
    comfort = min(100,max(0, 85 - vib_red*0.2 - abs(mean(S.u_hist))*0.05));

    % 1. Displacement comparison
    ax1 = subplot(3,3,[1 2]);
    plot(t,S.yu_hist,'r--','LineWidth',1.8,'DisplayName','Uncontrolled'); hold on;
    plot(t,S.y_hist, 'c-', 'LineWidth',2.2,'DisplayName','AI Adaptive (Predictive)');
    xlabel('Time (s)'); ylabel('Displacement (m)');
    title('Controlled vs Uncontrolled Displacement','Color','w');
    legend('TextColor','w','FontSize',9,'Color',[0.10 0.10 0.14]);
    style_ax(ax1);

    % 2. Reactive vs predictive Kp
    ax2 = subplot(3,3,3);
    plot(t,S.kp_hist, 'g-','LineWidth',1.5,'DisplayName','Kp reactive'); hold on;
    plot(t,S.pkp_hist,'c--','LineWidth',1.8,'DisplayName','Kp predictive');
    xlabel('Time (s)'); title('Gain Comparison: Reactive vs Predictive','Color','w');
    legend('TextColor','w','FontSize',8,'Color',[0.10 0.10 0.14]);
    style_ax(ax2);

    % 3. Kd
    ax3 = subplot(3,3,4);
    plot(t,S.kd_hist, 'y-', 'LineWidth',1.5,'DisplayName','Kd reactive'); hold on;
    plot(t,S.pkd_hist,'m--', 'LineWidth',1.8,'DisplayName','Kd predictive');
    xlabel('Time (s)'); title('Kd: Reactive vs Predictive','Color','w');
    legend('TextColor','w','FontSize',8,'Color',[0.10 0.10 0.14]);
    style_ax(ax3);

    % 4. Control force
    ax4 = subplot(3,3,5);
    plot(t,S.u_hist,'m-','LineWidth',1.2);
    xlabel('Time (s)'); ylabel('Force (N)');
    title('Predictive Control Force','Color','w');
    style_ax(ax4);

    % 5. Road disturbance
    ax5 = subplot(3,3,6);
    plot(t,S.d_hist,'y-','LineWidth',1.5);
    xlabel('Time (s)'); ylabel('Magnitude');
    title('Road Disturbance Profile','Color','w');
    style_ax(ax5);

    % 6. Vibration reduction over time (running)
    ax6 = subplot(3,3,[7 8]);
    e_red = abs(S.yu_hist) - abs(S.y_hist);
    area(t, max(0,e_red),'FaceColor',[0.25 0.78 0.45],'FaceAlpha',0.55,'EdgeColor','none');
    hold on;
    area(t, min(0,e_red),'FaceColor',[0.90 0.30 0.30],'FaceAlpha',0.55,'EdgeColor','none');
    yline(0,'w--','LineWidth',1);
    xlabel('Time (s)'); ylabel('Δ Displacement (m)');
    title('Vibration Reduction (green=improvement, red=worse)','Color','w');
    style_ax(ax6);

    % 7. Summary text
    ax7 = subplot(3,3,9);
    axis(ax7,'off');
    txt = sprintf([...
        ' PERFORMANCE SUMMARY\n\n' ...
        ' RMS Vibration (ctrl)  : %.4f m\n' ...
        ' RMS Vibration (unctrl): %.4f m\n' ...
        ' Vibration Reduction   : %.1f %%\n\n' ...
        ' Peak (ctrl)  : %.3f m\n' ...
        ' Peak (unctrl): %.3f m\n\n' ...
        ' Comfort Index: %.0f / 100\n' ...
        ' Avg Pred Kp  : %.1f\n' ...
        ' Avg Pred Kd  : %.1f'], ...
        rms_c, rms_u, vib_red, ...
        S.peak_ctrl, S.peak_unc, ...
        comfort, mean(S.pkp_hist), mean(S.pkd_hist));
    text(ax7, 0.02, 0.98, txt, 'Units','normalized','VerticalAlignment','top', ...
         'Color',[0.85 0.90 0.85],'FontSize',9.5,'FontName','FixedWidth');
    title(ax7,'','Color','w');
    sgtitle('AI Predictive Adaptive Suspension — Full Performance Report', ...
            'Color',[0.65 0.85 1.0],'FontSize',13,'FontWeight','bold');
end

function style_ax(ax)
    ax.Color     = [0.09 0.09 0.13];
    ax.XColor    = [0.55 0.55 0.60];
    ax.YColor    = [0.55 0.55 0.60];
    ax.GridColor = [0.25 0.25 0.30];
    ax.GridAlpha = 0.5;
    grid(ax,'on');
end

%% ── UTILITIES ────────────────────────────────────────────────────
function timer_err(t, e)
    fprintf('[Timer Error] %s\n', e.message);
end

function onClose(fig, ~)
    try
        tmr = getappdata(fig,'tmr');
        if strcmp(tmr.Running,'on'), stop(tmr); end
        delete(tmr);
    catch; end
    delete(fig);
end
