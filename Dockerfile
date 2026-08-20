FROM python:3.7-slim-bullseye AS builder
WORKDIR /app
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
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel
RUN pip install --default-timeout=1000 --no-cache-dir -r requirements.txt

RUN pip install --default-timeout=1000 --no-cache-dir \
    detectron2==0.6 \
    -f https://dl.fbaipublicfiles.com/detectron2/wheels/cpu/torch1.8/index.html
COPY . .

FROM python:3.7-slim-bullseye
WORKDIR /app
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local /usr/local
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
