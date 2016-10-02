---
layout: post
title: "Practical Guide to Nested ARM Templates in Azure."
date: 2016-10-02
---

# Introduction

One area that I have found limited documentation on in regards to ARM Template Deployment is a practical guide on how to use Nested Templates 
and how to pass output from Nested Templates to other Templates. This will the topic of discussion for this post.

## Getting Started

Below is a sample ARM Template:

```json


```


## Gotcha #348: Non-Existent Property Values from Outputs from deployed Resources

So you've checked over your ARM Template thoroughly, you've determined that the Property you are trying to reference in your Outputs actually exists, but
you aren't getting any results back. The next thing you should check is to see if the Property you are referencing actually has a value.

One particular resource that is likely to give you a hell of a time is the Public IP Address Resource as the PublicIPAddress Property will not have a value until
the Resource is assigned to a NIC Card or Load Balancer.

