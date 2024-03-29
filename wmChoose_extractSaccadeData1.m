% wmChoose_extractSaccadeData1.m (from MGSMap_extractSaccadeData1.m)
%
% extracts simple versions of initial, final saccades, saves them for use
% - also, for convenience, extracts X, Y, XDAT, Pupil for each trial





function wmChoose_extractSaccadeData1(subj)




if nargin < 1 || isempty(subj)
    %subj = {'KD','CC','EK','MR','AB'};
    subj = {'aa1','aa2','ab1','ab2','ac1','ac2','ae','af','ag','ah','ai'}; %aa1
    %subj = {'ah','ai'};
    
end

if ~iscell(subj)
    subj = {subj};
end

root = '/Volumes/data/wmChoose';

save_chan = {'X','Y','Pupil','XDAT'}; % what we want to extract & save for each trial

%% DEFINE PARAMETERS TO SELECT PRIMARY SACCADES
%  examine first saccade during relevant epoch
%  - how brief (duration) must they be?
%  - how big (amplitude) must they be?

excl_criteria.i_dur_thresh = 150; % must be shorter than 150 ms
excl_criteria.i_amp_thresh = 5;   % must be longer than 5 dva [if FIRST saccade in denoted epoch is not at least this long and at most this duration, drop the trial]
excl_criteria.i_err_thresh = 5;   % i_sacc must be within this many DVA of target pos to consider the trial (MGSMap)


%% DEFINE PARAMETERS TO REJECT TRIALS BASED ON NON-SACC METRICS
%  look at each trial's target/delay/etc periods, exclude trials if:
%  - any fixation outside a range of fixation point
%  - pupil not detected during entire target presentation
%  - 'calibration' adjustments outside of fair range (2/2 dva for drift)
%     (ii_cfg.calibrate.adj~=1) - trials where calibration was not applied

excl_criteria.drift_thresh = 2.5;     % if drift correction norm is this big or more, drop
excl_criteria.delay_fix_thresh = 2.5; % if any fixation is this far from 0,0 during delay (epoch 3)
excl_criteria.delay_raw_dur_thresh = 0.5; % if total of this many s of raw gaze points deviate from fixation window, drop trial

RESP_EPOCH = 3; % when did subj make a response? (when were they allowed to start responding)
FIX_EPOCH = 2;

