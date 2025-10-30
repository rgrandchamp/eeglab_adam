function pop_adam_tgm_viewer()
% POP_ADAM_TGM_VIEWER - Compute & plot temporal generalization matrices (group MVPA).
%
% Adds optional training window (ms) and training reduction:
%   - Train window (ms): if both start & end are valid numbers, sets cfg.trainlim = [start end].
%                        If left empty/invalid -> does not set cfg.trainlim.
%   - Training reduction: none | avtrain | diag
%       * none   -> no cfg.reduce_dims field (full GAT)
%       * avtrain-> cfg.reduce_dims = 'avtrain' (avg over cfg.trainlim)
%       * diag   -> cfg.reduce_dims = 'diag' (diagonal decoding)
%
% Folder selection:
%   - If selected folder name contains "_VS_" -> single contrast
%   - Else -> process all immediate "*_VS_*" subfolders
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
    [1 0.8 0.8] ...         % Train window ms: label + start + end  <-- FIXED: 3 columns
    [1 2] ...               % Training reduction
    [1 2] ...               % plot_order
    [1 1] ...               % Buttons (Compute & Plot, Close)
    };

uilist = {};
addc({ 'style' 'text' 'string' 'ADAM: Temporal generalization (single or multi-contrast) with optional training window' });

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
addc({ 'style' 'text' 'string' 'Iterations (e.g., 250 to save time):' });
addc({ 'style' 'edit' 'tag' 'iters' 'string' def.iterations });

% Train window (ms)  <-- three controls in this row to match geometry [1 0.8 0.8]
addc({ 'style' 'text' 'string' 'Train window (ms):   start        end' });
addc({ 'style' 'edit' 'tag' 'tstart' 'string' def.train_start_ms });
addc({ 'style' 'edit' 'tag' 'tend'   'string' def.train_end_ms });

% Training reduction
rdopts = {'none','avtrain','diag'};
addc({ 'style' 'text' 'string' 'Training reduction (reduce\_dims):' });
addc({ 'style' 'popupmenu' 'tag' 'rd' 'string' strjoin(rdopts,'|') ...
       'value' pickIndex(rdopts, def.reduce_dims_opt, 1) });

% plot_order
addc({ 'style' 'text' 'string' 'plot\_order (comma/space separated contrast names, optional):' });
addc({ 'style' 'edit' 'tag' 'plotord' 'string' def.plot_order_txt });

% Buttons
addc({ 'style' 'pushbutton' 'string' 'Compute & Plot' , 'callback', 'uiresume(gcbf);' });
addc({ 'style' 'pushbutton' 'string' 'Close'          , 'callback', 'close(gcbf);' });

% ---------- Open dialog ----------
res = inputgui('geometry', geometry, 'uilist', uilist, ...
    'title', 'ADAM Temporal Generalization Viewer');
if isempty(res), return; end

% ---------- Map outputs (order of edit/popup we added) ----------
idx = 0;
target_folder = nextstr(res);   % edit: tgt
mp_i          = nextnum(res);   % popup: mp
iters_txt     = nextstr(res);   % edit: iters
tstart_txt    = nextstr(res);   % edit: tstart
tend_txt      = nextstr(res);   % edit: tend
rd_i          = nextnum(res);   % popup: rd
plotord_txt   = nextstr(res);   % edit: plotord

% ---------- Validate target ----------
target_folder = strtrim(target_folder);
if isempty(target_folder) || ~exist(target_folder,'dir')
    errordlg('Please choose a valid target folder.','ADAM'); return;
end
setpref('eeglab_adam','resultsRoot', target_folder);

% Build contrast list
if is_contrast_folder(target_folder)
    contrast_paths = {target_folder};
else
    contrast_paths = find_contrast_subfolders(target_folder, def.scan_recursive);
    if isempty(contrast_paths)
        errordlg('No contrast subfolders (*_VS_*) found in the selected folder.','ADAM'); return;
    end
end

% Parse iterations
iterations = round(str2double(strtrim(iters_txt)));
if ~isfinite(iterations) || iterations < 1
    warndlg('Invalid iterations value; falling back to 250.','ADAM');
    iterations = 250;
end

% Parse training window (ms)
has_trainlim = false; trainlim = [];
tstart_txt = strtrim(tstart_txt);
tend_txt   = strtrim(tend_txt);
if ~isempty(tstart_txt) && ~isempty(tend_txt)
    tstart = str2double(tstart_txt);
    tend   = str2double(tend_txt);
    if isfinite(tstart) && isfinite(tend) && (tend > tstart)
        has_trainlim = true;
        trainlim = [tstart, tend];
    else
        warndlg('Invalid train window. Leave empty or provide two numbers in ms (start < end).','ADAM');
    end
