FROM ubuntu AS build

RUN apt-get update && apt-get -y install curl wget xz-utils build-essential

# DMD and DUB
RUN curl -L -o ~/dvm https://github.com/jacob-carlborg/dvm/releases/download/v0.4.4/dvm-0.4.4-linux-debian7-x86_64 \
    && chmod +x ~/dvm \
    && ~/dvm install dvm \
SHELL ["bash"]
RUN ~/.dvm/bin/dvm install 2.083.1 \
    && ~/.dvm/bin/dvm use 2.083.1 \
    && chmod +x ~/.dvm/compilers/dmd-2.083.1/linux/bin/dub


WORKDIR /build
COPY dub.sdl .
COPY dub.selections.json .
RUN ~/.dvm/compilers/dmd-2.083.1/linux/bin/dub upgrade
COPY ./source/ ./source
RUN ~/.dvm/compilers/dmd-2.083.1/linux/bin/dub build


FROM bitnami/minideb:stretch
RUN apt-get update && apt-get -y install git \
    && git config --global user.email "no@mail.address" \
    && git config --global user.name "DotfimTester"
COPY --from=build /build/dotfim /bin

VOLUME /dotfim
WORKDIR /dotfim

ENTRYPOINT ["dotfim"]