for ss = 1:length(subj)
    
    
    
    % load already-concatenated behavioral data
    behav_fn = sprintf('%s/data/%s_wmChoose_behav.mat',root,subj{ss});
    thisbehav = load(behav_fn);
    
    % load preproc'd eye data
    iEye_fs = sprintf('%s/preproc_iEye/%s_wmChoose_behav1_r*_preproc.mat',root,subj{ss});
    iEye_fn = dir(iEye_fs);
    
    iEye_sacc_fs = sprintf('%s/preproc_iEye/%s_wmChoose_behav1_r*_preproc_sacc.mat',root,subj{ss});
    iEye_sacc_fn = dir(iEye_sacc_fs);
    
    
    
    % for all iEye files...
    for ii = 1:length(iEye_fn)
        
        fprintf('loading %s/%s\n',iEye_fn(ii).folder,iEye_fn(ii).name);
        this_et = load(sprintf('%s/%s',iEye_fn(ii).folder,iEye_fn(ii).name));
        
        tmp_this_sacc = load(sprintf('%s/%s',iEye_sacc_fn(ii).folder,iEye_sacc_fn(ii).name));
        
        
        
        this_cfg = tmp_this_sacc.ii_cfg;
        this_data = this_et.ii_data;
        this_sacc = tmp_this_sacc.ii_sacc;
        

        
        if ii == 1

            
            s_all = thisbehav.s_all;
            
            nblank = size(s_all.i_sacc,1);
            
            for chan_idx = 1:length(save_chan)
                s_all.(save_chan{chan_idx}) = cell(nblank,1);
            end
            
            % save features related to drift correction; calibration
            s_all.drift = nan(size(s_all.i_sacc,1),2);
            s_all.calib = nan(size(s_all.i_sacc,1),2);
            s_all.calib_excl = cell(size(s_all.i_sacc,1),1); % if dropped from calibration, why?
            
            % also want to store the raw coordinates
            s_all.i_sacc_raw = nan(size(s_all.i_sacc));
            s_all.f_sacc_raw = nan(size(s_all.f_sacc));
            
            s_all.i_sacc = nan(size(s_all.i_sacc));
            s_all.f_sacc = nan(size(s_all.f_sacc));
            
            
            s_all.i_sacc_err = nan(size(s_all.i_sacc,1),1);
            s_all.f_sacc_err = nan(size(s_all.f_sacc,1),1);
            
            s_all.n_sacc = nan(size(s_all.i_sacc,1),1); % how many saccades are there total? (in each epoch maybe?)
            s_all.n_sacc_epoch = nan(nblank,5); % TODO: fill this w/ n_trials x n_epochs (exclude ITI)
            
            s_all.i_sacc_rt = nan(nblank,1); % latency from go cue to each of these
            s_all.f_sacc_rt = nan(nblank,1);
            
            % maybe save out the traces? could be useful for making
            % figures...
            s_all.i_sacc_trace = cell(nblank,1);
            s_all.f_sacc_trace = cell(nblank,1);
            
            s_all.sel_targ  = nan(nblank,1); % which target was selected? (1 or 2)
            s_all.sel_coord = nan(nblank,2); % coords of selected target
            
            s_all.excl_trial = cell(nblank,1);  % why is this trial excluded? each cell includes several markers
            
        end
        
        thisidx = (1:this_cfg.numtrials)+(ii-1)*this_cfg.numtrials;
        
        % extract initial saccade (first saccade after go cue)
        
        
        % which saccades are we even considering? those that start and
        % end during epoch 4
        %which_sacc = find(this_sacc.epoch_start==resp_epoch & this_sacc.epoch_end==resp_epoch);
        which_sacc = find(ismember(this_sacc.epoch_start,RESP_EPOCH) & ismember(this_sacc.epoch_end,RESP_EPOCH));

        % TODO: maybe some other constraints - like duration/amp, etc?
        
        which_trials = this_sacc.trial_start(which_sacc);
        
        % loop over trials
        for tt = 1:this_cfg.numtrials
            
            % save the data from each channel from each trial
            for chan_idx = 1:length(save_chan)
                s_all.(save_chan{chan_idx}){thisidx(tt)} = this_data.(save_chan{chan_idx})(this_cfg.trialvec==tt);
            end
            
            % pick which coord (trialinfo(:,[2 3] or [4 5]) was responded
            % to
            thistarg = this_cfg.trialinfo(tt,6);
            if isnan(thistarg)
                thistarg = 1; % when nan, default to 1st coord, but make sure s_all.sel_targ remains nan(below)
            end
            this_coord = this_cfg.trialinfo(tt,[1 2]+1+(thistarg-1)*2); 
            clear thistarg; 
            s_all.sel_targ(thisidx(tt)) = this_cfg.trialinfo(tt,6); % intentionally save a NaN if necessary
            s_all.sel_coord(thisidx(tt),:) = this_coord;
            
            % TODO: reject trial if s_all.sel_targ == NaN
            
            
            % TODO: implement rejection of express saccades & small
            % initial saccades (init could be > 5 deg)
            
            
            % time that relevant epoch of trial started
            t_start = find(this_cfg.trialvec==tt & this_data.XDAT==RESP_EPOCH ,1,'first')/this_cfg.hz; %CHECK
            
            
            %this_i_sacc = which_sacc(find(which_trials==tt,1,'first'));
            this_i_sacc = which_sacc(which_trials==tt);
            
            
            % compute amplitude of each of these
            this_i_amp = this_sacc.amplitude(this_i_sacc);
            this_i_dur = this_sacc.duration(this_i_sacc);

            
            % if amplitude too small or duration too short (for ALL
            % saccades in response epoch
            
            % first, if no saccade detected (if i_sacc is empty),
            % record as "20" - no identified saccades (whatosever!)
            if isempty(this_i_sacc)
                s_all.excl_trial{thisidx(tt)}(end+1) = 20; % no saccades identified in response epoch
            elseif ~any(this_i_dur<=excl_criteria.i_dur_thresh & this_i_amp>=excl_criteria.i_amp_thresh)  % if none of the saccades pass the amplitude & duration criteria
                s_all.excl_trial{thisidx(tt)}(end+1) = 21; % none of the identified saccades (>0) passed exclusion criteria for primary saccade
            else
                % ok, now we can use the first of the saccades that do
                % pass exclusion criteria as the 'primary' saccade
                
                % find the first of this_i_sacc for which amp & dur
                % pass threshold
                this_i_sacc = this_i_sacc(this_i_amp>=excl_criteria.i_amp_thresh & this_i_dur <= excl_criteria.i_dur_thresh);
                
                % just index into the first element of this_i_sacc...
                s_all.i_sacc_raw(thisidx(tt),:) = [this_sacc.X_end(this_i_sacc(1)) this_sacc.Y_end(this_i_sacc(1))];
                s_all.i_sacc_rt(thisidx(tt)) = this_sacc.t(this_i_sacc(1),1)-t_start;
                s_all.i_sacc_trace{thisidx(tt)} = [this_sacc.X_trace{this_i_sacc(1)} this_sacc.Y_trace{this_i_sacc(1)}];
                
            end
            
            
            clear this_i_amp this_i_dur;
            
            
            % within relevant epoch, find first sacc, compute
            % - RT
            % - position
            % - adjusted position [[below]]
            % - error [[below]]
            
            % same for final sacc
            this_f_sacc = which_sacc(find(which_trials==tt,1,'last'));
            if ~isempty(this_f_sacc)
                s_all.f_sacc_raw(thisidx(tt),:) = [this_sacc.X_end(this_f_sacc) this_sacc.Y_end(this_f_sacc)];
                s_all.f_sacc_rt(thisidx(tt)) = this_sacc.t(this_f_sacc,1)-t_start;
                s_all.f_sacc_trace{thisidx(tt)} = [this_sacc.X_trace{this_f_sacc} this_sacc.Y_trace{this_f_sacc}];
            end

            
            % first saccade: primary
            
            % last saccade: final
            
            % so, I think we just need the length of i_sacc:f_sacc
            if ~isempty(this_i_sacc) && ~isempty(this_f_sacc)
                % in most cases, we'll identify both i_sacc & f_sacc -
                % use this algo
                s_all.n_sacc(thisidx(tt)) = length(this_i_sacc:this_f_sacc);
            else
                % if either of them is undefined (or both), this will
                % give us the # of saccades: 1 if only i_sacc or only
                % f_sacc, 0 if neither
                s_all.n_sacc(thisidx(tt)) = sum([~isempty(this_i_sacc) ~isempty(this_f_sacc)]);
            end

                      
            
            
            % store calibration, drift correction
            s_all.drift(thisidx(tt),:) = this_cfg.drift.amt(tt,:);
            s_all.calib(thisidx(tt),:) = this_cfg.calibrate.amt(tt,:);
            
            
            % ~~~~~ FIRST: exclude based on trial-level features (see above)
            
            % DRIFT CORRECTION TOO BIG
            if sqrt(sum(this_cfg.drift.amt(tt,:).^2)) > excl_criteria.drift_thresh
                s_all.excl_trial{thisidx(tt)}(end+1) = 11;
            end
            
            % CALIBRATION OUTSIDE OF RANGE
            if this_cfg.calibrate.adj(tt)~=1
                s_all.excl_trial{thisidx(tt)}(end+1) = 12;
                s_all.calib_excl{thisidx(tt)} = this_cfg.calibrate.excl_info{tt};
            end
            
            % DURING DELAY, FIXATION OUTSIDE OF RANGE
            
            % find fixations in this trial; epoch
            this_fix_idx = this_cfg.trialvec==tt & ismember(this_data.XDAT,FIX_EPOCH);
            %if max(sqrt(this_data.X_fix(this_fix_idx).^2+this_data.Y_fix(this_fix_idx).^2)) > excl_criteria.delay_fix_thresh || ...
            %    sum(sqrt(this_data.X(this_fix_idx).^2+this_data.Y(this_fix_idx).^2) > excl_criteria.delay_fix_thresh)*(1/this_cfg.hz) > excl_criteria.delay_raw_dur_thresh
            if max(sqrt(this_data.X_fix(this_fix_idx).^2+this_data.Y_fix(this_fix_idx).^2)) > excl_criteria.delay_fix_thresh
                s_all.excl_trial{thisidx(tt)}(end+1) = 13;
            end
            
            % TODO: also check if a total of 500 ms (or more) of X,Y
            % samples within that epoch are outside of range (same error
            % code)
            
            
            % ~~~~ SECOND: exclude based on primary saccade features
            % first, if there's no primary saccade found...
            
            if isempty(this_i_sacc)
                s_all.excl_trial{thisidx(tt)}(end+1) = 20;
            else
                
                % if either duration too long or amplitude too small
                % NOTE: deprecated now? i_sacc *must* be correct amp/dur
%                 if 1000*this_sacc.duration(this_i_sacc)  > excl_criteria.i_dur_thresh || ...
%                         this_sacc.amplitude(this_i_sacc) < excl_criteria.i_amp_thresh
%                     s_all.excl_trial{thisidx(tt)}(end+1) = 21;
%                 end
                
                % if error greater than i_err_thresh
                if sqrt(sum((s_all.i_sacc_raw(thisidx(tt),:)-this_coord).^2,2)) > ...
                        excl_criteria.i_err_thresh
                    s_all.excl_trial{thisidx(tt)}(end+1) = 22;
                end
            end
            
            % TODO: look for saccades that land back at fixation after
            % initial and before final - probably drop these trials...
            
            % TODO: exclude fixation-gaps that are not accompanied by pupil
            % gaps?
            
            clear this_i_sacc this_f_sacc;
            
        end
        
        
        
        
        % error for initial
        s_all.i_sacc_err(thisidx) = sqrt(sum((s_all.i_sacc_raw(thisidx,:)-s_all.sel_coord(thisidx,:)).^2,2));
        
        % error for final
        s_all.f_sacc_err(thisidx) = sqrt(sum((s_all.f_sacc_raw(thisidx,:)-s_all.sel_coord(thisidx,:)).^2,2));
        
        

        
        clear thisidx this_data this_cfg this_et this_sacc;
        
    end
    
    % for this, let's only find the cond = 3 trials and rotate them
    % according to the 'chosen' position; all others, can rotate to
    % position 1 (this has the advantage that plotting a spaital histogram
    % will show errors prominently)
    
    % first, cond = 1,2
    
    thisidx = ismember(thisbehav.c_all(:,1),[1 2]);
    % rotate all so that i_sacc, f_sacc are at known position...
    [tmpth,tmpr] = cart2pol(s_all.i_sacc_raw(thisidx,1),s_all.i_sacc_raw(thisidx,2));
    tmpth = tmpth - deg2rad(thisbehav.c_all(thisidx,2));
    [s_all.i_sacc(thisidx,1),s_all.i_sacc(thisidx,2)] = pol2cart(tmpth,tmpr);
    clear tmpth tmpr;
    
    [tmpth,tmpr] = cart2pol(s_all.f_sacc_raw(thisidx,1),s_all.f_sacc_raw(thisidx,2));
    tmpth = tmpth - deg2rad(thisbehav.c_all(thisidx,2));
    [s_all.f_sacc(thisidx,1),s_all.f_sacc(thisidx,2)] = pol2cart(tmpth,tmpr);
    clear tmpth tmpr thisidx;
    
    % now, cond 3 trials
    thisidx = find(thisbehav.c_all(:,1)==3);
    for tt = 1:length(thisidx)
        % rotate all so that i_sacc, f_sacc are at known position...
        thistarg = s_all.sel_targ(thisidx(tt));
        if isnan(thistarg) % handle trials that can't be unambiguously scored
            thistarg = 1;
        end
        [tmpth,tmpr] = cart2pol(s_all.i_sacc_raw(thisidx(tt),1),s_all.i_sacc_raw(thisidx(tt),2));
        tmpth = tmpth - deg2rad(thisbehav.c_all(thisidx(tt),1 + thistarg));
        [s_all.i_sacc(thisidx(tt),1),s_all.i_sacc(thisidx(tt),2)] = pol2cart(tmpth,tmpr);
        clear tmpth tmpr;
        
        [tmpth,tmpr] = cart2pol(s_all.f_sacc_raw(thisidx(tt),1),s_all.f_sacc_raw(thisidx(tt),2));
        tmpth = tmpth - deg2rad(thisbehav.c_all(thisidx(tt),1 + thistarg));
        [s_all.f_sacc(thisidx(tt),1),s_all.f_sacc(thisidx(tt),2)] = pol2cart(tmpth,tmpr);
        clear tmpth tmpr thistarg;
    end
    clear thisidx;
    
    %% find trials to exclude
    %  want to exclude based on:
    %  - eye position during target presentation (longest fix) deviates
    %    from [mode?] delay position by more than ??? DVA
    %  - any fixation longer than ??? ms outside of 3 DVA radius around
    %    fixation during delay
    %  - any primary saccade further than ? (5?) DVA from target
    %    position (maybe use the calib fields for this?)
    %  - [probably included in above] primary saccade occurs after
    %    target presentation
    %  - saccade duration longer than 150 ms is likely not useful
    %    (https://www.liverpool.ac.uk/~pcknox/teaching/Eymovs/params.htm)
    
    
    
    
    
    
    % append s_all to behavioral data file
    save(behav_fn,'s_all','excl_criteria','-append')
    
    clear s_all thisbehav behav_fn iEye_fn;
    
    
end




return
