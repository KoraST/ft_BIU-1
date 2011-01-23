function [varargout] = funname(varargin)

% MEG_LEADFIELD1 magnetic leadfield for a dipole in a homogenous sphere
%
% [lf] = meg_leadfield1(R, pos, ori)
%
% with input arguments
%   R		  position dipole
%   pos		position magnetometers
%   ori		orientation magnetometers
%
% The center of the homogenous sphere is in the origin, the field
% of the dipole is not dependent on the sphere radius.
%
% This function is also implemented as MEX file.

% adapted from Luetkenhoener, Habilschrift '92
% optimized for speed using temporary variables
% the mex implementation is a literary copy of this

% Copyright (C) 2002-2008, Robert Oostenveld
%
% $Log: meg_leadfield1.m,v $
% Revision 1.3  2009/06/17 13:38:06  roboos
% cleaned up documentation
%
% Revision 1.2  2009/03/12 11:05:04  roboos
% implemented auto-compilation of the mex file in case it is missing
%
% Revision 1.1  2009/01/21 10:32:38  roboos
% moved from forwinv/* and forwinv/mex/* directory to forwinv/private/* to make the CVS layout consistent with the release version
%
% Revision 1.8  2008/07/21 20:32:27  roboos
% updated documentation
%
% Revision 1.7  2008/03/05 16:27:33  roboos
% updated documentation
%
% Revision 1.5  2003/03/28 10:01:15  roberto
% created mex implementation, updated help and comments
%
% Revision 1.4  2003/03/28 09:01:55  roberto
% fixed important bug (incorrect use of a temporary variable)
%
% Revision 1.3  2003/03/12 08:19:45  roberto
% improved help
%
% Revision 1.2  2003/03/11 14:45:37  roberto
% updated help and copyrights
%

% compile the missing mex file on the fly
% remember the original working directory
pwdir = pwd;

% determine the name and full path of this function
funname = mfilename('fullpath');
mexsrc  = [funname '.c'];
[mexdir, mexname] = fileparts(funname);

try
  % try to compile the mex file on the fly
  warning('trying to compile MEX file from %s', mexsrc);
  cd(mexdir);
  mex(mexsrc);
  cd(pwdir);
  success = true;

catch
  % compilation failed
  disp(lasterr);
  error('could not locate MEX file for %s', mexname);
  cd(pwdir);
  success = false;
end

if success
  % execute the mex file that was juist created
  funname   = mfilename;
  funhandle = str2func(funname);
  [varargout{1:nargout}] = funhandle(varargin{:});
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% THE FOLLOWING CODE CORRESPONDS WITH THE ORIGINAL IMPLEMENTATION
% function [lf] = meg_leadfield1(R, Rm, Um);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Nchans = size(Rm, 1);
%
% lf = zeros(Nchans,3);
%
% tmp2 = norm(R);
%
% for i=1:Nchans
%   r = Rm(i,:);
%   u = Um(i,:);
%
%   tmp1 = norm(r);
%   % tmp2 = norm(R);
%   tmp3 = norm(r-R);
%   tmp4 = dot(r,R);
%   tmp5 = dot(r,r-R);
%   tmp6 = dot(R,r-R);
%   tmp7 = (tmp1*tmp2)^2 - tmp4^2;	% cross(r,R)^2
%
%   alpha = 1 / (-tmp3 * (tmp1*tmp3+tmp5));
%   A = 1/tmp3 - 2*alpha*tmp2^2 - 1/tmp1;
%   B = 2*alpha*tmp4;
%   C = -tmp6/(tmp3^3);
%
%   if tmp7<eps
%     beta = 0;
%   else
%     beta = dot(A*r + B*R + C*(r-R), u)/tmp7;
%   end
%
%   lf(i,:) = cross(alpha*u  + beta*r, R);
% end
% lf = 1e-7*lf;	% multiply with u0/4pi
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % fast cross product
% function [c] = cross(a,b);
% c = [a(2)*b(3)-a(3)*b(2) a(3)*b(1)-a(1)*b(3) a(1)*b(2)-a(2)*b(1)];
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % fast dot product
% function [c] = dot(a,b);
% c = sum(a.*b);
%
