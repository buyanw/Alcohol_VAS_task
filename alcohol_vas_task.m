function alcohol_vas_task
% Alcohol cue VAS rating task (MATLAB + Psychtoolbox)
% 三个子文件夹：self_alcohol/  GAPED/  others_alcohol/
% 列：trial_num, image_id, library, urge, valence, arousal, onset_time, rt_urge, rt_valence, rt_arousal
% 新增：被试ID/场次ID输入、分块休息（blockSize） 

%% -------------------- USER SETTINGS --------------------
% 根目录与子目录
baseDir    = pwd; % ← 修改为你的根目录
subfolders = {'Gemini3_alcohol_12.25resize','GAPED_neutral_resized','WFAIS_alcohol_resized','ABPS_alcohol'   };
outDir     = fullfile(baseDir, 'results'); if ~exist(outDir,'dir'), mkdir(outDir); end

% 任务与界面
bgColor       = [128 128 128 ];            % 黑背景
textColor     = [255 255 255];      % 白字
imgTargetSize = [600 800];          % [H W] 像素
imgPhysicalCM = [15 20];            % 用于记录（显示物理一致性）
vasWidthPix   = 800 * 0.8;
vasHeightPix  = 6;
vasYOffsetPix = 220;
tickRadius    = 8;

% 分块设置
blockSize   = 60;         % ← 每多少trial插一次休息（可按你的刺激量调整）
breakSecs   = 10;         % 最短休息秒数（可设 0，完全由受试者控制继续）
breakText   = '休息一下～按空格继续（至少休息 %d 秒）';

% 三个量表的名称 + 左右端点说明
labels(1) = struct('name','对酒的渴求',       ...  % urge
                   'left','完全没有',   ...
                   'right','非常强烈');

labels(2) = struct('name','愉悦程度', ...  % valence
                   'left','非常不愉快', ...
                   'right','非常愉快');

labels(3) = struct('name','唤醒度',     ...  % arousal
                   'left','非常平静',   ...
                   'right','非常兴奋');


showNumericValue = false;   % 不显示具体数值（避免锚定）
clickToConfirm   = true;    % 点击确认评分

% 随机种子
rngSeed = sum(100*clock); rng(rngSeed);

%% -------------------- SUBJECT / SESSION INPUT --------------------
prompt  = {'被试ID (subject_id):','场次ID (session_id):'};
title   = '输入被试与场次';
dims    = [1 50];
defAns  = {datestr(now,'yyyymmdd'), 'S1'};
answ    = inputdlg(prompt, title, dims, defAns);
if isempty(answ), error('取消输入，被终止。'); end
subject_id = strtrim(answ{1});
session_id = strtrim(answ{2});

%% -------------------- GATHER STIMULI --------------------
fprintf('Scanning stimulus folders...\n');
allRows = {};
for i = 1:numel(subfolders)
    p = fullfile(baseDir, subfolders{i});
    assert(exist(p,'dir')==7, 'Folder not found: %s', p);
    f = [dir(fullfile(p,'*.jpg')); dir(fullfile(p,'*.png')); dir(fullfile(p,'*.jpeg')); dir(fullfile(p,'*.bmp'))];
    for k = 1:numel(f)
        allRows(end+1,:) = { fullfile(p, f(k).name), subfolders{i} }; %#ok<AGROW>
    end
end
assert(~isempty(allRows), 'No images found under the three folders.');

N = size(allRows,1);
order = randperm(N);

trial_num = (1:N).';
image_id  = strings(N,1);
library   = strings(N,1);
for t = 1:N
    image_id(t) = string(getFilename(allRows{order(t),1}));
    library(t)  = string(allRows{order(t),2});
end

% 预存顺序
orderInfo = table(trial_num, image_id, library, 'VariableNames', {'trial_num','image_id','library'});
orderStamp    = sprintf('%s_%s_%s', subject_id, session_id, stamp());
orderMatPath  = fullfile(outDir, sprintf('trial_order_%s.mat', orderStamp));
orderCsvPath  = fullfile(outDir, sprintf('trial_order_%s.csv', orderStamp));
save(orderMatPath, 'orderInfo','order','rngSeed','baseDir','subfolders','subject_id','session_id','blockSize');
writetable(orderInfo, orderCsvPath);
fprintf('Order saved:\n  %s\n  %s\n', orderMatPath, orderCsvPath);

