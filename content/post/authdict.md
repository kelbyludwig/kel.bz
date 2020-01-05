---
title: "Authenticated Dictionaries with Skip Lists and Commutative Hashing"
date: 2020-01-05
math: true
tags: [
    "cryptography",
]
summary: "Notes and implementation of the Goodrich and Tamassia paper on authenticated dictionaries with skip lists."
---


Goodrich and Tamassia's paper ["Efficient Authenticated Dictionaries with Skip Lists and Commutative Hashing”](http://www.cs.jhu.edu/~goodrich/cgc/pubs/hashskip.pdf) uses a skip list data structure and a concept called commutative hashing to build an authenticated dictionary. 

Authenticated dictionaries are interesting because they describe a standard way to hash a data set and reveal parts of the hashed data set for authenticated membership queries. Authenticated membership queries allow entities to ask potentially untrusted third parties whether some value exists in a data set and get an answer with metadata that enables verification that the answer is authentic.

If you are familiar with how [certificate transparency log proofs](https://www.certificate-transparency.org/log-proofs-work) work: this is the skip list version.

This notebook implements some of the ideas from Goodrich et. al.'s paper and captures some notes I took along the way.

> This blog post was originally written as a Python notebook. The original
> notebook can be found
> [here](https://github.com/kelbyludwig/kel.bz/blob/master/notebooks/authdict.ipynb).

## Skip lists

Skip lists are a data structure that were introduced by [William Pugh](https://epaperpress.com/sortsearch/download/skiplist.pdf) as a simpler to implement alternative to self-balancing trees with reasonably efficient search, insertion, and deletion properties. Goodrich's paper uses skip lists to implement authenticated dictionaries for similar reasons why one would choose a skip list over other tree-like structures.

For demonstration purposes, I’ve built an incomplete version of a skip list and some helper functions. It is not probabilistic, because I wanted to use specific skip lists to test my implementation against the examples in the paper. Using the skip list implementation to build the example skip list from the paper:


```python
from kelbz.skiplist import SkipList, INF

# Using the skip list from Figure 5 of Goodrich's paper.
skip_list = SkipList([
    [-INF,                                             INF], # Level 5
    [-INF,     17,                                     INF], # Level 4
    [-INF,     17,         25,                     55, INF], # Level 3
    [-INF,     17,         25, 31,                 55, INF], # Level 2
    [-INF, 12, 17,         25, 31, 38,     44,     55, INF], # Level 1
    [-INF, 12, 17, 20, 22, 25, 31, 38, 39, 44, 50, 55, INF], # Level 0
])

assert skip_list.height == 6
assert skip_list.get(12).elem == 12
assert skip_list.get(12).level == 0
assert skip_list.get(77) is None
```

## Commutative Hashing

Commutative hash functions are a relaxation of typical collision resistant hash function. That is, a commutative hash function $h(x, y)$ is defined to return the same results regardless of the order of the two inputs. There is a trivial case that would usually be considered a collision but explicitly permitted for commutative hashing: $h(x, y) = h(y, x)$.

Why introduce commutative hashing? From Section 1.3 of the paper:

> Second, we introduce the use of commutative hashing as a means to greatly simplify the verification process
for a user, while retaining the basic security properties...

(Aside: I was confused by this at first! I explain this in **Why is commutative hashing valuable?** in the appendix below. However, diving into that tangent now wouldn't be fruitful it depends on other parts of the paper we have not touched on.)

The commutative hash function they implement is simple. We first hash the smaller element of the two inputs and then the larger. This is implemented below.


```python
import hashlib

def chash(x, y):
    """Commutative hashing algorithm as described in Goodrich section 3.2.
    
    Assumes input will always be a 256-bit integer, -Inf, or Inf.
    
    This function truncates the output of SHA-256 for readability 
    but it is not required.
    """
    
    # The Goodirch paper doesn't explicitly state how to handle the -Infinity
    # case but there are cases where it expects us to hash -Infinity elements.
    # E.g. The bottom-left node will hit case (1a) which requires
    # a hash of elem(v).
    # 
    # The Goodrich paper *also* says we don't need to hash Infinity elements
    # but I think it also contradicts itself. Since case (1a) would require the
    # hash of elem(w) which could be infinity if v was a non-plateau node immedietely
    # to the left of an Inf node.
    def _to_bytes(i):
        """Serialize a number into a byte string.

        Assumes input will always be a 256-bit integer. Sentinel values
        -Inf/Inf are serialized using values that are not otherwise
        possible under this assumption.
        """
        if i == INF:
            return b"\xff" * ((256//8)+1)
        elif i == -INF:
            return b"\x00" * ((256//8)+1)
        else:
            return i.to_bytes(256//8, byteorder='big')
    
    fst, sec = min(x, y), max(x, y)
    sha256 = hashlib.sha256()
    sha256.update(_to_bytes(fst))
    sha256.update(_to_bytes(sec))
    return int.from_bytes(sha256.digest(), byteorder='big') % 0xff

def chash_sequence(seq):
    """Hash a sequence of values using the algorithm described in Section 3.
    """
    if len(seq) == 2:
        return chash(seq[0], seq[1])
    return chash(seq[0], chash_sequence(seq[1:]))

assert chash(1, 2) == chash(2, 1)
assert chash(1, 2) != chash(2, 3)
assert chash(chash(2, 3), 1) == chash(chash(3, 2), 1) == chash(1, chash(3, 2)) == chash(1, chash(2, 3))
assert chash_sequence([1,2]) == chash(1, 2)
assert chash_sequence([1,2,3]) == chash(1, chash(2, 3))
assert chash_sequence([1,3,2]) == chash(1, chash(2, 3))
assert chash_sequence([1,2,3,4]) == chash(1, chash(2, chash(3, 4)))
```

## Hashing the skip list

Now that we have a skip list implementation, we can build the "label" function $f$ described in Goodrich 4.1. This label is derived from the values to the right and below a given node $v$ and the commutative hash function $chash$ ($h$ in the paper) we just implemented.

To the author's credit, the implementation of the label function $f$ *is* straightforward. I did, however, find the underlying intuition for what the algorithm was accomplishing to be a bit opaque at first. After working out a few examples, I felt I could approximate the algorithm in my head. My notes follow.

To avoid confusion with "tower"/"plateau" terminology (which is used in the context of a single node) I'll call a vertical stack of at least two nodes (one plateau, at least one tower node) a "column".

First let's focus on the base level of the skip list (Cases 1a and 1b in Section 4.1). My shortest explanation for the base level is $f$ is recursively hashing a path to the next "column" to $v$'s right (if one exists). 

For demonstration, consider this snippet of the bottom row of a skip list.

```
    |         |                 |                           |
[ -Inf ] -> [ 1 ] -> [ 2 ] -> [ 3 ] -> [ 4 ] -> [ 5 ] -> [ Inf ]
```

This bottom row has a few columns, indicated by vertical lines above the node. E.g. The node with element 1 and the node with element 3 are both columns.

Working out a few computations of $f(v)$:

* The label of $N_1$ (The base node containing element 1) is: $f(N_1) = h(1, h(2, 3))$.

* The label of $N_2$ is: $f(N_2) = h(2, 3)$.

* The label of $N_3$ is: $f(N_3) = h(3, h(4, h(5, Inf)))$

* The label of $N_5$ is: $f(N_5) = h(5, Inf)$

Note how the hash chain for $N_3$ is longer as there are more lone plateau nodes between the 3-column and the Inf-column.

For nodes not on the base-level (Cases 2a and 2b in Section 4.1), it's a little trickier to explain all at once. Breaking it down into a two observations, first may help:

* Nodes not on the base level recursively hash nodes below and to the right of themselves.

* A node not on the base level $v$'s hash will include the label columns to its right, *if the column's plateau node is at $v$'s height or below*. This is derived from a Case 2a and 2b. As you move down from a starting node $v$, you are checking $w = right(v)$ at each level. If $w$ is a plateau node (i.e. the top of a new column), you recursively compute the label of that new column (which in turn, will include labels of all columns of the same or lesser height from $w$).

Putting all of this together and hand waving a bit: A label for a node $v$ will include all same-sized or smaller columns to the right of $v$ as well as a hash chain of elements at the base connecting each column. Note the top-left "start" node $s$ should be based on the entire structure of the skip-list as all nodes are at least $s$'s height and to the right of $s$.

If this is still opaque, I recommend working out a few examples of hash trees built out of skip lists. For example the skip list segment:

```
  |                 |
[ 3 ] -> [ 4 ] -> [ 5 ]
```

Looks like this hash tree:

```
   h
  / \
 3   h
    / \
   4   5
```

Now for the implementation! This function, given a node in the skip list, returns it's label.


```python
def f(v):
    """Computes a hash representing node `v` in a skip list.
    """
    w = v.right
    u = v.down
    # Base case: w/right is None. Default to a zero value.
    if w is None:
        return 0
    
    # Case 1: We are at the bottom level of the skiplist.
    if u is None:
        # Case 1a: The node to our right is a "tower"
        if w.is_tower:
            return chash(v.elem, w.elem)
        # Case 1b: The node to our right is a "plateau".
        return chash(v.elem, f(w))
    else:
        # Case 2a: The node to our right is a "tower" and we are not on the base level 
        if w.is_tower:
            return f(u)
        # Case 2b: The node to our right is a "plateau" and we are not on the base level
        return chash(f(u), f(w))

# f should be deterministic for a given start node in a list.
assert f(skip_list.start) == f(skip_list.start)

# Some examples of `f` that are simples enough to expand in my head.
assert f(skip_list.get(38)) == chash(38, chash(39, 44))
assert f(skip_list.get(38).up) == chash(chash(38, chash(39, 44)), chash(44, chash(50, 55)))
```

# Authenticated queries

Once we can label nodes in the skip list we can start providing authenticated queries. Authenticated queries can prove a given element does or does not exists in a skip list, even if the answer was provided by a potentially untrusted party.

To provide authenticated queries using the skip list structure, we need:

* A signature (e.g. ed25519) of the start node's label. This signature comes from some trusted party and allows the trusted party to delegate queries to potentially untrusted middlesystems.

* A set of values (called "authentication information") that can be hashed and compared with the signed start node label.

The authentication information should be encoded in an efficient way. One *inefficient* way of encoding authentication information is hashing every element of the skip list in one big hash: `h(-inf | 1 | 2 | ...)`. This is inefficient as the authentication information would have to contain every value within the skip list. In other words, every membership query would return the entire set of values in the skip list in response.

A more efficient way of providing authentication information involves building a hash tree and revealing only parts of the set that need to be revealed and otherwise revealing hashes of sub-components of the skip list. For example, if I want to provide a proof that the value `3` exists in my skip list, I will need to reveal `3` but I might not need to reveal that `7` and `11` are also in the skip list. Instead, we build authentication information that will reveal values close to `3` but when we can, we will otherwise reveal hashes like `h(7, 11)`.

We also need to handle authenticated queries for when queried values *don't* exist in the skip list. This is accomplished by revealing a few nodes that are around the queried value. E.g. If you query for the value `4` and `4` is not in my skip list, I can prove non-membership by providing authentication information that reveals the values (for example) `1`, `3`, and `5`.

The Goodrich paper describes their authentication information set building algorithm in Section 4.3. I've implemented an algorithm that provides authentication information for a given `element` below. I believe the paper has some typos or missing context so it is not *exactly* the same but it seems to function well.


```python
def authenticated_query(skiplist, element):
    """Given a `skiplist` and a `element`, return a set of authentication information 
    that can be hashed and compared to `f(skiplist.start)`.
    """
    search_stack = skiplist.search(element)
    px = list(reversed(search_stack))
    
    # build Q(X)
    qx = []
    w1 = px[0].right
    if w1.is_plateau:
        qx.append(f(w1))
    else:
        qx.append(w1.elem)
    
    # the algorithm in Figure 6 has a typo. It assigns $x1$ (The second element of Q(x))
    # to the value $x$. This cannot be correct, as $x$ is not guaranteed to exist in the
    # skip list. Based on other examples in the paper, I believe $v1$ is the intended value here.
    # px[0] = the paper's $v1$.
    qx.append(px[0].elem)
    
    # Paper is using one-indexing but Python uses zero-indexing.
    # Hence, I start at 1 here, not 2.
    for i in range(1, len(search_stack)):
        wi = px[i].right
        if wi.is_plateau:
            if wi != px[i-1]:
                qx.append(f(wi))
            else:
                if px[i].level == 0:
                    qx.append(px[i].elem)
                else:
                    qx.append(f(px[i].down))
            
    # The special cases from 4.3, where the searched for element does not match $v1$.
    v1 = px[0]
    qxr = list(reversed(qx))
    if v1.elem != element:
        w1 = v1.right
        z = v1.right.right
        # w1 is a tower node, return Q(x) as-is
        if w1.is_tower:
            return qxr
        if w1.is_plateau and z.is_tower:
            # I believe one of these elements from Q(X) should be dropped in this case.
            return qxr[:-1] + [z.elem, w1.elem]
        if w1.is_plateau and z.is_plateau:
            # I believe one of these elements from Q(X) should be dropped in this case.
            return qxr[:-1] + [f(z), w1.elem]
    return qxr


# From Figure 7 description, the authentication information should be the same
assert authenticated_query(skip_list, 39) == authenticated_query(skip_list, 42)
```

Now we can commutatively hash `authenticated_query` results and ensure they match with the label of the head of the skip list:


```python
# Confirm that query information for missing and non-missing values all hash correctly
fs = f(skip_list.start)
for x in range(1, 100):
    qx = authenticated_query(skip_list, x)
    assert chash_sequence(qx) == fs
```

In conclusion, I hope this implementation serves as a halfway decent reference implementation. The Goodrich paper didn't link to any public implementations, so I figured I'd give it a shot.

When reading this paper, I learned there is a lot of literature in this space. I haven't read most of it but if this topic interests you, there are quite a few papers that directly cite this paper.

Thanks for reading. As always, feel free to [contact me](https://kel.bz/about/me/) if you have feedback, comments, or questions.

## Appendix

### Why is commutative hashing valuable?

At first I thought the "simplify the verification process" argument for commutative hashing was confusing. That is, if I provided you an ordered set and defined set hashing as `h(s[0], h(s[1], h(s[2],...` commutativity doesn't make things simpler.

I have since come around to the value-add of commutative hashing. I believe commutativity makes implementation simpler when we account for the difference between how sets of elements are hashed when hashing a skip list and how elements of a query authentication information set are hashed.

My intuition here is that when hashing a skip list, we start from the outside hashing down and to the right. Therefore, we build deeply nested hashes-of-hashes (`h(h(h(h(…`) before we reach values/elements. When we are building authentication information we build $Q(X)$ starting with the nodes near the queried element ($X$). 

In other words, when hashing a skip list, we hash in a depth-first manner. E.g. `h(h(h(3, 4), 2), 1)`. However, when a verifier is hashing authentication information, it hashes along the way: `h(1, h(2, h(3, 4)))`.

Commutative hashing means `h(h(h(3, 4), 2), 1) = h(1, h(2, h(3, 4)))`. Without commutative hashing, I believe either the builder of query authentication information or verifiers would have re-order the set of elements before hashing.

### Hashing Inf and -Inf

Unless I'm missing something the Goodrich paper seems to contradict itself:

> We use $h$ to compute the label $f(v)$ of each node $v$ in the skip list, except for the nodes associated with
the sentinel value Infinity.

However, the skip list hashing scheme described in the paper seems to describe cases where one is expected to hash the Infinity sentinel values.

Take this skip list for example:

```
     |         |
-> [ 7 ] -> [ Inf ]

```

The label of the node with element `7` would hit case 1a and be computed as `f(v) = h(7, Inf)`. The paper does mention that `f(Inf)` should be zero, but not `h(...,elem(Inf))`.

Regardless, I think this is avoidable if your set of skip list elements is finite. I avoided this in my implementation by assuming my set of skip lists elements would be 256-bit numbers, and I encoded `-Inf` and `Inf` as 264-bit numbers. This makes it such that the hash of `-Inf` or `Inf` doesn't obviously collide with other valid skip list elements.
