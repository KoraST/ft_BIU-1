function [R] = spm_DEM_MEG(DEM,dt,n,graphics)
% as for spm_DEM_EEG but plots the causal and hidden errors
% FORMAT [R] = spm_DEM_MEG(DEM,dt,n,graphics)
% DEM  - DEM structure
% dt   - time bin (seconds)
% n    - level[s]
% g    - graphics switch
%
% R{i} - response over peri-stimulus time (whitened error): level i
%
% These simulated response assume that LFPs are generated by superficial
% pyramidal cells that correspond to units encoding precision-weighted
% prediction error.
%
% see also spm_DEM_ERP
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_DEM_MEG.m 2907 2009-03-20 13:02:24Z karl $

% defaults
%--------------------------------------------------------------------------
if ~nargout; graphics = 1; end
try
    dt;
catch
    try
        dt = DEM.U.dt;
    catch
        dt = 1;
    end
end
try,        n; catch,        n = 1; end
try, graphics; catch, graphics = 0; end

% loop over hierarchical (cortical) levels
%--------------------------------------------------------------------------
if graphics, cla; hold on; end

z     = DEM.qU.z;
w     = DEM.qU.w;
pst   = [1:size(z{1},2)]*dt*1000;
for k = 1:length(n)

    % level
    %----------------------------------------------------------------------
    i   = n(k);

    % precisions
    %----------------------------------------------------------------------
    V   = DEM.M(i).V;
    h   = DEM.M(i).hE;
    for j = 1:length(h)
        V = V + DEM.M(i).Q{j}*exp(h(j));
    end

    % precisions
    %----------------------------------------------------------------------
    W   = DEM.M(i).W;
    g   = DEM.M(i).gE;
    for j = 1:length(DEM.qH.g{i})
        W = W + DEM.M(i).R{j}*exp(g(j));
    end

    % ERPs
    %----------------------------------------------------------------------
    R{k,1}     = spm_sqrtm(V)*z{i};
    try
        R{k,2} = spm_sqrtm(W)*w{i};
    end

    if graphics
        plot(pst,R{k,1},'r')
        try
            plot(pst,R{k,2},'r:')
        end
    end

end

% labels
%--------------------------------------------------------------------------
if graphics
    xlabel('peristimulus time (ms)')
    ylabel('LFP (micro-volts)')
    box on
    hold off
    drawnow
end
