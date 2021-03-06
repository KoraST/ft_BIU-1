function [vol, cfg] = ft_prepare_headmodel(cfg, data)

% FT_PREPARE_HEADMODEL constructs a volume conduction model from
% the geometry of the head. The volume conduction model specifies how
% currents that are generated by sources in the brain, e.g. dipoles,
% are propagated through the tissue and how these result in externally
% measureable EEG potentials or MEG fields.
%
% FieldTrip implements a variety of forward solutions, some of them using
% external toolboxes or executables. Each of the forward solutions requires
% a set of configuration options which are listed below. This function
% takes care of all the preparatory steps in the construction of the volume
% conduction model and sets it up so that subsequent computations are
% efficient and fast.
%
% For EEG the following methods are available
%   singlesphere
%   asa
%   bemcp
%   dipoli
%   openmeeg
%   concentricspheres
%   halfspace
%   infinite
%   infinite_slab
%
% For MEG the following methods are available
%   singlesphere
%   localspheres
%   singleshell
%   infinite
%
% Use as
%   vol = ft_prepare_headmodel(cfg)
%   vol = ft_prepare_headmodel(cfg, vol)
%   vol = ft_prepare_headmodel(cfg, bnd)
%   vol = ft_prepare_headmodel(cfg, elec)
% 
% In general the input to this function is a geometrical description of the
% shape of the head and a description of the electrical conductivity. The
% second input argument (vol or bnd) can be a surface mesh that was
% obtained from FT_PREPARE_MESH or a segmented anatomical MRI that was
% obtained from FT_VOLUMESEGMENT. If the mesh is stored on disk, it can be
% provided as filename in cfg.hdmfile.
%
% The configuration structure should contain:
%     cfg.method            string that specifies the forward solution, see below
%     cfg.conductivity      a number or a vector containing the conductivities
%                           of the compartments
% 
% Additionally, the specific methods each have their specific configuration 
% options that are listed below.
% 
% BEMCP, DIPOLI, OPENMEEG
%     cfg.isolatedsource    (optional)
% 
% CONCENTRICSPHERES
%     cfg.fitind            (optional)
% 
% LOCALSPHERES
%     cfg.grad   
%     cfg.feedback          (optional)
%     cfg.radius            (optional)
%     cfg.maxradius         (optional)
%     cfg.baseline          (optional)
% 
% HALFSPACE
%     cfg.point     
%     cfg.submethod         (optional)
%     
% SIMBIO, FNS
%     cfg.tissue      
%     cfg.tissueval 
%     cfg.tissuecond  
%     cfg.sens      
%     cfg.transform   
%     cfg.unit      
% 
% INFINITE_SLAB
%     cfg.samplepoint
%     cfg.conductivity
%
% See also FT_PREPARE_MESH, FT_VOLUMESEGMENT, FT_VOLUMEREALIGN,
% FT_FETCH_SENS

% Copyright (C) 2011, Cristiano Micheli, Jan-Mathijs Schoffelen
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: ft_prepare_headmodel.m 5423 2012-03-09 10:13:06Z crimic $

revision = '$Id: ft_prepare_headmodel.m 5423 2012-03-09 10:13:06Z crimic $';

% do the general setup of the function
ft_defaults
ft_preamble help
ft_preamble trackconfig
ft_preamble callinfo

% check if the input cfg is valid for this function
cfg = ft_checkconfig(cfg, 'required', 'method');
cfg = ft_checkconfig(cfg, 'deprecated', 'geom');

% set the general defaults 
cfg.hdmfile        = ft_getopt(cfg, 'hdmfile');
cfg.headshape      = ft_getopt(cfg, 'headshape');
cfg.unit           = ft_getopt(cfg, 'unit');
cfg.conductivity   = ft_getopt(cfg, 'conductivity');
cfg.sourceunits    = ft_getopt(cfg, 'sourceunits');

