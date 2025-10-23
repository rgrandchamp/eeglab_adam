function adam_run_firstlevel_from_eeglab(cfg)
% ADAM_RUN_FIRSTLEVEL_FROM_EEGLAB - Build ADAM cfg from EEGLAB STUDY/ALLEEG and run first-level analysis.

% Check dependencies
s = adam_check_dependencies();
if ~s.ok
    warndlg(strjoin(s.msgs,newline), 'ADAM dependencies');
end

% Access EEGLAB globals
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab; %#ok<ASGLU>
STUDY = evalin('base','exist(''STUDY'',''var'')') * evalin('base','STUDY;'); %#ok<NASGU>

% Determine input files from STUDY or current dataset
if evalin('base','exist(''STUDY'',''var'')')
    STUDY = evalin('base','STUDY');
    fileList = {};
    for k = 1:numel(STUDY.datasetinfo)
        fileList{end+1} = erase(string(STUDY.datasetinfo(k).filename), '.set'); %#ok<AGROW>
    end
    cfg.filenames = fileList;    
    cfg.datadir   = STUDY.filepath;
else
    if isempty(EEG) || isempty(EEG.filename)
        error('No STUDY or dataset loaded.');
    end
    cfg.filenames = { erase(EEG.filename, '.set') };
    cfg.datadir   = EEG.filepath;
end

% Ensure output dir
if ~isfield(cfg,'outputdir') || isempty(cfg.outputdir)
    cfg.outputdir = fullfile(cfg.datadir,'RESULTS','EEG_RAW','EEG_PLUGIN_RUN');
end
if ~exist(cfg.outputdir,'dir'), mkdir(cfg.outputdir); end

% Basic safety defaults
if ~isfield(cfg,'nfolds') || isnan(cfg.nfolds), cfg.nfolds = 5; end
if ~isfield(cfg,'class_method'), cfg.class_method = 'AUC'; end
if ~isfield(cfg,'crossclass'),   cfg.crossclass   = 'yes'; end
if ~isfield(cfg,'channelpool'),  cfg.channelpool  = 'ALL_NOSELECTION'; end
if ~isfield(cfg,'resample') || isnan(cfg.resample), cfg.resample = 55; end
if ~isfield(cfg,'erp_baseline') || isempty(cfg.erp_baseline), cfg.erp_baseline = [-.1 0]; end
if ~isfield(cfg,'raw_or_tfr'), cfg.raw_or_tfr = 'raw'; end
if ~isfield(cfg,'model'), cfg.model = 'BDM'; end

% Class specs must be present
assert(isfield(cfg,'class_spec') && numel(cfg.class_spec)>=2, 'Please specify class_spec{1} and class_spec{2}.');

% Run first-level analysis
eegh('Running ADAM first-level...'); drawnow;
adam_MVPA_firstlevel(cfg);  % ADAM call (per paper)
eegh('ADAM first-level done. Results in: %s', cfg.outputdir);
msgbox(sprintf('ADAM first-level finished.\nResults:\n%s', cfg.outputdir), 'ADAM');
end
