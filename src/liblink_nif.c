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

#include <pthread.h>
#include "erl_nif.h"
#include "liblink.h"

typedef struct {
  pthread_mutex_t mutex;
  liblink_sock_t *socket;
  ErlNifPid pid;
} liblink_erlnif_t;

static
void _liblink_erlnif_destroy (ErlNifEnv *env, void *priv)
{
  LIBLINK_UNUSED(env);

  liblink_erlnif_t *data = (liblink_erlnif_t *) priv;
  if (data)
  {
    pthread_mutex_destroy(&data->mutex);
    if (data->socket)
    { liblink_sock_destroy(data->socket); }
    enif_release_resource(data);
  }
}

static
int _liblink_erlnif_recvfn (zmsg_t *msg, void *args)
{
  zframe_t *frame;
  liblink_erlnif_t *data = (liblink_erlnif_t *) args;
  size_t buffsize;
  unsigned char *buffdata;
  ErlNifEnv *env = NULL;
  ERL_NIF_TERM binary;
  ERL_NIF_TERM iolist;
  ERL_NIF_TERM message;

  if (NULL == (env = enif_alloc_env()))
  { return(-1); }

  iolist = enif_make_list(env, 0);
  for (frame = zmsg_first(msg); frame != NULL; frame = zmsg_next(msg))
  {
    buffsize = zframe_size(frame);
    if (NULL == (buffdata = enif_make_new_binary(env, buffsize, &binary)))
    { goto e_handler; }
    memcpy(buffdata, zframe_data(frame), buffsize);

    iolist = enif_make_list_cell(env, binary, iolist);
  }
  message = enif_make_tuple2(env, enif_make_atom(env, "liblink_message"), iolist);

  if (0 == enif_send(env, &data->pid, env, message))
  { goto e_handler; }
  enif_free_env(env);
  zmsg_destroy(&msg);

  return(0);

e_handler:
  enif_free_env(env);
  zmsg_destroy(&msg);
  return(-1);
}

static
int _liblink_erlnif_load (ErlNifEnv *env, void **priv, const ERL_NIF_TERM info)
{
  LIBLINK_UNUSED(info);

  *priv = enif_open_resource_type(env, "liblink_nif", "Elixir.Liblink.Nif", _liblink_erlnif_destroy, ERL_NIF_RT_CREATE, NULL);
  if (*priv == NULL)
  { return(-1); }
  return(0);
}

static
ERL_NIF_TERM _liblink_erlnif_new_socket (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  char ext_endpoint[256];
  char int_endpoint[256];
  char socktype[7];
  liblink_erlnif_t *data;
  ErlNifBinary erl_ext_endpoint;
  ErlNifBinary erl_int_endpoint;
  ErlNifResourceType *type;
  ERL_NIF_TERM data_term;
  int term_to_pid = 0;

  type = (ErlNifResourceType *) enif_priv_data(env);
  if (argc != 4
      || 0 == enif_is_atom(env, argv[0])
      || 0 == enif_get_atom(env, argv[0], socktype, 7, ERL_NIF_LATIN1)
      || 0 == enif_is_binary(env, argv[1])
      || 0 == enif_inspect_binary(env, argv[1], &erl_ext_endpoint)
      || erl_ext_endpoint.size >= 256
      || 0 == enif_is_binary(env, argv[2])
      || 0 == enif_inspect_binary(env, argv[2], &erl_int_endpoint)
      || erl_int_endpoint.size >= 256
      || 0 == enif_is_pid(env, argv[3]))
  { goto e_handle_badargs; }
  strncpy(ext_endpoint, (char *) erl_ext_endpoint.data, erl_ext_endpoint.size);
  strncpy(int_endpoint, (char *) erl_int_endpoint.data, erl_int_endpoint.size);
  ext_endpoint[erl_ext_endpoint.size] = '\0';
  int_endpoint[erl_int_endpoint.size] = '\0';

  data = (liblink_erlnif_t *) enif_alloc_resource(type, sizeof(liblink_erlnif_t));
  if (data != NULL && 0 != pthread_mutex_init(&data->mutex, NULL))
  {
    enif_release_resource(data);
    return(enif_make_atom(env, "error"));
  }
  if (data != NULL)
  {
    data->socket = NULL;
    term_to_pid = enif_get_local_pid(env, argv[3], &data->pid);

    if (term_to_pid != 0)
    {
      if (strcmp(socktype, "router") == 0)
      { data->socket = liblink_new_socket(LIBLINK_SOCK_ROUTER, ext_endpoint, int_endpoint, _liblink_erlnif_recvfn, data); }
      else if (strcmp(socktype, "dealer") == 0)
      { data->socket = liblink_new_socket(LIBLINK_SOCK_DEALER, ext_endpoint, int_endpoint, _liblink_erlnif_recvfn, data); }
    }
  }
  if (data == NULL || data->socket == NULL || 0 == term_to_pid)
  { goto e_handle_syserr; }

  data_term = enif_make_resource(env, (void *) data);
  enif_release_resource(data);

  return(enif_make_tuple2(env, enif_make_atom(env, "ok"), data_term));

e_handle_badargs:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "badargs")));

