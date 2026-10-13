# WeChat Download API - Docker Image
# Multi-stage build for smaller image size

FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies（2026-10-13 起从 requirements.lock 安装 —— 全量锁定，
# 消除范围声明导致的「同 Dockerfile 不同依赖」不可复现问题；升级流程：改
# requirements.txt 范围 → 重新生成 lock → 重建验证）
COPY requirements.lock .
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --wheel-dir=/app/wheels -r requirements.lock


FROM python:3.11-slim

LABEL maintainer="tmwgsicp"
LABEL description="WeChat Official Account Article Download API with RSS Support"
LABEL version="1.0.5"

WORKDIR /app

# Install runtime dependencies (curl for healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels from builder and install
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

# Copy application code
COPY . .

# Create data directory
RUN mkdir -p /app/data

# Environment variables with sensible defaults
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HOST=0.0.0.0 \
    PORT=5000 \
    DEBUG=false

EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:5000/api/health || exit 1

# Run with uvicorn
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"]
