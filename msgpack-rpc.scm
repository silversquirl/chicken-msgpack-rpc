(module msgpack-rpc
    (send-request
     await-response

     rpc-call
     rpc-proc*
     rpc-proc

     connect
     connection-i-port
     connection-o-port
     connection-active-msgs)

  (import chicken scheme
          data-structures)
  (use msgpack
       ports
       extras
       socket

       srfi-1

       srfi-18
       mailbox)

  (define-record connection
    i-port
    o-port
    active-msgs
    listen-thread)

  (define (connect #!key
                   path
                   host
                   port)

    (let* ((sock
            (socket
             (if path
                 af/unix
                 af/inet)
             sock/stream))

           (conn
            (let-values
              (((i-port o-port)
                (socket-i/o-ports sock)))
              (make-connection
               i-port
               o-port
               '()
               #f))))

      (socket-connect
       sock
       (if path
           (unix-address path)
           (inet-address host port)))

      (connection-listen-thread-set!
       conn
       (thread-start!
        (listen-for-responses conn)))

      conn))

  (define ((listen-for-responses conn))
    (let get-response ()
      (let* ((response (unpack (connection-i-port conn)
                               raw->string/mapper))
             (mb (alist-ref (vector-ref response 1)
                            (connection-active-msgs conn))))

        (when (and mb
                   (= 1 (vector-ref response 0)))
          (mailbox-send! mb response))

        (get-response))))

  (define (send-request conn msgid method params)
    (connection-active-msgs-set!
     conn
     (cons (cons msgid (make-mailbox))
           (connection-active-msgs conn)))

    (pack (connection-o-port conn)
          (vector 0
                  msgid
                  method
                  (list->vector params))))

  (define (await-response conn msgid)
    (let ((mb (alist-ref msgid (connection-active-msgs conn))))
      (let ((result (mailbox-receive! mb)))

        (if (null? (vector-ref result 2))
            ;; Remove the msgid and mailbox
            (begin
              (connection-active-msgs-set!
               conn
               (remove
                (lambda (x) (= msgid (car x)))
                (connection-active-msgs conn)))

              ;; Return the result
              (vector-ref result 3))

            (error (vector-ref result 2))))))

  (define (get-next-message-id conn)
    (let ((msgs (connection-active-msgs conn)))
      (do ((i 1 (add1 i)))
          ((not (member i msgs)) i))))

  (define (rpc-call conn name . args)
    (let ((msgid (get-next-message-id conn)))
      (send-request conn msgid name args)
      (await-response conn msgid)))

  (define ((rpc-proc* name) conn . args)
    (apply rpc-call name conn args))

  (define ((rpc-proc conn name) . args)
    (apply rpc-call name conn args)))
