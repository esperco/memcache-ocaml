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

let target = Sys.argv.(1)

let key = "benchmark"
let cycles = 50000

let t =
  Memcache.open_connection "localhost" 11211 >>= fun c ->
  Lwt_io.with_file Lwt_io.input target Lwt_io.read >>= fun content ->
  let content_length = String.length content in
  Memcache.set c key ~exptime:360 content >>= function
  | Memcache.STORED ->
      let rec loop n =
        if n < cycles
        then
          Memcache.get c key >>= function
          | None -> assert false
          | Some (recv_key, (_, recv_content)) ->
              assert (recv_key = key && (String.length recv_content) = content_length);
              loop (succ n)
        else return () in
      let bt = Unix.gettimeofday () in
      loop 0 >>= fun () ->
      let et = Unix.gettimeofday () in
      let time = et -. bt in
      Lwt_io.printf "%d cycles done in %f\n" cycles time
  | _ -> assert false

let () = Lwt_main.run t

