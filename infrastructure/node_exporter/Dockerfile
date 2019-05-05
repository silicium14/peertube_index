FROM alpine:3.9
RUN apk update && apk add socat
# Listen to TCP socket and forward request to unix socket
CMD socat -d -d -d TCP4-LISTEN:9100,fork UNIX-CONNECT:/node_exporter/node_exporter.sock
