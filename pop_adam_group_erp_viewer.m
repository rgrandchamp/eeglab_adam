function pop_adam_group_erp_viewer()
% POP_ADAM_GROUP_ERP_VIEWER - One-click viewer to plot group ERPs and their difference from ADAM first-level results.
%
% Author: <Your Name>, 2025 | License: GPLv3

% ---------- Defaults ----------
def.startdir          = getpref('eeglab_adam','resultsRoot','');
def.mpcompcor_method  = 'cluster_based';
def.electrode_method  = 'average';
def.electrodes        = 'P10';
def.line_colors_txt   = '[.75 .75 .75] | [.5 .5 .5] | [0 0 .5]'; % three series

% Try to get labels for picker
chanLabels = {};
try
    EEG = evalin('base','EEG');
    if isstruct(EEG) && isfield(EEG,'chanlocs') && ~isempty(EEG.chanlocs)
        chanLabels = {EEG.chanlocs.labels};
        chanLabels = chanLabels(~cellfun(@isempty,chanLabels));
    end
catch
end

% ---------- Geometry ----------
geometry = { ...
    [1] ...                 % Title
    [1 2 0.8] ...           % startdir + edit + Browse
    [1 2 0.8] ...           % Contrast + popup + Refresh
    [1 2] ...               % MP corr method
    [1 2] ...               % Electrode method
    [1 2 0.8] ...           % Electrodes edit + Pick
    [1 2] ...               % Line colors
    % [1 1] ...               % Buttons (Plot, Close)
    };

uilist = {};
addc({ 'style' 'text' 'string' 'ADAM: Group ERP (select contrast & auto-plot)' });

% startdir row
addc({ 'style' 'text'  'string' 'RESULTS root (cfg.startdir):' });
addc({ 'style' 'edit'  'tag' 'startdir' 'string' def.startdir });
addc({ 'style' 'pushbutton' 'string' 'Browse...' , 'callback', @onBrowseStartdir });

% contrast row
addc({ 'style' 'text' 'string' 'Contrast folder (CLASS1_VS_CLASS2):' });
addc({ 'style' 'popupmenu' 'tag' 'contrast_popup' 'string' '<refresh to scan...>' 'value' 1 });
addc({ 'style' 'pushbutton' 'string' 'Refresh' , 'callback', @refreshContrasts });

% mcc method
mpopts = {'none','cluster_based','bonferroni','fdr'};
addc({ 'style' 'text' 'string' 'Multiple-comparison correction:' });
addc({ 'style' 'popupmenu' 'tag' 'mp' 'string' strjoin(mpopts,'|') ...
       'value' pickIndex(mpopts, def.mpcompcor_method, 2) });

% electrode method
emopts = {'average','max','median'};
addc({ 'style' 'text' 'string' 'Electrode method:' });
addc({ 'style' 'popupmenu' 'tag' 'em' 'string' strjoin(emopts,'|') ...
       'value' pickIndex(emopts, def.electrode_method, 1) });

% electrodes
addc({ 'style' 'text' 'string' 'Electrodes (comma/space-separated):' });
addc({ 'style' 'edit' 'tag' 'elec' 'string' def.electrodes });
addc({ 'style' 'pushbutton' 'string' 'Pick…' , 'callback', @(src,~)onPickElectrodes(src,chanLabels) });

% line colors
addc({ 'style' 'text' 'string' 'Line colors ([r g b] triplets, 3 entries):' });
addc({ 'style' 'edit' 'tag' 'colors' 'string' def.line_colors_txt });

% buttons
% addc({ 'style' 'pushbutton' 'string' 'Plot ERPs' , 'callback', 'uiresume(gcbf);' });
% addc({ 'style' 'pushbutton' 'string' 'Close'     , 'callback', 'close(gcbf);' });

% ---------- Open dialog ----------
res = inputgui('geometry', geometry, 'uilist', uilist, 'title', 'ADAM Group ERP Viewer');
if isempty(res), return; end

% ---------- Map outputs in order (edits/popup only, in the same order we added them) ----------
idx = 0;
startdir_s   = nextstr(res);   % startdir
contrast_i   = nextnum(res);   % contrast popup value
mp_i         = nextnum(res);   % mp popup value
em_i         = nextnum(res);   % em popup value
elecs_s      = nextstr(res);   % electrodes
colors_s     = nextstr(res);   % colors

