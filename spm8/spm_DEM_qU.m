function spm_DEM_qU(qU,pU)
% displays conditional estimates of states (qU)
% FORMAT spm_DEM_qU(qU,pU);
%
% qU.v{i}    - causal states (V{1} = y = predicted response)
% qU.x{i}    - hidden states
% qU.e{i}    - prediction error
% qU.C{N}    - conditional covariance - [causal states] for N samples
% qU.S{N}    - conditional covariance - [hidden states] for N samples
%
% pU         - optional input for known states
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_DEM_qU.m 3122 2009-05-13 16:05:59Z karl $

% unpack
%--------------------------------------------------------------------------
clf
V      = qU.v;
E      = qU.z;
try
    X  = qU.x;
end
try
    C  = qU.C;
    S  = qU.S;
end
try
    pV = pU.v;
    pX = pU.x;
end
try
    pA = qU.a;
end

% time-series specification
%--------------------------------------------------------------------------
g     = length(V);          % order of hierarchy
N     = size(V{1},2);       % length of data sequence
dt    = 1;                  % time step
t     = [1:N]*dt;           % time


% unpack conditional covariances
%--------------------------------------------------------------------------
ci    = spm_invNcdf(1 - 0.05);
s     = [];
c     = [];
try
    for i = 1:N
        c = [c sqrt(diag(C{i}))];
        s = [s sqrt(diag(S{i}))];
    end
end

% loop over levels
%--------------------------------------------------------------------------
for i = 1:g

    if N == 1

        % causal states and error - single observation
        %------------------------------------------------------------------
        subplot(g,2,2*i - 1)
        t = 1:size(V{i},1);
        plot(t,full(E{i}),'r:',t,full(V{i}))


        % conditional covariances
        %------------------------------------------------------------------
        if i > 1 && size(c,1)
            hold on
            j      = [1:size(V{i},1)];
            y      = ci*c(j,:);
            c(j,:) = [];
            fill([t fliplr(t)],[full(V{i} + y)' fliplr(full(V{i} - y)')],...
                 [1 1 1]*.8,'EdgeColor',[1 1 1]*.8)
            plot(t,full(E{i}),'r:',t,full(V{i}))
            hold off
        end

        % title and grid
        %------------------------------------------------------------------
        title('causal states','FontSize',16);
        grid on
        axis square
        set(gca,'XLim',[t(1) t(end)])

    else

        % causal states and error - time series
        %------------------------------------------------------------------
        subplot(g,2,2*i - 1)
        try
            plot(t,pV{i},':k','linewidth',1)
        end, hold on
        try
            plot(t,full(E{i}(:,1:N)),'r:',t,full(V{i}))
        end, hold off
        set(gca,'XLim',[t(1) t(end)])
        a   = axis;

        % conditional covariances
        %------------------------------------------------------------------
        if i > 1 && size(c,1)
            hold on
            j      = [1:size(V{i},1)];
            y      = ci*c(j,:);
            c(j,:) = [];
            fill([t fliplr(t)],[full(V{i} + y) fliplr(full(V{i} - y))],...
                        [1 1 1]*.8,'EdgeColor',[1 1 1]*.8)
            try 
                plot(t,pV{i},':k','linewidth',1)
            end
            plot(t,full(E{i}(:,1:N)),'r:',t,full(V{i}))
            hold off
        end

        % title, action, grid and true casues (if available)
        %------------------------------------------------------------------
        if i == 1
            title('prediction and error','FontSize',16);
        else
            title('causal states','FontSize',16);
            try, hold on
                plot(t,pV{i},':k','linewidth',1)
            end, hold off
            try, hold on
                plot(t,pA{i - 1},'linewidth',1,'color',[1 0 0])
            end, hold off
        end
        xlabel('time','FontSize',14)
        axis square
        axis(a)

        % hidden states
        %------------------------------------------------------------------
        try
 
            subplot(g,2,2*i)
            try, hold on
                plot(t,pX{i},':k','linewidth',1)
            end, hold off
            plot(t,full(X{i}))
            set(gca,'XLim',[t(1) t(end)])
            a   = axis;
            
            if ~isempty(s)
                hold on
                j      = [1:size(X{i},1)];
                y      = ci*s(j,:);
                s(j,:) = [];
                fill([t fliplr(t)],[full(X{i} + y) fliplr(full(X{i} - y))],...
                        [1 1 1]*.8,'EdgeColor',[1 1 1]*.8)
                try
                    plot(t,pX{i},':k','linewidth',1)
                end
                plot(t,full(X{i}))
                hold off
            end
                      
            % title and grid
            %--------------------------------------------------------------
            title('hidden states','FontSize',16)
            xlabel('time','FontSize',14)
            axis square
            axis(a);
            
        catch
            delete(gca)
        end
    end
end

% plot action if specified
%--------------------------------------------------------------------------
if isfield(qU,'a')
    subplot(g,2,2*g)
    plot(t,qU.a{2});
    try, hold on
        plot(t,pU.v{2},':b','Linewidth',2) 
    end,hold off
    xlabel('time','Fontsize',14)
    title('perturbation and action','Fontsize',16)
    axis square
    set(gca,'XLim',[t(1) t(end)])
end
hold off
drawnow
