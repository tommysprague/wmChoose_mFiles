function [ii_data,ii_cfg,ii_sacc] = wmChoose_preproc1(edf_fn,cfg_fn,preproc_fn,targ_coords,trialinfo,ii_params)
% wmChoose_preproc1 Adapted from ii_preproc
%   Because for some conditions we don't know which coord is chosen until
%   eye movement measured, we must first select fixations, then determine
%   which is 'nearby', then calibrate to that one.
% 
%

%
% Tommy Sprague, 8/21/2017


% TODO: params contains resolution, ppd (or screen params), saccade
% detection params, etc. 

% initialize iEye - make sure paths are correct, etc
ii_init;

if nargin < 4 || isempty(ii_params)
    ii_params = ii_loadparams;
end

% import data
[ii_data,ii_cfg] = ii_import_edf(edf_fn,cfg_fn,[edf_fn(1:end-4) '_iEye.mat']);

% Show only the channels we care about at the moment
%ii_view_channels('X,Y,TarX,TarY,XDAT');

% rescale X, Y based on screen info
[ii_data,ii_cfg] = ii_rescale(ii_data,ii_cfg,{'X','Y'},ii_params.resolution,ii_params.ppd);



% Invert Y channel (the eye-tracker spits out flipped Y values)
[ii_data,ii_cfg] = ii_invert(ii_data,ii_cfg,'Y');


% remove extreme-valued X,Y channels (further than the screen edges)
[ii_data,ii_cfg] = ii_censorchans(ii_data,ii_cfg,{'X','Y'},...
    {[-0.5 0.5]*ii_params.resolution(1)/ii_params.ppd,...
     [-0.5 0.5]*ii_params.resolution(2)/ii_params.ppd});




% Correct for blinks
[ii_data, ii_cfg] = ii_blinkcorrect(ii_data,ii_cfg,{'X','Y'},'Pupil', ...
      ii_params.blink_thresh,ii_params.blink_window(1),ii_params.blink_window(2),'prctile'); % maybe 50, 50? %altering this 6/1/2017 from 1800 in both x/y 


% split into individual trials (so that individual-trial corrections can be
% applied)
[ii_data,ii_cfg] = ii_definetrial(ii_data,ii_cfg,...
    ii_params.trial_start_chan, ii_params.trial_start_value,...
    ii_params.trial_end_chan,   ii_params.trial_end_value); 


% Smooth data
[ii_data,ii_cfg] = ii_smooth(ii_data,ii_cfg,{'X','Y'},ii_params.smooth_type,...
    ii_params.smooth_amt);


% compute velocity using the smoothed data
[ii_data,ii_cfg] = ii_velocity(ii_data,ii_cfg,'X_smooth','Y_smooth');


% below - need to document still....

% look for saccades 
[ii_data,ii_cfg] = ii_findsaccades(ii_data,ii_cfg,'X_smooth','Y_smooth',...
    ii_params.sacc_velocity_thresh,ii_params.sacc_duration_thresh,...
    ii_params.sacc_amplitude_thresh); 



