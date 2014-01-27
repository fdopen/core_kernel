(** This module defines the [Map] module for [Core.Std].  We use "core_map" as the file
    name rather than "map" to avoid conflicts with OCaml's standard map module.  In this
    documentation, we use [Map] to mean this module, not the OCaml standard one.

    [Map] is a functional datastructure (balanced binary tree) implementing finite maps
    over a totally-ordered domain, called a "key".  The map types and operations appear
    in three places:

    {v
    | Map      | polymorphic map operations                                      |
    | Map.Poly | maps that use polymorphic comparison to order keys              |
    | Key.Map  | maps with a fixed key type that use [Key.compare] to order keys |
    v}

    Where [Key] is any module defining values that can be used as keys of a map, like
    [Int], [String], etc.  To add this functionality to an arbitrary module, use the
    [Comparable.Make] functor.

    One should use [Map] for functions that access existing maps, like [find], [mem],
    [add], [fold], [iter], and [to_alist].  For functions that create maps, like [empty],
    [singleton], and [of_alist], one should strive to use the corresponding [Key.Map]
    function, which will use the comparison function specifically for [Key].  As a last
    resort, if one does not have easy access to a comparison function for the keys in
    one's map, use [Map.Poly] to create the map.  This will use OCaml's built-in
    polymorphic comparison to compare keys, which has all the usual performance and
    robustness problems that entails.

    Parallel to the three kinds of map modules, there are also tree modules [Map.Tree],
    [Map.Poly.Tree], and [Key.Map.Tree].  A tree is a bare representation of a map,
    without the comparator.  Thus tree operations need to obtain the comparator from
    somewhere.  For [Map.Poly.Tree] and [Key.Map.Tree], the comparator is implicit in the
    module name.  For [Map.Tree], the comparator must be passed to each operation.  The
    main advantages of trees over maps are slightly improved space usage (there is no
    outer container holding the comparator) and the ability to marshal trees, because a
    tree doesn't contain a closure, unlike a map.  The main disadvantages of using trees
    are needing to be more explicit about the comparator, and the possibility of
    accidental use of polymorphic equality on a tree (for which maps dynamically detect
    failure due to the presence of a closure in the data structure).

    For a detailed explanation of the interface design, read on.

    An instance of the map type is determined by the types of the map's keys and values,
    and the comparison function used to order the keys:

    {[ type ('key, 'value, 'cmp) Map.t ]}

    ['cmp] is a phantom type uniquely identifying the comparison function, as generated by
    [Comparator.Make].

    [Map.Poly] supports arbitrary key and value types, but enforces that the comparison
    function used to order the keys is polymorphic comparison.  [Key.Map] has a fixed key
    type and comparison function, and supports arbitrary values.

    {[
      type ('key, 'value) Map.Poly.t = ('key , 'value, Comparator.Poly.t) Map.t
      type 'value Key.Map.t          = (Key.t, 'value, Key.comparator   ) Map.t
    ]}

    The same map operations exist in [Map], [Map.Poly], and [Key.Map], albeit with
    different types.  For example:

    {[
      val Map.length      : (_, _, _) Map.t   -> int
      val Map.Poly.length : (_, _) Map.Poly.t -> int
      val Key.Map.length  : _ Key.Map.t       -> int
    ]}

    Because [Map.Poly.t] and [Key.Map.t] are exposed as instances of the more general
    [Map.t] type, one can use [Map.length] on any map.  The same is true for all of the
    functions that access an existing map, such as [add], [change], [find], [fold],
    [iter], [map], [to_alist], etc.

    Depending on the number of type variables [N], the type of accessor (resp. creator)
    functions are defined in the module type [AccessorsN] (resp. [CreatorsN]) in
    {!Core_map_intf}.  Also for creators, when the comparison function is not fixed,
    i.e. the ['cmp] variable of [Map.t] is free, we need to pass a comparator to the
    function creating the map.  The module type is called [Creators3_with_comparator].
    There is also a module type [Accessors3_with_comparator] in addition to [Accessors3]
    which used for trees since the comparator is not known.
*)

open Core_map_intf

module Tree : sig
  type ('k, +'v, 'cmp) t with sexp_of

  include Creators_and_accessors3_with_comparator
    with type ('a, 'b, 'c) t    := ('a, 'b, 'c) t
    with type ('a, 'b, 'c) tree := ('a, 'b, 'c) t
end

type ('key, +'value, 'cmp) t

(** Test if invariants of internal AVL search tree hold. *)
val invariants : (_, _, _) t -> bool

val comparator : ('a, _, 'cmp) t -> ('a, 'cmp) Comparator.t

(** the empty map *)
val empty : comparator:('a, 'cmp) Comparator.t -> ('a, 'b, 'cmp) t

(** map with one key, data pair *)
val singleton : comparator:('a, 'cmp) Comparator.t -> 'a -> 'b -> ('a, 'b, 'cmp) t

(** creates map from association list with unique keys *)
val of_alist
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) list
  -> [ `Ok of ('a, 'b, 'cmp) t | `Duplicate_key of 'a ]

(** creates map from association list with unique keys.  Returns an error if duplicate 'a
    keys are found. *)
val of_alist_or_error
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) list -> ('a, 'b, 'cmp) t Or_error.t

(** creates map from association list with unique keys.  Raises an exception if duplicate
    'a keys are found. *)
val of_alist_exn
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) list -> ('a, 'b, 'cmp) t

(** creates map from association list with possibly repeated keys. *)
val of_alist_multi
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) list -> ('a, 'b list, 'cmp) t

(** combines an association list into a map, folding together bound values with common
    keys *)
val of_alist_fold
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) list -> init:'c -> f:('c -> 'b -> 'c) -> ('a, 'c, 'cmp) t

(** combines an association list into a map, reducing together bound values with common
    keys *)
val of_alist_reduce
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) list -> f:('b -> 'b -> 'b) -> ('a, 'b, 'cmp) t

val to_tree : ('k, 'v, 'cmp) t -> ('k, 'v, 'cmp) Tree.t

val of_tree
  :  comparator:('k, 'cmp) Comparator.t -> ('k, 'v, 'cmp) Tree.t -> ('k, 'v, 'cmp) t

(** creates map from sorted array of key-data pairs. The input array must be sorted, as
    given by the relevant comparator (either in ascending or descending order), and must
    not contain any duplicate keys.  If either of these conditions do not hold, an error
    is returned.  *)
val of_sorted_array
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) array -> ('a, 'b, 'cmp) t Or_error.t

(** Like [of_sorted_array] except behavior is undefined when an [Error] would have been
    returned. *)
val of_sorted_array_unchecked
  :  comparator:('a, 'cmp) Comparator.t
  -> ('a * 'b) array -> ('a, 'b, 'cmp) t

(** Test whether a map is empty or not. *)
val is_empty : (_, _, _) t -> bool

(** [length map] @return number of elements in [map]. *)
val length : (_, _, _) t -> int

(** returns a new map with the specified new binding;
    if the key was already bound, its previous binding disappears. *)
val add : ('k, 'v, 'cmp) t -> key:'k -> data:'v -> ('k, 'v, 'cmp) t

(** if key is not present then add a singleton list, otherwise, cons data on the head of
    the existing list. *)
val add_multi
  :  ('k, 'v list, 'cmp) t
  -> key:'k
  -> data:'v
  -> ('k, 'v list, 'cmp) t

(** [change map key f] updates the given map by changing the value stored under [key]
    according to [f].  Thus, for example, one might write:

    {[change m k (function None -> Some 0 | Some x -> Some (x + 1))]}

    to produce a new map where the integer stored under key [k] is incremented by one
    (treating an unknown key as zero). *)
val change
  :  ('k, 'v, 'cmp) t
  -> 'k
  -> ('v option -> 'v option)
  -> ('k, 'v, 'cmp) t

(** returns the value bound to the given key, raising [Not_found] if none such exists *)
val find     : ('k, 'v, 'cmp) t -> 'k -> 'v option
val find_exn : ('k, 'v, 'cmp) t -> 'k -> 'v

(** returns a new map with any binding for the key in question removed *)
val remove : ('k, 'v, 'cmp) t -> 'k -> ('k, 'v, 'cmp) t

(** [mem map key] tests whether [map] contains a binding for [key] *)
val mem : ('k, _, 'cmp) t -> 'k -> bool

(** iterator for map *)
val iter : ('k, 'v, _) t -> f:(key:'k -> data:'v -> unit) -> unit

(** Iterate two maps side by side.  Complexity of this function is O(M+N).  If two inputs
    are [(0, a); (1, a)] and [(1, b); (2, b)], [f] will be called with [(0, `Left a); (1,
    `Both (a, b)); (2, `Right b)] *)
val iter2
  :  ('k, 'v1, 'cmp) t
  -> ('k, 'v2, 'cmp) t
  -> f:(key:'k -> data:[ `Left of 'v1 | `Right of 'v2 | `Both of 'v1 * 'v2 ] -> unit)
  -> unit

(** returns new map with bound values replaced by f applied to the bound values *)
val map : ('k, 'v1, 'cmp) t -> f:('v1 -> 'v2) -> ('k, 'v2, 'cmp) t

(** like [map], but function takes both key and data as arguments *)
val mapi
  :  ('k, 'v1, 'cmp) t
  -> f:(key:'k -> data:'v1 -> 'v2)
  -> ('k, 'v2, 'cmp) t

(** folds over keys and data in map in increasing order of key. *)
val fold : ('k, 'v, _) t -> init:'a -> f:(key:'k -> data:'v -> 'a -> 'a) -> 'a

(** folds over keys and data in map in decreasing order of key. *)
val fold_right : ('k, 'v, _) t -> init:'a -> f:(key:'k -> data:'v -> 'a -> 'a) -> 'a

val filter
  :  ('k, 'v, 'cmp) t
  -> f:(key:'k -> data:'v -> bool)
  -> ('k, 'v, 'cmp) t

(** returns new map with bound values filtered by f applied to the bound values *)
val filter_map
  :  ('k, 'v1, 'cmp) t
  -> f:('v1 -> 'v2 option)
  -> ('k, 'v2, 'cmp) t

(** like [filter_map], but function takes both key and data as arguments*)
val filter_mapi
  :  ('k, 'v1, 'cmp) t
  -> f:(key:'k -> data:'v1 -> 'v2 option)
  -> ('k, 'v2, 'cmp) t

(** Total ordering between maps.  The first argument is a total ordering used to compare
    data associated with equal keys in the two maps. *)
val compare_direct
  :  ('v -> 'v -> int)
  -> ('k, 'v, 'cmp) t
  -> ('k, 'v, 'cmp) t
  -> int

(** [equal cmp m1 m2] tests whether the maps [m1] and [m2] are equal, that is, contain
    equal keys and associate them with equal data.  [cmp] is the equality predicate used
    to compare the data associated with the keys. *)
val equal
  :  ('v -> 'v -> bool)
  -> ('k, 'v, 'cmp) t
  -> ('k, 'v, 'cmp) t
  -> bool

(** returns list of keys in map *)
val keys : ('k, _, _) t -> 'k list

(** returns list of data in map *)
val data : (_, 'v, _) t -> 'v list

(** creates association list from map.  No guarantee about order. *)
val to_alist : ('k, 'v, _) t -> ('k * 'v) list

val validate : name:('k -> string) -> 'v Validate.check -> ('k, 'v, _) t Validate.check

(** {6 Additional operations on maps} *)

(** merges two maps *)
val merge
  :  ('k, 'v1, 'cmp) t
  -> ('k, 'v2, 'cmp) t
  -> f:(key:'k
        -> [ `Left of 'v1 | `Right of 'v2 | `Both of 'v1 * 'v2 ]
        -> 'v3 option)
  -> ('k, 'v3, 'cmp) t

(** [symmetric_diff t1 t2 ~data_equal] returns a list of changes between [t1] and [t2].
    It is intended to be efficient in the case where [t1] and [t2] share a large amount of
    structure. *)
val symmetric_diff
  :  ('k, 'v, 'cmp) t
  -> ('k, 'v, 'cmp) t
  -> data_equal:('v -> 'v -> bool)
  -> ('k * [ `Left of 'v | `Right of 'v |  `Unequal of 'v * 'v ]) list

(** [min_elt map] @return Some [(key, data)] pair corresponding to the minimum key in
    [map], None if empty. *)
val min_elt     : ('k, 'v, _) t -> ('k * 'v) option
val min_elt_exn : ('k, 'v, _) t ->  'k * 'v

(** [max_elt map] @return Some [(key, data)] pair corresponding to the maximum key in
    [map], and None if [map] is empty. *)
val max_elt     : ('k, 'v, _) t -> ('k * 'v) option
val max_elt_exn : ('k, 'v, _) t ->  'k * 'v

(** same semantics as similar functions in List *)
val for_all : ('k, 'v, _) t -> f:('v -> bool) -> bool
val exists  : ('k, 'v, _) t -> f:('v -> bool) -> bool

(** [fold_range_inclusive t ~min ~max ~init ~f]
    folds f (with initial value ~init) over all keys (and their associated values)
    that are in the range [min, max] (inclusive).  *)
val fold_range_inclusive
  :  ('k, 'v, 'cmp) t
  -> min:'k
  -> max:'k
  -> init:'a
  -> f:(key:'k -> data:'v -> 'a -> 'a)
  -> 'a

(** [range_to_alist t ~min ~max] returns an associative list of the elements whose
    keys lie in [min, max] (inclusive), with the smallest key being at the head of the
    list. *)
val range_to_alist : ('k, 'v, 'cmp) t -> min:'k -> max:'k -> ('k * 'v) list

(** [prev_key t k] returns the largest (key, value) pair in t with key less than k *)
val prev_key : ('k, 'v, 'cmp) t -> 'k -> ('k * 'v) option

(** [next_key t k] returns the smallest (key, value) pair in t with key greater than k *)
val next_key : ('k, 'v, 'cmp) t -> 'k -> ('k * 'v) option

(** [rank t k] if k is in t, returns the number of keys strictly less than k in t,
    otherwise None *)
val rank : ('k, 'v, 'cmp) t -> 'k -> int option

module Poly : sig
  type ('a, +'b, 'c) map

  module Tree : sig
    type ('k, +'v) t = ('k, 'v, Comparator.Poly.comparator_witness) Tree.t with sexp

    include Creators_and_accessors2
      with type ('a, 'b) t    := ('a, 'b) t
      with type ('a, 'b) tree := ('a, 'b) t
  end

  type ('a, +'b) t = ('a, 'b, Comparator.Poly.comparator_witness) map with bin_io, sexp, compare

  include Creators_and_accessors2
    with type ('a, 'b) t    := ('a, 'b) t
    with type ('a, 'b) tree := ('a, 'b) Tree.t
end
  with type ('a, 'b, 'c) map = ('a, 'b, 'c) t

module type Key         = Key
module type Key_binable = Key_binable

module type S = S
  with type ('a, 'b, 'c) map  := ('a, 'b, 'c) t
  with type ('a, 'b, 'c) tree := ('a, 'b, 'c) Tree.t

module type S_binable = S_binable
  with type ('a, 'b, 'c) map  := ('a, 'b, 'c) t
  with type ('a, 'b, 'c) tree := ('a, 'b, 'c) Tree.t

module Make (Key : Key) : S with type Key.t = Key.t

module Make_using_comparator (Key : sig
  type t with sexp
  include Comparator.S with type t := t
end)
  : S
    with type Key.t                  = Key.t
    with type Key.comparator_witness = Key.comparator_witness

module Make_binable (Key : Key_binable) : S_binable with type Key.t = Key.t

module Make_binable_using_comparator (Key : sig
  type t with bin_io, sexp
  include Comparator.S with type t := t
end)
  : S_binable
    with type Key.t                  = Key.t
    with type Key.comparator_witness = Key.comparator_witness
