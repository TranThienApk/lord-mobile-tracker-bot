import cv2
import numpy as np
import pytesseract
import pyautogui
import time
import os
import json
from discord import Webhook, RequestsWebhookAdapter
import logging

# Cấu hình logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class LordMobileTracker:
    def __init__(self, config_file='config.py'):
        # Load config
        from config import *
        self.discord_webhook_url = DISCORD_WEBHOOK_URL
        self.check_interval = CHECK_INTERVAL  # giây
        self.roi_shield = ROI_SHIELD  # (x1, y1, x2, y2)
        self.roi_fury = ROI_FURY
        self.roi_rally = ROI_RALLY
        self.templates_dir = TEMPLATES_DIR
        self.data_file = DATA_FILE
        self.filters = FILTERS  # {'kingdom': [1,2], 'might_min': 1000}

        # Khởi tạo Tesseract
        pytesseract.pytesseract.tesseract_cmd = TESSERACT_PATH

        # Load data lịch sử
        self.history = self.load_history()

        # Discord webhook
        if self.discord_webhook_url:
            self.webhook = Webhook.from_url(self.discord_webhook_url, adapter=RequestsWebhookAdapter())

    def capture_screen(self):
        """Capture màn hình từ emulator."""
        screenshot = pyautogui.screenshot()
        return cv2.cvtColor(np.array(screenshot), cv2.COLOR_RGB2BGR)

    def detect_element(self, img, template_name, threshold=0.8):
        """Detect element bằng template matching."""
        template_path = os.path.join(self.templates_dir, template_name)
        if not os.path.exists(template_path):
            logging.warning(f"Template {template_name} not found.")
            return None
        template = cv2.imread(template_path, 0)
        img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        res = cv2.matchTemplate(img_gray, template, cv2.TM_CCOEFF_NORMED)
        loc = np.where(res >= threshold)
        if loc[0].size > 0:
            return True
        return False

    def extract_text(self, img, roi):
        """Extract text từ ROI bằng OCR."""
        x1, y1, x2, y2 = roi
        cropped = img[y1:y2, x1:x2]
        text = pytesseract.image_to_string(cropped)
        return text.strip()

    def track_shield(self, img):
        """Theo dõi shield status."""
        shield_detected = self.detect_element(img, 'shield_template.png')
        return shield_detected

    def track_fury(self, img):
        """Theo dõi fury timer."""
        fury_text = self.extract_text(img, self.roi_fury)
        if "Fury" in fury_text:
            return True
        return False

    def track_rally_targets(self, img):
        """Tìm rally targets dựa trên filters."""
        rally_text = self.extract_text(img, self.roi_rally)
        # Giả sử text chứa might, kingdom
        # Parse và filter
        targets = []
        if "Might" in rally_text and any(k in rally_text for k in self.filters['kingdom']):
            targets.append({"player": "Parsed Player", "might": 1000})
        return targets

    def find_inactive_players(self, img):
        """Tìm inactive players (dựa trên activity heatmap - giả lập)."""
        # Giả lập: Nếu không có activity, inactive
        inactive = []
        # Logic thực: Scan map for inactive castles
        return inactive

    def send_notification(self, message):
        """Gửi thông báo Discord."""
        if self.webhook:
            self.webhook.send(message)

    def save_history(self):
        """Lưu data lịch sử."""
        with open(self.data_file, 'w') as f:
            json.dump(self.history, f)

    def load_history(self):
        """Load data lịch sử."""
        if os.path.exists(self.data_file):
            with open(self.data_file, 'r') as f:
                return json.load(f)
        return {"shields": [], "furys": []}

    def check_filters(self, target):
        """Kiểm tra filters cho target."""
        if target.get('might', 0) < self.filters['might_min']:
            return False
        return True

    def run(self):
        """Main loop."""
        logging.info("Starting Lord Mobile Tracker...")
        while True:
            img = self.capture_screen()

            # Track shield
            shield = self.track_shield(img)
            if shield != self.history.get('last_shield'):
                self.history['last_shield'] = shield
                msg = "Shield status changed!" if shield else "Shield down!"
                logging.info(msg)
                self.send_notification(msg)

            # Track fury
            fury = self.track_fury(img)
            if fury:
                logging.info("Fury active!")
                self.send_notification("Fury timer active!")

            # Track rally
            targets = self.track_rally_targets(img)
            for target in targets:
                if self.check_filters(target):
                    msg = f"Rally target: {target['player']} - Might: {target['might']}"
                    logging.info(msg)
                    self.send_notification(msg)

            # Track inactive
            inactive = self.find_inactive_players(img)
            for player in inactive:
                msg = f"Inactive player: {player}"
                self.send_notification(msg)

            # Save history
            self.save_history()

            time.sleep(self.check_interval)

if __name__ == "__main__":
    tracker = LordMobileTracker()
    tracker.run()