% volume related options
cfg.tissue         = ft_getopt(cfg, 'tissue');
cfg.smooth         = ft_getopt(cfg, 'smooth');
cfg.threshold      = ft_getopt(cfg, 'threshold');

% other options
cfg.numvertices    = ft_getopt(cfg, 'numvertices');
cfg.isolatedsource = ft_getopt(cfg, 'isolatedsource');
cfg.fitind         = ft_getopt(cfg, 'fitind'); % concentricspheres
cfg.point          = ft_getopt(cfg, 'point'); % halfspace
cfg.submethod      = ft_getopt(cfg, 'submethod'); 
cfg.grad           = ft_getopt(cfg, 'grad'); % localspheres
cfg.feedback       = ft_getopt(cfg, 'feedback'); 
cfg.radius         = ft_getopt(cfg, 'radius');
cfg.maxradius      = ft_getopt(cfg, 'maxradius');
cfg.baseline       = ft_getopt(cfg, 'baseline');
cfg.singlesphere   = ft_getopt(cfg, 'singlesphere');
cfg.tissueval      = ft_getopt(cfg, 'tissueval'); % FEM 
cfg.tissuecond     = ft_getopt(cfg, 'tissuecond'); 
cfg.transform      = ft_getopt(cfg, 'transform'); 

if nargin>1, 
  data = ft_checkdata(data); 
else
  data = [];
end

% new way of getting sens structure:
%cfg.sens           = ft_getopt(cfg, 'sens'); 
try
  cfg.sens = ft_fetch_sens(cfg, data);
catch
  cfg.sens = [];
end

% if the conductivity is in the data cfg.conductivity is overwritten
if nargin>1 && isfield(data,'cond')
  cfg.conductivity = data.cond;
end

% boolean variables to manages the different input types
hasdata    = ~isempty(data);
hasvolume  = ft_datatype(data, 'volume');
needvolcnd = strcmp(cfg.method,'asa'); % only for ASA
needvolume = strcmp(cfg.method,'fns') || strcmp(cfg.method,'simbio'); % only for FNS & SIMBIO
needbnd    = ~needvolcnd && ~needvolume; % all other methods

% new way of getting headmodel structure:
geometry = [];
if needvolcnd
  cfg = ft_checkconfig(cfg, 'required', 'hdmfile');
  asafilename = cfg.hdmfile;
elseif needbnd && hasdata && ~hasvolume
  geometry = ft_fetch_headshape(cfg,data);
elseif needbnd && ~hasdata
  geometry = ft_fetch_headshape(cfg);
elseif needvolume && hasvolume
  fprintf('using the specified geometrical description\n');
  geometry = data;  
elseif hasvolume && needbnd
  fprintf('computing the geometrical description from the segmented MRI\n');
  if issegmentation(data,cfg);
    % construct a surface-based geometry from the segmented compartments
    % (can be multiple shells)   
    if isempty(cfg.tissue) 
      if strcmp(cfg.method,'singleshell') || strcmp(cfg.method,'singlesphere')
        tmpcfg = [];
        tmpcfg.tissue       = cfg.tissue;
        tmpcfg.smooth       = cfg.smooth;
        tmpcfg.sourceunits  = cfg.sourceunits;
        tmpcfg.threshold    = cfg.threshold;
        tmpcfg.numvertices  = cfg.numvertices;
        geometry = prepare_singleshell(tmpcfg,data);    
      else
         % tries to infer which fields in the segmentations are the segmented compartments
        [dum,tissue] = issegmentation(data,cfg);
        % ...and then tessellates all!
        tmpcfg = [];
        tmpcfg.tissue       = tissue;
        tmpcfg.smooth       = cfg.smooth;
        tmpcfg.sourceunits  = cfg.sourceunits;
        tmpcfg.threshold    = cfg.threshold;
        tmpcfg.numvertices  = cfg.numvertices;
        geometry = prepare_shells(tmpcfg,data); 
      end
    end
  else
    error('The input data should already contain at least one field with a segmented volume');
  end
