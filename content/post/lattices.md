---
date: 2016-11-23
title: "The GGH Cryptosystem"
tags: [
    "cryptography",
]
summary: "An introduction to lattice-based cryptography using the broken Goldreich–Goldwasser–Halevi (GGH) cryptosystem."
---


The Goldreich–Goldwasser–Halevi (GGH) Cryptosystem is an asymmetric
cryptosystem based on lattices that can be used for encryption. Lattices are
pretty cool because lattice-based cryptography has some interesting properties
(some lattice-based cryptosystems are believed to be quantum resistant!).

GGH is pretty cool because it is straightforward to learn. GGH also has
interesting properties that could allow an adversary to recover plaintext from
a given ciphertext (I said cool not secure). 

This blog post will serve as an introduction to lattices and some concepts
surrounding lattice-based cryptography. After getting a feel for lattices and
how GGH works, I will subsequently demonstrate that GGH is squishy when
implemented as the author originally described it.

## Lattices 

If the words "linear algebra" make you nervous don't fret. I believe this
walkthrough can be understood using knowledge at about the level of the
["Essence of Linear
Algebra"](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
from 3Blue1Brown. At first, I plan on taking a similar approach to 3Blue1Brown
by focusing less on the math and more on the intuition behind GGH. Nguyen's
attack toward the end will be a bit less abstract but the math
involved there is not terrible.

### What is a Lattice?

A *lattice* can be defined as all linear combinations of a set of vectors where
the coefficients are integers. If you are familiar with the concept of
vector spaces, a lattice is similar (If you aren't watch [this](https://www.youtube.com/watch?v=k7RM-ot2NWY)). 
To be concrete, consider the set of vectors constructed using `sage`:

```python
sage: vector_a = vector(RR, [1,0])
sage: vector_b = vector(RR, [0,1])
```

If you take all linear combinations of those vectors using
real number coefficients, you could get *any possible 2-dimensional point*. 
What about `[17, -1.6]` you ask? Well just do the following:

```python
sage: 17*vector_a + -1.6*vector_b
```

Basically, the *span* of `vector_a` and `vector_b` is the entire 2D plane and
those two vectors form the *basis* of our vector space. What if we had all
linear combinations of the same vectors but required integer coefficients?
That gives us a lattice. Is `[17, -1.6]` a lattice point? Nope! It
requires non-integer coefficients. But `[3, 4]` is a lattice point
because it can be written as a linear combination of the basis vectors
with integer coefficients.


```python
sage: vector_a = vector(ZZ, [1,0]) 
sage: vector_b = vector(ZZ, [0,1])
sage: 3*vector_a + 4*vector_b
```

So with lattices, our span would not cover (for example) all possible
2-dimensional points so we get this weird collection of dots. 


To assist with visualizing some of the concepts discussed here, I wrote [some
code](https://gist.github.com/kelbyludwig/201d08e3e8e9a4f3764f366398f12a47) for
sage to plot a lattice from given basis vectors. 

```python
sage: load("ggh.sage")
sage: va = vector(ZZ, [1,0])
sage: vb = vector(ZZ, [0,1])
sage: show(plot_2d_lattice(va, vb))
sage: vc = vector(ZZ, [1,2])
sage: show(plot_2d_lattice(va, vc)) 
sage: show(plot_2d_lattice(va, vc, show_basis_vectors=False)) 
sage: vd = vector(ZZ, [25,2])
sage: show(plot_2d_lattice(va, vd, xmin=0, xmax=50, ymin=0, ymax=50))
```

It is important to note that a basis consists of only the vectors
needed to span the lattice. In other words, a set of vectors that
make up a lattice will not have any redundant vectors.

``` python
sage: va = vector(ZZ, [1,0])
sage: vb = vector(ZZ, [0,1])
sage: vc = vector(ZZ, [1,1])
```

In the above example, a lattice constructed with `va`, `vb`, and `vc` would not
form a basis because `vc = va + vb`. Furthermore, any given lattice can have
multiple bases. Below, `va` and `vb` span the same lattice as `vc` and `vd`
(the plots created by `plot_2d_lattice` may look different but the lattices are
the same).

``` python
sage: va = vector(ZZ, [1,0])
sage: vb = vector(ZZ, [0,1])
sage: vc = vector(ZZ, [1, 1])
sage: vd = vector(ZZ, [-1,-2])
sage: show(plot_2d_lattice(va, vb))
sage: show(plot_2d_lattice(vc, vd))
```

## Why Are Lattices So Special?

Lattices have hard problems associated with them. GGH's security depends on the
difficulty of the closest vector problem (CVP). Intuitively, CVP involves
finding the closest lattice point to an arbitrary point. For example:

``` python
sage: ol = vector(RR, [1.7, 2]) # a point that is not on the lattice
sage: show(plot_2d_lattice(va, vb, xmin=-5, xmax=5, ymin=-5, ymax=5) + plot(points(ol, color='red')))
```

In this example, the lattice point `[2, 2]` would be the solution to CVP as its
closest to the off-lattice point `[1.7, 2]`.

CVP appears to be straightforward in the two-dimensional example but it
is believed that CVP is difficult for higher dimension lattices (say, 200-400). 
Initially working with and visualizing higher-dimension vectors makes
the brain sizzle so I plan on sticking with the two dimensional case.

## Solving CVP (In Some Cases)

In a GGH keypair, a public key is a "bad" basis and a private key is a "good"
basis. A "good" basis is a close to orthogonal with short basis vectors.
There exist algorithms for approximating CVP for a "good" basis. One
such algorithm is called Babai's Closest Vector algorithm.

Babai's algorithm takes a point `w` and a set of basis vectors `[v1, ... , vn]`
as input. The algorithm then solves `w = t1*v1 + ... + tn*vn` where `[t1, ... , tn]` are
*real number* coefficients. Babai then approximates a solution to CVP by
rounding all coefficients `t1, ... , tn` to their nearest integer.

For short and approximately orthogonal bases, Babai works well and will likely
return the closest lattice point to `w`! For "bad" bases, Babai is likely to
return a lattice point that is not close to `w`.

## How Does GGH Use CVP?

GGH takes advantage CVP's assumed difficulty for "bad" bases to create an asymmetric
key pair. A GGH keypair consists of two bases for the same lattice: one public,
one private. A plaintext message is encoded as a vector with integer
coefficients and a ciphertext is a vector that is not a lattice point. 

When Alice wants to send a message to Bob, Alice encodes her message as a
vector and computes `ic = message_vector * bobs_public_basis`. This is then
"perturbed" with a small, randomly generated vector `r`. Alice's ciphertext
is `ct = ic + r = message_vector*bobs_public_basis + r`.

To decrypt the message, Bob uses his private basis to solve for `ic` and then
retrieves the original plaintext by multiplying the result by the inverse
of his public key. 

## Some Implementation Details

### Why the perturbation vector? How should the perturbation vector be generated?

`message_vec * public_basis` will always return a lattice point. Why? Because
`message_vec * public_basis` is just a linear combination of basis vectors, and
therefore, results in a lattice point. The perturbation vector bumps `ic` off
the lattice.

Generating the perturbation vector is almost as simple as generating a random
vector. Resources I found suggesting picking a parameter `d` and generating a
n-dimensional vector with elements from `-d -> d`. This threw me for a loop
initially because my perturbation vector would be large enough (because
my basis was small) where my ciphertext vector would be closer to a
*different* lattice point other than my original `ic` point.

### How do you generate a public key from the private key? Why do you use unimodular matrices to generate the public key?

My code uses a loop that generates random small bases until a basis exceeds
some orthogonality threshold (I determined the threshold experimentally). Once
a "good" private basis was generated, a public basis is generated by
multiplying the private basis by randomly generated unimodular matrices.  When
a basis is multiplied by a unimodular matrix, the lattice spanned by the
resultant matrix is equal to the original basis. This is covered a bit more in
[these](https://cseweb.ucsd.edu/classes/wi10/cse206a/lec1.pdf) lecture notes.


### How do you measure "orthogonality" of a basis?

Orthogonality can be measured with something called the Hadamard ratio. The
provided sage code uses this to generate GGH keypairs.

## Nyguen's Attack

GGH (as the author's originally described it) is basically toast. A couple
years after GGH was published, [Phong Q.
Nguyen](https://www.di.ens.fr/~pnguyen/pub_Ng08.htm) demonstrated an attack
against GGH that allows an attacker to decrypt a ciphertext encrypted via a
given a public key. Ouch. Nguyen's attack is also decently simple to follow!


In the [original GGH
paper](https://groups.csail.mit.edu/cis/pubs/shafi/1997-lncs-ggh.pdf), the
error vector used during message encryption is an n-vector `e` with its entries
set to `sigma` or `-sigma`(`sigma` is commonly 3). Recall that in GGH a
message `m` is encrypted with a public key `B` using the following formula:

```python
c = m*B + e
```

Nyguen attack works as follows. First, taking the ciphertext modulo `sigma`
causes `e` to disappear from the equation. Why? Because `e` is a vector
consisting only of `sigma` and `-sigma` (which are both 0 modulo `sigma`).

```python
c = m*B + e 
c = m*B (mod sigma)
```

While this leaks some information about `m` (specifically `m (mod sigma)`),
more information could be leaked with a little algebra and a slightly larger
modulus. This is accomplished by increasing the modulus to `2*sigma` and adding
an all-`sigma` vector `s` to the equation.

```python
c = m*B + e 
s + e = 0 (mod 2*sigma)
c + s = m*B + e + s (mod 2*sigma)
c + s = m*B + 0 (mod 2*sigma)
c + s = m*B (mod 2*sigma) # nice!
```

We know `c`, `s`, and `B` in this equation. If we solve for `m`, we reveal
information about `m`. Specifically, we learn `m (mod 2*sigma)`. A solution to
`m` is not guaranteed but Nyguen also demonstrated that in most cases it could
be easily solved. This is already not looking great for GGH but it
definitely gets worse. 

Working under the assumption that we solved the previous equation, denote `m
(mod 2*sigma)` by `m2s`. Using some more algebra magic we can create the
following equation (I'll explain it in just a second):

```python
c - m2s*B = (m - m2s)*B + e
```

Note, that `(m - m2s)` will give a vector of the form `2*sigma*m_p` (I had to puzzle
this out in sage but some small examples make it obvious). We don't know what `m_p`
is just yet but that is fine. Now lets incorporate that into our previous equation:

```python
c - m2s*B = (m - m2s)*B + e
c - m2s*B = 2*sigma*m_p*B + e
c - m2s*B = 2*sigma (m_p*B + (e/2*sigma)
(c - m2s*B) / (2*sigma) = m_p*B + (e/2*sigma)
```

Yeah that looks awful. Okay. Hear me out. We know everything on the left-hand
side there. Lets just call it `c_p`. 

```python
c_p = m_p*B + (e/2*sigma)
```

`c_p` is just a point in space. It is similar to a GGH ciphertext. Recall the equation
for a ciphertext in GGH:

```python
c = m*B + e
c_p = m_p*B + (e/2*sigma)
```

We have reduced the original CVP problem to another CVP problem with an
effectively random message using an error vector that is a *much shorter version
of the original*. Considering this is a "special" case of the CVP problem, it
could be solved using specialized algorithms that solve CVP for points that are
close to a lattice point. Nguyen also mentions that the "traditional
methods" of solving special CVP cases work better when an error vector is
smaller.

## Does this work?

Oh yes! This attack has a fun story behind it too.

Sometimes cryptographers will provide some form of a "challenge" to encourage
analysis of their cryptosystems. If the system holds up, the challenge should
increase confidence in the scheme. These challenges, however, are not always
well-received because they are believed to be
[unrealistic](https://web.archive.org/web/20171213214126/https://moxie.org/blog/telegram-crypto-challenge/) and/or
[unfair](https://www.schneier.com/crypto-gram/archives/1998/1215.html#1).

GGH's authors hosted a challenge to demonstrate GGH's security. They presented
5 public keys of differing security levels and 5 messages encrypted using GGH. This
"Ciphertext Only" attack model is a pretty low bar. There are probably a good
number of questionable cryptosystems that could stand-up to such an attack but
would crumble instantly under increased pressure.

Nguyen used this technique to break *all five* of the GGH challenges in
"reasonable time". A choice quote from Nguyen's paper:

> This proves that GGH is insecure for the parameters suggested by Goldreich,
> Goldwasser and Halevi. Learning the result of our experiments, one of the
> authors of GGH declared the scheme as “dead”

RIP

*Thanks to David Wong and Sean Devlin providing valuable feedback on this write-up*
