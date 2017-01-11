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

* Basic structure of WebhookData Payloads from GitHub.
* Sample Runbook showing how to parse WebhookData Payloads triggered from GitHub.

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

|                                               |                                                         |
|:---------------------------------------------:|:-------------------------------------------------------:|
| **Inital Webhook JSON Payload**               | **Triggered Webhook from Repo Commit Payload**          |
| zen                                           | ref                                                     |
| hook_id                                       | before                                                  |
| hook                                          | after                                                   |
| respository                                   | created                                                 |
| sender                                        | deleted                                                 |
|                                               | forced                                                  |
|                                               | base_ref                                                |
|                                               | compare                                                 |
|                                               | commits                                                 |
|                                               | head_commit                                             |
|                                               | repository                                              |
|                                               | pusher                                                  |
|                                               | sender                                                  |

Because of these differences, it is necessary to parse the Payloads from each of these sources based on their structure.

Additionally, the Webhook Data from the Payloads is passed to the Azure Automation Runbooks in JSON format consisting of three main sections:

* WebhookName
* RequestBody
* RequestHeader

An example of what this raw WebhookData looks like from a commit Payload is shown below:

```json
{"WebhookName":"github-sandbox-webhook","RequestBody":"{\"ref\":\"refs/heads/master\",\"before\":\"fa0d7d55d9b8ef2bf3f8f9dde6a69c768db14e81\",\"after\":\"2c2eea343f293abe753b883f6da03f9284de9d1a\",\"created\":false,\"deleted\":false,\"forced\":false,\"base_ref\":null,\"compare\":\"https://github.com/starkfell/starkfell.github.io/compare/fa0d7d55d9b8...2c2eea343f29\",\"commits\":[{\"id\":\"2c2eea343f293abe753b883f6da03f9284de9d1a\",\"tree_id\":\"6d0c4646d65af5c798205ec55c9b4bce670fe444\",\"distinct\":true,\"message\":\"updated table.\",\"timestamp\":\"2017-01-09T23:36:21+01:00\",\"url\":\"https://github.com/starkfell/starkfell.github.io/commit/2c2eea343f293abe753b883f6da03f9284de9d1a\",\"author\":{\"name\":\"Ryan Irujo\",\"email\":\"ryan.irujo@gmail.com\",\"username\":\"starkfell\"},\"committer\":{\"name\":\"Ryan Irujo\",\"email\":\"ryan.irujo@gmail.com\",\"username\":\"starkfell\"},\"added\":[],\"removed\":[],\"modified\":[\"_posts/2017-01-09-parsing-webhooks-from-github-in-azure-automation-runbooks.md\"]}],\"head_commit\":{\"id\":\"2c2eea343f293abe753b883f6da03f9284de9d1a\",\"tree_id\":\"6d0c4646d65af5c798205ec55c9b4bce670fe444\",\"distinct\":true,\"message\":\"updated table.\",\"timestamp\":\"2017-01-09T23:36:21+01:00\",\"url\":\"https://github.com/starkfell/starkfell.github.io/commit/2c2eea343f293abe753b883f6da03f9284de9d1a\",\"author\":{\"name\":\"Ryan Irujo\",\"email\":\"ryan.irujo@gmail.com\",\"username\":\"starkfell\"},\"committer\":{\"name\":\"Ryan Irujo\",\"email\":\"ryan.irujo@gmail.com\",\"username\":\"starkfell\"},\"added\":[],\"removed\":[],\"modified\":[\"_posts/2017-01-09-parsing-webhooks-from-github-in-azure-automation-runbooks.md\"]},\"repository\":{\"id\":56943135,\"name\":\"starkfell.github.io\",\"full_name\":\"starkfell/starkfell.github.io\",\"owner\":{\"name\":\"starkfell\",\"email\":\"ryan.irujo@gmail.com\"},\"private\":false,\"html_url\":\"https://github.com/starkfell/starkfell.github.io\",\"description\":\"Starkfell's Blog\",\"fork\":false,\"url\":\"https://github.com/starkfell/starkfell.github.io\",\"forks_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/forks\",\"keys_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/keys{/key_id}\",\"collaborators_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/collaborators{/collaborator}\",\"teams_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/teams\",\"hooks_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/hooks\",\"issue_events_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/issues/events{/number}\",\"events_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/events\",\"assignees_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/assignees{/user}\",\"branches_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/branches{/branch}\",\"tags_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/tags\",\"blobs_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/git/blobs{/sha}\",\"git_tags_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/git/tags{/sha}\",\"git_refs_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/git/refs{/sha}\",\"trees_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/git/trees{/sha}\",\"statuses_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/statuses/{sha}\",\"languages_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/languages\",\"stargazers_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/stargazers\",\"contributors_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/contributors\",\"subscribers_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/subscribers\",\"subscription_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/subscription\",\"commits_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/commits{/sha}\",\"git_commits_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/git/commits{/sha}\",\"comments_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/comments{/number}\",\"issue_comment_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/issues/comments{/number}\",\"contents_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/contents/{+path}\",\"compare_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/compare/{base}...{head}\",\"merges_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/merges\",\"archive_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/{archive_format}{/ref}\",\"downloads_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/downloads\",\"issues_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/issues{/number}\",\"pulls_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/pulls{/number}\",\"milestones_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/milestones{/number}\",\"notifications_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/notifications{?since,all,participating}\",\"labels_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/labels{/name}\",\"releases_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/releases{/id}\",\"deployments_url\":\"https://api.github.com/repos/starkfell/starkfell.github.io/deployments\",\"created_at\":1461449495,\"updated_at\":\"2016-11-26T23:26:06Z\",\"pushed_at\":1484001392,\"git_url\":\"git://github.com/starkfell/starkfell.github.io.git\",\"ssh_url\":\"git@github.com:starkfell/starkfell.github.io.git\",\"clone_url\":\"https://github.com/starkfell/starkfell.github.io.git\",\"svn_url\":\"https://github.com/starkfell/starkfell.github.io\",\"homepage\":null,\"size\":27992,\"stargazers_count\":0,\"watchers_count\":0,\"language\":\"PowerShell\",\"has_issues\":true,\"has_downloads\":true,\"has_wiki\":true,\"has_pages\":true,\"forks_count\":0,\"mirror_url\":null,\"open_issues_count\":0,\"forks\":0,\"open_issues\":0,\"watchers\":0,\"default_branch\":\"master\",\"stargazers\":0,\"master_branch\":\"master\"},\"pusher\":{\"name\":\"starkfell\",\"email\":\"ryan.irujo@gmail.com\"},\"sender\":{\"login\":\"starkfell\",\"id\":2753909,\"avatar_url\":\"https://avatars.githubusercontent.com/u/2753909?v=3\",\"gravatar_id\":\"\",\"url\":\"https://api.github.com/users/starkfell\",\"html_url\":\"https://github.com/starkfell\",\"followers_url\":\"https://api.github.com/users/starkfell/followers\",\"following_url\":\"https://api.github.com/users/starkfell/following{/other_user}\",\"gists_url\":\"https://api.github.com/users/starkfell/gists{/gist_id}\",\"starred_url\":\"https://api.github.com/users/starkfell/starred{/owner}{/repo}\",\"subscriptions_url\":\"https://api.github.com/users/starkfell/subscriptions\",\"organizations_url\":\"https://api.github.com/users/starkfell/orgs\",\"repos_url\":\"https://api.github.com/users/starkfell/repos\",\"events_url\":\"https://api.github.com/users/starkfell/events{/privacy}\",\"received_events_url\":\"https://api.github.com/users/starkfell/received_events\",\"type\":\"User\",\"site_admin\":false}}","RequestHeader":{"Accept":"*/*","Host":"s2events.azure-automation.net","User-Agent":"GitHub-Hookshot/b831b17","X-GitHub-Event":"push","X-GitHub-Delivery":"11ab1800-d6bc-11e6-8a4d-be846b385d83","x-ms-request-id":"afadc37e-d037-4191-9b8f-344029523b3d"}}
```

The screenshot below shows what the same payload looks like in the Input field of an Azure Automation Runbook.

![parsing-webhook-data-from-github-in-azure-automation-runbooks-000]({{ site.github.url }}/media/parsing-webhook-data-from-github-in-azure-automation-runbooks-000.jpg)

The raw WebhookData is daunting to deal with in its raw state. As such, I have included an Azure Runbook sample below
that when added to an Azure Automation Account and configured with a Webhook in GitHub, will return back the following information on a repo commit:

* The Commit Message
* The Name of the person who made the commit
* The Username of the person who made the commit
* The E-mail Address of the person who made the commit

```powershell
<#

.SYNOPSIS
This is a sample Runbook for demonstrating how to parse WebhookData from a GitHub Webhook Payload.

.DESCRIPTION
This is a sample Runbook for demonstrating how to parse WebhookData from a GitHub Webhook Payload.

Be aware that all relevant WebhookData is contained within the RequestBody of the Webhook Payload.

When this Runbook is triggered the following takes place:

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

# If this Runbook is not triggered from a Webhook or no WebhookData is found, exit.
If (!$WebhookData)
{
    Write-Output "Runbook wasn't triggered from Webhook or no WebhookData was passed. Exiting."
    exit 1
}

