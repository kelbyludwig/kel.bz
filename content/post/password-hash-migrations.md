---
date: "2015-11-27T20:42:26-05:00"
draft: false
title: "secure password hash migrations"
tags: [
    "cryptography",
]
---

Suppose you are in a situation where you need to migrate from one password
hashing mechanism to another. Common suggestions on StackOverflow suggest that
you should update the database schema to have two new fields: one for the
current password hash and one for the new password hash. To be concise, lets
call these fields `old_password_hash` and `new_password_hash`. After the
database migration is complete d something similar to the following
authentication mechanism is commonly suggested:

```go
if old_password_hash != nil {
        if old_password_hash_algorithm(password) == old_password_hash {
                new_password_hash = new_password_hash_algorithm(password)
                old_password_hash = nil
                // Successful authentication
        } else {
                // Unsuccessful authentication
        }
} else {
        if new_password_hash_algorithm(password) == new_password_hash {
                // Successful authentication
        } else {
                // Unsuccessful authentication
        }

}
```

This scheme is okay. It is transparent to the user (yay!) but leaves old and
presumably weak password hashes in the database for longer than necessary
(boo!). Users who do not authenticate often or have abandoned their account
are stuck with old password hashes.

Alternatively, one can do the same database migration and add
`old_password_hash` and `new_password_hash` but also replace the value stored
in all user's `old_password_hash` field with:

```python
new_password_hash_algorithm(old_password_hash)
```

Now an authentication scheme similar to the previous suggestion can be
implemented. But in this scheme, users with an old password hash would have
their stored hash compared with:

```python
new_password_hash_algorithm(old_password_hash_algorithm(password))
```

Once the user's password is validated, the `old_password_hash` value can be
deleted and then the new password hash can be computed and stored.

My suggestion requires a little more legwork up-front, but remains transparent
to the user (yay!) and does not leave crusty password hashes in the database
longer than necessary (also yay!). [Ashley Madison had to deal with this].

If you are not using scrypt, bcrypt, or PBKDF2 to store user passwords it is
highly probable that your password hashes are not as secure as they could be.
If you have influence over a system that is not using one of those three
algorithms to mask user passwords I would suggest that you implement a
migration plan soon.

If anyone has concerns or questions about this scheme, feel free to contact me
on [Twitter].

I realize that those are not the only 3 "good" options. But in most cases, they
are the [right answer].

[Ashley Madison had to deal with this]: http://www.fortune.com/2015/09/11/ashley-madison-passwords/
[Twitter]: https://twitter.com/kelbyludwig
[right answer]: https://gist.github.com/tqbf/be58d2d39690c3b366ad
