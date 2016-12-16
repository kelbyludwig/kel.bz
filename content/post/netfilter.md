+++
date = "2016-08-20T13:52:18-05:00"
draft = false
title = "modifying ip headers with netfilter"
+++

# Motivation

I recently read the ["Off-Path TCP
Exploits"](http://www.cs.ucr.edu/~zhiyunq/pub/sec16_TCP_pure_offpath.pdf)
whitepaper (Its very good!) and it made me a bit curious. How would I approach
recreating a PoC for this attack? While the authors mention several hurdles
that they had to overcome for their experiments, the first snag I ran into is
one of the core assumptions in the paper: An attacker can send packets with a
spoofed source IP address across the Internet. I'm skeptical that my ISP would
be cool with this, so I wanted to recreate this scenario on my local network.
Even with a isolated network setup, I still need to be able to create packets
that have a spoofed source IP. I know there are [existing
tools](https://nmap.org/) with this functionality but that seemed too easy. I
came up with two approaches.

1. I could build IP packets from scratch.

2. I could route traffic through a router that rewrites the source IP.

Option 1 seemed interesting, but I was concerned it wasn't flexible enough. I
was fairly sure after I constructed the IP-layer headers I would have to
manually build the TCP layer as well. Option 2 seemed more re-usable. I could
just configure my host OS to send TCP traffic through the router and it would
re-write the source IP. In this configuration, I only have to send TCP traffic
on my host OS.

Option 2 also appealed to me because I could dig into kernel modules and
Netfilter. I had written kernel modules a year or two ago and I recently have
been in the mood to revisit kernel programming. So I read some content online,
and I thought I would share my results here. I didn't find much content on
using Netfilter to *modify* packets, so hopefully this is useful for others as
well.

*Note:* I recognize `iptables` has support for packet mangling. I have used
it [in other projects](https://github.com/praetorian-inc/mitm-vm). That's
too easy though!

# The Setup

My router will be a Vagrant VM running Debian. To prepare the VM for kernel
module writing the following command should be ran:

```
sudo apt-get update
sudo apt-get install build-essential linux-headers-$(uname -r) make vim
```

Once that Vagrant VM is setup, we can install a kernel module that uses
Netfilter to modify packets on the fly. We can then use that Vagrant VM as our
router, and let the kernel hooks work their magic.

# Writing and Building A Kernel Module

To begin, we start with a very basic "Hello, world!" kernel module.

```
#Filename: Makefile
obj-m := hello.o
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
        $(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules
clean:
        rm *o
```

```
//Filename: hello.c
#include <linux/module.h> 
#include <linux/init.h>   

//setup will be the function that is called when our module is loaded.
static int __init setup(void) {
        printk(KERN_INFO "Hello, world!\n"); //printk is the kernel's version of printf. KERN_INFO is a log-level macro.
        return 0; //a return value of zero tells insmod that the module loaded successfully
}

//teardown will be the function that is called when our module is unloaded.
static void __exit teardown(void) {
        printk(KERN_INFO "Goodbye, cruel world!\n");
}

module_init(setup); //module_init defines the setup function for inserting the module
module_exit(teardown); //module_exit defines the teardown function for removing the module
```

Once those files are created, the module can be compiled by running `make` and then loaded
as a module by running `insmod hello.ko`. To see our module it action, run `dmesg | tail`.
You should see something like the following:

```
[14843.182893] hello: module license 'unspecified' taints kernel.
[14843.182896] Disabling lock debugging due to kernel taint
[14843.183267] Hello, world!
```

To remove our module, we can run `rmmod hello`. Running `dmesg | tail` again will show us
the results of our super fantastic teardown function:

```
[14843.182893] hello: module license 'unspecified' taints kernel.
[14843.182896] Disabling lock debugging due to kernel taint
[14843.183267] Hello, world!
[15006.239774] Goodbye, cruel world!
```

You are officially a kernel hacker! I tried to add some comments in the code to explain a little
bit about what is going on. For a more thorough analysis, the following resources maybe useful:

* [kbuild: The build system used by the Linux kernel](https://www.kernel.org/doc/Documentation/kbuild/modules.txt)
* [A "Hello, World!" Kernel Module](http://www.makelinux.net/books/lkd2/ch16lev2sec1)
* [The init and exit Macros](http://www.tldp.org/LDP/lkmpg/2.4/html/x281.htm)

# Introducing Netfilter

The next step is introducing Netfilter into our module. Netfilter is "a set of
hooks inside the Linux kernel that allows kernel modules to register callback
functions with the network stack." Netfilter sits at key points in the kernel's
network stack and allows developer to extend or add functionality. 

Lets add a function that just logs when the kernel has recieved a packet at
Netfilter's pre-routing hook. (A lot of Netfilter tutorials like to just drop
packets at this stage. Considering we are SSH'd into our Vagrant VM that is not
a great idea.) We can use roughly the same Makefile as our previous example.

```
//Filename: hello-netfilter.c
#include <linux/module.h>
#include <linux/init.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>

//nfho is a nf_hook_ops struct. This struct stores all the
//required information to register a Netfilter hook.
static struct nf_hook_ops nfho;

//hook_func is our Netfilter function that will be called at the pre-routing
//hook. This hook merely logs that Netfilter received a packet and tells
//Netfilter to continue processing that packet.
unsigned int hook_func(unsigned int hooknum,
                       struct sk_buff **skb,
                       const struct net_device *in,
                       const struct net_device *out,
                       int (*okfn)(struct sk_buff *)) {

        printk(KERN_INFO "Packet!\n"); //Lets log that we recieved a packet.
        return NF_ACCEPT; //NF_ACCEPT tells the hook to continue processing the packet.

}

//initialize will setup our Netfilter hook when our kernel
//module is loaded.
static int __init initialize(void) {
        nfho.hook     = hook_func; //Points to our hook function.
        nfho.hooknum  = NF_INET_PRE_ROUTING; //Our function will run at Netfilter's pre-routing hook.
        nfho.pf       = PF_INET; //pf = protocol family. We are only interested in IPv4 traffic.
        nfho.priority = NF_IP_PRI_FIRST; //Tells Netfilter this hook should be ran "first" (there is of-course, more to this when other hooks have this priority)
        nf_register_hook(&nfho); //We now register our hook function.
        return 0;
}

static void __exit cleanup(void) {
        nf_unregister_hook(&nfho); //unregister our hook
}

module_init(initialize);
module_exit(cleanup);
```

We can see this module in action by using `insmod` to load the module and
viewing `dmesg`. Because we are using SSH, there are a good number of "Packet!"
logs. Neat! For greater understanding of this code beyond my comments, I
recommend reading bioforge's Phrack article ["Hacking the Linux Kernel Network
Stack"](http://phrack.org/issues/61/13.html).

# Modifying Packets Using Netfilter

Making minor modifications to packets appeared to be fairly simple (at least
what I tried). If you google something similar to "modify packets netfilter"
you will may not see many results. However, after a bit of research I learned
that the data structure that represents a packet in Netfilter hooks is not
specific to Netfilter but, the `sk_buff` type is a key Linux kernel data
structure. Socket buffers are pretty large so I won't cover them in their
entirety here. I do recommend reviewing the "SKB: Linux Networking Data
Structure" below. I also included some (hopefully) useful commented code to
highlight some socket buffer components. The following kernel module will
modify the source IP address of incoming ICMP packets.

```
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/netdevice.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <linux/ip.h>
#include <linux/tcp.h>

#define NIPQUAD(addr) \
    ((unsigned char *)&addr)[0], \
    ((unsigned char *)&addr)[1], \
    ((unsigned char *)&addr)[2], \
    ((unsigned char *)&addr)[3]

static struct nf_hook_ops nfho;
struct iphdr *iph;
struct tcphdr *tcp_header;
struct sk_buff *sock_buff;
unsigned int sport, dport;

unsigned int hook_func(unsigned int hooknum,
                       struct sk_buff **skb,
                       const struct net_device *in,
                       const struct net_device *out,
                       int (*okfn)(struct sk_buff *)) 
{
    //NOTE: Feel free to uncomment printks! If you are using Vagrant and SSH
     //      too many printk's will flood your logs.
    //printk(KERN_INFO "=== BEGIN HOOK ===\n");

    sock_buff = skb;

    if (!sock_buff) {
        return NF_ACCEPT;
    }

    iph = (struct iphdr *)skb_network_header(sock_buff);

    if (!iph) {
        //printk(KERN_INFO "no ip header\n");
        return NF_ACCEPT;
    }

    if(iph->protocol==IPPROTO_TCP) {
        return NF_ACCEPT;

        //tcp_header = tcp_hdr(sock_buff);
        //sport = htons((unsigned short int) tcp_header->source);
        //dport = htons((unsigned short int) tcp_header->dest);
        //printk(KERN_INFO "TCP ports: source: %d, dest: %d \n", sport, dport);
        //printk(KERN_INFO "SKBuffer: len %d, data_len %d\n", sock_buff->len, sock_buff->data_len);
    }

    if(iph->protocol==IPPROTO_ICMP) {
        printk(KERN_INFO "=== BEGIN ICMP ===\n");
        printk(KERN_INFO "IP header: original source: %d.%d.%d.%d\n", NIPQUAD(iph->saddr));
        iph->saddr = iph->saddr ^ 0x10000000;
        printk(KERN_INFO "IP header: modified source: %d.%d.%d.%d\n", NIPQUAD(iph->saddr));
        printk(KERN_INFO "IP header: original destin: %d.%d.%d.%d\n", NIPQUAD(iph->daddr));
        printk(KERN_INFO "=== END ICMP ===\n");

    }

    //if(in) { printk(KERN_INFO "in->name:  %s\n", in->name); }
    //if(out) { printk(KERN_INFO "out->name: %s\n", out->name); }
    //printk(KERN_INFO "=== END HOOK ===\n");
    return NF_ACCEPT;        

}

static int __init initialize(void) {
    nfho.hook = hook_func;
    //nfho.hooknum = NF_INET_PRE_ROUTING;
    //Interesting note: A pre-routing hook may not work here if our Vagrant
    //                  box does not know how to route to the modified source.
    //                  For the record, mine did not.
    nfho.hooknum = NF_INET_POST_ROUTING;
    nfho.pf = PF_INET;
    nfho.priority = NF_IP_PRI_FIRST;
    nf_register_hook(&nfho);
    return 0;    
}

static void __exit teardown(void) {
    nf_unregister_hook(&nfho);
}

module_init(initialize);
module_exit(teardown);
```

Try pinging the Vagrant machine before and after the module is loaded. Once the
module is loaded you should see that ping replies don't reach your machine.
Perfect! If we monitor the Vagrant machine's network traffic, it may look like
this Wireshark capture:

{{< figure src="/ip_spoof_wireshark.png" >}}

Voila!


# Collection of Useful Resources
* [IP Spoofing with iptables](https://sandilands.info/sgordon/address-spoofing-with-iptables-in-linux)
* [SKBs: Linux Networking Data Structure](http://vger.kernel.org/~davem/skb.html) 
