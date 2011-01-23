function covToMont(pat2data,fileName,startt,endt,conds,groups,skipto)
% pat2data is the path to a directory where all the data is, every subject
% in a numbered folder. in addition to fieldtrip preprocessed files add
% hs_file, config and data file (e.g. c,rfhp0.1Hz wich is also the fileName). 
% startt and endt is the time window for the component of interest, assumes
% stimulus starts at 0.
% conds is a cell erray with names of fildtrip data files (averaged or
% epoched) for different conditions
% groups is a matrix with 1st row sub numbers, second row indicates 0 - not
% to analize, or a positive number for group number (1,2...)
% if needs to skip to a particular stage use skipto, 1 to 5. 1 for covariance (beggining, not really skipping),
% 2 for head model, 3 for beamforming, 4 for grand averaging and 5 for montecarlo.
% after creating and saving a list of conditions 'conds' and groups (may be [] for one
% group) run:
% skipto=3
% load conds; load groups; covToMont('','c,rfhp0.1Hz',0.7,0.8,conds,groups,skipto);

%% lists the subject data folders
eval(['cd ',pat2data])
!ls > ls.txt
subjects=importdata('ls.txt')';
if isempty('groups'); % when no groups specified assumes all subjects valid members of one group
    groups=subjects;
    groups(2,:)=1;
end
condt=num2str(round(1000*(startt+endt)/2)); % component name for output files
if ~exist('skipto','var')
    skipto=1;
end
if isempty('skipto')
    skipto=1;
end
grid=[]; % avoid conflict with grid function
%load /media/disk/Sharon/MEG/Experiment3/Source_localization/subs
%load /media/disk/Sharon/MEG/Experiment3/Source_localization/conds
%% calculating covariance matrices
if skipto==1
for sub=1:size(subjects,2)
    pat=num2str(subjects(sub));
    for con=1:size(conds,2)
        c=conds{1,con};
        load ([pat,'/',c]);
        covst=eval(c); %#ok<NASGU>
        cfg                  = [];
        cfg.covariance       = 'yes';
        cfg.removemean       = 'no';
        cfg.covariancewindow = [(startt-endt) 0];
        cfg.channel='MEG';
        eval(['pre',num2str(con),'=timelockanalysis(cfg, covst)']);
        cfg.covariancewindow = [startt endt];
        eval(['pst',num2str(con),'=timelockanalysis(cfg, covst)']);
    end
    save ([num2str(subjects(sub)),'/cov',condt], 'pst*' ,'pre*');
    display(sub);
end
end
%% building head model if necessary
if skipto<=2
cfg=[];
cfg.model='singleshell';
for sub=1:size(subjects,2)  % size(subs,2)
    if ~exist([num2str(subjects(sub)),'/model.mat'],'file')
    load([num2str(subjects(sub)),'/',conds{1,1}]);
    hdr=ft_read_header([num2str(subjects(sub)),'/c,rfhp0.1Hz,lp']);
    angcond.grad=hdr.grad;
    [vol,grid]=YHmodelwithspm2test(cfg,angcond,[num2str(subjects(sub)),'/hs_file']);
    save([num2str(subjects(sub)),'/model'],'vol','grid');
    end
end
end

%% LCMV beamforming
if skipto<=3
    for sub=1:size(subjects,2); % change to 1:19 or 1:25
        pat=num2str(subjects(sub));
        load ([pat,'/cov',condt]);
        hdr=ft_read_header([pat,'/',fileName]);
        grad=hdr.grad; %#ok<NASGU>
        load ([pat,'/model']);
        cfg        = [];
        cfg.method = 'lcmv';
        cfg.grid= grid;
        cfg.vol    = vol;
        cfg.lambda = '5%';
        cfg.keepfilter='yes';
        for con=1:size(conds,2)
            eval(['pre',num2str(con),'.grad=grad']);
            eval(['pst',num2str(con),'.grad=grad']);
            eval(['spre',num2str(con),'  = sourceanalysis(cfg, pre',num2str(con),')']);
            eval(['spst',num2str(con),'  = sourceanalysis(cfg, pst',num2str(con),')']);
            eval(['spst',num2str(con),'.avg.nai=(spst',num2str(con),'.avg.pow./spre',num2str(con),'.avg.pow)-spre',num2str(con),'.avg.pow']);
            eval(['save ',pat,'/s',num2str(con),condt,' spre',num2str(con),' spst',num2str(con)]);
            eval(['clear spre',num2str(con),' spst',num2str(con),' pre',num2str(con),' pst',num2str(con)])
        end
    end
end
%% Grand Averaging
if skipto<=4
    load pos
for con=1:size(conds,2)
    str='';
    for sub=1:size(subjects,2)
        group=groups(2,find(groups(1,:)==(subjects(sub))));
        if group>0;
            load ([num2str(subjects(sub)),'/s',num2str(con),condt]);
            eval(['s',num2str(con),'_',num2str(subjects(sub)),'=spst',num2str(con)]);
            eval(['s',num2str(con),'_',num2str(subjects(sub)),'.dim=[15,18,15]'])
            eval(['s',num2str(con),'_',num2str(subjects(sub)),'.pos=pos'])
            str=[str,',s',num2str(con),'_',num2str(subjects(sub))]; %#ok<AGROW>
            clear sp*
            display(subjects(sub));
        end
    end
    cfg                    = [];
    cfg.parameter          = 'pow'; % 'pow' 'nai' or 'coh'
    cfg.keepindividual     = 'yes';
    eval(['s',num2str(con),'p=sourcegrandaverage(cfg,',str(2:size(str,2)),')']);
    eval(['save s',num2str(con),'p',condt,' s',num2str(con),'p']);
    cfg.parameter='nai';
    eval(['s',num2str(con),'n=sourcegrandaverage(cfg,',str(2:size(str,2)),')']);
    eval(['save s',num2str(con),'n',condt,' s',num2str(con),'n']);
    clear *_* *n *p
end
end
if skipto<=5
    display('montecarlo not integrated yet')
end
end
