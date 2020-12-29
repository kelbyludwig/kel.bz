---
title: "Notes on Virtualization.Framework"
date: 2020-12-29
tags: [
    "macos",
]
summary: "Notes from reversing implmentation details of the macOS Virtualization.Framework"
---

> These are my notes from reversing implmentation details of the macOS
[Virtualization.Framework](https://developer.apple.com/documentation/virtualization).
This writeup doesn't lead to a notable outcome. It is loosely organized notes
on a process with a few takeaways.

# Background and Problem

Big Sur on macOS that added the
[Virtualization.Framework](https://developer.apple.com/documentation/virtualization?language=objc).
This is a higher-level API for creating and managing virtual machines than the
[Hypervisor.Framework](https://developer.apple.com/documentation/hypervisor?language=objc)
which gives you a seemingly thin wrapper around [Intel
VT-x](https://en.wikipedia.org/wiki/X86_virtualization#Intel_virtualization_(VT-x)).

The great thing about Virtualization.Framework is that it provides a fairly
high-level API to boot into a Linux Kernel:
[`VZLinuxBootLoader`](https://developer.apple.com/documentation/virtualization/vzlinuxbootloader?language=objc).
Booting Linux was possible with Hypervisor.Framework, you would just need some
bootstrapping implementation like [`xhyve`](https://github.com/machyve/xhyve).

Recently I was using [`vftool`](https://github.com/evansm7/vftool) which
provides a thin wrapper CLI around Virtualization.Framework but I was seeing
fairly unreliable results with booting various Linux distributions. The
[workflow outlined in the Github issues vftool by user
droidix](https://github.com/evansm7/vftool/issues/2#issuecomment-735455161) was
helpful in getting an Ubuntu VM setup but following similar workflows didn't
quite work for all Linux distributions. I could successfully boot Ubuntu,
Fedora, and OpenSUSE using the same rough workflow described here but was less
successful in booting Arch and TinyCoreLinux. TinyCoreLinux is notable example
distribution because that is [a test distribution that xhyve
uses](https://github.com/machyve/xhyve/blob/master/xhyverun-tinycorelinux.sh).
I had assumed (with no clear justification) that Virtualization.Framework was
borrowing code from xhyve given that xhyve is used in popular projects like
[HyperKit](https://github.com/moby/hyperkit). Attempting to boot TinyCoreLinux
using vftool lead to a "successful" boot of a VM but as soon as the the VM
starts it transitions to a 'Done' state within a second or so. There is no
output to the serial console during this time.

```shell
$ vftool -k tinycorelinux/vmlinuz -i tinycorelinux/core.gz -m 1024 -a 'console=hvc0'
2020-12-29 11:25:19.792 vftool[54377:1257388] vftool (v0.3 10/12/2020) starting
2020-12-29 11:25:19.793 vftool[54377:1257388] +++ kernel at tinycorelinux/vmlinuz, initrd at tinycorelinux/core.gz, cmdline 'console=hvc0', 1 cpus, 1024MB memory
2020-12-29 11:25:19.794 vftool[54377:1257388] +++ fd 3 connected to /dev/ttys008
2020-12-29 11:25:19.794 vftool[54377:1257388] +++ Waiting for connection to:  /dev/ttys008
2020-12-29 11:25:24.905 vftool[54377:1257388] +++ Configuration validated.
2020-12-29 11:25:24.905 vftool[54377:1257388] +++ canStart = 1, vm state 0
2020-12-29 11:25:25.266 vftool[54377:1257486] +++ VM started
2020-12-29 11:25:25.913 vftool[54377:1257388] +++ Done, state = 3
$
```

It is _very_ possible I'm not using vftool properly, or providing the right
format of kernel or initrd to vftool. However, there isn't much of a feedback
loop. It is very unclear _why_ this failed to successfully boot.
While it is probably not the most scientific approach to debugging, I started to
dig more into how Virtualization.Framework was implemented so I could see if I
could better understand what I might be doing wrong (Spoiler: I didn't figure
this out but I took notes along the way).

# Debugging vftool and Virtualization.Framework

My original approach was debugging vftool with lldb and trying to find some
indication of something failing. During this time I also used [this helpful
guide in dumping the dynamic library
cache](https://lapcatsoftware.com/articles/bigsur.html) so I could drop
{Virtualization,Hypervisor}.framework binaries into Hopper.

This took me the most time (I don't debug Obj-C too often so it took some time
to get cozy in the debugger) but I don't believe Virtualization.Framework
itself uses much (if any) of Hypervisor.Framework. I didn't comprehensively
reverse it but my takeaway is that Hypervisor.Framework is a small client that
provides a high level API for sending XPC messages to
`com.apple.Virtualization.VirtualMachine.xpc` which does the hardware emulation
and kernel bootstrapping in a sandbox. 

As an example see this Hopper disassmebly snippet for `VZVirtualMachine`'s
`_ensureConnectionWithCompletionHandler` which creates an XPC connection to
"com.apple.Virtualization.VirtualMachine":

```markdown
                     -[VZVirtualMachine _ensureConnectionWithCompletionHandler:]:
00007fff6efb47a0         push       rbp                                         ; Begin of try block
<snip>
00007fff6efb47be         mov        rax, qword [rax]
00007fff6efb47c1         mov        qword [rbp+var_30], rax
00007fff6efb47c5         mov        rdi, rdx
00007fff6efb47c8         call       qword [_objc_retain_7fff8703c418]           ; _objc_retain, _objc_retain_7fff8703c418
00007fff6efb47ce         mov        rbx, rax
00007fff6efb47d1         mov        rsi, qword [r12+0x10]                       ; argument "targetq" for method imp___stubs__xpc_connection_create
00007fff6efb47d6         lea        rdi, qword [aComapplevirtua]                ; End of try block started at 0x7fff6efb47a0, Begin of try block (catch block at 0x7fff6efb4db6), argument "name" for method imp___stubs__xpc_connection_create, "com.apple.Virtualization.VirtualMachine"
00007fff6efb47dd         mov        qword [rbp+var_90], rax
00007fff6efb47e4         call       imp___stubs__xpc_connection_create          ; xpc_connection_create
```

# Reversing com.apple.Virtualization.VirtualMachine.xpc 

After sorting out that the Hypervisor.Framework client seems to defer most of
the interesting virtualization logic to an XPC service I started reversing that
service. Thankfully, the XPC service isn't in some fancy cache so I could just
nab it off the filesystem.

```shell
$ pwd
/System/Library/Frameworks/Virtualization.framework/XPCServices/com.apple.Virtualization.VirtualMachine.xpc/Contents

$ ls -ltrh
total 16
-rw-r--r--  1 root  wheel   520B Jan  1  2020 version.plist
drwxr-xr-x  3 root  wheel    96B Jan  1  2020 _CodeSignature/
drwxr-xr-x  3 root  wheel    96B Jan  1  2020 Resources/
drwxr-xr-x  3 root  wheel    96B Jan  1  2020 MacOS/
-rw-r--r--  1 root  wheel   1.6K Jan  1  2020 Info.plist

$ file MacOS/com.apple.Virtualization.VirtualMachine
MacOS/com.apple.Virtualization.VirtualMachine: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64e:Mach-O 64-bit executable arm64e]
MacOS/com.apple.Virtualization.VirtualMachine (for architecture x86_64):        Mach-O 64-bit executable x86_64
MacOS/com.apple.Virtualization.VirtualMachine (for architecture arm64e):        Mach-O 64-bit executable arm64e
```

Running the VirtualMachine binary in a shell just crashes:
```shell
$ ./MacOS/com.apple.Virtualization.VirtualMachine
fish: './MacOS/com.apple.Virtualizatio…' terminated by signal SIGILL (Illegal instruction)
$
```
I didn't sort out why this happens and if it is intentional. I suppose I didn't expect this to work!

The XPC service has a pretty large sandbox profile that I didn't dig into too much:
```shell
$ head Resources/com.apple.Virtualization.VirtualMachine.sb
;;; Copyright (c) 2020 Apple Inc.  All Rights reserved.
;;;
;;; WARNING: The sandbox rules in this file currently constitute
;;; Apple System Private Interface and are subject to change at any time and
;;; without notice.
;;;
(version 1)

(disable-full-symbolication)
(deny default)
$ 
```

(I did notice that (even on successful Ubuntu boots) that some syscalls
were rejected in the sandboxed `com.apple.Virtualization.VirtualMachine`
process. You can see this in Console.app.)

And for reference here are the entitlements for the service:
```shell
$ codesign -d --entitlements :- ../../com.apple.Virtualization.VirtualMachine.xpc
Executable=/System/Library/Frameworks/Virtualization.framework/Versions/A/XPCServices/com.apple.Virtualization.VirtualMachine.xpc/Contents/MacOS/com.apple.Virtualization.VirtualMachine
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>com.apple.security.hypervisor</key>
        <true/>
        <key>com.apple.vm.networking</key>
        <true/>
</dict>
</plist>
$
```

I spent a bit of time statically tracing through the XPC service's subroutines.
Based on the `hv_*` symbol references I found in the binary it seemed like I'd
eventually find the bootloader routine. Starting from the entry point of the binary
and tracing down was time consuming and wasn't turning up anything interesting.

I also spent some time tracing back from various `hv_*` and `pthread*` calls
but didn't find anything that was obviously bootstrapping code.

I eventually started searching the binary for magic numbers referenced in this
[Linux/x86 boot protocol
documentation](https://www.kernel.org/doc/Documentation/x86/boot.txt) and
eventually found checks like (This is using Hopper's asm->C lifting):

```C
loc_10008e0e8:
    LODWORD(rdx) = 0x1000;
    LODWORD(rcx) = 0x0;
    rdx = var_78;
    if (LODWORD(*(int16_t *)(rdx + 0x1fe) & 0xffff) != 0xaa55) goto loc_10008e4d4;
```

This appears to be checking that offset 0x1fe has the bytes 0xaa55. 0x55aa is a
magic number used as a sort of checksum for a boot sector so this seemed
promising. A bit further down in this same subroutine I found:

```C
loc_10008e0fe:
    LODWORD(rcx) = 0x0;
    if (*(int32_t *)(rdx + 0x202) != 0x53726448) goto loc_10008e4d4;
```

0x53726448 is the ASCII string 'SrdH' which is yet another magic number from
the boot protocol documentation (The 0x202 offset matches too). 

The routine here is quite large and I assume it's some `kexec` implementation
(or subroutine of `kexec`). I did not some variations between
Virtualization.Framework's implementation and [xhyve's kexec
implementation.](https://github.com/machyve/xhyve/blob/master/src/firmware/kexec.c)

For example, xhyve's kexec [rejects booting
kernels](https://github.com/machyve/xhyve/blob/master/src/firmware/kexec.c#L97-L108)
under the following conditions:

```C
	if ((zp->setup_header.setup_sects == 0) ||    /* way way too old */
		(zp->setup_header.boot_flag != 0xaa55) || /* no boot magic */
		(zp->setup_header.header != HDRS) ||      /* way too old */
		(zp->setup_header.version < 0x020a) ||    /* too old */
		(!(zp->setup_header.loadflags & 1)) ||    /* no bzImage */
		(sz < (((zp->setup_header.setup_sects + 1) * 512) +
		(zp->setup_header.syssize * 16))))        /* too small */
	{
		/* we can't boot this kernel */
		fclose(f);
		return -1;
	}
```

It looks like the Virtualization.Framework implementation supports
boot protocol 2.04 and above (Unlike xhvye's supporting 2.10 and above):

```C
loc_10008e10e:
    LODWORD(rcx) = 0x0;
    LODWORD(rax) = *(int16_t *)(rdx + 0x206) & 0xffff;
    if (LODWORD(rax) < 0x204) goto loc_10008e4d4;
```

At this point, I found one potential difference that could explain the
variation between xhyve's behavior and Virtualization.framework. I don't think
this specific variation explains the difference in behavior I observed between
vftool and xhyve (TinyCoreLinux seems to use the same boot protocol version as
the Ubuntu image I was booting). However, I am happy that I did end up finding
something that appears to have notable implementation details of the
VZLInuxBootLoader.

I haven't yet finished digging here and may spend some more time reading the
VirtualMachine XPC implementation. Here are some other miscellaneous
obvservations I made when poking around.

# Undocumented, potentially not yet implemented APIs

The Virtualization.framework implementation has references to bootloaders that
aren't VZLinuxBootloaders such as VZEFIBootloader. These are not documented
currently so I assume they are either not stable or not complete.

I'd assume that VZEFIBootLoaders would be more generally useful than the
Linux-specific VZLinuxBootLoader.

```shell
$ pwd
$DYLIB_CACHE_PATH/System/Library/Frameworks/Virtualization.framework/Versions/A

$ file Virtualization
Virtualization: Mach-O 64-bit dynamically linked shared library x86_64

$ strings Virtualization | grep '_VZ'
_mode == _VZSocketSerialPortAttachmentModeServer
T@"<_VZVirtualMachineConfigurationDecoderDelegate>",W,V_delegate
v32@?0@"_VZGraphicsDeviceConfiguration"8Q16^c24
T@"_VZEFIVariableStore",&,V_variableStore
T@"_VZFramebuffer",&
T@"<_VZVirtualMachineViewDelegate>",W,V_delegate
_VZVirtualMachineGuestTypeLinux

$ nm -gU Virtualization | grep 'VZ.*Boot'
00007fff8d1de2d8 S _OBJC_CLASS_$_VZBootLoader
00007fff8d1deeb8 S _OBJC_CLASS_$_VZLinuxBootLoader
00007fff8d1de558 S _OBJC_CLASS_$__VZEFIBootLoader
00007fff8d1de300 S _OBJC_METACLASS_$_VZBootLoader
00007fff8d1deee0 S _OBJC_METACLASS_$_VZLinuxBootLoader
00007fff8d1de580 S _OBJC_METACLASS_$__VZEFIBootLoader
$ 
```

# Useful next steps

Attaching a debugger to the VirtualMachine XPC service is likely useful as it
seems clear that most of the interesting bootstrapping code lives there.
However, I believe I'd need to disable SIP to do this and I don't love
disabling security features on my hardware. If I revisit this (or someone
else does) starting from here seems reasonable.

I also didn't dig too deeply into the XPC messages from the
Virtualization.Framework "client" to the VirtualizationMachine.xpc "server".
It's my understanding that XPC is schemaless so I doubt it's easy to find the
schema of messages passed over XPC statically. Debugging XPC messages might be
a useful next step as I don't need to hook into SIP protected processes
(Assuming I just care about the 'client' view).

# Gotcha in using Hopper's dead code removal

Reversing Objective-C code that makes use of blocks took me some time. It was
especially confusing to use Hopper's lifting of asm to C which, by default,
would remove "dead" code. This would generate C like:

```C
  if (rbx != 0x0) {
          var_40 = *__NSConcreteStackBlock;
          [rbx retain];
          dispatch_async(*__dispatch_main_q, &var_40);
  // snip
```

Which is perplexing since `var_40` _should_ be a block but is clearly just a
pointer to a 'type'. Looking at the asm directly was more useful here:

```markdown
000000010001abd1         mov        rax, qword [__NSConcreteStackBlock_1000b4008] ; __NSConcreteStackBlock_1000b4008
000000010001abd8         mov        qword [rbp+var_40], rax
000000010001abdc         mov        eax, 0xc2000000
000000010001abe1         mov        qword [rbp+var_38], rax
000000010001abe5         lea        rax, qword [sub_10001ac60]                  ; sub_10001ac60
000000010001abec         mov        qword [rbp+var_30], rax
000000010001abf0         lea        rax, qword [__ZTINSt3__117bad_function_callE+696] ; 
# <snip>
000000010001ac16         call       imp___stubs__dispatch_async                 ; dispatch_async
```

I eventually sorted out that that the asm is probably building a [block literal
struct](https://clang.llvm.org/docs/Block-ABI-Apple.html#high-level). Hopper
seems to (understandbly) think the `sub_10001ac60` reference is unused so it
will remove it as dead code. However, I believe this is the `invoke` field of
the block struct which points to the instructions that would be executed by the
`dispatch_async` call.
