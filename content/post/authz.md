+++
date = "2016-08-01T20:53:18-05:00"
draft = false
title = "well-tested authorization design patterns"

+++

Authorization is a strange beast. In theory, it appears to be rather
straight-forward: a user should not be able to create, read, update, or delete
data that it does not have access to. However, from our experience, theory
tends to deviate from practice. Missing or incorrect access controls are
a dime a dozen for applications we test and this rarely stems from a
complete lack of access controls. More often then not, authorization issues
spring up during assessments where the application manages a complex
authorization model and an incorrect assumption was made or an edge case was
missed. Conversely, we have seen applications that have incredibly
complicated authorization models that have zero access control problems.

Authorization may seem like a trivial engineering problem, but consider a
mobile phone. Smart phones support configuring a lock screen that should
prevent unauthorized users from accessing the device. This seems
straight-forward, but allowing this leads to interesting edge cases. What
features should be exposed to users without a lock screen code?  Most smart
phones can still place emergency calls while locked. What about access to the
phone's camera? If these features are allowed, [access controls must be handled
properly](https://groups.google.com/forum/#!topic/android-security-updates/1M7qbSvACjo).
Even if an application begins with simple authorization models, as features are
added, the once simple access control mechanism must handle complex logic.

Requirements for access control mechanisms can vary greatly, so there is no
catch-all implementation. Even so, we observe that applications free from
authorization flaws still follow certain design patterns or principles. To best
understand and evaluate our rationale behind these why we recommend these
design principles, we must first form a solid understanding of the threats that
access controls are designed to thwart.

## The Threat Model: Horizontal and Vertical Privilege Escalation

There are two primary classes of bugs that access controls attempt to prevent:
horizontal and vertical privilege escalation. Vertical privilege escalation is
intuitive: a user should not be able to perform actions above her
privilege level (e.g. a low-privilege user should not be able to perform
administrative actions).  The somewhat unintuitively named "horizontal
privilege escalation" is when a user can perform actions at her privilege level
that are not typically allowed.  This typically happens when user is able to
act on another user's behalf (e.g. a customer of an online bank transfers money
from another customer's account). 

Understanding the distinction between these two classes of vulnerabilities are
crucial: doing so allows us to better reason about the security of our access control
mechanism. If you are interested in reading more on the subject, I recommend
checking out [Wikipedia's page on privilege
escalation](https://en.wikipedia.org/wiki/Privilege_escalation).

## Authorization Design Patterns

From assessing a significant number of authorization schemes, we have compiled
a list of key design principles which successful schemes follow. While
requirements for any particular scheme may vary, and not all principles may be
relevant to your particular needs, following the following design principles
will assist in avoiding common pitfalls.


### Key Principle 1: Design an access control model.

This is likely the least interesting component of designing a decent access
control mechanism, and I can hear the booing already, but access controls
don't really mean much unless some sort of access control model is defined. We
highly recommend that clients formally document their access controls if they
have not already. This document will be useful for some of the later key
principles.

*Doing this right:* 

* Consider following one of the models suggested by [OWASP](https://www.owasp.org/index.php/Access_Control_Cheat_Sheet). How the document looks is up to your team. 

* Be sure this document is within reach of all developers.

* Update it frequently.

### Key Principle 2: Don't trust client-provided data when authenticating or authorizing a user.

In order to make access control decisions, we must first correctly identify the
user making a request. This should be solely dependent on the application's
method of maintaining a user's authenticated session (e.g. a session
identifier, an authenticated claim). When access control decisions are made it
is of critical importance that client-provided data is not trusted without
verification. 

This description is a bit general as there is no one true way to identify a
user, but for the sake of clarity, one particularly egregious
example of using meaningful data would be including a parameter "admin=False"
in requests. If this "admin" parameter is used to determine whether the user
has administrative permissions, a malicious user could easily exploit a
vertical privilege escalation flaw. 

Relying on obscurity should also be avoided: if access control decisions are
based on a static identifiers that should only be known by users at that
privilege level, it is a matter of time before those secret values are leaked
in some fashion.

*Doing this right:* 

* Identify users strictly by their session identifier.

* A user's session identifier should be directly tied to whatever permissions they
may have (however that is represented by your system). 

* This session identifier should be the _only_ item that is used when authorizing a user. 

* Session identifiers should follow [current best practices](https://www.owasp.org/index.php/Session_Management_Cheat_Sheet).

### Key Principle 3: Deny access by default.

Access controls should deny access by default. This is critical, because sometimes
developers forget to include an access control check. In the event this mistake
happens, the application should not allow a user to gain unfettered access to 
the application. Furthermore, in more complex access controls, if a user
finds herself (or intentionally puts herself) in a state that is not currently handled by the 
access control logic, it is best not to default to allowing access.

*Doing this right:* 

* This is highly dependent on implementation! However your access control
mechanism is built, be sure to handle both the forgetful developer case and
the unhandled state case. 

### Key Principle 4: Be abstract and centralized.

If your access control checks take place within more than one conditional (e.g.
`if`, `switch`) statement I would reconsider the design of the access control
mechanism. Consider a simple CRUD API for a widget transaction. In this
example, we are working with a single object (the widget transaction), that has
at least 4 actions (create, read, update, delete). A likely method of
implementing access controls would be at the action-level. This means there are
4 separate conditional statements that authorize a user's action. This may work
for the short-term but this mechanism will quickly grow to be complex and
error-prone.

There are design patterns that can be leveraged to abstract access control
checks that are less problematic than conditional statements throughout the
codebase. We have seen cases where conditional statements have preceding
logic that affect access control decisions and complicate or cause
authorization flaws. Additionally, conditional statements could be easily
forgotten (Hopefully key principle 2 is obeyed). Wouldn't life be so much
better if you didn't have to write a potentially nasty switch statement within
every function that need access controls? We recommend that all access control
logic is centralized and abstract. This allows for a cleaner implementation and
easier bug fixes.

*Doing this right:* 

* If you are using a framework that provides an access control
API that obeys the listed key principles, that should be leveraged as much as
possible. 

* Generally, the [decorator design
pattern](https://sourcemaking.com/design_patterns/decorator) is something we
have seen work well as a method of verify a user's level of access.

## Authorization Bonus Points

We recommend other access control principles as well.
These may not prevent authorization flaws, but they may help identify or limit
issues considerably.

### Bonus Principle: Avoid complexity

Avoid uneccessary complexity if you can! ["Security’s worst enemy is
complexity"](https://www.schneier.com/academic/paperfiles/paper-ipsec.pdf).
Easier said than done, but important to keep in mind.

### Bonus Principle: Write access control tests

Write tests to validate that your model from Key Principle 0 is implemented
correctly. This won't catch all flaws but it will likely catch simple bugs and
regressions.  This is much easier when you follow Key Principle 3.

### Bonus Principle: Log access control events.

Logging can help identify strange behavior from users or highlight flaws in the
implementation.  If you are not following Key Principle 3 this will be a
nightmare. We also recommend logging both access control failures (e.g. "User A
tried to access User B's profile so we stopped her!") and successes (e.g. "We
let User A view her time sheet."). Logging successes may add a bit of noise,
but success events also add context that may be useful. We suggest accounting
for noise, and distinguishing between failure and success events in a way that
still allows the events to be coupled if necessary.

## Testing For Authorization Flaws

Authorization testing is too important to pass up but is error-prone (and a bit
boring) to test manually. Fortunately access control testing
can be trivially automated. We are partial to Burp so I wrote a plugin to
automate authorization testing. I am calling it Otter. There are existing Burp
plugins that have a similar premise but they didn't satisfy our needs
(namely, less-than-stellar UX and atypical assumptions about sessions). In a
nutshell, Otter browses the target web application alongside the web browser.
While browsing, Otter is transparently capturing requests and replaying them
with the session information of another user. Otter logs all of these requests
and records information that could be used to find differences between the
ordinary request and the modified one. If differences are noted between the two
requests, this is suggestive of authorization flaws. In short, Otter allows
testers to find authorization flaws in applications with the same amount of
effort it takes to browse the application. If this sounds appealing, please
check out [Otter on Github](https://github.com/kelbyludwig/otter).
