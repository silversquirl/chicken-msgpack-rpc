# CHICKEN msgpack-rpc

A msgpack-rpc implementation for CHICKEN Scheme.

## Demo

```scheme
(use msgpack-rpc)

(define conn (connect path: "/tmp/unix-socket"))
(define hello-world (rpc-proc conn "helloWorld"))

(hello-world)
```
