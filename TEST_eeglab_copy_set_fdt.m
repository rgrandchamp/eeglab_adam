% 1) Copie plate (tout dans un seul dossier), sans écraser
r = eeglab_copy_set_fdt('C:\Users\Romain\Workspace\Practical MEEG\2025\data\OpenNeuro\ds002718\derivatives\eeglab', ...
    'C:\Users\Romain\Workspace\Practical MEEG\2025\data\OpenNeuro\ds002718\derivatives\eeglab_adam');

% 2) Conserver l’arborescence source et écraser si nécessaire
r = eeglab_copy_set_fdt('C:\EEG\raw_subjects', 'D:\backup\raw_subjects', ...
                        'PreserveStructure', true, 'Overwrite', true);

% 3) Simulation (dry run) pour voir ce qui serait copié
r = eeglab_copy_set_fdt('/data/eeg', '/data/stage', 'DryRun', true, 'Verbose', true);