%% -------------------- PTB SETUP --------------------
AssertOpenGL;
KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
spaceKey  = KbName('SPACE');

Screen('Preference','SkipSyncTests', 2); % 正式实验建议设为0并做校准
screenId = max(Screen('Screens'));
[win, winRect] = Screen('OpenWindow', screenId, bgColor);
Screen('TextFont', win, 'simsun');
Screen('TextSize', win, 24);
HideCursor(win); ListenChar(2);
[screenW, screenH] = Screen('WindowSize', win);
xCenter = screenW/2; yCenter = screenH/2;

% 开始界面
intro = sprintf(['图片评分任务（酒精线索）\n\n被试: %s   场次: %s\n' ...
    '每张图片后，用鼠标在三条连续量表（VAS）上评分：\n' ...
    '1) 渴求（无→强）\n2) 情绪效价（非常不愉快→非常愉快）\n3) 情绪唤醒（非常平静→非常兴奋）\n\n' ...
    '拖动滑块到合适位置后点击确认进入下一条量表。\n（不显示数值，仅显示滑块位置）\n\n' ...
    '按空格键开始；按 ESC 退出，数据会保留。'], subject_id, session_id);
 DrawFormattedText(win, double(intro), 'center', 'center', textColor);
Screen('Flip', win);
KbWait([], 2);

ShowCursor('Arrow');

%% -------------------- RUNTIME LOGS --------------------
urge = nan(N,1); val = nan(N,1); aros = nan(N,1);
onset_time = nan(N,1);
rt_urge = nan(N,1); rt_val = nan(N,1); rt_arousal = nan(N,1);

dataCsvPath = fullfile(outDir, sprintf('trial_table_%s.csv', orderStamp));
fid = fopen(dataCsvPath,'w');
fprintf(fid, 'subject_id,session_id,trial_num,image_id,library,urge,valence,arousal,onset_time,rt_urge,rt_valence,rt_arousal\n');

%% -------------------- MAIN LOOP --------------------
try
    for t = 1:N
        Screen('FillRect', win, [0 0 0]);
    DrawFormattedText(win, '+', 'center', 'center', [255 255 255]);
    Screen('Flip', win);
    WaitSecs(1.5);  % 维持2秒
        % 读取并“等比缩放+黑边”至 800x600
        imgPath = allRows{order(t),1};
        [I , map] = imread(imgPath);
        
        % 如果有调色板（indexed image），先转成真彩色 RGB
        if ~isempty(map)
            I = ind2rgb(I, map);   % 得到 double, 0~1, size: H×W×3
            I = im2uint8(I);       % 转成 uint8，0~255
        end
        
        % 统一处理通道数，避免灰度/alpha 问题
        if size(I,3) == 1
            I = repmat(I, [1 1 3]);
        elseif size(I,3) > 3
            I = I(:,:,1:3);
        end
        Ipad = resizeWithPadding(I, imgTargetSize);
        tex = Screen('MakeTexture', win, Ipad);

        % 画面
        Screen('FillRect', win, bgColor);
        dstRect = CenterRectOnPoint([0 0 imgTargetSize(2) imgTargetSize(1)], xCenter, yCenter-150);
        Screen('DrawTexture', win, double(tex), [], dstRect);

        % 顶部标题（可注释隐藏）
        titleStr = sprintf('Trial %d/%d  |  %s  [%s]', t, N, image_id(t), library(t));
        DrawFormattedText(win, double(titleStr), 'center', dstRect(2)-40, textColor);

        % 三条VAS
        onset_time(t) = GetSecs;
        % —— 保持你原来的 tex, dstRect 生成代码不变 ——
        [urge(t), val(t), aros(t), rt_total] = doThreeVAS( ...
    win, tex, dstRect, screenW, screenH, ...
    vasYOffsetPix, vasWidthPix, vasHeightPix, ...
    tickRadius, textColor, labels, escapeKey);

        rt_urge(t)   = rt_total;  % 如需单独RT，可进一步拆分，这里记录总体
        rt_val(t)    = rt_total;
        rt_arousal(t)= rt_total;


        Screen('Close', tex);

        % 增量写盘
        fprintf(fid, '%s,%s,%d,%s,%s,%.3f,%.3f,%.3f,%.6f,%.3f,%.3f,%.3f\n', ...
            subject_id, session_id, t, image_id(t), library(t), urge(t), val(t), aros(t), ...
            onset_time(t), rt_urge(t), rt_val(t), rt_arousal(t));

        trial_table = table(trial_num, image_id, library, urge, val, aros, onset_time, rt_urge, rt_val, rt_arousal);
        autosaveMat = fullfile(outDir, sprintf('_autosave_%s.mat', subject_id));
        save(autosaveMat, 'trial_table','orderInfo','order','rngSeed','baseDir','subfolders','subject_id','session_id','blockSize');

        % ---- 分块休息 ----
        if mod(t, blockSize)==0 && t < N
            doBreak(win, textColor, breakSecs, breakText, t, N, spaceKey, escapeKey);
        end
    end

    % 结束页
    Screen('FillRect', win, bgColor);
    DrawFormattedText(win, double('任务完成，感谢参与！'), 'center', 'center', textColor);
    Screen('Flip', win); KbWait([], 2);

