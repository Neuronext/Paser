function psr_sst_artifact_removal(files,data,MFAtimesAll)

% Artifact removal

spikeTimes = [];
tetrodeID  = [];
ntets      = length(files);
Fs         = zeros(ntets,1);

% Load spikes from all tetrodes

for iTetrode = 1:ntets
    spikes = [];
    load(files{iTetrode});
    nspikes    = spikes.nspikes; % spikes per channel
    nspikesMax = max(nspikes);
    if (isfield(spikes,'spiketimes'))
        for i = 1:nspikesMax % run through every channel
            spikeTimesNew = spikes.spiketimes(nspikes > 0);
            spikeTimes    = [spikeTimes, spikeTimesNew]; %#ok
            tetrodeID     = [tetrodeID, iTetrode * ones(size(spikeTimesNew))]; %#ok
            nspikes       = nspikes - 1;
        end
    end
    Fs(iTetrode) = spikes.params.Fs;
end

Fs = mode(Fs);
parameters.Fs = Fs;

[spikeTimes,~] = sort(spikeTimes);

% Calculate correlations across all channels at each spike time

[artifacts,~,correlations,nsamples] = psr_sst_artifact_correlation(parameters,data,spikeTimes);

% Add magnetic field artifacts

nCells = length(MFAtimesAll);
MFAtimes = [];
for iCell = 1:nCells; MFAtimes = [MFAtimes,MFAtimesAll{iCell}]; end %#ok
MFAtimes = MFAtimes';

if (~isempty(MFAtimes))
    artifact_length = 0.5 * (nsamples - 1);
    MFAs = round(Fs * MFAtimes);
    MFAs(MFAs <= artifact_length) = artifact_length + 1;
    MFAs(MFAs > size(data,2) - artifact_length) = size(data,2) - artifact_length;
    MFAs = bsxfun(@plus,MFAs,-artifact_length:artifact_length)';
    MFAs = MFAs(:);
    artifacts = [artifacts; MFAs];
end

% Process

for iTetrode = 1:ntets
    
    samples = zeros(1,size(data,2));
    load(files{iTetrode});
            
    % Remove artifact spikes from spike vector
    
    spiketimes = spikes.spiketimes; % in seconds
    spiketimes = round(spiketimes * Fs);   % in sample number
    samples(spiketimes)  = 2;
    samples(artifacts)   = samples(artifacts) - 1;
    samples(samples < 1) = [];
    id = find(samples == 2);
    spikes = psr_sst_spike_removal(spikes,id,'keep');
    spikes.correlations = correlations(tetrodeID == iTetrode);
        
    % Remove 'nspikes' field
    spikes = rmfield(spikes,'nspikes');
    
    % Save
    save(files{iTetrode},'spikes','metadata','freq','parameters');
end

end