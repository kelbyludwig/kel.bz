+++
date = "2017-05-27"
description = ""
draft = true
title = "lattice reduction (LLL) intuitively"
+++

# TODO

* https://betterexplained.com/about/

* https://betterexplained.com/articles/adept-method/

## Suggested Background

I don't think LLL will make sense if you don't have a decent grasp on (at least):

* vector spaces and bases

* what a lattice is

* why lattice basis reduction is useful

* vector projections and the Gram-Schmidt process

I wrote another blog post on lattices and how they can be used to form an
asymmetric cryptosystem. [I think it would be a good thing to read
first](https://kel.bz/post/lattices/) as it covers some of the suggested
background.

## LLL Pseudocode

Getting right into it, here is some python pseudocode repurposed from
[wikipedia](https://en.wikipedia.org/wiki/Lenstra%E2%80%93Lenstra%E2%80%93Lov%C3%A1sz_lattice_basis_reduction_algorithm):

``` python
def LLL(B, delta):
    Q = gram_schmidt(B)

    def mu(i,j):
        v = B[i]
        u = Q[j]
        return (v*u) / (u*u)   

    n, k = B.nrows(), 1
    while k < n:

        # length reduction step
        for j in reversed(range(k)):
            if abs(mu(k,j)) > .5:
                B[k] = B[k] - round(mu(k,j))*B[j]
                Q = gram_schmidt(B)

        # swap step
        if Q[k]*Q[k] >= (delta - mu(k,k-1)**2)*(Q[k-1]*Q[k-1]):
            k = k + 1
        else:
            B[k], B[k-1] = B[k-1], B[k]
            Q = gram_schmidt(B)
            k = max(k-1, 1)

   return B 
```

LLL is concise, but there is definitely some seemingly magical logic at first
glance. Let's start with the `mu` function.

## mu

`mu` is the same function used in Gram-Schmidt orthogonalization. Suppose `B`
is our input basis and `Q` is the result of Gram-Schmidt applied to `B`
(without normalization). The constant produced by `mu(i,j)` is the scalar
projection of the `i`th lattice basis vector (`B[i]`) onto the `j`th
Gram-Schmidt orthogonalized basis vector (`Q[j]`). The GIF below is
a brief demonstration of `mu`. 

{{< figure src="/mu.gif" >}}

Gram-Schmidt uses `mu` as follows:

``` python
Q[0] = B[0]
Q[1] = B[1] - mu(1, 0)*Q[0]
Q[2] = B[2] - mu(2, 1)*Q[1] - mu(2, 0)*Q[0]
...
Q[k] = B[k] - mu(k, k-1)*Q[k-1] - mu(k, k-2)*Q[k-2] - ... - mu(k, 0)*Q[0]
```

If Gram-Schmidt and vectors don't make sense, `mu` won't make too much sense.

## length reduction

Isolating the length reduction pseudocode, we have:

``` python
1.  n, k = B.nrows(), 1
2.  # outer loop condition
3.  while k < n:
4.      # length reduction loop
5.      for j in reversed(range(k)):
6.          if abs(mu(k,j)) > .5:
7.              # reduce B[k]
8.              B[k] = B[k] - round(mu(k,j))*B[j]
9.              # re-calculate GS with new basis B
10.              Q = gram_schmidt(B)
```

At line 1, we establish two variables: 

* `n`: which is a constant that holds the number of rows in the basis `B`

* `k`: which keeps track of the index of the vector we are focusing on 

The outer loop condition is less of a concern during the length reduction step,
so we can head straight to the length reduction loop. The length reduction loop
iterates through the `k-1`th vector towards the `0`th vector and checks if the
absolute value of `mu(k,j)` is greater than `1/2`. `1/2` is significant for
since we are rounding the value of `mu(k,j)`, if its absolute value is less
than `1/2` then we would be subtracting a zero vector which wouldn't change the
vector at hand. We could remove that `if` statement on line 6 but we would then
have superfluous assignments (i.e. `B[k] = B[k]`) for some iterations.

The length reduction step is basically Gram-Schmidt with a few minor
modifications.  Here is another way to write the length reduction step
(omitting the `if` condition) for a particular `k`th vector.

``` python
B[k] = B[k] - round(mu(k, k-1))*Q[k-1] - round(mu(k, k-2))*Q[k-2] - ... - round(mu(k, 0))*Q[0]
```

<!--
``` python
B[0] = B[0]
B[1] = B[1] - round(mu(1, 0))*Q[0]
B[2] = B[2] - round(mu(2, 1))*Q[1] - round(mu(2, 0))*Q[0]
...
B[k] = B[k] - round(mu(k, k-1))*Q[k-1] - round(mu(k, k-2))*Q[k-2] - ... - round(mu(k, 0))*Q[0]
```
-->

Just for comparison here is how the `k`th Gram-Schmidt vector is calculated:

``` python
Q[k] = B[k] - mu(k, k-1)*Q[k-1] - mu(k, k-2)*Q[k-2] - ... - mu(k, 0)*Q[0]
```

Pretty similar, eh? 

## does length reduction work?

It may not seem obvious that rounding the result of `mu` and using as a scalar
would produce a good basis. In Gram-Schmidt using the exact value of `mu`
allows for the ideal decomposition of a vector, which can be used to
orthogonalize the vector. Now, we are rounding the result of `mu` which would
affect the orthogonality of the result.  Fortunately, even after rounding `mu`
the length reduction step will produce nearly orthogonal vectors.

In fact, a new length-reduced vector `B[k]` where `B[k] = B[k] -
round(mu(i,j))*B[j]` will always have an angle with `B[j]` that lies between 60
and 120 degrees. This is guarantee that stems from another fact that `B[k]`'s
projection onto `B[j]` will always lie between `-1/2*B[j]` and `1/2B[j]`.
Why is the latter fact true? Intuitively, we have removed all possible
_integer_ components of `B[j]` from `B[k]`, therefore, the resultant
projection of `B[k]` onto `B[j]` must lie between `-1/2*B[j]` and `1/2B[j]`.
Why does this guarantee we have achieved "near" orthogonality?

`soh cah toa => `
`proj_B[k]_onto_B[j] = (B[k]*B[j] / B[j]*B[j])*B[j]`
`abs(B[k]*B[j] / B[j]*B[j]) <= 1/2 #due to previous fact`
`B[k] / proj_B[k]_onto_B[j] = cos(theta)`

<!--
{{< figure src="/angle.png" >}}

* Why is that relevant to "almost" orthogonality? [This is why](http://mathinsight.org/media/image/image/dot_product_projection.png). If the scalar projection of `B[i]` onto `B[j]` is between `-1/2` and `1/2`, then the cosine of the angle between the two vectors is between 60 and 120 degrees (i.e. 90 degrees +/- 30)

    ```
    # just a quick demo of this property if you are bad at trig like me
    def cos_deg(deg):
        return cos(deg / 360 * (2*pi))

    for x in range(0, 180, 10):
        print("cos_deg(%d) = %.2f" % (x, cos_deg(x)))
    ```
-->



* Dependent on ordering of input basis



================
# Old Stuff that I don't like anymore
----------------
----------------
----------------


## Two Dimensional Reduction and Gram-Schmidt

To get a sense of LLL it helps to consider the two-dimensional case. Suppose
we have the following kinda crappy basis.

``` python
sage: b1 = vector(ZZ, [30,40])
sage: b2 = vector(ZZ, [40,50])
sage: from mage import matrix_utils # https://github.com/kelbyludwig/mage; use the install.sh script to install
sage: matrix_utils.plot_2d_lattice(b1, b2, xmin=-60, xmax=60, ymin=-60, ymax=60)
```

{{< figure src="/bad_basis.png" >}}

Why is it crappy? Well, for one, the vectors are pretty long. They are also not
close to orthogonal, which would be ideal (see my lattices post from above for more
intuitive justification). Just from a visual inspection, there are clearly
"better" bases for this lattice.

A good first step in improving this hunk-o-junk basis is applying
[Gram-Schmidt](https://en.wikipedia.org/wiki/Gram%E2%80%93Schmidt_process).
Gram-Schmidt (GS) will take a basis for a vector space (like our lattice) and transform
the basis vectors into a set of (optionally normalized) orthogonal vectors. 

_TODO(kkl): Intuition behind GS here?_

GS gets us closer to the basis we want, but GS is not guaranteed to produce
orthogonal vectors that form a basis for our lattice. Check it:

``` python 
sage: b1 = vector(ZZ, [3,5])
sage: b2 = vector(ZZ, [8,3])
sage: B  = Matrix(ZZ, [b1,b2])
sage: Br,_ = B.gram_schmidt()
sage: pplot = matrix_utils.plot_2d_lattice(B[0], B[1]) 
sage: pplot += plot(Br[0], color='grey', linestyle='-.', legend_label='unmodified', legend_color='blue') 
sage: pplot += plot(Br[1], color='grey', linestyle='-.', legend_label='orthogonalized', legend_color='grey')
sage: pplot
```

{{< figure src="/gs_compare.png" >}}

And to show just how close Gram-Schmidt could get us, lets compare the
orthogonalized basis to the LLL-reduced basis.

``` python
sage: b1 = vector(ZZ, [3,5])
sage: b2 = vector(ZZ, [8,3])
sage: B = Matrix(ZZ, [b1,b2])
sage: Bl = B.LLL()
sage: pplot = matrix_utils.plot_2d_lattice(Bl[0], Bl[1])
sage: pplot += plot(Br[0], color='grey', linestyle='-.', legend_label='LLL-reduced', legend_color='blue')
sage: pplot += plot(Br[1], color='grey', linestyle='-.', legend_label='orthogonalized',legend_color='grey')
sage: pplot
```

{{< figure src="/lll_gs_compare.png" >}}

Note that the orthogonalized (grey) vectors are not included in the original
lattice. We can, however, modify the internals of GS to produce vectors that
_are_ in the original basis.  Instead of *just* taking the projection of each
vector onto subsequent vectors, we can round the scalar produced during the
projection and use a guaranteed integer scalar. Before, GS used vector
projection code that would look something like this:

``` python
def proj(u, v):
    zv = zero_vector(len(u))
    if u == zv:
        return zv
    return ((v*u) / (u*u)) * u
```

Now, we can just modify the return:

``` python
def proj_round(u, v):
    zv = zero_vector(len(u))
    if u == zv:
        return zv
    return round((v*u) / (u*u)) * u
```
<s>
Is the vector result of `proj_round` a lattice vector?  Yup. `round((v*u) /
(u*u))` is just a integer scalar of `u`. By the definition of a lattice, if `u`
is a lattice vector the value returned by `proj_round` is a lattice vector.

Say we took Gram-Schmidt, and replaced `proj` with `proj_round`. Let's
call it `gs_round`. Would `gs_round` give us a better basis? I believe it would
in some cases but I don't think that is true for all cases. Gram-Schmidt works
well because it is removing every possible component of previous basis vectors
from a vector. `gs_round` only approximates this behavior. As the number of
vectors in the basis grows larger, each iteration would likely produce worse
results as we are dealing with approximations of approximations.
</s>

## LLL and GS - Friends Forever

Tampering with the internals of Gram-Schmidt didn't get us what we want.
However, Gram-Schmidt will still be very useful as we start our path to LLL. In
fact, part of the reason why I started with Gram-Schmidt is because there are
some similarities between their processes. Not only are there outputs similar
(i.e. a basis that is "better" than the input, yet spans the same space), but
both leverage vector projections as a way to remove redundancy from a basis.
More than that, LLL uses Gram-Schmidt as a sub-routine to assist in determining
what to do.

## the magic of `mu`

So what does `mu(i,j)` measure? It is scalar projection of the `i`th lattice
basis vector (`B[i]`) onto the `j`th Gram-Schmidt orthogonalized basis vector
(`Q[j]`). One way to look at it, is an function that quantifies the angle
between `B[i]` and `Q[j]`. If `mu(i,j)` is close to 0 then the angle between
the two vectors are almost orthogonal. As the angle between the two vectors
gets farther from 90 degrees, the absolute value of `mu(i,j)` grows larger.
Below is a GIF demonstrating this behavior. Notice how `mu(1,0)` gets
closer to 0 as `B[1]` is closer to orthogonality with `Q[0]`.

{{< figure src="/mu.gif" >}}

Why is `mu` comparing lattice vectors to orthogonalized vectors that are not
likely lattice vectors? `Q` is pretty much the "ideal" situation. Every vector
within `Q` is orthogonal to all other vectors in `Q`. We may not be able to use
`Q` directly nor will we necessarily have a completely orthogonal lattice
basis, however, we can use `Q` as a guide for how close our lattice basis is to
an ideal situation.

`mu` is important to LLL as it is used in both the length reduction step and
the swap step. At first, we can focus on it's application in the length reduction
step.

# LLL Questions I Want to Answer

* What is mu(i,j) measuring?

    * mu(i,j) is the scalar projection of the `i`th lattice basis vector (`B[i]`) onto the `j`th Gram-Schmidt orthogonalized basis vector (`Q[j]`)

    * mu(i,j) leverages the orthogonalized basis (which is unlikely to be a basis for the same lattice) as a guide-post.

    * mu(i,j) provides a measurement of the angle formed by `B[i]` and the `Q[j]` 

    * if mu(i,j) is close to 0 then the angle between the two vectors are almost orthogonal. as the angle between the two vectors grows close to 0 degrees or 180 degrees, the absolute value of mu(i,j) gets larger 

    * so if `mu(i,j)` suggests the `i`th lattice vector is that close to orthogonality with the `j`th GS vector, its probably the case that the `i`th lattice vector is close to orthogonal to the `j` lattice vector. 

    * by subtracting `round(mu(i,j))*jth_lattice_vector` from the `i`th lattice vector, we are removing all integral components of the `j`th lattice vector from the `i`th lattice vector. this result will be close to orthogonal (more on this in a second).

* How can we guarantee that computing `B[i] = B[i] - round(mu(i,j))*B[j]` (where `B[i]` is the ith lattice basis vector) will make `B[i]` "close" to orthogonal to `B[j]`?

    * `B[i] - round(mu(i,j))*B[j]` will always result in a vector whose projection onto `B[j]` lies between `-1/2*B[j]` and `1/2*B[j]`.

    * Why is that true? I didn't get this so [I asked StackOverflow :)](https://crypto.stackexchange.com/questions/46960/what-is-the-significance-of-the-value-1-2-within-the-first-property-of-a-lll-r). TODO(kkl) I did the algebra somewhere. Find those notes and throw them in here.

    * Why is that relevant to "almost" orthogonality? [This is why](http://mathinsight.org/media/image/image/dot_product_projection.png). If the scalar projection of `B[i]` onto `B[j]` is between `-1/2` and `1/2`, then the cosine of the angle between the two vectors is between 60 and 120 degrees (i.e. 90 degrees +/- 30)

        ```
        # just a quick demo of this property if you are bad at trig like me
        def cos_deg(deg):
            return cos(deg / 360 * (2*pi))
   
        for x in range(0, 180, 10):
            print("cos_deg(%d) = %.2f" % (x, cos_deg(x)))
        ```

* What does it mean when `abs(mu(i,j))` is greater than .5?

    * It means that we have at least one integral component of `B[j]` that we can remove from `B[i]`

* What does the first inner loop (length reduction step) accomplish in LLL?

    * TODO(kkl): Include some LLL pseduocode

    * Starting from `j = k-1` and decrementing towards `j = 0`, `mu(k,j)` is computed

        * e.g. suppose k = 3; then the loop computes `mu(3,2); mu(3,1); mu(3,0)` at each iteration

    * For each `mu(k,j)` computation, it is checked if `B[k]` can be reduced using `Q` as a guide-post

    * At the end of this loop `B[k]` is (probably) quite a bit shorter, since all integral components of `B[0:k-1]` have been removed.

    * `B[k]` is also pretty close to orthogonal to `B[0:k-1]`. This process is kinda like fuzzy Gram-Schmidt.

* What is the significance of the Lovasz condition?

    * LLL is dealing with ordered bases. While the length reduction step will (probably) shorten basis vectors, the ordering of the basis could affect results.

    * For example, [this StackOverflow post](https://crypto.stackexchange.com/questions/39532/why-is-the-lov%C3%A1sz-condition-used-in-the-lll-algorithm?rq=1) gives an example of a basis whose order negatively affects the quality of the reduction.

    * TODO(kkl) I don't have a great intuitive explanation for why the Lovasz condition works but it does 

* Is LLL guaranteed to terminate?

    * [3.2](https://ocw.mit.edu/courses/mathematics/18-409-topics-in-theoretical-computer-science-an-algorithmists-toolkit-fall-2009/lecture-notes/MIT18_409F09_scribe20.pdf)
