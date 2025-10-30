function vers = eegplugin_adam(fig, ~, ~)
% EEGPLUGIN_ADAM - EEGLAB plugin entry point for ADAM GUI integration.
% Adds "ADAM" menu and ensures ADAM paths are configured from preferences.
%
% Author: Your Name, 2025
% License: GPLv3

vers = '0.2.1';

if nargin < 1
    error('eegplugin_adam requires the EEGLAB main figure handle.');
end

% --- Setup paths once (non-fatal if fails)
try
    msgs = adam_setup_paths();
    if ~isempty(msgs)
        eegh(sprintf('ADAM path setup: %s', strjoin(msgs, ' | ')));
    end
catch ME
    eegh(sprintf('ADAM path setup failed: %s', ME.message));
end

% ----- Add "ADAM" top-level menu under Tools -----
toolsMenu = findobj(fig, 'tag', 'tools');
if isempty(toolsMenu), error('Cannot find EEGLAB Tools menu.'); end

adamMenu = uimenu(toolsMenu, 'Label', 'ADAM', 'separator', 'on', ...
    'tag', 'adam_menu', ...
    'userdata', 'startup:on;set:on;study:on'); % always visible

uimenu(adamMenu, 'Label', 'Preferences', ...
    'callback', @(~,~) pop_adam_prefs(), ...
    'tag', 'adam_prefs', ...
    'userdata', 'startup:on;set:on;study:on');

uimenu(adamMenu, 'Label', 'First-level (MVPA)', ...
    'callback', @(~,~) pop_adam_firstlevel(), ...
    'tag', 'adam_firstlevel', ...
    'userdata', 'startup:off;set:on;study:on');

uimenu(adamMenu, 'Label', 'Visualize: Group ERP', ...
    'callback', @(~,~) pop_adam_group_erp_viewer(), ...
    'tag', 'adam_view_group_erp', ...
    'userdata', 'startup:on;set:on;study:on');

uimenu(adamMenu, 'Label', 'Visualize: Decoding', ...
    'callback', @(~,~) pop_adam_diag_mvpa_viewer(), ...
    'tag', 'adam_view_diag_mvpa', ...
    'userdata', 'startup:on;set:on;study:on');

uimenu(adamMenu, 'Label', 'Visualize: Single-subject decoding', ...
    'callback', @(~,~) pop_adam_single_subject_mvpa_viewer(), ...
    'tag', 'adam_view_single_subject_mvpa', ...
    'userdata', 'startup:on;set:on;study:on');

uimenu(adamMenu, 'Label', 'Visualize: Temporal generalization', ...
    'callback', @(~,~) pop_adam_tgm_viewer(), ...
    'tag', 'adam_view_tgm', ...
    'userdata', 'startup:on;set:on;study:on');





% Force a redraw so EEGLAB applies enable rules immediately
try
    eeglab('redraw');
catch
end

eegh(sprintf('EEGLAB: added ADAM plugin v%s', vers));
end
