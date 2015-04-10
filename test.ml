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

(* Usage: make test && ./test *)

open Lwt

let string_of_reply = function
  | Memcache.STORED -> "STORED"
  | Memcache.NOT_STORED -> "NOT_STORED"
  | Memcache.EXISTS -> "EXISTS"
  | Memcache.NOT_FOUND -> "NOT_FOUND"

let host = "localhost"
let port = 11211

let t =

    Printf.printf "open_connection: %s:%d\n" host port;
  Memcache.open_connection host port >>= fun cache ->

    print_string "version: ";
  Memcache.version cache >>= fun version ->
    print_endline version;

    print_string "flush_all:";
  Memcache.flush_all cache >>= fun () ->
    print_endline " ok";

    print_endline "getsh: foo foo01";
  Memcache.getsh cache ["foo"; "foo01"] >>= fun reply ->
    Hashtbl.iter (fun name ((flags, unique), value) ->
    Printf.printf " answer: %s (%d, %Ld) = %s\n" name flags unique value) reply;

    print_endline "set: foo = bar";
  Memcache.set cache "foo" "bar" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "get: foo";
  Memcache.get cache "foo" >>= fun reply ->
    print_string " answer: ";
    (match reply with
    | Some (name, (flags, value)) ->
        Printf.printf "%s (%d) = %s\n" name flags value
    | None -> print_endline "None");

    print_endline "add: foo = bar";
  Memcache.add cache "foo" "bar" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "geth: foo foo01";
  Memcache.geth cache ["foo"; "foo01"] >>= fun reply ->
    Hashtbl.iter (fun name (flags, value) ->
    Printf.printf " answer: %s (%d) = %s\n" name flags value) reply;

    print_endline "delete: foo";
  Memcache.delete cache "foo" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_bool reply));

    print_endline "set: foo01 = 1";
  Memcache.set cache "foo01" "1" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "incr64: foo01 2L";
  Memcache.incr64 cache "foo01" 2L >>= fun reply ->
    print_string " answer: ";
    (match reply with
    | Some value ->
        Printf.printf "%Ld\n" value
    | None -> print_endline "None");

    print_endline "decr64: foo01 1L";
  Memcache.decr64 cache "foo01" 1L >>= fun reply ->
    print_string " answer: ";
    (match reply with
    | Some value ->
        Printf.printf "%Ld\n" value
    | None -> print_endline "None");

    print_endline "incr: foo01 1";
  Memcache.incr cache "foo01" "1" >>= fun reply ->
    print_string " answer: ";
    (match reply with
    | Some value ->
        Printf.printf "%s\n" value
    | None -> print_endline "None");

    print_endline "decr: foo01 1";
  Memcache.decr cache "foo01" "1" >>= fun reply ->
    print_string " answer: ";
    (match reply with
    | Some value ->
        Printf.printf "%s\n" value
    | None -> print_endline "None");

    print_endline "getl: foo foo01";
  Memcache.getl cache ["foo"; "foo01"] >>= fun l ->
    List.iter (fun (name, (flags, value)) ->
      Printf.printf " answer: %s (%d) = %s\n" name flags value) l;

    print_endline "add: foo = bar";
  Memcache.add cache "foo" "bar" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "prepend: foo _";
  Memcache.prepend cache "foo" "_" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "append: foo _";
  Memcache.append cache "foo" "_" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "gets: foo";
  Memcache.gets cache "foo" >>= fun resp ->
    match resp with
    | None -> print_endline "TEST FAILED!"; exit 1;
    | Some (name, ((flags, unique), value)) ->
        Printf.printf " answer: %s (%d, %Ld) = %s\n"
          name flags unique value;

    Printf.printf "cas: foo %Ld 'replaced by cas'\n" unique;
  Memcache.cas cache "foo" unique "replaced by cas" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "replace: foo = baz";
  Memcache.replace cache "foo" "baz" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_endline "getsl: foo foo01";
  Memcache.getsl cache ["foo"; "foo01"] >>= fun l ->
    List.iter (fun (name, ((flags, unique), value)) ->
    Printf.printf " answer: %s (%d, %Ld) = %s\n" name flags unique value) l;

    Printf.printf "cas: foo %Ld 'replaced by cas'\n" unique;
  Memcache.cas cache "foo" unique "replaced by cas" >>= fun reply ->
    print_endline (" answer: " ^ (string_of_reply reply));

    print_string "close_connection:";
  Memcache.close_connection cache >>= fun () ->
    print_endline " ok";

  exit 0

let _ = Lwt_main.run t
