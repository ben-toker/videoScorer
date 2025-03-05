function videoScorer()
    % Create the figure and UI components
    fig = figure('Name', 'Video Scorer', 'NumberTitle', 'off', ...
                 'Position', [100, 100, 800, 600]);

    % Load video
    [file, path] = uigetfile('*.avi', 'Select a Video File');
    if isequal(file, 0)
        disp('No file selected.');
        return;
    end
    vid = VideoReader(fullfile(path, file));

    % Initialize variables
    global behaviorLog currentFrame isPlaying scrubTimer scrubDirection scrubStartTime;
    behaviorLog = []; % Store frame and event type
    currentFrame = 1;
    isPlaying = false;
    scrubTimer = [];  % Timer for smooth scrubbing
    scrubDirection = 0;  % -1 for backward, 1 for forward
    scrubStartTime = 0;  % Tracks how long arrow key is held

    % Create UI elements
    ax = axes(fig, 'Position', [0.1, 0.3, 0.8, 0.6]); % Display video frame
    frameSlider = uicontrol(fig, 'Style', 'slider', ...
        'Min', 1, 'Max', vid.NumFrames, 'Value', 1, ...
        'Units', 'normalized', 'Position', [0.1, 0.2, 0.8, 0.05], ...
        'Callback', @updateFrame);
    addlistener(frameSlider, 'Value', 'PostSet', @updateFrame);

    % Buttons for coding behaviors
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Conspecific Approaching Subject (1)', ...
        'Units', 'normalized', 'Position', [0.05, 0.1, 0.4, 0.08], ...
        'Callback', @(~,~) logBehavior(1));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Subject Approaching Conspecific (2)', ...
        'Units', 'normalized', 'Position', [0.5, 0.1, 0.4, 0.08], ...
        'Callback', @(~,~) logBehavior(2));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Nose to Nose Sniff (3)', ...
        'Units', 'normalized', 'Position', [0.05, 0.02, 0.3, 0.08], ...
        'Callback', @(~,~) logBehavior(3));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Conspecific Sniff Subject (4)', ...
        'Units', 'normalized', 'Position', [0.37, 0.02, 0.3, 0.08], ...
        'Callback', @(~,~) logBehavior(4));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Subject Sniff Conspecific (5)', ...
        'Units', 'normalized', 'Position', [0.69, 0.02, 0.3, 0.08], ...
        'Callback', @(~,~) logBehavior(5));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save Data', ...
        'Units', 'normalized', 'Position', [0.75, 0.85, 0.2, 0.08], ...
        'Callback', @saveData);

    % Set up keyboard shortcuts
    set(fig, 'WindowKeyPressFcn', @keyPressHandler);
    set(fig, 'WindowKeyReleaseFcn', @keyReleaseHandler);

    % Display the first frame
    updateFrame();

    % Keyboard Event Handlers
    function keyPressHandler(~, event)
        switch event.Key
            case 'space'  % Play/Pause video
                isPlaying = ~isPlaying;
                if isPlaying
                    playVideo();
                end

            case 'leftarrow'  % Start moving backward
                startScrubbing(-1);

            case 'rightarrow'  % Start moving forward
                startScrubbing(1);

            case {'1', '2', '3', '4', '5'}  % Log behavior
                logBehavior(str2double(event.Key));
        end
    end

    function keyReleaseHandler(~, event)
        if any(strcmp(event.Key, {'leftarrow', 'rightarrow'}))
            stopScrubbing();
        end
    end

    % Play video at 30 FPS
    function playVideo()
        targetFPS = 30;
        frameTime = 1 / targetFPS;

        while isPlaying && currentFrame < vid.NumFrames
            tic;  % Start timer

            currentFrame = currentFrame + 1;
            set(frameSlider, 'Value', currentFrame);
            updateFrame();

            elapsed = toc;  % Get elapsed time
            remainingTime = frameTime - elapsed;
            if remainingTime > 0
                pause(remainingTime);  % Keep timing consistent
            end

            drawnow;  % Ensure UI updates properly
        end
        isPlaying = false;  % Stop when reaching the last frame
    end

    % Smooth Scrubbing with Progressive Acceleration
    function startScrubbing(direction)
        scrubDirection = direction;  % Set scrub direction
        scrubStartTime = tic;  % Reset timer for key hold duration

        % If timer already exists, don't start a new one
        if ~isempty(scrubTimer) && isvalid(scrubTimer)
            return;
        end

        % Create a new timer for smooth scrubbing with acceleration
        scrubTimer = timer('ExecutionMode', 'fixedSpacing', ...
                           'Period', 1/30, ... % 30 FPS baseline tick rate
                           'TimerFcn', @advanceFrame);
        start(scrubTimer);
    end

    function stopScrubbing()
        scrubDirection = 0;  % Stop movement
        
        if ~isempty(scrubTimer) && isvalid(scrubTimer)
            stop(scrubTimer);
            delete(scrubTimer);
            scrubTimer = [];
        end
    end

    function advanceFrame(~, ~)
        if scrubDirection == 0  % If no direction, stop
            return;
        end
        
        % Calculate acceleration factor based on how long the key is held.
        % Increased multiplier (5 instead of 2) so the speed ramps up more noticeably.
        timeHeld = toc(scrubStartTime);
        scrubSpeed = min(1 + floor(timeHeld * 5), 10);  % Max speed = 10x normal
        
        % Move frames based on current acceleration
        newFrame = currentFrame + scrubDirection * scrubSpeed;
        
        % Keep frame within valid range
        if newFrame >= 1 && newFrame <= vid.NumFrames
            currentFrame = newFrame;
            set(frameSlider, 'Value', currentFrame);
            updateFrame();
        end
    end

    % Update the displayed frame
    function updateFrame(~, ~)
        currentFrame = round(get(frameSlider, 'Value'));
        vid.CurrentTime = (currentFrame - 1) / vid.FrameRate;
        frame = read(vid, currentFrame);  % Read frame correctly
        imshow(frame, 'Parent', ax);
        title(ax, sprintf('Frame: %d', currentFrame));
    end

    % Log behavior
    function logBehavior(eventType)
        behaviorLog = [behaviorLog; currentFrame, eventType];
        disp(['Logged event ', num2str(eventType), ' at frame ', num2str(currentFrame)]);
    end

    % Save behavior log
    function saveData(~, ~)
        if isempty(behaviorLog)
            disp('No data to save.');
            return;
        end
        savePath = fullfile(path, 'behavior_data.csv');
        writematrix(behaviorLog, savePath);
        disp(['Data saved to ', savePath]);
    end
end
