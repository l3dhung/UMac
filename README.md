# ⚡ UMac — Tiện Ích Tất-Cả-Trong-Một Cho Mac (Apple Silicon & Intel)

[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/l3dhung/UMac/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-black.svg)](https://github.com/l3dhung/UMac)
[![Chip](https://img.shields.io/badge/chip-Apple%20Silicon%20%7C%20Intel-brightgreen.svg)](https://github.com/l3dhung/UMac)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

> 🚀 **UMac** là app menu bar viết bằng **Swift thuần** cho máy Mac, gom nhiều tiện ích vào một icon:
>
> **Chia cửa sổ** (kiểu Rectangle) + **Chuyển cửa sổ trực quan** (kiểu AltTab) + **Lịch sử Clipboard** (kiểu Maccy) + **Dọn dẹp máy** (kiểu CleanMyMac) + **Khóa sạc 80%** (Apple Silicon) + **Màn hình ngoài** + **Nhiệt độ, quạt & công suất** + **Đo tốc độ chép file**.
>
> UMac là bản fork của [HyperMac](https://github.com/mrgoose000000-gif/HyperMac) (MIT) — xem [Tác giả & Bản quyền](#-tác-giả--bản-quyền).

---

## 📥 TẢI VỀ & CÀI ĐẶT NHANH (Trong 30 Giây)

### ⬇️ Bước 1: Tải bộ cài dựng sẵn
Bấm vào nút bên dưới để tải về phiên bản mới nhất:

[![Download UMac](https://img.shields.io/badge/📥_TẢI_VỀ-UMac.zip_(v1.0.0)-2563EB?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/l3dhung/UMac/releases/latest/download/UMac.zip)

*(Hoặc vào trang [GitHub Releases](https://github.com/l3dhung/UMac/releases) để xem danh sách tất cả các bản phát hành).*

---

### 📦 Bước 2: Cài đặt vào máy
1. Nhấp đúp vào tệp **`UMac.zip`** vừa tải về để giải nén ra ứng dụng **`UMac.app`**.
2. **Kéo tệp `UMac.app` vào thư mục `Applications` (Ứng dụng)** của máy Mac.

---

### 🛡️ Bước 3: Mở app & Xử lý cảnh báo bảo mật macOS (Làm 1 lần duy nhất)

Do UMac là phần mềm mã nguồn mở miễn phí (chưa mua chứng chỉ Apple Developer trả phí 99$/năm), khi bạn mở app lần đầu, macOS Gatekeeper sẽ hiện thông báo:
> *"UMac Not Opened: Apple could not verify that UMac is free of malware..."*

Để mở app, bạn chỉ cần chọn **1 trong 2 cách** rất đơn giản:

#### 👉 Cách A: Dùng chuột (Không cần gõ lệnh)
1. Bấm nút **Done** trên bảng thông báo cảnh báo.
2. Mở **Cài đặt hệ thống (System Settings)** ➔ chọn mục **Quyền riêng tư & Bảo mật (Privacy & Security)**.
3. Cuộn xuống mục **Bảo mật (Security)**, bạn sẽ thấy thông báo *"UMac was blocked..."*.
4. Bấm nút **"Open Anyway" (Vẫn mở)** ➔ Quét Touch ID hoặc nhập mật khẩu máy để xác nhận.

#### 👉 Cách B: Dùng Terminal (Nhanh nhất trong 1 giây)
Mở ứng dụng **Terminal** trên Mac, dán dòng lệnh sau rồi ấn **Enter**:
```bash
xattr -cr /Applications/UMac.app
```
Sau đó mở UMac bình thường từ Spotlight (`Cmd + Space` gõ `UMac`) hoặc trong Launchpad!

---

### 🔐 Bước 4: Cấp quyền hoạt động
Để các tính năng chia cửa sổ và phím tắt hoạt động mượt mà, hãy bật 2 quyền sau:
1. **Trợ năng (Accessibility):** Vào *Cài đặt hệ thống ➔ Quyền riêng tư & Bảo mật ➔ Trợ năng* $\rightarrow$ Gạt bật **UMac**. (Dùng để nhận phím tắt chia cửa sổ, F1/F2 và AltTab).
2. **Ghi màn hình (Screen Recording - Tùy chọn):** Vào *Quyền riêng tư & Bảo mật ➔ Ghi màn hình & Âm thanh hệ thống* $\rightarrow$ Gạt bật **UMac** để hiển thị ảnh chụp nội dung thực tế trong thẻ chuyển tab AltTab.
3. **Quyền điều khiển sạc pin SMC (chỉ Apple Silicon):** Trong tab *Phần cứng*, bấm **Cấp quyền** và nhập mật khẩu 1 lần. Helper chỉ cho đúng tài khoản của bạn chạy 3 lệnh bật/tắt/đọc trạng thái sạc. Nếu app báo *"helper cũ không an toàn"*, bấm **Gỡ ngay**.

> 💡 **Sau khi cập nhật lên bản mới:** UMac tự kiểm tra và khôi phục quyền Trợ năng. Nếu macOS hiện hộp thoại xin quyền, bạn chỉ cần bật lại **UMac** trong *Trợ năng* — không cần xoá app khỏi danh sách rồi thêm lại. Trường hợp hiếm vẫn bị kẹt, xem [mục 5 trong FAQ](#-câu-hỏi-thường-gặp-faq).

---

## 🎮 BẢNG HƯỚNG DẪN SỬ DỤNG & PHÍM TẮT

UMac nằm gọn gàng trên thanh Menu Bar góc trên bên phải (biểu tượng `⌘`). Dưới đây là phím tắt của các tính năng:

### 🪟 1. Chia Cửa Sổ (Thay thế Rectangle)
Điều khiển cửa sổ siêu tốc độ trễ 0ms, tự động căn chuẩn tỷ lệ khi chuyển màn hình:

| Thao tác | Phím tắt mặc định | Mô tả |
| :--- | :--- | :--- |
| **Nửa trái** | `⌃ Control + ⌥ Option + ←` | Cửa sổ chiếm 50% bên trái |
| **Nửa phải** | `⌃ Control + ⌥ Option + →` | Cửa sổ chiếm 50% bên phải |
| **Toàn màn hình** | `⌃ Control + ⌥ Option + ↵` (hoặc `↑`) | Phóng to cửa sổ đầy màn hình |
| **Căn giữa** | `⌃ Control + ⌥ Option + ↓` | Thu cửa sổ về chính giữa màn hình |
| **Chuyển sang màn hình khác** | `⌃ Control + ⌥ Option + ⌘ Command + →` | Chuyển cửa sổ sang màn hình phụ/chính |

---

### 🔀 2. Chuyển Đổi Cửa Sổ Trực Quan (Thay thế AltTab)
Trình chuyển đổi cửa sổ dạng xem trước trực quan (Thumbnail Live Preview) cực xịn:
* **Mở trình chuyển đổi:** Nhấn giữ **`⌘ Command + Tab`** (hoặc `⌥ Option + Tab`).
* **Chuẩn MRU:** Đảo nhanh giữa 2 cửa sổ gần nhất chỉ bằng 1 cú nhấp thả.
* **Điều hướng:**
  * Bấm `Tab` để chọn tiếp, bấm `~` để lùi lại.
  * Bấm phím **`W`**: Đóng nhanh cửa sổ đang chọn.
  * Bấm phím **`Q`**: Thoát hẳn ứng dụng đó (`Quit`).
  * Bấm phím **`Esc`**: Hủy chuyển đổi.

---

### 📋 3. Lịch Sử Clipboard (Thay thế Maccy)
Lưu trữ lịch sử văn bản, hình ảnh, liên kết, mã màu đã sao chép:
* **Mở Clipboard:** Bấm **`⌘ Command + ⇧ Shift + C`** (hoặc `⌘ + ⇧ + V`).
* **Dán siêu tốc:** Bấm phím số **`1` đến `9`** để dán tức thì dòng tương ứng vào văn bản mà không cần click chuột.
* **Thao tác nhanh:**
  * Bấm **`↵ Enter`**: Dán mục đang chọn.
  * Bấm **`⌥ Option + P`**: Ghim / Bỏ ghim mục quan trọng lên đầu.
  * Bấm **`⌥ Option + ⌫ Delete`**: Xóa mục khỏi lịch sử.
  * Gõ chữ để tìm kiếm nhanh nội dung trong lịch sử.
* **Bảo mật:** Tự động phát hiện và bỏ qua mật khẩu từ Keychain, 1Password, Bitwarden...

---

### 🔋 4. Khóa Sạc Pin 80% & Sleep Guard (Thay thế AlDente Pro)
Bảo vệ phần cứng tối đa, đặc biệt phù hợp cho các dòng MacBook cắm sạc liên tục:
* **Khóa sạc ở 80% (SMC AC Bypass):** Ghi trực tiếp vào chip điều khiển nguồn Apple Silicon, ngắt dòng điện vào cell pin khi đạt 80%. Máy chuyển sang chạy điện củ sạc 100%, triệt tiêu nguy cơ phồng pin, chai pin.
* **Nút Sạc Đầy (Top-Up 100%):** Bấm nút sạc đầy tạm thời khi chuẩn bị mang máy ra ngoài.
* **Sleep Guard:** Tự động duy trì lệnh ngắt sạc khi gập máy và tự tắt Bluetooth để chống tụt pin qua đêm (0% hao hụt pin).

---

### 🖥️ 5. Màn Hình Ngoài & Chỉnh Độ Sáng (Thay thế BetterDisplay)
* **Chỉnh sáng màn hình ngoài bằng `F1 / F2`:** Bấm phím F1/F2 trên bàn phím Mac để tăng/giảm độ sáng màn hình rời. Hiện làm tối bằng phần mềm (bảng gamma), chưa chỉnh đèn nền qua DDC/CI.
* **Ngắt mềm màn ngoài (Software Sleep):** Tắt tạm thời tín hiệu màn ngoài khi không dùng mà không cần rút dây cáp Type-C/HDMI.

---

### 🧹 Dọn Dẹp Máy (Tương tự CleanMyMac)
Tab **Dọn dẹp** trên menu UMac:
* **Rác hệ thống:** bộ nhớ đệm, nhật ký, cache Xcode/Simulator, npm, Gradle. Không đụng dữ liệu của Apple; app đang chạy được tự bỏ chọn.
* **Gỡ ứng dụng:** gỡ app kèm dữ liệu sót lại trong `~/Library` (Application Support, Caches, Preferences, Containers...).
* **File lớn:** tìm file > 100 MB / 500 MB / 1 GB / 5 GB trong thư mục người dùng bằng Spotlight.
* **An toàn:** mọi thứ chỉ được **chuyển vào Thùng rác** — vẫn khôi phục được bằng *Đưa trở lại* cho tới khi bạn dọn Thùng rác.

---

### ☕ 6. Chống Ngủ Màn Hình (Thay thế Amphetamine)
* Nhấp vào biểu tượng ly cafe trên menu UMac để giữ màn hình luôn sáng khi đang render video, tải file nặng hoặc thuyết trình (`15 phút`, `30 phút`, `1 giờ`, `Vô hạn`).

---

### 🖱️ 7. Mẹo Chuột: Mở Mission Control Siêu Nhanh
* Nhấp đồng thời **Chuột Trái + Chuột Phải** (hoặc nhấn giữ chuột trái rồi click chuột phải) $\rightarrow$ UMac sẽ lập tức mở **Mission Control** mà không cần với tay lên bàn phím!

---

## ❓ CÂU HỎI THƯỜNG GẶP (FAQ)

<details>
<summary><b>1. Máy Mac chip Intel có dùng được UMac không?</b></summary>

> **Có.** UMac tự nhận diện loại chip (có thể chọn tay ở thẻ *Nhiệt độ & Cảm biến*).
> - Chạy trên cả hai: chia cửa sổ, AltTab, Clipboard, Dọn dẹp, chống ngủ, đo tốc độ chép file, thông tin pin.
> - Trên Intel: nhiệt độ, tốc độ quạt và công suất được đọc qua SMC (chỉ đọc, không cần quyền admin).
> - **Chỉ Apple Silicon:** khóa sạc 80% và hiệu chuẩn pin.
</details>

<details>
<summary><b>2. Dùng bàn phím cơ ngoài (Aula, Keychron, RK...) bấm F3 lại bị chuyển tab?</b></summary>

> Hiện tượng này là do firmware của bàn phím cơ ngoài ở chế độ Windows tự động phát macro `Cmd+Tab` khi bấm F3.
> 
> **Cách xử lý:**
> - Bấm **`Fn + F3`** để gửi tín hiệu F3 nguyên bản.
> - Hoặc dùng phím tắt chuẩn macOS: **`Control + Mũi tên lên (⌃ + ↑)`** để mở Mission Control.
> - Hoặc click đồng thời **Chuột Trái + Chuột Phải** để mở Mission Control bằng chuột.
</details>

<details>
<summary><b>3. Làm thế nào để UMac tự động chạy khi mở máy Mac?</b></summary>

> Vào **Cài đặt hệ thống (System Settings) ➔ Cài đặt chung (General) ➔ Mục đăng nhập (Login Items)**. Tại ô "Mở khi đăng nhập", bấm dấu `+` và chọn file **`UMac.app`** trong thư mục Applications.
</details>

<details>
<summary><b>4. Cập nhật phiên bản mới như thế nào?</b></summary>

> Bạn không cần tải lại thủ công! Chỉ cần bấm vào icon UMac trên Menu Bar ➔ Bấm nút **"Kiểm tra cập nhật"** ở chân trang. Khi có bản mới, app sẽ hiển thị nội dung cập nhật, tự tải về và nâng cấp 1-chạm trong 2 giây.
</details>

<details>
<summary><b>5. Cập nhật xong thì mất quyền Trợ năng / phím tắt không chạy?</b></summary>

> Đây là di chứng của kiểu ký **ad-hoc**: mỗi bản build có "danh tính" (cdhash) khác nhau nên macOS coi là app mới và vô hiệu hoá quyền cũ — entry trong System Settings vẫn trông như đang bật nhưng không có tác dụng.
>
> UMac tự phát hiện và khôi phục: app reset entry TCC bị kẹt rồi hiện lại hộp thoại xin quyền. Bạn chỉ cần bật **UMac** trong *Trợ năng*.
>
> Bản phát hành được ký bằng chứng chỉ cố định, nên các lần cập nhật sau **không mất quyền nữa**.
>
> Nếu vẫn kẹt, làm thủ công:
> ```bash
> tccutil reset Accessibility com.l3dhung.umac
> open /Applications/UMac.app
> ```
> rồi bật lại UMac trong *Cài đặt hệ thống ➔ Quyền riêng tư & Bảo mật ➔ Trợ năng*.
</details>

---

## 🛠️ Dành Cho Lập Trình Viên (Tự Biên Dịch Từ Mã Nguồn)

Yêu cầu: macOS 14.0 trở lên (Apple Silicon hoặc Intel), Xcode Command Line Tools.

```bash
# 1. Clone mã nguồn
git clone https://github.com/l3dhung/UMac.git
cd UMac

# 2. (Khuyên dùng, 1 lần) Tạo chứng chỉ ký cố định để không mất quyền Trợ năng sau mỗi lần build
./scripts/setup-signing-identity.sh

# 3. Biên dịch, cài vào /Applications và chạy
./build.sh
```

---

## 📝 Nhật Ký Phiên Bản (Changelog)

### [v1.0.0] — 2026-10-31
Bản phát hành đầu tiên của UMac, fork từ HyperMac v1.6.0.
- 🧹 **Tab Dọn dẹp:** rác hệ thống (cache, log, Xcode, npm/Gradle), gỡ app kèm file sót, tìm file lớn. Mọi thứ chỉ chuyển vào Thùng rác.
- 💻 **Hỗ trợ Mac Intel:** % và sức khỏe pin đúng (Intel báo theo mAh), 30+ cảm biến nhiệt, tốc độ quạt, công suất CPU/GPU/hệ thống qua SMC; công tắc chọn loại chip.
- 🔐 **Helper khóa sạc an toàn hơn:** cài vào thư mục chỉ root ghi được, sudoers chỉ cho đúng user và 3 lệnh cố định; tự gỡ helper "ALL ALL NOPASSWD" của HyperMac cũ.
- 🛡️ **Bộ tự cập nhật kiểm tra chữ ký** trước khi cài; file tạm nằm trong thư mục riêng của user.
- 🩹 Quyền Trợ năng được khôi phục đúng cả khi đổi chữ ký mà giữ nguyên phiên bản.
- 🔧 Sửa lỗi biên dịch trên máy Intel.

Lịch sử trước đó: xem [changelog của HyperMac](https://github.com/mrgoose000000-gif/HyperMac#-nhật-ký-phiên-bản-changelog).

---

## 👤 Tác Giả & Bản Quyền
- **UMac** do [l3dhung](https://github.com/l3dhung) phát triển, dựa trên **HyperMac** của **Nguyễn Khắc Đại** ([@khacdai24](https://github.com/khacdai24)) & [mrgoose000000-gif](https://github.com/mrgoose000000-gif).
- Phát hành miễn phí dưới giấy phép **[MIT License](LICENSE)**, giữ nguyên thông báo bản quyền của tác giả gốc.
- Thành phần bên thứ ba: công cụ `Resources/smc` (dùng cho khóa sạc trên Apple Silicon) thuộc dự án smcFanControl, giấy phép **GPL-2.0** — xem [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
