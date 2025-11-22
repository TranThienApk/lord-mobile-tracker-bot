# Hướng Dẫn Sử Dụng HTTP Canary cho Lords Mobile 📱

## 1. Tải xuống và cài đặt HTTP Canary trên Android 📥
- Truy cập vào [Google Play Store](https://play.google.com/store/apps/details?id=com.rulemkr.httpcanary) để tải xuống ứng dụng.
- Nhấn vào nút "Cài đặt" và chờ cho quá trình hoàn tất.

## 2. Thiết lập chứng chỉ để kiểm tra HTTPS 🔑
- Mở ứng dụng HTTP Canary sau khi cài đặt.
- Vào phần "Cài đặt" (Settings) > "Chứng chỉ" (Certificates).
- Nhấn "Cài đặt chứng chỉ" (Install Certificate) và làm theo hướng dẫn.
  - Lưu ý: Bạn cần phải cấp quyền cho phép ứng dụng.

## 3. Cấu hình HTTP Canary để bắt lưu lượng của Lords Mobile ⚙️
- Sau khi cài đặt chứng chỉ, quay lại giao diện chính của ứng dụng.
- Nhấn vào "Bắt đầu Capture" (Start Capture).
- Mở game Lords Mobile để bắt đầu ghi lại lưu lượng.

## 4. Cách tìm và trích xuất các API endpoint 📡
- Trong giao diện HTTP Canary, mẫu hình dữ liệu sẽ được thể hiện.
- Tìm endpoint như: `lmapi-ap-seoul.lordsmobile.igg.com/api/get_castle_detail` trong danh sách các yêu cầu.

## 5. Cách sao chép Authorization headers, tokens, cookies 🗝️
- Nhấp vào yêu cầu mà bạn muốn kiểm tra.
- Kéo xuống phần "Headers" để tìm các thông tin cần thiết như Authorization headers hoặc cookies.
- Chọn và sao chép nội dung tương ứng.

## 6. Cách tìm Castle IDs và Player IDs 🏰
- Qua các yêu cầu, chú ý đến các thông số đi kèm trong URL hoặc headers.
- Castle ID và Player ID thường xuất hiện trong các yêu cầu gửi đi khi có hành động trong game.

## 7. Cách xuất dữ liệu (cURL, JSON) 📂
- Chọn yêu cầu mà bạn muốn xuất.
- Nhấn vào nút "Export" và chọn định dạng bạn muốn (cURL hoặc JSON).

## 8. Mô tả các hình ảnh mà bạn cần chú ý 📸
- Hãy nhớ chụp ảnh các bước thiết lập cũng như các yêu cầu đang diễn ra chính xác trong quá trình sử dụng.
- Những hình ảnh này giúp bạn dễ dàng nhớ lại quá trình thực hiện.

## 9. Các vấn đề thường gặp trong quá trình thực hiện ⚠️
- Nếu không bắt được lưu lượng, kiểm tra lại xem chứng chỉ đã được cài đặt chưa.
- Kiểm tra xem HTTP Canary có đang chạy và đang trong trạng thái "Capture" không.

## 10. Cảnh báo an ninh về tokens 🔒
- Không chia sẻ token của bạn với người khác.
- Hãy đảm bảo rằng bạn chỉ sử dụng token trong ứng dụng mà bạn đã thiết lập.
- Đừng lưu trữ token trong các ứng dụng không bảo mật.

---

Hy vọng hướng dẫn này hữu ích cho bạn trong việc sử dụng HTTP Canary để theo dõi và phân tích lưu lượng game Lords Mobile!