catch ME
    localCleanup;
    warning('Error: %s', ME.message);
    sca;
end

%% -------------------- CLEANUP & FINAL SAVE --------------------
fclose(fid); ShowCursor; ListenChar(0); sca;
trial_table = table(trial_num, image_id, library, urge, val, aros, onset_time, rt_urge, rt_val, rt_arousal);
finalMat = fullfile(outDir, sprintf('trial_table_%s.mat', orderStamp));
finalCsv = fullfile(outDir, sprintf('trial_table_%s_final.csv', orderStamp));
save(finalMat, 'trial_table','orderInfo','order','rngSeed','baseDir','subfolders','subject_id','session_id','imgTargetSize','imgPhysicalCM','blockSize');
writetable(trial_table, finalCsv);
fprintf('Final saved:\n  %s\n  %s\n', finalMat, finalCsv);

end % main


%% ---------- Helpers ----------
function out = resizeWithPadding(I, targetHW)
% 等比缩放 + 黑边填充到 [H W]，兼容灰度/ RGB / RGBA / logical
targetH = targetHW(1); targetW = targetHW(2);

% 统一到 uint8 RGB
if islogical(I), I = uint8(I)*255; end
if ndims(I) == 2 || size(I,3)==1
    I = repmat(I, [1 1 3]);                % 灰度→RGB
elseif size(I,3) >= 3
    I = I(:,:,1:3);                         % 丢弃 alpha / 额外通道
end
if ~isa(I,'uint8')
    I = im2uint8(I);                        % 双精度/单精度→uint8
end

[h, w, ~] = size(I);
scale = min(targetH/h, targetW/w);
I2 = imresize(I, scale);

[h2, w2, ~] = size(I2);
out = zeros(targetH, targetW, 3, 'uint8');  % 黑底
r0 = floor((targetH - h2)/2) + 1;
c0 = floor((targetW - w2)/2) + 1;
out(r0:r0+h2-1, c0:c0+w2-1, :) = I2;
end


function [rating, rt] = doVAS(win, screenW, screenH, imgRect, vasYOffsetPix, vasWidthPix, vasHeightPix, ...
                               tickRadius, textColor, labelPair, showNumber, clickToConfirm, escapeKey, spaceKey)
% 连续VAS：鼠标移动评分，点击/空格确认；返回 0..100
leftX  = (screenW - vasWidthPix)/2;
rightX = leftX + vasWidthPix;
baseY  = imgRect(4) + vasYOffsetPix;
x = (leftX+rightX)/2; rating = 50; confirmed = false;
tStart = GetSecs;

while ~confirmed
    [down,~,kc] = KbCheck;
    if down && kc(escapeKey), error('ESC pressed.'); end
    [mx, ~, buttons] = GetMouse(win);
    x = min(max(mx, leftX), rightX);
    rating = 100 * (x - leftX) / (rightX - leftX);

    Screen('FillRect', win, [0 0 0]);
    Screen('FillRect', win, [200 200 200], [leftX, baseY-vasHeightPix/2, rightX, baseY+vasHeightPix/2]);
    DrawFormattedText(win, double(labelPair{2}), leftX, baseY - 40, textColor);      % 端点英文
    DrawFormattedText(win, double(labelPair{1}), 'center', baseY - 80, textColor);   % 量表标题（中文）
    Screen('FillOval', win, [255 255 255], [x-tickRadius, baseY-tickRadius, x+tickRadius, baseY+tickRadius]);

    if showNumber
        DrawFormattedText(win, double(sprintf('%.1f', rating)), x-10, baseY+30, textColor);
    end
    DrawFormattedText(win, double('移动鼠标选择，点击确认（或按空格）'), 'center', baseY+60, textColor);
    Screen('Flip', win);

    if clickToConfirm
        if any(buttons), confirmed = true; end
    else
        if down && kc(spaceKey), confirmed = true; end
    end
