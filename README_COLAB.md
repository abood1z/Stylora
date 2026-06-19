# دليل تشغيل خادم تجربة الملابس الذكي على Google Colab (Stylora Virtual Try-On)

هذا الدليل يحتوي على جميع الخلايا (Cells) البرمجية والأوامر اللازمة لتشغيل خادم **FastAPI** لتجربة الملابس الافتراضية الذكي (`tryon_api.py`) على بيئة Google Colab السحابية مجاناً مع حل جميع مشاكل تعارض المكتبات وحفظ الذاكرة الرسومية (VRAM).

---

## 🚀 الخلايا البرمجية لتشغيل Google Colab

أنشئ دفتر ملاحظات جديد (Notebook) على Google Colab وتأكد من تغيير بيئة العمل إلى **T4 GPU** (من قائمة `Runtime` -> `Change runtime type` -> اختر `T4 GPU`). ثم الصق الخلايا التالية بالترتيب:

### 1️⃣ الخلية الأولى: تحميل مستودع IDM-VTON الرسمي
تقوم هذه الخلية بنسخ الكود المصدري للمشروع والدخول للمجلد الخاص به:
```bash
# الانتقال للمجلد الرئيسي وتحميل المشروع
%cd /content
!git clone https://github.com/yisol/IDM-VTON.git
%cd /content/IDM-VTON
```

---

### 2️⃣ الخلية الثانية: تنصيب المكتبات البرمجية بالترتيب الصحيح (حل مشاكل التعارض)
* تقوم هذه الخلية بترقية جميع المكتبات الأساسية لأحدث نسخة متوافقة تلقائياً.
* يتم معالجة توافق `huggingface_hub` ديناميكياً داخل الكود لمنع تعارض الإصدارات.
```bash
# تنصيب وترقية المكتبات لمنع التعارضات ومشاكل الاستيراد
!pip install --upgrade huggingface_hub
!pip install accelerate==0.25.0 peft transformers==4.36.2 diffusers==0.25.0

# تنصيب المكتبات الأساسية لـ FastAPI والمواقع
!pip install einops fastapi uvicorn python-multipart pyngrok onnxruntime av

# تنصيب مكتبة الذكاء الاصطناعي detectron2 ومفسر openpose
!pip install 'git+https://github.com/facebookresearch/detectron2.git'
```

---

### 3️⃣ الخلية الثالثة: تحميل أوزان النماذج والملفات المدربة (Checkpoints)
تقوم هذه الخلية بإنشاء المجلدات وتحميل أوزان DensePose و OpenPose ومعالج الوجوه وتجزئة الملابس من Hugging Face:
```bash
# إنشاء مجلدات التخزين
!mkdir -p ckpt/densepose ckpt/humanparsing ckpt/openpose/ckpts

# 1. تحميل ملف DensePose
!wget -O ckpt/densepose/model_final_162be9.pkl https://huggingface.co/yisol/IDM-VTON/resolve/main/ckpt/densepose/model_final_162be9.pkl

# 2. تحميل ملفات تجزئة جسم الإنسان (Human Parsing)
!wget -O ckpt/humanparsing/parsing_atr.onnx https://huggingface.co/yisol/IDM-VTON/resolve/main/ckpt/humanparsing/parsing_atr.onnx
!wget -O ckpt/humanparsing/parsing_lip.onnx https://huggingface.co/yisol/IDM-VTON/resolve/main/ckpt/humanparsing/parsing_lip.onnx

# 3. تحميل ملف وضعيات الجسد (OpenPose)
!wget -O ckpt/openpose/ckpts/body_pose_model.pth https://huggingface.co/yisol/IDM-VTON/resolve/main/ckpt/openpose/ckpts/body_pose_model.pth
```

---