else
  error('Not able to find or build a geometrical description for the head');
end

% the construction of the volume conductor model is performed below
switch cfg.method
  case 'asa'
    vol = ft_headmodel_bem_asa(asafilename);
    
  case {'bemcp' 'dipoli' 'openmeeg'}
    if strcmp(cfg.method,'bemcp')
      funname = 'ft_headmodel_bemcp';
    elseif strcmp(cfg.method,'dipoli')
      funname = 'ft_headmodel_bem_dipoli';
    else
      funname = 'ft_headmodel_bem_openmeeg';
    end
    vol = feval(funname, geometry,'conductivity',cfg.conductivity,'isolatedsource',cfg.isolatedsource);
  
  case 'concentricspheres'
    vol = ft_headmodel_concentricspheres(geometry,'conductivity',cfg.conductivity,'fitind',cfg.fitind);
    
  case 'halfspace'
    cfg.point     = ft_getopt(cfg, 'point',     []);
    cfg.submethod = ft_getopt(cfg, 'submethod', []);
    cfg.conductivity = ft_getopt(cfg, 'conductivity',   []);
    vol = ft_headmodel_halfspace(geometry, cfg.point, 'conductivity',cfg.conductivity,'submethod',cfg.submethod);
    
  case 'infinite'
    vol = ft_headmodel_infinite;
    
  case 'localspheres'
    cfg.grad      = ft_getopt(cfg, 'grad',      []);
    if isempty(cfg.grad)
      error('for cfg.method = %s, you need to supply a cfg.grad structure', cfg.method);
    end
    vol = ft_headmodel_localspheres(geometry,cfg.grad,'feedback',cfg.feedback,'radius',cfg.radius,'maxradius',cfg.maxradius,'baseline',cfg.baseline,'singlesphere',cfg.singlesphere);
    
  case 'singleshell'
    vol = ft_headmodel_singleshell(geometry);
    
  case 'singlesphere'
    cfg.conductivity   = ft_getopt(cfg, 'conductivity',   []);
    if isempty(geometry) && ~isempty(cfg.hdmfile)
      geometry = ft_read_headshape(cfg.hdmfile);
    elseif isempty(geometry)
      error('no input available')
    end
    vol = ft_headmodel_singlesphere(geometry,'conductivity',cfg.conductivity);
    
  case {'simbio' 'fns'}
    if length([cfg.tissue cfg.tissueval cfg.tissuecond cfg.elec cfg.transform cfg.unit])<6
      error('Not all the required fields have been provided, see help')
    end
    if strcmp(method,'simbio')
      funname = 'ft_headmodel_fem_simbio';
    else
      funname = 'ft_headmodel_fdm_fns';
    end
    vol = feval(funname,geometry,'tissue',cfg.tissue,'tissueval',cfg.tissueval, ...
                               'tissuecond',cfg.tissuecond,'sens',cfg.sens, ...
                               'transform',cfg.transform,'unit',cfg.unit); 

  case 'slab_monopole'
    % geometry is composed by a structarray of 2 elements, each containing
    % 'pnt' field
    if numel(geometry)==2
      geom1 = geometry(1); 
      geom2 = geometry(2);
      P     = cfg.point;
      vol = ft_headmodel_slab(geom1,geom2,P,'sourcemodel','monopole','conductivity',cfg.conductivity);
    else
      error('geometry should be described by exactly 2 sets of points')
    end

  otherwise
    error('unsupported method "%s"', cfg.method);
end

% ensure that the geometrical units are specified
vol = ft_convert_units(vol);

% do the general cleanup and bookkeeping at the end of the function
ft_postamble trackconfig
ft_postamble callinfo
ft_postamble history vol

