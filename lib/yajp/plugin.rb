# frozen_string_literal: true

require_relative 'issue'

module Danger
  # Yet Another Jira Plugin (in short: yajp) provides methods to easily find and manipulate issues from within the Dangerfile.
  # The major difference with the existing Jira plugins is the ability to transition and update issues with the same feeling as manipulating PR data from Danger.
  # This plugin was build in the same mind as Danger, meaning that you will find methods to easily manipulate Jira data, but no predefined warning and/or message.
  # Like Danger, it requires environment variables to work:
  #   * DANGER_JIRA_URL: the URL of the Jira server (ex: `https://jira.company.com/jira`)
  #   * DANGER_JIRA_USER: the Jira user that will use the Jira API
  #   * DANGER_JIRA_API_TOKEN: the token associated to the user (Jira Cloud) or the password of the user (Jira Server)
  #
  # @example Full example of a Dangerfile
  #   issues = jira.find_issues('KEY')
  #
  #   if issues.empty?
  #     warn 'This PR does not contain any Jira issue.'
  #   else
  #     issues.each do |issue|
  #       message "<a href='#{issue.link}'>#{issue.key} - #{issue.summary}</a>"
  #
  #       case issue.status.name
  #       when 'In Progress'
  #         issue.transition(10, assignee: { name: 'username' }, customfield_11005: 'example')
  #       when 'To Do', 'Blocked'
  #         warn "Issue <a href='#{issue.link}'>#{issue.key}</a> is not in Dev status, please make sure the issue you're working on is in the correct status"
  #       end
  #     end
  #   end
  #
  # @example Access the Jira client of `jira-ruby` and list all Jira projects
  #   jira.api.Project.all
  #
  # @see  juliendms/danger-yajp
  # @tags jira, danger, gitlab, github
  #
  class DangerYajp < Plugin
    # Give access to the Jira API via `jira-ruby` client.
    #
    # @return [JIRA::Client] Jira API client from `jira-ruby`
    #
    attr_reader :api

    def initialize(dangerfile)
      throw Error('The environment variable DANGER_JIRA_URL is required') if ENV['DANGER_JIRA_URL'].nil?

      super(dangerfile)
      url_parser = %r{(?<site>https?://[^/]+)(?<context_path>/.+)}.match(ENV['DANGER_JIRA_URL'])

      options = {
        username:       ENV['DANGER_JIRA_USER'],
        password:       ENV['DANGER_JIRA_API_TOKEN'],
        site:           url_parser[:site],
        context_path:   url_parser[:context_path],
        auth_type:      :basic
      }

      @api = JIRA::Client.new(options)
    end

    def self.instance_name
      return 'jira'
    end

    # Find Jira issues (keys) in the specified parameters of the PR.
    #
    # @example Find issues in project KEY from the name of the PR branch
    #   jira.find_issues('KEY', search_title: false, search_branch: true)
    #
    # @param [Array<String>]  key An array of Jira project keys like `['KEY', 'JIRA']`, or a single `String` with a Jira project key
    # @param [Boolean] search_title Option to search Jira issues from PR title
    # @param [Boolean] search_commits Option to search Jira issues from from commit messages
    # @param [Boolean] search_branch Option to search Jira issues from the name of the PR branch
    #
    # @return [Array<JIRA::Resource::Issue>] An array containing all the unique issues found in the PR.
    #
    def find_issues(key, search_title: true, search_commits: false, search_branch: false)
      regexp = build_regexp_from_key(key)
      jira_issues = []

      jira_issues.concat(search_title(regexp)) if search_title
      jira_issues.concat(search_commits(regexp)) if search_commits
      jira_issues.concat(search_branch(regexp)) if search_branch
      jira_issues.concat(search_pr_body(regexp)) if jira_issues.empty?

      @issues = jira_issues.uniq(&:downcase).map { |issue_key| @api.Issue.find(issue_key) }
    end

    # Transition the given Jira issue(s) using the ID of the transition. Transition IDs can be found in Jira under Project Workflow > Edit Workflow in Text Mode.
    # The fields that can be updated with this method are only the fields available in the transition screen of the transition. Otherwise use `transition_and_update`.
    #
    # @example Transition the issue `my_issue` and set the fields `assignee` and `customfield_11005` available on the transition screens
    #   jira.transition_all(my_issue, 10, assignee: { name: 'username' }, customfield_11005: 'example')
    #
    # @param [Integer] transition_id
    # @param [Array<JIRA::Resource::Issue>, JIRA::Resource::Issue] issue An array of issues, or a single issue
    # @param [Hash] fields Fields that can be updated on the transition screen
    #
    # @return [Boolean] `true` if all the issues were transitioned successfully, `false` otherwise.
    #
    def transition_all(transition_id, issue: @issues, **fields)
      issues = issue.kind_of?(Array) ? issue : [] << issue
      result = true

      issues.each do |key|
        result &= key.transition(transition_id, **fields)
      end

      return result
    end

    # Update the given Jira issue(s).
    #
    # @example Update the issue `my_issue` and set the fields `assignee` and `customfield_11005`
    #   jira.update_all(my_issue, assignee: { name: 'username' }, customfield_11005: 'example')
    #
    # @param [Array<JIRA::Resource::Issue>, JIRA::Resource::Issue] issue An array of issue, or a single issue
    # @param [Hash] fields Fields to update
    #
    # @return [Boolean] `true` if all the issues were updated successfully, `false` otherwise.
    #
    def update_all(issue: @issues, **fields)
      return if fields.empty?

      issues = issue.kind_of?(Array) ? issue : [] << issue
      result = true

      issues.each do |key|
        result &= key.update(**fields)
      end

      return result
    end

    # Utility to split the given fields into fields that can be updated on the transition screen corresponding to the `transition_id` of the given `issue`.
    #
    # @param [JIRA::Resource::Issue] issue
    # @param [Integer] transition_id
    # @param [Hash] fields Fields to split
    #
    # @return [Hash]
    #   * :transition_fields [Hash] A hash containing the fields available in the transition screens
    #   * :other_fields [Hash] A hash containing the other fields
    #
    def split_transition_fields(issue, transition_id, **fields)
      transitions = issue.transitions.all.keep_if { |transition| transition.attrs['id'] == transition_id.to_s }
      transition_fields = transitions.first.attrs['fields']
      transition_data = {}

      fields.each_key do |field|
        transition_data[field] = fields.delete(field) if transition_fields&.key?(field.to_s)
      end

      { transition_fields: transition_data, other_fields: fields }
    end

    # Transition and update the given issues. It will use the `split_transition_fields` method to provide the right fields for the transition action,
    # and use the other fields with the update action.
    #
    # @example Transition the issue `my_issue` and set the fields `assignee` and `customfield_11005`
    #   jira.transition_and_update_all(my_issue, 10, assignee: { name: 'username' }, customfield_11005: 'example')
    #
    # @param [Integer] transition_id
    # @param [Array<JIRA::Resource::Issue>, JIRA::Resource::Issue] issue An array of issues, or a single issue
    # @param [Hash] fields Fields to update
    #
    # @return [Boolean] `true` if all the issues were transitioned and updated successfully, `false` otherwise.
    #
    def transition_and_update_all(transition_id, issue: @issues, **fields)
      issues = issue.kind_of?(Array) ? issue : [] << issue
      result = issues.first.split_transition_fields(transition_id, fields)
      transition_fields = result[:transition_fields]
      fields = result[:other_fields]

      result = transition(transition_id, issue: issues, **transition_fields)
      result & update(issue: issues, **fields)
    end

    # Add a remote link to the PR in the given Jira issues. It uses the link of the PR as the `globalId` of the remote link, thus avoiding to create duplicates each time the PR is updated.
    #
    # @param [Array<JIRA::Resource::Issue>, JIRA::Resource::Issue] issue An array of issues, or a single issue
    # @param [<String>] relation Option to set the relationship of the remote link
    # @param [<Hash>, <Boolean>] status Option to set the status property of the remote link, it can be <Hash> or a <Boolean> that will set the value of the property `resolved`
    #
    # @return [Boolean] `true` if all the remote links were added successfully, `false` otherwise.
    #
    def pr_as_remotelink(issue, relation: 'relates to', status: nil)
      issues = issue.kind_of?(Array) ? issue : [] << issue
      result = true

      remote_link_prop = { object: { url: pr_link, title: vcs_host.pr_title, icon: link_icon } }
      remote_link_prop[:globalId] = pr_link
      remote_link_prop[:relationship] = relation

      if status.kind_of?(Hash)
        remote_link_prop[:object][:status] = status
      elsif !status.nil?
        remote_link_prop[:object][:status] = { resolved: status }
      end

      issues.each do |key|
        result &= key.remotelink.build.save(remote_link_prop)
      end

      return result
    end

    private

    def vcs_host
      return gitlab if defined? @dangerfile.gitlab

      github
    end

    def pr_link
      return @pr_link unless @pr_link.nil?

      if defined? @dangerfile.gitlab
        @pr_link = vcs_host.pr_json['web_url']
      else
        @pr_link = vcs_host.pr_json['html_url']
      end

      return @pr_link
    end

    def link_icon
      return { title: 'Gitlab', url16x16: 'https://gitlab.com/favicon.ico' } if defined? @dangerfile.gitlab

      { title: 'Github', url16x16: 'https://github.com/favicon.ico' }
    end

    def build_regexp_from_key(key)
      keys = key.kind_of?(Array) ? key.join('|') : key
      return /((?:#{keys})-[0-9]+)/i
    end

    def search_title(regexp)
      jira_issues = []

      vcs_host.pr_title.gsub(regexp) do |match|
        jira_issues << match
      end

      jira_issues
    end

    def search_commits(regexp)
      jira_issues = []

      git.commits.map do |commit|
        commit.message.gsub(regexp) do |match|
          jira_issues << match
        end
      end

      jira_issues
    end

    def search_branch(regexp)
      jira_issues = []

      vcs_host.branch_for_head.gsub(regexp) do |match|
        jira_issues << match
      end

      jira_issues
    end

    def search_pr_body(regexp)
      jira_issues = []

      vcs_host.pr_body.gsub(regexp) do |match|
        jira_issues << match
      end

      jira_issues
    end
  end
end
