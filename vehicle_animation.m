%% ================================================================
%  VEHICLE_ANIMATION.m  (UPGRADED v2)
%  Real-time side-view vehicle suspension animation
%
%  Improvements over v1:
%   - Smoother suspension travel (exponential smoothing)
%   - Better spring + shock absorber rendering
%   - Road texture / lane markings
%   - Dual-panel side-by-side comparison mode
%   - Predictive lookahead mode indicator
%   - Chassis roll (tilt based on displacement velocity)
%   - Ground shadow + severity bar HUD
%
%  API:
%    vehicle_animation('init',   ax)
%    vehicle_animation('update', ax, y_body, y_wheel, road_h, mode_str, pred_mode)
%    vehicle_animation('init_compare',   ax_ctrl, ax_unctrl)
%    vehicle_animation('update_compare', ax_ctrl, ax_unctrl,
%                      y_ctrl, y_unctrl, road_h, mode_str)
%% ================================================================

function vehicle_animation(action, ax, varargin)
    switch lower(action)
        case 'init'
            init_anim(ax);
        case 'update'
            y_body   = varargin{1};
            y_wheel  = varargin{2};
            road_h   = varargin{3};
            mode_str = 'Comfort';
            if numel(varargin) >= 4, mode_str = varargin{4}; end
            pred_mode = '';
            if numel(varargin) >= 5, pred_mode = varargin{5}; end
            update_anim(ax, y_body, y_wheel, road_h, mode_str, pred_mode);
        case 'init_compare'
            init_anim(ax);
            title(ax,'CONTROLLED  (AI Adaptive PD)','Color',[0.30 0.95 0.55],'FontSize',10,'FontWeight','bold');
            if ~isempty(varargin)
                init_anim(varargin{1});
                title(varargin{1},'UNCONTROLLED','Color',[0.95 0.35 0.35],'FontSize',10,'FontWeight','bold');
            end
        case 'update_compare'
            ax_u    = varargin{1};
            y_ctrl  = varargin{2};
            y_unc   = varargin{3};
            road_h  = varargin{4};
            mode_str = 'Comfort';
            if numel(varargin) >= 5, mode_str = varargin{5}; end
            update_anim(ax,  y_ctrl, max(0,road_h), road_h, mode_str, '');
            update_anim(ax_u, y_unc, max(0,road_h), road_h, 'Uncontrolled', '');
        otherwise
            error('Unknown action: %s', action);
    end
end

function init_anim(ax)
    cla(ax); hold(ax,'on');
    axis(ax, [-1.5, 3.5, -0.8, 2.8]);
    axis(ax,'off');
    ax.Color = [0.06 0.06 0.10];
    ud.body_base_y  = 1.20;
    ud.wheel_base_y = 0.30;
    ud.road_base_y  = 0.0;
    ud.spring_x     = [0.50, 1.50];
    ud.wheel_x      = [0.42, 1.58];
    ud.prev_body_y  = 1.20;
    ud.prev_whl_y   = 0.30;
    ax.UserData = ud;
    fill(ax,[-1.5,3.5,3.5,-1.5],[-0.8,-0.8,0.0,0.0],[0.18 0.18 0.18],'EdgeColor','none','Tag','road_base');
    line(ax,[-1.5,3.5],[0.001,0.001],'Color',[0.50 0.50 0.50],'LineWidth',2,'Tag','road_base');
    for lx=-1.0:0.8:3.5
        line(ax,[lx,lx+0.4],[-0.04,-0.04],'Color',[0.38 0.38 0.38],'LineWidth',1.5,'Tag','road_base');
    end
    title(ax,'Live Suspension Animation','Color',[0.75 0.85 1.0],'FontSize',11,'FontWeight','bold');
end

