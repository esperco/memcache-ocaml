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

open Lwt
open Batteries
open Scanf
open Printf

exception Failure of string

type error =
  | ERROR
  | CLIENT_ERROR of string
  | SERVER_ERROR of string

exception Error of error

let error_of_string = function
  | "ERROR" -> Some ERROR
  | s ->
      if String.starts_with s "CLIENT_ERROR " then
        Some (CLIENT_ERROR (String.sub s 13 ((String.length s) - 13)))
      else if String.starts_with s "SERVER_ERROR " then
        Some (CLIENT_ERROR (String.sub s 13 ((String.length s) - 13)))
      else None

let s_of_nr = function
  | true -> " noreply"
  | false -> ""

let unexpected_reply s =
  match error_of_string s with
  | Some e -> fail (Error e)
  | None   -> fail (Failure (sprintf "unknow reply: %s" s))

(* Connection *)

type connection = {
  hostname : string;
  port     : int;
  input    : Lwt_io.input_channel;
  output   : Lwt_io.output_channel;
}

let open_connection hostname port =
  catch
    (fun () -> Lwt_lib.gethostbyname hostname)
    (function
      | Not_found -> raise (Failure ("Cannot resolve host name: " ^ hostname))
      | e -> raise e
    )
  >>= fun haddr ->
  Lwt_io.open_connection (Unix.ADDR_INET (haddr.Unix.h_addr_list.(0), port)) >>= fun (input, output) ->
  return {
    hostname = hostname;
    port     = port;
    input    = input;
    output   = output;
  }

let close_connection self =
  Lwt_io.close self.input >>= fun () ->
  Lwt_io.close self.output

let recv_line self =
  Lwt_io.read_line self.input

(* the same as Lwt_unix.read, but continue reading if the number of
 * characters actually read is lesser than number of bytes *)
let read self bytes =
  let b = String.create bytes in
  Lwt_io.read_into_exactly self.input b 0 bytes >>= fun () ->
  return b

let send self r =
  Lwt_io.write self.output r >>= fun () ->
  Lwt_io.flush self.output

(* Storage *)

type reply =
  | STORED
  | NOT_STORED
  | EXISTS
  | NOT_FOUND

let reply_of_string = function
  | "STORED"     -> return STORED
  | "NOT_STORED" -> return NOT_STORED
  | "EXISTS"     -> return EXISTS
  | "NOT_FOUND"  -> return NOT_FOUND
  | s -> unexpected_reply s

let storage cmd self key ?(flags=0) ?(exptime=0) ?(noreply=false) value =
  let request = sprintf "%s %s %d %d %d%s\r\n%s\r\n"
    cmd key flags exptime (String.length value) (s_of_nr noreply) value in
  send self request >>= fun _ ->
  if noreply
  then return STORED
  else
    recv_line self >>=
    reply_of_string

let set = storage "set"
let add = storage "add"
let replace = storage "replace"
let append = storage "append"
let prepend = storage "prepend"

let cas self key ?(flags=0) ?(exptime=0) ?(noreply=false) unique value =
  let request = sprintf "cas %s %d %d %d %Ld%s\r\n%s\r\n"
    key flags exptime (String.length value) unique (s_of_nr noreply) value in
  send self request >>= fun _ ->
  if noreply
  then return STORED
  else
    recv_line self >>=
    reply_of_string

(* Retrieval *)

let recv_data self bytes =
  let resp_len = bytes + 2 in
  read self resp_len >>= fun resp ->
  if String.ends_with resp "\r\n"
  then return (String.sub resp 0 bytes)
  else fail (Failure ("no \\r\\n at end of response: " ^ resp))

(* reads line of response and returns None if "END" or feeds line to f *)
let recv_resp f self =
  recv_line self >>= fun res ->
  if res = "END" then return None
  else
    catch
      (fun () -> f self res)
      (function ((Scan_failure _ | Failure _ | End_of_file) as e) ->
          fail (Failure (sprintf
            "incorrect first line of response: %s" (Printexc.to_string e)))
        | e -> fail e)

