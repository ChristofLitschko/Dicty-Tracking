%-------------------------------------------------------------------------%
% DICTY TRACKING v1.3
%-------------------------------------------------------------------------%
% by Christof Litschko (litschko.christof@gmail.com)
%-------------------------------------------------------------------------%

% The follwoing MATLAB code allows semi-automatic tracking of
% randomly migrating D.discoideum cells from phase contrast time-lapse
% image series. The code works with 8- and 16-bit TIFF stacks. 
% 
% In step 1 cells are automatically detected by binarization
% using the sobel edge detector. Parameters for detection can be adjusted
% manually. In a second step the user has the opportunity to select cells
% for tracking and exclude for example diving or colliding cells from
% automatic tracking.
% Tracking of the selected cells over time is achived by connecting the
% closest detected object compared to the previous frame.
% The code outputs a TIFF stack with labeled tracked cells and trajectories
% in different colors and an excel sheet containing the position of each
% tracked cell at each timepoint.
% 
%
%% --- STEP (1): IDENTIFICATION OF CELLS AND EXTRACTION OF CENTROIDS ---

clc
close all
clear all

CreateStruct.WindowStyle='replace';
CreateStruct.Interpreter='tex';
h = msgbox({'\bfDICTY TRACKING', '', 'MATLAB-based tool for semi-automatic tracking of migrating Dictyostelium cells from phase contrast time-lapse image series.', '', '---------------------------------------------------------------------------','', 'developed by', 'Christof Litschko', 'Institute for Biophysical Chemistry', 'Lab of Prof. Dr. Jan Faix (Cytoskeleton Dynamics)', 'Hannover Medical School (MHH), Germnay', 'Email: litschko.christof(at)gmail.com, faix.jan(at)mh-hannover.de', '', '', 'Copyright (C) 2017 Christof Litschko', 'The code of this software and associated files are licensed under the MIT license. Visit https://opensource.org/licenses/MIT to view a copy of the license.', '', '---------------------------------------------------------------------------', '', 'Press "OK" to start DICTY TRACKING!', ''}, 'DICTY TRACKING', 'modal', CreateStruct);
waitfor(h);

% --- open user interface for file selection ---
[filename] = uigetfile('*.*', 'DICTY TRACKING | Select TIFF stack for analysis');

% --- open window to enter pixelsize and threhsold ---
prompt = {'threshold for binarization:', '1st dilation parameter:', '1st erosion parameter:', 'threshold for halo removal:', '2nd dilation parameter:', '2nd erosion paramter', 'area threshold (px):'};
dlg_title = 'DICTY TRACKING | Parameters for cell detection';
num_lines = [1 65];
defaultans ={'', '', '', '', '', '', ''};
answer = inputdlg(prompt, dlg_title, num_lines, defaultans, 'on');
threshfactor = str2num(answer{1});
se1_size = str2num(answer{2});
se2_size = str2num(answer{3});
halothresh = str2num(answer{4});
se1_size2 =str2num(answer{5});
se2_size2 = str2num(answer{6});
areathresh = str2num(answer{7});

% --- generate a waitbar ---
c=waitbar(0, {'Cell detection is running. Please wait...'}, 'Name', 'DICTY TRACKING | Step 1 of 4');

%--- saving of cell detection parameters to xls. file ---
params={'threshold for binarization:', answer{1}; '1st dilation parameter:', answer{2}; 'erosion parameter:', answer{3}; 'threshold for halo removement:', answer{4}; '2nd dilation parameter:', answer{5}; '2nd erosion parameter:', answer{6}; 'area threshold (px):', answer{7}; 'tracked with version:', '1.3'}; 
[~,name,~] = fileparts(filename);
params_filename = [name '_params' '.xls'];
xlswrite(params_filename, params);


% --- determine the number of frames of the selected image stack ---
info = imfinfo(filename);
num_images = numel(info);

map=gray(256);
preview_filename = [name '_cell detection' '.tif'];