%FIXME: the next section is supposed to be partially transferred to other functions (e.g. ft_surface...)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% volumetric/mesh functions (either seg2seg or seg2mesh)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [res,fnames] = issegmentation(mri,cfg)
res = false;
names = {'segmentation', 'segment', 'seg', 'csf', 'white', 'gray', 'skull', 'scalp', 'brain'};
fnames = {};
tmp = fieldnames(mri);

cnt = 1;
for i=1:numel(tmp)
  if ismember(tmp{i},names)
    fnames{cnt} = tmp{i};
    res = true; cnt = cnt +1;
  end
end

% checks for existence of fields declared in the cfg.tissue option
if isfield(cfg,'tissue')
  if ~isempty(cfg.tissue) && ~isnumeric(cfg.tissue)
    res = true;
  end
end

function bnd          = prepare_shells(cfg,mri)
% Calculates the surfaces of each compartment from a segmentation or from
% an MRI volume structure to be segmented. As such the input always
% contains volumetric information.
% 
% The segmentation can be of two different types:
% - a raw segmentation: given as a 3D data matrix 
%   Requires the cfg.tissue option to be a set of numbers (intensity value of the
%   compartments)
% 
% - a mri segmentation: given as a mri volume with the segmented compartments as fields
%   Requires the cfg.tissue option to be a set of strings (the names of the
%   fields of actual input structure)
% 
% Required options:
% 
% cfg.tissue                  the tissue number/string
% cfg.numvertices             the desired number of vertices

% FIXME: introduce the sourceunits control as in prepare_singleshell

% process the inputs
tissue      = ft_getopt(cfg,'tissue');
sourceunits = ft_getopt(cfg, 'sourceunits', 'cm');
smoothseg   = ft_getopt(cfg, 'smooth',      5);
threshseg   = ft_getopt(cfg, 'threshold',   0.5); 
numvertices = ft_getopt(cfg, 'numvertices', 3000);

% check options consistency
ntissues = numel(tissue);
if ntissues>1
  % assign one single parameter to each tissue if more than one tissue
  if numel(numvertices)==1
    numvertices(1:ntissues) = numvertices(1);
  elseif numel(numvertices)~=ntissues
    error('tissues and vertices do not match')
  end
  if numel(smoothseg)==1
    smoothseg(1:ntissues) = smoothseg(1);
  elseif numel(smoothseg)~=ntissues
    error('tissues and smooth parameter do not match')
  end  
  if numel(threshseg)==1
    threshseg(1:ntissues) = threshseg(1);
  elseif numel(threshseg)~=ntissues
    error('tissues and threshold parameter do not match')
  end
else % only one tissue, choose the first parameter
  numvertices = numvertices(1);
  smoothseg   = smoothseg(1);
  threshseg   = threshseg(1);
end

% do the mesh extrapolation
for i =1:numel(tissue)
  if ~isnumeric(tissue(i))
    comp = tissue{i};
    seg = mri.(comp);
  else
    seg = mri==tissue(i);
  end
  seg    = dosmoothing(seg, smoothseg(i), num2str(i));
  seg    = threshold(seg, threshseg(i), num2str(i));
  seg    = fill(seg, num2str(i));
  bnd(i) = dotriangulate(seg, numvertices(i), num2str(i));
end

function bnd          = dotriangulate(seg, nvert, str)
% Triangulates a volume, and creates a boundary out of it
% by projecting rays from the center of the 3D matrix 

% str is just a placeholder for messages
dim = size(seg);
[mrix, mriy, mriz] = ndgrid(1:dim(1), 1:dim(2), 1:dim(3));

% make local variable seg logical 
seg = logical(seg);

% construct the triangulations of the boundaries from the segmented MRI
fprintf('triangulating the boundary of compartment %s\n', str);
ori(1) = mean(mrix(seg(:)));
ori(2) = mean(mriy(seg(:)));
ori(3) = mean(mriz(seg(:)));
[pnt, tri] = triangulate_seg(seg, nvert, ori); 

% output
bnd.pnt = pnt;
bnd.tri = tri;
fprintf(['segmentation compartment %s completed\n'],str);

