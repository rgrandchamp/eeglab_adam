function pop_adam_diag_mvpa_viewer()
% POP_ADAM_DIAG_MVPA_VIEWER - Compute & plot diagonal decoding (group MVPA) for one or many contrasts.
%
% Behavior:
%   - Select a folder in "Target folder":
%       * If it contains "_VS_" in its name -> treat as a single-contrast folder.
%       * Else -> scan immediate subfolders for "*_VS_*" and process them all.
%   - For each contrast:
%       cfg.reduce_dims   = 'diag';
%       mvpa_stats{k}     = adam_compute_group_MVPA(cfg_base, contrast_dir);
%   - Plot:
%       adam_plot_MVPA(cfg_plot, mvpa_stats{:});
%
% Author: <Your Name>, 2025 | License: GPLv3

% ---------- Defaults ----------
def.target_folder     = getpref('eeglab_adam','resultsRoot',''); % remember last used
def.mpcompcor_method  = 'cluster_based';
def.reduce_dims       = 'diag';   % forced
def.singleplot        = true;
def.acclim_txt        = '[0.4 0.8]'; % example; leave empty to use ADAM defaults
def.plot_order_txt    = '';       % e.g., 'FAMOUS_VS_SCRAMBLED, NONFAMOUS_VS_SCRAMBLED'
def.scan_recursive    = false;    % set true to scan recursively under parent folders

% ---------- Geometry ----------
geometry = { ...
    [1] ...                 % Title
    [1 2 0.8] ...           % Target folder + edit + Browse
    [1 2] ...               % MCC method
    [1 2] ...               % Singleplot checkbox
    [1 2] ...               % acclim
    [1 2] ...               % plot_order
    };

uilist = {};
addc({ 'style' 'text' 'string' 'ADAM: Diagonal decoding (single or multi-contrast)' });

% Target folder
addc({ 'style' 'text'  'string' 'Target folder (contrast or parent):' });
addc({ 'style' 'edit'  'tag' 'tgt' 'string' def.target_folder });
addc({ 'style' 'pushbutton' 'string' 'Browse...' , 'callback', @onBrowseTarget });

% MCC method
mpopts = {'none','cluster_based','bonferroni','fdr'};
addc({ 'style' 'text' 'string' 'Multiple-comparison correction:' });
addc({ 'style' 'popupmenu' 'tag' 'mp' 'string' strjoin(mpopts,'|') ...
       'value' pickIndex(mpopts, def.mpcompcor_method, 2) });

% Singleplot
addc({ 'style' 'text' 'string' 'Single figure (singleplot):' });
addc({ 'style' 'checkbox' 'tag' 'single' 'value' double(def.singleplot) });

% acclim
addc({ 'style' 'text' 'string' 'acclim (e.g., [0.4 0.8], leave empty = default):' });
addc({ 'style' 'edit' 'tag' 'acclim' 'string' def.acclim_txt });

% plot_order
addc({ 'style' 'text' 'string' 'plot\_order (comma/space separated contrast names, optional):' });
addc({ 'style' 'edit' 'tag' 'plotord' 'string' def.plot_order_txt });

% ---------- Open dialog ----------
res = inputgui('geometry', geometry, 'uilist', uilist, ...
    'title', 'ADAM Diagonal decoding Viewer (single or multi-contrast)');
if isempty(res), return; end

% ---------- Map outputs (order of edit/popup/checkbox we added) ----------
idx = 0;
target_folder = nextstr(res);
mp_i          = nextnum(res);
single_val    = nextnum(res);
acclim_txt    = nextstr(res);
plotord_txt   = nextstr(res);

% ---------- Validate target ----------
target_folder = strtrim(target_folder);
if isempty(target_folder) || ~exist(target_folder,'dir')
    errordlg('Please choose a valid target folder.','ADAM'); return;
end
setpref('eeglab_adam','resultsRoot', target_folder);

% Build the list of contrasts to process
if is_contrast_folder(target_folder)
    contrast_paths = {target_folder};
else
    contrast_paths = find_contrast_subfolders(target_folder, def.scan_recursive);
    if isempty(contrast_paths)
        errordlg('No contrast subfolders (*_VS_*) found in the selected folder.','ADAM'); return;
    end
end

