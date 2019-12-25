FROM golang:1.13-buster

# Download and install Hugo v0.62.0
RUN wget -O hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v0.62.0/hugo_0.62.0_Linux-64bit.tar.gz
RUN tar xf hugo.tar.gz
RUN rm -f hugo.tar.gz LICENSE README.md
RUN mv hugo /usr/local/bin/hugo

# Add new user
RUN useradd -ms /bin/bash kelby
USER kelby
WORKDIR /home/kelby

CMD ["/usr/local/bin/hugo"]
