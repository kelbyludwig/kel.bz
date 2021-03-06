---
title: "ECDSA is Weird"
date: 2019-07-28
math: true
tags: [
    "cryptography",
]
summary: "Unexpected properties of ECDSA signatures."
---

This notebook demonstrates some unexpected properties of ECDSA signatures. This notebook was heavily inspired by [SalusaSecondus's "Crypto Gotchas"](https://github.com/SalusaSecondus/CryptoGotchas/blob/master/README.md).

> This blog post was originally written as a Sage notebook. The original
> notebook can be found
> [here](https://github.com/kelbyludwig/kel.bz/blob/master/notebooks/ecdsa-is-weird.ipynb).

## ECDSA implementation using NIST P-256

This notebook uses the NIST P-256 curve for demonstration, so we'll need to define that curve and it's base point first. This first block of code may be opaque. An annotated version is in its own [blog post](https://kel.bz/post/sage-p256/).


```python
p256 = 115792089210356248762697446949407573530086143415290314195533631308867097853951 
a256 = p256 - 3 
b256 = 41058363725152142129326129780047268409114441015993725554835256314039467401291 
gx = 48439561293906451759052585252797914202762949526041747995844080717082404635286
gy = 36134250956749795798585127919587881956611106672985015071877198253568414405109
qq = 115792089210356248762697446949407573529996955224135760342422259061068512044369

FF = GF(p256) 
EC = EllipticCurve([FF(a256), FF(b256)]) 
EC.set_order(qq) 

# base point
G = EC(FF(gx), FF(gy))

# finite field of GF(qq) where qq is the order of the group G
Fq = GF(qq)
```

Now that we have a base point, we can define some functions that make up ECDSA signing and verification.


```python
from hashlib import sha256

def sha256_hasher(m):
    """Hash a message and map it to an Integer
    """
    s = sha256()
    s.update(m)
    digest = s.hexdigest()
    return Integer(digest, 16)

def generate_keypair(k=None):
    """Generate a keypair. If k is provided, use it as the private scalar.
    """
    if k is None:
        # a random private scalar, generated using a unsafe RNG 
        # for simplicity
        k = randint(1, qq)
    return k, k*G

def sign(private_key, message, k=None, hasher=sha256_hasher):
    """Sign `message` with the specified private key.
    
    `message` is hashed and mapped to a group element
    as part of signing. The default implementation of 
    is sha256_hasher.
    """
    # a per-signature random scalar
    if k is None:
        k = randint(1, qq)
    # a per-signature random point
    x, _ = (k*G).xy()
    # map various values to GF(qq) where qq is the order of
    # group generated by G.
    r = Fq(x)
    k = Fq(k)
    z = Fq(hasher(message))
    pkq = Fq(private_key)
    # compute the s value of the signature, in GF(qq)
    s = k^-1 * (z + r * pkq)
    return (r, s)

def verify(public_key, message, r, s, hasher=sha256_hasher):
    """Verify a signature (`r`,`s`) over `message` with the
    specified public key.
    
    `message` is hashed and mapped to a group element as part
    of verification. The default implementation is sha256_hasher.
    Verification must use the same hasher as `sign` in order to
    produce correct results.
    """
    # map the message to a element in GF(qq)
    z = Fq(hasher(message))
    # invert s in GF(qq)
    sinv = s^-1
    # compute intermediate verification scalars
    u1 = z*sinv
    u2 = r*sinv
    # extract x, y values from point addition and scaling
    x, _ = (Integer(u1)*G + Integer(u2)*public_key).xy()
    return Fq(x) == r
```

Now that we have these functions, we can do a basic signing and verification roundtrip to check that we have done everything correctly.


```python
# generate a keypair
private, public = generate_keypair(13)

# sign a message with our private key
message = "a message to sign!"
r, s = sign(private, message)

# verify the signature is correct!
assert verify(public, message, r, s), "Signature was invalid!"

# verify incorrect signatures are invalid!
_, new_public = generate_keypair(7)
assert not verify(new_public, message, r, s), "Invalid signature was valid!"
print("no problem!")
```

    no problem!


With that out of the way we can start with the first weird property.

## Signature malleability

ECDSA signatures are malleable. Given a valid signature `(r, s)`, one can create a second valid signature by negating the `s` value. This is demonstrated below.

This is not the only way in which signatures are malleable. Since ECDSA signatures are pairs of numbers, their encoding maybe maellable. Encodings of these pairs *should* only have one representation but some implementations may be more permissive. For example, the integer 2 may be encoded as the byte string `\x02` or `\x00\x02`. [Project Wycheproof has great set of test vectors](https://github.com/google/wycheproof/blob/master/java/com/google/security/wycheproof/testcases/EcdsaTest.java) that looks for implementations that accept multiple encodings as valid.


```python
# generate a random keypair
private, public = generate_keypair()

# sign a message with our private key
message = "a test of malleable signatures"
r, s = sign(private, message)

# verify the signature is correct
assert verify(public, message, r, s), "Signature was invalid!"

# negate s and the signature will still be valid!
assert verify(public, message, r, -s), "Negated s signature was invalid!"
print("no problem!")
```

    no problem!


## Duplicate signatures

The paper ["Flaws in Applying Proof Methodologies to Signature Schemes"](https://www.researchgate.net/publication/221355164_Flaws_in_Applying_Proof_Methodologies_to_Signature_Schemes) describes an interesting property of ECDSA which the author's call "Duplicate Signatures".

Duplicate signatures are signatures that are the exact same for multiple distinct messages. It is trivial to generate a keypair that has valid duplicate signatures for chosen messages!


```python
def create_duplicate_signatures_keypair(m1, m2):
    """Generates a keypair and signature given two messages `m1` and `m2`.
    
    The generated keypair will be valid. The generated (`r`, `s`) values are
    a valid signature on both `m1` and `m2` for the generated public key.
    """
    # generate a random scalar
    k = randint(1, qq)
    # get a random point's x value
    x, _ = (k*G).xy()
    # map values to GF(qq)
    r = Fq(x)
    k = Fq(k)
    h1 = Fq(sha256_hasher(m1))
    h2 = Fq(sha256_hasher(m2))
    # generate a private scalar using specific values derived
    # from the input messages and the random scalar
    private_scalar = -(h1 + h2) / (2*r)
    # generate a signature value for both messages
    s = k^-1 * (h1 + private_scalar*r)
    private_scalar = Integer(private_scalar)
    return private_scalar, private_scalar*G, r, s


private, public, r, s = create_duplicate_signatures_keypair("foo", "bar")
# verify the duplicate signature property
assert verify(public, "foo", r, s)
assert verify(public, "bar", r, s)

# generate another signature to test the keypair being otherwise valid
r2, s2 = sign(private, "baz")
assert verify(public, "baz", r2, s2)

print("no problem!")
```

    no problem!


## Creating a valid signatures without knowledge of a message

Suppose I'm using a signature verification interface that accepts a hashed value instead of a message. That is, instead of a function like `verify` below, I use a function like `direct_verify`:

```python
def verify(public_key, message, r, s):
    digest = hash(message)
    # verification using digest
    # ....
    
def direct_verify(public_key, digest, r, s):
    # i trust you provided me a trustworthy digest
    # verification using digest
    # ....
```

As a signature verifier, if I trust digests without knowing the corresponding message, an attacker can generate valid signatures for any public key. In this case, the attacker doesn't necessarily know the corresponding *message* to the digest but a sufficiently trusting (or faulty) verifier may not recognize that.

This trick was used by some person in an attempt to convince people that they invented Bitcoin. This great ["Faketoshi" application](https://albacore.io/faketoshi) demonstrates that you too can trick people into believing you invented Bitcoin!


```python
def direct_verify(public, digest, r, s):
    """Verifies a signature given an already hashed message digest as an Integer
    """
    direct_hasher = lambda x: x
    return verify(public, digest, r, s, hasher=direct_hasher)

def generate_signature_for_public_key(public_key):
    """Given any public key, this create a signature for a random digest.
    
    The corresponding message to the generated digest is unknown.
    """
    # generate random scalars
    a = randint(1, qq)
    b = randint(1, qq)
    # generate a random point using the above 
    # scalars and the target public key
    R = a*G + b*public_key
    x, _ = R.xy()
    # map values to GF(qq)
    a = Fq(a)
    b = Fq(b)
    # compute the signature values
    r = Fq(x)
    s = r / b
    # compute the digest value
    z = r * (a/b)
    return Integer(z), r, s

# generate a new keypair
private, public = generate_keypair()

# generate a signature and digest using only knowledge of the public key!
digest, r, s = generate_signature_for_public_key(public)

# verify the signature validates when the digest is used directly
assert direct_verify(public, digest, r, s)
print("no problem!")
```

    no problem!


## Knowledge of k for a given signature leaks the private key

If the random `k` value used during signature generation is ever known, an attacker with that value can recover the private key used to sign that message.


```python
def recover_private_scalar(message, r, s, k, hasher=sha256_hasher):
    h = Fq(hasher(message))
    k = Fq(k)
    return (s*k - h) / r

# generate a keypair
private, public = generate_keypair()

message = "i used a bad k!"
# fix a k value
fixed_k = 1337

# generate a signature with known k value
r, s = sign(private, message, k=fixed_k)

# confirm the signature is valid
assert verify(public, message, r, s), "Signature was invalid!"

# recover private scalar given known k
recovered_private = recover_private_scalar(message, r, s, fixed_k)
assert recovered_private == private, "Recovered private scalar was wrong"

print("no problem!")
```

    no problem!


## Repeating k values for two distinct messages leaks the private key

If a signer repeats a `k` value for two distinct messages `k` can be recovered. This, as was just shown, leaks the private key.


```python
def recover_private_scalar_from_repeated_k(m1, r1, s1, m2, r2, s2, hasher=sha256_hasher):
    """Recovers the private scalar given two signatures over distinct 
    messages with repeating k values.
    """
    # Note that a repeat k value can be detected by colliding r values
    assert r1 == r2
    h1 = Fq(hasher(m1))
    h2 = Fq(hasher(m2))
    # recover k
    k = (h1 - h2) / (s1 - s2)
    # recover private key from k
    return recover_private_scalar(m1, r1, s1, k, hasher=hasher)

# generate a keypair
private, public = generate_keypair()

# generate two messages and a fixed nonce
m1 = "message one with k"
m2 = "message two with k"
fixed_k = 0xcafe

# generate signatures with fixed k value
r1, s1 = sign(private, m1, k=fixed_k)
r2, s2 = sign(private, m2, k=fixed_k)

# confirm the signatures are valid
assert verify(public, m1, r1, s1), "Signature one was invalid!"
assert verify(public, m2, r2, s2), "Signature two was invalid!"

# recover private scalar given known k
recovered_private = recover_private_scalar_from_repeated_k(m1, r1, s1, m2, r2, s2)
assert recovered_private == private, "Recovered private scalar was wrong"

print("no problem!")
```

    no problem!


## More?

There are some other fun ECDSA properties worth exploring but they are probably best covered in their own notebook.

* Duplicate signature key selection from Koblitz's and Menezes' ["Another Look at Security Definitions"](https://eprint.iacr.org/2011/343.pdf)

* Private key recovery against a signer using biased `k` values as described in Nguyen's ["The insecurity of the elliptic curve digital signature algorithm with partially known nonces"](https://dl.acm.org/citation.cfm?id=937385)

Both of these are covered in [Set 8 of Cryptopals](https://cryptopals.com/sets/8).