% --- framewise detection of cells and extraction of position data ---
for k = 1:num_images
    % --- load the current frame k ---
    I = imread(filename, k);

    % --- (1) edge detection and binarization using the Sobel operator ---
    threshold=graythresh(I);
    BW = edge(I,'sobel', threshold * threshfactor);
    BWs.(sprintf('BW%d', k))=BW;

    % --- (2) dilation of detected shapes using a linear structuring element ---
    se1_90=strel('line', se1_size, 90);
    se1_60=strel('line', se1_size, 60);
    se1_30=strel('line', se1_size, 30);
    se1_0=strel('line', se1_size, 0);
    BW2=imdilate(BW, [se1_90 se1_60 se1_30 se1_0]);

    % --- (3) fill holes ---
    BW3=imfill(BW2, 'holes');

    % --- (4) erode shapes ---
    se2=strel('disk', se2_size);
    BW4=imerode(BW3, se2);

    % --- (5) halo removement: set bright pixels of halo to zero in binary image BW6 ---
    halopix=find(I>halothresh);
    BW5=BW4;
    BW5(halopix)=0;

    % --- (6) dilation after halo removement ---
    se1_90=strel('line', se1_size2, 90);
    se1_60=strel('line', se1_size2, 60);
    se1_30=strel('line', se1_size2, 30);
    se1_0=strel('line', se1_size2, 0);
    BW6=imdilate(BW5, [se1_90 se1_60 se1_30 se1_0]);

    % --- (7) filling ---
    BW7=imfill(BW6, 'holes');
    
    % --- (8) 2nd erosion ---
    se2=strel('disk', se2_size2);
    BW8=imerode(BW7, se2);
    
    % --- (9) remove small areas and save resulting BW8 in the structure array BW8s ---
    LM8=bwlabel(BW8);
    stats8=regionprops(LM8,'area', 'centroid');
    too_small=find([stats8.Area]<areathresh);
    PL=regionprops(LM8,'PixelIdxList');
    BW9=BW8;
    for i=1:length(too_small)
        BW9(PL(too_small(i)).PixelIdxList)=0;
    end
    BW9s.(sprintf('BW9_%d', k))=BW8;

    % --- label all regions (cells) in the final BW8 of each frame and determine their centroids ---
    % --- save to structure arrays LM8s and stats8s ---
    LM9 = bwlabel(BW9);
    LM9s.(sprintf('LM9_%d', k))=LM8;
    stats9=regionprops(LM9,'centroid');
    stats9s.(sprintf('stats9_%d', k))=stats9;
    
    
    BW9_uint8=im2uint8(BW9);
    I_uint8=im2uint8(I);
    [rows cols]=size(I);
    spacer=ones(3,cols);
    spacer_uint8=im2uint8(spacer);
    im = [I_uint8; spacer_uint8; BW9_uint8];
    imwrite(im, preview_filename, 'WriteMode','append');    
        
    % --- actualize waitbar ---
    waitbar(k / num_images)
end

% --- close waitbar and clear all variables except ... ---
F = findall(0,'type','figure','tag','TMWWaitbar');
delete(F);


%% --- STEP (2): SELECT CELLS TO TRACK ---


clearvars -except num_images stats9s filename

% --- open the first frame of the selected TIFF stack and start the getpoints function to select cells ---
iptsetpref('ImshowBorder','loose');
I_first=imread(filename, 1);
figure('Name', 'DICTY TRACKING | Cell Selection Window', 'NumberTitle','off'), imshow(I_first), title('Click all trackable cells in the image below and press "Enter" when finished.');
CreateStruct.WindowStyle='replace';
CreateStruct.Interpreter='tex';
h = msgbox({'\bfInstructions for Step 2:', 'Control of Cell Detection & Selection of Cells for Tracking', '', '', 'Please open the "...\_cell detection.tif" stack with FIJI/ImageJ to check for appropriate cell detection. If cells were detected well, please click on all non-colliding and non-dividing cells in the Cell Selection Window and press "Enter" to start tracking.', 'If cell detection was not sufficient, please just close the Cell Selection Window, delete the "...\_cell detection.tif" stack (important step!) and restart DICTY TRACKING to adjust detection paramters.', ''}, 'DICTY TRACKING | Step 2 of 4', 'modal', CreateStruct);
waitfor(h);
[to_track_Xs to_track_Ys]= getpts;

