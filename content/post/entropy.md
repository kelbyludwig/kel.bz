---
title: "Measures of Entropy"
date: 2019-06-02
tags: [
    "cryptography",
]
summary: "Different ways to describe the entropy of a random variable."
---

## What is entropy?

Entropy is a measure of information for a random variable. Entropy is often
presented in units of bits. Random events that are likely to happen carry
fewer bits of information than random events that occur infrequently.

One view of entropy is the optimal bit encoding of the outcome of a random variable.
Suppose I needed to transmit to you the winner of a checkers tournament. If
there were 32 players in this tournament, each with equal chances of winning, I
could encode the outcome as:

| Winner    | Encoding |
|-----------|----------|
| Player 1  | 00000    |
| Player 2  | 00001    |
| Player 3  | 00010    |
| Player 4  | 00011    |
| Player 5  | 00100    |
| ......    | ......   |
| Player 31 | 11110    |
| Player 32 | 11111    |

Due to the uniform outcome the result of the tournament has higher
entropy and there is no better bit encoding of winner.

We could do better if Player 1 was highly favored to win. We could encode
"Player 1" in fewer bits (say, 1 bit) and encode other players in *more* bits
(say, 6). Dependent on exactly how probable Player 1's victory is, encoding the
outcome of this tournament could be more efficient than the 5-bit encoding
above. The tournament where Player 1 is favored has less entropy since the
winner is more predictable.

Entropy can be measured in multiple ways. Some measurements [only rely on
the number of possible outcomes](#hartley) while others [factor in the
probability of each possible outcome](#shannon). Others only measure [specific
properties of the random variable](#minentropy). This post explores
multiple entropy measurements and how they differ.

## Hartley entropy {#hartley}

Hartley entropy is a simple measurement that only relies on the
cardinality of the set of possible outcomes. Hartley entropy assumes the
distribution of outcomes are uniform. 

```python
import math

def hartley_entropy(outcome_set, base=2):
    set_cardinality = len(outcome_set)
    return math.log(set_cardinality, base)

coin_toss = {'heads', 'tails'}
dice_roll = {1, 2, 3, 4, 5, 6}
hartley_entropy(coin_toss) #=> 1.0 bits
hartley_entropy(dice_roll) #=> 2.58 bits
```

## Shannon entropy {#shannon}

Shannon entropy is a generalization of Hartley entropy. Shannon entropy takes
the probability of each outcome into account given an "average" measure of
entropy across all outcomes. Given a uniform set of outcomes, Shannon entropy
is equivalent to Hartley entropy.

```python
def shannon_entropy(outcome_dict, base=2):
    entropy = 0
    for _, probability in outcome_dict.items():
        entropy += probability * math.log(probability, base)
    return -entropy

# uniform coin toss
coin_toss = {'heads': 1/2., 'tails': 1/2.}
shannon_entropy(coin_toss) #=> 1.0 bits, same as hartley_entropy

biased_coin_toss = {'heads': 3/4., 'tails': 1/4.}
shannon_entropy(biased_coin_toss) #=> .81 bits, less than the fair coin
```

## Conditional entropy

Conditional entropy is a generalization on Shannon entropy. While Shannon
entropy does factor in the probability of each outcome it assumes that each
outcome occurs independently from one another. Conditional entropy is a measure
of uncertainty given known outcomes. If two events are correlated then knowing
one event happened would lower the entropy of the other.

## Min-entropy {#minentropy}

Min-entropy is a measure of the entropy of the most likely outcome. Constrast
this with Shannon entropy which is a measure of the average outcome.

When a random variable has uniform outcomes, the min-entropy is the same as the
Shannon entropy (and the Hartley entropy).  However, min-entropy is less
forgiving when dealing with biased outcomes. Recall the Shannon entropy from
the biased coin toss above (`.81` bits).  The min-entropy of that outcome is
calculated as:

```python
-math.log(3/4., 2)
```

Which is only about `.42` bits of entropy which is much lower than the Shannon
entropy calculation.
