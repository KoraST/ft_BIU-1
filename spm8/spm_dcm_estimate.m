function [DCM] = spm_dcm_estimate(P)   
% Estimate parameters of a DCM (bilinear or nonlinear) for fMRI data
% FORMAT [DCM] = spm_dcm_estimate(DCM)   
%
% DCM  - the DCM or its filename
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Will Penny
% $Id: spm_dcm_estimate.m 3177 2009-06-03 08:47:41Z vladimir $

 
% load DCM structure
%--------------------------------------------------------------------------
if ~nargin
    
    %-display model details
    %----------------------------------------------------------------------
    Finter = spm_figure('GetWin','Interactive');
    set(Finter,'name','Dynamic Causal Modeling')
    
    %-get DCM
    %----------------------------------------------------------------------
    P = spm_select(1,'^DCM.*\.mat$','select DCM_???.mat');
    
    spm('Pointer','Watch')
    spm('FigName','Estimation in progress');
    
end
if isstruct(P)
    DCM = P;
    P   = ['DCM-' date];
else
    load(P)
end

    
% unpack
%--------------------------------------------------------------------------
a  = DCM.a;                             % switch on endogenous connections
b  = DCM.b;                             % switch on bilinear modulations
c  = DCM.c;                             % switch on exogenous connections
U  = DCM.U;                             % exogenous inpurs 
Y  = DCM.Y;                             % responses
X0 = DCM.Y.X0;                          % confounds
n  = DCM.n;
v  = DCM.v;


% adopt model specification M if it already exists 
%--------------------------------------------------------------------------
if isfield(DCM,'M') 
    M = DCM.M;
end


% check whether this is a nonlinear DCM
%--------------------------------------------------------------------------
if isfield(DCM,'d') && any(any(DCM.d(:)))
    % nonlinear DCM
    M.nlDCM = 1;
    d       = DCM.d; % switch on nonlinear modulations
    fprintf('\n\n%s %s\n','Nonlinear DCM:',P);
    fprintf('%s\n\n','--------------------------------------------------------------------------------------');
    fprintf('%s\n\n','Please note that this computation will be considerably slower than for a bilinear DCM.');
    fprintf('%s\n','If you want to speed up computation, you can use fewer microtime bins per TR when defining your design matrix');
    fprintf('%s\n','(the size of a microtime bin defines the dt for integration of the DCM state equations).');
    fprintf('%s\n','We found microtime bins of 0.2 s to give stable results; longer time bins may well still work, but you would need to check.');
    fprintf('%s %1.3f seconds.\n\n','You are currently using microtimebins of',DCM.U.dt);
else
    % bilinear DCM
    M.nlDCM = 0;
end


% check integrator
%--------------------------------------------------------------------------
if ~isfield(M,'IS')
    if M.nlDCM
        % nonlinear DCM
        M.IS    = 'spm_int_B_nlDCM_fMRI';
    else
        % bilinear DCM
        M.IS    = 'spm_int';
    end
end

% prevent mismatch between DCM structure and integration scheme
if M.nlDCM && (length(M.IS) == length('spm_int'))
    fprintf('\n\n%s\n','WARNING: You are trying to run a nonlinear DCM with a bilinear integration scheme (spm_int).');
    fprintf('%s\n\n','A nonlinear integration scheme (spm_int_B_nlDCM_fMRI) is used instead.');
    M.IS    = 'spm_int_B_nlDCM_fMRI';
end


% check whether TE of acquisition has been defined 
% (if not, default to 0.04 s)
%--------------------------------------------------------------------------
if ~isfield(DCM,'TE')
    DCM.TE = 0.04;
else
    if (DCM.TE < 0) || (DCM.TE > 0.1)
        disp('spm_dcm_estimate: Extreme TE value found.')
        disp('Please check and adjust DCM.TE - note this value must be in seconds!')
        return
    end
end
TE = DCM.TE;


% priors - expectations
%--------------------------------------------------------------------------
if ~M.nlDCM
    % bilinear DCM
    [pE,pC,qE,qC] = spm_dcm_priors(a,b,c);
else
    % nonlinear DCM
    [pE,pC,qE,qC] = spm_dcm_priors(a,b,c,d);
end