close all force


%% --- STEP (3): TRACKING OF SELECTED CELLS ---

clearvars -except num_images stats9s filename to_track_Xs to_track_Ys

% --- load x and y coordinates of all identified cell centroids in frame 1 ---
k=1;
first_stats9=getfield(stats9s, sprintf('stats9_%d', k));
first_Cens = cat(1, first_stats9.Centroid);
first_Cens_Xs = first_Cens(:,1);
first_Cens_Ys = first_Cens(:,2);

% --- calculate euclidian distance between all selected cells and all identified cell centroids ---
for i=1:length(to_track_Xs)
        X=to_track_Xs(i,1);
        Y=to_track_Ys(i,1);
        for j=1:length(first_Cens)
            first_X=first_Cens_Xs(j,1);
            first_Y=first_Cens_Ys(j,1);
            dists(j,i)=sqrt((first_Y - Y)^2 + (first_X - X)^2); %size of matrix dists changes over time
            %dists: colums=centroids of curr frame rows=distances to
            %centroids in next frame
        end
end
clear i


% --- assign selected cells and corresponding centroids by minimal distance and write them "tracks" structure ---
[~, dists_mins]=min(dists);
for i=1:length(to_track_Xs)
    min=dists_mins(1,i);
    data_X=first_Cens_Xs(min,1);
    data_Y=first_Cens_Ys(min,1);
    tracks.(sprintf('cell_%d', i))(k,1)= data_X;
    tracks.(sprintf('cell_%d', i))(k,2)= data_Y;
end

clearvars -except num_images stats9s filename tracks to_track_Xs to_track_Ys


% --- do the same for all consecutive frames ---
for k=2:num_images
    
    % --- load x and y coordinates of all identified cell centroids in current frame --- 
    curr_stats9=getfield(stats9s, sprintf('stats9_%d', k));
    curr_Cens = cat(1, curr_stats9.Centroid);
    curr_Cens_Xs = curr_Cens(:,1);
    curr_Cens_Ys = curr_Cens(:,2);
    
    % --- load centroids of selected cells to track from last frame ---
    for i=1:length(to_track_Xs)
        last_Cens = getfield(tracks, sprintf('cell_%d', i));
        last_Cens_Xs(i,1)=last_Cens(k-1,1);
        last_Cens_Ys(i,1)=last_Cens(k-1,2);
        % --- saving of centroids of track cells from last frame for later image generation in step (4) ---
        Cens = [last_Cens_Xs last_Cens_Ys];
        frames.(sprintf('frame_%d', k-1))=Cens;
    end
    clear i
    
    % --- calculate euclidian distance between centroids of cells to track from last frame and centroids of this frame ---
    for i=1:length(to_track_Xs)
        X=last_Cens_Xs(i,1);
        Y=last_Cens_Ys(i,1);
        for j=1:length(curr_Cens)
            curr_X=curr_Cens_Xs(j,1);
            curr_Y=curr_Cens_Ys(j,1);
            dists(j,i)=sqrt((curr_Y - Y)^2 + (curr_X - X)^2); %size of matrix dists changes over time
            %dists: colums=centroids of curr frame rows=distances to
            %centroids in next frame
        end
    end
    clear i
    
    % --- assign cells to track and corresponding centroids by minimal distance and write them into "tracks" structure ---    
    [~, dists_mins]=min(dists);
    for i=1:length(to_track_Xs)
        min=dists_mins(1,i);
        data_X=curr_Cens_Xs(min,1);
        data_Y=curr_Cens_Ys(min,1);
        tracks.(sprintf('cell_%d', i))(k,1)= data_X;
        tracks.(sprintf('cell_%d', i))(k,2)= data_Y;
    end
    clear i
            
    clearvars -except num_images stats9s filename tracks to_track_Xs to_track_Ys k frames

    end
clear k

