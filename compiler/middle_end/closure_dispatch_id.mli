(** Path-space interval decomposition for DAGs.

    Ball-Larus path numbering algorithm

    For each node v, compute:

    N(v) = number of paths from v to any leaf

    using dynamic programming with memoization:

    N(v) = 1 if v is a leaf N(v) = Σ N(child) otherwise

    Then, for each node v with ordered children c1, c2, ..., ck, assign an
    offset to every outgoing edge:

    offset(v, ci) = Σ N(cj) for j < i

    The offset of an edge is therefore the prefix sum of the path counts of its
    preceding siblings.

    Properties:

    - Unary edges always receive offset 0.
    - Only branching nodes contribute to path ranks.
    - Shared subgraphs are handled naturally.
    - Runs in O(V + E) on a DAG.
    - For a path P, the rank is:

    rank(P) = Σ offset(e) for e in P

    - For a fixed root, the ranks of all root-to-leaf paths are exactly:

    0 .. N(root) - 1

    with no gaps and no collisions.

    With multiple roots, ranking is root-local: paths are identified by (root,
    rank). *)

open Syli_common

type graph = { root_ids : int list; edges : int list IntMap.t }
type t

val compute_dispatch_ids : graph -> t
val edge_weight : t -> src:int -> target:int -> int