let recv_get_resp self =
  let f self res =
    let f name flags bytes =
      recv_data self bytes >>= fun data ->
      return (Some (name, (flags, data))) in
    sscanf res "VALUE %s %u %u" f in
  recv_resp f self

let recv_gets_resp self =
  let f self res =
    let f name flags bytes unique =
      recv_data self bytes >>= fun data ->
      return (Some (name, ((flags, unique), data))) in
    sscanf res "VALUE %s %u %u %Lu" f in
  recv_resp f self

(* recives a value and then "END" *)
let recv_a_value f self =
  f self >>= function
  | None -> return None
  | resp ->
      f self >>= function
      | Some _ -> fail (Failure "unexpected data")
      | None -> return resp

(* recives several values and then "END" *)
let recv_list f self =
  let rec loop acc =
    f self >>= function
    | Some resp -> loop (resp :: acc)
    | None -> return acc in
  loop []

let recv_hash f self =
  let h = Hashtbl.create 0 in
  let rec loop () =
    f self >>= function
    | Some (key, data) -> Hashtbl.add h key data; loop ()
    | None -> return h in
  loop ()

let get self key =
  let request = sprintf "get %s\r\n" key in
  send self request >>= fun _ ->
  recv_a_value recv_get_resp self

let getl self keys =
  let s = String.concat " " keys in
  let request = sprintf "get %s\r\n" s in
  send self request >>= fun _ ->
  recv_list recv_get_resp self

let geth self keys =
  let s = String.concat " " keys in
  let request = sprintf "get %s\r\n" s in
  send self request >>= fun _ ->
  recv_hash recv_get_resp self

let gets self key =
  let request = sprintf "gets %s\r\n" key in
  send self request >>= fun _ ->
  recv_a_value recv_gets_resp self

let getsl self keys =
  let s = String.concat " " keys in
  let request = sprintf "gets %s\r\n" s in
  send self request >>= fun _ ->
  recv_list recv_gets_resp self

let getsh self keys =
  let s = String.concat " " keys in
  let request = sprintf "gets %s\r\n" s in
  send self request >>= fun _ ->
  recv_hash recv_gets_resp self

(* Deletion *)

let delete self ?(noreply=false) key =
  let request = sprintf "delete %s%s\r\n" key (s_of_nr noreply) in
  send self request >>= fun _ ->
  if noreply
  then return true
  else
    recv_line self >>= function
    | "DELETED"   -> return true
    | "NOT_FOUND" -> return false
    | s -> unexpected_reply s

(* Increment/Decrement *)

let crement64 cmd self key ?(noreply=false) value =
  let request = sprintf "%s %s %Ld%s\r\n"
    cmd key value (s_of_nr noreply) in
  send self request >>= fun _ ->
  if noreply
  then return None
  else
    recv_line self >>= function
    | "NOT_FOUND" -> return None
    | s -> catch
        (fun () -> return (Some (Int64.of_string s)))
        (fun _ -> unexpected_reply s)

let incr64 = crement64 "incr"
let decr64 = crement64 "decr"

let crement cmd self key ?(noreply=false) value =
  let request = sprintf "%s %s %s%s\r\n"
    cmd key value (s_of_nr noreply) in
  send self request >>= fun _ ->
  if noreply
  then return None
  else
    recv_line self >>= function
    | "NOT_FOUND" -> return None
    | s ->
        catch (fun () ->
          sscanf s "%Lu" (fun _ -> ());
          return (Some s))
          (fun _ -> unexpected_reply s)

let incr = crement "incr"
let decr = crement "decr"

(* Other commands *)

let flush_all ?(delay = 0) self =
  let request = sprintf "flush_all %d\r\n" delay in
  send self request >>= fun _ ->
  recv_line self >>= function
  | "OK" -> return ()
  | s -> unexpected_reply s

let version self =
  let request = "version\r\n" in
  send self request >>= fun _ ->
  recv_line self >>= fun line ->
  let s = "VERSION " in
  if String.starts_with line s
  then return (String.sub line (String.length s)
         ((String.length line) - (String.length s)))
  else unexpected_reply line
