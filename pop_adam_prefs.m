function pop_adam_prefs()
% POP_ADAM_PREFS - Preferences GUI for the ADAM EEGLAB plugin.
%
% Lets the user set ADAM, FieldTrip and EEGLAB root folders.
% Stores prefs under group 'eeglab_adam' and can apply/test immediately.
%
% Author: <Your Name>, 2025
% License: GPLv3

% ---- Load existing preferences
adamRoot   = getpref('eeglab_adam','adamRoot','');
ftRoot     = getpref('eeglab_adam','ftRoot','');
eeglabRoot = getpref('eeglab_adam','eeglabRoot','');

% ---- Geometry (7 rows)
geometry = { ...
    [1] ...            % 1) Title
    [1 2 0.6] ...      % 2) ADAM row
    [1 2 0.6] ...      % 3) FieldTrip row
    [1 2 0.6] ...      % 4) EEGLAB row
    [1] ...            % 5) Note 1
    [1] ...            % 6) Note 2
    [1 1] ...          % 7) Buttons (OK, Apply & Test)
    };

% ---- Build UI list programmatically (avoid vertcat issues)
uilist = {};
addc({ 'style' 'text' 'string' 'Set toolboxes roots. ADAM startup will use these to configure the path.' });

% ADAM
addc({ 'style' 'text' 'string' 'ADAM root:' });
addc({ 'style' 'edit' 'tag' 'adamRoot' 'string' adamRoot });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback' ...
    ['p = uigetdir(''Select ADAM root folder''); ' ...
     'if isequal(p,0), return; end; ' ...
     'set(findobj(gcbf,''tag'',''adamRoot''),''string'',p);'] });

% FieldTrip
addc({ 'style' 'text' 'string' 'FieldTrip root (optional):' });
addc({ 'style' 'edit' 'tag' 'ftRoot' 'string' ftRoot });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback' ...
    ['p = uigetdir(''Select FieldTrip root folder''); ' ...
     'if isequal(p,0), return; end; ' ...
     'set(findobj(gcbf,''tag'',''ftRoot''),''string'',p);'] });

% EEGLAB
addc({ 'style' 'text' 'string' 'EEGLAB root (optional if already running):' });
addc({ 'style' 'edit' 'tag' 'eeglabRoot' 'string' eeglabRoot });
addc({ 'style' 'pushbutton' 'string' 'Browse...' 'callback' ...
    ['p = uigetdir(''Select EEGLAB root folder''); ' ...
     'if isequal(p,0), return; end; ' ...
     'set(findobj(gcbf,''tag'',''eeglabRoot''),''string'',p);'] });

% Notes
addc({ 'style' 'text' 'string' 'Tip: If ADAM/install/startup.m exists, it will be executed using these paths.' });
addc({ 'style' 'text' 'string' 'Otherwise, the plugin will add ADAM (and FT) to the MATLAB path manually.' });

% Buttons
addc({ 'style' 'pushbutton' 'string' 'OK (Save)' 'callback' 'uiresume(gcbf);' });
addc({ 'style' 'pushbutton' 'string' 'Apply & Test' 'callback' ...
    ['adamRoot = get(findobj(gcbf,''tag'',''adamRoot''),''string'');' ...
     'ftRoot = get(findobj(gcbf,''tag'',''ftRoot''),''string'');' ...
     'eeglabRoot = get(findobj(gcbf,''tag'',''eeglabRoot''),''string'');' ...
     'setpref(''eeglab_adam'',''adamRoot'',strtrim(adamRoot));' ...
     'setpref(''eeglab_adam'',''ftRoot'',strtrim(ftRoot));' ...
     'setpref(''eeglab_adam'',''eeglabRoot'',strtrim(eeglabRoot));' ...
     '[msgs, info] = adam_setup_paths(struct(''adamRoot'',adamRoot,''ftRoot'',ftRoot,''eeglabRoot'',eeglabRoot));' ...
     'if isfield(info,''adamRootResolved'') && ~isempty(info.adamRootResolved) && ~strcmp(info.adamRootResolved, adamRoot),' ...
     '  setpref(''eeglab_adam'',''adamRoot'',info.adamRootResolved);' ...
     '  set(findobj(gcbf,''tag'',''adamRoot''),''string'',info.adamRootResolved);' ...
     'end;' ...
     'msg = strjoin(msgs,newline); helpdlg(msg,''ADAM path setup result'');' ] });

% ---- Launch GUI
res = inputgui('geometry', geometry, 'uilist', uilist, 'title', 'ADAM Preferences');
if isempty(res), return; end

% ---- Map results (order of edit/popup controls only)
% Edits present in order: adamRoot, ftRoot, eeglabRoot
idx = 0;
adamRoot   = nextstr();
ftRoot     = nextstr();
eeglabRoot = nextstr();

% ---- Save preferences (OK pressed)
setpref('eeglab_adam','adamRoot',adamRoot);
setpref('eeglab_adam','ftRoot',ftRoot);
setpref('eeglab_adam','eeglabRoot',eeglabRoot);

close(gcf);

% =========================
% Local helper functions
% =========================
    function addc(cellrow)
        % Append one control row safely
        uilist{end+1} = cellrow; %#ok<AGROW>
    end
    function v = nextstr()
        idx = idx + 1; v = res{idx};
        if isstring(v), v = char(v); end
        if ~ischar(v), v = ''; end
    end
end
