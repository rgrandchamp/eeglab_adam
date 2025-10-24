function adam_run_firstlevel_from_eeglab(cfg)
% ADAM_RUN_FIRSTLEVEL_FROM_EEGLAB - Build ADAM cfg from EEGLAB STUDY/EEG and run first-level MVPA.
%
% This function inspects the current EEGLAB session. If a STUDY is loaded,
% it uses STUDY.datasetinfo to assemble file names and data path; otherwise,
% it falls back to the currently loaded EEG dataset.
%
% Author: <Your Name>, 2025
% License: GPLv3

% ----------------------------
% Bring EEGLAB vars from base
% ----------------------------
hasSTUDY = false;
try
    hasSTUDY = evalin('base','exist(''STUDY'',''var'') == 1');
catch, hasSTUDY = false; end

if hasSTUDY
    STUDY = evalin('base','STUDY'); %#ok<NASGU>
end

try
    ALLEEG = evalin('base','ALLEEG'); %#ok<NASGU>
catch, ALLEEG = []; end

try
    EEG = evalin('base','EEG');
catch, EEG = []; end

% ----------------------------
% Dependencies (attempt setup once)
% ----------------------------
s = adam_check_dependencies();
if ~isempty(s.msgs), eegh('[ADAM] %s', strjoin(s.msgs,' | ')); end
if ~s.ok
    warndlg(strjoin(s.msgs,newline), 'ADAM dependencies');
end

% ----------------------------
% Resolve input files & paths (supports per-subject subfolders)
% ----------------------------
fileList = {};
dataDir  = '';

if hasSTUDY
    S = evalin('base','STUDY');
    % Collect absolute paths to .set files
    absFiles = {};
    for k = 1:numel(S.datasetinfo)
        di = S.datasetinfo(k);
        if isfield(di,'filename') && isfield(di,'filepath') ...
                && ~isempty(di.filename) && ~isempty(di.filepath)
            absFiles{end+1} = fullfile(di.filepath, di.filename); %#ok<AGROW>
        end
    end
    if ~isempty(absFiles)
        % Compute common root and relative file names (without .set)
        dataDir = commonroot(absFiles);
        fileList = cellfun(@(p) stripset(relpath(p, dataDir)), absFiles, 'UniformOutput', false);
    end
end

% Fallback: single EEG dataset
if isempty(fileList)
    if ~isempty(EEG) && isfield(EEG,'filename') && ~isempty(EEG.filename)
        absFile = fullfile(EEG.filepath, EEG.filename);
        dataDir = fileparts(absFile);
        fileList = { stripset(EEG.filename) };
    else
        error('ADAM:NoData','No STUDY or dataset loaded in EEGLAB.');
    end
end

% Ensure datadir exists
if isempty(dataDir) || ~isfolder(dataDir)
    error('ADAM:BadDataPath','Could not resolve a valid data directory from STUDY/EEG.');
end

% Helper: remove .set extension
function s = stripset(fn)
    s = regexprep(fn, '\.set$', '', 'ignorecase');
end