e_handle_syserr:
  _liblink_erlnif_destroy(NULL, data);

  return(enif_make_atom(env, "error"));
}

static
ERL_NIF_TERM _liblink_erlnif_sendmsg (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary payload;
  zmsg_t *msg = NULL;
  liblink_erlnif_t *data;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);
  ERL_NIF_TERM head;
  ERL_NIF_TERM tail;

  if (argc != 2
      || 0 == enif_get_resource(env, argv[0], type, (void **) &data)
      || (0 == enif_is_binary(env, argv[1]) && 0 == enif_is_list(env, argv[1])))
  { goto e_handle_badargs; }

  msg = zmsg_new();
  if (msg != NULL && 0 != enif_is_binary(env, argv[1]))
  {
    if (0 == enif_inspect_binary(env, argv[1], &payload)
        || 0 != zmsg_addmem(msg, payload.data, payload.size))
    { goto e_handle_syserr; }
  }
  else if (msg != NULL && 0 != enif_is_list(env, argv[1]))
  {
    tail = argv[1];
    while (0 != enif_get_list_cell(env, tail, &head, &tail))
    {
      if (0 != enif_is_binary(env, head))
      {
        if (0 == enif_inspect_binary(env, head, &payload)
            || 0 != zmsg_addmem(msg, payload.data, payload.size))
        { goto e_handle_syserr; }
      }
      else if (0 != enif_is_list(env, head))
      {
        if (0 == enif_inspect_iolist_as_binary(env, head, &payload)
            || 0 != zmsg_addmem(msg, payload.data, payload.size))
        { goto e_handle_syserr; }
      }
    }
  }
  else
  { goto e_handle_syserr; }

  if (0 == liblink_sock_write(data->socket, &msg))
  { return(enif_make_atom(env, "ok")); }
  else
  { return(enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "ioerror"))); }

e_handle_badargs:
  return(enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "badargs")));

e_handle_syserr:
  if (msg != NULL)
  { zmsg_destroy(&msg); }

  return(enif_make_atom(env, "error"));
}

static
ERL_NIF_TERM _liblink_erlnif_term (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  liblink_erlnif_t *data;
  liblink_sock_t *socket;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (argc != 1 || 0 == enif_get_resource(env, argv[0], type, (void **) &data))
  { return(enif_make_atom(env, "error")); }

  socket = data->socket;
  data->socket = NULL;
  if (0 != liblink_sock_signal(socket, LIBLINK_SIGNAL_HALT))
  { return(enif_make_atom(env, "error")); }
  liblink_sock_wait_term(socket);
  liblink_sock_destroy(socket);

  return(enif_make_atom(env, "ok"));
}

static
ERL_NIF_TERM _liblink_erlnif_signal (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  char signal[5];
  liblink_erlnif_t *data;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (argc != 2
      || 0 == enif_get_resource(env, argv[0], type, (void **) &data)
      || 0 == enif_is_atom(env, argv[1])
      || 0 == enif_get_atom(env, argv[1], signal, 5, ERL_NIF_LATIN1))
  { return(enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "badargs"))); }

  if (0 == strcmp(signal, "stop"))
  {
    if (0 != liblink_sock_signal(data->socket, LIBLINK_SIGNAL_STOP))
    { return(enif_make_atom(env, "error")); }
  }
  else if (0 == strcmp(signal, "cont"))
  {
    if (0 != liblink_sock_signal(data->socket, LIBLINK_SIGNAL_CONT))
    { return(enif_make_atom(env, "error")); }
  }
  else
  { return(enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "badsignal"))); }

  return(enif_make_atom(env, "ok"));
}

static
ERL_NIF_TERM _liblink_erlnif_state (ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  liblink_erlnif_t *data;
  ErlNifResourceType *type = (ErlNifResourceType *) enif_priv_data(env);

  if (argc != 1
      || 0 == enif_get_resource(env, argv[0], type, (void **) &data))
  { return(enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "badargs"))); }

  switch (liblink_sock_state(data->socket))
  {
  case LIBLINK_STATE_HALTING:
    return(enif_make_atom(env, "halting"));
  case LIBLINK_STATE_RUNNING:
    return(enif_make_atom(env, "running"));
  case LIBLINK_STATE_WAITING:
    return(enif_make_atom(env, "waiting"));
  default:
    return(enif_make_atom(env, "error"));
  }
}

ErlNifFunc liblink_erlnif[] =
{
  {"new_socket", 4, _liblink_erlnif_new_socket, 0},
  {"sendmsg", 2, _liblink_erlnif_sendmsg, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"term", 1, _liblink_erlnif_term, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"signal", 2, _liblink_erlnif_signal, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"state", 1, _liblink_erlnif_state, 0}
};

ERL_NIF_INIT(Elixir.Liblink.Nif, liblink_erlnif, _liblink_erlnif_load, NULL, NULL, NULL)
