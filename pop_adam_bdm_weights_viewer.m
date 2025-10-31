function pop_adam_bdm_weights_viewer()
% POP_ADAM_BDM_WEIGHTS_VIEWER - Compute (diag) and plot BDM activation patterns for one or many contrasts.
%
% Mirrors the OK/Cancel handling style of pop_adam_tgm_viewer.m (plain inputgui).
% Steps:
%   1) Select Target folder (a single "*_VS_*" contrast folder or a parent folder with many contrasts).
%   2) Optionally "Pick…" contrasts to fill cfg.plot_order.
%   3) Compute diagonal MVPA (reduce_dims='diag'), then plot patterns with adam_plot_BDM_weights.
%
% Author: <Your Name>, 2025 | License: GPLv3

% ---------- Defaults ----------
def.target_folder          = getpref('eeglab_adam','resultsRoot','');
def.mpcompcor_method       = 'cluster_based';
def.plot_order_txt         = '';
def.pattern_opt            = 'covpatterns';   % 'covpatterns' | 'weights'
def.weightlim_txt          = '[-1.2 1.2]';    % leave empty for ADAM default
def.timelim_txt            = '[250 400]';     % leave empty for ADAM default
def.scan_recursive         = false;

% ---------- GUI layout (like pop_adam_tgm_viewer) ----------
geometry = { ...
    [1] ...                 % Title
    [1 2 0.8] ...           % Target folder + edit + Browse
    [1 2] ...               % MCC method
    [1 2] ...               % Pattern type
    [1 2] ...               % weightlim
    [1 2] ...               % timelim
    [1 2 0.8] ...           % plot_order + edit + Pick...
    };

uilist = {};
addc({ 'style' 'text' 'string' 'ADAM: BDM activation patterns (covariance patterns / classifier weights)' });

% Target folder
addc({ 'style' 'text'  'string' 'Target folder (contrast or parent):' });
addc({ 'style' 'edit'  'tag' 'tgt' 'string' def.target_folder });
addc({ 'style' 'pushbutton' 'string' 'Browse...' , 'callback', @onBrowseTarget });

% MCC method
mpopts = {'none','cluster_based','bonferroni','fdr'};
addc({ 'style' 'text' 'string' 'Multiple-comparison correction:' });
addc({ 'style' 'popupmenu' 'tag' 'mp' 'string' strjoin(mpopts,'|') ...
      'value' pickIndex(mpopts, def.mpcompcor_method, 2) });

% Pattern type
ptopts = {'covpatterns','weights'};
addc({ 'style' 'text' 'string' 'Pattern type:' });
addc({ 'style' 'popupmenu' 'tag' 'pt' 'string' strjoin(ptopts,'|') ...
      'value' pickIndex(ptopts, def.pattern_opt, 1) });

% weightlim
addc({ 'style' 'text' 'string' 'Weight limits (e.g., [-1.2 1.2]):' });
addc({ 'style' 'edit' 'tag' 'wlim' 'string' def.weightlim_txt });

% timelim
addc({ 'style' 'text' 'string' 'Time window (ms, e.g., [250 400]):' });
addc({ 'style' 'edit' 'tag' 'tlim' 'string' def.timelim_txt });

% plot_order + Pick
addc({ 'style' 'text' 'string' 'plot_order (contrast names):' });
addc({ 'style' 'edit' 'tag' 'plotord' 'string' def.plot_order_txt });
addc({ 'style' 'pushbutton' 'string' 'Pick...' , 'callback', @onPickContrasts });

% ---------- Open dialog (plain inputgui like TGM viewer) ----------
res = inputgui('geometry', geometry, 'uilist', uilist, ...
               'title', 'ADAM BDM Activation Patterns');
if isempty(res), return; end

% ---------- Map outputs (same style as TGM viewer) ----------
idx = 0;
target_folder = nextstr(res);
mp_i          = nextnum(res);
pt_i          = nextnum(res);
wlim_txt      = nextstr(res);
tlim_txt      = nextstr(res);
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

% ---------- Build cfg for compute (diag) ----------
cfg_base = [];
cfg_base.startdir         = startdir_for(target_folder);
cfg_base.mpcompcor_method = pick(mpopts, mp_i, def.mpcompcor_method);
cfg_base.reduce_dims      = 'diag';  % train==test time

% ---------- Compute ----------
mvpa_stats     = cell(1, numel(contrast_paths));
contrast_names = cell(1, numel(contrast_paths));
for k = 1:numel(contrast_paths)
    cdir  = contrast_paths{k};
    cname = contrast_name(cdir);
    contrast_names{k} = cname;
    eegh_try('[ADAM] BDM patterns (compute diag): %s', cdir);
    mvpa_stats{k} = adam_compute_group_MVPA(cfg_base, cdir);
end

% ---------- Plot ----------
cfgp = [];
cfgp.mpcompcor_method       = cfg_base.mpcompcor_method;
cfgp.plotweights_or_pattern = pick(ptopts, pt_i, def.pattern_opt);

% weightlim
wlim = try_eval_vec(wlim_txt);
if isnumeric(wlim) && numel(wlim)==2 && all(isfinite(wlim))
    cfgp.weightlim = wlim(:)';
end

% timelim
tlim = try_eval_vec(tlim_txt);
if isnumeric(tlim) && numel(tlim)==2 && all(isfinite(tlim))
    cfgp.timelim = tlim(:)';
end

% plot_order
ord = parse_plotorder(plotord_txt);
if ~isempty(ord), cfgp.plot_order = ord; end

adam_plot_BDM_weights(cfgp, mvpa_stats{:});
if numel(contrast_paths)==1
    try, set(gcf,'Name',sprintf('ADAM BDM Activation Patterns - %s', contrast_names{1}), 'NumberTitle','off'); end
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
    function v = try_eval_vec(txt), try, v=eval(txt); catch, v=[]; end, end
end

% ===== Shared helpers (same as in pop_adam_tgm_viewer) =====
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
cur = '';
h = findobj(figHandle,'tag',editTag);
if ~isempty(h), cur = strtrim(get(h,'string')); end
if isempty(cur) || ~exist(cur,'dir'), cur = pwd; end
p = uigetdir(cur, titleStr);
end

function eegh_try(fmt, varargin)
try, eegh(fmt, varargin{:}); catch, end
end
