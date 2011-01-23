function mesh = spm_eeg_inv_mesh(sMRI, Msize)
% Apply the inverse spatial deformation to the template mesh
% to obtain the individual cortical mesh
% save the individual .mat tesselation of the chosen size
%
% FORMAT [fid, mesh] = spm_eeg_inv_meshing(filename, Msize)
% Input:
% sMRI - name of the sMRI file
% Msize - size of the mesh (1-3)
% Output:
% fid    - fiducials (head surface + points inverse normalized from the template)
% mesh   - inverse - normalized canonical mesh
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Jeremie Mattout & Christophe Phillips
% $Id: spm_eeg_inv_mesh.m 2763 2009-02-19 14:50:58Z guillaume $


% SPM directory of canonical anatomy
%--------------------------------------------------------------------------
Cdir              = fullfile(spm('dir'), 'canonical');

if nargin == 0 || isempty(sMRI)
    % Use the template
    %----------------------------------------------------------------------
    mesh.template = true;
    mesh.Affine   = eye(4);
    mesh.sMRI     = fullfile(Cdir, 'single_subj_T1.nii');
else
    mesh.template = false;
    mesh.sMRI     = sMRI;
    mesh          = spm_eeg_inv_spatnorm(mesh);
end

[pth, nam]        = spm_fileparts(mesh.sMRI);

if nargin < 2
    Msize         = 2;
end

mesh.Msize        = Msize;

spm('Pointer','Watch');

% Canonical cortical mesh
%--------------------------------------------------------------------------
switch mesh.Msize
    case 1
        filename  = fullfile(Cdir, 'cortex_5124.surf.gii');
    case 2
        filename  = fullfile(Cdir, 'cortex_8196.surf.gii');
    case 3
        filename  = fullfile(Cdir, 'cortex_20484.surf.gii');
end

mesh.tess_mni     = export(gifti(filename), 'spm');

% Compute the cortical mesh from the template
%--------------------------------------------------------------------------
if ~mesh.template
    Tmesh         = spm_swarp(filename, mesh.def);
    suffind       = max(strfind(filename, 'cortex'));
    filename      = fullfile(pth, [nam filename(suffind:end)]);
    save(gifti(Tmesh), filename);
end

mesh.tess_ctx     = filename;

% Compute the scalp mesh from the template
%--------------------------------------------------------------------------
filename          = fullfile(Cdir, 'scalp_2562.surf.gii');

if ~mesh.template
    Tmesh         = spm_swarp(filename, mesh.def);
    suffind       = max(strfind(filename, 'scalp'));
    filename      = fullfile(pth, [nam filename(suffind:end)]);
    save(gifti(Tmesh), filename);
end

mesh.tess_scalp   = filename;


% Compute the outer skull mesh from the template
%--------------------------------------------------------------------------
filename          = fullfile(Cdir, 'oskull_2562.surf.gii');

if ~mesh.template
    Tmesh         = spm_swarp(filename, mesh.def);
    suffind       = max(strfind(filename, 'oskull'));
    filename      = fullfile(pth, [nam filename(suffind:end)]);
    save(gifti(Tmesh), filename);
end

mesh.tess_oskull  = filename;

% Compute the inner skull mesh from the template
%--------------------------------------------------------------------------
filename          = fullfile(Cdir, 'iskull_2562.surf.gii');

if ~mesh.template
    Tmesh         = spm_swarp(filename, mesh.def);
    suffind       = max(strfind(filename, 'iskull'));
    filename      = fullfile(pth, [nam filename(suffind:end)]);
    save(gifti(Tmesh), filename);
end

mesh.tess_iskull  = filename;

% datareg
%--------------------------------------------------------------------------
mesh.fid = export(gifti(mesh.tess_scalp), 'ft');
mesh.fid.unit     = 'mm';
mesh.fid.fid      = struct('pnt', [  1  85 -41; ...
                                   -83 -20 -65; ...
                                    83 -20 -65; ...
                                   -87 -11 -62; ...
                                    87 -11 -62], ...
                    'label', {{'nas'; 'lpa'; 'rpa'; 'FIL_CTF_L'; 'FIL_CTF_R'}});

if ~mesh.template
    fidpnt        = mesh.fid.fid;
    fidpnt        = export(spm_swarp(gifti(fidpnt), mesh.def), 'ft');
    mesh.fid.fid.pnt = fidpnt.pnt;
end


spm('Pointer','Arrow');
