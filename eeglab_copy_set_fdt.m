function report = eeglab_copy_set_fdt(sourcedir, destdir, varargin)
% EEG_LAB_COPY_SET_FDT - Recursively find EEGLAB .set/.fdt files and copy them to a destination folder.
%
% Usage:
%   report = eeglab_copy_set_fdt(sourcedir, destdir, 'key', value, ...)
%
% Inputs:
%   sourcedir (char) - Root folder to search. All subfolders are scanned.
%   destdir   (char) - Destination folder where files will be copied.
%
% Optional name/value pairs:
%   'PreserveStructure' (logical, default=false)
%       If true, recreate the subfolder structure of sourcedir inside destdir.
%       If false, flatten: copy all files directly under destdir.
%
%   'Overwrite' (logical, default=false)
%       If false, existing files at destdir are not overwritten and are counted as skipped.
%       If true, files are overwritten.
%
%   'DryRun' (logical, default=false)
%       If true, nothing is copied; a report of what WOULD be copied is returned.
%
%   'Verbose' (logical, default=true)
%       If true, print progress messages to Command Window.
%
% Output:
%   report (struct) with fields:
%       n_set      - number of .set files discovered
%       n_fdt      - number of .fdt files discovered (paired + orphan)
%       n_copied   - number of files successfully copied
%       n_skipped  - number of files skipped (exists and Overwrite=false)
%       log        - struct array with per-file details (source, dest, action, message)
%
% Notes:
%   - For each .set file, the function will also copy a same-basename .fdt file
%     from the same source folder if it exists.
%   - Orphan .fdt files (without a matching .set) are also copied.
%   - This function does not modify .set headers or paths; it only copies files.
%
% Example:
%   % Copy all .set/.fdt from raw data tree into a single flat folder:
%   rpt = eeglab_copy_set_fdt('D:\data\raw', 'D:\data\collected', ...
%                             'PreserveStructure', false, 'Overwrite', false);
%
% See also: dir, copyfile
%
% Author: Plugin EEGLAB ADAM utils
% -------------------------------------------------------------------------

    % ---- Parse inputs
    p = inputParser;
    p.FunctionName = mfilename;
    addRequired(p, 'sourcedir', @(s) ischar(s) || (isstring(s) && isscalar(s)));
    addRequired(p, 'destdir',   @(s) ischar(s) || (isstring(s) && isscalar(s)));
    addParameter(p, 'PreserveStructure', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'Overwrite',         false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'DryRun',            false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'Verbose',            true, @(x) islogical(x) && isscalar(x));
    parse(p, sourcedir, destdir, varargin{:});
    opt = p.Results;
    sourcedir = char(sourcedir);
    destdir   = char(destdir);

    % ---- Validate folders
    if ~isfolder(sourcedir)
        error('%s: Source folder does not exist: %s', mfilename, sourcedir);
    end
    if ~isfolder(destdir)
        if opt.DryRun
            % Will create during real run
        else
            mkok = mkdir(destdir);
            if ~mkok, error('%s: Could not create destination folder: %s', mfilename, destdir); end
        end
    end

    % ---- Discover files
    set_list = find_files_recursive(sourcedir, '*.set');
    fdt_list = find_files_recursive(sourcedir, '*.fdt');

    % Build a map of .set -> paired .fdt (same basename in same folder)
    paired_fdt = false(size(fdt_list));
    tasks = struct('src', {}, 'dst', {}, 'type', {});

    % Queue all .set files
    for k = 1:numel(set_list)
        src_set = set_list{k};
        [src_dir, base, ~] = fileparts(src_set);

        % destination path
        dst_dir = compute_dest_dir(src_dir, sourcedir, destdir, opt.PreserveStructure);
        dst_set = fullfile(dst_dir, [base '.set']);

        tasks(end+1) = struct('src', src_set, 'dst', dst_set, 'type', '.set'); %#ok<AGROW>

        % look for paired .fdt in same folder
        cand_fdt = fullfile(src_dir, [base '.fdt']);
        idx = find(strcmpi(cand_fdt, fdt_list), 1, 'first');
        if ~isempty(idx)
            paired_fdt(idx) = true;
            dst_fdt = fullfile(dst_dir, [base '.fdt']);
            tasks(end+1) = struct('src', cand_fdt, 'dst', dst_fdt, 'type', '.fdt'); %#ok<AGROW>
        end
    end

    % Add orphan .fdt files (without a matching .set queued above)
    orphan_idx = find(~paired_fdt);
    for j = 1:numel(orphan_idx)
        src_fdt = fdt_list{orphan_idx(j)};
        [src_dir, base, ~] = fileparts(src_fdt);
        dst_dir = compute_dest_dir(src_dir, sourcedir, destdir, opt.PreserveStructure);
        dst_fdt = fullfile(dst_dir, [base '.fdt']);
        tasks(end+1) = struct('src', src_fdt, 'dst', dst_fdt, 'type', '.fdt'); %#ok<AGROW>
    end

    % ---- Copy (or simulate)
    log = struct('source', {}, 'destination', {}, 'action', {}, 'message', {});
    n_copied = 0;
    n_skipped = 0;

    if opt.Verbose
        fprintf('[%s] Found %d .set and %d .fdt files under "%s".\n', ...
            mfilename, numel(set_list), numel(fdt_list), sourcedir);
        if opt.DryRun, fprintf('[%s] DryRun enabled: no files will be copied.\n', mfilename); end
    end

    for t = 1:numel(tasks)
        src = tasks(t).src;
        dst = tasks(t).dst;
        this_dir = fileparts(dst);

        if ~opt.DryRun && ~isfolder(this_dir)
            mkdir(this_dir);
        end

        % Overwrite handling
        if ~opt.Overwrite && exist(dst, 'file')
            n_skipped = n_skipped + 1;
            log(end+1) = mklog(src, dst, 'skipped', 'Destination exists and Overwrite=false'); %#ok<AGROW>
            if opt.Verbose
                fprintf('  - SKIP   %s  (exists)\n', dst);
            end
            continue;
        end

        if opt.DryRun
            log(end+1) = mklog(src, dst, 'would-copy', 'DryRun'); %#ok<AGROW>
            if opt.Verbose
                fprintf('  - WOULD COPY -> %s\n', dst);
            end
        else
            [ok, msg, ~] = copyfile(src, dst, 'f');
            if ok
                n_copied = n_copied + 1;
                log(end+1) = mklog(src, dst, 'copied', ''); %#ok<AGROW>
                if opt.Verbose
                    fprintf('  - COPY   %s\n', dst);
                end
            else
                n_skipped = n_skipped + 1;
                log(end+1) = mklog(src, dst, 'error', msg); %#ok<AGROW>
                if opt.Verbose
                    fprintf('  ! ERROR  %s\n      %s\n', dst, msg);
                end
            end
        end
    end

    % ---- Report
    report = struct();
    report.n_set     = numel(set_list);
    report.n_fdt     = numel(fdt_list);
    report.n_copied  = n_copied;
    report.n_skipped = n_skipped;
    report.log       = log;

    if opt.Verbose
        fprintf('[%s] Done. Copied: %d, Skipped: %d.\n', mfilename, n_copied, n_skipped);
    end
