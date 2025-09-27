function medical_diagnosis_app()
    % -------------------- Set Python environment --------------------
    pyenv("Version","C:\\Users\\Sahil Bhagat\\AppData\\Local\\Programs\\Python\\Python310\\python.exe");

    % -------------------- Import Python wrapper ---------------------
    py.importlib.import_module('yolo_wrapper');

    % -------------------- Define available models -------------------
    models = containers.Map;
    models('Brain Tumor MRI')       = 'models/brain_tumor_mri.pt';
    models('Brain Tumor CT')        = 'models/brain_tumor_ct.pt';
    models('Pneumonia CT')          = 'models/pneumonia_ct.pt';
    models('Pneumonia X-ray')       = 'models/pneumonia_xray.pt';
    models('Breast Cancer Mammogram')  = 'models/breast_cancer_mammogram.pt';
    models('Breast Cancer Ultrasound') = 'models/breast_cancer_ultrasound.pt';

    % -------------------- Create Python models ----------------------
    keys = models.keys;
    for i = 1:length(keys)
        name = keys{i};
        model_path = models(name);
        py.yolo_wrapper.create_model(name, model_path);
    end

    % -------------------- Select test image -------------------------
    [file, path] = uigetfile({'*.jpg;*.png;*.jpeg'}, 'Select a medical scan');
    if isequal(file,0)
        disp('No file selected'); return;
    end
    imgPath = fullfile(path,file);
    I = imread(imgPath);

    % -------------------- Choose disease model ----------------------
    fprintf('Available models:\n');
    for i=1:length(keys)
        fprintf('%d) %s\n', i, keys{i});
    end
    idx = input('Select model number: ');
    modelName = keys{idx};

    % -------------------- Run prediction via Python -----------------
    results = py.yolo_wrapper.predict(modelName, imgPath);

    % -------------------- Extract bounding boxes, classes, confidence
    pyResults = results{1};  % first image
    boxes_py = pyResults.boxes.xyxy; 
    cls_py   = pyResults.boxes.cls;  
    conf_py  = pyResults.boxes.conf;

    % Convert Python arrays to MATLAB
    if ~isempty(boxes_py)
        boxes = double(boxes_py.cpu().numpy());
        cls   = double(cls_py.cpu().numpy());
        conf  = double(conf_py.cpu().numpy());

        % -------------------- Annotate image without toolbox ----------
        imshow(I); hold on;
        for j = 1:size(boxes,1)
            rectangle('Position',[boxes(j,1), boxes(j,2), boxes(j,3)-boxes(j,1), boxes(j,4)-boxes(j,2)], ...
                      'EdgeColor','r','LineWidth',2);
            txt = sprintf('Class %d (%.2f)', cls(j), conf(j));
            text(boxes(j,1), boxes(j,2)-10, txt, 'Color','yellow','FontSize',10,'FontWeight','bold');
        end
        title(['Detections - ', modelName]);
        hold off;
    else
        imshow(I); title(['No detections - ', modelName]);
    end

    % -------------------- Calculate severity -----------------------
    if ~isempty(boxes_py)
        total_area = 0;
        for j = 1:size(boxes,1)
            x1 = boxes(j,1); y1 = boxes(j,2);
            x2 = boxes(j,3); y2 = boxes(j,4);
            total_area = total_area + (x2-x1)*(y2-y1);
        end
        img_area = size(I,1)*size(I,2);
        severity = (total_area / img_area)*100;
        stage = severity_to_stage(severity);
        fprintf('Severity: %.2f%%, Stage: %s\n', severity, stage);
    else
        fprintf('No detections, cannot calculate severity.\n');
    end
end

function stage = severity_to_stage(severity)
    if severity < 30
        stage = 'Mild';
    elseif severity < 70
        stage = 'Moderate';
    else
        stage = 'Severe';
    end
end
