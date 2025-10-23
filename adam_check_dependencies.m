function s = adam_check_dependencies()
% ADAM_CHECK_DEPENDENCIES - Verify ADAM is on path and report versions.
% Returns struct with fields: ok, msgs

s.ok = true; s.msgs = {};

% Check ADAM functions
need = {'adam_MVPA_firstlevel','adam_compute_group_MVPA','adam_compute_group_ERP','adam_plot_MVPA'};
for k = 1:numel(need)
    if isempty(which(need{k}))
        s.ok = false;
        s.msgs{end+1} = sprintf('Missing ADAM function "%s" on MATLAB path.', need{k});
    end
end

% Optional: warn about FieldTrip versions (per ADAM notes)
% (We do not enforce FT unless user requests TFR)
if isempty(which('ft_defaults'))
    s.msgs{end+1} = 'FieldTrip not found (only required for TFR analyses).';
end
end
