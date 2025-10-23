function vers = eegplugin_adam(fig, ~, ~)
% EEGPLUGIN_ADAM - EEGLAB plugin entry point for ADAM GUI integration.
% Adds "ADAM" menu with first-level and group analysis GUIs.
%
% Author: Your Name, 2025
% License: GPLv3
%
% This plugin provides GUIs to run the ADAM toolbox (Fahrenfort et al., 2018)
% directly from EEGLAB STUDYs and datasets.

vers = '0.1.0'; % plugin version

% Ensure EEGLAB main figure
if nargin < 1
    error('eegplugin_adam requires the EEGLAB main figure handle.');
end

% ----- Add "ADAM" top-level menu under Tools -----
toolsMenu = findobj(fig, 'tag', 'tools');
if isempty(toolsMenu), error('Cannot find EEGLAB Tools menu.'); end
adamMenu  = uimenu(toolsMenu, 'Label', 'ADAM', 'separator', 'on', 'tag', 'adam_menu');

% Submenus
uimenu(adamMenu, 'Label', 'First-level (MVPA)...', ...
    'callback', 'pop_adam_firstlevel;', 'tag', 'adam_firstlevel');
uimenu(adamMenu, 'Label', 'Group analysis...', ...
    'callback', 'pop_adam_group;', 'tag', 'adam_group');
uimenu(adamMenu, 'Label', 'Preferences...', ...
    'callback', 'pop_adam_prefs;', 'tag', 'adam_prefs');

% Print in EEGLAB history
eegh('EEGLAB: added ADAM plugin v%s', vers);
end
