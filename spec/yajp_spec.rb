# frozen_string_literal: true

require_relative 'spec_helper'

# rubocop:disable Metrics/ModuleLength
module Danger
  describe Danger::DangerYajp do
    before do
      ENV['DANGER_JIRA_URL'] = 'https://jira.company.com/jira'
      ENV['DANGER_JIRA_USER'] = 'username'
      ENV['DANGER_JIRA_PASSWORD'] = 'password'
    end

    it 'should be a plugin' do
      expect(Danger::DangerYajp.new(nil)).to be_a Danger::Plugin
    end

    describe 'with Dangerfile' do
      let(:dangerfile) { testing_dangerfile }
      let(:plugin) { dangerfile.jira }

      before do
        DangerYajp.send(:public, *DangerYajp.private_instance_methods)
      end

      it 'should return a JIRA::Client instance' do
        expect(plugin.api).to be_a(JIRA::Client)
      end

      it 'can find jira issues via title' do
        allow(plugin).to receive_message_chain('github.pr_title').and_return('Ticket [WEB-123] and WEB-124')
        issues = plugin.search_title(plugin.build_regexp_from_key('WEB'))
        expect(issues).to eq(['WEB-123', 'WEB-124'])
      end

      it 'can find jira issues in commits' do
        single_commit = Object.new

        def single_commit.message
          'WIP [WEB-125]'
        end

        commits = [single_commit]
        allow(plugin).to receive_message_chain('git.commits').and_return(commits)
        issues = plugin.search_commits(plugin.build_regexp_from_key('WEB'))
        expect(issues).to eq(['WEB-125'])
      end

      it 'can find jira issues via branch name' do
        allow(plugin).to receive_message_chain('github.branch_for_head').and_return('bugfix/web-126')
        issues = plugin.search_branch(plugin.build_regexp_from_key('WEB'))
        expect(issues).to eq(['web-126'])
      end

      it 'can find jira issues in pr body' do
        allow(plugin).to receive_message_chain('github.pr_body').and_return('Closes WEB-127')
        issues = plugin.search_pr_body(plugin.build_regexp_from_key('WEB'))
        expect(issues).to eq(['WEB-127'])
      end

      it 'can remove duplicates issue' do
        issue = Object.new

        def issue.find(key)
          # The find method in jira-ruby plugin is not case sensitive, hence the upcase.
          return key.upcase
        end

        allow_any_instance_of(JIRA::Client).to receive(:Issue).and_return(issue)

        allow(plugin).to receive_message_chain('github.pr_title').and_return('Fix for WEB-128 and WEB-129')
        allow(plugin).to receive_message_chain('github.branch_for_head').and_return('bugfix/web-128')
        issues = plugin.find_issues('WEB', search_branch: true)
        expect(issues).to eq(['WEB-128', 'WEB-129'])
      end

      # rubocop:disable Naming/VariableNumber
      it 'can split transition field from other fields' do
        json = File.read("#{File.dirname(__FILE__)}/support/transitions.all.json")
        url = "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/WEB-130/transitions"
        transition_data = { assignee: { name: 'username' }, summary: 'new_summary' }
        fields = { colour: 'red', customfield_11005: 'example' }

        allow_any_instance_of(JIRA::Base).to receive(:self).and_return(url)
        stub = stub_request(:get, "#{url}/transitions?expand=transitions.fields").
          to_return(body: json)
        result = plugin.split_transition_fields(plugin.api.Issue.build, 2, **transition_data.merge(fields))

        expect(stub).to have_been_requested.once
        expect(result).to eq({ transition_fields: transition_data, other_fields: fields })
      end

      it 'can transition an issue' do
        expected_json = '{"transition":{"id":"2"},"fields":{"assignee":{"name":"username"},"customfield_11005":"example"}}'
        issue_id = Random.rand(1000)
        url = "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/#{issue_id}/transitions"
        issue = plugin.api.Issue.build({ 'id' => issue_id, 'key' => 'WEB-131' })
        transition_1 = issue.transitions.build({ 'id' => '2', 'name' => 'TEST' })
        transition_2 = issue.transitions.build({ 'id' => '3', 'name' => 'FAKE' })

        allow_any_instance_of(JIRA::HasManyProxy).to receive(:all).and_return([transition_1, transition_2])
        stub = stub_request(:post, url).
          with(body: expected_json)
        result = plugin.transition_all('test', issue: issue, assignee: { name: 'username' }, customfield_11005: 'example')

        expect(stub).to have_been_requested.once
        expect(result).to be true
      end

      it 'can update issues' do
        expected_json = '{"fields":{"assignee":{"name":"username"},"customfield_11005":"example"}}'
        uri_template = Addressable::Template.new "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/{issue}"
        issue1 = plugin.api.Issue.build({ 'id' => Random.rand(1000), 'self' => "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/WEB-132", 'key' => 'WEB-132' })
        issue2 = plugin.api.Issue.build({ 'id' => Random.rand(1000), 'self' => "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/WEB-133", 'key' => 'WEB-133' })

        stub = stub_request(:put, uri_template).
          with(body: expected_json)
        result = plugin.update_all(issue: [issue1, issue2], assignee: { name: 'username' }, customfield_11005: 'example')

        expect(stub).to have_been_requested.twice
        expect(result).to be true
      end
      # rubocop:enable Naming/VariableNumber

      it 'can add remote link' do
        pr_title = 'PR Title'
        pr_json = { 'html_url' => 'https://github.com/test/pull/1234' }
        url = "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/WEB-134/remotelink"
        json = File.read("#{File.dirname(__FILE__)}/support/remotelink.json")
        issue = plugin.api.Issue.build

        allow(issue).to receive(:key_value).and_return('WEB-134')
        allow(dangerfile.github).to receive(:pr_json).and_return(pr_json)
        allow(dangerfile.github).to receive(:pr_title).and_return(pr_title)

        stub = stub_request(:post, url).
          with(body: json)
        result = plugin.pr_as_remotelink(issue, status: true)

        expect(stub).to have_been_requested.once
        expect(result).to be true
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