% Validate startdir
startdir_s = strtrim(startdir_s);
if isempty(startdir_s) || ~exist(startdir_s,'dir')
    errordlg('Please set a valid RESULTS root.','ADAM'); return;
end
setpref('eeglab_adam','resultsRoot', startdir_s);

% Re-scan contrasts now and pick the one at contrast_i
[names, paths] = scan_contrasts(startdir_s);
if isempty(paths)
    errordlg('No contrast folders (*_VS_*) found under RESULTS root.','ADAM'); return;
end
if ~isscalar(contrast_i) || contrast_i < 1 || contrast_i > numel(paths)
    errordlg('Invalid contrast selection. Please try again.','ADAM'); return;
end
contrast_dir = paths{contrast_i};

% ---------- Build cfgs ----------
cfg_base = [];
cfg_base.startdir         = startdir_s;
cfg_base.mpcompcor_method = pick(mpopts, mp_i, def.mpcompcor_method);
cfg_base.electrode_method = pick(emopts,  em_i, def.electrode_method);
cfg_base.electrode_def    = parse_electrodes(elecs_s);

cfg_sub          = cfg_base;
cfg_sub.condition_method = 'subtract';

% Log
try
    eegh('[ADAM] Group ERP viewer: contrast=%s | mp=%s | emeth=%s | elecs=%s', ...
        contrast_dir, cfg_base.mpcompcor_method, cfg_base.electrode_method, strjoin(cfg_base.electrode_def,', '));
catch
end

% ---------- Run ADAM (no selection dialog; pass contrast folder explicitly) ----------
erp_stats     = adam_compute_group_ERP(cfg_base, contrast_dir); %#ok<NASGU>
erp_stats_dif = adam_compute_group_ERP(cfg_sub,  contrast_dir); %#ok<NASGU>

% ---------- Plot ----------
cfgp = [];
cfgp.singleplot = true;
try
    cfgp.line_colors = eval_linecolors(colors_s);
catch
    % leave default colors if parsing failed
end
adam_plot_MVPA(cfgp, erp_stats, erp_stats_dif);

% ==================== Callbacks (nested) ====================
    function onBrowseStartdir(src,~)
        fig = ancestor(src,'figure');
        editH = findobj(fig,'tag','startdir');
        p = uigetdir('','Select ADAM RESULTS root');
        if isequal(p,0), return; end
        set(editH,'string',p);
        refreshContrasts(src,[]);
    end

    function refreshContrasts(src,~)
        fig = ancestor(src,'figure');
        root = get(findobj(fig,'tag','startdir'),'string');
        [names2,paths2] = scan_contrasts(root);
        popH = findobj(fig,'tag','contrast_popup');
        if isempty(paths2)
            set(popH,'string','<no contrasts found>','value',1,'userdata',[]);
        else
            set(popH,'string',names2,'value',1,'userdata',paths2);
        end
    end

    function onPickElectrodes(src,labels)
        fig = ancestor(src,'figure');
        if isempty(labels)
            warndlg('No EEG.chanlocs in base workspace.','ADAM'); return;
        end
        [idxL,ok] = listdlg('PromptString','Select electrodes', ...
                            'SelectionMode','multiple', ...
                            'ListString',labels,'ListSize',[220 300]);
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
    function [names,paths] = scan_contrasts(root)
        names = {}; paths = {};
        if isempty(root) || ~exist(root,'dir'), return; end
        dd = genpath(root);
        allp = regexp(dd, pathsep, 'split');
        allp = allp(~cellfun(@isempty,allp));
        for i=1:numel(allp)
            p = allp{i};
            [~,base] = fileparts(p);
            if contains(base,'_VS_','IgnoreCase',true)
                names{end+1} = base; %#ok<AGROW>
                paths{end+1} = p;    %#ok<AGROW>
            end
        end
        % unique stable
        [~,ia] = unique(paths,'stable'); names = names(ia); paths = paths(ia);
        if isempty(names)
            names = {'<no contrasts found>'}; paths = {};
        end
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
end
