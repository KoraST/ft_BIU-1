function S = spm_cfg_eeg_contrast
% configuration file for computing contrast over epochs
%_______________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Stefan Kiebel
% $Id: spm_cfg_eeg_contrast.m 2200 2008-09-26 10:09:45Z stefan $

D = cfg_files;
D.tag = 'D';
D.name = 'File Name';
D.filter = 'mat';
D.num = [1 1];
D.help = {'Select the EEG mat file.'};

c = cfg_entry;
c.tag = 'c';
c.name = 'Contrast vector/matrix';
c.strtype = 'r';
c.num = [inf inf];
c.help = {'Enter each contrast vector in a row. Each row must have ''number of epochs'' entries.'};

yes = cfg_const;
yes.tag = 'yes';
yes.name = 'Weight average by repetition numbers';
yes.val = {1};

no = cfg_const;
no.tag = 'no';
no.name = 'Don''t weight averager by repetition numbers';
no.val = {1};

WeightAve = cfg_choice;
WeightAve.tag = 'WeightAve';
WeightAve.name = 'Weight averages';
WeightAve.values = {yes,no};
WeightAve.val = {yes};
WeightAve.help = {'This option will weight averages by the number of their occurences in the data set. This is only important when there are multiple occurences of a trial type, e.g. in single trial data.'};


S = cfg_exbranch;
S.tag = 'eeg_contrast';
S.name = 'M/EEG Contrast over epochs';
S.val = {D c WeightAve};
S.help = {'Computes contrasts over EEG/MEG epochs.'};
S.prog = @eeg_contrast;
S.vout = @vout_eeg_contrast;
S.modality = {'EEG'};

function out = eeg_contrast(job)
% construct the S struct
S.D = job.D{1};
S.c = job.c;
if isfield(job.WeightAve, 'yes')
    S.WeightAve = 1;
else
    S.WeightAve = 0;
end

out.D = spm_eeg_weight_epochs(S);
out.Dfname = {out.D.fname};

function dep = vout_eeg_contrast(job)
% Output is always in field "D", no matter how job is structured
dep = cfg_dep;
dep.sname = 'Contrast of M/EEG epochs';
% reference field "D" from output
dep.src_output = substruct('.','D');
% this can be entered into any evaluated input
dep.tgt_spec   = cfg_findspec({{'strtype','e'}});

dep(2) = cfg_dep;
dep(2).sname = 'Contrast Datafile';
% reference field "Dfname" from output
dep(2).src_output = substruct('.','Dfname');
% this can be entered into any file selector
dep(2).tgt_spec   = cfg_findspec({{'filter','mat'}});

