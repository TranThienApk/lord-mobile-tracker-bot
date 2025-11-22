# Lord Mobile Tracker Bot

Bot tự động theo dõi và thông báo cho Lord Mobile, sử dụng computer vision và OCR.

## Tính năng
- **Theo dõi Shield**: Phát hiện khi shield lên/xuống.
- **Theo dõi Fury**: Thông báo khi fury timer active.
- **Rally Targets**: Tìm mục tiêu rally dựa trên filters (kingdom, might).
- **Inactive Players**: Phát hiện players không hoạt động.
- **Notifications**: Gửi tin nhắn qua Discord webhook.
- **Data Storage**: Lưu lịch sử để theo dõi thay đổi.
- **Filters**: Tùy chỉnh kingdom, might min.
- **Anti-ban**: Chỉ capture screen, không tương tác server.

## Cài đặt
1. Clone repo: `git clone https://github.com/TranThienApk/lord-mobile-tracker-bot.git`
2. Cài dependencies: `pip install -r requirements.txt`
3. Cài Tesseract OCR: Tải từ https://github.com/UB-Mannheim/tesseract
4. Tạo thư mục `templates/` và thêm hình template (e.g., `shield_template.png` - chụp từ game).
5. Tạo thư mục `data/`.
6. Chỉnh `config.py`: Điền webhook Discord, đường dẫn Tesseract, ROI.

## Hướng dẫn sử dụng
1. Mở emulator (Bluestacks/Nox) và chạy Lord Mobile.
2. Điều chỉnh ROI trong `config.py` bằng cách chụp screen và xem tọa độ.
3. Chạy bot: `python tracker_bot.py`
4. Bot sẽ chạy liên tục, gửi thông báo khi phát hiện.

### Cấu hình ROI
- Sử dụng tool như PyAutoGUI để lấy tọa độ: `pyautogui.position()` khi hover vùng cần track.
- Ví dụ: Shield ở góc trên trái, ROI = (50, 50, 150, 100).

### Templates
- Chụp hình element từ game (e.g., icon shield) và lưu vào `templates/`.
- Bot sẽ match với threshold 0.8.

### Discord Webhook
- Tạo webhook trong server Discord: Settings > Integrations > Webhooks.
- Paste URL vào `config.py`.

### An toàn
- Chạy cục bộ, chỉ đọc screen.
- Không dùng cho cheating công khai để tránh ban.

Nếu cần hỗ trợ, tạo issue trên GitHub.