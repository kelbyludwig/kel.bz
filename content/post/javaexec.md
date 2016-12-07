+++
draft = false
description = ""
date = "2016-12-06T19:21:35-06:00"
title = "user-influenced os commands are still considered harmful"

+++

# more of the same (sorta)

Its pretty standard advice to avoid using user-input within code that executes
operating system commands. However, most of that advice tends to revolve around
how dangerous it is for a user to provide the *command* to execute and I have
not seen (good) advice on whether other parts of a command (e.g. flags, flag
parameters) are safe to be user-controlled. 

Command injection vulnerabilities do not necessarily require special shell directives or
user-controlled commands. This form of command injection is fairly
straightforward and has had [plenty written about
it](https://www.owasp.org/index.php/Command_injection) so I will focus on
less obvious examples.

Consider the following code snippet that I'm borrowing from an [OWASP page on
command injection](https://www.owasp.org/index.php/Command_injection_in_Java):

```
Runtime runtime = Runtime.getRuntime();
Process proc = runtime.exec("find" + " " + args[0]);
```

The page claims "it is not possible to inject additional commands" so it must
be secure! However, compiling the full Java file and running `java Example1
"bad -exec cat {} +"` on a Linux machine modifies the command being executed. A
program that originally listed file names matching the user-supplied argument
is now a program that *prints the contents* of the user-supplied file. 

What about `tar`? Consider the following two code snippets:

```
String cmd = "tar tf " + userControlledFilename;
Process proc = Runtime.getRuntime().exec(cmd);
```

```
String[] cmdArray = new String[3];
cmdArray[0] = "tar";
cmdArray[1] = "tf";	
cmdArray[2] = userControlledFilename;
Process proc = Runtime.getRuntime().exec(cmdArray);
```

Are they safe? In short the answer is "no" because user-controlled
`tar` flags can lead to command injection. The following example
will execute `echo hello` (the `tar` version may affect results):

```
tar tf file.tar --checkpoint=1 --checkpoint-action=exec="echo hello"
```

The other interesting property of `Runtime.exec` is its behavior depends
on how its called and how its arguments are passed. The following Java
program demonstrates this (I use `gtar` as a GNU tar alias on OS X):

```
// Full file here: https://gist.github.com/kelbyludwig/afb1755af190bb9fe66145b6a1706d76

//Executes a local script.
//String cmd = "gtar tf file.tar --checkpoint=1 --checkpoint-action=exec=evil.sh";

//In some versions, GNU tar runs the checkpoint action with bash.
//String cmd = "gtar tf file.tar --checkpoint=1 --checkpoint-action=exec={echo,test0}";
        
//GNU tar seperates on spaces, tabs, and newlines and `exec` seperates on spaces.
//String cmd = "gtar tf file.tar --checkpoint=1 --checkpoint-action=exec=echo\ttest0";

//Test 1: Does not execute echo command
String cmd = "gtar tf file.tar --checkpoint=1 --checkpoint-action=exec=\"echo test1\"";
System.out.println("TEST1:");
Process proc1 = Runtime.getRuntime().exec(cmd);
readOutput(proc1);

//Test 2: Executes echo command
String[] cmdArray = new String[5];
cmdArray[0] = "gtar";
cmdArray[1] = "tf";    
cmdArray[2] = "file.tar";
cmdArray[3] = "--checkpoint=1";
cmdArray[4] = "--checkpoint-action=exec=\"echo test2\"";
System.out.println("TEST2:");
Process proc2 = Runtime.getRuntime().exec(cmdArray);
readOutput(proc2);

//Test 3: Does not execute echo command
cmdArray = new String[2];
cmdArray[0] = "gtar";
cmdArray[1] = "tf file.tar --checkpoint=1 --checkpoint-action=exec=\"echo test3\"";
System.out.println("TEST3:");
Process proc3 = Runtime.getRuntime().exec(cmdArray);
readOutput(proc3);
```

There are a few interesting results I would like to point out. Suppose
everything after `/usr/local/bin/gtar tf` was user-controlled. First, I find it
interesting that Test 2 does executes `echo` and Test 3 does not. I have some
suspicions on why this is but I need to poke through OpenJDK and figure that
out.  Second, I have included several comments on interesting behaviors of
`Runtime.exec`'s method of parsing its parameters. Depending on the context,
differences in input parsing could lead to input validation bypasses (and
subsequently command injection).

# in conclusion...

`Runtime.exec` is (still) unsafe for user-controlled input! I imagine this is
not specific to Java or `Runtime.exec` either. Code that constructs OS commands
using user-input is scary and error-prone. It should be avoided completely!

If there are not high-level and secure libraries to perform a task without
resorting to OS-level commands I recommend coming up with a solution that
avoids using user-controlled input in that command all together. Shell escaping
is [too fragile](https://lf.lc/CVE-2016-4991.txt) and should be avoided as
well.