end
rt = GetSecs - tStart;
end

function s = stamp()
s = datestr(now,'yyyymmdd_HHMMSS');
end

function f = getFilename(p)
[~, f, e] = fileparts(p); f = [f e];
end

function checkEscape
[down,~,kc] = KbCheck; if down && kc(KbName('ESCAPE')), error('ESC pressed.'); end
end

function doBreak(win, textColor, minSecs, msgFmt, t, N, spaceKey, escapeKey)
t0 = GetSecs; keydown = false;
while true
    nowSecs = GetSecs - t0;
    Screen('FillRect', win, [0 0 0]);
    txt = sprintf(['第 %d/%d 试次完成\n\n' msgFmt '\n\n已休息：%.1f 秒\n\n按空格继续，ESC 退出'], ...
                  t, N, minSecs, nowSecs);
    DrawFormattedText(win, double(txt), 'center','center', textColor);
    Screen('Flip', win);
    [down,~,kc] = KbCheck;
    if down && kc(escapeKey), error('ESC pressed.'); end
    if nowSecs >= minSecs && down && kc(spaceKey), keydown = true; end
    if keydown, break; end
    WaitSecs(0.02);
end
end

function [urge, valence, arousal, rt_total] = doThreeVAS( ...
    win, tex, dstRect, screenW, screenH, ...
    vasYOffsetPix, vasWidthPix, vasHeightPix, ...
    tickRadius, textColor, labels, escapeKey)
% 三个VAS同屏：
% - 紧贴图片下方
% - 每条bar左有“指标名称”，左右端点有端点文字
% - 右下角“继续”按钮（仅鼠标点击确认）

% ========= 布局参数 =========
gapY      = 70;    % 三条之间的垂直间距
nameGap   = 40;    % 指标名称距bar左端的水平距离
nameColW  = 160;   % 名称列宽度（大一点文字不挤）
btnW      = 260;   % 继续按钮宽
btnH      = 46;    % 继续按钮高
btnMargin = 50;    % 按钮距右/下边缘的边距

% 以图片下缘为基准，靠近图片的第一条bar
firstY = round(dstRect(4) + vasYOffsetPix)+100;
baseY1 = firstY;
baseY2 = baseY1 + gapY;
baseY3 = baseY2 + gapY;

% bar 水平位置：相对屏幕居中
barLeft  = (screenW - vasWidthPix)/2;
barRight = barLeft + vasWidthPix;

% 如太靠底，整体上移
bottomMargin = 140;
if baseY3 + 60 > screenH - bottomMargin
    shiftUp = (baseY3 + 60) - (screenH - bottomMargin);
    baseY1 = baseY1 - shiftUp;
    baseY2 = baseY2 - shiftUp;
    baseY3 = baseY3 - shiftUp;
end

% 指标名称位置：在bar左边一小段距离
nameX = barLeft - nameGap - nameColW;   % 名称左上角x
if nameX < 40, nameX = 40; end          % 不要太靠左

% ===== 初值与命中区域 =====
urge    = 50; valence = 50; arousal = 50;
x1 = barLeft + (barRight-barLeft)*urge/100;
x2 = barLeft + (barRight-barLeft)*valence/100;
x3 = barLeft + (barRight-barLeft)*arousal/100;

hitH = max(40, vasHeightPix*6);
hit1 = [barLeft, baseY1-hitH/2, barRight, baseY1+hitH/2];
hit2 = [barLeft, baseY2-hitH/2, barRight, baseY2+hitH/2];
hit3 = [barLeft, baseY3-hitH/2, barRight, baseY3+hitH/2];

% 右下角按钮
confirmBtn = [screenW-btnMargin-btnW, screenH-btnMargin-btnH, ...
              screenW-btnMargin,       screenH-btnMargin];

tStart      = GetSecs;
prevButtons = [0 0 0];
dragLock    = 0;  % 0=无；1=urge；2=valence；3=arousal

