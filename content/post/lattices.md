+++
draft = true
description = ""
date = "2016-11-23T22:43:10-06:00"
title = "notes on lattices"

+++

1. Vector Spaces and Bases
2. Lattices
3. SVP and CVP
4. Good and Bad Bases
5. Projection and Gram-Schmidt
6. GGH

* Probably the most concise and easy-to-follow notes on lattices: http://www.math.brown.edu/~jhs/Presentations/WyomingLattices.pdf
* Lattice: https://en.wikipedia.org/wiki/Lattice_(group)
* Gram-Schmidt: https://en.wikipedia.org/wiki/Gram%E2%80%93Schmidt_process
* Hermite-Constant: https://en.wikipedia.org/wiki/Hermite_constant
* Why is the Lovasz condition used in the LLL algorithm?: https://crypto.stackexchange.com/questions/39532/why-is-the-lov%C3%A1sz-condition-used-in-the-lll-algorithm
* 2.2 has some good intuition on lattice reduction http://algo.epfl.ch/_media/en/projects/bachelor_semester/rapportetiennehelfer.pdf
* Lagrange-Gauss reduced
	* Intuitively: You have two basis vectors, the vector b1 has a norm (read: length) that is smaller (or equal to) the vector b2.
					If there is *any* integer q s.t. `b2 + qb1` has a smaller norm than b2 or b1 than the lattice formed by b1 and
					b2 can be formed with shorter vectors!
	* Example:
	```
	a = vector([-1,1])
	b = vector([4,1])
	r = vector([5,0])
	g = vector([3,2])
	o = vector([2,3])
	print("a:", N(a.norm()))
	print("b:", N(b.norm()))
	print("r:", N(r.norm()))
	print("g:", N(g.norm()))
	print("o:", N(o.norm()))
	show(plot_2d_lattice(a,b) + plot(r, color='red') + plot(g, color='green') +  plot(o, color='orange'))
	```
