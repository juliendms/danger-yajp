# frozen_string_literal: true

require 'jira-ruby'

module Danger
  # This class extends (aka monkey patch) the `JIRA::Resource::Issue` class with straightforward methods to easily transition and update issues.
  #
  class JIRA::Resource::Issue
    # Get the browse URL of the issue.
    #
    # @return [String] the URL of the issue
    #
    def link
      "#{ENV['DANGER_JIRA_URL']}/browse/#{key}"
    end

    # Update the issue.
    #
    # @example Update the fields `assignee` and `customfield_11005`
    #   issue.update(assignee: { name: 'username' }, customfield_11005: 'example')
    #
    # @param [Hash] fields Fields to update
    #
    # @return [Boolean] `true` if the issue was updated successfully, `false` otherwise.
    #
    def update(**fields)
      return if fields.empty?

      save({ fields: fields })
    end

    # Transition the issue using the ID or name of the transition. Transition IDs can be found in Jira under Project Workflow > Edit Workflow in Text Mode.
    # The transition name is the text that appears on the issue screen to transition it.
    # The fields that can be updated with this method are only the fields available in the transition screen of the transition. Otherwise use `transition_and_update`.
    #
    # @example Transition the issue and set the fields `assignee` and `customfield_11005` available on the transition screens
    #   jira.transition(my_issue, 10, assignee: { name: 'username' }, customfield_11005: 'example')
    #
    # @param [Integer, String] transition_id ID or name of the transition
    # @param [Hash] fields Fields that can be updated on the transition screen
    #
    # @return [Boolean] `true` if the issue was transitioned successfully, `false` otherwise.
    #
    def transition(transition_id, **fields)
      if transition_id.kind_of?(String)
        transition_id = get_transition_id(transition_id)

        return false if transition_id == -1
      end
      data = { transition: { id: transition_id.to_s } }
      data[:fields] = fields unless fields.empty?

      transitions.build.save(data)
    end

    # Retrieve the ID of the transition matching the given name.
    #
    # @param [String] name
    #
    # @return [Integer] the ID of the transition, or -1 if no match was found
    #
    def get_transition_id(name)
      transitions.all.each do |transition|
        return transition.id if transition.name.casecmp?(name)
      end

      return -1
    end
  end
end
