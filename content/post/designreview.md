---
date: "2019-05-12"
title: "questions for system design reviews"
tags: [
    "software-security",
]
summary: "Moving towards operationalizing system design reviews. What questions should a review team ask, or expect to be answered?"
---

Often I am responsible for providing feedback on system designs prior to implementation. These reviews are usually focused on identifying or validating security properties of the proposed design.

When doing these reviews I find it easy to miss out on feedback opportunities when I get stuck down some rabbit hole. This is a short checklist to remind myself what questions I might want to answer during a review.

* Is the problem clear? Does the design appear to solve this problem?

* Is the rationale behind design decisions clear? Are design constraints enumerated?

* Have alternate designs been explored? Is the rationale for why a specific design was selected clear?

* Are desired security properties enumerated? Are the enumerated properties strong? Are any properties missing?

* Does the design meet all desired security properties? Is it stated why they are met? Are those statements correct?

* Does anything in the design feel superfluous? Can superfluous components be eliminated safely?
