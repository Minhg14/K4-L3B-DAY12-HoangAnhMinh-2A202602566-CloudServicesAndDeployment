# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Hoàng Anh Minh  Mã học viên: 2A202602566

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi đưa code lên môi trường Cloud/Production mà người quản trị quên cấu hình biến môi trường `AGENT_API_KEY`, nếu để mặc định `"changeme"` thì service vẫn khởi động bình thường. Các bot tự động quét lỗ hổng trên Internet có thể dùng ngay khóa mặc định `"changeme"` để gọi API `/ask` miễn phí và đốt sạch ngân sách LLM của hệ thống mà ta không hề hay biết cho đến khi nhận hóa đơn. Ngược lại, cơ chế "fail fast" làm app crash ngay lập tức từ lúc start, báo lỗi rõ ràng trên log deployment, buộc người triển khai phải bổ sung secret key an toàn trước khi service có thể nhận bất kỳ traffic nào.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log JSON thu được:
> `{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T05:11:51.815779+00:00", "user_id": "sv-test", "tokens_in": 39, "tokens_out": 47, "cost_usd": 3.405e-05}`
> 
> Hai việc làm được với dòng log JSON này:
> 1. **Theo dõi và cảnh báo chi phí theo thời gian thực (Cost Monitoring & Alerting):** Các công cụ phân tích log (như Datadog, Grafana Loki, CloudWatch) có thể parse trực tiếp trường `cost_usd` để vẽ biểu đồ chi phí tiêu hao của từng user và gửi alert khi chi phí tăng đột biến.
> 2. **Tìm kiếm, lọc và thống kê có cấu trúc (Structured Querying):** Có thể lọc chính xác các request theo `user_id == "sv-test"` hoặc tính tổng số tokens tiêu thụ (`tokens_in + tokens_out`) trong một khoảng thời gian bằng truy vấn SQL/JSON query thay vì phải viết regex bóc tách chuỗi thô phức tạp và dễ vỡ.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1020 MB |
| Multi-stage | ~272 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần dung lượng chênh lệch (~750 MB) bao gồm:
> - Base image ban đầu dùng `python:3.11` đầy đủ vốn chứa toàn bộ hệ thống Debian build tools, trình biên dịch C/C++ (`gcc`, `g++`, `make`), header files, package manager caches và tài liệu hướng dẫn.
> - Bản multi-stage dùng `python:3.11-slim` cho runtime stage, đồng thời chỉ copy thư mục dependencies đã được cài sẵn (`/install` sang `/usr/local`) từ builder stage sang runtime. Toàn bộ compiler và công cụ build bị loại bỏ hoàn toàn khỏi image cuối cùng, giúp image gọn nhẹ, bảo mật hơn và kéo về/khởi động nhanh hơn nhiều trên cloud.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Với Dockerfile hiện tại:
> - Các layer tải base image, tạo user, `COPY requirements.txt` và `RUN pip install` trong builder stage đều được tái sử dụng hoàn toàn từ Docker cache (`CACHED`).
> - Chỉ có layer `COPY . .` và `RUN chown` trong runtime stage là phải chạy lại vì nội dung source code bị thay đổi. Quá trình rebuild chỉ mất chưa tới 2 giây.
> - Nếu đặt `COPY . .` lên trước `RUN pip install`, mỗi lần ta sửa bất kỳ ký tự nào trong code, checksum của build context thay đổi làm mất hiệu lực toàn bộ cache từ điểm đó trở đi. Docker sẽ buộc phải chạy lại lệnh `RUN pip install -r requirements.txt` từ đầu (tải lại toàn bộ FastAPI, Pydantic, Redis...), gây tốn băng thông và mất từ 1 đến 2 phút cho mỗi lần build.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện:
> 1. Kẻ tấn công phát hiện một lỗ hổng thực thi mã từ xa (RCE) trong code Python (ví dụ: qua deserialization hoặc command injection).
> 2. Kẻ tấn công chiếm quyền điều khiển tiến trình Python. Vì container chạy mặc định bằng root, tiến trình này có UID 0 (root) bên trong container.
> 3. Tận dụng quyền root này, kẻ tấn công khai thác lỗ hổng kernel của máy host hoặc các volume mount nhạy cảm (như docker.sock) để thực hiện "container escape".
> 4. Khi thoát ra được khỏi container, do tiến trình ban đầu là UID 0 nên kẻ tấn công nghiễm nhiên sở hữu quyền root (cao nhất) trên máy host.
> 
> Lệnh `USER appuser` cắt đứt chuỗi ngay ở bước 2: Tiến trình ứng dụng bị giới hạn dưới quyền của một user thông thường (non-root UID 1000). Kể cả khi khai thác được RCE, kẻ tấn công chỉ có quyền đọc/ghi hạn chế trong phạm vi được cấp phép, không thể can thiệp tài nguyên hệ thống hay thực hiện container escape để leo thang đặc quyền root trên máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Một người dùng có thể gửi tối đa **20 request trong 2 giây liên tiếp**.
> Cách đạt được:
> - Người dùng gửi 10 request vào giây cuối cùng của phút thứ nhất (ví dụ: 10:00:59). Hệ thống đếm đủ 10 request cho phút đó và cho qua.
> - Ngay sang giây tiếp theo (10:01:00), đồng hồ bước sang phút mới và bộ đếm fixed window tự động reset về 0.
> - Người dùng lập tức gửi tiếp 10 request nữa trong giây 10:01:00.
> Kết quả: Đúng luật theo từng phút đồng hồ (10 req ở phút 10:00 và 10 req ở phút 10:01), nhưng thực tế trong khoảng thời gian 2 giây (10:00:59 – 10:01:00) hệ thống đã phải gánh tới 20 request, gây quá tải đột biến (traffic burst). Sliding window 60s giải quyết triệt để lỗi này bằng cách luôn tính lùi đúng 60 giây từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Sự khác biệt:
> - **Rate Limit**: Giới hạn **số lượng/tần suất request** trong một cửa sổ thời gian ngắn (ngăn chặn DoS, spam gọi API dồn dập).
> - **Cost Guard**: Giới hạn **tổng chi phí tài chính (USD)** phát sinh do sử dụng LLM tokens trong một chu kỳ dài (tháng) (ngăn ngừa cạn kiệt ngân sách).
> 
> Tình huống cụ thể:
> - **Rate limit cho qua nhưng Cost guard chặn:** Một người dùng gọi API rất thưa thớt (chỉ 1 request mỗi 10 phút, hoàn toàn nằm trong hạn mức 10 req/phút). Tuy nhiên tài khoản của họ đã tích lũy chi phí đạt ngưỡng ngân sách tháng 10.0$ từ trước -> Rate limit cho qua nhưng Cost guard chặn ngay bằng HTTP 402 Payment Required.
> - **Cost guard cho qua nhưng Rate limit chặn:** Một người dùng mới toanh chưa tiêu đồng nào (ngân sách còn nguyên 10.0$). Người này dùng script gửi liên tục 15 request chỉ trong vòng 5 giây -> Cost guard thừa ngân sách cho phép, nhưng Rate limit sẽ chặn từ request thứ 11 bằng HTTP 429 Too Many Requests để bảo vệ server khỏi bị nghẽn tải.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện:
> 1. Redis gặp sự cố hoặc gián đoạn mạng trong 30 giây.
> 2. Container orchestrator (Docker/Kubernetes/Railway) định kỳ gọi liveness probe `/health` tới cả 3 container.
> 3. Do `/health` bị gộp kiểm tra cả Redis, cả 3 container đồng loạt trả về lỗi (503 hoặc fail probe).
> 4. Orchestrator hiểu lầm rằng toàn bộ tiến trình ứng dụng đã chết hoặc bị treo (deadlock), lập tức phát tín hiệu restart (kill và khởi động lại) cả 3 container.
> 5. Khi các container vừa khởi động lại, Redis vẫn chưa online, probe tiếp tục fail, orchestrator lại restart tiếp -> Cả cụm rơi vào vòng lặp tử thần **CrashLoopBackOff**.
> 6. Khi Redis phục vụ trở lại, các container vẫn đang bị restart liên tục hoặc bận nạp lại môi trường, khiến thời gian ngừng dịch vụ (downtime) kéo dài hơn nhiều so với thực tế 30 giây của Redis.
> (Khi tách riêng: `/health` độc lập giúp giữ container sống nguyên vẹn, còn `/ready` báo 503 để load balancer tạm thời không chuyển traffic cho đến khi Redis kết nối lại).

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Nếu lịch sử hội thoại được lưu trong một dict Python nội bộ của process (in-memory RAM):
> - Khi gọi `/ask` liên tiếp, load balancer phân phối các request ngẫu nhiên (hoặc round-robin) tới 3 container khác nhau (A, B, C).
> - Request 1 vào container A: A ghi vào RAM của nó, trả lời `history_length = 0`.
> - Request 2 vào container B: RAM của B hoàn toàn trống, trả lời `history_length = 0` (agent bị "mất trí nhớ", không biết câu hỏi ở lượt 1).
> - Request 3 vào container C: C cũng trống, trả lời `history_length = 0`.
> - Request 4 lại rơi vào container A: A thấy 2 tin nhắn trước đó của nó, trả lời `history_length = 2`.
> Con số `history_length` sẽ nhảy lộn xộn không thể đoán trước (0, 0, 0, 2, 0, 4...) và câu trả lời của agent bị phân mảnh. Ngược lại, khi lưu state tập trung vào Redis, mọi container đều đọc ghi chung một dữ liệu, giúp `history_length` tăng đều đặn (0 -> 2 -> 4 -> 6...).

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> - **Lỗi gặp phải:** Khi vừa deploy lên Railway và tạo domain công khai, endpoint `/health` trả về 200 OK nhưng gọi `/ready` và `/ask` đều trả về `500 Internal Server Error`.
> - **Cách tìm nguyên nhân:** Kiểm tra mã nguồn thấy `/ready` và `/ask` đều gọi đến hàm lấy cấu hình `get_settings()`, trong khi đó `Settings` yêu cầu biến bí mật `agent_api_key: str` bắt buộc không có giá trị mặc định. Nếu thiếu biến môi trường trên dashboard thì Pydantic sẽ ném ra lỗi `ValidationError` làm sập request với mã 500 (Fail-fast). Đồng thời kiểm tra lại tab Variables trên Railway thấy ban đầu chưa gán `AGENT_API_KEY` và `REDIS_URL`.
> - **Cách sửa:** Vào tab **Variables** của service `agent` trên Railway, thêm biến `AGENT_API_KEY` bằng giá trị khóa cá nhân (`XvmjdFzekofoDFZ0iA6VOAPS-JnP9SXtbgKAmo_JZo8`) và `REDIS_URL=${{Redis.REDIS_URL}}`. Sau khi Railway tự động redeploy với đầy đủ biến môi trường, cả `/ready` và `/ask` đều hoạt động hoàn hảo và trả về mã 200 OK.
