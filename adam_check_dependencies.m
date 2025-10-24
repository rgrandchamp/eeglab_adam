function s = adam_check_dependencies()
% ADAM_CHECK_DEPENDENCIES - Verify ADAM is on path and report versions.
% Returns struct with fields: ok, msgs

s.ok = true; s.msgs = {};

% If key ADAM functions are missing, try one automatic setup pass
need = {'adam_MVPA_firstlevel','adam_compute_group_MVPA','adam_compute_group_ERP','adam_plot_MVPA'};
missing = false;
for k = 1:numel(need)
    if isempty(which(need{k})), missing = true; break; end
end
if missing
    try
        msgs = adam_setup_paths();
        s.msgs = [s.msgs(:); msgs(:)];
    catch ME
        s.msgs{end+1} = sprintf('Path setup attempt failed: %s', ME.message);
    end
end

% Re-check presence
s.ok = true;
for k = 1:numel(need)
    if isempty(which(need{k}))
        s.ok = false;
        s.msgs{end+1} = sprintf('Missing ADAM function "%s" on MATLAB path.', need{k});
    end
end

% FieldTrip note (optional)
if isempty(which('ft_defaults'))
    s.msgs{end+1} = 'FieldTrip not found (only required for TFR analyses).';
end
end
