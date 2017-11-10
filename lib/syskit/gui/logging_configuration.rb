require 'vizkit'
require 'vizkit/vizkit_items'
require 'vizkit/tree_view'
require 'Qt4'
require 'syskit/shell_interface'
require 'syskit/gui/logging_configuration_item'
require 'roby/interface/exceptions'

module Syskit
    module GUI
        # A widget containing an editable TreeView to allow the user to
        # manage basic Syskit's logging configuration
        class LoggingConfiguration < Qt::Widget
            attr_reader :model, :treeView, :syskit
            def initialize(parent = nil, syskit)
                super(parent)
                main_layout = Qt::VBoxLayout.new(self)
                @treeView = Qt::TreeView.new

                Vizkit.setup_tree_view treeView
                @model = Vizkit::VizkitItemModel.new
                treeView.setModel @model
                main_layout.add_widget(treeView)
                treeView.setColumnWidth(0, 200)
                treeView.style_sheet = "QTreeView { background-color: rgb(255, 255, 219);
                                                    alternate-background-color: rgb(255, 255, 174);
                                                    color: rgb(0, 0, 0); }
                                        QTreeView:disabled { color: rgb(159, 158, 158); }"

                @syskit = syskit
                @timer = Qt::Timer.new
                @timer.connect(SIGNAL('timeout()')) { refresh }
                @timer.start 10000

                update_model(ShellInterface::LoggingConfiguration.new(false, false, Hash.new))
                refresh
            end

            # Fetches the current logging configuration from syskit's
            # sync interface
            def refresh
                if !syskit.client.nil?
                    begin
                        conf = syskit.client.call ['syskit'], :logging_conf
                        update_model(conf)
                        enabled true
                    rescue Roby::Interface::ComError
                        enabled false
                    end
                else
                    enabled false
                end
            end

            # Expands the entire tree
            def recursive_expand(item)
                treeView.expand(item.index)
                (0...item.rowCount).each do |i|
                    recursive_expand(item.child(i))
                end
            end

            # Changes the top most item in the tree state
            # and makes it update its childs accordingly 
            def enabled(toggle)
                @item1.enabled toggle
            end

            # Updates the view model
            def update_model(conf)
                if @item1.nil?
                    @item1 = LoggingConfigurationItem.new(conf, :accept => true)
                    @item2 = LoggingConfigurationItem.new(conf)
                    @item2.setEditable true
                    @item2.setText ""
                    @model.appendRow([@item1, @item2])
                    recursive_expand(@item1)

                    @item1.on_accept_changes do |new_conf|
                        begin
                            conf = syskit.client.call ['syskit'], :update_logging_conf, new_conf
                        rescue Roby::Interface::ComError
                            enabled false
                        end
                    end
                else
                    return if @item1.modified?
                    @item1.update_conf(conf)
                end
            end
        end
    end
end
