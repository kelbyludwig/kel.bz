+++
draft = true
date = "2016-11-23"
title = "the ggh cryptosystem"

+++

# The Goldreich–Goldwasser–Halevi (GGH) Cryptosystem

GGH is an asymmetric cryptosystem based on lattices that can be used for
encryption.  Lattices are an interesting primitive with neat properties but are
not incredibly approachable. This purpose of this blog post is to introduce
some of the core concepts behind the GGH cryptosystem and hopefully make it
intuitive as well.

## The End Result

Lets start from the end so we know what we are working towards.

First, a basic understanding of lattices will be established. There will be
some introductory linear algebra involved but nothing too crazy.

Then, we'll look at the GGH cryptosystem and how lattices are used. 

Finally, I'll demonstrate code that encrypts and decrypts messages as
well as some implementation details that I had to smooth out.

## Lattices 

If the words "linear algebra" make you nervous don't fret. I believe this
walkthrough can be understood using knowledge at about the level of the
["Essence of Linear Algebra"](https://www.youtube.com/playlist?list=PLZHQObOWTQDPD3MizzM2xVFitgF8hE_ab)
from 3Blue1Brown. I plan on taking a similar approach to 3Blue1Brown by
focusing less on the math and more on the intuition behind GGH.

### What is a lattice?

A *lattice* can be defined as all linear combinations of a set of vectors where
the coefficients are integers. If you are familiar with the concept of
vector spaces, a lattice is very similar (If you aren't watch [this](https://www.youtube.com/watch?v=k7RM-ot2NWY)). 
To be concrete, consider the set of vectors constructed using `sage`:

``` python
sage: vector_a = vector(RR, [1,0])
sage: vector_b = vector(RR, [0,1])
```

If you take all linear combinations of those vectors using
real number coefficients, you could get *any possible 2-dimensional point*. 
What about `[17, -1.6]` you ask? Well just do the following:

``` python
sage: 17*vector_a + -1.6*vector_b
```

Basically, the *span* of `vector_a` and `vector_b` is the entire 2D plane and
those two vectors form the *basis* of our vector space. What if we had all
linear combinations of the same vectors but required integer coefficients?
That gives us a lattice. Is `[17, -1.6]` a lattice point? Nope! It
requires non-integer coefficients. But `[3, 4]` is a lattice point
because it can be written as a linear combination of the basis vectors
with integer coefficients.

``` python
sage: vector_a = vector(ZZ, [1,0]) 
sage: vector_b = vector(ZZ, [0,1])
sage: 3*vector_a + 4*vector_b
```

So with lattices, our span would not cover (for example) all possible
2-dimensional points so we get this weird collection of dots. To assist with
visualizing some of the concepts discussed here, I wrote [some
code](https://gist.github.com/kelbyludwig/201d08e3e8e9a4f3764f366398f12a47) for
sage to plot a lattice from given basis vectors.

``` python
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

## Why are lattices so special?

There are hard problems associated with lattices. GGH's security depends on the
difficulty of the closest vector problem (CVP). Intuitively, CVP involves
finding the closest lattice point to an arbitrary point that is not on the
lattice. For example:

``` python
sage: ol = vector(RR, [1.7, 2]) # a point that is not on the lattice
sage: show(plot_2d_lattice(va, vb, xmin=-5, xmax=5, ymin=-5, ymax=5) + plot(points(ol, color='red')))
```

In this example, the lattice point `[2, 2]` would be the solution to CVP as its
closest to the off-lattice point `[1.7, 2]`.

CVP appears to be fairly straightforward in the two-dimensional example but
gets much more difficult as the dimension of the basis increases.
Initially working with and visualizing higher-dimension vectors makes the brain
sizzle so I plan on sticking with the two dimensional case.

## How does GGH use CVP?

GGH uses the difficulty of CVP to create an asymmetric key pair. A GGH keypair
consists of two bases: one public, one private. A plaintext message is encoded
as a vector with integer coefficients and a ciphertext is a vector that is not
a lattice point. 

When Alice wants to send a message to Bob, Alice encodes her message as a
vector and computes `ic = message_vector * bobs_public_basis`. This is then
"perturbed" with a small, randomly generated vector `r`. Alice's ciphertext
is `ct = ic + r = message_vector*bobs_public_basis + r`.

To decrypt the message, Bob uses his private basis to solve for `ic` and then
retrieves the original plaintext by multiplying the result by the inverse
of his public key. 

Observant readers may have noticed that I completely glossed over a potentially
important detail: When Bob is decrypting the ciphertext, he must solve an
instance of CVP to recover `ic`. Remember when I said CVP was hard? GGH takes
advantage of a property of certain bases to make solving CVP (technically
approximate CVP) easily. 

## Solving CVP

In a GGH keypair, a public key is a "bad" basis and a private key is a "good"
basis. A "good" basis is a relatively orthogonal with short basis vectors.
There are algorithms for approximating CVP for a "good" basis. One
such algorithm is called Babai's Closest Vector algorithm.

Babai's algorithm takes a point `w` and a set of basis vectors `[v1, ... , vn]`
as input. The algorithm then solves `w = t1*v1 + ... + tn*vn` where `[t1, ... , tn]` are
*real number* coefficients. Babai then approximates a solution to CVP by
rounding all coefficients `t1, ... , tn` to their nearest integer.

For short and relatively orthogonal bases, Babai works well and will likely
return the closest lattice point to `w`! For "bad" bases, Babai is likely to
return a lattice point that is not close to `w`. 

To recap: If Alice's public basis is "bad", and decrypting a ciphertext
requires solving an instance of CVP, the consistently malicious Mallory will
not be able to use Babai's algorithm to decrypt a captured ciphertext. However,
Alice can use her know of her private "good" basis to decrypt messages. Aside
from some of the implementation details, that is all there is to it!

# Some Implementation Details

## Why the perturbation vector? How should the perturbation vector be generated?

`message_vec * public_basis` will always return a lattice point. Why? Because
`message_vec * public_basis` is just a linear combination of basis vectors, and
therefore, results in a lattice point. The perturbation vector bumps `ic` off
the lattice.

Generating the perturbation vector is almost as simple as generating a random
vector. Resources I found suggesting picking a parameter `d` and generating a
n-dimensional vector with elements from `-d -> d`. This threw me for a loop
initially because my perturbation vector would be large enough (mostly because
my basis was fairly small) where my ciphertext vector would be closer to a
*different* lattice point other than my original `ic` point. :shrug:

## How do you generate a public key from the private key? Why do you use unimodular matrices to generate the public key?

My code uses a loop that generates random small bases until a basis exceeds
some orthogonality threshold (I determined the threshold experimentally). Once a 
"good" private basis was generated, a public basis is generated by multiplying
the private basis by randomly generated unimodular matrices.

* TODO(kkl): I still have not determined exactly why the matrices need to be unimodular (or
  if they don't need to be unimodular, why do they suggest such a thing?).

## How do you measure "orthogonality" of a basis?

* TODO(kkl): Dot product, hadamard 

# Putting it all together

* TODO(kkl): a walkthrough of the GGH code.
