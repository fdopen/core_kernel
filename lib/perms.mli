(** These types are intended to be used as phantom types encoding the permissions on a
    given type.

    {1 Basic Usage}

    Here's a hypothetical interface to an on-off switch which uses them:

    {|
      open Perms.Export

      module Switch : sig
        type -'permissions t

        val create : unit -> [< _ perms] t
        val read  : [> read] t  -> [`On | `Off]
        val write : [> write] t -> [`On | `Off] -> unit
      end
    |}

    Note that the permissions parameter must be contravariant -- you are allowed to forget
    that you have any particular permissions, but not give yourself new permissions.

    You can now create different "views" of a switch. For example, in:

    {|
      let read_write_s1 : read_write Switch.t = Switch.create ()
      let read_only_s1 = (read_write_s1 :> read t)
    |}

    [read_write_s1] and [read_only_s1] are physically equal, but calling
    [Switch.write read_only_s1] is a type error, while [Switch.write read_write_s1] is
    allowed.

    Also note that this is a type error:

    {|
      let s1 = Switch.create ()
      let read_write_s1 = (s1 :> read_write t)
      let immutable_s1  = (s1 :> immutable  t)
    |}

    which is good, since it would be incorrect if it were allowed.  This is enforced by:

    1. Having the permissions parameter be contravariant, which causes the compiler to
    require that the result of a [create ()] call has a concrete type (due to the value
    restriction).

    2. Ensuring that there is no type that has both [read_write] and [immutable] as
    subtypes.  This is why the variants are [`Who_can_write of Me.t] and [`Who_can_write
    of Nobody.t] rather than [`I_can_write] and [`Nobody_can_write].

    {1 More Usage Patterns}

    The standard usage pattern is as above:

    {ul
    {- The permissions type parameter is contravariant with no constraints.}
    {- The result of creation functions is a [t] with [[< _ perms]] permissions.}
    {- Functions which take a [t] and access it in some way represent that access in the
       type. }
    }

    The reason for having creation functions return a [t] with [[< _ perms]] permissions
    is to help give early warning if you create a [t] with a nonsensical permission type
    that you wouldn't be able to use with the other functions in the module.

    Ideally, this would be done with a constraint on the type in a usage pattern like
    this:

    {ul
    {- The permissions type parameter is contravariant with constraint [[< _ perms]].}
    {- The result of creation functions is a [t] with no constraint on the permissions.}
    {- Functions which take a [t] and access it in some way represent that access in the
       type. }
    }

    Unfortunately, that doesn't work for us due to some quirks in the way constraints of
    this form are handled:  In particular, they don't work well with [with sexp] and they
    don't work well with included signatures.  But you could try this usage pattern if you
    don't do either of those things.

    For some types you may expect to always have read permissions, and it may therefore by
    annoying to keep rewriting [[> read]].  In that case you may want to try this usage
    pattern:

    {ul
    {- The permissions type parameter is contravariant with constraint [[> read]].}
    {- The result of creation functions is a [t] with [[< _ perms]] permissions.}
    {- Functions which take a [t] and access it in some way represent that access in the
       type, except that you don't have to specify read permissions. }
    }

    However, the standard usage pattern is again preferred to this one: [constraint] has
    lots of sharp edges, and putting [[> read]] instead of [_] in the types provides
    explicitness.
*)

(** Every type in this module besides the following two represent permission sets; these
    two represent who is allowed to write in the [Write.t] and [Immutable.t] types. *)
type nobody with bin_io, compare, sexp
type me     with bin_io, compare, sexp

module Read : sig
  type t = [ `Read ]
  with bin_io, compare, sexp
end

module Write : sig
  type t = [ `Who_can_write of me ]
  with bin_io, compare, sexp
end

module Immutable : sig
  type t = [ Read.t | `Who_can_write of nobody ]
  with bin_io, compare, sexp
end

module Read_write : sig
  type t = [ Read.t | Write.t ]
  with bin_io, compare, sexp
end

module Upper_bound : sig
  type 'a t = [ Read.t | `Who_can_write of 'a ]
  with bin_io, compare, sexp
end

module Export : sig
  (** We don't expose [bin_io] for [write] due to a naming conflict with the functions
      exported by [bin_io] for [read_write].  If you want [bin_io] for [write], use
      [Write.t]. *)
  type read       = Read.          t with bin_io, compare, sexp
  type write      = Write.         t with         compare, sexp
  type immutable  = Immutable.     t with bin_io, compare, sexp
  type read_write = Read_write.    t with bin_io, compare, sexp
  type 'a perms   = 'a Upper_bound.t with bin_io, compare, sexp
end

module Stable : sig
  module V1 : sig
    type nonrec nobody = nobody with bin_io, compare, sexp
    type nonrec me     = me     with bin_io, compare, sexp

    module Read : sig
      type t = Read.t
      with bin_io, compare, sexp
    end

    module Write : sig
      type t = Write.t
      with bin_io, compare, sexp
    end

    module Immutable : sig
      type t = Immutable.t
      with bin_io, compare, sexp
    end

    module Read_write : sig
      type t = Read_write.t
      with bin_io, compare, sexp
    end

    module Upper_bound : sig
      type 'a t = 'a Upper_bound.t
      with bin_io, compare, sexp
    end
  end

  module Export : module type of Export
end