% --- save also centroids of last frame to struct "frames" ---
k=num_images;
for i=1:length(to_track_Xs)
    last_Cens = getfield(tracks, sprintf('cell_%d', i));
    last_Cens_Xs(i,1)=last_Cens(k,1);
    last_Cens_Ys(i,1)=last_Cens(k,2);
    % --- saving of centroids of track cells from last frame for later image generation in step (4) ---
    Cens = [last_Cens_Xs last_Cens_Ys];
    frames.(sprintf('frame_%d', k))=Cens;
end

%% --- STEP (4): GENERATION OF TIFF STACK WITH HIGHLGHTED TRACKED CELLS ---


clearvars -except num_images BW8s LM8s stats9s tracks to_track_Xs frames filename

c=waitbar(0,'Generation of TIFF stack with trajectories. Please wait...', 'Name', 'DICTY TRACKING | Step 3 of 4');

colors=['b' 'g' 'r' 'c' 'm' 'y'];

[~,name,~] = fileparts(filename);
trackedname=[name '_' 'tracks' '.tif'];


for k=1:num_images
% --- load current frame ---
I=imread(filename, k);
Imin=min(min(I));
Imax=max(max(I));

% --- load coordinates of cell markers in current frame from "frames" struct ---
Cell_points = getfield(frames, sprintf('frame_%d', k));

% --- assemble x and y coordinates and set marker size for scatter plotting of cell markers ---
Xs = Cell_points(:,1);
Ys = Cell_points(:,2);
sz=25;

% --- create invisible figure without borders ---
figure('visible', 'off')
iptsetpref('ImshowBorder','tight');
imshow(I, [Imin, Imax]);
hold on

% --- plot current cell markers onto figure using scatter function ---
%scatter(Xs, Ys, sz, 'magenta', 'filled');

% --- plot track of each cell onto image ---
for i=1:length(Cell_points)
    cidx = mod(i,length(colors))+1;
    Track_points = getfield(tracks, sprintf('cell_%d', i));
    curr_Track_points_Xs = Track_points(1:k,1);
    curr_Track_points_Ys = Track_points(1:k,2);
    plot(curr_Track_points_Xs, curr_Track_points_Ys, 'color', colors(cidx), 'LineWidth', 1.5);
end
clear curr_Track_points_Xs curr_Track_points_Ys

% --- plot cell numbers onto figure ---
for i=1:length(Cell_points)
    cidx = mod(i,length(colors))+1;
    cellnum=num2str(i);
    text(Cell_points(i,1), Cell_points(i,2)-30, cellnum, 'color', colors(cidx), 'FontSize', 12, 'FontWeight', 'bold')
end

% --- pause for 0.7 sec and make screenshot from marked figure ---
pause('on');
pause(0.5);
I_screen = getframe(gcf);

% --- generate file name for marked figure and save it ---
imwrite(I_screen.cdata, trackedname, 'WriteMode','append');

close all
waitbar(k / num_images)
end

% --- close waitbar ---
F = findall(0,'type','figure','tag','TMWWaitbar');
delete(F);


%% --- STEP (5): EXPORT OF TRACKING DATA AND PARAMETERS ---


clearvars -except num_images stats9s tracks to_track_Xs frames filename name

% --- open window to enter pixelsize and threhsold ---
prompt = {'time interval:', 'time unit:', 'pixelsize:', 'unit:'};
dlg_title = 'DICTY TRACKING | Parameters for data export';
num_lines = [1 65];
defaultans ={'', 's', '', '�m'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans,'on');
time_int = str2num(answer{1});
time_unit = answer{2};
px_size = str2num(answer{3});
unit = answer{4};

c=waitbar(0,'Export of track data. Please wait...', 'Name', 'DICTY TRACKING | Step 4 of 4');

% --- generate column (1): "track ID"  ---
all_track_IDs = [];
for i=1:length(to_track_Xs)
    for k=1:num_images
       curr_ID = i;
       all_track_IDs = vertcat(all_track_IDs, curr_ID);
    end
end

waitbar(1 / 11)

% --- generate column (2): "frame" ---
frame_nums = [];
for i=1:length(to_track_Xs)
    for k=1:num_images
       curr_frame = k;
       frame_nums = vertcat(frame_nums, curr_frame);
    end
