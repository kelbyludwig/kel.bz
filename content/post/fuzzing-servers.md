---
date: "2015-11-11T18:13:14-05:00"
draft: false
title: "when fuzzing servers"
tags: [
    "software-testing",
    "software-security",
]
---

If you want to use a fuzzer that writes data to STDIN (e.g. [afl-fuzz]) to fuzz
a networked server, consider looking at the server's tests. Often, network
connections are mocked in tests. This code can be repurposed to "send" bytes
from STDIN to the mocked connection.

[Preeny] is another solution, but results can vary.

[afl-fuzz]: http://lcamtuf.coredump.cx/afl/
[Preeny]: https://github.com/zardus/preeny
