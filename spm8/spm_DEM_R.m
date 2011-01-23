function [R,V,D] = spm_DEM_R(n,s,dt,form)
% returns the precision of the temporal derivatives of a Gaussian process
% FORMAT [R,V,D] = spm_DEM_R(n,s,dt,form)
%__________________________________________________________________________
% n    - truncation order
% s    - temporal smoothness - s.d. of kernel {bins}
% dt   - bin interval (seconds) [default 1]
% form - 'Gaussian', '1/f' [default: 'Gaussian']
%
%                         e[:] <- E*e(0)
%                         e(0) -> D*e[:]
%                 <e[:]*e[:]'> = R
%                              = <E*e(0)*e(0)'*E'>
%                              = E*V*E'
%
% R    - (n x n)     E*V*E: precision of n derivatives
% V    - (n x n)     V:    covariance of n derivatives
% D    - (n x n)     D:    projector:   Y(t) <- D*y[:]
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_DEM_R.m 2921 2009-03-23 17:59:50Z guillaume $

% if no serial dependencies 
%--------------------------------------------------------------------------
if ~n,         R = sparse(0,0); V = R; return, end
if isempty(s), R = sparse(n,n); V = R; return, end
if ~s,         s = exp(-16);                   end



% temporal correlations (assuming known form) - V
%--------------------------------------------------------------------------
try, form;, catch, form = 'Gaussian'; end

switch form

    case{'Gaussian'} % curvature: D^k(r) = cumprod(1 - k)/(sqrt(2)*s)^k
        %------------------------------------------------------------------
        k          = 0:(n - 1);
        x          = sqrt(2)*s;
        r(1 + 2*k) = cumprod(1 - 2*k)./(x.^(2*k));

    case{'1/f'}     % g(w) = exp(-x*w) => r(t) = sqrt(2/pi)*x/(x^2 + w^2)
        %------------------------------------------------------------------
        k          = [0:(n - 1)];
        x          = 8*s^2;
        r(1 + 2*k) = (-1).^k.*gamma(2*k + 1)./(x.^(2*k));
        
    otherwise
        errordlg('unknown autocorrelation')
end


% create coavraince matrix in generlised coordinates
%==========================================================================
V     = [];
for i = 1:n;
    V = [V; r([1:n] + i - 1)];
    r = -r;
end

% and precision - R
%--------------------------------------------------------------------------
sw = warning('off','MATLAB:nearlySingularMatrix');
R     = inv(V);
warning(sw);


if nargout, return, end


% Inverse embedding operator (D): c.f., a Taylor expansion Y(t) <- D*y[:]
%--------------------------------------------------------------------------
try, dt; catch, dt = 1; end

x     = fix((n + 1)/2);
for i = 1:n
    for j = 1:n
        D(i,j) = ((i - x)*dt)^(j - 1)/prod(1:(j - 1));
    end
end

% graphics
%==========================================================================

% embedding operator: y[:] <- E*Y(t): Graphics
%--------------------------------------------------------------------------
t     = ([1:n] - x)*dt;
subplot(2,2,1)
imagesc(V)
axis square
title({'covariance';'derivatives'})

subplot(2,2,2)
imagesc(t,t,D*V*D')
axis square
title({'covariance';'time (secs)'})

subplot(2,2,3)
imagesc(R)
axis square
title({'precision';'derivatives'})

subplot(2,2,4)
imagesc(t,t,inv(D*V*D'))
axis square
title({'precision';'time (secs)'})

return

% NB: temporal correlations (assuming stationary Gaussian form)
%--------------------------------------------------------------------------
t     = ([1:n] - 1)*dt;
v     = 2*(s^2);
V     = exp(-t.^2/(2*v));
V     = toeplitz(V);







