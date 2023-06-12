clear
clc
%%
% Let's see how can we visualize all channels at once

% create time scope with 14 input channels, 512Hz sample rate and a buffer
% length of 10 seconds (5120 samples per channel)
scope_handle = dsp.TimeScope(14, 512, 'BufferLength', 5120,...
    'TimeAxisLabels', 'Bottom', 'YLimits', [-200000 200000],...
    'TimeSpan', 10, 'LayoutDimensions', [7,2], 'ReduceUpdates', true,...
    'YLabel', 'Amplitude [µV]','AxesScaling','Auto');
% switch to second axes object to change limit and label
set(scope_handle, 'ActiveDisplay', 3, 'YLimits', [-200000 200000], 'YLabel', 'Amplitude [µV]');

%% Device setup

fprintf('Creating Device Object...\r\n')
% Create interface object
gds_interface = gtecDeviceInterface;

% Set the IP ports for host and client. 
gds_interface.IPAddressHost = '127.0.0.1';
gds_interface.IPAddressLocal = '127.0.0.1';
gds_interface.HostPort = 50223;
gds_interface.LocalPort = 50224;

% Get currently connected devices
connected_devices = gds_interface.GetConnectedDevices();

fprintf('Configuring device...\r\n')
gusbamp_config = gUSBampDeviceConfiguration();

% First basic setting, lets change the name of the device currently
% connected to the computer
gusbamp_config.Name = connected_devices(1,1).Name;

% Now let's change other settings such as sampling rate and Number of
% scanns, remember that the default values are 256 and 8 respectively
gusbamp_config.SamplingRate = 512;
gusbamp_config.NumberOfScans = 16;
gusbamp_config.CommonGround = true(1,4);
gusbamp_config.CommonReference = true(1,4);
gusbamp_config.ShortCutEnabled = false;
gusbamp_config.CounterEnabled = false;
gusbamp_config.TriggerEnabled = false;

% Let's apply configuration to our device, we have to edit the contents of
% gusbamp_config first, and then apply it to the gds_interface, object 
gds_interface.DeviceConfigurations = gusbamp_config;

% Let's set the number of channels to use
num_chan = 14;

% Now let's enable our channels to acquire data
for i=1:num_chan;
 gusbamp_config.Channels(1,i).Available = true;
 gusbamp_config.Channels(1,i).Acquire = true;
 % do not use bandpass filter
 gusbamp_config.Channels(1,i).BandpassFilterIndex = -1;
 % use notch filter at 50Hz
 gusbamp_config.Channels(1,i).NotchFilterIndex = 4;
 % do not use a bipolar channel
 gusbamp_config.Channels(1,i).BipolarChannel = 0;
end

% % Let's set the internal generator to test all channels
% gusbamp_siggen = gUSBampInternalSignalGenerator();
% gusbamp_siggen.Enabled = true;
% gusbamp_siggen.Frequency = 10;
% gusbamp_siggen.WaveShape = 3;
% gusbamp_siggen.Amplitude = 200;
% gusbamp_siggen.Offset = 0;
% gusbamp_config.InternalSignalGenerator = gusbamp_siggen;

% Apply lattest settings to the device
gds_interface.DeviceConfigurations = gusbamp_config;

% We set current settings before starting to work
gds_interface.SetConfiguration();

% Before we start aqcquiring data, let's set the time and number of samples

% 10 seconds recording, defined by user
% data_time = 10;
task = input('Enter condition: ');

data_time = input('Enter recording time (min): ');

% convert data time into seconds
data_time = data_time*60;

% Sampling rate, obtained from device
fs = gusbamp_config.SamplingRate;

% number of samples to acquire
n_samples = data_time*fs;

fprintf('Device ready. Press any key to start acquisition...\n\n')
pause

% Start data acquisition 
gds_interface.StartDataAcquisition();

datestring_start = datestr(datetime('now'),'yyyy-mm-dd_HH-MM-SS'); 
fprintf ('EEG Recording Started on %s\r\n', datestring_start);

samples_acquired = 0;
fprintf ('Collecting Data...\r\n');

aq_start = now;
while (samples_acquired < n_samples)
 [scans_received, data] = gds_interface.GetData(8);
 
% these lines will call the oscilloscope handler and display the 
% channels, it should show 6 screens of 10 seconds each
 step(scope_handle, data(:,1),data(:,2),data(:,3),data(:,4),data(:,5),data(:,6),data(:,7),...
                    data(:,8),data(:,9),data(:,10),data(:,11),data(:,12),data(:,13),data(:,14));
  
 %this lines accumulate the data received in each scan to be processed
 %later
 data_received((samples_acquired + 1) : (samples_acquired + scans_received), :) = data;
 samples_acquired = samples_acquired + scans_received; 
end
aq_stop = now;

gds_interface.StopDataAcquisition();
fprintf ('Data Acquisition Finished...\r\n');

%% Exporting recorded data to textfile
% generate timestamps array

timestamp = linspace(aq_start,aq_stop,n_samples);
timestamp = datestr(timestamp,'HH:MM:SS.FFF');

% wrapping dataset
vars = ["TimeStamp" "F3" "Fz" "F4" "T7" "C3" "Cz" "C4" "T8" "P3" "Pz" "P4" "O1" "Oz" "O2"];
dataset = string(data_received);
dataset = horzcat(timestamp,dataset);
EEGData = array2table(dataset, "VariableNames",vars);

% Save as .mat
% outputfilemat = strcat('OutputData\EEG_',datestring_start,'_',task,'.mat');
% save(outputfilemat,'data_received');

%save as .csv
outputfilecsv = strcat('OutputData\EEG_',datestring_start,'_',task,'.csv');
writetable(EEGData,outputfilecsv,"Delimiter",";");

% clean up
delete(gds_interface)

scope_handle.hide;

clear gds_interface;
clear gusbamp_config;
clear scope_handle;












