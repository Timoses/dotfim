FROM andrewbenton/alpine-ldc as build

WORKDIR /build
COPY dub.sdl .
COPY dub.selections.json .
RUN dub upgrade
COPY ./source/ ./source
RUN dub build --build=release

FROM frolvlad/alpine-glibc
RUN apk add git \
    && git config --global user.email "no@mail.address" \
    && git config --global user.name "DotfimTester"
COPY --from=build /build/dotfim /bin/

ENTRYPOINT ["dotfim"]