% complete model specification
%--------------------------------------------------------------------------
M.f     = 'spm_fx_dcm';
M.g     = 'spm_gx_dcm';
M.x     = sparse(n*5,1);
M.pE    = pE;
M.pC    = pC;
M.m     = size(U.u,2);
M.n     = size(M.x,1);
M.l     = n;
M.N     = 32;
M.dt    = 16/M.N;
M.ns    = size(Y.y,1);
M.TE    = TE;


% fMRI slice time sampling
%--------------------------------------------------------------------------
try, M.delays = DCM.delays; end


% nonlinear system identification (nlsi)
%--------------------------------------------------------------------------
[Ep,Cp,Ce,H0,H1,H2,M0,M1,L1,L2,F] = spm_nlsi(M,U,Y);


% Data ID
%==========================================================================
if isfield(M,'FS')
    try
        ID  = spm_data_id(feval(M.FS,Y.y,M));
    catch
        ID  = spm_data_id(feval(M.FS,Y.y));
    end
else
    ID  = spm_data_id(Y.y);
end


% predicted responses and residuals
%--------------------------------------------------------------------------
y     = feval(M.IS,Ep,M,U);
R     = Y.y - y;
R     = R - X0*inv(X0'*X0)*(X0'*R);


% neuronal kernels
%--------------------------------------------------------------------------
L          = sparse(1:n,[1:n] + 1,1,n,length(M0));
[K0,K1,K2] = spm_kernels(M0,M1,L,M.N,M.dt);


% Bayesian inference and reshape {default threshold T = 0}
%--------------------------------------------------------------------------
T          = 0;
sw = warning('off','SPM:negativeVariance'); % switch off NaN-related warning of spm_Ncdf
pp         = 1 - spm_Ncdf(T,abs(Ep),diag(Cp));
warning(sw);
if ~M.nlDCM
    % bilinear DCM
    [ A  B  C] = spm_dcm_reshape(Ep,M.m,n,1);
    [pA pB pC] = spm_dcm_reshape(pp,M.m,n,1);
else
    % nonlinear DCM
       % NB: order of parameter vector is: 
       % bilinear neural params -> hemodynamic params -> nonlinear neural params
    [ A  B  C  H  D] = spm_dcm_reshape(Ep,M.m,n,1);
    [pA pB pC pH pD] = spm_dcm_reshape(pp,M.m,n,1);
end


% Also record variances - this helps Bayesian inference, e.g. across sessions
%--------------------------------------------------------------------------
vv         = diag(Cp);
if ~M.nlDCM
    % bilinear DCM
    [vA vB vC]       = spm_dcm_reshape(vv,M.m,n,1);
else
    % nonlinear DCM
    [vA vB vC vH vD] = spm_dcm_reshape(vv,M.m,n,1);
end


% Store parameter estimates
%--------------------------------------------------------------------------
DCM.M      = M;
DCM.Y      = Y;
DCM.U      = U;
DCM.Ep     = Ep;
DCM.Cp     = Cp;
DCM.A      = A;
DCM.B      = B;
DCM.C      = C;
DCM.pA     = pA;
DCM.pB     = pB;
DCM.pC     = pC;
DCM.vA     = vA;
DCM.vB     = vB;
DCM.vC     = vC;
DCM.H1     = H1;
DCM.H2     = H2;
DCM.K1     = K1;
DCM.K2     = K2;
DCM.R      = R;
DCM.y      = y;
DCM.T      = T;
DCM.Ce     = Ce;
if M.nlDCM
    % nonlinear DCM
    DCM.D      = D;
    DCM.pD     = pD;
    DCM.vD     = vD;
end


% Save approximations to model evidence: negative free energy, AIC, BIC
%--------------------------------------------------------------------------
evidence   = spm_dcm_evidence(DCM);
DCM.F      = F;
DCM.ID     = ID;        % data ID
DCM.AIC    = evidence.aic_overall;
DCM.BIC    = evidence.bic_overall;


%-Save DCM
%--------------------------------------------------------------------------
if spm_matlab_version_chk('7') >= 0
    save(P,'-V6','DCM');
else
    save(P,'DCM');
end

if ~nargin
    spm('Pointer','Arrow');
    spm('FigName','Done');
end

return