function [output]     = threshold(input, thresh, str)

if thresh>0 && thresh<1
  fprintf('thresholding %s at a relative threshold of %0.3f\n', str, thresh);

  % mask by taking the negative of the brain, thus ensuring
  % that no holes are within the compartment and do a two-pass 
  % approach to eliminate potential vitamin E capsules etc.

  output   = double(input>(thresh*max(input(:))));
  [tmp, N] = spm_bwlabel(output, 6);
  for k = 1:N
    n(k,1) = sum(tmp(:)==k);
  end
  output   = double(tmp~=find(n==max(n))); clear tmp;
  [tmp, N] = spm_bwlabel(output, 6);
  for k = 1:N
    m(k,1) = sum(tmp(:)==k);
  end
  output   = double(tmp~=find(m==max(m))); clear tmp;
else
  output = input;
end

function [output]     = fill(input, str)
fprintf('filling %s\n', str);
  output = input;
  dim = size(input);
  for i=1:dim(2)
    slice=squeeze(input(:,i,:));
    im = imfill(slice,8,'holes');
    output(:,i,:) = im;
  end

function [output]     = dosmoothing(input, fwhm, str)
if fwhm>0
  fprintf('smoothing %s with a %d-voxel FWHM kernel\n', str, fwhm);
  spm_smooth(input, input, fwhm);
end
output = input;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mesh functions (mesh2mesh)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bnd = prepare_singleshell(cfg,mri)
% prepares the spheres boundaries for the methods 'singlesphere' and
% 'singleshell'
cfg.sourceunits    = ft_getopt(cfg, 'sourceunits', 'cm');
cfg.smooth         = ft_getopt(cfg, 'smooth',      5);
cfg.threshold      = ft_getopt(cfg, 'threshold',   0.5); 
cfg.numvertices    = ft_getopt(cfg, 'numvertices', 3000);

if ~isfield(mri, 'unit'), mri = ft_convert_units(mri); end

fprintf('using the segmented MRI\n');

if isfield(mri, 'gray') || isfield(mri, 'white') || isfield(mri, 'csf')
  % construct the single image segmentation from the three probabilistic
  % tissue segmentations for csf, white and gray matter
  mri.seg = zeros(size(mri.gray ));
  if isfield(mri, 'gray')
    fprintf('including gray matter in segmentation for brain compartment\n')
    mri.seg = mri.seg | (mri.gray>(cfg.threshold*max(mri.gray(:))));
  end
  if isfield(mri, 'white')
    fprintf('including white matter in segmentation for brain compartment\n')
    mri.seg = mri.seg | (mri.white>(cfg.threshold*max(mri.white(:))));
  end
  if isfield(mri, 'csf')
    fprintf('including CSF in segmentation for brain compartment\n')
    mri.seg = mri.seg | (mri.csf>(cfg.threshold*max(mri.csf(:))));
  end
  if ~strcmp(cfg.smooth, 'no'),
    fprintf('smoothing the segmentation with a %d-pixel FWHM kernel\n',cfg.smooth);
    mri.seg = double(mri.seg);
    spm_smooth(mri.seg, mri.seg, cfg.smooth);
  end
  % threshold for the last time
  mri.seg = (mri.seg>(cfg.threshold*max(mri.seg(:))));
elseif isfield(mri, 'brain')
  mri.seg = mri.brain;
elseif isfield(mri, 'scalp')
  mri.seg = mri.scalp;
end

[mrix, mriy, mriz] = ndgrid(1:size(mri.seg,1), 1:size(mri.seg,2), 1:size(mri.seg,3));

