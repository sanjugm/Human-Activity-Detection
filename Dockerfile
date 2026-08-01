# ==========================================
# Stage 1 - Builder
# ==========================================
FROM python:3.7-slim-bullseye AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Upgrade pip
RUN pip install --upgrade pip setuptools wheel

# Install project dependencies
RUN pip install --default-timeout=1000 --no-cache-dir -r requirements.txt

# Install Detectron2
RUN pip install --default-timeout=1000 --no-cache-dir \
    detectron2==0.6 \
    -f https://dl.fbaipublicfiles.com/detectron2/wheels/cpu/torch1.8/index.html

# Copy application
COPY . .

# ==========================================
# Stage 2 - Runtime
# ==========================================
FROM python:3.7-slim-bullseye

WORKDIR /app

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages
COPY --from=builder /usr/local /usr/local

# Copy application files
COPY . .

# Flask Port
EXPOSE 5000

# Start application
CMD ["python", "app.py"]