% ---------- Build base cfg ----------
cfg_base = [];
cfg_base.startdir         = startdir_for(target_folder); % parent of contrast if needed
cfg_base.mpcompcor_method = pick(mpopts, mp_i, def.mpcompcor_method);
cfg_base.reduce_dims      = def.reduce_dims; % 'diag'

% ---------- Compute MVPA for each contrast ----------
mvpa_stats = cell(1, numel(contrast_paths));
contrast_names = cell(1, numel(contrast_paths));
for k = 1:numel(contrast_paths)
    cdir = contrast_paths{k};
    cname = contrast_name(cdir);
    contrast_names{k} = cname;
    try
        eegh('[ADAM] Diagonal decoding: contrast=%s | mp=%s | reduce=%s', ...
            cdir, cfg_base.mpcompcor_method, cfg_base.reduce_dims);
    catch
    end
    mvpa_stats{k} = adam_compute_group_MVPA(cfg_base, cdir);
end

% ---------- Plot all in one shot ----------
cfgp = [];
cfgp.singleplot = logical(single_val);
% acclim (optional)
acclim_txt = strtrim(acclim_txt);
if ~isempty(acclim_txt)
    v = try_eval_vec(acclim_txt);
    if isnumeric(v) && numel(v)==2 && all(isfinite(v))
        cfgp.acclim = v(:)';
    else
        warndlg('Ignoring invalid acclim; expected e.g. [0.4 0.8].','ADAM');
    end
end
% plot_order (optional)
ord = parse_plotorder(plotord_txt);
if ~isempty(ord)
    cfgp.plot_order = ord;
end

% Call plot with all stats (comma-expanded cell)
adam_plot_MVPA(cfgp, mvpa_stats{:});

% Try to name the figure if single contrast
if numel(contrast_paths)==1
    try, set(gcf, 'Name', sprintf('ADAM Diagonal Decoding - %s', contrast_names{1}), 'NumberTitle', 'off'); end
end

% ==================== Callbacks (nested) ====================
    function onBrowseTarget(src,~)
        fig = ancestor(src,'figure');
        editH = findobj(fig,'tag','tgt');
        p = uigetdir('','Select contrast folder or parent folder');
        if isequal(p,0), return; end
        set(editH,'string',p);
    end

% ==================== Utilities ====================
    function addc(c), uilist{end+1} = c; end %#ok<AGROW>

    function k = pickIndex(opts,val,defIdx)
        k = find(strcmpi(opts,val),1); if isempty(k), k = defIdx; end
    end

    function v = pick(opts,i,defv)
        if isempty(i) || i<1 || i>numel(opts), v = defv; else, v = opts{i}; end
    end

    function tf = is_contrast_folder(p)
        if isempty(p) || ~exist(p,'dir'), tf = false; return; end
        [~,name] = fileparts(p);
        tf = contains(name,'_VS_','IgnoreCase',true);
    end

    function startd = startdir_for(selectedFolder)
        if is_contrast_folder(selectedFolder)
            startd = fileparts(selectedFolder);
            if isempty(startd), startd = selectedFolder; end
        else
            startd = selectedFolder;
        end
    end

    function list = find_contrast_subfolders(root, recursiveFlag)
        list = {};
        if isempty(root) || ~exist(root,'dir'), return; end
        if ~recursiveFlag
            d = dir(root); d = d([d.isdir]);
            names = {d.name};
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

    function n = contrast_name(p)
        [~,n] = fileparts(p);
    end

    function v = nextstr(cellres)
        idx = idx + 1; v = cellres{idx};
        if isstring(v), v = char(v); end
        if ~ischar(v), v = ''; end
    end

    function n = nextnum(cellres)
        idx = idx + 1; n = cellres{idx};
        if isempty(n) || ~isscalar(n), n = NaN; end
    end

    function v = try_eval_vec(txt)
        try, v = evalin('base', txt); %#ok<EVLDIR>
        catch, try, v = eval(txt); catch, v = []; end
        end
    end

    function ord = parse_plotorder(s)
        ord = {};
        if isstring(s), s = char(s); end
        s = strtrim(s);
        if isempty(s), return; end
        s = strrep(strrep(s,',',' '),';',' ');
        parts = regexp(s, '\s+', 'split');
        parts = parts(~cellfun(@isempty,parts));
        % Keep raw tokens (contrast folder names) as provided
        ord = parts;
    end
end
