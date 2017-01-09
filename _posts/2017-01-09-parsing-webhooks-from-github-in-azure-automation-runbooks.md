---
layout: post
comments: true
title: "Parsing Webhook Data from GitHub in Azure Automation Runbooks"
date: 2017-01-09
---

The article covers how to parse Webhook Data from GitHub in Azure Automation Runbooks.

# Overview

This article is related to the earlier series of blog posts on setting up continuous deployment to Nano Server in Azure; however, the material
herein can be used for any other Azure Automation Runbook scenarios.

* [Setting up Continuous Deployment to Nano Server in Azure - Part 1](http://starkfell.github.io/continuous-deployment-to-nano-server-in-azure-p1/)
* [Setting up Continuous Deployment to Nano Server in Azure - Part 2](http://starkfell.github.io/continuous-deployment-to-nano-server-in-azure-p2/)
* [Setting up Continuous Deployment to Nano Server in Azure - Part 3](http://starkfell.github.io/continuous-deployment-to-nano-server-in-azure-p3/)

This article will cover the following:

* Basic formatting of GitHub WebHooks.
* How to parse data from GitHub Webhooks.
* Create a new Personal Access Token in GitHub
* Add the Webhook to GitHub using the GitHub API and PowerShell

## Prerequisites

* Access to an existing Azure Subscription and the rights to deploy or manage an Azure Automation Account.
* An existing GitHub Account.

## Overview of GitHub Webhook JSON Structure

Below are two different Webhook Payloads. The first examples is part of a from a Webhook that has just been created in GitHub. The second is from a Webhook Payload
from a Webhook that was triggered from a Repo Commit. Some value pairs have been removed from each example to keep the Some Values have been removed to keep the size of the sample small.

### Inital Webhook JSON Payload

```json
{
  "zen": "Responsive is better than fast.",
  "hook_id": 11370116,
  "hook": {
    "type": "Repository",
    "id": 11370116,
    "name": "web",
    "active": true,
    "events": [
      "push"
    ],
    "config": {
      "content_type": "json",
      "insecure_ssl": "0",
      "url": "https://s2events.azure-automation.net/webhooks?token=yn4ucKVSljrsEiizNcmowBnEAMlEmzkyerNxIREmdMk%3d"
    },
    "updated_at": "2017-01-03T14:26:24Z",
    "created_at": "2017-01-03T14:26:24Z",
    "url": "https://api.github.com/repos/starkfell/starkfell.github.io/hooks/11370116",
    "test_url": "https://api.github.com/repos/starkfell/starkfell.github.io/hooks/11370116/test",
    "ping_url": "https://api.github.com/repos/starkfell/starkfell.github.io/hooks/11370116/pings",
    "last_response": {
      "code": null,
      "status": "unused",
      "message": null
    }
  },
  "repository": {
    "id": 56943135,
    "name": "starkfell.github.io",
    "full_name": "starkfell/starkfell.github.io",
    "owner": {
      "login": "starkfell",
      "id": 2753909,
      "avatar_url": "https://avatars.githubusercontent.com/u/2753909?v=3",
      "gravatar_id": "",
      "url": "https://api.github.com/users/starkfell",
      "html_url": "https://github.com/starkfell",
      "received_events_url": "https://api.github.com/users/starkfell/received_events",
      "type": "User",
      "site_admin": false
    },
    "private": false,
    "html_url": "https://github.com/starkfell/starkfell.github.io",
    "description": "Starkfell's Blog",
    "fork": false,
    "url": "https://api.github.com/repos/starkfell/starkfell.github.io",
    "forks_url": "https://api.github.com/repos/starkfell/starkfell.github.io/forks",
    "deployments_url": "https://api.github.com/repos/starkfell/starkfell.github.io/deployments",
    "created_at": "2016-04-23T22:11:35Z",
    "updated_at": "2016-11-26T23:26:06Z",
    "pushed_at": "2017-01-02T22:54:18Z",
    "git_url": "git://github.com/starkfell/starkfell.github.io.git",
    "ssh_url": "git@github.com:starkfell/starkfell.github.io.git",
    "clone_url": "https://github.com/starkfell/starkfell.github.io.git",
    "svn_url": "https://github.com/starkfell/starkfell.github.io",
    "homepage": null,
    "size": 27982,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": "PowerShell",
    "has_issues": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": true,
    "forks_count": 0,
    "mirror_url": null,
    "open_issues_count": 0,
    "forks": 0,
    "open_issues": 0,
    "watchers": 0,
    "default_branch": "master"
  },
  "sender": {
    "login": "starkfell",
    "id": 2753909,
    "avatar_url": "https://avatars.githubusercontent.com/u/2753909?v=3",
    "gravatar_id": "",
    "url": "https://api.github.com/users/starkfell",
    "received_events_url": "https://api.github.com/users/starkfell/received_events",
    "type": "User",
    "site_admin": false
  }
}
```

### Triggered Webhook from Repo Commit Payload

```json
{
  "ref": "refs/heads/master",
  "before": "b6a1cefb43b7a08e4be34e8d9ef687199a17501e",
  "after": "cfdc9d412eca1ec66a9a8cc11c23f5cfdad13ea7",
  "created": false,
  "deleted": false,
  "forced": false,
  "base_ref": null,
  "compare": "https://github.com/starkfell/starkfell.github.io/compare/b6a1cefb43b7...cfdc9d412eca",
  "commits": [
    {
      "id": "cfdc9d412eca1ec66a9a8cc11c23f5cfdad13ea7",
      "tree_id": "692f92345d7c4672ae523771a032b96d98e0b8f4",
      "distinct": true,
      "message": "azure cli example added to sandbox",
      "timestamp": "2017-01-05T15:35:10+01:00",
      "url": "https://github.com/starkfell/starkfell.github.io/commit/cfdc9d412eca1ec66a9a8cc11c23f5cfdad13ea7",
      "author": {
        "name": "Ryan Irujo",
        "email": "ryan.irujo@gmail.com",
        "username": "starkfell"
      },
      "committer": {
        "name": "Ryan Irujo",
        "email": "ryan.irujo@gmail.com",
        "username": "starkfell"
      },
      "added": [
        "sandbox/deploy-arm-template-from-azure-cli.sh"
      ],
      "removed": [
      ],
      "modified": [
      ]
    }
  ],
  "head_commit": {
    "id": "cfdc9d412eca1ec66a9a8cc11c23f5cfdad13ea7",
    "tree_id": "692f92345d7c4672ae523771a032b96d98e0b8f4",
    "distinct": true,
    "message": "azure cli example added to sandbox",
    "timestamp": "2017-01-05T15:35:10+01:00",
    "url": "https://github.com/starkfell/starkfell.github.io/commit/cfdc9d412eca1ec66a9a8cc11c23f5cfdad13ea7",
    "author": {
      "name": "Ryan Irujo",
      "email": "ryan.irujo@gmail.com",
      "username": "starkfell"
    },
    "committer": {
      "name": "Ryan Irujo",
      "email": "ryan.irujo@gmail.com",
      "username": "starkfell"
    },
    "added": [
      "sandbox/deploy-arm-template-from-azure-cli.sh"
    ],
    "removed": [
    ],
    "modified": [
    ]
  },
  "repository": {
    "id": 56943135,
    "name": "starkfell.github.io",
    "full_name": "starkfell/starkfell.github.io",
    "owner": {
      "name": "starkfell",
      "email": "ryan.irujo@gmail.com"
    },
    "private": false,
    "html_url": "https://github.com/starkfell/starkfell.github.io",
    "description": "Starkfell's Blog",
    "fork": false,
    "url": "https://github.com/starkfell/starkfell.github.io",
    "forks_url": "https://api.github.com/repos/starkfell/starkfell.github.io/forks",
    "deployments_url": "https://api.github.com/repos/starkfell/starkfell.github.io/deployments",
    "created_at": 1461449495,
    "updated_at": "2016-11-26T23:26:06Z",
    "pushed_at": 1483626921,
    "git_url": "git://github.com/starkfell/starkfell.github.io.git",
    "ssh_url": "git@github.com:starkfell/starkfell.github.io.git",
    "clone_url": "https://github.com/starkfell/starkfell.github.io.git",
    "svn_url": "https://github.com/starkfell/starkfell.github.io",
    "homepage": null,
    "size": 27991,
    "stargazers_count": 0,
    "watchers_count": 0,
    "language": "PowerShell",
    "has_issues": true,
    "has_downloads": true,
    "has_wiki": true,
    "has_pages": true,
    "forks_count": 0,
    "mirror_url": null,
    "open_issues_count": 0,
    "forks": 0,
    "open_issues": 0,
    "watchers": 0,
    "default_branch": "master",
    "stargazers": 0,
    "master_branch": "master"
  },
  "pusher": {
    "name": "starkfell",
    "email": "ryan.irujo@gmail.com"
  },
  "sender": {
    "login": "starkfell",
    "id": 2753909,
    "avatar_url": "https://avatars.githubusercontent.com/u/2753909?v=3",
    "gravatar_id": "",
    "url": "https://api.github.com/users/starkfell",
    "received_events_url": "https://api.github.com/users/starkfell/received_events",
    "type": "User",
    "site_admin": false
  }
}
```

As you can see, both have a similar overall structure, however they have different primary sections as well as unique data.

| Inital Webhook JSON Payload Sections | Triggered Webhook from Repo Commit Payload Sections |
|--------------------------------------|-----------------------------------------------------|
| zen | ref |
| hook_id | before |
| hook | after |
| respository | created |
| sender | deleted |
| ---- | forced |
| ---- | base_ref |
| ---- | compare |
| ---- | commits |
| ---- | head_commit |
| ---- | repository |
| ---- | pusher |
| ---- | sender |

Because of these differences, it is necessary to parse the Payloads from each of these sources based on their structure.

For example, in order to correctly parse the Repo Commit Webhook Payload, you need to write a Runbooks similar to the example shown below.

```powershell
<#

.SYNOPSIS
This is a sample script for demonstrating how to parse WebhookData from a GitHub Webhook Payload.

.DESCRIPTION
This is a sample script for demonstrating how to parse WebhookData from a GitHub Webhook Payload.

Be aware that all relevant WebhookData is contained within the RequestBody of the Webhook Payload.

When this Script is triggered the following takes place:

- The Raw Webhook Data is returned in Write-Output.
- The WebhookData is pulled from the RequestBody of the Webhook Payload and converted From JSON.
- The Request Body is returned in Write-Output.
- The Commit Message is parsed out of the head_commit section in the RequestBody.
- The Name of the person who made the commit is parsed out of the head_commit section in the RequestBody.
- The Username of the person who made the commit is parsed out of the pusher setion in the RequestBody.
- The E-Mail Address of the person who made the commit is parsed out of the pusher setion in the RequestBody.
- The Commit Message, Name, Username, and E-Mail Address are returned in Write-Output.

.PARAMETER WebhookData
This is the WebhookData that is automatically passed from the GitHub Webhook Payload to the Runbook. The Runbook will exit if this Data Object is empty.

.NOTES
Filename:   rb-parse-github-webhook-from-commit.ps1
Author:     Ryan Irujo (https://github.com/starkfell)
Language:   PowerShell 5.0

.EXAMPLE
./rb-parse-github-webhook-from-commit.ps1

#>

param(
    [Object]$WebhookData
)

# Parsing information out of the WebhookData.
If ($WebhookData)
{
    Write-Output "RAW WEBHOOK DATA"
    $WebhookData | FL *
    Write-Output "                "

    # Parsing the RequestBody from the WebhookData.
    $RequestBody = ConvertFrom-Json -InputObject $WebhookData.RequestBody

    Write-Output "REQUEST BODY"
    $RequestBody
    Write-Output "            "


    # Commit Message
    $Message = $RequestBody.head_commit.message

    # Name of person who made the commit.
    $Name = $RequestBody.head_commit.author.name

    # Username of the person who pushed the update.
    $Username = $RequestBody.pusher.name

    # E-mail address of the person pushed the update.
    $Email = $RequestBody.pusher.email

    Write-Output "Commit Message:  $Message "
    Write-Output "Name:            $Name "
    Write-Output "Username:        $Username "
    Write-Output "E-mail Address:  $Email "
}

# If this Runbook is not triggered from a Webhook or no WebhookData is found, the script will exit.
If (!$WebhookData)
{
    Write-Output "Runbook wasn't triggered from Webhook or no WebhookData was passed. Exiting."
    exit 1
}

```

...