function pop_adam_tgm_viewer()
% POP_ADAM_TGM_VIEWER - Compute & plot temporal generalization matrices (group MVPA).
%
% Adds:
%   - Train window (ms) + reduce_dims options.
%   - "Pick…" button next to plot_order, to select contrast names from Target.
%
% Author: <Your Name>, 2025 | License: GPLv3

% ---------- Defaults ----------
def.target_folder     = getpref('eeglab_adam','resultsRoot','');
def.mpcompcor_method  = 'cluster_based';
def.iterations        = '250';
def.plot_order_txt    = '';
def.train_start_ms    = '';
def.train_end_ms      = '';
def.reduce_dims_opt   = 'none';  % 'none' | 'avtrain' | 'diag'
def.scan_recursive    = false;

% ---------- GUI layout ----------
geometry = { ...
    [1] ...                 % Title
    [1 2 0.8] ...           % Target folder + edit + Browse
    [1 2] ...               % MCC method
    [1 2] ...               % Iterations
    [1 0.8 0.8] ...         % Train window: label + start + end
    [1 2] ...               % reduce_dims
    [1 2 0.8] ...           % plot_order + edit + Pick...
    };

uilist = {};
addc({ 'style' 'text' 'string' 'ADAM: Temporal generalization (with optional training window)' });

% Target folder
addc({ 'style' 'text'  'string' 'Target folder (contrast or parent):' });
addc({ 'style' 'edit'  'tag' 'tgt' 'string' def.target_folder });
addc({ 'style' 'pushbutton' 'string' 'Browse...' , 'callback', @onBrowseTarget });

% MCC method
mpopts = {'none','cluster_based','bonferroni','fdr'};
addc({ 'style' 'text' 'string' 'Multiple-comparison correction:' });
addc({ 'style' 'popupmenu' 'tag' 'mp' 'string' strjoin(mpopts,'|') ...
    'value' pickIndex(mpopts, def.mpcompcor_method, 2) });

% Iterations
addc({ 'style' 'text' 'string' 'Iterations (e.g., 250):' });
addc({ 'style' 'edit' 'tag' 'iters' 'string' def.iterations });

% Train window (ms)
addc({ 'style' 'text' 'string' 'Train window (ms):   start        end' });
addc({ 'style' 'edit' 'tag' 'tstart' 'string' def.train_start_ms });
addc({ 'style' 'edit' 'tag' 'tend'   'string' def.train_end_ms });

% reduce_dims
rdopts = {'none','avtrain','diag'};
addc({ 'style' 'text' 'string' 'Training reduction (reduce\_dims):' });
addc({ 'style' 'popupmenu' 'tag' 'rd' 'string' strjoin(rdopts,'|') ...
    'value' pickIndex(rdopts, def.reduce_dims_opt, 1) });

% plot_order + Pick
addc({ 'style' 'text' 'string' 'plot_order (contrast names):' });
addc({ 'style' 'edit' 'tag' 'plotord' 'string' def.plot_order_txt });
addc({ 'style' 'pushbutton' 'string' 'Pick…' , 'callback', @onPickContrasts });


% ---------- Open dialog ----------
res = inputgui('geometry', geometry, 'uilist', uilist, ...
    'title', 'ADAM Temporal Generalization Viewer');
if isempty(res), return; end

% ---------- Map outputs ----------
idx = 0;
target_folder = nextstr(res);
mp_i          = nextnum(res);
iters_txt     = nextstr(res);
tstart_txt    = nextstr(res);
tend_txt      = nextstr(res);
rd_i          = nextnum(res);
plotord_txt   = nextstr(res);

% ---------- Validate target ----------
target_folder = strtrim(target_folder);
if isempty(target_folder) || ~exist(target_folder,'dir')
    errordlg('Please choose a valid Target folder.','ADAM'); return;
end
setpref('eeglab_adam','resultsRoot', target_folder);

% Build contrast list to compute
if is_contrast_folder(target_folder)
    contrast_paths = {target_folder};
else
    contrast_paths = find_contrast_subfolders(target_folder, def.scan_recursive);
    if isempty(contrast_paths)
        errordlg('No contrast subfolders (*_VS_*) found in the selected folder.','ADAM'); return;
    end
end

% Iterations
iterations = round(str2double(strtrim(iters_txt)));
if ~isfinite(iterations) || iterations < 1
    warndlg('Invalid iterations; using 250.','ADAM'); iterations = 250;
end

% Train window
has_trainlim = false; trainlim = [];
tstart_txt = strtrim(tstart_txt);
tend_txt   = strtrim(tend_txt);
if ~isempty(tstart_txt) && ~isempty(tend_txt)
    tstart = str2double(tstart_txt);
    tend   = str2double(tend_txt);
    if isfinite(tstart) && isfinite(tend) && tend>tstart
        has_trainlim = true; trainlim = [tstart, tend];
    else
        warndlg('Invalid train window. Leave empty or provide two numbers in ms (start < end).','ADAM');
    end
end

% reduce_dims
reduce_dims_val = pick(rdopts, rd_i, def.reduce_dims_opt);

% ---------- Build cfg ----------
cfg_base = [];
cfg_base.startdir         = startdir_for(target_folder);
cfg_base.mpcompcor_method = pick(mpopts, mp_i, def.mpcompcor_method);
cfg_base.iterations       = iterations;
if has_trainlim, cfg_base.trainlim = trainlim; end
if ~strcmpi(reduce_dims_val,'none'), cfg_base.reduce_dims = reduce_dims_val; end

