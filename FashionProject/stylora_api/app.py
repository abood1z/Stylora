from fastapi import FastAPI, UploadFile, File
import os

from models.fashion_classifier import predict

app = FastAPI(title="Stylora AI API")


@app.get("/")
def home():
    return {
        "message": "Stylora API Running"
    }


@app.get("/health")
def health():
    return {
        "status": "online"
    }


@app.post("/classify")
async def classify(file: UploadFile = File(...)):

    os.makedirs(
        "uploads",
        exist_ok=True
    )

    image_path = os.path.join(
        "uploads",
        file.filename
    )

    with open(image_path, "wb") as f:
        f.write(
            await file.read()
        )

    result = predict(
        image_path
    )

    return result