function pop_adam_single_subject_mvpa_viewer()
% POP_ADAM_SINGLE_SUBJECT_MVPA_VIEWER
% Compute and plot single-subject diagonal decoding for one contrast folder
% (CLASS1_VS_CLASS2) or for every contrast subfolder under a chosen parent.
%
% For each contrast:
%   cfg = [];
%   cfg.startdir     = <parent of contrast or selected parent>;
%   cfg.reduce_dims  = 'diag';
%   cfg.splinefreq   = <GUI value>;
%   cfg.plotsubjects = true;
%   adam_compute_group_MVPA(cfg, contrast_dir);
%
% Author: <Your Name>, 2025 | License: GPLv3

% ---------- Defaults ----------
def.target_folder  = getpref('eeglab_adam','resultsRoot','');
def.splinefreq     = '11';     % text edit (parsed to double)
def.plotsubjects   = true;     % always true for this viewer
def.scan_recursive = false;    % set true to recurse when a parent is selected

% ---------- Geometry ----------
geometry = { ...
    [1] ...                 % Title
    [1 2 0.8] ...           % Target folder + edit + Browse
    [1 2] ...               % Splinefreq (Hz)
    };

uilist = {};
addc({ 'style' 'text'  'string' 'ADAM: Single-subject decoding (select a contrast or a parent folder)' });

% Target folder
addc({ 'style' 'text'  'string' 'Target folder (contrast or parent):' });
addc({ 'style' 'edit'  'tag' 'tgt' 'string' def.target_folder });
addc({ 'style' 'pushbutton' 'string' 'Browse...' , 'callback', @onBrowseTarget });

% Splinefreq
addc({ 'style' 'text'  'string' 'Splinefreq (Hz, low-pass-like smoothing):' });
addc({ 'style' 'edit'  'tag' 'spline' 'string' def.splinefreq });


% ---------- Open dialog ----------
res = inputgui('geometry', geometry, 'uilist', uilist, ...
    'title', 'ADAM Single-subject Decoding Viewer (diag)');
if isempty(res), return; end

% ---------- Map outputs (order of edit controls) ----------
idx = 0;
target_folder = nextstr(res);
spline_txt    = nextstr(res);

% ---------- Validate target ----------
target_folder = strtrim(target_folder);
if isempty(target_folder) || ~exist(target_folder,'dir')
    errordlg('Please choose a valid target folder.','ADAM'); return;
end
setpref('eeglab_adam','resultsRoot', target_folder);

% Parse splinefreq
splinefreq = str2double(strtrim(spline_txt));
if ~isfinite(splinefreq) || splinefreq <= 0
    warndlg('Invalid splinefreq; falling back to 11 Hz.','ADAM');
    splinefreq = 11;
end

% Build contrast list based on folder type
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
cfg_base.startdir     = startdir_for(target_folder); % parent of contrast if needed
cfg_base.reduce_dims  = 'diag';
cfg_base.splinefreq   = splinefreq;
cfg_base.plotsubjects = true; % as requested

% ---------- Run for each contrast ----------
for k = 1:numel(contrast_paths)
    cdir  = contrast_paths{k};
    cname = contrast_name(cdir);
    try
        eegh('[ADAM] Single-subject decoding: contrast=%s | reduce=%s | splinefreq=%g', ...
            cdir, cfg_base.reduce_dims, cfg_base.splinefreq);
    catch
    end
    % ADAM will produce the plots (including per-subject), using the passed contrast folder:
    adam_compute_group_MVPA(cfg_base, cdir);
    % Try to label the figure (in case ADAM leaves a current figure)
    try, set(gcf, 'Name', sprintf('ADAM Single-subject Decoding - %s', cname), 'NumberTitle', 'off'); end
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
end
