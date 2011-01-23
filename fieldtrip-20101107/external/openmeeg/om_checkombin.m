function om_checkombin
% Check if OpenMEEG binaries are installed and work.
%
% Copyright (C) 2010, Alexandre Gramfort, INRIA

% $Id: om_checkombin.m 1825 2010-09-30 09:15:51Z alegra $
% $LastChangedBy: alegra $
% $LastChangedDate: 2010-09-30 11:15:51 +0200 (Thu, 30 Sep 2010) $
% $Revision: 1825 $

[status,result] = system('om_assemble');
if status
    web('http://openmeeg.gforge.inria.fr')
    disp('---------------------------------------------')
    disp('---------------------------------------------')
    disp('OpenMEEG binaries are not correctly installed')
    disp(' ')
    disp('Download OpenMEEG from')
    disp('http://gforge.inria.fr/frs/?group_id=435')
    disp(' ')
    disp('See wiki page for installation instructions:')
    disp('http://fieldtrip.fcdonders.nl/development/openmeeg/testinginstallation')
    disp('---------------------------------------------')
    disp('---------------------------------------------')
    error('OpenMEEG not found')
end