### 4️⃣ الخلية الرابعة: كتابة كود الخادم الذكي المحسّن (`tryon_api.py`)
الصق الكود التالي بالكامل في خلية واحدة لإنشاء ملف `tryon_api.py` داخل بيئة كولاب:
```python
%%writefile tryon_api.py
import os
import sys
import io
import json

# 0. حل مشكلة cached_download في huggingface_hub للنسخ الجديدة (0.26+) بشكل ديناميكي ومضمون
import huggingface_hub
if not hasattr(huggingface_hub, "cached_download"):
    try:
        from huggingface_hub.file_download import cached_download
        huggingface_hub.cached_download = cached_download
    except ImportError:
        import urllib.request
        import hashlib
        
        def get_token_safely():
            token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
            if token:
                return token
            try:
                import huggingface_hub
                if hasattr(huggingface_hub, "get_token"):
                    return huggingface_hub.get_token()
            except Exception:
                pass
            try:
                from huggingface_hub.utils import get_token
                return get_token()
            except Exception:
                pass
            try:
                from huggingface_hub import HfFolder
                return HfFolder.get_token()
            except Exception:
                pass
            return None
        
        def cached_download_shim(url, *args, **kwargs):
            cache_dir = os.path.join(os.environ.get("HF_HOME", os.path.expanduser("~/.cache/huggingface")), "compat")
            os.makedirs(cache_dir, exist_ok=True)
            url_hash = hashlib.sha256(url.encode('utf-8')).hexdigest()
            local_path = os.path.join(cache_dir, f"cached_{url_hash}_{os.path.basename(url.split('?')[0])}")
            
            if not os.path.exists(local_path):
                print(f"📥 Downloading dynamic module via compat shim: {url}")
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                token = kwargs.get('token') or get_token_safely()
                if token:
                    req.add_header('Authorization', f'Bearer {token}')
                with urllib.request.urlopen(req) as response, open(local_path, 'wb') as out_file:
                    out_file.write(response.read())
            return local_path
            
        huggingface_hub.cached_download = cached_download_shim
        try:
            import huggingface_hub.file_download
            huggingface_hub.file_download.cached_download = cached_download_shim
        except Exception:
            pass
        print("🔧 Configured dynamic compatibility fallback for cached_download in huggingface_hub")

# 0.1 حل مشكلة تعارض واستيراد PositionNet و CaptionProjection في النسخ الجديدة من diffusers (0.26+)
try:
    import diffusers.models.embeddings
    if not hasattr(diffusers.models.embeddings, "PositionNet"):
        try:
            from diffusers.models.embeddings import GLIGENTextBoundingboxProjection
            diffusers.models.embeddings.PositionNet = GLIGENTextBoundingboxProjection
            print("🔧 Patched diffusers PositionNet with GLIGENTextBoundingboxProjection fallback")
        except ImportError:
            pass
    if not hasattr(diffusers.models.embeddings, "CaptionProjection"):
        try:
            from diffusers.models.embeddings import PixArtAlphaTextProjection
            diffusers.models.embeddings.CaptionProjection = PixArtAlphaTextProjection
            print("🔧 Patched diffusers CaptionProjection with PixArtAlphaTextProjection fallback")
        except ImportError:
            pass
except Exception as e:
    print(f"⚠️ Could not pre-patch diffusers embeddings: {e}")

import torch
import numpy as np
from PIL import Image, ImageFilter
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import uvicorn
from torchvision import transforms
from torchvision.transforms.functional import to_pil_image
import traceback
import gc

# التحديد التلقائي لبيئة العمل وتوجيه الكاش
IS_COLAB = "google.colab" in sys.modules or os.path.exists("/content")
if IS_COLAB:
    os.environ["HF_HOME"] = "/content/huggingface_cache"
    print("🌐 Running on Google Colab. Configured cache path to /content/huggingface_cache")
else:
    os.environ["HF_HOME"] = r"C:\d\Stylora\huggingface_cache"
    print("💻 Running locally. Configured cache path to local Stylora folder")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(BASE_DIR)
sys.path.append(os.path.join(BASE_DIR, 'gradio_demo'))

# استيراد مكونات موديل IDM-VTON
from src.tryon_pipeline import StableDiffusionXLInpaintPipeline as TryonPipeline
from src.unet_hacked_garmnet import UNet2DConditionModel as UNet2DConditionModel_ref
from src.unet_hacked_tryon import UNet2DConditionModel
from transformers import (
    CLIPImageProcessor,
    CLIPVisionModelWithProjection,
    CLIPTextModel,
    CLIPTextModelWithProjection,
    AutoTokenizer,
)
from diffusers import DDPMScheduler, AutoencoderKL
from utils_mask import get_mask_location
import apply_net
from preprocess.humanparsing.run_parsing import Parsing
from preprocess.openpose.run_openpose import OpenPose
from detectron2.data.detection_utils import convert_PIL_to_numpy, _apply_exif_orient

base_path = 'yisol/IDM-VTON'
device = 'cuda:0' if torch.cuda.is_available() else 'cpu'

# تحميل المشفرات على الـ CPU مؤقتاً لتفادي امتلاء الذاكرة OOM
print("⏳ Loading tokenizer and scheduler...")
tokenizer_one = AutoTokenizer.from_pretrained(base_path, subfolder="tokenizer", use_fast=False)
tokenizer_two = AutoTokenizer.from_pretrained(base_path, subfolder="tokenizer_2", use_fast=False)
noise_scheduler = DDPMScheduler.from_pretrained(base_path, subfolder="scheduler")

print("⏳ Loading UNet model...")
unet = UNet2DConditionModel.from_pretrained(base_path, subfolder="unet", torch_dtype=torch.float16, low_cpu_mem_usage=True)
unet.requires_grad_(False)
if 'cuda' in device:
    unet.to(device)
gc.collect()
torch.cuda.empty_cache()

print("⏳ Loading Text Encoders on CPU (VRAM optimization)...")
text_encoder_one = CLIPTextModel.from_pretrained(base_path, subfolder="text_encoder", torch_dtype=torch.float16, low_cpu_mem_usage=True)
text_encoder_two = CLIPTextModelWithProjection.from_pretrained(base_path, subfolder="text_encoder_2", torch_dtype=torch.float16, low_cpu_mem_usage=True)

print("⏳ Loading UNet Encoder, Image Encoder, and VAE on GPU...")
UNet_Encoder = UNet2DConditionModel_ref.from_pretrained(base_path, subfolder="unet_encoder", torch_dtype=torch.float16, low_cpu_mem_usage=True)
UNet_Encoder.requires_grad_(False)
if 'cuda' in device:
    UNet_Encoder.to(device)

image_encoder = CLIPVisionModelWithProjection.from_pretrained(base_path, subfolder="image_encoder", torch_dtype=torch.float16, low_cpu_mem_usage=True)
image_encoder.requires_grad_(False)
if 'cuda' in device:
    image_encoder.to(device)

vae = AutoencoderKL.from_pretrained(base_path, subfolder="vae", torch_dtype=torch.float16, low_cpu_mem_usage=True)
vae.requires_grad_(False)
if 'cuda' in device:
    vae.to(device)

gc.collect()
torch.cuda.empty_cache()

print("⏳ Loading parsing and openpose models...")
parsing_model = Parsing(0)
openpose_model = OpenPose(0)
if 'cuda' in device:
    openpose_model.preprocessor.body_estimation.model.to(device)

print("⏳ Initializing TryonPipeline...")
pipe = TryonPipeline.from_pretrained(
    base_path,
    unet=unet,
    vae=vae,
    feature_extractor=CLIPImageProcessor(),
    text_encoder=text_encoder_one,
    text_encoder_2=text_encoder_two,
    tokenizer=tokenizer_one,
    tokenizer_2=tokenizer_two,
    scheduler=noise_scheduler,
    image_encoder=image_encoder,
    torch_dtype=torch.float16,
)
pipe.unet_encoder = UNet_Encoder

if 'cuda' in device:
    pipe.to(device)
    pipe.text_encoder.to('cpu')
    pipe.text_encoder_2.to('cpu')
    torch.cuda.empty_cache()
    gc.collect()

tensor_transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize([0.5], [0.5]),
])

def pil_to_binary_mask(pil_image, threshold=0):
    np_image = np.array(pil_image)
    grayscale_image = Image.fromarray(np_image).convert("L")
    binary_mask = np.array(grayscale_image) > threshold
    mask = np.zeros(binary_mask.shape, dtype=np.uint8)
    for i in range(binary_mask.shape[0]):
        for j in range(binary_mask.shape[1]):
            if binary_mask[i, j] == True:
                mask[i, j] = 1
    mask = (mask * 255).astype(np.uint8)
    return Image.fromarray(mask)

def blend_images(human_img, generated_img, mask, feather_radius=10):
    mask_blurred = mask.filter(ImageFilter.GaussianBlur(radius=feather_radius))
    human_np = np.array(human_img).astype(np.float32) / 255.0
    gen_np = np.array(generated_img).astype(np.float32) / 255.0
    mask_np = np.array(mask_blurred).astype(np.float32) / 255.0
    
    if len(mask_np.shape) == 2:
        mask_np = np.expand_dims(mask_np, axis=-1)
        
    blended_np = human_np * (1.0 - mask_np) + gen_np * mask_np
    blended_np = np.clip(blended_np * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(blended_np)

def encode_prompt_optimized(pipe, prompt, negative_prompt, device):
    if 'cuda' in str(device):
        pipe.text_encoder.to(device)
        pipe.text_encoder_2.to(device)
    with torch.no_grad():
        (
            prompt_embeds,
            negative_prompt_embeds,
            pooled_prompt_embeds,
            negative_pooled_prompt_embeds,
        ) = pipe.encode_prompt(
            prompt,
            num_images_per_prompt=1,
            do_classifier_free_guidance=True,
            negative_prompt=negative_prompt,
        )
    if 'cuda' in str(device):
        pipe.text_encoder.to('cpu')
        pipe.text_encoder_2.to('cpu')
        torch.cuda.empty_cache()
        gc.collect()
    return prompt_embeds, negative_prompt_embeds, pooled_prompt_embeds, negative_pooled_prompt_embeds

def encode_cloth_prompt_optimized(pipe, prompt, negative_prompt, device):
    if 'cuda' in str(device):
        pipe.text_encoder.to(device)
        pipe.text_encoder_2.to(device)
    if not isinstance(prompt, list):
        prompt = [prompt] * 1
    if not isinstance(negative_prompt, list):
        negative_prompt = [negative_prompt] * 1
    with torch.no_grad():
        (prompt_embeds_c, _, _, _) = pipe.encode_prompt(
            prompt,
            num_images_per_prompt=1,
            do_classifier_free_guidance=False,
            negative_prompt=negative_prompt,
        )
    if 'cuda' in str(device):
        pipe.text_encoder.to('cpu')
        pipe.text_encoder_2.to('cpu')
        torch.cuda.empty_cache()
        gc.collect()
    return prompt_embeds_c

def run_tryon_inference(human_img_orig, garm_img_orig, category, garment_des, denoise_steps=25, seed=42, websocket=None, loop=None):
    category_mapped = "upper_body"
    if category in ["top", "upper_body"]:
        category_mapped = "upper_body"
    elif category in ["bottom", "lower_body"]:
        category_mapped = "lower_body"
    elif category == "dress":
        category_mapped = "dress"
        
    garm_img = garm_img_orig.convert("RGB").resize((768, 1024))
    human_img = human_img_orig.convert("RGB").resize((768, 1024))
    
    print("⏳ Extracting keypoints and parsing models...")
    human_down = human_img.resize((384, 512))
    keypoints = openpose_model(human_down)
    model_parse, _ = parsing_model(human_down)
    mask, _ = get_mask_location('hd', category_mapped, model_parse, keypoints)
    mask = mask.resize((768, 1024))
    
    print("⏳ Running DensePose segmentation...")
    human_img_arg = _apply_exif_orient(human_down)
    human_img_arg = convert_PIL_to_numpy(human_img_arg, format="BGR")
    
    args_dp = apply_net.create_argument_parser().parse_args((
        'show', './configs/densepose_rcnn_R_50_FPN_s1x.yaml', './ckpt/densepose/model_final_162be9.pkl', 'dp_segm', '-v', '--opts', 'MODEL.DEVICE', 'cuda' if torch.cuda.is_available() else 'cpu'
    ))
    pose_img = args_dp.func(args_dp, human_img_arg)
    pose_img = pose_img[:, :, ::-1]
    pose_img = Image.fromarray(pose_img).resize((768, 1024))
    
    print("⏳ Generating optimized text embeddings...")
    prompt = "model is wearing " + garment_des
    negative_prompt = "monochrome, lowres, bad anatomy, worst quality, low quality"
    prompt_embeds, negative_prompt_embeds, pooled_prompt_embeds, negative_pooled_prompt_embeds = encode_prompt_optimized(pipe, prompt, negative_prompt, device)
    
    prompt_cloth = "a photo of " + garment_des
    prompt_embeds_c = encode_cloth_prompt_optimized(pipe, prompt_cloth, negative_prompt, device)
    
    pose_tensor = tensor_transform(pose_img).unsqueeze(0).to(device, torch.float16)
    garm_tensor = tensor_transform(garm_img).unsqueeze(0).to(device, torch.float16)
    generator = torch.Generator(device).manual_seed(seed) if seed is not None else None
    
    callback = None
    if websocket is not None and loop is not None:
        def callback_on_step_end(pipe_self, step, timestep, callback_kwargs):
            if step % 5 == 0:
                latents = callback_kwargs["latents"]
                with torch.no_grad():
                    latents = 1 / pipe_self.vae.config.scaling_factor * latents
                    latents = latents.to(pipe_self.vae.dtype)
                    image_t = pipe_self.vae.decode(latents).sample
                    image_t = (image_t / 2 + 0.5).clamp(0, 1)
                    image_np = image_t.cpu().permute(0, 2, 3, 1).float().numpy()
                    image_np = (image_np * 255).round().astype("uint8")
                    pil_img = Image.fromarray(image_np[0]).resize((768, 1024))
                    
                    blended_img = blend_images(human_img, pil_img, mask, feather_radius=10)
                    byte_io = io.BytesIO()
                    blended_img.save(byte_io, format='JPEG', quality=80)
                    jpeg_bytes = byte_io.getvalue()
                    asyncio.run_coroutine_threadsafe(websocket.send_bytes(jpeg_bytes), loop)
            return callback_kwargs
        callback = callback_on_step_end

    print("⏳ Launching tryon pipeline...")
    with torch.no_grad():
        with torch.cuda.amp.autocast():
            with torch.inference_mode():
                images = pipe(
                    prompt_embeds=prompt_embeds.to(device, torch.float16),
                    negative_prompt_embeds=negative_prompt_embeds.to(device, torch.float16),
                    pooled_prompt_embeds=pooled_prompt_embeds.to(device, torch.float16),
                    negative_pooled_prompt_embeds=negative_pooled_prompt_embeds.to(device, torch.float16),
                    num_inference_steps=denoise_steps,
                    generator=generator,
                    strength=1.0,
                    pose_img=pose_tensor,
                    text_embeds_cloth=prompt_embeds_c.to(device, torch.float16),
                    cloth=garm_tensor,
                    mask_image=mask,
                    image=human_img,
                    height=1024,
                    width=768,
                    ip_adapter_image=garm_img,
                    guidance_scale=2.0,
                    callback_on_step_end=callback,
                )[0]
                
    final_blended = blend_images(human_img, images[0], mask, feather_radius=10)
    print("✅ Inference finished and blending applied.")
    return final_blended, mask

app = FastAPI(title="Stylora IDM-VTON Local API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/tryon")
async def tryon_post(
    category: str = Form(...),
    description: str = Form("stylish fashion garment"),
    steps: int = Form(25),
    seed: int = Form(42),
    human_img: UploadFile = File(...),
    garm_img: UploadFile = File(...),
):
    try:
        human_bytes = await human_img.read()
        human_pil = Image.open(io.BytesIO(human_bytes)).convert("RGB")
        garm_bytes = await garm_img.read()
        garm_pil = Image.open(io.BytesIO(garm_bytes)).convert("RGB")
        
        loop = asyncio.get_running_loop()
        final_img, _ = await loop.run_in_executor(None, lambda: run_tryon_inference(human_pil, garm_pil, category, description, steps, seed))
        
        byte_io = io.BytesIO()
        final_img.save(byte_io, format="JPEG", quality=95)
        return Response(content=byte_io.getvalue(), media_type="image/jpeg")
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.websocket("/tryon-ws")
async def tryon_ws(websocket: WebSocket):
    await websocket.accept()
    print("🔌 WebSocket client connected to tryon-ws")
    try:
        config_text = await websocket.receive_text()
        config = json.loads(config_text)
        category = config.get("category", "upper_body")
        description = config.get("description", "stylish fashion garment")
        steps = int(config.get("steps", 25))
        seed = int(config.get("seed", 42))
        
        human_bytes = await websocket.receive_bytes()
        human_pil = Image.open(io.BytesIO(human_bytes)).convert("RGB")
        garm_bytes = await websocket.receive_bytes()
        garm_pil = Image.open(io.BytesIO(garm_bytes)).convert("RGB")
        
        loop = asyncio.get_running_loop()
        final_img, _ = await loop.run_in_executor(None, lambda: run_tryon_inference(human_pil, garm_pil, category, description, steps, seed, websocket, loop))
        
        byte_io = io.BytesIO()
        final_img.save(byte_io, format="JPEG", quality=95)
        await websocket.send_bytes(byte_io.getvalue())
        print("WS Final Image sent successfully.")
    except WebSocketDisconnect:
        print("🔌 WebSocket client disconnected.")
    except Exception as e:
        traceback.print_exc()
        try:
            await websocket.send_text(json.dumps({"error": str(e)}))
        except Exception:
            pass
    finally:
        try:
            await websocket.close()
        except Exception:
            pass

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

---

### 5️⃣ الخلية الخامسة: ربط خادم Ngrok وتشغيل خادم FastAPI
ضع التوكن الخاص بك في المتغير `NGROK_TOKEN` (من لوحة تحكم Ngrok الخاصة بك في المتصفح)، وشغل هذه الخلية:
```python
# إدخال توكن Ngrok وتشغيل النفق والاتصال
NGROK_TOKEN = "3Es2OiuZPYMc5OanCfu1OTWVMz8_6HASApu8dY9hFr8ViHTmy"

from pyngrok import ngrok
import time

# إغلاق أي جلسات ngrok سابقة
ngrok.kill()
ngrok.set_auth_token(NGROK_TOKEN)

# فتح نفق اتصال على المنفذ 8001
public_url = ngrok.connect(8001, bind_tls=True)
print("=" * 60)
print(f"🚀 Stylora Server public URL:")
print(f"🔗 {public_url}")
print("=" * 60)
print("ملاحظة: انسخ هذا الرابط والصقه في إعدادات صفحة القياس الافتراضي (Virtual Try-on) في التطبيق مباشرة.")
print("=" * 60)

# تشغيل الخادم
!python tryon_api.py
```
*(بمجرد أن تشغل هذه الخلية سيقوم السيرفر بالعمل بشكل مستمر وتنزيل النماذج، ومن ثم استقبال طلبات الهاتف أو المحاكي فوراً!)*