end

% -------------------------------------------------------------------------
function files = find_files_recursive(rootdir, pattern)
% Return a cellstr of full paths matching pattern under rootdir (recursive).
    files = {};
    if ~isfolder(rootdir), return; end
    % Breadth-first traversal to avoid relying on ** support
    q = {rootdir};
    while ~isempty(q)
        cur = q{1}; q(1) = [];
        d = dir(fullfile(cur, pattern));
        d = d(~[d.isdir]);
        files = [files; fullfile(cur, {d.name}')]; %#ok<AGROW>

        sub = dir(cur);
        sub = sub([sub.isdir]);
        names = setdiff({sub.name}, {'.','..'});
        for i = 1:numel(names)
            q{end+1} = fullfile(cur, names{i}); %#ok<AGROW>
        end
    end
end

% -------------------------------------------------------------------------
function dst_dir = compute_dest_dir(src_dir, root_src, root_dst, preserve)
% Compute destination folder (preserve relative path or flatten).
    if preserve
        rel = erase(src_dir, append(trailing_sep(root_src)));
        if startsWith(rel, filesep), rel = rel(2:end); end
        dst_dir = fullfile(root_dst, rel);
    else
        dst_dir = root_dst;
    end
end

% -------------------------------------------------------------------------
function s = trailing_sep(p)
% Ensure path ends with file separator.
    if isempty(p), s = filesep; return; end
    if p(end) == filesep
        s = p;
    else
        s = [p filesep];
    end
end

% -------------------------------------------------------------------------
function entry = mklog(src, dst, action, msg)
% Create a log entry.
    entry = struct('source', src, 'destination', dst, 'action', action, 'message', msg);
end
