function pop_adam_group_erp_viewer()
% POP_ADAM_GROUP_ERP_VIEWER - Plot group ERPs (and their difference) from ADAM first-level results.
%
% Behavior:
%   - Select a folder in "Target folder":
%       * If the folder name contains "_VS_" -> treat as a single contrast folder.
%       * Otherwise -> scan immediate subfolders whose names contain "_VS_" and process them all.
%   - For each contrast:
%       erp_stats     = adam_compute_group_ERP(cfg_base, contrast_dir);
%       erp_stats_dif = adam_compute_group_ERP(cfg_sub,  contrast_dir);
%       adam_plot_MVPA(cfg_plot, erp_stats, erp_stats_dif);
%
% Electrode picker:
%   - Tries STUDY + ALLEEG: verifies all datasets have the same nbchan, then uses
%     labels from the FIRST dataset of the STUDY.
%   - If STUDY is missing or inconsistent, falls back to EEG.chanlocs (if available).
%
% Author: <Your Name>, 2025 | License: GPLv3

% ---------- Defaults ----------
def.target_folder      = getpref('eeglab_adam','resultsRoot','');
def.mpcompcor_method   = 'cluster_based';
def.electrode_method   = 'average';
def.electrodes_txt     = 'P10';
def.line_colors_txt    = '[.75 .75 .75] | [.5 .5 .5] | [0 0 .5]';
def.scan_recursive     = false;  % set true to scan recursively under parent folders

% ---------- Geometry ----------
geometry = { ...
    [1] ...                 % Title
    [1 2 0.8] ...           % Target folder + edit + Browse
    [1 2] ...               % MP corr method
    [1 2] ...               % Electrode method
    [1 2 0.8] ...           % Electrodes + Pick
    [1 2] ...               % Line colors
    };

uilist = {};
addc({ 'style' 'text'  'string' 'ADAM: Group ERP (single or multi-contrast from a chosen folder)' });

% Target folder
addc({ 'style' 'text'  'string' 'Target folder (contrast or parent):' });
addc({ 'style' 'edit'  'tag' 'tgt' 'string' def.target_folder });
addc({ 'style' 'pushbutton' 'string' 'Browse...' , 'callback', @onBrowseTarget });

% Multiple-comparison correction
mpopts = {'none','cluster_based','bonferroni','fdr'};
addc({ 'style' 'text' 'string' 'Multiple-comparison correction:' });
addc({ 'style' 'popupmenu' 'tag' 'mp' 'string' strjoin(mpopts,'|') ...
    'value' pickIndex(mpopts, def.mpcompcor_method, 2) });

% Electrode method
emopts = {'average','max','median'};
addc({ 'style' 'text' 'string' 'Electrode method:' });
addc({ 'style' 'popupmenu' 'tag' 'em' 'string' strjoin(emopts,'|') ...
    'value' pickIndex(emopts, def.electrode_method, 1) });

% Electrodes
addc({ 'style' 'text' 'string' 'Electrodes (comma/space-separated):' });
addc({ 'style' 'edit' 'tag' 'elec' 'string' def.electrodes_txt });
addc({ 'style' 'pushbutton' 'string' 'Pick…' , 'callback', @onPickElectrodes });

% Line colors
addc({ 'style' 'text' 'string' 'Line colors ([r g b] triplets, 3 entries):' });
addc({ 'style' 'edit' 'tag' 'colors' 'string' def.line_colors_txt });

% ---------- Open dialog ----------
res = inputgui('geometry', geometry, 'uilist', uilist, 'title', 'ADAM Group ERP Viewer (single or multi-contrast)');
if isempty(res), return; end

% ---------- Map outputs ----------
idx = 0;
target_folder = nextstr(res);
mp_i          = nextnum(res);
em_i          = nextnum(res);
elecs_txt     = nextstr(res);
colors_txt    = nextstr(res);

% ---------- Validate target ----------
target_folder = strtrim(target_folder);
if isempty(target_folder) || ~exist(target_folder,'dir')
    errordlg('Please choose a valid target folder.','ADAM'); return;
end
setpref('eeglab_adam','resultsRoot', target_folder);

% Decide single vs multi
if is_contrast_folder(target_folder)
    contrast_paths = {target_folder};
else
    contrast_paths = find_contrast_subfolders(target_folder, def.scan_recursive);
    if isempty(contrast_paths)
        errordlg('No contrast subfolders (*_VS_*) found in the selected folder.','ADAM'); return;
    end
end

% ---------- Build base cfgs ----------
cfg_base = [];
cfg_base.startdir         = startdir_for(target_folder);
cfg_base.mpcompcor_method = pick(mpopts, mp_i, def.mpcompcor_method);
cfg_base.electrode_method = pick(emopts,  em_i, def.electrode_method);
cfg_base.electrode_def    = parse_electrodes(elecs_txt);

cfg_sub          = cfg_base;
cfg_sub.condition_method = 'subtract';

% ---------- Parse line colors (optional) ----------
cfgp = []; cfgp.singleplot = true;
try
    cfgp.line_colors = eval_linecolors(colors_txt);
catch
    % keep ADAM defaults
end

