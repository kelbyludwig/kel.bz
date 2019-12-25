---
title: "Fiat-Shamir Heuristic"
date: 2018-09-22
tags: [
    "cryptography",
]
summary: "Overview and implementation of the Fiat-Shamir heuristic used to build signature schemes from interactive zero-knowledge proofs."
---

The Fiat-Shamir heuristic is commonly referenced method of turning interactive zero-knowledge proofs into signature schemes. I believe this concept was introduced in the paper "[How To Prove Yourself: Practical Solutions to Identification and Signature Problems](https://dl.acm.org/citation.cfm?id=36676)".

The basic idea of the heuristic is that one of the interactive steps performed by the verifier, specifically the selection of a set of random bits, is replaced by a hash function.

The "How To Prove Yourself" (HTPY) paper also describes a specific identification protocol. This notebook implements that identification protocol, as well as the transformation of the identification protocol to signature scheme using the described heuristic.


> This blog post was originally written as a Sage notebook. The original
> notebook can be found
> [here](https://github.com/kelbyludwig/kel.bz/blob/master/notebooks/fiat-shamir-heuristic.ipynb).


```python
import hashlib

# secret parameters only known to the Center
p, q = next_prime(2^32), next_prime(2^33)

# global parameters
N = p*q
ZN = Zmod(N)
t, k = 4, 4

def f(*args):
    h = hashlib.md5()
    for a in args:
        h.update(str(a))
    hd = h.hexdigest()
    return ZN(int(hd, 16))

class Center(object):
    
    def provision_prover(self, identity):
        secret_root = ZN(randint(1, N-1))^-1
        return InteractiveProver(identity, secret_root)

class InteractiveProver(object):
    
    def __init__(self, identity, secret_root):
        self.identity = identity
        self.secret_root = secret_root
        
    def commit(self):
        self.prover_random = ZN(randint(1, N-1))
        return self.identity, self.secret_root^2, self.prover_random^2
    
    def respond(self, verifier_random):
        y = self.secret_root^verifier_random
        return self.prover_random*y
            

class InteractiveVerifier(object):
    
    def challenge(self, identity, public_square, prover_random):
        self.prover_random = prover_random
        self.verifier_random = randint(0,1)
        self.public_square = public_square
        return self.verifier_random
        
    def check(self, proof):
        y = self.public_square^self.verifier_random
        return proof^2 == self.prover_random*y
        

center = Center()
verifier = InteractiveVerifier()
me = center.provision_prover("@kelbyludwig")

for _ in range(256):
    # begin identification protocol
    (identity, public_square, prover_random) = me.commit()
    verifier_random = verifier.challenge(identity, public_square, prover_random)

    # generate my proof
    proof = me.respond(verifier_random)

    # present proof to verifier
    assert(verifier.check(proof))
```


```python
class NewCenter(object):
    
    def provision_signer(self, identity):
        secret_root = ZN(randint(1, N-1))
        return Signer(identity, secret_root)

class Signer(object):
    
    def __init__(self, identity, secret_root):
        self.identity = identity
        self.secret_root = secret_root
        self.public_square = secret_root^-2
    
    def sign(self, message):
        r = f(randint(1, N-1))
        x = r^2
        e = f(message, x).lift().bits()[0]
        y = r*self.secret_root^e
        return self.public_square, e, y
        
    
class Verifier(object):
    
    def verify(self, message, public_square, e, y):
        # assume the verifier knows the `public_square` is
        # legitimately tied to the signer
        z = y^2 * public_square^e
        calculated_e = f(message, z).lift().bits()[0]
        return calculated_e == e

center = NewCenter()
verifier = Verifier()

for _ in range(256):
    me = center.provision_signer("@kelbyludwig")
    message = "foo"
    public_square, e, y = me.sign(message)
    assert(verifier.verify(message, public_square, e, y))
```

# Notes

## The Selection of the Function `f`

In the HTPY paper, the function `f` is described as a "pseudo random function... which maps arbitrary strings to the range [0, N)". However, the applications of the Fiat-Shamir heuristic that I have seen have used a hash function as `f`. It's my understanding that hash functions are *not* PRFs, so maybe the original definition of the heuristic has just changed over time.

My selection of `f` in my code above is for simplicity (Or at least that is what I have told myself). I can pretty much gaurantee it's broken in some way.

## Why does the interactive version in HTPY use the function `f` to generate public values on each protocol run?

I do not do this in the code above, but in the original HTPY paper, the list of `vj` values is created by applying `f` to the user's identifier and a series of small indices. 

This seems superfluous, as the user's identifier and these indices are public information. I'm guessing that this is used to lower the size of data transmitted in the protocol, since the target application described in the paper is constrained smartcards.

Also, since `f` is used during transformation to a signature scheme, there is no extra cost to keep `f` in the smartcard.
