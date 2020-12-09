# Yet Another Jira Plugin

[![License](https://img.shields.io/github/license/juliendms/danger-yajp)](LICENSE)
[![Gem](https://img.shields.io/gem/v/danger-yajp)](https://rubygems.org/gems/danger-yajp)
[![Dependencies](https://img.shields.io/librariesio/release/rubygems/danger-yajp)](https://libraries.io/rubygems/danger-yajp)

Yet Another Jira Plugin (in short: yajp) is a [Danger](https://danger.systems/ruby/) plugin that provides methods to easily find and manipulate issues from within the Dangerfile. The major difference with the existing Jira plugins is the ability to transition and update issues with the same feeling as manipulating PR data from Danger. This plugin was build in the same mind as Danger, meaning that you will find methods to easily manipulate Jira data, but no predefined warning and/or message. It also does that by expanding the Issue class from `jira-ruby`.

Inspired by [danger-jira](https://github.com/RestlessThinker/danger-jira), from which I borrowed the issue search, and by [danger-jira_sync](https://github.com/roverdotcom/danger-jira_sync) for their usage of the awesome [jira-ruby](https://github.com/sumoheavy/jira-ruby) gem.

## Installation

Add this line to your Gemfile:

```rb
gem 'danger-yajp'
```

## Usage

You first need to define the environment variables `DANGER_JIRA_URL`, `DANGER_JIRA_USER` and `DANGER_JIRA_API_TOKEN` in your CI environment, for example:

```
DANGER_JIRA_URL: https://jira.company.com/jira
DANGER_JIRA_USER: username
DANGER_JIRA_API_TOKEN: abcd12345
```

### Find issues

This methode returns an array of Jira issues. All the base fields of each issue are directly accessible thanks to the gem `jira-ruby`. Input can be one project key, or an array of project keys.

```rb
issues = jira.find_issues(
    ['PROJECTKEY','MP'],
    search_title: true,
    search_commits: false,
    search_branch: false
)

issues.each do |issue|
    message issue.summary
end
```

### Transition / update issues

yajp allows to easily transition and update issues without the hassle of building custom json in the Dangerfile. The methods are available in the issue object, or to handle multiple issues in the plugin object. The inputs are:

* For the transition action, the ID of the transition
* When using the methods from the plugin object, the issues to handled, which is by default the issues found when the command `find_issues` was last run.
* Any number of fields to be updated in a hash: `key: value`

Example 1: transition all the issues found after running `find_issues`:
 ```rb
 jira.transition_all(10, assignee: { name: 'username' }, customfield_11005: 'example')
 ```

Example 2: update a single issue:
 ```rb
 issue.update(assignee: { name: 'username' }, customfield_11005: 'example')
 ```

The `transition` and `transition_all` methods only take fields available in the transition screen. Use the `split_transition_fields` method to separate the fields available in the transition screen, or use the `transition_and_update_all` method to transition and update issues (and automatically dispatch the fields to the correct action).

> Transition IDs can be found in Jira under Project Workflow > Edit Workflow in Text Mode.

### Reference the PR as a remote link

yajp can reference the PR as a remote link on Jira. It will use the icon of GitLab or Github depending on what you use. The remote link will use the URL of the PR as a `globalId` to not create duplicates. Optionnaly, you can specify the relationship with the issue (default is `relates to`), and the status, either as an object (eg. `{ "resolved": true, "icon": {...} }`) or as a boolean that will set the value of the property `resolved`. By default, no status is sent.

```rb
jira.pr_as_remotelink(issue, false)
```

### Issue URL

Use `link` to retrieve the browse URL of the Jira issue.

```rb
message "<a href='#{issue.link}'>#{issue.key} - #{issue.summary}</a>"
```

### API

You can always access the Jira API client from the `jira-ruby` gem via `jira.api`.

```rb
jira.api.Project.all
```

### Full example

```rb
issues = jira.find_issues('KEY')

if issues.empty?
  warn 'This PR does not contain any Jira issue.'
else
  issues.each do |issue|
    message "<a href='#{issue.link}'>#{issue.key} - #{issue.summary}</a>"

    case issue.status.name
    when 'In Progress'
      jira.transition_and_update_all(10, issue: issue, assignee: { name: 'username' }, customfield_11005: 'example')
    when 'To Do', 'Blocked'
      warn "Issue <a href='#{issue.link}'>#{issue.key}</a> is not in Dev status, please make sure the issue you're working on is in the correct status"
    end
  end
end
```

## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.