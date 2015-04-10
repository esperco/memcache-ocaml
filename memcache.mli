(* This file is part of memcache-ocaml.
 *
 * memcache-ocaml is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * memcache-ocaml is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with memcache-ocaml.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2010 Alexander Markov *)

(** Memcache support for OCaml. Based on it's text protocol.

  All text below is mainly revised protocol specification
  with some markups and simplifications.

  Nearly all functions in this module use Lwt.
  Lwt is a library for cooperative threads in OCaml.
  It is using monadic style, which makes it really easy to use.

  @author 2010 Alexander Markov (apsheronets\@gmail.com)
  @see <http://github.com/memcached/memcached/blob/master/doc/protocol.txt>
  the last official protocol specification
  @see <http://ocsigen.org/lwt/> Lwt manual
*)

(** This is non-regular exception, which raised only when library can't
understand server's behavior. It's reasonably to send a bug report when this
exception raises. *)
exception Failure of string

(** {2 Connection}

Clients of memcached communicate with server through TCP connections.
A given running memcached server listens on some
(configurable) port; clients connect to that port, send commands to
the server, read responses, and eventually close the connection. *)

type connection

val open_connection : string -> int -> connection Lwt.t

val close_connection : connection -> unit Lwt.t

(** {2 Keys}

Data stored by memcached is identified with the help of a key. A key
is a text string which should uniquely identify the data for clients
that are interested in storing and retrieving it.  Currently the
length limit of a key is set at 250 characters (of course, normally
clients wouldn't need to use such long keys); the key must not include
control characters or whitespace. *)

(** {2 Expiration times}

Some commands involve a client sending some kind of expiration time
(relative to an item or to an operation requested by the client) to
the server. In all such cases, the actual value sent may either be
Unix time (number of seconds since January 1, 1970, as a 32-bit
value), or a number of seconds starting from current time. In the
latter case, this number of seconds may not exceed 60*60*24*30 (number
of seconds in 30 days); if the number sent by a client is larger than
that, the server will consider it to be real Unix time value rather
than an offset from current time. *)

(** {1 Commands}  *)

(** Each command sent by a client may be answered with an error
from the server. These errors come in three types:

- [ERROR]
  means the client sent a nonexistent command name.

- [CLIENT_ERROR error]
  means some sort of client error in the input line, i.e. the input
  doesn't conform to the protocol in some way. [error] is a
  human-readable error string.

- [SERVER_ERROR error]
  means some sort of server error prevents the server from carrying
  out the command. [error] is a human-readable error string. In cases
  of severe server errors, which make it impossible to continue
  serving the client (this shouldn't normally happen), the server will
  close the connection after sending the error line. This is the only
  case in which the server closes a connection to a client.

In the descriptions of individual commands below, these errors
are not again specifically mentioned, but clients must allow for their
possibility.*)
type error =
  | ERROR
  | CLIENT_ERROR of string
  | SERVER_ERROR of string

exception Error of error

(** {2 Storage commands} *)

(** Storage commands (there are six: [set], [add], [replace], [append]
[prepend] and [cas]) ask the server to store some data identified by a
key. The client sends a command and a data block; after
that the client expects response, which will indicate
success or faulure. *)

(** After sending the command and the data the client awaits
the reply, which may be:

- [STORED], to indicate success.

- [NOT_STORED] to indicate the data was not stored, but not
because of an error. This normally means that the
condition for an [add] or a [replace] command wasn't met.

- [EXISTS] to indicate that the item you are trying to store with
a [cas] command has been modified since you last fetched it.

- [NOT_FOUND] to indicate that the item you are trying to store
with a [cas] command did not exist. *)
type reply =
  | STORED
  | NOT_STORED
  | EXISTS
  | NOT_FOUND

val set : connection -> string -> ?flags:int -> ?exptime:int ->
  ?noreply:bool -> string -> reply Lwt.t
(** [set] means "store this data". *)

val add : connection -> string -> ?flags:int -> ?exptime:int ->
  ?noreply:bool -> string -> reply Lwt.t
(** [add] means "store this data, but only if the server {b doesn't}
already hold data for this key". *)

val replace : connection -> string -> ?flags:int -> ?exptime:int ->
  ?noreply:bool -> string -> reply Lwt.t
(** [replace] means "store this data, but only if the server {b does}
already hold data for this key". *)

val append : connection -> string -> ?flags:int -> ?exptime:int ->
  ?noreply:bool -> string -> reply Lwt.t
(** [append] means "add this data to an existing key after existing
data". *)

val prepend : connection -> string -> ?flags:int -> ?exptime:int ->
  ?noreply:bool -> string -> reply Lwt.t
(** [prepend] means "add this data to an existing key before existing
data". *)

val cas : connection -> string -> ?flags:int -> ?exptime:int ->
  ?noreply:bool -> int64 -> string -> reply Lwt.t
(** [cas] is a check and set operation which means "store this data but
only if no one else has updated since I last fetched it."

- [key] is the key under which the client asks to store the data

- [flags] is an arbitrary 16-bit unsigned integer (written out in
  decimal) that the server stores along with the data and sends back
  when the item is retrieved. Clients may use this as a bit field to
  store data-specific information; this field is opaque to the server.
  Note that in memcached 1.2.1 and higher, flags may be 32-bits, instead
  of 16, but you might want to restrict yourself to 16 bits for
  compatibility with older versions. The default is 0.

- [exptime] is expiration time. If it's 0, the item never expires
  (although it may be deleted from the cache to make place for other
  items). If it's non-zero (either Unix time or offset in seconds from
  current time), it is guaranteed that clients will not be able to
  retrieve this item after the expiration time arrives (measured by
  server time). The default value is 0 (never).

- [unique] is a unique 64-bit value of an existing entry.
  Clients should use the value returned from the [gets] command
  when issuing [cas] updates.

- [noreply] optional parameter instructs the server to not send the
  reply. All storage functions will always return [STORED]. Use it with
  caution because you willn't recive [Error] exception if any error
  occurs. *)


(** {2 Retrieval command} *)

(** Retrieval commands (there are four: [get], [getl], [gets] and [getsl])
ask the server to
retrieve data corresponding to a set of keys (one or more keys in one
request). The client sends a command, which includes all the
requested keys; after that for each item the server finds it sends to
the client one response with information about the item, and one
data block with the item's data. *)

val get : connection -> string ->
  (string * (int * string)) option Lwt.t
(** [get conn key] returns [Some (key, (flags, value)] or [None] if the item with this key was not found. *)

val getl : connection -> string list ->
  (string * (int * string)) list Lwt.t
(** The same, but takes a list of keys and returns list of founded
values. *)

val geth : connection -> string list ->
  (string, (int * string)) Hashtbl.t Lwt.t
(** The same, but returns hash table of founded values. *)

val gets : connection -> string ->
  (string * ((int * int64) * string)) option Lwt.t
(** [gets] is similar to [get]
but returns [Some (key, ((flags, unique), value)] if item was found. *)

val getsl : connection -> string list ->
  (string * ((int * int64) * string)) list Lwt.t
(** The same, but takes a list of keys and returns list of founded
values. *)

val getsh : connection -> string list ->
  (string, ((int * int64) * string)) Hashtbl.t Lwt.t
(** The same, but returns hash table of founded values. *)

(** {2 Deletion} *)

val delete : connection -> ?noreply:bool -> string -> bool Lwt.t
(** [delete key] allows for explicit deletion of items.

- [key] is the key of the item the client wishes the server to delete

- [noreply] optional parameter instructs the server to not send the
  reply.  See the note in Storage commands regarding malformed
  requests. When [true], function will always return [true]. Use it with
  caution because you willn't recive [Error] exception if any error
  occurs.

This function can return:

- [true] to indicate success

- [false] to indicate that the item with this key was not
  found.

See the [flush_all] function below for immediate invalidation
of all existing items. *)

(** {2 Increment/Decrement} *)

val incr64 : connection -> string -> ?noreply:bool -> int64 ->
  int64 option Lwt.t
val decr64 : connection -> string -> ?noreply:bool -> int64 ->
  int64 option Lwt.t
(** Commands [incr] and [decr] are used to change data for some item
in-place, incrementing or decrementing it. The data for the item is
a 64-bit unsigned integer.  If
the current data value does not conform to such a representation, the
incr/decr commands return an error (memcached <= 1.2.6 treated the
bogus value as if it were 0, leading to confusing). Also, the item
must already exist for incr/decr to work; these commands won't pretend
that a non-existent key exists with value 0; instead, they will fail.

Example of usage: [incr conn key value]

- [key] is the key of the item the client wishes to change

- [value] is the amount by which the client wants to increase/decrease
the item. It is a 64-bit unsigned integer.

- [noreply] optional parameter instructs the server to not send the
  reply.  See the note in Storage commands regarding malformed
  requests.

The response will be one of:

- [None] to indicate the item with this value was not found or [noreply]
was set.

- [Some value], where [value] is the new value of the item's data,
  after the increment/decrement operation was carried out.

Note that underflow in the "decr" command is caught: if a client tries
to decrease the value below 0, the new value will be 0.  Overflow in
the "incr" command will wrap around the 64 bit mark. *)

val incr : connection -> string -> ?noreply:bool -> string ->
  string option Lwt.t
val decr : connection -> string -> ?noreply:bool -> string ->
  string option Lwt.t
(** The same, but brings and returns decimal representations of 64-bit
unsigned integer. These functions are faster and more dangerous to use. *)

(** {2 Statistics} *)

(** {3 General-purpose statistics} *)

(** {3 Settings statistics} *)

(** {3 Item statistics} *)

(** {3 Item size statistics} *)

(** {3 Slab statistics} *)

(** {2 Other commands} *)

val flush_all : ?delay:int -> connection -> unit Lwt.t
(** [flush_all] is a command with an optional numeric argument. It always
succeeds, and the function returns [()]. Its effect is to invalidate all
existing items immediately (by default) or after the expiration
specified.  After invalidation none of the items will be returned in
response to a retrieval command (unless it's stored again under the
same key {b after} [flush_all] has invalidated the items). [flush_all]
doesn't actually free all the memory taken up by existing items; that
will happen gradually as new items are stored. The most precise
definition of what [flush_all] does is the following: it causes all
items whose update time is earlier than the time at which [flush_all]
was set to be executed to be ignored for retrieval purposes.

The intent of [flush_all] with a [delay], was that in a setting where you
have a pool of memcached servers, and you need to flush all content,
you have the option of not resetting all memcached servers at the
same time (which could e.g. cause a spike in database load with all
clients suddenly needing to recreate content that would otherwise
have been found in the memcached daemon).

The [delay] option allows you to have them reset in e.g. 10 second
intervals (by passing 0 to the first, 10 to the second, 20 to the
third, etc. etc.). *)

val version : connection -> string Lwt.t
(** In response, the server sends the version string for the server. *)

(** {2 UDP protocol} *)
