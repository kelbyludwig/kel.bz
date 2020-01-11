---
title: "P-256 in Sage"
date: 2020-01-10
tags: [
    "cryptography",
]
summary: "Reference code for creating NIST P-256 curve objects in Sagemath."
---


This notebook demonstrates how to create a NIST P-256 curve ([aka secp256r1](https://tools.ietf.org/search/rfc4492#appendix-A)) and it's standard base point in [Sagemath](https://www.sagemath.org/).


> This blog post was originally written as a Python notebook. The original
> notebook can be found
> [here](https://github.com/kelbyludwig/kel.bz/blob/master/notebooks/sage-p256.ipynb).

First, we define the parameters that make up the P-256 curve. The parameters are from "[SEC 2: Recommended Elliptic Curve Domain Parameters](https://www.secg.org/SEC2-Ver-1.0.pdf)".


```python
# Finite field prime
p256 = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF

# Curve parameters for the curve equation: y^2 = x^3 + a256*x +b256
a256 = p256 - 3 
b256 = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B

# Base point (x, y)  
gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296
gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5

# Curve order
qq = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
```

Then we can create a EllipticCurve sage object over a finite field.


```python
# Create a finite field of order p256
FF = GF(p256) 

# Define a curve over that field with specified Weierstrass a and b parameters
EC = EllipticCurve([FF(a256), FF(b256)]) 

# Since we know P-256's order we can skip computing it and set it explicitly
EC.set_order(qq) 

# Create a variable for the base point
G = EC(FF(gx), FF(gy))
```

We can compare results to a few [public test vectors](http://point-at-infinity.org/ecc/nisttv) to make sure everything is working as intended.

These test vectors are defined as three-tuples: (scalar `k`, x-coordinate of `k*G`, y-coordinate of `k*G`)


```python
test_vectors = [
    (1, 
     0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296, 
     0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5),
    (2,
     0x7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978,
     0x07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1),
    (3,
     0x5ECBE4D1A6330A44C8F7EF951D4BF165E6C6B721EFADA985FB41661BC6E7FD6C,
     0x8734640C4998FF7E374B06CE1A64A2ECD82AB036384FB83D9A79B127A27D5032),
    (4,
     0xE2534A3532D08FBBA02DDE659EE62BD0031FE2DB785596EF509302446B030852,
     0xE0F1575A4C633CC719DFEE5FDA862D764EFC96C3F30EE0055C42C23F184ED8C6),
    (5,
     0x51590B7A515140D2D784C85608668FDFEF8C82FD1F5BE52421554A0DC3D033ED,
     0xE0C17DA8904A727D8AE1BF36BF8A79260D012F00D4D80888D1D0BB44FDA16DA4)
]

for k, x, y in test_vectors:
    P = k*G
    Px, Py = P.xy()
    assert Px == x
    assert Py == y
```

That seems alright. We can do a simple ECDH to double check as well.


```python
for _ in range(100):
    alice_private = randint(0, qq-1)
    alice_public = alice_private*G

    bob_private = randint(0, qq-1)
    bob_public = bob_private*G

    assert alice_private*bob_public == bob_private*alice_public
```
