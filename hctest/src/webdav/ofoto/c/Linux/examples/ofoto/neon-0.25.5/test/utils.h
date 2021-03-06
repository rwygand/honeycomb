/* 
   neon-specific test utils
   Copyright (C) 2001-2005, Joe Orton <joe@manyfish.co.uk>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
  
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
  
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

#ifndef UTILS_H
#define UTILS_H 1

#include "ne_request.h"

#include "child.h"

#define ONREQ(x) do { int _ret = (x); if (_ret) { t_context("line %d: HTTP error:\n%s", __LINE__, ne_get_error(sess)); return FAIL; } } while (0);

int single_serve_string(ne_socket *s, void *userdata);

struct many_serve_args {
    int count;
    const char *str;
};

/* Serves args->str response args->count times down a single
 * connection. */
int many_serve_string(ne_socket *s, void *userdata);

/* Run a request using URI on the session. */
int any_request(ne_session *sess, const char *uri);

/* Run a request using URI on the session; fail on a non-2xx response.
 */
int any_2xx_request(ne_session *sess, const char *uri);

/* As above but with a request body. */
int any_2xx_request_body(ne_session *sess, const char *uri);

/* makes *session, spawns server which will run 'fn(userdata,
 * socket)'.  sets error context if returns non-zero, i.e use like:
 * CALL(make_session(...)); */
int make_session(ne_session **sess, server_fn fn, void *userdata);

/* Server which sleeps for 10 seconds then closes the socket. */
int sleepy_server(ne_socket *sock, void *userdata);

struct string {
    char *data;
    size_t len;
};

/* Serve a struct string. */
int serve_sstring(ne_socket *sock, void *ud);

/* Serve a struct string slowly. */
int serve_sstring_slowly(ne_socket *sock, void *ud);

struct infinite {
    const char *header, *repeat;
};

/* Pass a "struct infinite *" as userdata, this function sends
 * ->header and then loops sending ->repeat forever. */
int serve_infinite(ne_socket *sock, void *ud);

#endif /* UTILS_H */