function update_anim(ax, y_body, y_wheel, road_h, mode_str, pred_mode)
    ud = ax.UserData;
    scale  = 0.55;
    alpha_b = 0.35;
    alpha_w = 0.65;
    raw_body_y = ud.body_base_y + y_body  * scale;
    raw_whl_y  = ud.wheel_base_y + y_wheel * scale + road_h * scale;
    body_y = alpha_b * raw_body_y + (1-alpha_b) * ud.prev_body_y;
    whl_y  = alpha_w * raw_whl_y  + (1-alpha_w) * ud.prev_whl_y;
    road_y = ud.road_base_y + road_h * scale;
    body_y = max(0.55, min(2.30, body_y));
    whl_y  = max(0.08, min(body_y - 0.22, whl_y));
    road_y = max(-0.18, min(0.40, road_y));
    body_vel = (raw_body_y - ud.prev_body_y);
    tilt_rad = max(-0.08, min(0.08, body_vel * 0.6));
    ud.prev_body_y = body_y;
    ud.prev_whl_y  = whl_y;
    ax.UserData = ud;
    switch mode_str
        case 'Sport',        body_clr=[0.82 0.16 0.16]; spring_clr=[1.00 0.42 0.12]; accent_clr=[1.00 0.60 0.20];
        case 'Off-Road',     body_clr=[0.80 0.56 0.08]; spring_clr=[1.00 0.85 0.20]; accent_clr=[1.00 0.90 0.40];
        case 'Uncontrolled', body_clr=[0.55 0.55 0.58]; spring_clr=[0.75 0.75 0.80]; accent_clr=[0.85 0.85 0.88];
        otherwise,           body_clr=[0.14 0.52 0.85]; spring_clr=[0.28 0.90 0.60]; accent_clr=[0.50 0.95 0.80];
    end
    delete(findobj(ax,'Tag','dyn'));
    if abs(road_y) > 0.01
        rx = linspace(-0.5,2.5,80);
        bump = road_y * exp(-((rx-1.0).^2)/(2*0.30^2));
        fill(ax,[rx,fliplr(rx)],[bump,zeros(1,80)],[0.38 0.38 0.38],'EdgeColor','none','Tag','dyn');
        line(ax,rx,bump,'Color',[0.65 0.65 0.65],'LineWidth',1.5,'Tag','dyn');
    end
    % Shadow
    sw = 0.45 - (body_y-ud.body_base_y)*0.06;
    sw = max(0.15, min(0.45, sw));
    fill(ax,1.0+sw*[-1,1,1,-1],[-0.01,-0.01,0.01,0.01],[0 0 0],'FaceAlpha',0.22,'EdgeColor','none','Tag','dyn');
    % Wheels
    r_whl = 0.20;
    for wx = ud.wheel_x
        theta = linspace(0,2*pi,48);
        fill(ax,wx+r_whl*cos(theta),whl_y+r_whl*sin(theta),[0.12 0.12 0.12],'EdgeColor',[0.55 0.55 0.55],'LineWidth',2,'Tag','dyn');
        fill(ax,wx+0.55*r_whl*cos(theta),whl_y+0.55*r_whl*sin(theta),[0.38 0.38 0.44],'EdgeColor',[0.65 0.65 0.70],'LineWidth',1,'Tag','dyn');
        for ang=0:pi/3:pi-0.01
            line(ax,[wx+0.52*r_whl*cos(ang),wx-0.52*r_whl*cos(ang)],[whl_y+0.52*r_whl*sin(ang),whl_y-0.52*r_whl*sin(ang)],'Color',[0.58 0.58 0.63],'LineWidth',1.2,'Tag','dyn');
        end
        fill(ax,wx+0.09*r_whl*cos(theta),whl_y+0.09*r_whl*sin(theta),[0.75 0.75 0.80],'EdgeColor','none','Tag','dyn');
    end
    % Axle
    line(ax,ud.wheel_x,[whl_y,whl_y],'Color',[0.60 0.60 0.60],'LineWidth',3.5,'Tag','dyn');
    % Springs + dampers
    sp_top = body_y; sp_bot = whl_y + r_whl;
    for sx = ud.spring_x
        dx = sx - 0.05;
        mid_y = (sp_bot+sp_top)/2;
        cyl_h = (sp_top-sp_bot)*0.45;
        fill(ax,dx+[-0.025,0.025,0.025,-0.025],[mid_y-cyl_h/2,mid_y-cyl_h/2,mid_y+cyl_h/2,mid_y+cyl_h/2],[0.28 0.28 0.34],'EdgeColor',accent_clr*0.7,'LineWidth',1,'Tag','dyn');
        line(ax,[dx,dx],[sp_bot,mid_y-cyl_h/2+0.02],'Color',[0.75 0.75 0.80],'LineWidth',2.5,'Tag','dyn');
        n_c=9; amp=0.06;
        yp=linspace(sp_bot,sp_top,n_c*6+2);
        xp=(sx+0.06)+amp*sin(linspace(0,n_c*2*pi,length(yp)));
        line(ax,xp,yp,'Color',spring_clr,'LineWidth',2.0,'Tag','dyn');
        for yc=[sp_bot,sp_top]
            fill(ax,sx+[-0.10,0.12,0.12,-0.10],[yc-0.015,yc-0.015,yc+0.015,yc+0.015],spring_clr*0.8,'EdgeColor','none','Tag','dyn');
        end
    end
    % Chassis body
    bh=0.35; bw=1.55; bx0=0.225; cx=bx0+bw/2;
    cx_= [bx0,bx0+bw,bx0+bw,bx0]-cx;
    cy_= [body_y,body_y,body_y+bh,body_y+bh];
    R=[cos(tilt_rad),-sin(tilt_rad);sin(tilt_rad),cos(tilt_rad)];
    rot=R*[cx_;zeros(1,4)];
    rx=rot(1,:)+cx; ry=rot(2,:)+cy_;
    fill(ax,rx,ry,body_clr,'EdgeColor',body_clr*0.65,'LineWidth',2,'Tag','dyn');
    % Cabin
    cob_ox=[0.18,0.60,1.05,1.32,0.18]; cob_oy=[0,0.30,0.30,0,0];
    cob_cx=cob_ox+bx0-cx;
    rotc=R*[cob_cx;zeros(1,5)];
    fill(ax,rotc(1,:)+cx,rotc(2,:)+ry(3)+cob_oy,body_clr*0.80,'EdgeColor',body_clr*0.55,'LineWidth',1.2,'Tag','dyn');
    ws_ox=[0.20,0.58,0.58,0.20]; ws_oy=[0.02,0.27,0.02,0.02];
    ws_cx=ws_ox+bx0-cx;
    rotws=R*[ws_cx;zeros(1,4)];
    fill(ax,rotws(1,:)+cx,rotws(2,:)+ry(3)+ws_oy,[0.50 0.72 0.92],'FaceAlpha',0.60,'EdgeColor','none','Tag','dyn');
    % Headlight
    fill(ax,rx(2)+[-0.01,0.04,0.04,-0.01],ry(2)+[0.06,0.06,0.12,0.12],[1 0.95 0.60],'FaceAlpha',0.9,'EdgeColor','none','Tag','dyn');
    % Mode label
    mc=min(body_clr+0.18,1);
    text(ax,-1.35,2.55,['◆ ' mode_str],'Color',mc,'FontSize',10,'FontWeight','bold','Tag','dyn');
    if ~isempty(pred_mode)
        switch pred_mode
            case 'Anticipate', pc=[1.0 0.80 0.10];
            case 'React',      pc=[0.9 0.55 0.20];
            otherwise,         pc=[0.5 0.85 0.55];
        end
        text(ax,-1.35,2.30,['⚡ ' pred_mode],'Color',pc,'FontSize',8,'FontWeight','bold','Tag','dyn');
    end
    % Displacement HUD
    t2=max(0,min(1,abs(y_body)*4));
    col=(1-t2)*[0.30 0.95 0.45]+t2*[0.95 0.30 0.30];
    text(ax,2.10,2.55,sprintf('Δy=%+.3f m',y_body),'Color',col,'FontSize',9,'FontWeight','bold','Tag','dyn');
    % Severity bar
    sev=max(0,min(1,abs(y_body)*4));
    fill(ax,2.80+[0,0.15,0.15,0],[0.05,0.05,2.05,2.05],[0.20 0.20 0.25],'EdgeColor',[0.40 0.40 0.45],'Tag','dyn');
    if sev>0.01
        t3=sev; sc=(1-t3)*[0.20 0.85 0.40]+t3*[0.95 0.20 0.20];
        fill(ax,2.80+[0,0.15,0.15,0],0.05+[0,0,sev*2,sev*2],sc,'EdgeColor','none','Tag','dyn');
    end
    text(ax,2.78,2.10,'SEV','Color',[0.60 0.60 0.65],'FontSize',7,'Tag','dyn');
    drawnow limitrate;
end