% Helper: compute relative path (p must start with root)
function r = relpath(p, root)
    % Normalize separators
    p = char(p); root = char(root);
    if ispc
        p = strrep(p,'/','\'); root = strrep(root,'/','\');
    else
        p = strrep(p,'\','/'); root = strrep(root,'\','/');
    end
    % Ensure root ends with file separator
    if ~endsWith(root, filesep), root = [root filesep]; end
    if strncmpi(p, root, length(root))
        r = p(length(root)+1:end);
    else
        % Fallback: return basename if no relation found
        r = p;
    end
end

% Helper: longest common ancestor directory for a list of absolute paths
function root = commonroot(paths)
    % Split each path into parts
    parts = cellfun(@(p) splitpath(p), paths, 'UniformOutput', false);
    % Find minimal length
    L = min(cellfun(@numel, parts));
    common = {};
    for i = 1:L
        tokens = cellfun(@(pp) pp{i}, parts, 'UniformOutput', false);
        if numel(unique(tokens)) == 1
            common{end+1} = tokens{1}; %#ok<AGROW>
        else
            break;
        end
    end
    if isempty(common)
        % If nothing common, use the folder of the first file
        root = fileparts(paths{1});
    else
        root = fullfile(common{:});
        % If the common path ends at the file name level, back up one dir
        if ~isfolder(root)
            root = fileparts(root);
        end
    end
end

function parts = splitpath(p)
    % Normalize
    p = char(p);
    if ispc, p = strrep(p,'/','\'); sep = '\'; else, p = strrep(p,'\','/'); sep = '/'; end
    % If p points to a file, take its folder
    if exist(p,'file') == 2, p = fileparts(p); end
    parts = regexp(p, ['(?<=^|',sep,')[^',sep,']+'], 'match');
end

% ----------------------------
% Fill cfg with safe defaults
% ----------------------------
if ~isfield(cfg,'filenames'),      cfg.filenames    = fileList;              end
if ~isfield(cfg,'datadir'),        cfg.datadir      = dataDir;               end
if ~isfield(cfg,'model'),          cfg.model        = 'BDM';                 end
if ~isfield(cfg,'raw_or_tfr'),     cfg.raw_or_tfr   = 'raw';                 end
if ~isfield(cfg,'nfolds') || isempty(cfg.nfolds) || ~isfinite(cfg.nfolds)
                                   cfg.nfolds       = 5;                     end
if ~isfield(cfg,'class_method'),   cfg.class_method = 'AUC';                 end
if ~isfield(cfg,'crossclass'),     cfg.crossclass   = 'yes';                 end
if ~isfield(cfg,'channelpool'),    cfg.channelpool  = 'ALL_NOSELECTION';     end
if ~isfield(cfg,'resample') || isempty(cfg.resample) || ~isfinite(cfg.resample)
                                   cfg.resample     = 55;                    end
if ~isfield(cfg,'erp_baseline') || isempty(cfg.erp_baseline)
                                   cfg.erp_baseline = [-0.1 0];              end

% Class specs are required (two classes minimum)
if ~isfield(cfg,'class_spec') || numel(cfg.class_spec) < 2 ...
   || any(cellfun(@(s) isempty(strtrim(char(string(s)))), cfg.class_spec))
    % Sécurité silencieuse : ne rien faire si mal paramétré (la GUI doit valider avant)
    return;
end

% Output dir default (inside dataDir)
if ~isfield(cfg,'outputdir') || isempty(cfg.outputdir)
    cfg.outputdir = fullfile(cfg.datadir, 'RESULTS', 'EEG_RAW', 'EEGLAB_PLUGIN_RUN');
end
if ~exist(cfg.outputdir,'dir'), mkdir(cfg.outputdir); end

% ----------------------------
% Normalize filenames to ensure ADAM finds .set files
% ----------------------------
% 1) Ensure cfg.filenames are char rows (not string) and trimmed
for i = 1:numel(cfg.filenames)
    cfg.filenames{i} = char(string(cfg.filenames{i}));
    cfg.filenames{i} = strrep(cfg.filenames{i}, filesep, filesep); %#ok<NASGU> % noop normalize
end

% 2) Quick existence check with current datadir (relative mode)
missing = false(1, numel(cfg.filenames));
for i = 1:numel(cfg.filenames)
    % If filename already has .set, strip it (ADAM appends extension internally)
    basei = regexprep(cfg.filenames{i}, '\.set$', '', 'ignorecase');
    testrel = fullfile(cfg.datadir, [basei '.set']);
    if ~exist(testrel, 'file')
        missing(i) = true;
    else
        % Store back the base (no extension, possibly relative)
        cfg.filenames{i} = basei;
    end
end

% 3) If any missing with relative paths, try absolute fallback from STUDY
if any(missing)
    % Rebuild absolute path list from STUDY (or EEG)
    absList = cell(1, numel(cfg.filenames));
    hasST = evalin('base','exist(''STUDY'',''var'')==1');
    if hasST
        S = evalin('base','STUDY');
        for k = 1:numel(S.datasetinfo)
            di = S.datasetinfo(k);
            if isfield(di,'filename') && isfield(di,'filepath') && ~isempty(di.filename) && ~isempty(di.filepath)
                absList{k} = fullfile(di.filepath, di.filename); % absolute path to .set
            end
        end
    else
        try
            EEG = evalin('base','EEG');
            absList{1} = fullfile(EEG.filepath, EEG.filename);
        catch
        end
    end

    % Switch to absolute addressing mode if absolutes exist
    canUseAbs = true;
    for i = 1:numel(absList)
        if isempty(absList{i}) || ~exist(absList{i}, 'file')
            canUseAbs = false;
            break;
        end
    end

    if canUseAbs
        for i = 1:numel(absList)
            % store absolute base name (no extension)
            cfg.filenames{i} = regexprep(absList{i}, '\.set$', '', 'ignorecase');
        end
        cfg.datadir = ''; % IMPORTANT: let ADAM use absolute filenames directly
    else
        % Build an informative error to stop early
        missList = {};
        for i = 1:numel(cfg.filenames)
            if missing(i)
                missList{end+1} = fullfile(cfg.datadir, [cfg.filenames{i} '.set']); %#ok<AGROW>
            end
        end
        errordlg(sprintf(['Some .set files were not found at the expected location.\n\n' ...
                          'datadir: %s\nMissing:\n- %s\n\n' ...
                          'Tip: rebuild STUDY or check datasetinfo.filepath.'], ...
                          cfg.datadir, strjoin(missList, '\n- ')), 'ADAM');
        return;
    end
end

% (Optionnel) Log what will be used
eegh(sprintf('[ADAM] datadir = %s', cfg.datadir));
for i = 1:numel(cfg.filenames)
    eegh(sprintf('[ADAM] file %d = %s', i, cfg.filenames{i}));
end


% ----------------------------
% Run ADAM first-level
% ----------------------------
eegh(sprintf('[ADAM] Running first-level: model=%s, data=%s, nfolds=%d, method=%s, crossclass=%s, resample=%g, baseline=[%g %g], out=%s', ...
    cfg.model, cfg.raw_or_tfr, cfg.nfolds, cfg.class_method, cfg.crossclass, cfg.resample, cfg.erp_baseline(1), cfg.erp_baseline(2), cfg.outputdir));
drawnow;

% === Log resolved data paths for debugging ===
eegh(sprintf('[ADAM] datadir=%s', cfg.datadir));
for i=1:numel(cfg.filenames)
    eegh(sprintf('[ADAM] file %d = %s', i, cfg.filenames{i}));
end
% ============================================

% Now launch ADAM
adam_MVPA_firstlevel(cfg);

eegh(sprintf('[ADAM] First-level done. Results: %s', cfg.outputdir));

try
    msgbox(sprintf('ADAM first-level finished.\nResults:\n%s', cfg.outputdir), 'ADAM');
catch
end
end
