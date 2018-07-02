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

#include "liblink.h"
#include <pthread.h>

struct _liblink_sock_t {
  volatile enum liblink_state state;
  pthread_t ioloop;
  pthread_mutex_t mutex;
  zloop_t *reactor;
  zsock_t *sock;
  zsock_t *push;
  zsock_t *pull;
  liblink_recv_fn recvfn;
  void *recvfn_args;
};

static int _liblink_ioloop_recv (zloop_t *zloop, zsock_t *sock, void *args);

static
void _liblink_state_w (liblink_sock_t *socket)
{
  if (0 == pthread_mutex_lock(&socket->mutex))
  {
    if (socket->state == LIBLINK_STATE_RUNNING)
    {
      socket->state = LIBLINK_STATE_WAITING;
      zloop_reader_end(socket->reactor, socket->sock);
    }

    pthread_mutex_unlock(&socket->mutex);
  }
}

static
void _liblink_state_r (liblink_sock_t *socket)
{
  if (0 == pthread_mutex_lock(&socket->mutex))
  {
    if (socket->state == LIBLINK_STATE_WAITING)
    {
      socket->state = LIBLINK_STATE_RUNNING;
      zloop_reader(socket->reactor, socket->sock, _liblink_ioloop_recv, socket);
    }

    pthread_mutex_unlock(&socket->mutex);
  }
}

static
void _liblink_state_t (liblink_sock_t *socket)
{
  if (0 == pthread_mutex_lock(&socket->mutex))
  {
    if (socket->state == LIBLINK_STATE_RUNNING || socket->state == LIBLINK_STATE_WAITING)
    {
      socket->state = LIBLINK_STATE_HALTING;
      zloop_reader_end(socket->reactor, socket->pull);
      zloop_reader_end(socket->reactor, socket->sock);
    }

    pthread_mutex_unlock(&socket->mutex);
  }
}

static
int _liblink_ioloop_recv (zloop_t *zloop, zsock_t *sock, void *args)
{
  liblink_sock_t *socket = (liblink_sock_t *) args;
  zmsg_t *msg = zmsg_recv(sock);
  LIBLINK_UNUSED(zloop);

  if (msg != NULL)
  {
    if (0 != socket->recvfn(msg, socket->recvfn_args))
    { _liblink_state_w(socket); }
  }

  return(0);
}

static
int _liblink_ioloop_pull (zloop_t *zloop, zsock_t *sock, void *args)
{
  liblink_sock_t *socket = (liblink_sock_t *) args;
  zmsg_t *msg = zmsg_recv(sock);

  LIBLINK_UNUSED(zloop);

  if (msg != NULL)
  {
    switch (zmsg_signal(msg))
    {
    case -1:
      zmsg_send(&msg, socket->sock);
      break;
    case LIBLINK_SIGNAL_HALT:
      _liblink_state_t(socket);
      zmsg_destroy(&msg);
      return(-1);
    case LIBLINK_SIGNAL_STOP:
      _liblink_state_w(socket);
      zmsg_destroy(&msg);
      break;
    case LIBLINK_SIGNAL_CONT:
      _liblink_state_r(socket);
      zmsg_destroy(&msg);
      break;
    default:
      zmsg_destroy(&msg);
      break;
    }
  }

  return(0);
}

static
void *_liblink_ioloop (void *args)
{
  liblink_sock_t *socket = (liblink_sock_t *) args;

  zloop_reader(socket->reactor, socket->sock, _liblink_ioloop_recv, args);
  zloop_reader(socket->reactor, socket->pull, _liblink_ioloop_pull, args);
  zloop_start(socket->reactor);

  return(NULL);
}

liblink_sock_t *liblink_new_socket (enum liblink_type socktype, const char *ext_endpoint, const char *int_endpoint, liblink_recv_fn recvfn, void *recvfn_args)
{
  liblink_sock_t *socket;

  if (recvfn == NULL)
  { return(NULL); }

  if (strstr("inproc://", int_endpoint) != NULL)
  { return(NULL); }

  if (NULL == (socket = malloc(sizeof(liblink_sock_t))))
  { return(NULL); }

  if (0 != pthread_mutex_init(&socket->mutex, NULL))
  {
    free(socket);
    return(NULL);
  }

  socket->state = LIBLINK_STATE_RUNNING;
  socket->recvfn = recvfn;
  socket->recvfn_args = recvfn_args;
  socket->push = zsock_new_push(int_endpoint);
  socket->pull = zsock_new_pull(int_endpoint);
  socket->reactor = zloop_new();
  switch (socktype)
  {
  case LIBLINK_SOCK_ROUTER:
    socket->sock = zsock_new_router(ext_endpoint);
    break;
    ;;
  case LIBLINK_SOCK_DEALER:
    socket->sock = zsock_new_dealer(ext_endpoint);
    break;
    ;;
  default:
    socket->sock = NULL;
    break;
  }
  if (socket->reactor == NULL || socket->sock == NULL || socket->push == NULL || socket->pull == NULL)
  { goto e_handler; }

  if (0 != (pthread_create(&(socket->ioloop), NULL, *_liblink_ioloop, (void *) socket)))
  { goto e_handler; }

  return(socket);

e_handler:
  liblink_sock_destroy(socket);
  return(NULL);
}

int liblink_sock_signal (liblink_sock_t *socket, enum liblink_signal signal)
{
  zmsg_t *msg = zmsg_new_signal((byte) signal);

  if (msg != NULL && socket->state != LIBLINK_STATE_HALTING)
  { return(zmsg_send(&msg, socket->push)); }
  else
  {
    if (msg != NULL)
    { zmsg_destroy(&msg); }

    if (signal == LIBLINK_SIGNAL_HALT)
    { return(0); }
    else
    { return(-1); }
  }
}

enum liblink_state liblink_sock_state (liblink_sock_t *socket)
{ return(socket->state); }

int liblink_sock_write (liblink_sock_t *socket, zmsg_t **msg)
{
  if (socket->state != LIBLINK_STATE_HALTING)
  { return(zmsg_send(msg, socket->push)); }
  else
  {
    zmsg_destroy(msg);
    return(-1);
  }
}

void liblink_sock_destroy (liblink_sock_t *socket)
{
  if (socket != NULL)
  {
    if (socket->reactor != NULL)
    { zloop_destroy(&socket->reactor); }
    if (socket->sock != NULL)
    { zsock_destroy(&socket->sock); }
    if (socket->push != NULL)
    { zsock_destroy(&socket->push); }
    if (socket->pull != NULL)
    { zsock_destroy(&socket->pull); }
    pthread_mutex_destroy(&socket->mutex);
    free(socket);
  }
}

void liblink_sock_wait_term (liblink_sock_t *socket)
{ pthread_join(socket->ioloop, NULL); }
