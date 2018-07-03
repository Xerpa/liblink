// Copyright 2018 (c) Xerpa
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <czmq.h>
#include <pthread.h>

#ifndef __LIBLINK_H__
#define __LIBLINK_H__

#define LIBLINK_UNUSED(x) ((void) x)

// the receiver function. the function takes ownership of `msg` and
// must free its memory when done
//
// return: 0 = success; failure otherwise
typedef int (*liblink_recv_fn) (
  zmsg_t *msg, void *rcvfn_args);

// the opaque structure that representas a socket
typedef struct _liblink_sock_t liblink_sock_t;

// the state the zloop is currently in
enum liblink_state
{
  // the socket is halting and no further actions are allowed
  LIBLINK_STATE_HALTING,
  // in this state writes are allowed but it won't probe the socket
  // for reads
  LIBLINK_STATE_WAITING,
  // read-write mode
  LIBLINK_STATE_RUNNING
};

enum liblink_signal
{
  // terminate the socket. you should use `liblink_wait_term` after
  // sending this signal to allow the socket to cleanup its resources.
  LIBLINK_SIGNAL_HALT,
  // disables receiving messages on the socket. use this for a
  // rudimentary form of flow control.
  LIBLINK_SIGNAL_STOP,
  // resumes receiving messages on the socket. use this for a
  // rudimentary form of flow control.
  LIBLINK_SIGNAL_CONT
};

// the socket type. refer to zmq documentation for information about
// these sockets
enum liblink_type
{
  LIBLINK_SOCK_ROUTER,
  LIBLINK_SOCK_DEALER
};

// creates a new router socket. the router socket is bound to
// `ext_endpoint` and will invoke `recvfn` on new messages.
//
// the `int_endpoint` must be an `ipc://` endpoint and will be used to
// write regular and signal messages [refer to `liblink_sock_write`
// and `liblink_sock_signal`].
//
// return: NULL on error; a valid pointer otherwise
liblink_sock_t *liblink_new_socket (
  enum liblink_type,        // the socket type

  const char *ext_endpoint, // the external endpoint this
                            // socket will be bind
  const char *int_endpoint, // the endpoint to bind sockets for
                            // signals and writes. must start with
                            // `ipc://`
  liblink_recv_fn recvfn,   // the callback function that is called
                            // for every received message
  void *recvfn_args);       // additional args for the `recvfn`
                            // functions. might be null;

// if you created a `@tcp://` socket, returns the port the socket was
// bound to. useful if the port is dinamically allocated.
//
// return: 0 on success
int liblink_sock_bind_port (liblink_sock_t *socket, int *port);

// sends a message through the socket. it takes ownership of `msg` and
// free the memory after sending it successfully.
//
// return: 0 = success; failure otherwise;
int liblink_sock_write (liblink_sock_t *socket, zmsg_t **msg);

// sends a singal to the socket. `signal` is one of `LIBLINK_SIGNAL_*`
// values.
//
// return: 0 = success; failure otherwise;
int liblink_sock_signal(
  liblink_sock_t *socket,
  // the signal to send. notice that the signal processing is
  // asynchronous and may take a while to complete. notice that after
  // `LIBLINK_SIGNAL_HALT` the only valid operation is
  // `liblink_sock_wait_term`.
  enum liblink_signal signal);

// query about the current state of the liblink
enum liblink_state liblink_sock_state(liblink_sock_t *socket);

// destroy the socket. notice you should signal `TERM` and wait for
// termination using `liblink_wait_term` before using this function.
void liblink_sock_destroy (liblink_sock_t *);

// wait for socket termination. this is only guaranteed to return
// after sending a `term` signal, though it may block for an unknown
// amount of time depending on the current load.
void liblink_sock_wait_term (liblink_sock_t *);

#endif
