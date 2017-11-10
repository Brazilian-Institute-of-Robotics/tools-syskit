require 'vizkit'
require 'Qt4'
require 'syskit/gui/logging_configuration_item_base'

module Syskit
    module GUI
        # A QStandardItem to display a hash of Sysit::ShellInterface::LoggingGroup
        # in a tree view
        class LoggingGroupsItem < LoggingConfigurationItemBase
            def initialize(logging_groups, label = '')
                super(logging_groups)

                @groups_item1 = Hash.new
                @groups_item2 = Hash.new

                setText label
                update_groups(logging_groups)
            end

            # Updates the model according to a new hash
            def update_groups(groups)
                @current_model.keys.each do |key|
                    if !groups.key? key
                        group_row = @groups_item1[key].index.row
                        @groups_item1[key].clear
                        @groups_item2[key].clear
                        @groups_item1.delete key
                        @groups_item2.delete key
                        removeRow(group_row)
                    end
                end

                @current_model = deep_copy(groups)
                @editing_model = deep_copy(groups)

                @current_model.keys.each do |key|
                    if !@groups_item1.key? key
                        @groups_item1[key], @groups_item2[key] = add_conf_item(key)
                        @groups_item2[key].getter do
                            @editing_model[key].enabled
                        end
                        @groups_item2[key].setter do |value|
                            @editing_model[key].enabled = value
                        end
                    end
                end
            end
        end
    end
end
