function [msgs, info] = adam_setup_paths(opts)
% ADAM_SETUP_PATHS - Configure MATLAB path for ADAM (+ optional FieldTrip/EEGLAB).
% Runs ADAM/install/startup.m if found (for compatibility) THEN enforces user prefs
% for ADAM, FieldTrip, and EEGLAB paths. Guarantees ADAM on path if folders exist.
%
% Returns:
%   msgs : cellstr of log lines
%   info : struct with fields .adamRootInput .adamRootResolved .startupPath .didRunStartup

msgs = {};
info = struct('adamRootInput','','adamRootResolved','','startupPath','','didRunStartup',false);

% ---- Read options / prefs
if nargin < 1 || ~isstruct(opts), opts = struct(); end
if ~isfield(opts,'adamRoot'),   opts.adamRoot   = getpref('eeglab_adam','adamRoot','');   end
if ~isfield(opts,'ftRoot'),     opts.ftRoot     = getpref('eeglab_adam','ftRoot','');     end
if ~isfield(opts,'eeglabRoot'), opts.eeglabRoot = getpref('eeglab_adam','eeglabRoot',''); end

adamRootIn = strtrim(char(string(opts.adamRoot)));
ftRoot     = strtrim(char(string(opts.ftRoot)));
eeglabRoot = strtrim(char(string(opts.eeglabRoot)));
info.adamRootInput = adamRootIn;

if isempty(adamRootIn) || ~isfolder(adamRootIn), msgs{end+1} = 'ADAM root not set or not a folder.'; end
if ~isempty(ftRoot)     && ~isfolder(ftRoot),     msgs{end+1} = 'FieldTrip root not found.'; end
if ~isempty(eeglabRoot) && ~isfolder(eeglabRoot), msgs{end+1} = 'EEGLAB root not found.'; end

% ---- Locate startup.m robustly
[startupPath, adamRootResolved, note] = locate_adam_startup(adamRootIn);
if ~isempty(note), msgs{end+1} = note; end
info.adamRootResolved = adamRootResolved;
info.startupPath      = startupPath;

% ---- Run ADAM startup if found (but it may ignore variables)
if ~isempty(startupPath) && isfile(startupPath)
    try
        prevDir = pwd;
        cd(fileparts(startupPath));
        run(startupPath); % may print its own warnings; OK
        cd(prevDir);
        info.didRunStartup = true;
        msgs{end+1} = sprintf('Ran ADAM startup: %s', startupPath);
        if ~strcmp(adamRootResolved, adamRootIn) && ~isempty(adamRootResolved)
            setpref('eeglab_adam','adamRoot',adamRootResolved);
            msgs{end+1} = sprintf('Updated preference adamRoot -> %s', adamRootResolved);
        end
    catch ME
        msgs{end+1} = sprintf('WARNING: ADAM startup failed (%s). Continuing with manual setup.', ME.message);
        info.didRunStartup = false;
    end
else
    msgs{end+1} = 'ADAM install/startup.m not found. Using manual setup.';
end

% ---- Enforce user prefs regardless of startup behavior
try
    % EEGLAB path (helpful if not in MATLAB path already)
    if ~isempty(eeglabRoot) && isfolder(eeglabRoot) && isempty(which('eeglab'))
        addpath(eeglabRoot);
        msgs{end+1} = sprintf('Added EEGLAB to path: %s', eeglabRoot);
    end

    % FieldTrip path + defaults
    if ~isempty(ftRoot) && isfolder(ftRoot)
        if isempty(which('ft_defaults')), addpath(ftRoot); msgs{end+1} = sprintf('Added FieldTrip to path: %s', ftRoot); end
        if ~isempty(which('ft_defaults'))
            try, ft_defaults; msgs{end+1} = 'FieldTrip defaults executed.'; catch ME2, msgs{end+1} = sprintf('WARNING: ft_defaults failed (%s).', ME2.message); end
        end
    end

    % ADAM path (guarantee)
    adamAdd = '';
    if ~isempty(adamRootResolved) && isfolder(adamRootResolved), adamAdd = adamRootResolved;
    elseif ~isempty(adamRootIn)   && isfolder(adamRootIn),       adamAdd = adamRootIn;
    end
    if ~isempty(adamAdd)
        addpath(genpath(adamAdd));
        msgs{end+1} = sprintf('Ensured ADAM on path: %s', adamAdd);
    end

    rehash;
catch ME
    msgs{end+1} = sprintf('WARNING: Manual path setup encountered an error: %s', ME.message);
end

% ---- Final check
needFun = {'adam_MVPA_firstlevel','adam_compute_group_MVPA','adam_compute_group_ERP','adam_plot_MVPA'};
missing = {};
for k = 1:numel(needFun)
    if isempty(which(needFun{k})), missing{end+1} = needFun{k}; end %#ok<AGROW>
end
if ~isempty(missing)
    msgs{end+1} = ['MISSING after setup: ' strjoin(missing, ', ')];
else
    msgs{end+1} = 'ADAM functions available on path.';
end

% Also print to console (in case helpdlg truncates)
for i = 1:numel(msgs), try, disp(['[ADAM-setup] ' msgs{i}]); end, end

% ===== Helpers =====
    function [sp, rootResolved, noteMsg] = locate_adam_startup(rootCandidate)
        sp = ''; rootResolved = ''; noteMsg = '';
        if isempty(rootCandidate) || ~isfolder(rootCandidate), return; end

        % 1) Direct expected location
        direct = fullfile(rootCandidate,'install','startup.m');
        if exist(direct,'file') == 2
            sp = direct; rootResolved = rootCandidate; return;
        end

        % 2) Parent pointing (e.g., external/)
        cand = fullfile(rootCandidate,'ADAM','install','startup.m');
        if exist(cand,'file') == 2
            sp = cand; rootResolved = fileparts(fileparts(sp)); return;
        end

        % 3) Recursive search (first match)
        d = dir(fullfile(rootCandidate,'**','install','startup.m')); % R2016b+
        if ~isempty(d)
            sp = fullfile(d(1).folder, d(1).name);
            rootResolved = fileparts(fileparts(sp));
            noteMsg = sprintf('Resolved ADAM root via recursive search: %s', rootResolved);
        end
    end
end
