# Stage 1: compile llama-server (speculative decoding fork) for CC 8.6
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends git cmake build-essential curl libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*
# Pin to a commit SHA for reproducible builds: --build-arg SOURCE_REF=<sha>
# (fetch-by-ref works for branches, tags and arbitrary SHAs, unlike a shallow clone + checkout)
ARG SOURCE_REF=master
WORKDIR /src
RUN git init -q . \
    && git remote add origin https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant.git \
    && git fetch --depth 1 origin "$SOURCE_REF" \
    && git checkout -q FETCH_HEAD \
    && git submodule update --init --recursive --depth 1
# CI runners have no GPU driver — use the CUDA stub library for linking.
# cuMem* VMM functions are absent from the stub; GGML_CUDA_NO_VMM=ON removes that dependency.
RUN ln -sf /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
RUN cmake -B build \
        -DGGML_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES=86 \
        -DGGML_CUDA_NO_VMM=ON \
        -DLLAMA_SERVER_WEBUI=OFF \
        -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda" \
    && cmake --build build --config Release --target llama-server -j"$(nproc)"

# Stage 2: minimal runtime
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04
RUN apt-get update \
    && apt-get install -y --no-install-recommends libcurl4 curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /src/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder /src/build/bin/*.so* /usr/local/lib/
ENV LD_LIBRARY_PATH=/usr/local/lib
# Fix 16: build-time smoke check — fails the build if the binary or shared libs are broken
RUN llama-server --version 2>/dev/null || llama-server --help >/dev/null 2>&1
EXPOSE 8080
ENTRYPOINT []
CMD ["llama-server", "--host", "0.0.0.0", "--port", "8080"]
