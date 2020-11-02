# frozen_string_literal: true

require File.expand_path('spec_helper', __dir__)

module Danger
  describe Danger::DangerYajp do
    it 'should be a plugin' do
      expect(Danger::DangerYajp.new(nil)).to be_a Danger::Plugin
    end

    describe 'with Dangerfile' do
      let(:dangerfile) { testing_dangerfile }
      let(:plugin) { dangerfile.jira }

      before do
        ENV['DANGER_JIRA_URL'] = 'https://jira.company.com/jira'
        ENV['DANGER_JIRA_USER'] = 'username'
        ENV['DANGER_JIRA_PASSWORD'] = 'password'
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
        allow(plugin).to receive_message_chain('github.branch_for_head').and_return('bugfix/WEB-126')
        issues = plugin.search_branch(plugin.build_regexp_from_key('WEB'))
        expect(issues).to eq(['WEB-126'])
      end

      it 'can find jira issues in pr body' do
        allow(plugin).to receive_message_chain('github.pr_body').and_return('Closes WEB-127')
        issues = plugin.search_pr_body(plugin.build_regexp_from_key('WEB'))
        expect(issues).to eq(['WEB-127'])
      end

      it 'can remove duplicates issue' do
        issue = Object.new

        def issue.find(key)
          return key
        end

        allow_any_instance_of(JIRA::Client).to receive(:Issue).and_return(issue)

        allow(plugin).to receive_message_chain('github.pr_title').and_return('Fix for WEB-128 and WEB-129')
        allow(plugin).to receive_message_chain('github.branch_for_head').and_return('bugfix/WEB-128')
        issues = plugin.find_issues('WEB', search_branch: true)
        expect(issues).to eq(['WEB-128', 'WEB-129'])
      end

      it 'can split transition field from other fields' do
        json = File.read("#{File.dirname(__FILE__)}/support/transitions.all.json")
        url = "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/WEB-130/transitions"
        transition_data = { assignee: { name: 'username' }, summary: 'new_summary' }
        fields = { colour: 'red', customfield_11005: 'example' }

        allow_any_instance_of(JIRA::Base).to receive(:self).and_return(url)
        stub = stub_request(:get, "#{url}/transitions?expand=transitions.fields").
          to_return(body: json)
        result = plugin.split_transition_fields(plugin.api.Issue.build, 2, transition_data.merge(fields))

        expect(stub).to have_been_requested.once
        expect(result).to eq({ transition_fields: transition_data, other_fields: fields })
      end

      it 'can transition an issue' do
        expected_json = '{"transition":{"id":"2"},"fields":{"assignee":{"name":"username"},"customfield_11005":"example"}}'
        url = "#{ENV['DANGER_JIRA_URL']}/rest/api/2/issue/WEB-131/transitions"
        issue = plugin.api.Issue.build

        allow(issue).to receive(:key_value).and_return('WEB-131')
        stub = stub_request(:post, url).
          with(body: expected_json)
        plugin.transition(issue, 2, assignee: { name: 'username' }, customfield_11005: 'example')

        expect(stub).to have_been_requested.once
      end
    end
  end
end
