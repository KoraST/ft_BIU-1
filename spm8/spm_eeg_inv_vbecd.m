function P = spm_eeg_inv_vbecd(P)
% Model inversion routine for ECDs using variational Bayesian approach 
%
% FORMAT P = spm_eeg_inv_vbecd(P)
%
% Input:
% structure P with fields:
%  forward      - structure containing the forward model, i.e. the "vol"
%                 and "sens" structure in a FT compatible format
%  bad          - list of bad channels, not to use.
%  y            - data vector
%
%  Niter        - maximum number of iterations
%  priors       - priors on parameters,  as filled in (and
%                 described) in spm_eeg_inv_vbecd_gui.m.
%
% Output:
% same structure with extra fields
%  init         - initial valuse used for mu_w/s
%  dF           - successive (relative) improvement of F
%  post         - posterior value of estimated parameters and ther variance
%  Fi           - successive values of F
%  F            - Free energy final value.
%
% Reference:
% Kiebel et al., Variational Bayesian inversion of the equivalent current
% dipole model in EEG/MEG., NeuroImage, 39:728-741, 2008
% (Although this algorithm uses a function for general Bayesian inversion of
% a non-linear model - see spm_nlsi_gn)
%__________________________________________________________________________
% Copyright (C) 2009 Wellcome Trust Centre for Neuroimaging
% Gareth Barnes 
% $Id: spm_eeg_inv_vbecd.m 3514 2009-10-28 14:37:09Z gareth $



% unpack model, priors, data


Nd = length(P.priors.mu_w0)/3;
mu_w0 = P.priors.mu_w0;
mu_s0 = P.priors.mu_s0;
S_w0 = P.priors.S_w0;
S_s0 = P.priors.S_s0;

if strcmp(upper(P.modality),'EEG'),
    P.y=P.y-mean(P.y); %% subtracting mean level from eeg data
end; % if 

y = P.y;
sc_y=10000/std(y); %% rescale data to fit into minimisation routine (same magnitude for EEG and MEG means same threshold and exit criteria)
y = y*sc_y;






Y.y=y;
U.u=1;

 outsideflag=1;
 while outsideflag==1, %% don't use sources which end up outside the head


    [u,s,v] = svd(S_w0); 
%% set random moment, scaled by prior variances
    mu_w = mu_w0 + u*diag(sqrt(diag(s+eps)))*v'*randn(size(mu_w0)); %% source units  

    [u,s,v] = svd(S_s0); %% 
    %% a random guess for the location, based on variance of the prior

    outside=1;
    while (outside),
        outside=0;
        mu_s = mu_s0 + u*diag(sqrt(diag(s+eps)))*v'*randn(size(mu_s0)); % 
        for i=1:3:length(mu_s), %% check each dipole is inside the head
        pos=mu_s(i:i+2);
        outside = outside+ ~forwinv_inside_vol(pos',P.forward.vol);
        end; 
    end;

     

% get lead fields


    M.pE  = [mu_s;mu_w]; %% prior parameter estimate 
    M.pC  = blkdiag(S_s0,S_w0); % %% prior covariance estimate
    M.IS='spm_eeg_wrap_dipfit_vbecd';
    startguess=M.pE;
    M.Setup=P; %% pass volume conductor and sensor locations on
    M.sc_y=sc_y; %%  pass on scaling factor
     
    [starty]=spm_eeg_wrap_dipfit_vbecd(startguess,M,U);
    [Ep,Cp,S,F] = spm_nlsi_GN(M,U,Y);
    P.Ep=Ep;
    P.Cp=Cp;
    P.S=S;
    P.F=F;
    [P.ypost,outsideflag]=spm_eeg_wrap_dipfit_vbecd(P.Ep,M,U); 
    P.ypost=P.ypost./sc_y; %%  scale it back
    if outsideflag
        disp('running again, one or more dipoles outside head.');
        end;
    
 end; % while
P.post_mu_s=Ep(1:length(mu_s));
P.post_mu_w=Ep(length(mu_s)+1:end);
P.post_S_s=Cp(1:length(mu_s),1:length(mu_s));
P.post_S_w=Cp(length(mu_s)+1:end,length(mu_s)+1:end);




