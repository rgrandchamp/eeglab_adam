function pop_adam_firstlevel()
% POP_ADAM_FIRSTLEVEL - GUI to run ADAM first-level MVPA from EEGLAB.
% Author: <Your Name>, 2025 | License: GPLv3
%
% Adds:
%   - Output folder (cfg.outputdir)
%   - Class 1 name and Class 2 name (cfg.class_labels{1,2})

% ---- Defaults ----
def.model        = 'BDM';
def.raw_or_tfr   = 'raw';
def.nfolds       = 5;
def.class_method = 'AUC';
def.crossclass   = 'yes';
def.channelpool  = 'ALL_NOSELECTION';
def.resample     = 55;
def.erp_baseline = [-0.1 0];
def.outputdir    = '';           % leave empty so runner can choose default
def.classname1   = 'class1';     % default class labels if user leaves blank
def.classname2   = 'class2';

% ---- Geometry (rows) ----
geometry = { ...
    [1] ...            % Title
    [1 2] ...          % Class 1 spec
    [1 2] ...          % Class 1 name
    [1 2] ...          % Class 2 spec
    [1 2] ...          % Class 2 name
    [1 2] ...          % Model
    [1 2] ...          % Data
    [1 2] ...          % Perf metric
    [1 2] ...          % Crossclass
    [1 2] ...          % Channelpool
    [1 1] ...          % nfolds
    [1 1] ...          % resample
    [1 1] ...          % baseline
    [1 2 0.6] ...      % Output folder + edit + Browse
    };

% ---- Build UI ----
uilist = {};
addc({ 'style' 'text' 'string' 'ADAM First-level (MVPA)' });

% Class 1
addc({ 'style' 'text' 'string' 'Class 1 spec (e.g., cond_string([...]))' });
addc({ 'style' 'edit' 'tag' 'class1' 'string' '' });

addc({ 'style' 'text' 'string' 'Class 1 name' });
addc({ 'style' 'edit' 'tag' 'class1_name' 'string' def.classname1 });

% Class 2
addc({ 'style' 'text' 'string' 'Class 2 spec (e.g., cond_string([...]))' });
addc({ 'style' 'edit' 'tag' 'class2' 'string' '' });

addc({ 'style' 'text' 'string' 'Class 2 name' });
addc({ 'style' 'edit' 'tag' 'class2_name' 'string' def.classname2 });

% Other controls
addc({ 'style' 'text' 'string' 'Model' });
addc({ 'style' 'popupmenu' 'string' 'BDM' 'value' iff(strcmpi(def.model,'BDM'),1,2) });

addc({ 'style' 'text' 'string' 'Data' });
addc({ 'style' 'popupmenu' 'string' 'raw' 'value' iff(strcmpi(def.raw_or_tfr,'raw'),1,2) });

addc({ 'style' 'text' 'string' 'Performance' });
addc({ 'style' 'popupmenu' 'string' 'AUC|accuracy|dprime' 'value' idxOf({'AUC','accuracy','dprime'}, def.class_method, 1) });

addc({ 'style' 'text' 'string' 'Cross-temporal gen. (crossclass)' });
addc({ 'style' 'popupmenu' 'string' 'yes|no' 'value' iff(strcmpi(def.crossclass,'yes'),1,2) });

addc({ 'style' 'text' 'string' 'Channel pool' });
addc({ 'style' 'edit' 'string' def.channelpool });

addc({ 'style' 'text' 'string' 'k-folds' });
addc({ 'style' 'edit' 'string' num2str(def.nfolds) });

addc({ 'style' 'text' 'string' 'Resample (Hz)' });
addc({ 'style' 'edit' 'string' num2str(def.resample) });

addc({ 'style' 'text' 'string' 'ERP baseline [start end] s' });
addc({ 'style' 'edit' 'string' sprintf('%.3f %.3f', def.erp_baseline(1), def.erp_baseline(2)) });

% Output folder
addc({ 'style' 'text' 'string' 'Output folder (cfg.outputdir):' });
addc({ 'style' 'edit' 'tag' 'outputdir' 'string' def.outputdir });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback' ...
    ['p = uigetdir(''Select output folder''); ' ...
     'if isequal(p,0), return; end; ' ...
     'set(findobj(gcbf,''tag'',''outputdir''),''string'',p);'] });

% ---- Open GUI ----
res = inputgui('geometry', geometry, 'uilist', uilist, 'title', 'ADAM First-level (MVPA)');
if isempty(res), return; end

% ---- Map results in order ----
idx = 0;
class1        = nextstr();
class1_name   = nextstr();
class2        = nextstr();
class2_name   = nextstr();
model_i       = nextnum();
raw_i         = nextnum();
method_i      = nextnum();
cross_i       = nextnum();
channelpool_s = nextstr();
nfolds_s      = nextstr();
resample_s    = nextstr();
baseline_s    = nextstr();
outputdir_s   = nextstr();
% (buttons return nothing)

% ---- Validate ----
if isempty(strtrim(class1)) || isempty(strtrim(class2))
    errordlg('Please fill both Class 1 and Class 2 event codes (comma-separated or cond_string(...)).','ADAM');
    return;
end

% ---- Build cfg ----
cfg = struct();
cfg.class_spec    = { class1, class2 };
cfg.class_labels  = { fallback_str(class1_name, def.classname1), fallback_str(class2_name, def.classname2) };
cfg.model         = pick({'BDM'}, model_i, def.model);
cfg.raw_or_tfr    = pick({'raw'}, raw_i, def.raw_or_tfr);
cfg.class_method  = pick({'AUC','accuracy','dprime'}, method_i, def.class_method);
cfg.crossclass    = pick({'yes','no'}, cross_i, def.crossclass);
cfg.channelpool   = fallback_str(channelpool_s, def.channelpool);
cfg.nfolds        = safe_int(nfolds_s, def.nfolds);
cfg.resample      = safe_int(resample_s, def.resample);
cfg.erp_baseline  = parse_baseline(baseline_s, def.erp_baseline);
outputdir_s = strtrim(outputdir_s);
if ~isempty(outputdir_s), cfg.outputdir = outputdir_s; end

% ---- Run ----
adam_run_firstlevel_from_eeglab(cfg);

% ===== Helpers =====
    function addc(cellrow), uilist{end+1} = cellrow; end %#ok<AGROW>
    function v = nextstr(), idx=idx+1; v = res{idx}; if isstring(v), v=char(v); end; if ~ischar(v), v=''; end; end
    function n = nextnum(), idx=idx+1; n = res{idx}; if isempty(n)||~isscalar(n), n=NaN; end; end
    function x = pick(opts,i,defv), if isnan(i)||i<1||i>numel(opts), x=defv; else, x=opts{i}; end; end
    function n = safe_int(s,defv), n=round(str2double(strtrim(s))); if isnan(n)||~isfinite(n), n=defv; end; end
    function s2 = fallback_str(s2,defv), if isempty(s2), s2=defv; end; end
    function b = parse_baseline(s,defb)
        if ~(ischar(s)||isstring(s)), b=defb; return; end
        s=char(s); s=strrep(s,',',' ');
        t=textscan(s,'%f %f');
        if isempty(t)||numel(t)<2||isempty(t{1})||isempty(t{2}), b=defb; else
            a=t{1}(1); c=t{2}(1); if ~isfinite(a)||~isfinite(c), b=defb; else, b=[a c]; end
        end
    end
    function v = iff(cond,a,b), if cond, v=a; else, v=b; end; end
    function idxv = idxOf(opts,val,defIdx)
        idxv = find(strcmpi(opts,val),1); if isempty(idxv), idxv=defIdx; end
    end
end