% find fixation epochs (between saccades and blinks)
% [create X_fix, Y_fix channels? these could be overlaid with 'raw' data as
% 'stable' eye positions
[ii_data,ii_cfg] = ii_findfixations(ii_data,ii_cfg,{'X','Y'},ii_params.fixation_mode);



% select the last fixation of pre-target epochs (trying to also do delay..)
[ii_data,ii_cfg] = ii_selectfixationsbytrial( ii_data, ii_cfg, ii_params.epoch_chan,...
    ii_params.drift_epoch, ii_params.drift_fixation_mode );

% use those selections to drift-correct each trial (either using the
% fixation value, which may include timepoints past end of epoch, or using
% 'raw' or 'smoothed' data on each channel)
[ii_data,ii_cfg] = ii_driftcorrect(ii_data,ii_cfg,{'X','Y'},ii_params.drift_select_mode,...
    ii_params.drift_target);



% add trial info [not explicitly necessary if simple experiment, TarX &
% TarY fields used as before]
%
% trial_info should be n_trials x n_params/features - can be indexed in
% some data processing commands below. can be cell or array. 


% 'target correct' or 'calibrate' (which name is better?)
% adjust timeseries on a trial so that gaze at specified epoch (quantified
% w/ specified method, like driftcorrect) is at known coords (either given
% by a channel or a pair of cols in ii_cfg.trialinfo

% first, select relevant epochs (should be one selection per trial)
%[ii_data,ii_cfg] = ii_selectfixationsbytrial(ii_data,ii_cfg,'XDAT',4,'last',300); % 
[ii_data,ii_cfg] = ii_selectfixationsbytrial(ii_data,ii_cfg,ii_params.epoch_chan,...
    ii_params.calibrate_epoch,ii_params.calibrate_select_mode,ii_params.calibrate_window); % 

[targ_coords,coord_idx,dist_from_targs] = ii_nearestcoord(ii_data,ii_cfg,targ_coords);


% if trialinfo is defined, otherwise skip
if nargin>=5 && ~isempty(trialinfo)
    [ii_data,ii_cfg] = ii_addtrialinfo(ii_data,ii_cfg,[trialinfo coord_idx dist_from_targs]);
end




% then, calibrate by trial
% ii_calibratebytrial.m
%[ii_data,ii_cfg] = ii_calibratebytrial(ii_data,ii_cfg,{'X','Y'},targ_coords,'scale',[0.75 4/3]);
% NOTE: differs from ii_preproc! uses targ_coords, from above, instead of
% TarX, TarY
%[ii_data,ii_cfg] = ii_calibratebytrial(ii_data,ii_cfg,{'X','Y'},...
%   targ_coords,ii_params.calibrate_mode, ii_params.calibrate_limits);

[ii_data,ii_cfg] = ii_calibratebyrun(ii_data,ii_cfg,{'X','Y'},targ_coords,3,ii_params.calibrate_limits);


% plot all these - make sure they're good
%f_all = ii_plotalltrials(ii_data,ii_cfg,{'X','Y'},[],[],'XDAT',[3 4],0);
f_all = ii_plotalltrials(ii_data,ii_cfg,{'X','Y'},[],[],ii_params.epoch_chan,ii_params.plot_epoch,ii_params.show_plots);

% save the figures for our records
if length(f_all)>1
    for ff = 1:lenght(f_all)
        saveas(f_all,sprintf('%s_%02.f.png',preproc_fn(1:end-4),ff),'png');
    end
else
    saveas(f_all,sprintf('%s.png',preproc_fn(1:end-4)),'png');
end

% and plot the final full timeseries
% and plot the final full timeseries
if ii_params.show_plots == 1
    f_ts = ii_plottimeseries(ii_data,ii_cfg);
else
    f_ts = ii_plottimeseries(ii_data,ii_cfg,[],'nofigure');
end
saveas(f_ts,sprintf('%s_timeseries.png',preproc_fn(1:end-4)),'png');


ii_cfg.params = ii_params;

% save ii_data,ii_cfg in _preproc.mat file
%ii_savedata(ii_data,ii_cfg,sprintf('%s_iEye_preproc.mat',ii_cfg.edf_file(1:end-4)));
ii_savedata(ii_data,ii_cfg,preproc_fn);%sprintf('%s_iEye_preproc.mat',ii_cfg.edf_file(1:end-4)));

% get the saccades
[ii_data,ii_cfg,ii_sacc] = ii_extractsaccades(ii_data,ii_cfg,{'X','Y'},...
    ii_params.extract_sacc_mode_start,...
    ii_params.extract_sacc_mode_end,...
    ii_params.epoch_chan);

% save the saccades
ii_savesacc(ii_cfg,ii_sacc,[preproc_fn(1:end-4) '_sacc.mat']);


end
