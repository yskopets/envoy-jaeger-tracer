## Build image.
FROM ubuntu:18.04 AS builder

RUN apt-get update     \
 && apt-get install -y \
      clang-9          \
      curl             \
      git              \
      libc++-9-dev     \
      libc++abi-9-dev  \
      make             \
 && rm -rf /var/lib/apt/lists/*

RUN curl -L -O "https://cmake.org/files/v3.11/cmake-3.11.0-Linux-x86_64.sh" \
 && bash cmake-3.11.0-Linux-x86_64.sh --skip-license \
 && rm cmake-3.11.0-Linux-x86_64.sh

RUN update-alternatives                                         \
      --install /usr/bin/cc  cc  /usr/lib/llvm-9/bin/clang   20 \
      --slave   /usr/bin/c++ c++ /usr/lib/llvm-9/bin/clang++    \
 && update-alternatives                                         \
      --install /usr/bin/gcc gcc /usr/lib/llvm-9/bin/clang   21 \
      --slave   /usr/bin/g++ g++ /usr/lib/llvm-9/bin/clang++

RUN mkdir /source \
 && cd /source    \
 && git clone -b v0.4.2 https://github.com/jaegertracing/jaeger-client-cpp \
 && cd jaeger-client-cpp

WORKDIR /source/jaeger-client-cpp

COPY v0.4.2.patch v0.4.2.patch

RUN git apply --ignore-space-change v0.4.2.patch

# Must produce a library at /libjaegertracing_plugin.so
RUN scripts/build-plugin.sh

## Distro image.
FROM scratch

# Notice that this image is not runnable by itself and should only be used
# as a source of artifacts for building other images.
COPY --from=builder /libjaegertracing_plugin.so /libjaegertracing_plugin.so