end

waitbar(2 / 11)

% --- generate column (3): "time" ---
last_timept = (num_images-1)*time_int;
time = transpose(linspace(0,last_timept,num_images));
all_time = [];
for i=1:length(to_track_Xs)
    all_time = vertcat(all_time, time);
end
    clear last_timept
    clear time

waitbar(3 / 11)    
    
% --- generate columns (4) & (5): "X" and "Y" in �m ---
all_tracks_XsYs = [];
for i=1:length(to_track_Xs)
    currtrack = getfield(tracks, sprintf('cell_%d', i)) * px_size; %�m calculation
    all_tracks_XsYs=vertcat(all_tracks_XsYs, currtrack);
end
    clear currtrack

waitbar(4 / 11)    
    
% --- generate column (6): "D2P" (distance between consecutive points, stepsize) in �m ---
stepsize = [];
for i=1:length(to_track_Xs)
    % --- for first frame, step size is not a number (NaN) ---
    k=1;
    curr_stepsize = NaN;
    stepsize=vertcat(stepsize, curr_stepsize);
    % --- generate struct array "stepsize2" for later calculation of track length ---
    stepsize2.(sprintf('cell_%d', i))(1,1)= curr_stepsize;
    clear k
    clear curr_stepsize
    curr_cell = getfield(tracks, sprintf('cell_%d', i));
    % --- calculation of euclidian distance between current and previous point of track ---
    for k=2:num_images
        curr_X = curr_cell(k,1);
        prev_X = curr_cell(k-1, 1);
        curr_Y = curr_cell(k,2);
        prev_Y = curr_cell(k-1, 2);
        curr_stepsize=sqrt((curr_X - prev_X)^2 + (curr_Y - prev_Y)^2) * px_size;
        stepsize=vertcat(stepsize, curr_stepsize);
        % --- generate struct array "stepsize2" for later calculation of track length ---
        stepsize2.(sprintf('cell_%d', i))(k,1)= curr_stepsize;
    end
end
    clear curr_stepsize curr_cell curr_X prev_X curr_Y prev_Y

waitbar(5 / 11)   
    
% --- generate column (7): "Len" (length of track) in �m ---
Len = [];
for i=1:length(to_track_Xs)
    % --- for first frame, length of whole track is zero ---
    k=1;
    curr_Len = 0;
    Len=vertcat(Len, curr_Len);
    clear k
    clear curr_Len
    curr_cell = getfield(stepsize2, sprintf('cell_%d', i));
    % --- calculation of euclidian distance between current and previous point of track ---
    for k=2:num_images
        curr_Len = sum(curr_cell(2:k));
        Len=vertcat(Len, curr_Len);
    end
end
    clear curr_Len

waitbar(6 / 11)    
    
% --- generate column (8): "D2S" (direct distance to start, beeline) in �m ---
D2S = [];
for i=1:length(to_track_Xs)
    % --- for first frame, step size is not a number (NaN) ---
    k=1;
    curr_D2S = 0;
    D2S=vertcat(D2S, curr_D2S);
    clear k
    clear curr_D2S
    curr_cell = getfield(tracks, sprintf('cell_%d', i));
    % --- calculation of euclidian distance between current and previous point of track ---
    for k=2:num_images
        curr_X = curr_cell(k,1);
        start_X = curr_cell(1,1);
        curr_Y = curr_cell(k,2);
        start_Y = curr_cell(1,2);
        curr_D2S=sqrt((curr_X - start_X)^2 + (curr_Y - start_Y)^2) * px_size;
        D2S=vertcat(D2S, curr_D2S);
    end
end
    clear curr_cell curr_X curr_Y start_X start_Y curr_D2S

waitbar(7 / 11)    
    
% --- generate column (9): "v" (instantaneous velocity) in �m/time unit ---
v = [];
for i=1:length(to_track_Xs)
    % --- for first frame, step size is not a number (NaN) ---
    k=1;
    curr_v = NaN;
    v = vertcat(v, curr_v);
    clear k
    clear curr_stepsize
    curr_cell = getfield(stepsize2, sprintf('cell_%d', i));
    % --- calculation of euclidian distance between current and previous point of track ---
    for k=2:num_images
        curr_v = curr_cell(k,1) / time_int;
        v=vertcat(v, curr_v);
    end
