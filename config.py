# Cấu hình cho bot
DISCORD_WEBHOOK_URL = 'YOUR_DISCORD_WEBHOOK_URL'  # Thay bằng URL webhook Discord của bạn
CHECK_INTERVAL = 10  # Giây giữa mỗi lần check
TESSERACT_PATH = r'C:\Program Files\Tesseract-OCR\tesseract.exe'  # Thay đường dẫn Tesseract

# ROI (Regions of Interest): Điều chỉnh theo emulator của bạn (x1, y1, x2, y2)
ROI_SHIELD = (100, 200, 200, 250)  # Ví dụ cho vùng shield
ROI_FURY = (300, 200, 400, 250)    # Vùng fury
ROI_RALLY = (500, 200, 600, 300)   # Vùng rally list

# Thư mục templates (chứa hình template cho detection)
TEMPLATES_DIR = 'templates/'

# File lưu data lịch sử
DATA_FILE = 'data/history.json'

# Filters tùy chỉnh
FILTERS = {
    'kingdom': [1, 2, 3],  # Kingdoms cần track
    'might_min': 1000     # Might tối thiểu
}