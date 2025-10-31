function pop_adam_prefs()
% POP_ADAM_PREFS - Preferences GUI for the ADAM EEGLAB plugin.
% Author: <Your Name>, 2025 | License: GPLv3

% ---- Load existing preferences
adamRoot   = getpref('eeglab_adam','adamRoot','');
ftRoot     = getpref('eeglab_adam','ftRoot','');
eeglabRoot = getpref('eeglab_adam','eeglabRoot','');

% ---- Detect EEGLAB root if pref empty ----
if isempty(eeglabRoot)
    try
        eeglabFile = which('eeglab');
        if ~isempty(eeglabFile)
            eeglabRoot = fileparts(eeglabFile);
        end
    catch
    end
end

% ---- Default FieldTrip path if empty (requested behavior) ----
% <EEGLAB root>\plugins\eeglab_adam\external\fieldtrip-20170704
if isempty(ftRoot) && ~isempty(eeglabRoot)
    ftDefault = fullfile(eeglabRoot, 'plugins', 'eeglab_adam', 'external', 'fieldtrip-20170704');
    if exist(ftDefault,'dir')
        ftRoot = ftDefault;  % prefill GUI with this default
    end
end

% ---- Geometry ----
geometry = { ...
    [1] ...            % Title
    [1 2 0.6] ...      % ADAM row
    [1 2 0.6] ...      % FieldTrip row
    [1 2 0.6] ...      % EEGLAB row
    [1] ...            % Note 1
    [1] ...            % Note 2
    };

% ---- UI ----
uilist = {};
addc({ 'style' 'text' 'string' 'Set toolboxes roots. ADAM startup will use these to configure the path.' });

% ADAM
addc({ 'style' 'text' 'string' 'ADAM root:' });
addc({ 'style' 'edit' 'tag' 'adamRoot' 'string' adamRoot });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback', @onBrowseAdam });

% FieldTrip
addc({ 'style' 'text' 'string' 'FieldTrip root (optional):' });
addc({ 'style' 'edit' 'tag' 'ftRoot' 'string' ftRoot });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback', @onBrowseFT });

% EEGLAB
addc({ 'style' 'text' 'string' 'EEGLAB root (optional if already running):' });
addc({ 'style' 'edit' 'tag' 'eeglabRoot' 'string' eeglabRoot });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback', @onBrowseEEGLAB });

% Notes
addc({ 'style' 'text' 'string' 'Tip: If ADAM/install/startup.m exists, it will be executed using these paths.' });
addc({ 'style' 'text' 'string' 'Otherwise, the plugin will add ADAM (and FT) to the MATLAB path manually.' });

% ---- Launch GUI (get also resstruct for tag-based reading)
[res, ~, ~, resstruct] = inputgui('geometry', geometry, 'uilist', uilist, ...
    'title', 'ADAM Preferences');
if isempty(res), return; end  % Cancel press or window closed

% ---- Read values by TAG (order-agnostic)
adamRoot   = getfield_def(resstruct, 'adamRoot',   '');
ftRoot     = getfield_def(resstruct, 'ftRoot',     '');
eeglabRoot = getfield_def(resstruct, 'eeglabRoot', '');

adamRoot   = strtrim(aschar(adamRoot));
ftRoot     = strtrim(aschar(ftRoot));
eeglabRoot = strtrim(aschar(eeglabRoot));

% ---- Save preferences
setpref('eeglab_adam','adamRoot',adamRoot);
setpref('eeglab_adam','ftRoot',ftRoot);
setpref('eeglab_adam','eeglabRoot',eeglabRoot);

% ---- Apply paths immediately (FieldTrip update done in BASE workspace)
try
    % 1) Remove ANY existing FieldTrip from path
    remove_all_fieldtrip_from_path();

    % 2) Re-add ADAM/FT/EEGLAB using central setup (optional)
    [msgs, info] = adam_setup_paths(struct( ...
        'adamRoot',   adamRoot, ...
        'ftRoot',     ftRoot, ...
        'eeglabRoot', eeglabRoot ...
    ));
    if ~isempty(msgs), eegh('[ADAM] Path setup: %s', strjoin(msgs,' | ')); end

    % 3) FIELDTRIP SETUP (do it in BASE workspace)
    if ~isempty(ftRoot) && exist(ftRoot,'dir')
        % ensure ft root is on base path, then run ft_defaults *in base*
        ftRootEsc = strrep(ftRoot, '''', '''''');
        evalin('base', sprintf('addpath(''%s''); ft_defaults;', ftRootEsc));

        % verify core functions are available
        ok = ~isempty(which('ft_defaults')) && ~isempty(which('ft_preprocessing'));
        if ok
            eegh('[ADAM] FieldTrip set to: %s', ftRoot);
        else
            warndlg('FieldTrip did not initialize correctly. Check your FieldTrip path.', 'ADAM preferences');
        end
    end

    % 4) Persist canonical ADAM root if resolved
    if isfield(info,'adamRootResolved') && ~isempty(info.adamRootResolved) && ~strcmp(info.adamRootResolved, adamRoot)
        setpref('eeglab_adam','adamRoot',info.adamRootResolved);
        try, set(findobj('tag','adamRoot'),'string',info.adamRootResolved); end
    end

catch ME
    warndlg(sprintf('Path update failed:\n%s', ME.message), 'ADAM preferences');
end

% Close the preferences window if it's still around
h = findobj('type','figure','-and','name','ADAM Preferences');
if ishghandle(h), close(h); end

% ===== done main function =====
end

% =========================
% Local functions (file-local)
% =========================
function addc(cellrow)
uilist = evalin('caller','uilist');
uilist{end+1} = cellrow; %#ok<AGROW>
assignin('caller','uilist',uilist);
end

function onBrowseAdam(~,~)
p = uigetdir_smart('adamRoot','Select ADAM root folder'); if isequal(p,0), return; end
set(findobj(gcbf,'tag','adamRoot'),'string',p);
end

function onBrowseFT(~,~)
p = uigetdir_smart('ftRoot','Select FieldTrip root folder'); if isequal(p,0), return; end
set(findobj(gcbf,'tag','ftRoot'),'string',p);
end

function onBrowseEEGLAB(~,~)
p = uigetdir_smart('eeglabRoot','Select EEGLAB root folder'); if isequal(p,0), return; end
set(findobj(gcbf,'tag','eeglabRoot'),'string',p);
end

function p = uigetdir_smart(editTag, titleStr)
fig = gcbf;
cur = '';
if ~isempty(fig) && ishghandle(fig)
    h = findobj(fig,'tag',editTag);
    if ~isempty(h), cur = strtrim(get(h,'string')); end
end
if isempty(cur) || ~exist(cur,'dir'), cur = pwd; end
p = uigetdir(cur, titleStr);
end

function s = aschar(v)
if isstring(v), s = char(v);
elseif ischar(v), s = v;
else, s = '';
end
end

function v = getfield_def(st, fld, def)
if isstruct(st) && isfield(st,fld), v = st.(fld); else, v = def; end
end

function remove_all_fieldtrip_from_path()
ftdefs = which('ft_defaults','-all');
for i = 1:numel(ftdefs)
    root = fileparts(ftdefs{i});
    try, rmpath(genpath(root)); catch, end
end
end
