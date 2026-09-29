# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (Production-Ready Multi-Stage Build)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# Cache layer: copy requirements và cài đặt dependency trước
COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

# Tạo non-root user để tăng tính bảo mật
RUN useradd --create-home --shell /bin/bash appuser

# Copy các thư viện đã build từ stage builder sang /usr/local
COPY --from=builder /install /usr/local

# Copy source code
COPY . .

# Phân quyền thư mục app cho appuser
RUN chown -R appuser:appuser /app

USER appuser

ENV PORT=8000 \
    PYTHONUNBUFFERED=1

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, os; urllib.request.urlopen('http://localhost:' + str(os.getenv('PORT', 8000)) + '/health')" || exit 1

EXPOSE 8000

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
