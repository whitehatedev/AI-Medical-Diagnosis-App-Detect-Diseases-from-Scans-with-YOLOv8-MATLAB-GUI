# yolo_wrapper.py
from ultralytics import YOLO

models = {}

def create_model(name, model_path):
    """
    Create and store YOLO model under a name.
    """
    models[name] = YOLO(model_path)
    return name

def predict(name, img_path):
    """
    Run YOLO prediction on an image using a stored model.
    """
    model = models[name]
    results = model.predict(img_path)
    return results
