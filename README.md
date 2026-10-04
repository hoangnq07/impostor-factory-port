# Impostor Factory - Port cho ArkOS / R36S (PortMaster)

Bản port game **Impostor Factory (To the Moon 3)** dành cho các thiết bị máy chơi game cầm tay chạy **ArkOS** (như R36S, Anbernic RK3326).

## Đặc điểm bản Port
- Sử dụng engine **mkxp-freebird** kèm runtime glibc 2.35 tương thích tốt với cả ArkOS mới lẫn ArkOS legacy.
- **Việt Hóa 100%**: Tích hợp font tiếng Việt và patch tên UMS fix font.
- **Tối ưu hiệu năng & Làm sạch log**:
  - Đã làm sạch metadata lỗi `iCCP` trên toàn bộ 370 file PNG của game, triệt tiêu cảnh báo `libpng` và giải phóng nghẽn I/O ghi thẻ nhớ SD.
  - Cấu hình `mkxp.conf` chuẩn (`frameSkip=false`, `subImageFix=false`) giúp game mượt mà ở 40 FPS.
  - Tự động kích hoạt Governor CPU/GPU `performance`.

## Cài đặt trên ArkOS (R36S)
1. Chép file `Impostor Factory.sh` vào thư mục `/roms/ports/` (hoặc `/roms2/ports/`).
2. Chép toàn bộ thư mục `impostorfactory/` vào `/roms/ports/impostorfactory/`.
3. Khởi động lại EmulationStation hoặc vào mục **Ports** để chọn và chơi game.

## Điều khiển (Controls)
- **D-Pad / Cần Analog trái**: Di chuyển nhân vật / Di chuyển chuột
- **Nút A**: Tương tác / Đồng ý (`Enter` / `Input::C`)
- **Nút B**: Hủy / Menu (`Esc` / `Input::B`)
- **Nút X**: Chạy nhanh (`Shift`)
- **Nút Y**: Giảm tốc độ chuột
- **Nút R1**: Chuột trái
- **Nút L1**: Chuột phải
- **Nút L2 / R2**: Đổi trang menu (`Q` / `W`)
- **Start**: `Enter`
- **Select + Start**: Thoát game