% ---------- Compute ----------
mvpa_stats = cell(1, numel(contrast_paths));
contrast_names = cell(1, numel(contrast_paths));
for k = 1:numel(contrast_paths)
    cdir = contrast_paths{k};
    cname = contrast_name(cdir);
    contrast_names{k} = cname;
    eegh_try('[ADAM] TGM: %s', cdir);
    mvpa_stats{k} = adam_compute_group_MVPA(cfg_base, cdir);
end

% ---------- Plot ----------
cfgp = [];
ord = parse_plotorder(plotord_txt);
if ~isempty(ord), cfgp.plot_order = ord; end
adam_plot_MVPA(cfgp, mvpa_stats{:});
if numel(contrast_paths)==1
    try, set(gcf,'Name',sprintf('ADAM TGM - %s', contrast_names{1}), 'NumberTitle', 'off'); end
end

% ==================== Callbacks ====================
    function onBrowseTarget(src,~)
        fig   = ancestor(src,'figure');
        editH = findobj(fig,'tag','tgt');
        p = uigetdir_smart(fig, 'tgt', 'Select contrast folder or parent folder');
        if isequal(p,0), return; end
        set(editH,'string',p);
    end

    function onPickContrasts(src,~)
        fig  = ancestor(src,'figure');
        root = get(findobj(fig,'tag','tgt'),'string');
        root = strtrim(root);
        if isempty(root) || ~exist(root,'dir')
            warndlg('Please choose a valid Target folder first.','ADAM'); return;
        end
        [names,~] = build_contrast_name_list(root, def.scan_recursive);
        if isempty(names)
            warndlg('No contrast folders (*_VS_*) found under Target.','ADAM'); return;
        end
        [idxL,ok] = listdlg('PromptString','Select contrasts to plot (order preserved):', ...
            'SelectionMode','multiple', 'ListString',names, 'ListSize',[280 360]);
        if ~ok, return; end
        set(findobj(fig,'tag','plotord'), 'string', strjoin(names(idxL), ', '));
    end

% ==================== Utilities ====================
    function addc(c), uilist{end+1} = c; end %#ok<AGROW>
    function k = pickIndex(opts,val,defIdx), k=find(strcmpi(opts,val),1); if isempty(k), k=defIdx; end, end
    function v = pick(opts,i,defv), if isempty(i)||i<1||i>numel(opts), v=defv; else, v=opts{i}; end, end
    function v = nextstr(cellres), idx=idx+1; v=cellres{idx}; if isstring(v), v=char(v); end; if ~ischar(v), v=''; end, end
    function n = nextnum(cellres), idx=idx+1; n=cellres{idx}; if isempty(n)||~isscalar(n), n=NaN; end, end
end

% ===== Shared helpers (same block as above) =====
function tf = is_contrast_folder(p)
if isempty(p) || ~exist(p,'dir'), tf=false; return; end
[~,name] = fileparts(p);
tf = contains(name,'_VS_','IgnoreCase',true);
end
function startd = startdir_for(selectedFolder)
if is_contrast_folder(selectedFolder)
    startd = fileparts(selectedFolder); if isempty(startd), startd = selectedFolder; end
else
    startd = selectedFolder;
end
end
function list = find_contrast_subfolders(root, recursiveFlag)
list = {};
if isempty(root) || ~exist(root,'dir'), return; end
if ~recursiveFlag
    d = dir(root); d = d([d.isdir]); names={d.name};
    names = names(~ismember(lower(names),{'.','..'}));
    for i=1:numel(names)
        sub = fullfile(root,names{i});
        if is_contrast_folder(sub), list{end+1}=sub; end %#ok<AGROW>
    end
else
    dd = genpath(root);
    allp = regexp(dd, pathsep, 'split'); allp = allp(~cellfun(@isempty,allp));
    for i=1:numel(allp), if is_contrast_folder(allp{i}), list{end+1}=allp{i}; end, end
    list = unique(list,'stable');
end
end
function [names,paths] = build_contrast_name_list(root, recursiveFlag)
if is_contrast_folder(root)
    names = {contrast_name(root)}; paths = {root}; return;
end
paths = find_contrast_subfolders(root, recursiveFlag);
names = cellfun(@contrast_name, paths, 'UniformOutput', false);
end
function n = contrast_name(p), [~,n] = fileparts(p); end
function eegh_try(fmt, varargin)
try, eegh(fmt, varargin{:}); catch, end
end
function ord = parse_plotorder(s)
ord = {};
if isstring(s), s = char(s); end
s = strtrim(s);
if isempty(s), return; end
s = strrep(strrep(s,',',' '),';',' ');
parts = regexp(s, '\s+', 'split');
ord = parts(~cellfun(@isempty,parts));
end
function p = uigetdir_smart(figHandle, editTag, titleStr)
% UIGETDIR_SMART - Open a folder picker starting at the current value of an edit field.
% If that path is invalid/empty, fall back to the current working directory (pwd).

cur = '';
h = findobj(figHandle,'tag',editTag);
if ~isempty(h)
    cur = strtrim(get(h,'string'));
end
if isempty(cur) || ~exist(cur,'dir')
    cur = pwd;
end
p = uigetdir(cur, titleStr);
end