clear all;
clc;
close all;


% inputs
ipAddress='169.254.230.53';
acquisitionFreq=25600; % in hz
acquisitionTime=10;% in seconds
saveDirectory='/Users/prateek/Desktop/HBK/open-api-time-data-recorder/Measurement Files/';
[data, channelInfo] = acquireHBKData(ipAddress, acquisitionFreq, acquisitionTime, saveDirectory);
