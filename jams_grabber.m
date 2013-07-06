%% Lousy script to extract traffic information

%%
prjDir = pwd;
%'/home/dmitry/yandex/' works for linux

% This is for GE plotting and wont work in Linux
addpath('D:\Dropbox\Work\Projects\Matlabing\GoogleEarth Toolbox');
ge_out = [];

%%
% This is the only thing that should be hardcoded for each city
% Chages may be needed for non-round cities (efficiency)
% Kremlin-centered URL for yandex maps
% http://maps.yandex.ru/?ll=37.617671%2C55.755768&spn=1.750946%2C0.414321&z=10&l=map%2Ctrf&trfm=cur
% TODO: explore options to do it via yandex or google search string and local cahce
% the only thing that really should be changed by hand is z and the city
% name
z=10; 
refX = 309; refY = 160;
centerLat = 55.755768; centerLon = 37.617671;

%%
% the rule between tile length and z is as simple as that:
% 1 - each zoom in divides 1 tile into 4 and vice versa
% 2 - when z=9, the tile side is 44 km long
tileLen = 44 * 2^(9-z); % in km basically

% If z is odd, the map center is between four tiles, 
% if z is even, the map center is in the center of one tile
centerX = refX * 2^(z-9) + 0.5*(rem(z,2) == 0); centerY = refY * 2^(z-9) + 0.5*(rem(z,2) == 0);

% This span is OK, but can be optimized: for coarse resolution it is too big, 
% for fine it is too small 
span = 2^(z-9);

% Loop for tiles grabbing and analysis
for x = ceil(centerX-span):floor(centerX+span)
    for y = ceil(centerY-span):floor(centerY+span)
        
        % Form the wget string and download the tile
        wgetBase = '"http://jgo.maps.yandex.net/1.1/tiles?l=trf&lang=ru_RU&';
        wgetEnding = 'tm=1372673624"';
        wgetX = ['x=' num2str(x, '%2.3i') '&']; %618
        wgetY = ['y=' num2str(y, '%2.3i') '&']; %312
        wgetZ = ['z=' num2str(z, '%2.3i') '&'];
        wgetString = [wgetBase wgetX wgetY wgetZ wgetEnding];
        
        % System-dependent wget call
        if(strfind(computer, 'WIN'))
            system([fullfile(prjDir, 'wget.exe') ' -q -O ' fullfile(prjDir, 'tiles', ['tile_' num2str(x, '%2.3i') '_' num2str(y, '%2.3i') '.png'] ...
                ) ' ' wgetString]);
        else
            system(['wget -q -O ' fullfile(prjDir, 'tiles', ['tile_' num2str(x, '%2.3i') '_' num2str(y, '%2.3i') '.png'] ...
                 ) ' ' wgetString]);
        end
        
        % Got the file, grab the image and divide it by colors
        tp = (imread(fullfile(prjDir, 'tiles', ['tile_' num2str(x, '%2.3i') '_' num2str(y, '%2.3i') '.png']), 'png'));
        tp_r = (squeeze(tp(:,:,1)));
        tp_g = (squeeze(tp(:,:,2)));
        tp_b = (squeeze(tp(:,:,3)));
        
        % Get the coordinates for the current tile
        % The cases are different for different elevationtypes: even and odd issue again
        % TODO: rewrite to a readable version
        % TODO: take into account the ellipsoid instead of a sphere as in km2deg
        if((rem(z,2) == 0))
            lat1 = centerLat + round(centerY-y)*km2deg(tileLen) - sign(centerY-y)*km2deg(tileLen);
            lat2 = centerLat + round(centerY-y)*km2deg(tileLen);
            lon1 = centerLon + round(x-centerX)*km2deg(tileLen) - sign(x-centerX)*km2deg(tileLen);
            lon2 = centerLon + round(x-centerX)*km2deg(tileLen);
        else
            lat1 = centerLat + (sign((centerY-y))-(centerY==y))*abs(km2deg(tileLen/2+tileLen*(abs(centerY-y)-1)));
            lat2 = centerLat + (sign((centerY-y))+(centerY==y))*abs(km2deg(tileLen/2 + tileLen*abs(centerY-y)));
            lon1 = centerLon + (sign((x-centerX))-(centerX==x))*abs(km2deg(tileLen/2+tileLen*(abs(x-centerX)-1)));
            lon2 = centerLon + (sign((x-centerX))+(centerX==x))*abs(km2deg(tileLen/2 + tileLen*abs(x-centerX)));
        end
        
        % Latitude is inverted since it has inverted direction with y
        lat = linspace(max(lat1, lat2), min(lat1, lat2), size(tp, 1));
        lon = linspace(min(lon1, lon2), max(lon1, lon2), size(tp, 2));
            
        % Yandex traffic colors are indexed badly which is likely a trick. 
        % TODO: play around with colors indexing
        indGreen = tp_g <= 240 & tp_g >= 150 & tp_r <=150; % more or less
        indYellow = tp_g <= 210 & tp_g >= 170 & tp_r <= 255 & tp_r >= 210 & tp_b < 10; % revision needed
        indRed = tp_g <= 100 & tp_b <= 100 & tp_r >=240; % more or less
        indDarkRed = []; % Not reviewed
        indBlocked = []; % Not reviewed
                
        % debugging plot with a white background
        resPicR = ones(size(tp_r)); resPicG = resPicR; resPicB = resPicG;
        resPicR(indRed) = 1; resPicG(indRed) = 0; resPicB(indRed) = 0;
        resPicR(indGreen) = 0; resPicG(indGreen) = 1; resPicB(indGreen) = 0;
        resPicR(indYellow) = 1; resPicG(indYellow) = 1; resPicB(indYellow) = 0;
        resPic = zeros(size(tp)); 
        resPic(:,:,1) = resPicR; resPic(:,:,2) = resPicG; resPic(:,:,3) = resPicB;
        %figure(z); hold on; imagesc(lon, lat, resPic); xlim([centerLon-0.4 centerLon+0.4]); ylim([centerLat-0.4 centerLat+0.4]); 
        
        % GoogleEarth output
        
        imgForGE = rgb2ind(resPic, 65000);
        alphaMatrix = imgForGE; alphaMatrix(alphaMatrix == 0) = 1;
        alphaMatrix(alphaMatrix == 1) = 0;
        ge_output(fullfile(prjDir, 'GoogleEarth', ['ge_plotting_' num2str(x, '%2.3i') '_' num2str(y, '%2.3i') '.kml']),...
            ge_imagesc(lon, lat, double(imgForGE)));
        
    end
end

%ge_output('ge_plotting.kml', ge_out);