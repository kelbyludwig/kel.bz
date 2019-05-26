+++
title = "rsa-based key encapsulation mechanisms"
date = "2019-05-27"
+++

A key encapsulation mechanism (KEM) can be used to construct a "hybrid" cryptosystems. In these cryptosystems symmetric keys (e.g. for AES) are encrypted using asymmetric keys. The symmetric key is used for encrypting data.

A naive KEM built using RSA primitives could use "textbook" RSA to encrypt a randomly generated symmetric key but this has some significant flaws:

* If `e` is small (e.g. `e`=3), the symmetric key may not be reduced by the modulus after exponentiation. This means the "encrypted" key would be trivially decrypted by taking the `e`th-root of the ciphertext.

* Unpadded RSA ciphertexts can be manipulated in predicatable ways. The paper ["When Textbook RSA is Used to Protect the Privacy of Hundreds of Millions of Users"](https://arxiv.org/pdf/1802.03367.pdf) describes a fantastic attack on an unpadded RSA-based KEM where captured encrypted keys were decrypted by replaying ciphertexts with clever bit-shifts.

These issues could be alleviated by using a secure padding scheme like [OAEP](https://cseweb.ucsd.edu/~mihir/papers/oae.pdf). However, there is a secure KEM that is just about as simple as the textbook KEM called [RSA-KEM](https://www.shoup.net/papers/iso-2.pdf).

RSA-KEM works by generating a random integer `r` in `(0, N-1)` (where `N` is the modulus of the key) and encrypting/encapsulating `r`. The symmetric key is then derived by throwing `r` into a key derivation function (KDF).

As I understand it, OAEP is emulating a construction like RSA-KEM in that it attempts to converts a message into a `r`-like value. The extra complexity that OAEP introduces is to handle messages that are not necessarily evenly distributed in `(0, N-1)` and the padding step needs to be reversible.
