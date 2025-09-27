function medical_diagnosis_gui_pro()
    % -------------------- Python environment --------------------
    pyenv("Version","C:\\Users\\Sahil Bhagat\\AppData\\Local\\Programs\\Python\\Python310\\python.exe");
    py.importlib.import_module('yolo_wrapper');

    % -------------------- Disease Groups & Models ----------------
    groups = containers.Map;
    groups('Brain Tumor') = {'Brain Tumor MRI','Brain Tumor CT'};
    groups('Pneumonia')   = {'Pneumonia CT','Pneumonia X-ray'};
    groups('Breast Cancer') = {'Breast Cancer Mammogram','Breast Cancer Ultrasound'};

    models = containers.Map;
    models('Brain Tumor MRI')       = 'models/brain_tumor_mri.pt';
    models('Brain Tumor CT')        = 'models/brain_tumor_ct.pt';
    models('Pneumonia CT')          = 'models/pneumonia_ct.pt';
    models('Pneumonia X-ray')       = 'models/pneumonia_xray.pt';
    models('Breast Cancer Mammogram')  = 'models/breast_cancer_mammogram.pt';
    models('Breast Cancer Ultrasound') = 'models/breast_cancer_ultrasound.pt';

    % Load Python YOLO models
    modelKeys = models.keys;
    for i = 1:length(modelKeys)
        py.yolo_wrapper.create_model(modelKeys{i}, models(modelKeys{i}));
    end

    % -------------------- Create UI Figure ----------------------
    fig = uifigure('Name','Medical Diagnosis App','Position',[100 100 1200 750]);

    % -------------------- Step 1: Disease Group ----------------
    grpStep1 = uibuttongroup(fig,'Title','Step 1: Select Disease Group','Position',[20 650 1160 70]);
    uilabel(grpStep1,'Text','Disease Group:','Position',[10 25 120 25]);
    ddlGroup = uidropdown(grpStep1,'Position',[140 25 200 25],'Items',groups.keys,'ValueChangedFcn',@(ddl,event) updateScanDropdowns());

    % -------------------- Step 2: Upload Scans -----------------
    grpStep2 = uibuttongroup(fig,'Title','Step 2: Upload Scans','Position',[20 500 1160 140]);

    uilabel(grpStep2,'Text','Scan 1 Type:','Position',[10 85 120 25]);
    ddlScan1 = uidropdown(grpStep2,'Position',[140 85 200 25]);
    btnUpload1 = uibutton(grpStep2,'push','Position',[360 85 180 30],'Text','Upload Scan 1','ButtonPushedFcn',@(btn,event) uploadScan(1));

    uilabel(grpStep2,'Text','Scan 2 Type:','Position',[10 35 120 25]);
    ddlScan2 = uidropdown(grpStep2,'Position',[140 35 200 25]);
    btnUpload2 = uibutton(grpStep2,'push','Position',[360 35 180 30],'Text','Upload Scan 2','ButtonPushedFcn',@(btn,event) uploadScan(2));

    % -------------------- Step 3: Analyze & Reset -------------
    btnAnalyze = uibutton(fig,'push','Position',[400 450 180 35],'Text','Analyze','FontWeight','bold','ButtonPushedFcn',@(btn,event) analyzeScans());
    btnReset   = uibutton(fig,'push','Position',[600 450 180 35],'Text','Reset','FontWeight','bold','ButtonPushedFcn',@(btn,event) resetGUI());

    % -------------------- Step 4: Results ----------------------
    grpResults = uibuttongroup(fig,'Title','Step 4: Results','Position',[20 20 1160 420]);

    % Define equal width axes
    axesWidth  = 550;
    axesHeight = 350;
    spacing    = 40; % space between axes

    ax1 = uiaxes(grpResults,'Position',[spacing 50 axesWidth axesHeight]);
    axis(ax1,'off'); title(ax1,'Scan 1');

    ax2 = uiaxes(grpResults,'Position',[axesWidth+2*spacing 50 axesWidth axesHeight]);
    axis(ax2,'off'); title(ax2,'Scan 2');

    lblSeverity = uilabel(grpResults,'Position',[20 10 400 25],'Text','Combined Severity: ');
    lblStage    = uilabel(grpResults,'Position',[450 10 400 25],'Text','Combined Stage: ');

    % -------------------- Variables -----------------------------
    scanPaths = cell(1,2);

    % -------------------- Functions -----------------------------
    function updateScanDropdowns()
        groupName = ddlGroup.Value;
        scanTypes = groups(groupName);
        ddlScan1.Items = scanTypes;
        ddlScan1.Value = scanTypes{1};
        ddlScan2.Items = scanTypes;
        ddlScan2.Value = scanTypes{min(2,length(scanTypes))};
        resetGUI();
    end

    function uploadScan(scanNum)
        [file,path] = uigetfile({'*.jpg;*.png;*.jpeg'},sprintf('Select Scan %d',scanNum));
        if isequal(file,0)
            uialert(fig,'No file selected','Error'); return;
        end
        scanPaths{scanNum} = fullfile(path,file);
        if scanNum == 1
            btnUpload1.Text = sprintf('Uploaded: %s', ddlScan1.Value);
        else
            btnUpload2.Text = sprintf('Uploaded: %s', ddlScan2.Value);
        end
    end

    function analyzeScans()
        cla(ax1); cla(ax2);
        totalArea = 0;
        imgArea = 0;

        for i = 1:2
            if ~isempty(scanPaths{i})
                imgPath = scanPaths{i};
                I = imread(imgPath);

                % Display in respective axes
                if i == 1
                    ax = ax1;
                    modelName = ddlScan1.Value;
                else
                    ax = ax2;
                    modelName = ddlScan2.Value;
                end

                imshow(I,'Parent',ax); hold(ax,'on');

                % Predict using YOLO
                res = py.yolo_wrapper.predict(modelName,imgPath);
                pyRes = res{1};
                boxes_py = pyRes.boxes.xyxy;
                cls_py   = pyRes.boxes.cls;
                conf_py  = pyRes.boxes.conf;

                if ~isempty(boxes_py)
                    boxes = double(boxes_py.cpu().numpy());
                    cls   = double(cls_py.cpu().numpy());
                    conf  = double(conf_py.cpu().numpy());

                    for j = 1:size(boxes,1)
                        rectangle(ax,'Position',[boxes(j,1), boxes(j,2), boxes(j,3)-boxes(j,1), boxes(j,4)-boxes(j,2)],...
                            'EdgeColor','r','LineWidth',2);
                        txt = sprintf('Class %d (%.2f)', cls(j), conf(j));
                        text(ax,boxes(j,1), boxes(j,2)-10, txt,'Color','yellow','FontSize',10,'FontWeight','bold');
                        totalArea = totalArea + (boxes(j,3)-boxes(j,1))*(boxes(j,4)-boxes(j,2));
                    end
                    imgArea = imgArea + size(I,1)*size(I,2);
                end
                hold(ax,'off');
            end
        end

        % Severity & Stage
        if totalArea>0 && imgArea>0
            severity = (totalArea/imgArea)*100;
            stage = severity_to_stage(severity);
            lblSeverity.Text = sprintf('Combined Severity: %.2f%%',severity);
            lblStage.Text    = sprintf('Combined Stage: %s',stage);
        else
            lblSeverity.Text = 'Combined Severity: N/A';
            lblStage.Text    = 'Combined Stage: No detections';
        end
    end

    function stage = severity_to_stage(severity)
        if severity<30
            stage='Mild';
        elseif severity<70
            stage='Moderate';
        else
            stage='Severe';
        end
    end

    function resetGUI()
        scanPaths = {[],[]};
        btnUpload1.Text = 'Upload Scan 1';
        btnUpload2.Text = 'Upload Scan 2';
        cla(ax1); cla(ax2);
        lblSeverity.Text = 'Combined Severity: ';
        lblStage.Text    = 'Combined Stage: ';
    end

    % -------------------- Initialize -----------------------------
    updateScanDropdowns();
end