end
    clear curr_cell curr_v

waitbar(8 / 11)
    
% --- generate column (10) & (11) & (13): "inst. angle", "turning angle" & "cos(turning angle)" ---
% --- calculate instantaneous angle ---
instangle = [];
for i=1:length(to_track_Xs)
    % --- for first frame angle can not be calculated due to it's definition ---
    curr_instangle = NaN;
    instangle = vertcat(instangle, curr_instangle);
    instangle2.(sprintf('cell_%d', i))(1,1)= curr_instangle;
    curr_cell = getfield(tracks, sprintf('cell_%d', i));
    for k=2:num_images
        % --- load x,y coordinates of current and previous position ---
        curr_X = curr_cell(k,1);
        curr_Y = curr_cell(k,2);
        prev_X = curr_cell(k-1,1);
        prev_Y = curr_cell(k-1,2);
        % --- calculate angle --
        curr_instangle = atand((curr_Y-prev_Y)/(curr_X-prev_X));
        instangle = vertcat(instangle, curr_instangle);
        instangle2.(sprintf('cell_%d', i))(k,1)= curr_instangle;
    end
end
    clear curr_X curr_Y prev_X prev_Y curr_cell curr_instangle

% --- calculate turning angle and it's cosine ---
turnangle = [];
cosine = [];
for i=1:length(to_track_Xs)
    % --- turnangle not defined for first two timepoints ---
    curr_turnangle = NaN;
    turnangle = vertcat(turnangle, curr_turnangle);
    turnangle = vertcat(turnangle, curr_turnangle);
    curr_cosine = NaN;
    cosine = vertcat(cosine, curr_cosine);
    cosine = vertcat(cosine, curr_cosine);
    % --- calculate turning angle for frames 3...end ---
    curr_cell = getfield(instangle2, sprintf('cell_%d', i));
    for k=3:num_images
       curr_instangle = curr_cell(k,1);
       prev_instangle = curr_cell(k-1,1);
       curr_turnangle = curr_instangle - prev_instangle;
       turnangle = vertcat(turnangle, curr_turnangle);
       curr_cosine = cosd(curr_turnangle);
       cosine = vertcat(cosine, curr_cosine);
    end
end

waitbar(9 / 11)

%--- combine the columns and prepare for excel export ---
export = [all_track_IDs frame_nums all_time all_tracks_XsYs stepsize Len D2S v instangle turnangle cosine];
export2 = num2cell(export);
col_time = ['time (' time_unit ')'];
col_x = ['x (' unit ')'];
col_y = ['y (' unit ')'];
col_D2pP = ['D2pP (' unit ')'];
col_Len = ['Len (' unit ')'];
col_D2S = ['D2S (' unit ')'];
col_v = ['v (' unit '/' time_unit ')'];
col_header={'track', 'frame', col_time, col_x, col_y, col_D2pP, col_Len, col_D2S, col_v, 'inst. angle', 'turning angle', 'cos(turn. angle)'};
output=vertcat(col_header, export2);
clear export export2 col_time col_x col_y col_D2pP col_Len col_D2S col_v

waitbar(10 / 11)

% --- generate file name and save output as .xls file ---
[~,name,~] = fileparts(filename);
xlsname = [name '_' 'track data' '.xls'];
xlswrite(xlsname, output);

waitbar(11 / 11)

clearvars -except num_images BW9s LM9s output stats9s

% --- close waitbar ---
F = findall(0,'type','figure','tag','TMWWaitbar');
delete(F);

% --- open current directory ---
CreateStruct.WindowStyle='replace';
CreateStruct.Interpreter='tex';
h = msgbox({'\bfCell tracking completed. Open "...\_tracks.tif" with FIJI/ImageJ to check tracking results.', ''}, 'DICTY TRACKING', CreateStruct);
waitfor(h)
%dos(['explorer ' pwd]);