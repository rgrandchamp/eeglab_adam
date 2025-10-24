function [ok, class1_str, class2_str] = pop_adam_classbuilder()
% POP_ADAM_CLASSBUILDER - Build ADAM class_spec strings using factor combinations.
%
% Returns:
%   ok          - logical, true if user clicked OK
%   class1_str  - string for cfg.class_spec{1}
%   class2_str  - string for cfg.class_spec{2}
%
% The preset matches Wakeman & Henson (2015):
%   Stimulus: Famous=[5 6 7], NonFamous=[13 14 15], Scrambled=[17 18 19]
%   Repetition: First=[5 13 17], Immediate=[6 14 18], Delayed=[7 15 19]
%
% Author: <Your Name>, 2025  |  License: GPLv3

ok = false; class1_str = ''; class2_str = '';

% ---------- Factor levels (numeric code sets)
stimKeys = {'Famous','NonFamous','Scrambled'};
reptKeys = {'First','Immediate','Delayed'};

stimMap = struct( ...
    'Famous',      [5 6 7], ...
    'NonFamous',   [13 14 15], ...
    'Scrambled',   [17 18 19] ...
);
reptMap = struct( ...
    'First',       [5 13 17], ...
    'Immediate',   [6 14 18], ...
    'Delayed',     [7 15 19] ...
);

% ---------- Defaults (WH2015 example)
defStim1 = 'NonFamous'; defRept1 = 'First';
defStim2 = 'Scrambled'; defRept2 = 'First';

% ---------- Geometry & UI (programmatic; one control per cell)
geometry = { ...
    [1] ...          % Title
    [1 1] ...        % Class1: Stimulus, Repetition
    [1 1] ...        % Class2: Stimulus, Repetition
    [1] ...          % Note
    [1 1] ...        % Buttons: OK / Cancel
};

uilist = {};
addc({ 'style' 'text' 'string' 'Build classes from factors (Stimulus × Repetition)' });

% Class 1
addc({ 'style' 'popupmenu' 'string' 'Famous|NonFamous|Scrambled' ...
       'value' pickidx(stimKeys, defStim1) });
addc({ 'style' 'popupmenu' 'string' 'First|Immediate|Delayed' ...
       'value' pickidx(reptKeys, defRept1) });

% Class 2
addc({ 'style' 'popupmenu' 'string' 'Famous|NonFamous|Scrambled' ...
       'value' pickidx(stimKeys, defStim2) });
addc({ 'style' 'popupmenu' 'string' 'First|Immediate|Delayed' ...
       'value' pickidx(reptKeys, defRept2) });

% Note
addc({ 'style' 'text' 'string' 'Tip: Defaults match WH2015 (NonFamous×First vs Scrambled×First).' });

% Buttons
addc({ 'style' 'pushbutton' 'string' 'OK'     'callback' 'uiresume(gcbf);' });
addc({ 'style' 'pushbutton' 'string' 'Cancel' 'callback' 'close(gcbf);' });

% ---------- Open dialog
res = inputgui('geometry', geometry, 'uilist', uilist, 'title', 'ADAM Class Builder');
if isempty(res), return; end

% ---------- Map results in order (popups output numeric indices)
idx = 0;
stim1_i = nextnum();   rept1_i = nextnum();
stim2_i = nextnum();   rept2_i = nextnum();

% Safety: ensure valid indices (1..3)
if any([stim1_i rept1_i stim2_i rept2_i] < 1) || any([stim1_i rept1_i stim2_i rept2_i] > 3)
    errordlg('Invalid selection in Class Builder.','ADAM'); return;
end

stim1 = stimKeys{stim1_i};   rept1 = reptKeys{rept1_i};
stim2 = stimKeys{stim2_i};   rept2 = reptKeys{rept2_i};

% ---------- Build cond_string-based class specs
if isempty(which('cond_string'))
    errordlg('ADAM function cond_string not found on the MATLAB path. Check ADAM setup.', 'ADAM');
    return;
end

try
    class1_str = cond_string(stimMap.(stim1), reptMap.(rept1));
    class2_str = cond_string(stimMap.(stim2), reptMap.(rept2));
catch ME
    errordlg(sprintf('cond_string failed: %s', ME.message), 'ADAM'); return;
end

ok = true;

% ======= local helpers =======
    function addc(c), uilist{end+1} = c; end %#ok<AGROW>
    function n = nextnum(), idx = idx+1; n = res{idx}; if isempty(n) || ~isscalar(n), n = NaN; end; end
    function v = pickidx(keys, val)
        j = find(strcmpi(keys,val),1); if isempty(j), j = 1; end; v = j;
    end
end
