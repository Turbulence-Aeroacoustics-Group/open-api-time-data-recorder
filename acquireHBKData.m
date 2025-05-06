function [data, channelInfo] = acquireHBKData(ipAddress, acquisitionFreq, acquisitionTime, saveDirectory)
% acquireHBKData Acquire data from HBK LAN-XI device
%   [data, channelInfo] = acquireHBKData(ipAddress, acquisitionFreq, acquisitionTime, saveDirectory)
%   
%   Inputs:
%   ipAddress - IP address of the HBK LAN-XI device (e.g., '169.254.230.53')
%   acquisitionFreq - Acquisition frequency in Hz
%   acquisitionTime - Duration of acquisition in seconds
%   saveDirectory - Directory path where data should be saved
%   
%   Outputs:
%   data - Structure containing acquired data
%   channelInfo - Structure containing channel and module information

    % Constants
    DEFAULT_TIMEOUT = 60;
    DOMAIN = 45;

    % Initialize output structures
    data = struct();
    channelInfo = struct();
    
    try
        % Step 1: Get module information and setup channels
        moduleInfo = GetModuleInformation(ipAddress, DEFAULT_TIMEOUT);
        channelInfo.module = moduleInfo;
        
        % Step 3: Configure channel setup based on frequency
        channelSetup = struct();
        channelSetup.frequency = acquisitionFreq;
        channelSetup.duration = acquisitionTime;
        
        % Step 4: Open recorder
        openParams = struct();
        openParams.destinationPort = [];  % Will be assigned by the recorder
        openParams.duration = acquisitionTime;
        recorderPort = OpenRecorder(ipAddress, openParams, DEFAULT_TIMEOUT);
        
        % Step 5: Prepare for data acquisition
        PrepareRecorder(ipAddress, channelSetup, DEFAULT_TIMEOUT);
        
        % Step 6: Start recording
        StartRecording(ipAddress, DEFAULT_TIMEOUT);
        
        % Step 7: Collect data
        signalData = table();
        interpretData = table();
        numMessages = 0;
        messagesRequired = ceil(acquisitionTime * acquisitionFreq);
        
        while numMessages < messagesRequired
            [newSignalData, newInterpretData] = GetRecorderData(ipAddress, recorderPort, DEFAULT_TIMEOUT);
            if ~isempty(newSignalData)
                signalData = [signalData; newSignalData];
                interpretData = [interpretData; newInterpretData];
                numMessages = numMessages + height(newSignalData);
            end
        end
        
        % Step 8: Stop recording
        StopRecording(ipAddress, DEFAULT_TIMEOUT);
        
        % Step 9: Close recorder
        CloseRecorder(ipAddress, DEFAULT_TIMEOUT);
        
        % Package data for output
        data.signals = signalData;
        data.interpretation = interpretData;
        data.acquisitionInfo = struct('frequency', acquisitionFreq, ...
                                    'duration', acquisitionTime, ...
                                    'timestamp', datetime('now'), ...
                                    'ipAddress', ipAddress);
        
        % Save data to specified directory
        if ~exist(saveDirectory, 'dir')
            mkdir(saveDirectory);
        end
        
        % Create filename based on timestamp
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = fullfile(saveDirectory, sprintf('hbk_data_%s.h5', timestamp));
        
        % Save data and channel info in HDF5 format
        % Create main groups
        h5create(filename, '/data/signals', size(signalData.Variables));
        h5write(filename, '/data/signals', signalData.Variables);
        
        % Save signal variable names
        varNames = signalData.Properties.VariableNames;
        h5create(filename, '/data/signal_variables', size(varNames));
        h5write(filename, '/data/signal_variables', varNames);
        
        % Save interpretation data if not empty
        if ~isempty(interpretData)
            h5create(filename, '/data/interpretation', size(interpretData.Variables));
            h5write(filename, '/data/interpretation', interpretData.Variables);
            
            % Save interpretation variable names
            interpVarNames = interpretData.Properties.VariableNames;
            h5create(filename, '/data/interpretation_variables', size(interpVarNames));
            h5write(filename, '/data/interpretation_variables', interpVarNames);
        end
        
        % Save acquisition info
        h5create(filename, '/metadata/frequency', [1]);
        h5write(filename, '/metadata/frequency', acquisitionFreq);
        
        h5create(filename, '/metadata/duration', [1]);
        h5write(filename, '/metadata/duration', acquisitionTime);
        
        h5create(filename, '/metadata/ip_address', [1 length(ipAddress)], 'DataType', 'string');
        h5write(filename, '/metadata/ip_address', ipAddress);
        
        h5create(filename, '/metadata/timestamp', [1], 'DataType', 'string');
        h5write(filename, '/metadata/timestamp', datetime('now'));
        
        % Save channel info
        if ~isempty(channelInfo.module)
            moduleData = jsonencode(channelInfo.module);
            h5create(filename, '/channel_info/module', [1 length(moduleData)], 'DataType', 'string');
            h5write(filename, '/channel_info/module', moduleData);
        end
        
        fprintf('Data saved to: %s\n', filename);
        fprintf('HDF5 structure:\n');
        fprintf('/data/signals - Main signal data\n');
        fprintf('/data/signal_variables - Signal variable names\n');
        fprintf('/data/interpretation - Signal interpretation data\n');
        fprintf('/metadata/* - Acquisition parameters and metadata\n');
        fprintf('/channel_info/* - Channel and module information\n');

    catch ME
        % Ensure recorder is closed in case of error
        try
            CloseRecorder(ipAddress, DEFAULT_TIMEOUT);
        catch
            % Ignore errors during cleanup
        end
        rethrow(ME);
    end
end
