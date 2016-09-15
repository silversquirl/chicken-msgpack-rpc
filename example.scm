(use msgpack-rpc)

(define conn (connect host: "0.0.0.0"
                      port: (string->number
                              (car (command-line-arguments)))))

(define echo (rpc-proc conn "echo"))

(print (echo (read-line)))
