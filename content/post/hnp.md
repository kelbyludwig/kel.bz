---
title: "the hidden number problem"
date: 2019-08-10
math: true
tags: [
    "cryptography",
]
summary: "Notes on the Boneh and Venkatesan's paper describing the Hidden Number Problem and code demonstrating some of the results."
---

# The Hidden Number Problem

The Hidden Number Problem (HNP) is a problem that poses the question: Are the most signficant bits of a Diffie-Hellman shared key as hard to compute as the entire secret? The original problem was defined in the paper ["Hardness of computing the most significant bits of secret keys in Diffie-Hellman and related schemes" by Dan Boneh and Ramarathnam Venkatesan](https://crypto.stanford.edu/~dabo/pubs/abstracts/dhmsb.html).

In this paper Boneh and Venkatesan demonstrate that a bounded number of most signifcant bits of a shared secret are as hard to compute as the entire secret itself. They also demonstrate an efficient algorithm for recovering secrets given a significant enough bit leakage. This notebook walks through some of the paper and demonstrates some of the results.

> This blog post was originally written as a Sage notebook. The original
> notebook can be found
> [here](https://github.com/kelbyludwig/kel.bz/blob/master/notebooks/hnp.ipynb).

## How is the HNP defined?

Like many "hard problems" in cryptography the HNP is defined as a game with an "oracle". When the oracle is queried with a specific number, it returns a value that approximately reveals the most significant bits of the input.

To be concrete, the oracle depends on a $n$-bit prime number $p$ and a $k$-bit significant bit leak. The output of $MSB_{k}(x)$ defined as some value $z$ such that:

$$ |x - z| \lt \frac{p}{2^{k+1}}$$

The Hidden Number Problem oralce reveals $g^x$ and $MSB_{k}(\alpha g^{x} \pmod{p})$ for randomized values of $g^x$ and asks if you can reveal the hidden $\alpha$ value. 

There are a few variations on this problem described in the paper, however, this "randomized" version of the HNP is the only version of the problem we'll focus on.

An implementation of the $MSB$ function can be found below.


```python
# Some parameters of the game, chosen for simplicity.

# p - A prime number for our field.
p = next_prime(2^16)

# n - The number of bits in `p`.
n = ceil(log(p, 2))

# k - The number of significant bits revealed by the oracle.
# Using parameters from Thereom 1.
k = ceil(sqrt(n)) + ceil(log(n, 2))

def msb(query):
    """Returns the MSB of query based on the global paramters p, k.
    """
    while True:
        z = randint(1, p-1)
        answer = abs(query - z)
        if answer < p / 2^(k+1):
            break
    return z

def create_oracle(alpha):
    """Returns a randomized MSB oracle using the specified alpha value.
    """
    alpha = alpha
    def oracle():
        random_t = randint(1, p-1)
        return random_t, msb((alpha * random_t) % p)
    return oracle
```

## What is the MSB function revealing?

Something worth noting about this paper is their defintion of most signficant bits. The definition of $MSB_k$ tripped me up at first as I defaulted to thinking $MSB_{k}(x)$ was intended to reveal exactly the $k$ most significant bits of $x$. If you think the same you may discover: 

* This definition is defined for "some value of $z$" which means $MSB_{k}(x)$ can have multiple correct outputs!

* This definition depends on a prime value $p$ which shouldn't affect $x$'s most significant bits!

These properties of $MSB$ are very unlike the properties I would expect from the most natural definition of most significant bits. This is why earlier I specified that the value revealed by the oracle *approximately* reveals the most signficant bits of the input.

So how do you make sense of the $MSB$ function? I found the following observations helped me grok what it was doing.

* $u = x$ will always be one valid solution satsifying the inequality $| x - u | \leq \frac{p}{2^{k+1}}$. Note that if $u = x$ the oracle's output would be $x$.

* Other solutions to the inequality will "hover" around $x$. Plotting the function `f(u) = | x - u |` for some fixed $x$ values should convince you of this.

* As $k$ increases, the right hand side of the inequality greatly shrinks. This reduces the set of valid $u$ solutions. This also means the set of valid $u$ values are also closer to $x$.

* The $k$ value isn't exactly the number of bits of $x$ revealed. Instead, as $k$ increase, the possible values of $u$s become closer to $x$. The closer $u$ solutions are to $x$, the more likely $x - u$ will accurately reveal $x$'s most significant bits.

Another way to say it: As $k$ grows closer to the number of bits in $p$, the closer $MSB_k(x)$ will be to $x$. The closer the possible answers of $MSB_k(x)$ are to $x$ the more accurate the leaked bits are.

## When is the HNP solvable?

In Section 3 Theorem 1 the paper shows that an adversary has an advantage in solving an instance of the randomized HNP given a $k$ value that is approximately $\sqrt{\log{p}}$ using $d = 2\sqrt{n}$ oracle queries. For this demonstration, I used a more significant $k$ value: $\sqrt{\log{p}} + \log{\log{p}} = \sqrt{n} + \log{n}$.


```python
# d - The number of oracle queries.
# Using parameters from Thereom 1.
d = 2 * ceil(sqrt(n))
```

## Given a useful oracle, how do I solve the HNP?

I'm trying to summarize an otherwise dense paper, so I likely have some of this wrong. With that being said...

Given $d$ oracle queries and answers, solving the HNP can be done by viewing the solution as a specific case of the [Closest Vector Problem](https://en.wikipedia.org/wiki/Lattice_problem). This case of CVP is easy to solve given an useful enough $MSB$ oracle and a specially selected basis.

This special case CVP uses a lattice with the basis vectors:

```
[  p,  0, ... ,  0,   0 ]
[  0,  p, ... ,  0,   0 ]
[         ...           ]
[  0,  0, ... ,  p,   0 ]
[ t1, t2, ... , td, 1/p ]
```

Where $t_N$ values are randomized inputs for the $MSB$ oracle. The lattice is spanned by the rows of this matrix. 

The vector $u$ = `[a1, a2, ..., ad, 0]` is the vector that we want to find a close lattice point to. The $a_N$ values are the outputs of the $MSB$ oracle for the respective $t_N$ values.

A vector with the first coefficient $\alpha t_1 \pmod{p}$ (for example) can be a valid lattice point as $\alpha$ is an integer scalar of the last row, and $\pmod{p}$ is equivalent to subtracting some integer multiple of the first row. 

The vector $v$ is a lattice vector such that each element of $v$ is $\alpha t_n \pmod{p}$ except for the $d+1$th coefficient which is $\frac{\alpha}{p}$. Given the vector $v$, we can recover $\alpha$ easily by scaling the vector by $p$.

By the definition of the $MSB$ oracle, the vector $u$ is likely to be close to $v$. The paper proves this. The paper also proves that $v$ is a likely to be the only vector close to $u$.

Given all of this, we can use a efficient algorithm that solves approximate CVP (e.g. [Babai's Nearest Plane Algorithm](https://www.isical.ac.in/~shashank_r/lattice.pdf)) for $u$. This is likely to find our friend $v$ which reveals $\alpha$. This means we solved a case of the HNP!


```python
def build_basis(oracle_inputs):
    """Returns a basis using the HNP game parameters and inputs to our oracle
    """
    basis_vectors = []
    for i in range(d):
        p_vector = [0] * (d+1)
        p_vector[i] = p
        basis_vectors.append(p_vector)
    basis_vectors.append(list(oracle_inputs) + [QQ(1)/QQ(p)])
    return Matrix(QQ, basis_vectors)

def approximate_closest_vector(basis, v):
    """Returns an approximate CVP solution using Babai's nearest plane algorithm.
    """
    BL = basis.LLL()
    G, _ = BL.gram_schmidt()
    _, n = BL.dimensions()
    small = vector(ZZ, v)
    for i in reversed(range(n)):
        c = QQ(small * G[i]) / QQ(G[i] * G[i])
        c = c.round()
        small -= BL[i] * c
    return (v - small).coefficients()

# Hidden alpha scalar
alpha = randint(1, p-1)

# Create a MSB oracle using the secret alpha scalar
oracle = create_oracle(alpha)

# Using terminology from the paper: inputs = `t` values, answers = `a` values
inputs, answers = zip(*[ oracle() for _ in range(d) ])

# Build a basis using our oracle inputs
lattice = build_basis(inputs)
print("Solving CVP using lattice with basis:\n%s\n" % str(lattice))

# The non-lattice vector based on the oracle's answers
u = vector(ZZ, list(answers) + [0])
print("Vector of MSB oracle answers:\n%s\n" % str(u))

# Solve an approximate CVP to find a vector v which is likely to reveal alpha.
v = approximate_closest_vector(lattice, u)
print("Closest lattice vector:\n%s\n" % str(v))

# Confirm the recovered value of alpha matches the expected value of alpha.
recovered_alpha = (v[-1] * p) % p
assert recovered_alpha == alpha
print("Recovered alpha! Alpha is %d" % recovered_alpha)
```

    Solving CVP using lattice with basis:
    [  65537       0       0       0       0       0       0       0       0       0       0]
    [      0   65537       0       0       0       0       0       0       0       0       0]
    [      0       0   65537       0       0       0       0       0       0       0       0]
    [      0       0       0   65537       0       0       0       0       0       0       0]
    [      0       0       0       0   65537       0       0       0       0       0       0]
    [      0       0       0       0       0   65537       0       0       0       0       0]
    [      0       0       0       0       0       0   65537       0       0       0       0]
    [      0       0       0       0       0       0       0   65537       0       0       0]
    [      0       0       0       0       0       0       0       0   65537       0       0]
    [      0       0       0       0       0       0       0       0       0   65537       0]
    [  48551    1628   14964   48927   50148   53570   35147   30246   38191   58907 1/65537]
    
    Vector of MSB oracle answers:
    (18059, 60122, 7350, 9904, 22254, 10999, 28418, 1197, 4772, 55857, 0)
    
    Closest lattice vector:
    [18088, 60138, 7377, 9917, 22252, 10984, 28403, 1220, 4782, 55883, 10262/65537]
    
    Recovered alpha! Alpha is 10262


## A solution using Sage's IntegerLattice

I also wrote this originally using Sage's `IntegerLattice` module which has a `closest_vector` method. However this was non-ideal because:

* `IntegerLattice` requires integer coefficient basis vectors but the HNP uses $\frac{1}{p}$ as one of the coefficients. This was addressable, as I just scaled the basis and the CVP vectors by a value of $p$.

* `IntegerLattice.closest_vector` is slow, as it solves a more general problem then approximate CVP.

Because I may want to borrow ideas from this code in the future, I'll keep the old and slow solution around.


```python
from sage.modules.free_module_integer import IntegerLattice

def build_integer_lattice(oracle_inputs):
    basis_vectors = []
    for i in range(d):
        p_vector = [0] * (d+1)
        p_vector[i] = p*p
        basis_vectors.append(p_vector)
    scaled_answers = list(map(lambda oi: oi*p, oracle_inputs))
    basis_vectors.append(scaled_answers + [1])
    return IntegerLattice(basis_vectors)

oracle = create_oracle(alpha)
inputs, answers = zip(*[ oracle() for _ in range(d) ])
    
basis = build_integer_lattice(inputs)
v = vector(ZZ, list(answers)  + [0])*p

# This general closest_vector method is pretty slow so I'm leaving it commented out.
# cv = lat.closest_vector(v)
# assert cv[-1] % p == alpha
# print("Found!")
```