% ---------- Run for one or many contrasts ----------
for k = 1:numel(contrast_paths)
    cdir = contrast_paths{k};
    cname = contrast_name(cdir);
    try
        eegh('[ADAM] Group ERP viewer: contrast=%s | mp=%s | emeth=%s | elecs=%s', ...
            cdir, cfg_base.mpcompcor_method, cfg_base.electrode_method, strjoin(cfg_base.electrode_def,', '));
    catch
    end

    erp_stats     = adam_compute_group_ERP(cfg_base, cdir); %#ok<NASGU>
    erp_stats_dif = adam_compute_group_ERP(cfg_sub,  cdir); %#ok<NASGU>

    adam_plot_MVPA(cfgp, erp_stats, erp_stats_dif);
    try, set(gcf, 'Name', sprintf('ADAM Group ERP - %s', cname), 'NumberTitle', 'off'); end
end

% ==================== Callbacks (nested) ====================
    function onBrowseTarget(src,~)
        fig   = ancestor(src,'figure');
        editH = findobj(fig,'tag','tgt');
        p = uigetdir_smart(fig, 'tgt', 'Select contrast folder or parent folder');
        if isequal(p,0), return; end
        set(editH,'string',p);
    end

    function onPickElectrodes(src,~)
        % Try STUDY first with channel-count consistency check; fallback to EEG.
        [labels, msg] = study_labels_if_consistent();
        if isempty(labels)
            if ~isempty(msg), warndlg(msg,'ADAM'); end
            labels = eeg_base_labels(); % may still be empty -> warn below
        end
        if isempty(labels)
            warndlg('No electrode labels available (no STUDY/EEG with chanlocs).','ADAM');
            return;
        end

        fig = ancestor(src,'figure');
        [idxL,ok] = listdlg('PromptString','Select electrodes', ...
            'SelectionMode','multiple', ...
            'ListString',labels,'ListSize',[240 320]);
        if ~ok, return; end
        set(findobj(fig,'tag','elec'),'string', strjoin(labels(idxL), ','));
    end

% ==================== Utilities ====================
    function addc(c), uilist{end+1} = c; end %#ok<AGROW>

    function k = pickIndex(opts,val,defIdx)
        k = find(strcmpi(opts,val),1); if isempty(k), k = defIdx; end
    end

    function v = pick(opts,i,defv)
        if isempty(i) || i<1 || i>numel(opts), v = defv; else, v = opts{i}; end
    end

    function C = parse_electrodes(s)
        if isstring(s), s = char(s); end
        s = strrep(strrep(s,',',' '),';',' ');
        parts = regexp(strtrim(s),'\s+','split');
        C = parts(~cellfun(@isempty,parts));
        if isempty(C), C = {'P10'}; end
    end

    function L = eval_linecolors(s)
        toks = regexp(s,'\[(.*?)\]','tokens');
        if isempty(toks), error('bad colors'); end
        L = cellfun(@(t) sscanf(t{1},'%f')', toks, 'UniformOutput', false);
        ok = cellfun(@(x) isnumeric(x) && numel(x)==3, L);
        if ~all(ok), error('bad colors'); end
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

% -------- Electrode sources with STUDY consistency check --------
    function [labels, msg] = study_labels_if_consistent()
        labels = {}; msg = '';
        try
            hasST = evalin('base','exist(''STUDY'',''var'') == 1');
        catch, hasST = false; end
        if ~hasST, msg = 'No STUDY in base workspace.'; return; end

        try
            STUDY = evalin('base','STUDY');
            ALLEEG = evalin('base','ALLEEG');
        catch
            msg = 'Cannot access STUDY/ALLEEG in base workspace.'; return;
        end
        if ~isfield(STUDY,'datasetinfo') || isempty(STUDY.datasetinfo)
            msg = 'STUDY.datasetinfo is empty.'; return;
        end

        % Gather nbchan for each dataset present in ALLEEG
        nbchans = [];
        idxs = [];
        for k = 1:numel(STUDY.datasetinfo)
            if isfield(STUDY.datasetinfo(k),'index') && ~isempty(STUDY.datasetinfo(k).index)
                ai = STUDY.datasetinfo(k).index;
            else
                ai = []; % unknown index
            end
            if isempty(ai) || ai<1 || ai>numel(ALLEEG) || isempty(ALLEEG(ai).data)
                continue; % skip unloaded
            end
            nbchans(end+1) = ALLEEG(ai).nbchan; %#ok<AGROW>
            idxs(end+1)    = ai; %#ok<AGROW>
        end


        if length(unique(nbchans)) > 1
            msg = sprintf('Inconsistent channel counts across STUDY datasets');
            labels = {};
            return;
        end

        % Same nbchan -> take labels from the first loaded dataset
        ai1 = idxs(1);
        if isfield(ALLEEG(ai1),'chanlocs') && ~isempty(ALLEEG(ai1).chanlocs)
            labels = {ALLEEG(ai1).chanlocs.labels};
            labels = labels(~cellfun(@isempty,labels));
        end
        if isempty(labels)
            msg = 'First dataset has no chanlocs labels.'; % will trigger fallback
        end
    end

    function labels = eeg_base_labels()
        labels = {};
        try
            EEG = evalin('base','EEG');
            if isstruct(EEG) && isfield(EEG,'chanlocs') && ~isempty(EEG.chanlocs)
                labels = {EEG.chanlocs.labels};
                labels = labels(~cellfun(@isempty,labels));
            end
        catch
        end
    end
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