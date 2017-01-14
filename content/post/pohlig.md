+++
date = "2017-01-14"
title = "a note on subgroup confinement attacks"
draft = true
+++

The Pohlig-Hellman algorithm is a efficient method of solving the discrete log
problem for groups whose order is a `smooth integer`. A smooth integer is just
an integer whose prime factorization consists of mostly small prime numbers.

Pohlig-Hellman could be used to efficiently recover private keys from broken
(EC)DH implementations. There are some cryptopals exercise that use it (its in
set 8). This attack is often referred to as a "subgroup confinement" attack.
It's really cool. (I do not plan on covering the algorithm here
[Wikipedia](https://en.wikipedia.org/wiki/Pohlig%E2%80%93Hellman_algorithm) has
a pretty good walkthrough of the algorithm).

Something that initially tripped me up was that subgroup confinement does not
work in a single context. When looking up the algorithm in most textbooks (or,
you know, Wikipedia) Pohlig-Hellman takes advantage of a single element whose
order is a smooth integer. In other words, we want to solve `h = g^x (mod m)`
with knowledge of `h`, `g`, and `m`. If the order of `g` is smooth, we can
recover bits of `x` with only a single element `h`. This is the "offline"
case.

Another context for subgroup confinement allow leverages an "online" oracle. In
this context, the target implementation could accept malicious group elements
`g` and respond with `h = g^x (mod m)`. Dependent on the properties of `m` the
attacker could generate many different values for `g` that make solving for `h`
easy(ish).

This is not revolutionary or crazy! It's just something that had stumped me when
working on this attack.
