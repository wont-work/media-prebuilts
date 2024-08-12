# syntax = docker.io/docker/dockerfile:1

FROM ubuntu:noble AS media-libs-build
ARG TARGETARCH

ADD https://github.com/libvips/libvips/releases/download/v8.15.2/vips-8.15.2.tar.xz /vips.tar.xz
ADD https://ffmpeg.org/releases/ffmpeg-snapshot-git.tar.bz2 /ffmpeg.tar.bz2

RUN --mount=type=cache,sharing=locked,target=/var/lib/apt \
    --mount=type=cache,sharing=locked,target=/var/cache \
    mkdir -p /out \
 && rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
 && apt update \
 && apt-get install --no-install-recommends -y meson ninja-build build-essential pkg-config libglib2.0-dev libexpat1-dev libtiff-dev liblcms2-dev libspng-dev libhwy-dev libwebp-dev libopenjp2-7-dev libjxl-dev libjpeg-turbo8-dev fftw-dev libheif-dev libheif-plugin-libde265 libheif-plugin-dav1d \
                                               yasm libdav1d-dev

RUN mkdir /vips \
 && tar xf /vips.tar.xz -C /vips --strip-components=1 \
 && cd /vips \
 && meson setup build --prefix /usr/local --libdir lib --optimization 3 --strip \
	-Ddeprecated=false \
	-Dexamples=false \
	-Dcplusplus=false \
	-Danalyze=false \
	-Dradiance=false \
 && cd build \
 && meson compile \
 && meson install --destdir /out

RUN mkdir /ffmpeg \
 && tar xf /ffmpeg.tar.bz2 -C /ffmpeg --strip-components=1 \
 && cd /ffmpeg \
 && ./configure --disable-everything --prefix=/usr/local --enable-gpl --enable-version3 --arch=$TARGETARCH --enable-lto=auto --enable-pic --enable-hardcoded-tables --optflags="-O3" \
 	--disable-static \
	--disable-doc \
	--disable-network \
	--disable-dwt \
	--disable-lsp \
	--disable-faan \
	--disable-iamf \
	--disable-pixelutils \
	--disable-debug \
	--enable-shared \
	--enable-ffmpeg \
	--enable-ffprobe \
	--enable-encoder=libwebp_anim,ppm \
	--enable-decoder=h264,hevc,libdav1d,vp8,vp9 \
	--enable-muxer=mov,mp4,matroska,webm,webp,image2pipe \
	--enable-demuxer=mov,matroska,image2pipe,image_webp_pipe \
	--enable-protocol=pipe,file \
	--enable-pthreads \
	--enable-filter=thumbnail,scale \
	--enable-lcms2 \
	--enable-libdav1d \
	--enable-libwebp \
 && make -j$(nproc) \
 && make DESTDIR=/out install

RUN rm -r /out/usr/local/lib/pkgconfig /out/usr/local/include /out/usr/local/share /out/usr/local/bin/vips*



FROM scratch
COPY --link --from=media-libs-build /out /
