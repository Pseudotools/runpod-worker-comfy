# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/Pseudotools/ComfyUI.git /comfyui

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    && pip3 install --upgrade -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Stage 2: Download models
FROM base as downloader

# Change working directory to ComfyUI
WORKDIR /comfyui


# Create Ipadapter model subdirectory
RUN mkdir -p models/ipadapter

# Clone the Pseudocomfy repository into the custom_nodes/Pseudocomfy subfolder
RUN git clone https://github.com/Pseudotools/Pseudocomfy.git custom_nodes/Pseudocomfy

# Clone the ComfyUI_IPAdapter_plus repository into the custom_nodes/ComfyUI_IPAdapter_plus subfolder
RUN git clone https://github.com/Pseudotools/ComfyUI_IPAdapter_plus.git custom_nodes/ComfyUI_IPAdapter_plus



# Stage 3: Final image
FROM base as final

# Copy models from stage 2 to the final image (even if we didn't download any)
COPY --from=downloader /comfyui/models /comfyui/models

# Copy custom_nodes from stage 2 to the final image
COPY --from=downloader /comfyui/custom_nodes /comfyui/custom_nodes

# Start the container
CMD /start.sh