end

% reduce_dims choice
reduce_dims_val = pick(rdopts, rd_i, def.reduce_dims_opt);

% ---------- Build base cfg ----------
cfg_base = [];
cfg_base.startdir         = startdir_for(target_folder);
cfg_base.mpcompcor_method = pick(mpopts, mp_i, def.mpcompcor_method);
cfg_base.iterations       = iterations;

% Conditionally set trainlim
if has_trainlim
    cfg_base.trainlim = trainlim;
    % If you prefer explicit empty when not set: else cfg_base.trainlim = [];
end

% Conditionally set reduce_dims
switch lower(reduce_dims_val)
    case 'none'
        % do not set cfg_base.reduce_dims
    otherwise
        cfg_base.reduce_dims = reduce_dims_val; % 'avtrain' or 'diag'
end

% ---------- Compute MVPA for each contrast ----------
mvpa_stats = cell(1, numel(contrast_paths));
contrast_names = cell(1, numel(contrast_paths));
for k = 1:numel(contrast_paths)
    cdir = contrast_paths{k};
    cname = contrast_name(cdir);
    contrast_names{k} = cname;
    try
        eegh('[ADAM] TGM: contrast=%s | mp=%s | iterations=%d | trainlim=%s | reduce=%s', ...
            cdir, cfg_base.mpcompcor_method, cfg_base.iterations, ...
            tern(has_trainlim, sprintf('[%g %g]', trainlim(1), trainlim(2)), '<none>'), ...
            tern(isfield(cfg_base,'reduce_dims'), cfg_base.reduce_dims, '<none>'));
    catch
    end
    mvpa_stats{k} = adam_compute_group_MVPA(cfg_base, cdir);
end

% ---------- Plot all together ----------
cfgp = [];
ord = parse_plotorder(plotord_txt);
if ~isempty(ord), cfgp.plot_order = ord; end
adam_plot_MVPA(cfgp, mvpa_stats{:});

% Name figure if single contrast
if numel(contrast_paths)==1
    try, set(gcf,'Name',sprintf('ADAM TGM - %s', contrast_names{1}), 'NumberTitle', 'off'); end
end

% ==================== Callbacks (nested) ====================
    function onBrowseTarget(src,~)
        fig   = ancestor(src,'figure');
        editH = findobj(fig,'tag','tgt');
        p = uigetdir('','Select contrast folder or parent folder');
        if isequal(p,0), return; end
        set(editH,'string',p);
    end

% ==================== Utilities ====================
    function addc(c), uilist{end+1} = c; end %#ok<AGROW>
    function k = pickIndex(opts,val,defIdx), k = find(strcmpi(opts,val),1); if isempty(k), k = defIdx; end, end
    function v = pick(opts,i,defv), if isempty(i)||i<1||i>numel(opts), v=defv; else, v=opts{i}; end, end
    function tf = is_contrast_folder(p)
        if isempty(p) || ~exist(p,'dir'), tf = false; return; end
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
            d = dir(root); d = d([d.isdir]); names = {d.name};
            names = names(~ismember(lower(names),{'.','..'}));
            for i = 1:numel(names)
                sub = fullfile(root, names{i});
                if is_contrast_folder(sub), list{end+1} = sub; end %#ok<AGROW>
            end
        else
            dd = genpath(root);
            allp = regexp(dd, pathsep, 'split'); allp = allp(~cellfun(@isempty,allp));
            for i=1:numel(allp), if is_contrast_folder(allp{i}), list{end+1} = allp{i}; end, end
            list = unique(list,'stable');
        end
    end
    function n = contrast_name(p), [~,n] = fileparts(p); end
    function v = nextstr(cellres), idx=idx+1; v=cellres{idx}; if isstring(v), v=char(v); end; if ~ischar(v), v=''; end, end
    function n = nextnum(cellres), idx=idx+1; n=cellres{idx}; if isempty(n)||~isscalar(n), n=NaN; end, end
    function ord = parse_plotorder(s)
        ord = {}; if isstring(s), s=char(s); end; s=strtrim(s);
        if isempty(s), return; end
        s=strrep(strrep(s,',',' '),';',' ');
        parts = regexp(s,'\s+','split');
        ord = parts(~cellfun(@isempty,parts));
    end
    function out = tern(cond, a, b), if cond, out=a; else, out=b; end, end
end
