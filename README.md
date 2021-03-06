# memcache-ocaml
Fork of http://komar.bitcheese.net/en/code/memcache-ocaml

Memcache support library for OCaml
==================================
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2010 Alexander Markov

Building :
----------

First you need to get
* an ocaml compiler >= 3.11 (http://caml.inria.fr/ocaml);
* GNU Make (http://www.gnu.org/software/make/);
* findlib which provide ocamlfind command
  (http://projects.camlcity.org/projects/findlib.html);
* lwt >= 2.0.0 (http://ocsigen.org/lwt/);
* Batteries Included for ocaml (http://batteries.forge.ocamlcore.org/);

Then simply run

> make

Installation :
--------------

> sudo make install

Usage :
-------

Generate the documentation

> make doc

and watch it.