% construct the triangulations of the boundary from the segmented MRI
fprintf('triangulating the boundary of single shell compartment\n', i);
seg = imfill((mri.seg==1), 'holes');
ori(1) = mean(mrix(seg(:)));
ori(2) = mean(mriy(seg(:)));
ori(3) = mean(mriz(seg(:)));
[pnt, tri] = triangulate_seg(seg, cfg.numvertices, ori);
% FIXME: corrects the original tri because is weird
%tri = projecttri(pnt);
% apply the coordinate transformation from voxel to head coordinates
pnt(:,4) = 1;
pnt = (mri.transform * (pnt'))';
pnt = pnt(:,1:3);

% convert the MRI surface points into the same units as the source/gradiometer
scale = 1;
switch cfg.sourceunits
  case 'mm'
    scale = scale * 1000;
  case 'cm'
    scale = scale * 100;
  case 'dm'
    scale = scale * 10;
  case 'm'
    scale = scale * 1;
  otherwise
    error('unknown physical dimension in cfg.sourceunits');
end
switch mri.unit
  case 'mm'
    scale = scale / 1000;
  case 'cm'
    scale = scale / 100;
  case 'dm'
    scale = scale / 10;
  case 'm'
    scale = scale / 1;
  otherwise
    error('unknown physical dimension in mri.unit');
end
if scale~=1
  fprintf('converting MRI surface points from %s into %s\n', cfg.sourceunits, mri.unit);
  pnt = pnt* scale;
end

bnd.pnt = pnt;
bnd.tri = tri;
fprintf('Triangulation completed\n');

function bnd = prepare_mesh_headshape(cfg)

% PREPARE_MESH_HEADSHAPE
%
% See also PREPARE_MESH_MANUAL, PREPARE_MESH_SEGMENTATION

% Copyrights (C) 2009, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: ft_prepare_headmodel.m 5423 2012-03-09 10:13:06Z crimic $

% get the surface describing the head shape
if isstruct(cfg.headshape) && isfield(cfg.headshape, 'pnt') 
  % use the headshape surface specified in the configuration
  headshape = cfg.headshape;
elseif isstruct(cfg.headshape) &&  isfield(cfg.headshape, 'bnd')
  for i=1:numel(cfg.headshape.bnd)
    headshape(i).pnt = cfg.headshape.bnd(i).pnt;
    headshape(i).tri = cfg.headshape.bnd(i).tri;
  end
elseif isnumeric(cfg.headshape) && size(cfg.headshape,2)==3
  % use the headshape points specified in the configuration
  headshape.pnt = cfg.headshape;
elseif ischar(cfg.headshape)
  % read the headshape from file
  headshape = ft_read_headshape(cfg.headshape);
else
  error('cfg.headshape is not specified correctly')
end

% usually a headshape only describes a single surface boundaries, but there are cases
% that multiple surfaces are included, e.g. skin_surface, outer_skull_surface, inner_skull_surface
nbnd = numel(headshape);

if ~isfield(headshape, 'tri')
  % generate a closed triangulation from the surface points
  for i=1:nbnd
    headshape(i).pnt = unique(headshape(i).pnt, 'rows');
    headshape(i).tri = projecttri(headshape(i).pnt);
  end
end

if ~isempty(cfg.numvertices) && ~strcmp(cfg.numvertices, 'same')
  for i=1:nbnd
    tri1 = headshape(i).tri;
    pnt1 = headshape(i).pnt;
    % The number of vertices is multiplied by 3 in order to have more
    % points on the original mesh than on the sphere mesh (see below).
    % The rationale for this is that every projection point on the sphere
    % has three corresponding points on the mesh
    if (cfg.numvertices>size(pnt1,1))
      [tri1, pnt1] = refinepatch(headshape(i).tri, headshape(i).pnt, 3*cfg.numvertices);
    else
      [tri1, pnt1] = reducepatch(headshape(i).tri, headshape(i).pnt, 3*cfg.numvertices);
    end
    
    % remove double vertices
    [pnt1, tri1] = remove_double_vertices(pnt1, tri1);
    
    % replace the probably unevenly distributed triangulation with a regular one
    % and retriangulate it to the desired accuracy
    [pnt2, tri2] = mysphere(cfg.numvertices); % this is a regular triangulation
    [pnt1, tri1] = retriangulate(pnt1, tri1, pnt2, tri2, 2);
    [pnt1, tri1] = fairsurface(pnt1, tri1, 1);% this helps redistribute the superimposed points
    
    % remove double vertices
    [headshape(i).pnt,headshape(i).tri] = remove_double_vertices(pnt1, tri1);
    fprintf('returning %d vertices, %d triangles\n', size(headshape(i).pnt,1), size(headshape(i).tri,1));
  end
end

% the output should only describe one or multiple boundaries and should not
% include any other fields
bnd = rmfield(headshape, setdiff(fieldnames(headshape), {'pnt', 'tri'}));

function [tri1, pnt1] = refinepatch(tri, pnt, numvertices)
fprintf('the original mesh has %d vertices against the %d requested\n',size(pnt,1),numvertices/3);
fprintf('trying to refine the compartment...\n');
[pnt1, tri1] = refine(pnt, tri, 'updown', numvertices);

function [pnt, tri]   = mysphere(N)
% This is a copy of MSPHERE without the confusing output message
% Returns a triangulated sphere with approximately M vertices
% that are nicely distributed over the sphere. The vertices are aligned
% along equally spaced horizontal contours according to an algorithm of
% Dave Russel.
% 
% Use as
%  [pnt, tri] = msphere(M)
%
% See also SPHERE, NSPHERE, ICOSAHEDRON, REFINE
% Copyright (C) 1994, Dave Rusin 

storeM    = [];
storelen  = [];
increaseM = 0;
while (1)

  % put a single vertex at the top
  phi = [0];
  th  = [0];

  M = round((pi/4)*sqrt(N)) + increaseM;
  for k=1:M
    newphi = (k/M)*pi;
    Q = round(2*M*sin(newphi));
    for j=1:Q
      phi(end+1) = newphi;
      th(end+1)  = (j/Q)*2*pi;
      % in case of even number of contours
      if mod(M,2) & k>(M/2)
        th(end) = th(end) + pi/Q;
      end
    end
  end

  % put a single vertex at the bottom
  phi(end+1) = [pi];
  th(end+1)  = [0];

  % store this vertex packing
  storeM(end+1).th  = th;
  storeM(end  ).phi = phi;
  storelen(end+1) = length(phi);
  if storelen(end)>N
    break;
  else
    increaseM = increaseM+1;
    % fprintf('increasing M by %d\n', increaseM);
  end
end

% take the vertex packing that most closely matches the requirement
[m, i] = min(abs(storelen-N));
th  = storeM(i).th;
phi = storeM(i).phi;

% convert from spherical to cartehsian coordinates
[x, y, z] = sph2cart(th, pi/2-phi, 1);
pnt = [x' y' z'];
tri = convhulln(pnt);

function [pntR, triR] = remove_double_vertices(pnt, tri)

% REMOVE_VERTICES removes specified vertices from a triangular mesh
% renumbering the vertex-indices for the triangles and removing all
% triangles with one of the specified vertices.
%
% Use as
%   [pnt, tri] = remove_double_vertices(pnt, tri)

pnt1 = unique(pnt, 'rows');
keeppnt   = find(ismember(pnt1,pnt,'rows'));
removepnt = setdiff([1:size(pnt,1)],keeppnt);

npnt = size(pnt,1);
ntri = size(tri,1);

if all(removepnt==0 | removepnt==1)
  removepnt = find(removepnt);
end

% remove the vertices and determine the new numbering (indices) in numb
keeppnt = setdiff(1:npnt, removepnt);
numb    = zeros(1,npnt);
numb(keeppnt) = 1:length(keeppnt);

% look for triangles referring to removed vertices
removetri = false(ntri,1);
removetri(ismember(tri(:,1), removepnt)) = true;
removetri(ismember(tri(:,2), removepnt)) = true;
removetri(ismember(tri(:,3), removepnt)) = true;

% remove the vertices and triangles
pntR = pnt(keeppnt, :);
triR = tri(~removetri,:);

% renumber the vertex indices for the triangles
triR = numb(triR);

function [pnt1, tri1] = fairsurface(pnt, tri, N)

% FAIRSURFACE modify the mesh in order to reduce overlong edges, and
% smooth out "rough" areas. This is a non-shrinking smoothing algorithm.
% The procedure uses an elastic model : At each vertex, the neighbouring
% triangles and vertices connected directly are used. Each edge is
% considered elastic and can be lengthened or shortened, depending
% on their length. Displacement are done in 3D, so that holes and
% bumps are attenuated.
%
% Use as
%   [pnt, tri] = fairsurface(pnt, tri, N);
% where N is the number of smoothing iterations.
%
% This implements:
%   G.Taubin, A signal processing approach to fair surface design, 1995

% This function corresponds to spm_eeg_inv_ElastM
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging
%                    Christophe Phillips & Jeremie Mattout
% spm_eeg_inv_ElastM.m 1437 2008-04-17 10:34:39Z christophe
%
% $Id: ft_prepare_headmodel.m 5423 2012-03-09 10:13:06Z crimic $

ts = [];
ts.XYZmm = pnt';
ts.tri   = tri';
ts.nr(1) = size(pnt,1);
ts.nr(2) = size(tri,1);

% Connection vertex-to-vertex
%--------------------------------------------------------------------------
M_con = sparse([ts.tri(1,:)';ts.tri(1,:)';ts.tri(2,:)';ts.tri(3,:)';ts.tri(2,:)';ts.tri(3,:)'], ...
  [ts.tri(2,:)';ts.tri(3,:)';ts.tri(1,:)';ts.tri(1,:)';ts.tri(3,:)';ts.tri(2,:)'], ...
  ones(ts.nr(2)*6,1),ts.nr(1),ts.nr(1));

kpb   = .1;                       % Cutt-off frequency
lam   = .5; mu = lam/(lam*kpb-1); % Parameters for elasticity.
XYZmm = ts.XYZmm;

% smoothing iterations
%--------------------------------------------------------------------------
for j=1:N

  XYZmm_o = zeros(3,ts.nr(1)) ;
  XYZmm_o2 = zeros(3,ts.nr(1)) ;

  for i=1:ts.nr(1)
    ln = find(M_con(:,i));
    d_i = sqrt(sum((XYZmm(:,ln)-XYZmm(:,i)*ones(1,length(ln))).^2));
    w_i = d_i/sum(d_i);
    XYZmm_o(:,i) = XYZmm(:,i) + ...
      lam * sum((XYZmm(:,ln)-XYZmm(:,i)*ones(1,length(ln))).*(ones(3,1)*w_i),2);
  end

  for i=1:ts.nr(1)
    ln = find(M_con(:,i));
    d_i = sqrt(sum((XYZmm(:,ln)-XYZmm(:,i)*ones(1,length(ln))).^2));
    w_i = d_i/sum(d_i);
    XYZmm_o2(:,i) = XYZmm_o(:,i) + ...
      mu * sum((XYZmm_o(:,ln)-XYZmm_o(:,i)*ones(1,length(ln))).*(ones(3,1)*w_i),2);
  end

  XYZmm = XYZmm_o2;

end

% collect output results
%--------------------------------------------------------------------------

pnt1 = XYZmm';
tri1 = tri;

if 0
  % this is some test/demo code
  [pnt, tri] = icosahedron162;

  scale = 1+0.3*randn(size(pnt,1),1);
  pnt = pnt .* [scale scale scale];

  figure
  triplot(pnt, tri, [], 'faces')
  triplot(pnt, tri, [], 'edges')

  [pnt, tri] = fairsurface(pnt, tri, 10);

  figure
  triplot(pnt, tri, [], 'faces')
  triplot(pnt, tri, [], 'edges')
end