while true
    % ESC 退出
    [down,~,kc] = KbCheck;
    if down && kc(escapeKey), error('ESC pressed.'); end

    [mx,my,buttons] = GetMouse(win);
    clickDown = any(buttons);
    clickEdge = clickDown && ~any(prevButtons); % 鼠标上升沿
    prevButtons = buttons;

    % 命中+拖拽锁定
    if clickEdge
        if inRect(mx,my,hit1), dragLock = 1;
        elseif inRect(mx,my,hit2), dragLock = 2;
        elseif inRect(mx,my,hit3), dragLock = 3;
        end
    elseif ~clickDown
        dragLock = 0;
    end

    % 根据锁定条更新位置
    if clickDown && dragLock==1
        x1 = min(max(mx,barLeft),barRight);
        urge = 100*(x1-barLeft)/(barRight-barLeft);
    elseif clickDown && dragLock==2
        x2 = min(max(mx,barLeft),barRight);
        valence = 100*(x2-barLeft)/(barRight-barLeft);
    elseif clickDown && dragLock==3
        x3 = min(max(mx,barLeft),barRight);
        arousal = 100*(x3-barLeft)/(barRight-barLeft);
    end

    % ========= 绘制 =========
    Screen('FillRect', win, [0 0 0]);
    Screen('DrawTexture', win, double(tex), [], dstRect);

    % 三条bar（紧跟图片）
    drawOneBarWithLabels(win, nameX, barLeft, barRight, baseY1, ...
        vasHeightPix, tickRadius, textColor, labels(1), x1);
    drawOneBarWithLabels(win, nameX, barLeft, barRight, baseY2, ...
        vasHeightPix, tickRadius, textColor, labels(2), x2);
    drawOneBarWithLabels(win, nameX, barLeft, barRight, baseY3, ...
        vasHeightPix, tickRadius, textColor, labels(3), x3);

    % 右下角“继续”按钮
    Screen('FrameRect', win, [200 200 200], confirmBtn, 2);
    DrawFormattedText(win, double('继续 / Continue'), ...
        'center', confirmBtn(2)+30, textColor, [], [], [], [], [], confirmBtn);

    Screen('Flip', win);

    % 仅在“点击按钮”的上升沿确认
    if clickEdge && inRect(mx,my,confirmBtn)
        rt_total = GetSecs - tStart;
        waitMouseRelease;
        WaitSecs(0.10);   % 去抖
        break;
    end
end
end

function drawOneBarWithLabels(win, nameX, barLeft, barRight, baseY, ...
                              vasHeightPix, tickRadius, textColor, labelStruct, cursorX)
% 左：指标名称；条两端：端点文字；条上：光标

nameStr = char(labelStruct.name);
leftStr = char(labelStruct.left);
rightStr= char(labelStruct.right);

% 指标名称放在bar左侧，略高一点
DrawFormattedText(win, double(nameStr), nameX, baseY, textColor);

% bar 本体
Screen('FillRect', win, [200 200 200], ...
    [barLeft, baseY-vasHeightPix/2, barRight, baseY+vasHeightPix/2]);

[rightBounds, ~] = Screen('TextBounds', win, double(rightStr));
% 左右端点说明，贴近bar，稍微在下面
DrawFormattedText(win, double(leftStr), barLeft-1/2*rightBounds(3), baseY -12 - 20, textColor);

% 右端点用一个限制矩形，让文本贴着右边对齐
%rightRect = [barRight-160, baseY+20, barRight, baseY+20+40]; % 160像素宽够放中文
DrawFormattedText(win, double(rightStr), barRight-1/2*rightBounds(3),baseY-12-20,textColor);

% 光标
Screen('FillOval', win, [255 255 255], ...
    [cursorX-tickRadius, baseY-tickRadius, cursorX+tickRadius, baseY+tickRadius]);
end

function tf = inRect(x,y,rect)
tf = (x>=rect(1) && x<=rect(3) && y>=rect(2) && y<=rect(4));
end

function waitMouseRelease
[~,~,b] = GetMouse;
while any(b)
    WaitSecs(0.01);
    [~,~,b] = GetMouse;
end
end






  
function localCleanup()
    try
        KbReleaseWait;             % 等键释放，避免残留按键状态
    catch, end
    try
        ListenChar(0);             % 释放键盘拦截（最关键！）
    catch, end
    try
        ShowCursor;                % 恢复光标
    catch, end
    try
        Priority(0);               % 恢复调度优先级
    catch, end
    try
        Screen('CloseAll');        % 关闭所有窗口/纹理
    catch, end
    try
        clear mex;                 % 释放 PTB MEX（有时能解决卡顿）
    catch, end
end
