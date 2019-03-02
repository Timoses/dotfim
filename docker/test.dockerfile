FROM dlanguage/ldc AS build

RUN apt-get update && apt-get -y install git vim zsh tmux wget \
    && git config --global user.email "no@mail.address" \
    && git config --global user.name "DotfimTester" \
    && chsh -s /bin/zsh root

VOLUME /source

WORKDIR /build
COPY dub.sdl .
COPY dub.selections.json .
RUN dub upgrade
COPY ./source/ ./source
RUN dub build --config=debug \
    && ln -s /build/dotfim /usr/bin/dotfim

WORKDIR /dotfim

ENTRYPOINT ["zsh"]

